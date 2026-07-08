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
source(file.path(project_dir, "040_preprocessing.R"))

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

# Alle drei mit derselben power=1.5-Gewichtung wie das finale LightGBM, um
# einen fairen Vergleich fuer eine moegliche Ensemble-Entscheidung zu haben
# (bisherige XGBoost/Ranger-Zahlen aus 080/090 waren ungewichtet).
learner_lightgbm <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations),
  id = "lightgbm"
)

learner_ranger <- make_baseline_learner(
  lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = seed),
  id = "ranger"
)

learner_xgboost <- build_classif_pipeline(
  lrn("classif.xgboost", nrounds = 200),
  encode_factors = TRUE,
  scale_numeric = FALSE
)
learner_xgboost$id <- "xgboost"

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_weighted),
  learners = list(learner_lightgbm, learner_ranger, learner_xgboost),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

ensemble_candidates_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(ensemble_candidates_results, ensemble_candidates_results_path)

cat("=== Ensemble-Kandidaten mit power =", class_weight_power, "(Rohfeatures, 5-fache CV) ===\n")
print(ensemble_candidates_results)
cat("\nGespeichert:", ensemble_candidates_results_path, "\n")
