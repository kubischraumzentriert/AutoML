# Defensive export contract: binary probabilities or classification labels.
# Multi-column probability formats require competition-specific mapping.
submission_prediction_values <- function(prediction, probability_metric, positive_class = NULL) {
  probabilities <- prediction$prob
  classes <- if (!is.null(probabilities)) colnames(probabilities) else levels(prediction$response)
  if (probability_metric) {
    if (is.null(probabilities) || ncol(probabilities) != 2L ||
        is.null(classes) || anyNA(classes) || anyDuplicated(classes)) {
      stop("Probability submission requires two named classes; multiclass needs explicit column mapping.", call. = FALSE)
    }
    if (!is.numeric(probabilities) || any(!is.finite(probabilities)) ||
        any(probabilities < 0 | probabilities > 1) || any(abs(rowSums(probabilities) - 1) > 1e-8)) {
      stop("Model probability rows must be finite, in [0,1] and sum to one.", call. = FALSE)
    }
    selected <- if (is.null(positive_class)) classes[length(classes)] else positive_class
    if (length(selected) != 1L || is.na(selected) || !selected %in% classes) {
      stop("positive_class is not a prediction class.", call. = FALSE)
    }
    if (is.null(positive_class)) {
      warning("positive_class is NULL; preserving legacy export class '", selected, "'. Set it explicitly.", call. = FALSE)
    }
    return(list(mode = "probability", values = probabilities[, selected], positive_class = selected, classes = classes))
  }
  list(mode = "label", values = as.character(prediction$response), positive_class = NA_character_, classes = classes)
}

validate_submission_ids <- function(ids, context) {
  if (!is.atomic(ids) || length(ids) == 0L || anyNA(ids) ||
      any(!nzchar(as.character(ids))) || anyDuplicated(as.character(ids)) ||
      (is.numeric(ids) && any(!is.finite(ids)))) {
    stop(context, " IDs must be nonempty, unique and nonmissing.", call. = FALSE)
  }
}

validate_submission_table <- function(submission, test_ids, id_col, target_col, expected, sample = NULL,
                                      tolerance = 1e-12) {
  if (length(id_col) != 1L || length(target_col) != 1L || identical(id_col, target_col)) {
    stop("Submission requires distinct scalar ID and target columns.", call. = FALSE)
  }
  if (!is.data.frame(submission) || !identical(names(submission), c(id_col, target_col))) {
    stop("Submission columns/order do not match the configured contract.", call. = FALSE)
  }
  validate_submission_ids(test_ids, "Test")
  validate_submission_ids(submission[[id_col]], "Submission")
  if (nrow(submission) != length(test_ids) ||
      !identical(as.character(submission[[id_col]]), as.character(test_ids))) {
    stop("Submission row count or ID order differs from test data.", call. = FALSE)
  }
  if (!is.null(sample)) {
    if (!is.data.frame(sample) || !identical(names(sample), names(submission))) {
      stop("Sample submission columns/order differ from the contract.", call. = FALSE)
    }
    validate_submission_ids(sample[[id_col]], "Sample")
    if (!identical(as.character(sample[[id_col]]), as.character(test_ids))) {
      stop("Sample submission ID order differs from test data.", call. = FALSE)
    }
  }
  values <- submission[[target_col]]
  if (length(expected$values) != nrow(submission)) stop("Prediction row count differs from test data.", call. = FALSE)
  if (identical(expected$mode, "probability")) {
    if (!is.numeric(values) || any(!is.finite(values)) || any(values < 0 | values > 1) ||
        !is.numeric(expected$values) || any(!is.finite(expected$values))) {
      stop("Submission probabilities must be finite numeric values in [0,1].", call. = FALSE)
    }
    error <- max(abs(values - expected$values))
    if (error > tolerance) stop("Submission values differ from the selected model probability column.", call. = FALSE)
  } else if (identical(expected$mode, "label")) {
    if (!is.atomic(values) || anyNA(values) || any(!nzchar(as.character(values))) ||
        anyNA(expected$values) || !identical(as.character(values), as.character(expected$values))) {
      stop("Submission labels differ from model predictions or contain missing values.", call. = FALSE)
    }
    if (!is.null(expected$classes) && any(!as.character(values) %in% expected$classes)) {
      stop("Submission contains unknown class labels.", call. = FALSE)
    }
    error <- 0
  } else {
    stop("Unknown submission output mode.", call. = FALSE)
  }
  list(valid = TRUE, rows = nrow(submission), mode = expected$mode,
       positive_class = expected$positive_class, max_export_error = error)
}

align_submission_factor_levels <- function(test, feature_levels) {
  test <- data.table::copy(test)
  for (column in names(feature_levels)) {
    if (!column %in% names(test)) stop("Missing categorical feature: ", column, call. = FALSE)
    levels <- feature_levels[[column]]
    values <- as.character(test[[column]])
    if (any(!is.na(values) & !values %in% levels)) {
      stop("Unknown test factor levels in feature: ", column, call. = FALSE)
    }
    test[[column]] <- factor(values, levels = levels)
  }
  test
}

validate_submission_model <- function(bundle, feature_set, expected_params, positive_class = NULL) {
  trained_set <- bundle$feature_set
  if (is.null(trained_set) && identical(feature_set, "raw")) trained_set <- "raw"
  if (!identical(trained_set, feature_set)) stop("Model feature_set differs from configuration.", call. = FALSE)
  actual_params <- bundle$learner$param_set$values
  if (!setequal(names(actual_params), names(expected_params)) ||
      !isTRUE(all.equal(actual_params[names(expected_params)], expected_params, tolerance = 0))) {
    stop("Stored model parameters differ from the deployment constructor; retrain or restore configuration.", call. = FALSE)
  }
  stored_positive <- bundle$positive_class
  if (!is.null(positive_class) && !is.null(stored_positive) && !is.na(stored_positive) &&
      !identical(stored_positive, positive_class)) {
    stop("Stored positive class differs from configuration.", call. = FALSE)
  }
  invisible(TRUE)
}

read_submission_csv <- function(path, id_col, target_col, mode) {
  character_columns <- if (mode == "label") c(id_col, target_col) else id_col
  data.table::fread(path, colClasses = list(character = character_columns))
}

write_checked_submission <- function(submission, path, test_ids, id_col, target_col, expected, sample = NULL) {
  validate_submission_table(submission, test_ids, id_col, target_col, expected, sample)
  staged_path <- tempfile(pattern = ".submission-", tmpdir = dirname(path), fileext = ".csv")
  on.exit(unlink(staged_path), add = TRUE)
  data.table::fwrite(submission, staged_path)
  staged <- read_submission_csv(staged_path, id_col, target_col, expected$mode)
  report <- validate_submission_table(staged, test_ids, id_col, target_col, expected, sample)
  if (!file.copy(staged_path, path, overwrite = TRUE)) stop("Could not publish validated submission file.", call. = FALSE)
  report
}
