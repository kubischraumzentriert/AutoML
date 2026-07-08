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
task_weighted <- add_balanced_class_weights(task_train_small, class_weight_power)

make_baseline_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}

learner_ranger <- make_baseline_learner(
  lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = seed),
  id = "ranger"
)

learner_lightgbm <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations),
  id = "lightgbm"
)

# Gleichgewichtetes Wahrscheinlichkeits-Ensemble: beide Zweige liefern "prob",
# po("classifavg") mittelt sie (Standard: gleiche Gewichte), argmax entscheidet.
ensemble_ranger_branch <- learner_ranger$clone(deep = TRUE)
ensemble_ranger_branch$id <- "ranger_branch"
ensemble_ranger_branch$predict_type <- "prob"

ensemble_lightgbm_branch <- learner_lightgbm$clone(deep = TRUE)
ensemble_lightgbm_branch$id <- "lightgbm_branch"
ensemble_lightgbm_branch$predict_type <- "prob"

ensemble_graph <- gunion(list(ensemble_ranger_branch, ensemble_lightgbm_branch)) %>>% po("classifavg", id = "avg")
learner_ensemble <- as_learner(ensemble_graph)
learner_ensemble$id <- "ensemble_ranger_lightgbm"

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_weighted),
  learners = list(learner_ranger, learner_lightgbm, learner_ensemble),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

ensemble_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(ensemble_results, ensemble_ranger_lightgbm_results_path)

cat("=== Ranger vs. LightGBM vs. gleichgewichtetes Ensemble (power =", class_weight_power, ", 5-fache CV) ===\n")
print(ensemble_results)
cat("\nGespeichert:", ensemble_ranger_lightgbm_results_path, "\n")
