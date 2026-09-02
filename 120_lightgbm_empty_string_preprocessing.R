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

# Variante A: "" bleibt eigene Faktorstufe (aktueller Ansatz in 070_final_models.R).
make_baseline_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}
# predict_type="prob" jeweils: siehe 030_baseline.R/BACKLOG.md (2026-09-01).
learner_keep_empty <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations, predict_type = "prob"),
  id = "lightgbm_keep_empty"
)

# Variante B: "" -> NA -> Imputation via empty_factor_to_na (040_preprocessing.R).
learner_na_impute <- build_classif_pipeline(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations, predict_type = "prob"),
  encode_factors = FALSE,
  scale_numeric = FALSE
)
learner_na_impute$id <- "lightgbm_na_impute"

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_weighted),
  learners = list(learner_keep_empty, learner_na_impute),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

lightgbm_empty_string_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(lightgbm_empty_string_results, lightgbm_empty_string_results_path)

cat("=== LightGBM: '' behalten vs. '' -> NA -> Imputation (power =", class_weight_power, ", 5-fache CV) ===\n")
print(lightgbm_empty_string_results)
cat("\nGespeichert:", lightgbm_empty_string_results_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "120_lightgbm_empty_string_preprocessing.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "LightGBM: Leerstring behalten vs. NA-Imputation")
db_log_run_config(db_con, db_run_id, list(cv_folds = cv_folds, class_weight_power = class_weight_power, lightgbm_tuning_final_iterations = lightgbm_tuning_final_iterations))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) list(
    task_type = "classif", algorithm = "lightgbm", feature_set = feature_set_from_task_id(row$task_id[1]),
    preprocessing = if (grepl("na_impute", row$learner_id[1])) "empty_to_na_impute" else "keep_empty_string",
    class_weight_power = class_weight_power, task_id = row$task_id[1],
    hyperparams = list(num_iterations = lightgbm_tuning_final_iterations)
  ),
  resampling_strategy = "cv", resampling_folds = cv_folds, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
