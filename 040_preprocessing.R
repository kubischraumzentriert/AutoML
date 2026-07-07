suppressPackageStartupMessages({
  library(mlr3)
  library(mlr3pipelines)
})

empty_factor_to_na <- function(x) {
  if (!is.factor(x) && !is.ordered(x)) {
    return(x)
  }

  y <- as.character(x)
  y[y == ""] <- NA_character_
  factor(y)
}

build_preprocessing_graph <- function(encode_factors = FALSE, scale_numeric = FALSE) {
  graph <- po(
    "colapply",
    id = "empty_factor_to_na",
    applicator = empty_factor_to_na,
    affect_columns = selector_type(c("factor", "ordered"))
  ) %>>%
    po("imputemedian", id = "impute_numeric_median") %>>%
    po("imputemode", id = "impute_factor_mode") %>>%
    po("fixfactors", id = "fix_factor_levels")

  if (encode_factors) {
    graph <- graph %>>%
      po("encode", id = "encode_factors_one_hot", method = "one-hot")
  }

  if (scale_numeric) {
    graph <- graph %>>%
      po("scale", id = "scale_numeric")
  }

  graph
}

build_classif_pipeline <- function(base_learner, encode_factors = FALSE, scale_numeric = FALSE) {
  as_learner(
    build_preprocessing_graph(
      encode_factors = encode_factors,
      scale_numeric = scale_numeric
    ) %>>%
      base_learner
  )
}
