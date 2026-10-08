# Explicit I/O boundary shared by scripts and cached targets.
check_registered_submission_artifact <- function(record) {
  if (nrow(record) != 1L) stop("No completed registered model artifact.", call. = FALSE)
  path <- record$model_path[[1]]
  manifest <- jsonlite::fromJSON(record$mconf_manifest_json[[1]])
  if (!file.exists(path) || !identical(sha256_file(path), manifest$artifacts$model_artifact_sha256)) {
    stop("Model artifact hash differs from its registered manifest, or artifact is missing.", call. = FALSE)
  }
  invisible(record)
}

log_validated_submission_candidate <- function(report, workflow_name) {
  if (!isTRUE(report$valid) || !report$status %in% c("generated_validated", "validated_existing_file")) {
    stop("Only validated exports may enter the candidate ledger.", call. = FALSE)
  }
  con <- db_connect(project_dir = project_dir)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  report_path <- NULL
  completed <- FALSE
  on.exit(if (!completed && !is.null(report_path)) unlink(report_path), add = TRUE)
  result <- DBI::dbWithTransaction(con, {
    record <- db_get_submission_model_record(con, project_name, workflow_name = NULL, mconf_id = report$mconf_id)
    check_registered_submission_artifact(record)
    if (!identical(sha256_file(record$model_path[[1]]), report$model_sha256) ||
        !identical(sha256_file(report$submission_path), report$submission_sha256)) {
      stop("Candidate artifacts changed before logging.", call. = FALSE)
    }
    project_id <- db_get_or_create_project(con, project_name)
    workflow_id <- db_get_or_create_workflow(con, project_id, "script", workflow_name)
    run_id <- db_create_run(con, workflow_id, seed = seed,
      notes = "Local submission contract validated; no external upload or score recorded")
    dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)
    report_path <- file.path(artifact_dir, paste0("submission_validation_", run_id, ".rds"))
    saveRDS(report, report_path)
    db_log_run_config(con, run_id, c(report, list(validation_report_path = report_path,
      validation_report_sha256 = sha256_file(report_path))))
    db_finish_run(con, run_id, test_data_path = test_path, model_artifact_path = record$model_path[[1]])
    run_id
  })
  completed <- TRUE
  result
}

persist_targets_submission_model <- function(learner, feature_levels, feature_set, positive_class, task) {
  con <- db_connect(project_dir = project_dir)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  dir.create(artifact_dir, recursive = TRUE, showWarnings = FALSE)
  paths <- character(0)
  completed <- FALSE
  on.exit(if (!completed) unlink(paths), add = TRUE)
  result <- DBI::dbWithTransaction(con, {
    project_id <- db_get_or_create_project(con, project_name)
    workflow_id <- db_get_or_create_workflow(con, project_id, "targets", "_targets.R")
    run_id <- db_create_run(con, workflow_id, seed = seed, notes = "Persisted targets full-model cache")
    model_path <- file.path(artifact_dir, paste0("targets_model_", run_id, ".rds"))
    reference_path <- file.path(artifact_dir, paste0("targets_model_reference_", run_id, ".rds"))
    paths <- c(model_path, reference_path)
    saveRDS(list(learner = learner, feature_levels = feature_levels, feature_set = feature_set,
      positive_class = positive_class), model_path)
    model_hash <- sha256_file(model_path)
    manifest <- capture_reproducibility_manifest(
      project_dir = project_dir,
      model = list(name = submission_model_name, positive_class = positive_class,
        params = learner$param_set$values),
      features = list(feature_set = feature_set, feature_transform_hash = feature_transform_function_hash(feature_set)),
      artifacts = list(model_artifact_path = model_path, model_artifact_sha256 = model_hash))
    model_id <- db_create_model_config(con, run_id, "classif", submission_model_name,
      feature_set = feature_set, preprocessing = "impute_median_mode", task_id = task$id,
      hyperparams = c(list(model_artifact_path = model_path), learner$param_set$values), manifest = manifest)
    saveRDS(list(mconf_id = model_id, model_path = model_path, model_sha256 = model_hash), reference_path)
    db_finish_run(con, run_id, train_data_path = train_path, model_artifact_path = model_path)
    paths
  })
  completed <- TRUE
  result
}

read_targets_submission_model <- function(paths) {
  if (length(paths) != 2L) stop("Missing targets artifact/reference pair.", call. = FALSE)
  reference <- readRDS(paths[[2]])
  con <- db_connect(project_dir = project_dir)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  record <- db_get_submission_model_record(con, project_name, submission_model_name,
    "_targets.R", reference$mconf_id)
  check_registered_submission_artifact(record)
  feature_set <- record$mconf_feature_set[[1]]
  if (!identical(feature_set, "raw")) {
    manifest <- jsonlite::fromJSON(record$mconf_manifest_json[[1]])
    current_transform <- feature_transform_function_hash(feature_set)
    if (is.na(current_transform) || !identical(current_transform, manifest$features$feature_transform_hash)) {
      stop("Feature transformation hash differs from the registered model.", call. = FALSE)
    }
  }
  if (!identical(record$model_path[[1]], paths[[1]]) ||
      !identical(reference$model_sha256, sha256_file(paths[[1]]))) {
    stop("Targets model reference differs from its registered artifact.", call. = FALSE)
  }
  list(record = record, bundle = readRDS(paths[[1]]), reference = reference)
}

ensemble_submission_prediction <- function(bundle, test, target_col, positive_class) {
  if (!identical(bundle$target_col_name, target_col)) stop("Ensemble target differs from configuration.", call. = FALSE)
  if (!is.null(bundle$positive_class) && !identical(bundle$positive_class, positive_class)) {
    stop("Ensemble positive class differs from configuration.", call. = FALSE)
  }
  classes <- bundle$class_names
  if (length(classes) < 2L || anyNA(classes) || anyDuplicated(classes)) stop("Invalid ensemble classes.", call. = FALSE)
  members <- bundle$members
  weights <- vapply(members, function(member) {
    weight <- member$weight
    if (!is.numeric(weight) || length(weight) != 1L || !is.finite(weight) || weight < 0) {
      stop("Ensemble weights must be finite nonnegative scalars.", call. = FALSE)
    }
    as.numeric(weight)
  }, numeric(1))
  if (!length(weights) || !is.finite(sum(weights)) || sum(weights) <= 0) stop("Ensemble total weight must be positive.", call. = FALSE)
  average <- matrix(0, nrow(test), length(classes), dimnames = list(NULL, classes))
  for (i in seq_along(members)) {
    probabilities <- members[[i]]$learner$predict_newdata(test)$prob
    if (!is.matrix(probabilities) || !is.numeric(probabilities) ||
        !setequal(colnames(probabilities), classes) || ncol(probabilities) != length(classes) ||
        nrow(probabilities) != nrow(test) || anyNA(probabilities) ||
        any(!is.finite(probabilities) | probabilities < 0 | probabilities > 1) ||
        any(abs(rowSums(probabilities) - 1) > 1e-8)) {
      stop("Ensemble member probabilities violate the class/row/probability contract.", call. = FALSE)
    }
    average <- average + probabilities[, classes, drop = FALSE] * weights[[i]]
  }
  average <- average / sum(weights)
  list(prob = average, response = factor(classes[max.col(average, ties.method = "first")], levels = classes))
}
