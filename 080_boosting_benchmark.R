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

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

# Ranger als bekannte Referenz (siehe 037), lightgbm verarbeitet Faktoren nativ
# wie Ranger, xgboost braucht dagegen numerische Eingaben (one-hot encodiert).
learner_ranger <- make_baseline_learner(
  lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = seed)
)

learner_lightgbm <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = 200)
)

learner_xgboost <- build_classif_pipeline(
  lrn("classif.xgboost", nrounds = 200),
  encode_factors = TRUE,
  scale_numeric = FALSE
)

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small),
  learners = list(learner_ranger, learner_lightgbm, learner_xgboost),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

boosting_results_raw <- timed_benchmark$results

boosting_results <- boosting_results_raw[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(boosting_results, boosting_results_path)
saveRDS(timed_benchmark$benchmarks, boosting_benchmark_path)

cat("=== Boosting-Benchmark (Rohfeatures, 5-fache CV) ===\n")
print(boosting_results)
cat("\nGespeichert:\n")
cat("Ergebnisse:", boosting_results_path, "\n")
cat("Benchmark :", boosting_benchmark_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "080_boosting_benchmark.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Boosting-Benchmark: Ranger vs. LightGBM vs. XGBoost")
db_log_run_config(db_con, db_run_id, list(cv_folds = cv_folds))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) {
    algorithm <- algorithm_from_learner_id(row$learner_id[1])
    list(
      task_type = "classif",
      algorithm = algorithm,
      feature_set = feature_set_from_task_id(row$task_id[1]),
      preprocessing = if (algorithm == "xgboost") "empty_to_na_onehot" else "impute_median_mode",
      class_weight_power = NA_real_,
      task_id = row$task_id[1],
      hyperparams = list(n_rounds_or_trees = 200)
    )
  },
  resampling_strategy = "cv", resampling_folds = cv_folds, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
