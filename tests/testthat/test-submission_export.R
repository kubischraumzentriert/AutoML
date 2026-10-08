library(data.table)
make_submission_fixture <- function(root, binary) {
  suppressPackageStartupMessages({library(mlr3); library(mlr3learners); library(mlr3pipelines)})
  directory <- tempfile(pattern = "submission-fixture-")
  dir.create(directory)
  dir.create(file.path(directory, "modules"))
  dir.create(file.path(directory, "_artifacts"))
  for (file in c("155_predict_submission.R", "157_predict_ensemble_submission.R", "158_register_submission_result.R", "db_logging.R", "db_schema.sql", "provenance.R")) {
    file.copy(file.path(root, file), file.path(directory, file))
  }
  file.copy(file.path(root, "modules", "submission_contract.R"), file.path(directory, "modules", "submission_contract.R"))
  file.copy(file.path(root, "modules", "submission_registry.R"), file.path(directory, "modules", "submission_registry.R"))
  file.copy(file.path(root, "modules", "submission_artifacts.R"), file.path(directory, "modules", "submission_artifacts.R"))
  file.copy(file.path(root, "_targets.R"), file.path(directory, "production_targets.R"))
  file.copy(file.path(root, "tests", "fixtures", "submission_targets.R"), file.path(directory, "fixture_targets.R"))
  file.copy(file.path(root, "tests", "fixtures", "submission_targets_make.R"), file.path(directory, "fixture_targets_make.R"))
  file.copy(file.path(root, "tests", "fixtures", "submission_config.R"), file.path(directory, "000_config.R"))
  fixture <- list(positive_class = "TRUE", cp = 0,
    measures = if (binary) "classif.auc" else "classif.bacc")
  saveRDS(fixture, file.path(directory, "fixture_settings.rds"))
  had_project_dir <- exists("project_dir", envir = globalenv(), inherits = FALSE)
  old_project_dir <- if (had_project_dir) get("project_dir", envir = globalenv()) else NULL
  assign("project_dir", directory, envir = globalenv())
  on.exit({
    if (had_project_dir) assign("project_dir", old_project_dir, envir = globalenv())
    else rm("project_dir", envir = globalenv())
  }, add = TRUE)
  context <- new.env(parent = globalenv())
  context$project_dir <- directory
  source(file.path(directory, "000_config.R"), local = context)
  source(file.path(directory, "db_logging.R"), local = context)
  source(file.path(directory, "provenance.R"), local = context)
  if (binary) {
    train <- data.table(x = 1:60, category = factor(rep(c("a", "b"), 30)),
      outcome = factor(rep(c("FALSE", "TRUE"), each = 30)))
    levels <- list(category = levels(train$category))
  } else {
    train <- as.data.table(iris)
    setnames(train, "Species", "outcome")
    levels <- list()
  }
  task <- as_task_classif(train, target = "outcome")
  if (binary) task$positive <- "TRUE"
  learner <- as_learner(po("imputemedian") %>>% po("imputemode") %>>% context$base_learner_constructors$rpart())
  learner$train(task)
  fwrite(train, context$train_path)
  saveRDS(task, file.path(directory, "task.rds"))
  test <- copy(train[seq(1, nrow(train), length.out = 10)])
  test[, outcome := NULL]
  test[, id := sprintf("%03d", seq_len(.N))]
  setcolorder(test, c("id", setdiff(names(test), "id")))
  sample <- data.table(id = test$id, outcome = 0)
  fwrite(test, context$test_path)
  fwrite(sample, context$sample_submission_path)
  model_path <- file.path(directory, "_artifacts", "model.rds")
  bundle <- list(learner = learner, feature_set = "raw", feature_levels = levels, positive_class = task$positive)
  saveRDS(bundle, model_path)
  con <- context$db_connect()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  project_id <- context$db_get_or_create_project(con, context$project_name)
  workflow_id <- context$db_get_or_create_workflow(con, project_id, "script", "150_train_full_model.R")
  run_id <- context$db_create_run(con, workflow_id, seed = 42)
  model_id <- context$db_create_model_config(con, run_id, "classif", "rpart", feature_set = "raw",
    hyperparams = list(model_artifact_path = model_path),
    manifest = list(artifacts = list(model_artifact_sha256 = context$sha256_file(model_path))))
  context$db_finish_run(con, run_id)
  foreign_project <- context$db_get_or_create_project(con, "different-project")
  foreign_workflow <- context$db_get_or_create_workflow(con, foreign_project, "script", "150_train_full_model.R")
  foreign_run <- context$db_create_run(con, foreign_workflow, seed = 42)
  context$db_create_model_config(con, foreign_run, "classif", "rpart", feature_set = "raw",
    hyperparams = list(model_artifact_path = "wrong-project.rds"))
  context$db_finish_run(con, foreign_run)
  unfinished_run <- context$db_create_run(con, workflow_id, seed = 42)
  context$db_create_model_config(con, unfinished_run, "classif", "rpart", feature_set = "raw",
    hyperparams = list(model_artifact_path = "unfinished-model.rds"))
  list(directory = directory, model_id = model_id, bundle = bundle, test = test, context = context)
}

run_submission_fixture_script <- function(directory, arguments = character(0), script = "155_predict_submission.R") {
  previous <- getwd()
  on.exit(setwd(previous), add = TRUE)
  setwd(directory)
  executable <- if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript"
  suppressWarnings(system2(file.path(R.home("bin"), executable),
    c(script, arguments), stdout = TRUE, stderr = TRUE))
}

test_that("155 exports and revalidates pinned binary probabilities and multiclass labels", {
  skip_if_not_installed("mlr3extralearners")
  root <- normalizePath(testthat::test_path("..", ".."))
  for (binary in c(TRUE, FALSE)) {
    fixture <- make_submission_fixture(root, binary)
    directory <- fixture$directory
    on.exit(unlink(directory, recursive = TRUE), add = TRUE)
    output <- run_submission_fixture_script(directory)
    expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
    path <- file.path(directory, "submission.csv")
    expect_true(file.exists(path))
    submission <- fread(path, colClasses = list(character = "id"))
    expect_identical(submission$id, fixture$test$id)
    test <- copy(fixture$test); test[, id := NULL]
    predictions <- fixture$bundle$learner$predict_newdata(test)
    expected <- if (binary) predictions$prob[, "TRUE"] else as.character(predictions$response)
    if (binary) expect_equal(submission$outcome, expected, tolerance = 1e-12)
    else expect_identical(as.character(submission$outcome), expected)
    hash_before <- fixture$context$sha256_file(path)
    checked <- run_submission_fixture_script(directory, "--validate-only")
    expect_null(attr(checked, "status"), info = paste(checked, collapse = "\n"))
    expect_identical(fixture$context$sha256_file(path), hash_before)
    # Execute the production targets submission body on the same pinned fixture.
    source(file.path(root, "modules", "submission_contract.R"), local = fixture$context)
    source(file.path(root, "modules", "submission_artifacts.R"), local = fixture$context)
    expressions <- as.list(parse(file.path(root, "_targets.R")))
    target_list <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("list")), expressions)[[1]]
    export_target <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("tar_target")) &&
      identical(expr[[2]], as.name("submission")), as.list(target_list)[-1])[[1]]
    fixture$context$test_file <- file.path(directory, "test.csv")
    fixture$context$sample_submission_file <- file.path(directory, "sample_submission.csv")
    fixture$context$final_model_full <- fixture$bundle$learner
    fixture$context$full_feature_levels <- fixture$bundle$feature_levels
    fixture$context$submission_model_name <- "rpart"
    fixture$context$submission_path <- file.path(directory, "targets_submission.csv")
    fixture$context$make_baseline_learner <- function(base) as_learner(po("imputemedian") %>>% po("imputemode") %>>% base)
    fixture$context$final_model_artifacts <- fixture$context$persist_targets_submission_model(
      fixture$bundle$learner, fixture$bundle$feature_levels, "raw", fixture$bundle$positive_class,
      readRDS(file.path(directory, "task.rds")))
    eval(export_target[[3]], envir = fixture$context)
    expect_identical(readLines(fixture$context$submission_path), readLines(path))
    con <- DBI::dbConnect(RSQLite::SQLite(), file.path(directory, "_artifacts", "experiments.db"))
    recorded <- DBI::dbGetQuery(con, paste("SELECT rconf_value FROM run_config",
      "WHERE rconf_key = 'mconf_id'"))
    expect_equal(sum(recorded$rconf_value == fixture$model_id), 2L)
    expect_equal(nrow(recorded), 3L)
    expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM submission_result")$n, 0L)
    DBI::dbDisconnect(con)
    if (binary) {
      submission$outcome <- 1 - submission$outcome
      fwrite(submission, path)
      tampered_hash <- fixture$context$sha256_file(path)
      rejected <- run_submission_fixture_script(directory, "--validate-only")
      expect_equal(attr(rejected, "status"), 1L)
      expect_true(any(grepl("selected model probability", rejected)))
      expect_identical(fixture$context$sha256_file(path), tampered_hash)
      settings_path <- file.path(directory, "fixture_settings.rds")
      changed_settings <- readRDS(settings_path)
      changed_settings$cp <- 0.5
      saveRDS(changed_settings, settings_path)
      stale <- run_submission_fixture_script(directory, "--validate-only")
      expect_equal(attr(stale, "status"), 1L)
      expect_true(any(grepl("parameters differ", stale)))
      expect_identical(fixture$context$sha256_file(path), tampered_hash)
    }
    unlink(directory, recursive = TRUE)
  }
})

test_that("targets persists a cache-bound model and registers a candidate without retraining on rerun", {
  skip_if_not_installed("targets")
  root <- normalizePath(testthat::test_path("..", ".."))
  fixture <- make_submission_fixture(root, TRUE)
  directory <- fixture$directory
  previous <- getwd()
  on.exit({setwd(previous); unlink(directory, recursive = TRUE)}, add = TRUE)
  setwd(directory)
  made <- run_submission_fixture_script(directory, script = "fixture_targets_make.R")
  expect_null(attr(made, "status"), info = paste(made, collapse = "\n"))
  paths <- targets::tar_read(final_model_artifacts, store = "fixture_store")
  reference <- readRDS(paths[[2]])
  expect_true(all(file.exists(paths)))
  con <- fixture$context$db_connect(project_dir = directory)
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  candidates <- fixture$context$db_list_submission_candidates(con, "submission-fixture")
  expect_equal(nrow(candidates), 1L)
  expect_identical(candidates$mconf_id, reference$mconf_id)
  expect_identical(candidates$model_sha256, fixture$context$sha256_file(paths[[1]]))
  cached <- run_submission_fixture_script(directory, script = "fixture_targets_make.R")
  expect_null(attr(cached, "status"), info = paste(cached, collapse = "\n"))
  expect_identical(targets::tar_read(final_model_artifacts, store = "fixture_store"), paths)
  expect_equal(nrow(fixture$context$db_list_submission_candidates(con, "submission-fixture")), 1L)
  registered <- run_submission_fixture_script(directory, c("--public-score", "0.91"), "158_register_submission_result.R")
  expect_null(attr(registered, "status"), info = paste(registered, collapse = "\n"))
  manifest <- jsonlite::fromJSON(DBI::dbGetQuery(con, "SELECT subm_manifest_json FROM submission_result")$subm_manifest_json)
  expect_identical(manifest$model$workflow_name, "_targets.R")
  expect_identical(manifest$model$mconf_id, reference$mconf_id)
  wrong_workflow <- run_submission_fixture_script(directory,
    c("--workflow-name", "150_train_full_model.R", "--public-score", "0.99"), "158_register_submission_result.R")
  expect_equal(attr(wrong_workflow, "status"), 1L)
  expect_equal(nrow(fixture$context$db_list_submission_events(con, "submission-fixture")), 1L)
  source(file.path(root, "modules", "submission_artifacts.R"), local = fixture$context)
  fixture$context$submission_model_name <- "rpart"
  saveRDS(list(tampered = TRUE), paths[[1]])
  expect_error(fixture$context$read_targets_submission_model(paths), "hash differs")
  rebuilt <- run_submission_fixture_script(directory, script = "fixture_targets_make.R")
  expect_null(attr(rebuilt, "status"), info = paste(rebuilt, collapse = "\n"))
  new_paths <- targets::tar_read(final_model_artifacts, store = "fixture_store")
  expect_false(identical(new_paths, paths))
  expect_false(identical(readRDS(new_paths[[2]])$mconf_id, reference$mconf_id))
  expect_equal(nrow(fixture$context$db_list_submission_candidates(con, "submission-fixture")), 2L)
  # Failure during DB registration must remove staged model/reference files and roll back the run.
  context <- fixture$context
  original_create <- context$db_create_model_config
  context$db_create_model_config <- function(...) stop("injected model registration failure")
  before_files <- list.files(context$artifact_dir)
  before_runs <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM run")$n
  expect_error(context$persist_targets_submission_model(fixture$bundle$learner,
    fixture$bundle$feature_levels, "raw", context$positive_class, readRDS(file.path(directory, "task.rds"))), "injected")
  expect_identical(list.files(context$artifact_dir), before_files)
  expect_identical(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM run")$n, before_runs)
  context$db_create_model_config <- original_create
})

test_that("157 validates weighted ensembles and 158 pins their scores without touching the single-model CSV", {
  skip_if_not_installed("mlr3extralearners")
  root <- normalizePath(testthat::test_path("..", ".."))
  for (binary in c(TRUE, FALSE)) {
    fixture <- make_submission_fixture(root, binary)
    directory <- fixture$directory
    on.exit(unlink(directory, recursive = TRUE), add = TRUE)
    context <- fixture$context
    con <- context$db_connect(project_dir = directory)
    project <- context$db_get_or_create_project(con, context$project_name)
    workflow <- context$db_get_or_create_workflow(con, project, "script", "156_train_full_ensemble.R")
    run <- context$db_create_run(con, workflow, seed = 42)
    bundle <- list(members = list(list(learner = fixture$bundle$learner, weight = 1.5),
      list(learner = fixture$bundle$learner, weight = 2.5)), feature_levels = fixture$bundle$feature_levels,
      class_names = fixture$bundle$learner$state$model$class_names,
      target_col_name = "outcome", positive_class = context$positive_class)
    test <- copy(fixture$test); test[, id := NULL]
    probabilities <- fixture$bundle$learner$predict_newdata(test)$prob
    bundle$class_names <- colnames(probabilities)
    path <- file.path(directory, "_artifacts", "ensemble.rds")
    saveRDS(bundle, path)
    model <- context$db_create_model_config(con, run, "classif", "ensemble", feature_set = "raw",
      hyperparams = list(model_artifact_path = path),
      manifest = list(artifacts = list(model_artifact_sha256 = context$sha256_file(path))))
    context$db_finish_run(con, run)
    sentinel <- charToRaw("single-model CSV remains unchanged")
    writeBin(sentinel, context$submission_path)
    exported <- run_submission_fixture_script(directory, script = "157_predict_ensemble_submission.R")
    expect_null(attr(exported, "status"), info = paste(exported, collapse = "\n"))
    output <- fread(context$submission_ensemble_path, colClasses = list(character = "id"))
    expected_prob <- (probabilities * 1.5 + probabilities * 2.5) / 4
    expected <- if (binary) expected_prob[, "TRUE"] else bundle$class_names[max.col(expected_prob, ties.method = "first")]
    expect_equal(output$outcome, expected, tolerance = 1e-12)
    expect_identical(output$id, fixture$test$id)
    expect_identical(readBin(context$submission_path, "raw", length(sentinel)), sentinel)
    validated <- run_submission_fixture_script(directory, "--validate-only", "157_predict_ensemble_submission.R")
    expect_null(attr(validated, "status"), info = paste(validated, collapse = "\n"))
    registered <- run_submission_fixture_script(directory,
      c("--submission-path", "submission_ensemble.csv", "--public-score", "0.93"), "158_register_submission_result.R")
    expect_null(attr(registered, "status"), info = paste(registered, collapse = "\n"))
    row <- DBI::dbGetQuery(con, "SELECT subm_mconf_id, subm_manifest_json FROM submission_result")
    expect_identical(row$subm_mconf_id, model)
    expect_identical(jsonlite::fromJSON(row$subm_manifest_json)$model$workflow_name, "156_train_full_ensemble.R")
    source(file.path(root, "modules", "submission_artifacts.R"), local = context)
    bad <- bundle; bad$members[[1]]$weight <- -1
    expect_error(context$ensemble_submission_prediction(bad, test, "outcome", context$positive_class), "weights")
    bad <- bundle; bad$class_names[[1]] <- "unknown"
    expect_error(context$ensemble_submission_prediction(bad, test, "outcome", context$positive_class), "probabilities violate")
    bad <- bundle; bad$members <- list()
    expect_error(context$ensemble_submission_prediction(bad, test, "outcome", context$positive_class), "total weight")
    bad <- bundle; bad$positive_class <- "wrong"
    expect_error(context$ensemble_submission_prediction(bad, test, "outcome", context$positive_class), "positive class")
    saveRDS(bad, path)
    before <- context$sha256_file(context$submission_ensemble_path)
    rejected <- run_submission_fixture_script(directory, script = "157_predict_ensemble_submission.R")
    expect_equal(attr(rejected, "status"), 1L)
    expect_true(any(grepl("hash differs", rejected)))
    expect_identical(context$sha256_file(context$submission_ensemble_path), before)
    expect_equal(nrow(context$db_list_submission_candidates(con, context$project_name)), 2L)
    DBI::dbDisconnect(con)
    unlink(directory, recursive = TRUE)
  }
})

test_that("158 pins older validated models, preserves partial scores and keeps registration history", {
  skip_if_not_installed("mlr3extralearners")
  root <- normalizePath(testthat::test_path("..", ".."))
  fixture <- make_submission_fixture(root, TRUE)
  directory <- fixture$directory
  on.exit(unlink(directory, recursive = TRUE), add = TRUE)
  exported <- run_submission_fixture_script(directory)
  expect_null(attr(exported, "status"), info = paste(exported, collapse = "\n"))
  path <- file.path(directory, "submission.csv")
  original_bytes <- readBin(path, "raw", n = file.info(path)$size)
  con <- DBI::dbConnect(RSQLite::SQLite(), file.path(directory, "_artifacts", "experiments.db"))
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  context <- fixture$context
  project_id <- context$db_get_or_create_project(con, "submission-fixture")
  workflow_id <- context$db_get_or_create_workflow(con, project_id, "script", "150_train_full_model.R")
  newer_run <- context$db_create_run(con, workflow_id, seed = 42)
  newer_path <- file.path(directory, "_artifacts", "newer-model.rds")
  newer_bundle <- fixture$bundle
  newer_bundle$identity_marker <- "separate-final-model"
  saveRDS(newer_bundle, newer_path)
  newer_model <- context$db_create_model_config(con, newer_run, "classif", "rpart", feature_set = "raw",
    hyperparams = list(model_artifact_path = newer_path),
    manifest = list(artifacts = list(model_artifact_sha256 = context$sha256_file(newer_path))))
  context$db_finish_run(con, newer_run)
  register <- function(arguments) run_submission_fixture_script(directory,
    c("--competition", "fixture-comp", arguments), script = "158_register_submission_result.R")
  first <- register(c("--public-score", "0.91", "--private-score", "0.90"))
  expect_null(attr(first, "status"), info = paste(first, collapse = "\n"))
  row <- DBI::dbGetQuery(con, "SELECT subm_mconf_id, subm_public_score, subm_private_score FROM submission_result")
  expect_identical(row$subm_mconf_id, fixture$model_id)
  expect_false(row$subm_mconf_id == newer_model)
  second <- run_submission_fixture_script(directory, c("--private-score", "0.92"),
    script = "158_register_submission_result.R")
  expect_null(attr(second, "status"), info = paste(second, collapse = "\n"))
  row <- DBI::dbGetQuery(con, "SELECT subm_public_score, subm_private_score, subm_manifest_json FROM submission_result")
  expect_equal(row$subm_public_score, 0.91)
  expect_equal(row$subm_private_score, 0.92)
  expect_identical(DBI::dbGetQuery(con, "SELECT subm_competition FROM submission_result")$subm_competition, "fixture-comp")
  expect_equal(jsonlite::fromJSON(row$subm_manifest_json)$submission$public_score, 0.91)
  events <- context$db_list_submission_events(con, "submission-fixture")
  expect_equal(nrow(events), 2L)
  expect_equal(as.numeric(events$private_score), c(0.90, 0.92))
  expect_true(all(events$mconf_id == fixture$model_id))
  expect_equal(nrow(context$db_list_submission_candidates(con, "submission-fixture")), 1L)
  expect_equal(nrow(context$db_list_submission_candidates(con, "different-project")), 0L)
  conflict <- run_submission_fixture_script(directory, c("--competition", "different-comp", "--public-score", "0.99"),
    script = "158_register_submission_result.R")
  expect_equal(attr(conflict, "status"), 1L)
  expect_equal(nrow(context$db_list_submission_events(con, "submission-fixture")), 2L)
  # The newer artifact has the same predictions; a real validation makes the SHA ambiguous.
  validated <- run_submission_fixture_script(directory, "--validate-only")
  expect_null(attr(validated, "status"), info = paste(validated, collapse = "\n"))
  ambiguous <- register(c("--public-score", "0.93"))
  expect_equal(attr(ambiguous, "status"), 1L)
  expect_true(any(grepl("multiple models", ambiguous)))
  explicit <- register(c("--mconf-id", fixture$model_id, "--public-score", "0.93"))
  expect_null(attr(explicit, "status"), info = paste(explicit, collapse = "\n"))
  expect_equal(nrow(context$db_list_submission_events(con, "submission-fixture")), 3L)
  expect_equal(DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM submission_result")$n, 1L)
  wrong_model <- register(c("--model-name", "lightgbm", "--public-score", "0.94"))
  expect_equal(attr(wrong_model, "status"), 1L)
  typo <- register(c("--mconf-idd", fixture$model_id, "--public-score", "0.94"))
  expect_equal(attr(typo, "status"), 1L)
  expect_true(any(grepl("Unknown registration argument", typo)))
  submission <- fread(path)
  submission$outcome <- 1 - submission$outcome
  fwrite(submission, path)
  tampered <- register(c("--mconf-id", fixture$model_id, "--public-score", "0.99"))
  expect_equal(attr(tampered, "status"), 1L)
  expect_true(any(grepl("No validated candidate", tampered)))
  writeBin(original_bytes, path)
  saveRDS(list(tampered = TRUE), file.path(directory, "_artifacts", "model.rds"))
  changed_model <- register(c("--mconf-id", fixture$model_id, "--public-score", "0.99"))
  expect_equal(attr(changed_model, "status"), 1L)
  expect_true(any(grepl("Pinned model hash differs", changed_model)))
  expect_equal(nrow(context$db_list_submission_events(con, "submission-fixture")), 3L)
  expect_equal(DBI::dbGetQuery(con, "SELECT subm_public_score FROM submission_result")$subm_public_score, 0.93)
})
