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
