library(testthat)
library(mlr3)

source(testthat::test_path("..", "..", "modules", "final_model_spec.R"))

make_test_spec <- function() {
  constructor <- function() {
    lrn("classif.rpart", cp = 0.01, minsplit = 2L, predict_type = "prob")
  }
  learner <- constructor()
  build_final_model_spec(
    model_name = "rpart",
    project_name = "spec-fixture",
    target_col = "outcome",
    feature_set = "raw",
    preprocessing = "impute_median_mode",
    positive_class = "yes",
    class_weight_power = 1.5,
    seed = 42L,
    base_learner = learner,
    constructor = constructor,
    selection = list(
      metric_name = "classif.auc",
      metric_value = 0.91,
      candidate_mconf_id = "mconf-1",
      candidate_run_id = "run-1",
      selection_source = "metric_selection"
    ),
    feature_transform_hash = NA_character_,
    decision_threshold = NULL
  )
}

test_that("final-model spec is validated, hashed and versioned", {
  spec <- make_test_spec()
  expect_silent(validate_final_model_spec(spec))
  expect_identical(final_model_spec_hash(spec), spec$spec_hash)

  path <- tempfile(fileext = ".rds")
  on.exit(unlink(c(path, final_model_spec_versioned_path(path, spec$spec_hash))), add = TRUE)
  paths <- write_final_model_spec(spec, path)
  expect_true(file.exists(paths$current_path))
  expect_true(file.exists(paths$versioned_path))
  expect_identical(read_final_model_spec(path), spec)
})

test_that("tampering or context drift fails closed", {
  spec <- make_test_spec()
  tampered <- spec
  tampered$model$learner_params$cp <- 0.02
  expect_error(validate_final_model_spec(tampered), "hash")

  expect_error(
    validate_final_model_spec_context(spec, list(model_name = "ranger")),
    "Re-run 148_select_submission_model"
  )
})

test_that("the frozen learner parameters can be applied to a fresh learner", {
  spec <- make_test_spec()
  constructor <- function() {
    lrn("classif.rpart", predict_type = "response")
  }
  learner <- apply_final_model_spec(constructor(), spec)
  expect_identical(learner$predict_type, "prob")
  expect_equal(learner$param_set$values$cp, 0.01)
  expect_equal(learner$param_set$values$minsplit, 2L)
})
