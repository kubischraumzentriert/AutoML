# Controlled LightGBM seed/thread screening on one fixed holdout split.
rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "modules", "lightgbm_seed_thread.R"))
source(file.path(project_dir, "db_logging.R"))

if (!requireNamespace("lightgbm", quietly = TRUE)) {
  stop("Package 'lightgbm' is required for this controlled comparison.", call. = FALSE)
}
if (!file.exists(task_train_small_path)) source(file.path(project_dir, "020_task.R"))

task <- readRDS(task_train_small_path)
task <- enable_class_stratification(apply_positive_class(task, positive_class))
measure_id <- baseline_measure_ids[[1]]
measure <- msr(measure_id)
grid <- lightgbm_seed_thread_grid(lightgbm_seed_thread_seeds, lightgbm_seed_thread_threads)
started <- Sys.time()

set.seed(seed)
test_idx <- sample(task$nrow, round((1 - validation_ratio) * task$nrow))
train_idx <- setdiff(seq_len(task$nrow), test_idx)
task_train <- task$clone(deep = TRUE)$filter(train_idx)
task_test <- task$clone(deep = TRUE)$filter(test_idx)

make_learner <- function(seed_value, threads) {
  base <- lrn("classif.lightgbm", predict_type = "prob",
    num_iterations = lightgbm_tuning_final_iterations,
    seed = seed_value, num_threads = threads)
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base)
}

if (file.exists(lightgbm_seed_thread_artifact_path)) {
  cached <- readRDS(lightgbm_seed_thread_artifact_path)
  results <- cached$results
  paired <- cached$paired
  summary <- cached$summary
  train_idx <- cached$train_idx
  test_idx <- cached$test_idx
  cat("=== Reusing completed LightGBM seed/thread screening artifact ===\n")
} else {
  cat("=== LightGBM seed/thread screening ===\n")
  cat("Fixed holdout rows:", task_train$nrow, "train /", task_test$nrow, "test;",
      "iterations:", lightgbm_tuning_final_iterations, "\n")
  results <- rbindlist(lapply(seq_len(nrow(grid)), function(i) {
  setting <- grid[i, , drop = FALSE]
  learner <- make_learner(setting$seed, setting$num_threads)
  started_fit <- Sys.time()
  learner$train(task_train)
  score <- learner$predict(task_test)$score(measure)[[measure_id]]
  data.table(seed = setting$seed, num_threads = setting$num_threads,
             metric = measure_id, score = score,
             elapsed_seconds = as.numeric(Sys.time() - started_fit, units = "secs"))
  }))
  setnames(results, "score", measure_id)
  paired <- paired_seed_thread_summary(results, measure_id)
  summary <- summarize_seed_thread_check(results, measure_id)
}
print(results)
cat("\nPaired thread deltas (high - low):\n")
print(paired)
cat("\nSummary:\n")
print(summary)

dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)
fwrite(results, lightgbm_seed_thread_results_path)
fwrite(paired, lightgbm_seed_thread_paired_path)
fwrite(summary, lightgbm_seed_thread_summary_path)
saveRDS(list(results = results, paired = paired, summary = summary,
  train_idx = train_idx, test_idx = test_idx, task_id = task$id),
  lightgbm_seed_thread_artifact_path)
cat("\nElapsed total:", round(as.numeric(Sys.time() - started, units = "mins"), 2), "minutes\n")

db_con <- db_connect()
project_id <- db_get_or_create_project(db_con, project_name)
workflow_id <- db_get_or_create_workflow(db_con, project_id, "script", "093_lightgbm_seed_thread_stability.R")
run_id <- db_create_run(db_con, workflow_id, seed = seed,
  notes = paste0("Paired LightGBM seed/thread screening; metric ", measure_id))
db_log_run_config(db_con, run_id, list(
  metric_name = measure_id,
  seed_thread_seeds = paste(grid$seed, collapse = ","),
  seed_thread_threads = paste(grid$num_threads, collapse = ","),
  fixed_holdout_train_rows = task_train$nrow,
  fixed_holdout_test_rows = task_test$nrow,
  lightgbm_iterations = lightgbm_tuning_final_iterations,
  result_path = lightgbm_seed_thread_results_path,
  paired_path = lightgbm_seed_thread_paired_path,
  summary_path = lightgbm_seed_thread_summary_path,
  artifact_path = lightgbm_seed_thread_artifact_path
))
rsmp_id <- db_create_resampling(db_con, run_id, strategy = "holdout", folds = 1L,
  ratio = validation_ratio, seed = seed)
for (i in seq_len(nrow(results))) {
  mconf_id <- db_create_model_config(db_con, run_id, "classif", "lightgbm", feature_set = "raw",
    preprocessing = "impute_median_mode", task_id = as.character(task$id),
    hyperparams = list(seed = as.integer(results$seed[[i]]), num_threads = as.integer(results$num_threads[[i]]),
      num_iterations = lightgbm_tuning_final_iterations))
  db_log_metric_result(db_con, mconf_id, as.character(rsmp_id), as.character(measure_id),
    as.numeric(results[[measure_id]][[i]]))
}
db_finish_run(db_con, run_id, train_data_path = train_path, test_data_path = test_path,
  feature_set = task$feature_names, model_artifact_path = lightgbm_seed_thread_artifact_path)
DBI::dbDisconnect(db_con)
cat("\nExperiment-DB:", experiments_db_path, "(run", run_id, ")\n")
