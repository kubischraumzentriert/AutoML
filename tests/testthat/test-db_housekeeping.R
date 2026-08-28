# =====================================================================
# test-db_housekeeping.R -- Korrektheitstests fuer discover_source_db_paths()/
# db_housekeeping_check() (db_housekeeping.R).
# =====================================================================
assign("project_dir", testthat::test_path("..", ".."), envir = globalenv())
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(data.table) })
source(testthat::test_path("..", "..", "db_logging.R")) # db_connect() baut das Schema aus db_schema.sql auf
source(testthat::test_path("..", "..", "db_housekeeping.R"))

# db_connect() aus db_logging.R statt eines eigenen SQL-Parsers - testet
# gegen das REALE Schema, nicht gegen eine vereinfachte Testkopie, die
# stillschweigend veralten koennte.
make_schema_db <- function() {
  path <- tempfile(fileext = ".sqlite")
  con <- db_connect(path)
  list(con = con, path = path)
}

seed_project <- function(con, proj_name, git_commit = "abc123", finished = TRUE) {
  proj_id <- db_get_or_create_project(con, proj_name)
  wf_id <- db_get_or_create_workflow(con, proj_id, "script", "test_workflow")
  run_id <- db_create_run(con, wf_id, seed = 1, git_commit = git_commit)
  if (finished) db_finish_run(con, run_id)
  list(proj_id = proj_id, wf_id = wf_id, run_id = run_id)
}

test_that("discover_source_db_paths() findet experiments.db unter _artifacts, schliesst target und exclude_dirs aus", {
  root <- tempfile()
  dir.create(file.path(root, "projA", "_artifacts"), recursive = TRUE)
  dir.create(file.path(root, "projB", "_artifacts"), recursive = TRUE)
  dir.create(file.path(root, "MLR3_Classifikation", "_artifacts"), recursive = TRUE)
  file.create(file.path(root, "projA", "_artifacts", "experiments.db"))
  file.create(file.path(root, "projB", "_artifacts", "experiments.db"))
  target <- file.path(root, "MLR3_Classifikation", "_artifacts", "experiments.db")
  file.create(target)

  found <- discover_source_db_paths(root, exclude = "MLR3_Classifikation", target = target)
  expect_setequal(names(found), c("projA", "projB"))
})

test_that("db_housekeeping_check() erkennt ein fehlendes (noch nie gemergtes) Projekt", {
  target <- make_schema_db()
  on.exit(dbDisconnect(target$con))
  seed_project(target$con, "known-project")

  res <- db_housekeeping_check(target = target$path, sources = c("known-project" = target$path, "new-project" = target$path))
  expect_equal(res$missing_projects$project, "new-project")
})

test_that("db_housekeeping_check() erkennt unvollstaendige Runs (run_finished_at IS NULL)", {
  target <- make_schema_db()
  on.exit(dbDisconnect(target$con))
  seed_project(target$con, "proj-ok", finished = TRUE)
  seed_project(target$con, "proj-broken", finished = FALSE)

  res <- db_housekeeping_check(target = target$path, sources = character(0))
  expect_equal(res$incomplete_runs$proj_name, "proj-broken")
})

test_that("db_housekeeping_check() erkennt Runs ohne Git Commit (NULL oder leer)", {
  target <- make_schema_db()
  on.exit(dbDisconnect(target$con))
  seed_project(target$con, "proj-with-commit", git_commit = "deadbeef")
  seed_project(target$con, "proj-without-commit", git_commit = NA_character_)

  res <- db_housekeeping_check(target = target$path, sources = character(0))
  expect_equal(res$runs_without_commit$proj_name, "proj-without-commit")
})

test_that("db_housekeeping_check() erkennt doppelte metric_result-Zeilen fuer dieselbe Model-Config/Metrik/Fold", {
  target <- make_schema_db()
  on.exit(dbDisconnect(target$con))
  ids <- seed_project(target$con, "proj-dup")
  mconf_id <- db_create_model_config(target$con, ids$run_id, task_type = "classif", algorithm = "ranger")
  rsmp_id <- db_create_resampling(target$con, ids$run_id, strategy = "holdout", ratio = 0.8, seed = 1)
  db_log_metric_result(target$con, mconf_id, rsmp_id, "classif.bacc", 0.8)
  db_log_metric_result(target$con, mconf_id, rsmp_id, "classif.bacc", 0.81) # Duplikat derselben Kombination

  res <- db_housekeeping_check(target = target$path, sources = character(0))
  expect_equal(nrow(res$duplicate_metrics), 1)
  expect_equal(res$duplicate_metrics$n, 2)
})

test_that("db_housekeeping_check() meldet keine Befunde bei einer sauberen DB", {
  target <- make_schema_db()
  on.exit(dbDisconnect(target$con))
  seed_project(target$con, "clean-project")

  res <- db_housekeeping_check(target = target$path, sources = c("clean-project" = target$path))
  expect_equal(nrow(res$missing_projects), 0)
  expect_equal(nrow(res$incomplete_runs), 0)
  expect_equal(nrow(res$runs_without_commit), 0)
  expect_equal(nrow(res$duplicate_metrics), 0)
})

test_that("db_housekeeping_check() zaehlt die Ziel-DB selbst NIE als eigenes Backup (Pfad ohne .db-Endung)", {
  target <- make_schema_db() # tempfile(fileext = ".sqlite"), absichtlich KEINE .db-Endung
  on.exit(dbDisconnect(target$con))
  seed_project(target$con, "proj-no-db-suffix")

  res <- db_housekeeping_check(target = target$path, sources = character(0))
  expect_equal(nrow(res$backups), 0)
})

test_that("db_housekeeping_check() bricht bei fehlender Ziel-DB mit verstaendlicher Fehlermeldung ab", {
  expect_error(db_housekeeping_check(target = tempfile()), "Ziel-DB nicht gefunden")
})

test_that("db_housekeeping_check() schreibt NIE in die Ziel-DB (read-only erzwungen)", {
  target <- make_schema_db()
  on.exit(dbDisconnect(target$con))
  seed_project(target$con, "proj-readonly-check")

  db_housekeeping_check(target = target$path, sources = character(0))

  # Nach dem Check muss die DB weiterhin schreibbar UND inhaltlich
  # unveraendert sein - ein Beweis, dass der Read-Only-Connect keine
  # Seiteneffekte auf die Datei selbst hinterlassen hat.
  n_projects_before <- dbGetQuery(target$con, "SELECT COUNT(*) AS n FROM project")$n
  db_housekeeping_check(target = target$path, sources = character(0))
  n_projects_after <- dbGetQuery(target$con, "SELECT COUNT(*) AS n FROM project")$n
  expect_equal(n_projects_before, n_projects_after)
})

# --- detect_problem_type()/discover_source_db_paths_by_type() (DB-Domain-
# Trennung, siehe BACKLOG.md "Naechste Bewertung 2026-08-28") -------------

seed_metric <- function(con, proj_name, measure_name) {
  ids <- seed_project(con, proj_name)
  mconf_id <- db_create_model_config(con, ids$run_id, task_type = "classif", algorithm = "ranger")
  rsmp_id <- db_create_resampling(con, ids$run_id, strategy = "holdout", ratio = 0.8, seed = 1)
  db_log_metric_result(con, mconf_id, rsmp_id, measure_name, 0.8)
  ids
}

test_that("detect_problem_type() erkennt classification/regression/mixed/unknown korrekt", {
  db_classif <- make_schema_db(); on.exit(dbDisconnect(db_classif$con), add = TRUE)
  seed_metric(db_classif$con, "p", "classif.bacc")
  expect_equal(detect_problem_type(db_classif$path), "classification")

  db_regr <- make_schema_db(); on.exit(dbDisconnect(db_regr$con), add = TRUE)
  seed_metric(db_regr$con, "p", "regr.rmse")
  expect_equal(detect_problem_type(db_regr$path), "regression")

  db_mixed <- make_schema_db(); on.exit(dbDisconnect(db_mixed$con), add = TRUE)
  ids <- seed_project(db_mixed$con, "p")
  mconf_id <- db_create_model_config(db_mixed$con, ids$run_id, task_type = "classif", algorithm = "ranger")
  rsmp_id <- db_create_resampling(db_mixed$con, ids$run_id, strategy = "holdout", ratio = 0.8, seed = 1)
  db_log_metric_result(db_mixed$con, mconf_id, rsmp_id, "classif.bacc", 0.8)
  db_log_metric_result(db_mixed$con, mconf_id, rsmp_id, "regr.rmse", 1.2)
  expect_equal(detect_problem_type(db_mixed$path), "mixed")

  db_unknown <- make_schema_db(); on.exit(dbDisconnect(db_unknown$con), add = TRUE)
  # Analog zum realen Fund bei openml-yeast-multilabel: nur ein fachfremder
  # Sanity-Probe-Wert geloggt, keine classif.*/regr.*-Zeile.
  seed_metric(db_unknown$con, "p", "weather_balloon_relative_slope")
  expect_equal(detect_problem_type(db_unknown$path), "unknown")

  expect_true(is.na(detect_problem_type(tempfile())))
})

test_that("discover_source_db_paths_by_type() schliesst NUR positiv erkannte Gegentypen aus, nicht 'unknown'", {
  # Realer Anlass fuer diesen Test (siehe BACKLOG.md): ein erster
  # Testlauf schloss echte Multi-Label-Classification-Projekte
  # faelschlich als 'unknown' aus, weil deren metric_result-Tabelle nur
  # einen fachfremden Sanity-Wert enthielt - ein falsch-negativer
  # Ausschluss (echtes Projekt verloren) ist schlimmer als ein zu
  # vorsichtiger Einschluss.
  root <- tempfile()
  target <- file.path(root, "MLR3_Classifikation", "_artifacts", "experiments.db")
  dir.create(dirname(target), recursive = TRUE)
  target_con <- db_connect(target)
  dbDisconnect(target_con)

  make_project_db <- function(name, measure_name) {
    dir.create(file.path(root, name, "_artifacts"), recursive = TRUE)
    path <- file.path(root, name, "_artifacts", "experiments.db")
    con <- db_connect(path)
    if (!is.na(measure_name)) seed_metric(con, name, measure_name)
    dbDisconnect(con)
  }
  make_project_db("proj-classif", "classif.bacc")
  make_project_db("proj-regr", "regr.rmse")
  make_project_db("proj-unknown", "weather_balloon_relative_slope")

  res <- discover_source_db_paths_by_type(root, exclude = "MLR3_Classifikation", target = target, expected_type = "classification")
  expect_setequal(names(res), c("proj-classif", "proj-unknown"))
  expect_equal(attr(res, "excluded")$project, "proj-regr")
  expect_equal(attr(res, "needs_review")$project, "proj-unknown")
})
