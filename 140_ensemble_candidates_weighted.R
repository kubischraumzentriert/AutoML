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
source(file.path(project_dir, "db_logging.R"))

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
# predict_type="prob" jeweils: siehe 030_baseline.R/BACKLOG.md (2026-09-01).
learner_lightgbm <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations, predict_type = "prob"),
  id = "lightgbm"
)

learner_ranger <- make_baseline_learner(
  lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = seed, predict_type = "prob"),
  id = "ranger"
)

learner_xgboost <- build_classif_pipeline(
  lrn("classif.xgboost", nrounds = 200, predict_type = "prob"),
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

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "140_ensemble_candidates_weighted.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Ensemble-Kandidaten (LightGBM/Ranger/XGBoost) unter finaler Klassengewichtung")
db_log_run_config(db_con, db_run_id, list(
  cv_folds = cv_folds,
  class_weight_power = class_weight_power,
  lightgbm_tuning_final_iterations = lightgbm_tuning_final_iterations
))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) {
    algorithm <- algorithm_from_learner_id(row$learner_id[1])
    list(
      task_type = "classif", algorithm = algorithm, feature_set = feature_set_from_task_id(row$task_id[1]),
      preprocessing = if (algorithm == "xgboost") "empty_to_na_onehot" else "impute_median_mode",
      class_weight_power = class_weight_power, task_id = row$task_id[1],
      hyperparams = if (algorithm == "lightgbm") list(num_iterations = lightgbm_tuning_final_iterations) else list(n_rounds_or_trees = 200)
    )
  },
  resampling_strategy = "cv", resampling_folds = cv_folds, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
