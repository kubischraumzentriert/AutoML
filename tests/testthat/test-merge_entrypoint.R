library(testthat)
source(testthat::test_path("..", "..", "modules", "db_housekeeping.R"))

test_that("public merge entrypoint delegates to the canonical incremental implementation", {
  root <- normalizePath(testthat::test_path("..", ".."))
  entrypoint <- paste(readLines(file.path(root, "merge_project_experiments.R"), warn = FALSE), collapse = "\n")
  implementation <- paste(readLines(file.path(root, "modules", "merge_project_experiments.R"), warn = FALSE), collapse = "\n")

  expect_true(grepl("modules", entrypoint, fixed = TRUE))
  expect_true(grepl("merge_project_experiments.R", entrypoint, fixed = TRUE))
  expect_false(grepl("existing_projects", entrypoint, fixed = TRUE))
  expect_true(grepl("WHERE %s NOT IN", implementation, fixed = TRUE))
  expect_true(grepl("dbBegin(con)", implementation, fixed = TRUE))
  expect_true(grepl("discover_source_db_paths_by_type", implementation, fixed = TRUE))

  housekeeping <- paste(readLines(file.path(root, "modules", "db_housekeeping.R"), warn = FALSE), collapse = "\n")
  expect_true(grepl("AUTOML_MERGE_TARGET_DB_PATH", housekeeping, fixed = TRUE))
  expect_true(grepl("AUTOML_MERGE_PROJECT_ROOTS", housekeeping, fixed = TRUE))
  expect_false(grepl("C:/Users/HP/OneDrive/Dokumente/R_Workspace/MLR3_Classifikation/_artifacts/experiments.db", housekeeping, fixed = TRUE))
})

test_that("merge project roots accept semicolon-separated environment overrides", {
  old <- Sys.getenv("AUTOML_MERGE_PROJECT_ROOTS", unset = NA_character_)
  on.exit(if (is.na(old)) Sys.unsetenv("AUTOML_MERGE_PROJECT_ROOTS") else Sys.setenv(AUTOML_MERGE_PROJECT_ROOTS = old), add = TRUE)
  Sys.setenv(AUTOML_MERGE_PROJECT_ROOTS = "C:/one; C:/two;C:/one")
  expect_identical(merge_env_paths("AUTOML_MERGE_PROJECT_ROOTS"), c("C:/one", "C:/two"))
})
