rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})
source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

validate_only <- "--validate-only" %in% commandArgs(trailingOnly = TRUE)
con <- db_connect()
record <- db_get_submission_model_record(con, project_name, "ensemble", "156_train_full_ensemble.R")
DBI::dbDisconnect(con)
if (nrow(record) == 0L || !file.exists(record$model_path[[1]])) {
  if (validate_only) stop("No completed ensemble available for validation.")
  source(file.path(project_dir, "156_train_full_ensemble.R"))
  validate_only <- FALSE
  con <- db_connect()
  record <- db_get_submission_model_record(con, project_name, "ensemble", "156_train_full_ensemble.R")
  DBI::dbDisconnect(con)
}
source(file.path(project_dir, "provenance.R"))
source(file.path(project_dir, "modules", "submission_contract.R"))
source(file.path(project_dir, "modules", "submission_artifacts.R"))

run_ensemble_submission_export <- function() {
  check_registered_submission_artifact(record)
  if (!identical(record$mconf_feature_set[[1]], "raw")) stop("Ensemble export requires raw features.")
  bundle <- readRDS(record$model_path[[1]])
  if (length(id_col) != 1L) stop("Submission requires one configured ID column.")
  test <- fread(test_path, colClasses = list(character = id_col))
  test_ids <- test[[id_col]]
  validate_submission_ids(test_ids, "Test")
  test[, (id_col) := NULL]
  test <- align_submission_factor_levels(test, bundle$feature_levels)
  predictions <- ensemble_submission_prediction(bundle, test, target_col, positive_class)
  expected <- submission_prediction_values(predictions,
    is_threshold_independent_metric(baseline_measure_ids[[1]]), positive_class)
  sample <- if (file.exists(sample_submission_path)) {
    fread(sample_submission_path, colClasses = list(character = id_col))
  } else NULL
  if (validate_only) {
    submission <- read_submission_csv(submission_ensemble_path, id_col, target_col, expected$mode)
    report <- validate_submission_table(submission, test_ids, id_col, target_col, expected, sample)
  } else {
    submission <- data.table(test_ids, expected$values)
    setnames(submission, c(id_col, target_col))
    report <- write_checked_submission(submission, submission_ensemble_path, test_ids, id_col, target_col, expected, sample)
  }
  report <- c(report, list(status = if (validate_only) "validated_existing_file" else "generated_validated",
    mconf_id = record$mconf_id[[1]], model_sha256 = sha256_file(record$model_path[[1]]),
    submission_path = submission_ensemble_path, submission_sha256 = sha256_file(submission_ensemble_path),
    metric_name = baseline_measure_ids[[1]], test_sha256 = sha256_file(test_path), sample_checked = !is.null(sample)))
  run_id <- log_validated_submission_candidate(report, "157_predict_ensemble_submission.R")
  cat("=== Ensemble submission contract PASSED ===\nFile:", submission_ensemble_path,
    "\nModel configuration:", report$mconf_id, "\nValidation DB run:", run_id,
    "\nSingle-model CSV unchanged; no upload or score recorded.\n")
}
run_ensemble_submission_export()
