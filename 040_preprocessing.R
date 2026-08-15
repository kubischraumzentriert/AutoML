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

# Wandelt numerische Fehlwert-Sentinels (z.B. -9999) in echtes NA um, BEVOR
# imputemedian sie sonst als extreme, aber gueltige Messwerte einrechnen
# wuerde. Analog zu empty_factor_to_na() oben, aber fuer numerische Spalten
# und mit einer konfigurierbaren Sentinel-Liste statt eines festen Werts
# (siehe sentinel_values in 000_config.R, TARGETS.md fuer den Anlassfall
# geoai-aquaculture-pond-identification-challenge).
sentinel_to_na <- function(x, sentinel_values) {
  if (!is.numeric(x) || length(sentinel_values) == 0) {
    return(x)
  }

  x[x %in% sentinel_values] <- NA_real_
  x
}

build_preprocessing_graph <- function(
    encode_factors = FALSE, scale_numeric = FALSE,
    sentinel_values = get0("sentinel_values", envir = globalenv(), ifnotfound = numeric(0))) {
  graph <- po(
    "colapply",
    id = "empty_factor_to_na",
    applicator = empty_factor_to_na,
    affect_columns = selector_type(c("factor", "ordered"))
  )

  if (length(sentinel_values) > 0) {
    graph <- graph %>>%
      po(
        "colapply",
        id = "sentinel_to_na",
        applicator = function(x) sentinel_to_na(x, sentinel_values),
        affect_columns = selector_type(c("numeric", "integer"))
      )
  }

  graph <- graph %>>%
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
