sanitize_feature_token <- function(x) {
  x <- gsub("[^A-Za-z0-9]+", "_", x)
  x <- gsub("^_+|_+$", "", x)
  tolower(x)
}

surrogate_feature_name <- function(feature_a, feature_b, operation) {
  paste(
    "sg",
    operation,
    sanitize_feature_token(feature_a),
    sanitize_feature_token(feature_b),
    sep = "_"
  )
}

add_surrogate_guided_features <- function(data, spec, operations = surrogate_guided_operations) {
  if (is.null(spec) || nrow(spec) == 0) {
    return(data)
  }

  data <- as_tibble(data)

  for (i in seq_len(nrow(spec))) {
    feature_a <- spec$feature_a[i]
    feature_b <- spec$feature_b[i]

    if (!all(c(feature_a, feature_b) %in% names(data))) {
      next
    }

    a <- data[[feature_a]]
    b <- data[[feature_b]]

    if (!is.numeric(a) || !is.numeric(b)) {
      next
    }

    if ("product" %in% operations) {
      data[[surrogate_feature_name(feature_a, feature_b, "product")]] <- a * b
    }
    if ("ratio_ab" %in% operations) {
      data[[surrogate_feature_name(feature_a, feature_b, "ratio_ab")]] <- safe_divide(a, b)
    }
    if ("ratio_ba" %in% operations) {
      data[[surrogate_feature_name(feature_a, feature_b, "ratio_ba")]] <- safe_divide(b, a)
    }
    if ("absdiff" %in% operations) {
      data[[surrogate_feature_name(feature_a, feature_b, "absdiff")]] <- abs(a - b)
    }
  }

  data
}
