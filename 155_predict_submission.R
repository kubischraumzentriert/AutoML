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
for (f in list.files(file.path(project_dir, "features"), pattern = "\\.R$", full.names = TRUE)) source(f)

read_model_record <- function() {
  con <- db_connect()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  db_get_submission_model_record(con, project_name, resolve_submission_model_name())
}
validate_only <- "--validate-only" %in% commandArgs(trailingOnly = TRUE)
record <- read_model_record()
if (nrow(record) == 0L || !file.exists(record$model_path)) {
  if (validate_only) stop("No completed final model available for validation.")
  source(file.path(project_dir, "150_train_full_model.R"))
  # 150 clears globals; restore the export entry point's state.
  validate_only <- FALSE
  con <- db_connect()
  record <- db_get_submission_model_record(con, project_name, resolve_submission_model_name())
  DBI::dbDisconnect(con)
}
source(file.path(project_dir, "provenance.R"))
source(file.path(project_dir, "modules", "submission_contract.R"))
source(file.path(project_dir, "modules", "submission_artifacts.R"))

run_submission_export <- function() {
  if (nrow(record) != 1L) stop("Could not resolve a completed final model.")
  model_name <- resolve_submission_model_name()
  feature_set <- model_feature_sets[[model_name]]
  model_path <- record$model_path[[1]]
  manifest <- jsonlite::fromJSON(record$mconf_manifest_json[[1]])
  expected_hash <- manifest$artifacts$model_artifact_sha256
  model_hash <- sha256_file(model_path)
  if (is.null(expected_hash) || !identical(expected_hash, model_hash)) {
    stop("Model artifact hash differs from its registered manifest, or hash is missing.")
  }
  if (!identical(record$mconf_feature_set[[1]], feature_set)) stop("Registered feature_set differs from configuration.")
  if (!identical(feature_set, "raw")) {
    current_transform <- feature_transform_function_hash(feature_set)
    registered_transform <- manifest$features$feature_transform_hash
    if (is.null(registered_transform) || is.na(current_transform) ||
        !identical(current_transform, registered_transform)) {
      stop("Feature transformation hash differs from the registered model.")
    }
  }
  bundle <- readRDS(model_path)
  expected_learner <- as_learner(po("imputemedian") %>>% po("imputemode") %>>%
    base_learner_constructors[[model_name]]())
  validate_submission_model(bundle, feature_set, expected_learner$param_set$values, positive_class)
  if (length(id_col) != 1L) stop("Submission requires one configured ID column.")
  test <- fread(test_path, colClasses = list(character = id_col))
  test_ids <- test[[id_col]]
  validate_submission_ids(test_ids, "Test")
  test[, (id_col) := NULL]
  test <- apply_feature_set(test, feature_set)
  test <- align_submission_factor_levels(test, bundle$feature_levels)
  predictions <- bundle$learner$predict_newdata(test)
  expected <- submission_prediction_values(predictions,
    is_threshold_independent_metric(baseline_measure_ids[[1]]), positive_class)
  sample <- if (file.exists(sample_submission_path)) {
    fread(sample_submission_path, colClasses = list(character = id_col))
  } else NULL
  if (validate_only) {
    submission <- read_submission_csv(submission_path, id_col, target_col, expected$mode)
    report <- validate_submission_table(submission, test_ids, id_col, target_col, expected, sample)
  } else {
    submission <- data.table(test_ids, expected$values)
    setnames(submission, c(id_col, target_col))
    report <- write_checked_submission(submission, submission_path, test_ids, id_col, target_col, expected, sample)
  }
  report <- c(report, list(status = if (validate_only) "validated_existing_file" else "generated_validated",
    mconf_id = record$mconf_id[[1]], model_path = model_path, model_sha256 = model_hash,
    metric_name = baseline_measure_ids[[1]],
    submission_path = submission_path, submission_sha256 = sha256_file(submission_path),
    sample_checked = !is.null(sample), test_sha256 = sha256_file(test_path)))
  run_id <- log_validated_submission_candidate(report, "155_predict_submission.R")
  cat("=== Submission contract PASSED ===\n")
  cat("Mode:", report$mode, "Rows:", report$rows, "Positive class:", report$positive_class, "\n")
  cat("File:", submission_path, "\nModel configuration:", report$mconf_id,
    "\nValidation DB run:", run_id, "\n")
}
run_submission_export()
