suppressPackageStartupMessages(library(mlr3))
settings <- new.env(parent = globalenv())
settings$project_dir <- normalizePath(testthat::test_path("..", ".."))
source(file.path(settings$project_dir, "000_config.R"), local = settings)

test_that("configured positive class overrides a binary task consistently", {
  task <- as_task_classif(data.frame(x = 1:6, y = factor(rep(c("FALSE", "TRUE"), 3))), target = "y")
  result <- settings$apply_positive_class(task, "TRUE")
  expect_identical(result, task)
  expect_identical(result$positive, "TRUE")
  expect_identical(settings$apply_positive_class(task, "FALSE")$positive, "FALSE")
  expect_error(settings$apply_positive_class(task, "not_a_class"))
})

test_that("NULL preserves both default and cached binary positive class", {
  task <- as_task_classif(data.frame(x = 1:6, y = factor(rep(c("a", "b"), 3))), target = "y")
  original_positive <- task$positive
  expect_identical(settings$apply_positive_class(task, NULL)$positive, original_positive)
  task$positive <- "b"
  path <- tempfile(fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  saveRDS(task, path)
  cached <- readRDS(path)
  expect_identical(settings$apply_positive_class(cached, NULL)$positive, "b")
  expect_identical(settings$apply_positive_class(cached, "a")$positive, "a")
})

test_that("multiclass and regression tasks remain unchanged", {
  task <- tsk("iris")
  original_data <- task$data()
  original_roles <- task$col_roles
  original_positive <- task$positive
  expect_identical(settings$apply_positive_class(task, "TRUE"), task)
  expect_identical(task$positive, original_positive)
  expect_identical(task$data(), original_data)
  expect_identical(task$col_roles, original_roles)
  regr <- tsk("mtcars")
  expect_identical(settings$apply_positive_class(regr, "TRUE"), regr)
})

test_that("stratification keeps existing roles and positive class", {
  task <- as_task_classif(data.frame(group = rep(c("g1", "g2"), 6), x = 1:12,
    y = factor(rep(c("FALSE", "TRUE"), 6))), target = "y")
  task$set_col_roles("group", add_to = "stratum")
  task <- settings$apply_positive_class(task, "TRUE")
  roles_before <- task$col_roles
  task <- settings$enable_class_stratification(task)
  expect_setequal(task$col_roles$stratum, c("group", "y"))
  expect_identical(task$positive, "TRUE")
  expect_identical(task$col_roles$feature, roles_before$feature)
})

test_that("023 and 150 execute the shared positive-class setting", {
  for (script in c("023_learning_curve.R", "150_train_full_model.R")) {
    expressions <- as.list(parse(file.path(settings$project_dir, script)))
    calls <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("<-")) &&
      is.call(expr[[3]]) && identical(expr[[3]][[1]], as.name("apply_positive_class")), expressions)
    expect_length(calls, 1L)
    context <- new.env(parent = settings)
    context$task_full <- as_task_classif(data.frame(x = 1:6,
      y = factor(rep(c("FALSE", "TRUE"), 3))), target = "y")
    context$positive_class <- "TRUE"
    eval(calls[[1]], envir = context)
    expect_identical(context$task_full$positive, "TRUE")
    context$task_full <- tsk("iris")
    original_positive <- context$task_full$positive
    eval(calls[[1]], envir = context)
    expect_identical(context$task_full$positive, original_positive)
  }
})

test_that("023 applies class settings after both CSV and cached-task loading", {
  expressions <- as.list(parse(file.path(settings$project_dir, "023_learning_curve.R")))
  loader <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("if")) &&
    "task_full_path" %in% all.vars(expr[[2]]), expressions)[[1]]
  class_settings <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("<-")) &&
    is.call(expr[[3]]) && as.character(expr[[3]][[1]]) %in%
      c("apply_positive_class", "enable_class_stratification"), expressions)
  raw_path <- tempfile(fileext = ".csv")
  cached_path <- tempfile(fileext = ".rds")
  on.exit(unlink(c(raw_path, cached_path)), add = TRUE)
  raw <- data.frame(id = 1:12, x = 1:12, y = rep(c("FALSE", "TRUE"), 6))
  data.table::fwrite(raw, raw_path)
  cached_task <- as_task_classif(raw[, c("x", "y")], target = "y", positive = "FALSE")
  saveRDS(cached_task, cached_path)
  for (use_cache in c(FALSE, TRUE)) {
    context <- new.env(parent = settings)
    context$task_full_path <- if (use_cache) cached_path else tempfile()
    context$train_path <- raw_path
    context$id_col <- "id"
    context$target_col <- "y"
    context$positive_class <- "TRUE"
    context$fread <- data.table::fread
    eval(loader, envir = context)
    for (expr in class_settings) eval(expr, envir = context)
    expect_identical(context$task_full$positive, "TRUE")
    expect_true("y" %in% context$task_full$col_roles$stratum)
    expect_false("id" %in% context$task_full$feature_names)
  }
  expect_identical(readRDS(cached_path)$positive, "FALSE")
})

test_that("150 serializes positive-class metadata without removing old bundle fields", {
  expressions <- as.list(parse(file.path(settings$project_dir, "150_train_full_model.R")))
  save_call <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("saveRDS")), expressions)[[1]]
  path <- tempfile(fileext = ".rds")
  on.exit(unlink(path), add = TRUE)
  binary <- as_task_classif(data.frame(x = 1:6, y = factor(rep(c("FALSE", "TRUE"), 3))), target = "y")
  for (task in list(settings$apply_positive_class(binary, "TRUE"), tsk("iris"))) {
    context <- new.env(parent = settings)
    context$task_full <- task
    context$model_path <- path
    context$learner_full <- list(id = "bundle-fixture")
    context$feature_levels <- list()
    context$feature_set <- "raw"
    eval(save_call, envir = context)
    bundle <- readRDS(path)
    expect_true(all(c("learner", "feature_levels", "feature_set", "positive_class") %in% names(bundle)))
    expect_identical(bundle$positive_class, task$positive)
    expect_identical(bundle$learner, context$learner_full)
    expect_identical(bundle$feature_set, "raw")
  }
})
