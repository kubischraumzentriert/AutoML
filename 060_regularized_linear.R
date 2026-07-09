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

if (!file.exists(task_train_small_features_path)) {
  source(file.path(project_dir, "025_feature_engineering.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_train_small_features <- readRDS(task_train_small_features_path)

make_cv_glmnet <- function(id, alpha) {
  learner <- lrn(
    "classif.cv_glmnet",
    id = id,
    alpha = alpha,
    nfolds = glmnet_nfolds,
    nlambda = glmnet_nlambda,
    standardize = TRUE,
    s = "lambda.1se"
  )

  build_classif_pipeline(
    learner,
    encode_factors = TRUE,
    scale_numeric = FALSE
  )
}

learners <- list(
  make_cv_glmnet("glmnet_ridge", alpha = 0),
  make_cv_glmnet("glmnet_elastic_net", alpha = 0.5),
  make_cv_glmnet("glmnet_lasso", alpha = 1)
)

resampling <- rsmp("holdout", ratio = validation_ratio)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small, task_train_small_features),
  learners = learners,
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

glmnet_results_raw <- timed_benchmark$results

glmnet_results <- glmnet_results_raw[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(glmnet_results, glmnet_results_path)
saveRDS(timed_benchmark$benchmarks, glmnet_benchmark_path)

cat("=== Regularisierte lineare Modelle: glmnet ===\n")
print(glmnet_results)
cat("\nGespeichert:\n")
cat("Ergebnisse:", glmnet_results_path, "\n")
cat("Benchmark :", glmnet_benchmark_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "060_regularized_linear.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Regularisierte lineare Modelle (glmnet: Ridge/Elastic Net/Lasso)")
db_log_run_config(db_con, db_run_id, list(
  validation_ratio = validation_ratio,
  glmnet_nfolds = glmnet_nfolds,
  glmnet_nlambda = glmnet_nlambda
))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) list(
    task_type = "classif",
    algorithm = algorithm_from_learner_id(row$learner_id[1]),
    feature_set = feature_set_from_task_id(row$task_id[1]),
    preprocessing = "empty_to_na_onehot",
    class_weight_power = NA_real_,
    task_id = row$task_id[1],
    hyperparams = list(nfolds = glmnet_nfolds, nlambda = glmnet_nlambda, s = "lambda.1se")
  ),
  resampling_strategy = "holdout", resampling_ratio = validation_ratio, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
