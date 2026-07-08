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

# CatBoosts Kernvorteil bei uns waere nicht die Kategorie-Kodierung (siehe
# README, 3-4 Auspraegungen je Spalte), sondern Ordered Boosting, das generell
# gegen Prediction-Shift/Overfitting hilft - unabhaengig von Kategorien.
learner_catboost <- make_baseline_learner(
  lrn("classif.catboost", iterations = catboost_iterations),
  id = "catboost"
)

learner_lightgbm <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations),
  id = "lightgbm"
)

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_weighted),
  learners = list(learner_lightgbm, learner_catboost),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

catboost_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(catboost_results, catboost_results_path)

cat("=== CatBoost vs. LightGBM (power =", class_weight_power, ", Rohfeatures, 5-fache CV) ===\n")
print(catboost_results)
cat("\nGespeichert:", catboost_results_path, "\n")
