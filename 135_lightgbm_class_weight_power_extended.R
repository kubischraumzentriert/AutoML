rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "005_benchmark_runtime.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)

# Setzt die Klassengewicht-Kurve aus 105 ueber power=1 hinaus fort, um zu
# pruefen, ob LightGBM CatBoosts BAcc (0.9435) einholen kann, ohne das Modell
# zu wechseln (CatBoost war ca. 10x langsamer, siehe 125).
tasks_by_power <- lapply(class_weight_power_extended_grid, function(power) add_balanced_class_weights(task_train_small, power))

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

learner_lightgbm <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations)
)

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = tasks_by_power,
  learners = list(learner_lightgbm),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

class_weight_power_extended_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]
class_weight_power_extended_results[, weight_power := class_weight_power_extended_grid]

fwrite(class_weight_power_extended_results, class_weight_power_extended_results_path)

cat("=== LightGBM: Klassengewichtung ueber power=1 hinaus (5-fache CV) ===\n")
print(class_weight_power_extended_results)
cat("\nZum Vergleich CatBoost (power=1): BAcc 0.9435, MCC 0.8022, 805.8 s\n")
cat("\nGespeichert:", class_weight_power_extended_results_path, "\n")
