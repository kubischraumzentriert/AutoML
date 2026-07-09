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
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

family_task_paths <- vapply(feature_families, task_train_small_feature_family_path, character(1))
if (!all(file.exists(family_task_paths)) || !file.exists(task_train_small_features_path) ||
      !file.exists(task_train_small_features_selected_path)) {
  source(file.path(project_dir, "025_feature_engineering.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_train_small_features <- readRDS(task_train_small_features_path)
task_train_small_features_selected <- readRDS(task_train_small_features_selected_path)
family_tasks <- lapply(family_task_paths, readRDS)

tasks <- c(list(task_train_small), family_tasks, list(task_train_small_features_selected, task_train_small_features))

# Klassengewichtung (power = 1, siehe README "Klassengewichtung") auf alle
# Tasks anwenden, damit der Feature-Vergleich zur tatsaechlichen finalen
# LightGBM-Konfiguration passt, nicht zu einer ungewichteten Variante.
tasks_weighted <- lapply(tasks, add_balanced_class_weights, power = class_weight_power)

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

learner_lightgbm <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations)
)

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = tasks_weighted,
  learners = list(learner_lightgbm),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

lightgbm_family_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(lightgbm_family_results, lightgbm_family_results_path)

cat("=== LightGBM Feature-Family-Benchmark (power =", class_weight_power, ", 5-fache CV) ===\n")
print(lightgbm_family_results)
cat("\nGespeichert:", lightgbm_family_results_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "110_lightgbm_feature_family_benchmark.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "LightGBM Feature-Family-Benchmark unter finaler Klassengewichtung")
db_log_run_config(db_con, db_run_id, list(
  cv_folds = cv_folds,
  class_weight_power = class_weight_power,
  lightgbm_tuning_final_iterations = lightgbm_tuning_final_iterations
))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) list(
    task_type = "classif", algorithm = "lightgbm", feature_set = feature_set_from_task_id(row$task_id[1]),
    preprocessing = "impute_median_mode", class_weight_power = class_weight_power, task_id = row$task_id[1],
    hyperparams = list(num_iterations = lightgbm_tuning_final_iterations)
  ),
  resampling_strategy = "cv", resampling_folds = cv_folds, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
