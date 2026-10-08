suppressPackageStartupMessages({library(mlr3); library(mlr3learners); library(mlr3pipelines)})
curve_settings <- new.env(parent = globalenv())
curve_settings$project_dir <- normalizePath(testthat::test_path("..", ".."))
source(file.path(curve_settings$project_dir, "000_config.R"), local = curve_settings)
source(file.path(curve_settings$project_dir, "modules", "learning_curve.R"), local = curve_settings)
curve_expressions <- as.list(parse(file.path(curve_settings$project_dir, "023_learning_curve.R")))
learner_expression <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("<-")) &&
  identical(expr[[2]], as.name("learner")), curve_expressions)[[1]]
make_curve_learner <- function() {
  context <- new.env(parent = curve_settings)
  eval(learner_expression, envir = context)
  context$learner
}

test_that("023 imputes medians and modes from training fold only", {
  skip_if_not_installed("ranger")
  task <- as_task_classif(data.frame(
    x = c(1, 3, NA, 5, 7, NA, 1000, 2000, 3000, 4000, 5000, NA),
    category = factor(c("a", "a", "a", "b", NA, NA, rep("b", 5), NA)),
    y = factor(rep(c("no", "yes"), 6))), target = "y", positive = "yes")
  split <- rsmp("custom")
  split$instantiate(task, train_sets = list(1:6), test_sets = list(7:12))
  result <- resample(task, make_curve_learner(), split, store_models = TRUE)
  fitted_graph <- result$learners[[1]]$graph_model
  heldout <- task$clone(deep = TRUE)$filter(7:12)
  median_imputed <- fitted_graph$pipeops$imputemedian$predict(list(heldout))[[1]]
  imputed <- fitted_graph$pipeops$imputemode$predict(list(median_imputed))[[1]]
  values <- imputed$data()
  expect_equal(values$x[6], 4)
  expect_identical(as.character(values$category[6]), "a")
  expect_false(median(task$data()$x, na.rm = TRUE) == 4)
  expect_identical(names(sort(table(task$data()$category), decreasing = TRUE))[1], "b")
  expect_true(all(is.finite(result$prediction()$prob)))
  expect_true(anyNA(task$data()$x))
  expect_true(anyNA(task$data()$category))
})

test_that("imputation is a prediction no-op on complete data", {
  skip_if_not_installed("ranger")
  task <- as_task_classif(data.frame(x = rep(1:10, 8), z = rep(1:8, each = 10),
    y = factor(rep(c("no", "yes"), 40))), target = "y", positive = "yes")
  wrapped <- make_curve_learner()
  plain <- lrn("classif.ranger", num.trees = 100, respect.unordered.factors = "order",
    seed = curve_settings$seed, predict_type = "prob")
  plain$train(task)
  wrapped$train(task)
  expect_identical(wrapped$predict(task)$prob, plain$predict(task)$prob)
  expect_identical(wrapped$predict(task)$response, plain$predict(task)$response)
})

test_that("learning curve runs with missing predictors for binary and multiclass tasks", {
  skip_if_not_installed("ranger")
  binary <- as_task_classif(data.frame(x = rep(c(1:9, NA), 12),
    category = factor(rep(c("a", "b", NA), 40)),
    y = factor(rep(c("FALSE", "TRUE"), 60))), target = "y")
  multiclass <- tsk("iris")
  iris_data <- multiclass$data()
  iris_data$Sepal.Length[seq(1, 150, by = 10)] <- NA_real_
  multiclass <- as_task_classif(iris_data, target = "Species")
  for (task in list(binary, multiclass)) {
    task <- curve_settings$apply_positive_class(task, "TRUE")
    task <- curve_settings$enable_class_stratification(task)
    curve <- curve_settings$learning_curve(task, make_curve_learner(), msr("classif.logloss"),
      fractions = c(0.5, 0.75, 1), cv_folds = 3L, repeats = 1L, seed = 42L)
    expect_equal(nrow(curve), 3L)
    expect_true(all(is.finite(curve$val_score)))
    expect_true(all(is.finite(curve$train_score)))
  }
})
