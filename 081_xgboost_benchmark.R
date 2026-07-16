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

# XGBoost separat von 080 (Ranger/LightGBM), weil es als einziges der drei
# Boosting-/Ensemble-Modelle numerische Eingaben braucht: mlr3learners'
# classif.xgboost akzeptiert nur logical/integer/numeric, keine Faktoren
# (geprueft mit mlr3learners 0.13.0 / xgboost 1.7.11.1 - die C++-Bibliothek
# hat seit ~1.6 natives enable_categorical, mlr3learners bindet es aber nicht
# an). Deshalb hier die One-Hot-Pipeline aus 040_preprocessing.R, die 080
# bewusst NICHT mehr sourct. Wer nur Ranger/LightGBM vergleichen will, muss
# diese Preprocessing-Abhaengigkeit damit nicht mehr mitziehen (frueherer
# Reibungspunkt, siehe TARGETS.md-Backlog).
learner_xgboost <- build_classif_pipeline(
  lrn("classif.xgboost", nrounds = 200, predict_type = "prob"),
  encode_factors = TRUE,
  scale_numeric = FALSE
)

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small),
  learners = list(learner_xgboost),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

xgboost_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(xgboost_results, xgboost_results_path)
saveRDS(timed_benchmark$benchmarks, xgboost_benchmark_path)

cat("=== XGBoost-Benchmark (Rohfeatures, one-hot, 5-fache CV) ===\n")
print(xgboost_results)
cat("\nZum Vergleich (Ranger/LightGBM aus 080_boosting_benchmark.R):\n")
if (file.exists(boosting_results_path)) print(fread(boosting_results_path))
cat("\nGespeichert:\n")
cat("Ergebnisse:", xgboost_results_path, "\n")
cat("Benchmark :", xgboost_benchmark_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "081_xgboost_benchmark.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "XGBoost-Benchmark (one-hot) vs. Ranger/LightGBM-Referenz aus 080")
db_log_run_config(db_con, db_run_id, list(cv_folds = cv_folds))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) list(
    task_type = "classif",
    algorithm = algorithm_from_learner_id(row$learner_id[1]),
    feature_set = feature_set_from_task_id(row$task_id[1]),
    preprocessing = "empty_to_na_onehot",
    class_weight_power = NA_real_,
    task_id = row$task_id[1],
    hyperparams = list(nrounds = 200)
  ),
  resampling_strategy = "cv", resampling_folds = cv_folds, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
