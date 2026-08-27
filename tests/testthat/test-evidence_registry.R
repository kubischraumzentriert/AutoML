# =====================================================================
# test-evidence_registry.R -- Korrektheitstests fuer db_log_evidence()/
# evidence_registry_summary() (evidence_registry.R).
# =====================================================================
assign("project_dir", testthat::test_path("..", ".."), envir = globalenv())
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source(testthat::test_path("..", "..", "db_logging.R"))
source(testthat::test_path("..", "..", "evidence_registry.R"))

make_test_db <- function() {
  path <- tempfile(fileext = ".sqlite")
  con <- db_connect(path)
  list(con = con, path = path)
}

test_that("db_log_evidence() schreibt eine Zeile mit allen Feldern korrekt in die DB", {
  db <- make_test_db()
  on.exit(dbDisconnect(db$con))

  evid_id <- db_log_evidence(
    db$con,
    project = "health_condition", module = "outer_workflow_evaluation",
    role = "score_lever", status = "core_finding",
    dataset_type = "kaggle-tabular", metric = "classif.bacc",
    baseline_value = 0.8633, result_value = 0.9480, delta = 0.0847,
    runtime_seconds = 72.3, backport_status = "confirmed_prototype",
    evidence_source = "outer_workflow_evaluation.R", git_commit = "af154a0",
    notes = "P1.1-Prototyp, 3 Outer Folds"
  )

  row <- dbGetQuery(db$con, "SELECT * FROM evidence WHERE evid_id = ?", params = list(evid_id))
  expect_equal(nrow(row), 1)
  expect_equal(row$evid_project, "health_condition")
  expect_equal(row$evid_role, "score_lever")
  expect_equal(row$evid_status, "core_finding")
  expect_equal(row$evid_delta, 0.0847)
  expect_equal(row$evid_git_commit, "af154a0")
})

test_that("db_log_evidence() erlaubt optionale Felder als NA (Minimalaufruf)", {
  db <- make_test_db()
  on.exit(dbDisconnect(db$con))

  evid_id <- db_log_evidence(
    db$con, project = "s6e8", module = "tabm_diversity_check",
    role = "score_lever", status = "negative"
  )
  row <- dbGetQuery(db$con, "SELECT * FROM evidence WHERE evid_id = ?", params = list(evid_id))
  expect_equal(nrow(row), 1)
  expect_true(is.na(row$evid_metric))
  expect_true(is.na(row$evid_delta))
})

test_that("db_log_evidence() gibt verstaendliche Fehlermeldungen bei ungueltigem role/status", {
  db <- make_test_db()
  on.exit(dbDisconnect(db$con))

  expect_error(
    db_log_evidence(db$con, project = "x", module = "y", role = "nicht_existent", status = "open"),
    "role muss eine von"
  )
  expect_error(
    db_log_evidence(db$con, project = "x", module = "y", role = "score_lever", status = "nicht_existent"),
    "status muss eine von"
  )
  expect_error(
    db_log_evidence(db$con, project = "", module = "y", role = "score_lever", status = "open"),
    "project darf nicht leer sein"
  )
})

test_that("evidence_registry_summary() liest alle geloggten Befunde, neueste zuerst", {
  db <- make_test_db()
  on.exit(dbDisconnect(db$con))

  db_log_evidence(db$con, project = "a", module = "m1", role = "score_lever", status = "confirmed")
  Sys.sleep(1.1) # SQLite datetime('now') hat Sekundenaufloesung - Reihenfolge sonst nicht garantiert
  db_log_evidence(db$con, project = "b", module = "m2", role = "trust_gate", status = "open")

  summary_dt <- evidence_registry_summary(db$con)
  expect_equal(nrow(summary_dt), 2)
  expect_equal(summary_dt$evid_project[1], "b") # neuester Eintrag zuerst
  expect_true(data.table::is.data.table(summary_dt))
})
