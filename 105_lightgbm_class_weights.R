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

# power = 0 -> ungewichtet, power = 1 -> volle Balance. Dazwischen gedaempfte
# Zwischenstufen, um einen BAcc/MCC-Mittelweg empirisch zu finden.
weight_powers <- c(0, 0.25, 0.5, 0.75, 1)
tasks_by_power <- lapply(weight_powers, function(power) add_balanced_class_weights(task_train_small, power))

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

# Derselbe Learner fuer alle Power-Stufen - der Unterschied liegt ausschliesslich
# in der weights_learner-Spalte des jeweiligen Tasks, nicht im Learner selbst.
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

class_weight_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]
class_weight_results[, weight_power := weight_powers]

fwrite(class_weight_results, class_weight_results_path)

cat("=== LightGBM: Klassengewichtung nach Power-Stufe (Rohfeatures, 5-fache CV) ===\n")
print(class_weight_results)
cat("\nGespeichert:", class_weight_results_path, "\n")

# Konfusionsmatrizen fuer die beiden Extreme auf einem gemeinsamen Holdout-
# Split, um den BAcc/MCC-Trade-off greifbar zu machen.
cat("\n=== Konfusionsmatrizen (Holdout-Split zur Interpretation) ===\n")
holdout <- rsmp("holdout", ratio = validation_ratio)
holdout$instantiate(task_train_small)

for (i in c(1, length(weight_powers))) {
  task_i <- tasks_by_power[[i]]
  learner_fit <- learner_lightgbm$clone(deep = TRUE)
  learner_fit$train(task_i, row_ids = holdout$train_set(1))
  pred <- learner_fit$predict(task_i, row_ids = holdout$test_set(1))
  cat("\npower =", weight_powers[i], ":\n")
  print(pred$confusion)
}
