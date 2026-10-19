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
source(file.path(project_dir, "modules", "final_model_spec.R"))
for (f in list.files(file.path(project_dir, "features"), pattern = "\\.R$", full.names = TRUE)) source(f)

validate_only_arg <- "--validate-only" %in% commandArgs(trailingOnly = TRUE)

if (!file.exists(final_model_spec_path)) {
  if (validate_only_arg) {
    stop("No final-model spec available for validation. Run 148_select_submission_model.R first.")
  }
  source(file.path(project_dir, "148_select_submission_model.R"))
  source("000_config.R")
  source(file.path(project_dir, "db_logging.R"))
  source(file.path(project_dir, "modules", "final_model_spec.R"))
  for (f in list.files(file.path(project_dir, "features"), pattern = "\\.R$", full.names = TRUE)) source(f)
  validate_only_arg <- "--validate-only" %in% commandArgs(trailingOnly = TRUE)
}

final_model_spec <- read_final_model_spec(final_model_spec_path)

read_model_record <- function(model_name) {
  con <- db_connect()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  db_get_submission_model_record(con, project_name, model_name)
}

validate_only <- validate_only_arg
record <- read_model_record(final_model_spec$model$name)
if (nrow(record) == 0L || !file.exists(record$model_path)) {
  if (validate_only) stop("No completed final model available for validation.")
  source(file.path(project_dir, "150_train_full_model.R"))
  # 150 clears globals; restore the export entry point's state.
  validate_only <- validate_only_arg
  source("000_config.R")
  source(file.path(project_dir, "db_logging.R"))
  source(file.path(project_dir, "modules", "final_model_spec.R"))
  for (f in list.files(file.path(project_dir, "features"), pattern = "\\.R$", full.names = TRUE)) source(f)
  source(file.path(project_dir, "provenance.R"))
  validate_only_arg <- "--validate-only" %in% commandArgs(trailingOnly = TRUE)
  final_model_spec <- read_final_model_spec(final_model_spec_path)
  con <- db_connect()
  record <- db_get_submission_model_record(con, project_name, final_model_spec$model$name)
  DBI::dbDisconnect(con)
}
source(file.path(project_dir, "provenance.R"))
source(file.path(project_dir, "modules", "submission_contract.R"))
source(file.path(project_dir, "modules", "submission_artifacts.R"))

run_submission_export <- function() {
  if (nrow(record) != 1L) stop("Could not resolve a completed final model.")
  model_name <- final_model_spec$model$name
  feature_set <- final_model_spec$model$feature_set
  model_path <- record$model_path[[1]]
  manifest <- jsonlite::fromJSON(record$mconf_manifest_json[[1]])
  validate_final_model_spec_context(
    final_model_spec,
    expected = list(
      project_name = project_name,
      target_col = target_col,
      model_name = model_name,
      feature_set = feature_set,
      preprocessing = "impute_median_mode",
      predict_type = base_learner_constructors[[model_name]]()$predict_type,
      class_weight_power = if (model_name %in% names(model_class_weight_power)) {
        unname(model_class_weight_power[[model_name]])
      } else {
        NULL
      },
      positive_class = positive_class,
      seed = seed,
      learner_params = base_learner_constructors[[model_name]]()$param_set$values,
      constructor_hash = final_model_spec_constructor_hash(base_learner_constructors[[model_name]]),
      feature_transform_hash = feature_transform_function_hash(feature_set)
    )
  )
  if (!identical(manifest$model$final_model_spec_hash, final_model_spec$spec_hash)) {
    stop("Registered manifest does not reference the current final-model spec.")
  }
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
  if (!identical(bundle$final_model_spec_hash, final_model_spec$spec_hash)) {
    stop("Model artifact does not reference the current final-model spec.")
  }
  expected_base_learner <- apply_final_model_spec(
    base_learner_constructors[[model_name]](), final_model_spec
  )
  expected_learner <- as_learner(po("imputemedian") %>>% po("imputemode") %>>%
    expected_base_learner)
  validate_submission_model(
    bundle, feature_set, expected_learner$param_set$values,
    final_model_spec$model$positive_class
  )
  if (length(id_col) != 1L) stop("Submission requires one configured ID column.")
  test <- fread(test_path, colClasses = list(character = id_col))
  test_ids <- test[[id_col]]
  validate_submission_ids(test_ids, "Test")
  test[, (id_col) := NULL]
  test <- apply_feature_set(test, feature_set)
  test <- align_submission_factor_levels(test, bundle$feature_levels)
  predictions <- bundle$learner$predict_newdata(test)
  expected <- submission_prediction_values(predictions,
    is_threshold_independent_metric(baseline_measure_ids[[1]]),
    final_model_spec$model$positive_class)
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
