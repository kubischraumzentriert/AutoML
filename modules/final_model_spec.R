# Final-model contract: freeze the selected production configuration before
# full training and verify the same contract again at submission export.

final_model_spec_schema_version <- 1L

final_model_spec_constructor_hash <- function(constructor) {
  if (!is.function(constructor)) {
    stop("The final-model constructor must be a function.", call. = FALSE)
  }
  digest::digest(deparse(constructor), algo = "sha256")
}

final_model_spec_hash_payload <- function(spec) {
  payload <- spec
  payload$spec_hash <- NULL
  payload$generated_at <- NULL
  payload
}

final_model_spec_hash <- function(spec) {
  digest::digest(final_model_spec_hash_payload(spec), algo = "sha256")
}

validate_final_model_spec <- function(spec) {
  if (!is.list(spec)) stop("Final-model spec must be a list.", call. = FALSE)
  if (!identical(spec$schema_version, final_model_spec_schema_version)) {
    stop("Unsupported final-model spec schema version.", call. = FALSE)
  }

  required_top_level <- c("project", "model", "selection", "provenance", "spec_hash")
  missing_top_level <- setdiff(required_top_level, names(spec))
  if (length(missing_top_level) > 0L) {
    stop("Final-model spec is missing: ", paste(missing_top_level, collapse = ", "), call. = FALSE)
  }

  required_model <- c(
    "name", "learner_id", "feature_set", "preprocessing", "predict_type",
    "learner_params", "class_weight_power", "positive_class", "seed",
    "decision_threshold", "constructor_hash"
  )
  missing_model <- setdiff(required_model, names(spec$model))
  if (length(missing_model) > 0L) {
    stop("Final-model spec model section is missing: ", paste(missing_model, collapse = ", "), call. = FALSE)
  }
  if (!is.character(spec$spec_hash) || length(spec$spec_hash) != 1L || !nzchar(spec$spec_hash)) {
    stop("Final-model spec has no valid spec_hash.", call. = FALSE)
  }
  if (!identical(final_model_spec_hash(spec), spec$spec_hash)) {
    stop("Final-model spec hash does not match its contents.", call. = FALSE)
  }
  if (!is.list(spec$model$learner_params)) {
    stop("Final-model spec learner_params must be a named list.", call. = FALSE)
  }
  if (is.null(names(spec$model$learner_params)) || any(!nzchar(names(spec$model$learner_params)))) {
    stop("Final-model spec learner_params must have names.", call. = FALSE)
  }
  invisible(TRUE)
}

validate_final_model_spec_context <- function(spec, expected = list()) {
  validate_final_model_spec(spec)
  if (!is.list(expected)) stop("Expected final-model context must be a list.", call. = FALSE)

  checks <- list(
    project_name = c("project", "name"),
    target_col = c("project", "target_col"),
    model_name = c("model", "name"),
    feature_set = c("model", "feature_set"),
    preprocessing = c("model", "preprocessing"),
    predict_type = c("model", "predict_type"),
    class_weight_power = c("model", "class_weight_power"),
    positive_class = c("model", "positive_class"),
    seed = c("model", "seed"),
    learner_params = c("model", "learner_params"),
    constructor_hash = c("model", "constructor_hash"),
    feature_transform_hash = c("provenance", "feature_transform_hash")
  )

  for (expected_name in intersect(names(expected), names(checks))) {
    path <- checks[[expected_name]]
    actual <- spec[[path[[1]]]][[path[[2]]]]
    expected_value <- expected[[expected_name]]
    if (!identical(actual, expected_value)) {
      stop(
        "Final-model spec ", if (identical(expected_name, "learner_params")) "parameters differ from current " else "differs from current ", expected_name,
        ": expected ", paste(deparse(expected_value), collapse = " "),
        ", got ", paste(deparse(actual), collapse = " "),
        ". Re-run 148_select_submission_model.R.",
        call. = FALSE
      )
    }
  }
  invisible(TRUE)
}

build_final_model_spec <- function(model_name, project_name, target_col, feature_set,
                                   preprocessing, positive_class, class_weight_power,
                                   seed, base_learner, constructor, selection,
                                   feature_transform_hash = NA_character_,
                                   decision_threshold = NULL) {
  if (!is.character(model_name) || length(model_name) != 1L || !nzchar(model_name)) {
    stop("model_name must be one non-empty string.", call. = FALSE)
  }
  if (!is.list(selection)) stop("selection must be a list.", call. = FALSE)

  spec <- list(
    schema_version = final_model_spec_schema_version,
    project = list(name = project_name, target_col = target_col),
    model = list(
      name = model_name,
      learner_id = base_learner$id,
      feature_set = feature_set,
      preprocessing = preprocessing,
      predict_type = base_learner$predict_type,
      learner_params = base_learner$param_set$values,
      class_weight_power = class_weight_power,
      positive_class = positive_class,
      seed = seed,
      decision_threshold = decision_threshold,
      constructor_hash = final_model_spec_constructor_hash(constructor)
    ),
    selection = selection,
    provenance = list(feature_transform_hash = feature_transform_hash),
    generated_at = format(Sys.time(), tz = "UTC", usetz = TRUE)
  )
  spec$spec_hash <- final_model_spec_hash(spec)
  validate_final_model_spec(spec)
  spec
}

final_model_spec_versioned_path <- function(path, spec_hash) {
  if (!is.character(path) || length(path) != 1L || !nzchar(path)) {
    stop("Final-model spec path must be one non-empty string.", call. = FALSE)
  }
  file.path(dirname(path), paste0(tools::file_path_sans_ext(basename(path)), "_v",
                                 final_model_spec_schema_version, "_",
                                 substr(spec_hash, 1L, 16L), ".rds"))
}

write_final_model_spec <- function(spec, path) {
  validate_final_model_spec(spec)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  versioned_path <- final_model_spec_versioned_path(path, spec$spec_hash)
  temporary_path <- tempfile(pattern = ".final-model-spec-", tmpdir = dirname(path), fileext = ".rds")
  on.exit(unlink(temporary_path), add = TRUE)
  saveRDS(spec, temporary_path)
  if (!file.copy(temporary_path, path, overwrite = TRUE)) {
    stop("Could not publish the current final-model spec.", call. = FALSE)
  }
  if (!file.copy(temporary_path, versioned_path, overwrite = TRUE)) {
    stop("Could not publish the versioned final-model spec.", call. = FALSE)
  }
  invisible(list(current_path = path, versioned_path = versioned_path))
}

read_final_model_spec <- function(path) {
  if (!file.exists(path)) {
    stop("Final-model spec is missing: ", path, ". Run 148_select_submission_model.R first.", call. = FALSE)
  }
  spec <- readRDS(path)
  validate_final_model_spec(spec)
  spec
}

apply_final_model_spec <- function(learner, spec) {
  validate_final_model_spec(spec)
  parameters <- spec$model$learner_params
  unknown <- setdiff(names(parameters), learner$param_set$ids())
  if (length(unknown) > 0L) {
    stop("Final-model spec contains unknown learner parameters: ", paste(unknown, collapse = ", "), call. = FALSE)
  }
  if (length(parameters) > 0L) learner$param_set$values <- parameters
  if (!spec$model$predict_type %in% learner$predict_types) {
    stop("Final-model spec predict_type is unsupported by the learner.", call. = FALSE)
  }
  learner$predict_type <- spec$model$predict_type
  actual_parameters <- learner$param_set$values
  if (!isTRUE(all.equal(actual_parameters[names(parameters)], parameters, tolerance = 0))) {
    stop("Learner parameters differ from the final-model spec after application.", call. = FALSE)
  }
  learner
}
