library(testthat)
source(testthat::test_path("..", "..", "modules", "db_housekeeping.R"))
source(testthat::test_path("..", "..", "modules", "merge_project_experiments_helpers.R"))
source(testthat::test_path("..", "..", "db_logging.R"))

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

test_that("SQLite snapshot contains rows visible through WAL", {
  source_path <- tempfile(fileext = ".db")
  snapshot_path <- NULL
  source_con <- DBI::dbConnect(RSQLite::SQLite(), source_path)
  on.exit({
    if (DBI::dbIsValid(source_con)) DBI::dbDisconnect(source_con)
    if (!is.null(snapshot_path)) unlink(snapshot_path, force = TRUE)
    unlink(c(source_path, paste0(source_path, "-wal"), paste0(source_path, "-shm")), force = TRUE)
  }, add = TRUE)
  DBI::dbExecute(source_con, "CREATE TABLE values_table (id TEXT PRIMARY KEY, value INTEGER)")
  DBI::dbExecute(source_con, "PRAGMA journal_mode = WAL")
  DBI::dbExecute(source_con, "INSERT INTO values_table (id, value) VALUES ('wal-row', 42)")

  snapshot_path <- create_sqlite_snapshot(source_path)
  snapshot_con <- DBI::dbConnect(RSQLite::SQLite(), snapshot_path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(snapshot_con), add = TRUE)
  expect_equal(DBI::dbGetQuery(snapshot_con, "SELECT value FROM values_table WHERE id = 'wal-row'")$value, 42)
})

test_that("merge reruns are idempotent and pull later source runs", {
  root <- normalizePath(testthat::test_path("..", ".."), winslash = "/")
  workspace <- tempfile(pattern = "merge-workspace-")
  source_dir <- file.path(workspace, "merge-source")
  source_path <- file.path(source_dir, "_artifacts", "experiments.db")
  target_path <- file.path(workspace, "merge-target", "_artifacts", "experiments.db")
  dir.create(dirname(source_path), recursive = TRUE)
  dir.create(dirname(target_path), recursive = TRUE)
  on.exit(unlink(workspace, recursive = TRUE, force = TRUE), add = TRUE)

  source_con <- db_connect(source_path, project_dir = root)
  project_id <- db_get_or_create_project(source_con, "merge-fixture")
  workflow_id <- db_get_or_create_workflow(source_con, project_id, "script", "fixture")
  first_run <- db_create_run(source_con, workflow_id, seed = 1L, log_baseline_provenance = FALSE)
  db_finish_run(source_con, first_run)
  dbDisconnect(source_con)
  target_con <- db_connect(target_path, project_dir = root)
  dbDisconnect(target_con)

  run_merge <- function() {
    executable <- file.path(R.home("bin"), if (.Platform$OS.type == "windows") "Rscript.exe" else "Rscript")
    previous_directory <- getwd()
    on.exit(setwd(previous_directory), add = TRUE)
    env_names <- c(
      "AUTOML_MERGE_TEMPLATE_ROOT",
      "AUTOML_MERGE_TARGET_DB_PATH",
      "AUTOML_MERGE_PROJECT_ROOTS"
    )
    previous_env <- Sys.getenv(env_names, unset = NA_character_)
    on.exit({
      for (name in env_names) {
        if (is.na(previous_env[[name]])) {
          Sys.unsetenv(name)
        } else {
          do.call(Sys.setenv, setNames(list(previous_env[[name]]), name))
        }
      }
    }, add = TRUE)
    setwd(root)
    Sys.setenv(
      AUTOML_MERGE_TEMPLATE_ROOT = root,
      AUTOML_MERGE_TARGET_DB_PATH = normalizePath(target_path, winslash = "/", mustWork = FALSE),
      AUTOML_MERGE_PROJECT_ROOTS = normalizePath(workspace, winslash = "/", mustWork = FALSE)
    )
    output <- system2(
      executable,
      "merge_project_experiments.R",
      stdout = TRUE,
      stderr = TRUE
    )
    expect_null(attr(output, "status"), info = paste(output, collapse = "\n"))
  }

  run_merge()
  target_con <- db_connect(target_path, project_dir = root)
  expect_equal(dbGetQuery(target_con, "SELECT COUNT(*) AS n FROM run")$n, 1L)
  dbDisconnect(target_con)

  run_merge()
  target_con <- db_connect(target_path, project_dir = root)
  expect_equal(dbGetQuery(target_con, "SELECT COUNT(*) AS n FROM run")$n, 1L)
  dbDisconnect(target_con)

  source_con <- db_connect(source_path, project_dir = root)
  second_run <- db_create_run(source_con, workflow_id, seed = 2L, log_baseline_provenance = FALSE)
  db_finish_run(source_con, second_run)
  dbDisconnect(source_con)
  run_merge()
  target_con <- db_connect(target_path, project_dir = root)
  expect_equal(dbGetQuery(target_con, "SELECT COUNT(*) AS n FROM run")$n, 2L)
  dbDisconnect(target_con)

  # Schema-Drift: eine aeltere Projekt-DB ohne run_manifest_json muss trotzdem
  # mergen. Der Merge-Prozess endet auch bei zurueckgerolltem Fehler mit
  # Exit-Code 0 -> nur die Zeilenzahl im Ziel entlarvt einen stillen Ausfall.
  drift_path <- file.path(workspace, "merge-drift-source", "_artifacts", "experiments.db")
  dir.create(dirname(drift_path), recursive = TRUE)
  drift_con <- db_connect(drift_path, project_dir = root)
  drift_project <- db_get_or_create_project(drift_con, "merge-drift-fixture")
  drift_workflow <- db_get_or_create_workflow(drift_con, drift_project, "script", "fixture")
  drift_run <- db_create_run(drift_con, drift_workflow, seed = 3L, log_baseline_provenance = FALSE)
  db_finish_run(drift_con, drift_run)
  for (view_name in dbGetQuery(drift_con, "SELECT name FROM sqlite_master WHERE type = 'view'")$name) {
    dbExecute(drift_con, paste0("DROP VIEW ", view_name))
  }
  dbExecute(drift_con, "ALTER TABLE run DROP COLUMN run_manifest_json")
  dbDisconnect(drift_con)
  run_merge()
  target_con <- db_connect(target_path, project_dir = root)
  expect_equal(
    dbGetQuery(target_con, "SELECT COUNT(*) AS n FROM run WHERE run_id = ?", params = list(drift_run))$n,
    1L
  )
  dbDisconnect(target_con)
})
