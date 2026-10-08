test_that("030 persists actual benchmark folds without changing scores or predictions", {
  skip_if_not_installed("mlr3")
  skip_if_not_installed("mlr3learners")
  skip_if_not_installed("RSQLite")
  suppressPackageStartupMessages({ library(mlr3); library(mlr3learners) })
  root <- normalizePath(testthat::test_path("..", ".."))
  had_project_dir <- exists("project_dir", envir = globalenv(), inherits = FALSE)
  old_project_dir <- if (had_project_dir) get("project_dir", envir = globalenv()) else NULL
  assign("project_dir", root, envir = globalenv())
  on.exit({
    if (had_project_dir) assign("project_dir", old_project_dir, envir = globalenv())
    else rm("project_dir", envir = globalenv())
  }, add = TRUE)
  context <- new.env(parent = globalenv())
  context$project_dir <- root
  source(file.path(root, "000_config.R"), local = context)
  source(file.path(root, "005_benchmark_runtime.R"), local = context)
  source(file.path(root, "db_logging.R"), local = context)
  source(file.path(root, "provenance.R"), local = context)
  task <- tsk("iris")
  prototype <- rsmp("holdout", ratio = 0.8)
  set.seed(42)
  timed <- context$run_timed_benchmark(list(task),
    list(lrn("classif.rpart"), lrn("classif.rpart", maxdepth = 2L)),
    prototype, msrs("classif.acc"))
  expect_false(prototype$is_instantiated)
  actual_split <- timed$benchmarks[[1]]$resample_result(1)$resampling
  other_split <- timed$benchmarks[[2]]$resample_result(1)$resampling
  expect_identical(actual_split$train_set(1), other_split$train_set(1))
  expect_identical(actual_split$test_set(1), other_split$test_set(1))
  expect_error(context$capture_run_provenance(resampling = prototype, packages = character(0)))
  scores_before <- data.table::copy(timed$results)
  prediction_before <- timed$benchmarks[[1]]$resample_result(1)$prediction()$response

  db_path <- tempfile(fileext = ".sqlite")
  con <- context$db_connect(db_path)
  on.exit({ DBI::dbDisconnect(con); unlink(c(db_path, paste0(db_path, "-wal"), paste0(db_path, "-shm"))) }, add = TRUE)
  project_id <- context$db_get_or_create_project(con, "baseline-provenance-fixture")
  workflow_id <- context$db_get_or_create_workflow(con, project_id, "script", "030_baseline.R")
  run_id <- context$db_create_run(con, workflow_id, seed = 42)
  context$db_con <- con
  context$db_run_id <- run_id
  context$task_train_small <- task
  context$timed_benchmark <- timed
  # Execute the actual script's finalization call, not a copy of its implementation.
  expressions <- parse(file.path(root, "030_baseline.R"))
  finish_calls <- Filter(function(expr) is.call(expr) &&
    identical(expr[[1]], as.name("db_finish_run")), as.list(expressions))
  expect_length(finish_calls, 1L)
  expect_warning(eval(finish_calls[[1]], envir = context), NA)
  recorded <- DBI::dbGetQuery(con, paste("SELECT rconf_value FROM run_config",
    "WHERE rconf_run_id = ? AND rconf_key = 'provenance.resampling_hash'"), params = list(run_id))
  expected_hash <- context$hash_value(list(list(train = actual_split$train_set(1), test = actual_split$test_set(1))))
  expect_identical(recorded$rconf_value, expected_hash)
  expect_identical(timed$results, scores_before)
  expect_identical(timed$benchmarks[[1]]$resample_result(1)$prediction()$response, prediction_before)
  expect_false(is.na(DBI::dbGetQuery(con, "SELECT run_finished_at FROM run WHERE run_id = ?",
    params = list(run_id))$run_finished_at))
})
