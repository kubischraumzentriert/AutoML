# =====================================================================
# test-experiment_planner.R -- Korrektheitstests fuer db_plan_experiment()/
# db_start_experiment()/db_complete_experiment()/db_close_experiment()/
# report_planned_experiments() (experiment_planner.R).
# =====================================================================
assign("project_dir", testthat::test_path("..", ".."), envir = globalenv())
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source(testthat::test_path("..", "..", "db_logging.R")) # db_connect() baut das Schema aus db_schema.sql auf
source(testthat::test_path("..", "..", "modules", "experiment_planner.R"))

make_schema_db <- function() {
  con <- db_connect(tempfile(fileext = ".sqlite"))
  proj_id <- db_get_or_create_project(con, paste0("test-proj-", uuid::UUIDgenerate()))
  list(con = con, proj_id = proj_id)
}

test_that("db_plan_experiment() legt einen neuen Eintrag mit Status 'planned' an", {
  db <- make_schema_db()
  on.exit(dbDisconnect(db$con))

  pexp_id <- db_plan_experiment(db$con, db$proj_id, "090_ranger_tuning @ full",
                                 script = "090_ranger_tuning.R", config_hash = "hash-a")
  row <- dbGetQuery(db$con, "SELECT * FROM planned_experiment WHERE pexp_id = ?", params = list(pexp_id))
  expect_equal(nrow(row), 1)
  expect_equal(row$pexp_status, "planned")
  expect_equal(row$pexp_config_hash, "hash-a")
})

test_that("db_plan_experiment() ist idempotent ueber (proj_id, label) - kein Duplikat bei erneutem Aufruf", {
  db <- make_schema_db()
  on.exit(dbDisconnect(db$con))

  id1 <- db_plan_experiment(db$con, db$proj_id, "label-x", config_hash = "hash-a")
  id2 <- db_plan_experiment(db$con, db$proj_id, "label-x", config_hash = "hash-a")
  expect_equal(id1, id2)
  n <- dbGetQuery(db$con, "SELECT COUNT(*) AS n FROM planned_experiment WHERE pexp_proj_id = ?", params = list(db$proj_id))$n
  expect_equal(n, 1)
})

test_that("kompletter Lebenszyklus: planned -> running -> done", {
  db <- make_schema_db()
  on.exit(dbDisconnect(db$con))
  wf_id <- db_get_or_create_workflow(db$con, db$proj_id, "script", "wf")
  run_id <- db_create_run(db$con, wf_id, log_baseline_provenance = FALSE)

  pexp_id <- db_plan_experiment(db$con, db$proj_id, "label-y", config_hash = "hash-a")
  db_start_experiment(db$con, pexp_id)
  status_running <- dbGetQuery(db$con, "SELECT pexp_status FROM planned_experiment WHERE pexp_id = ?", params = list(pexp_id))$pexp_status
  expect_equal(status_running, "running")

  db_complete_experiment(db$con, pexp_id, run_id)
  row <- dbGetQuery(db$con, "SELECT pexp_status, pexp_run_id FROM planned_experiment WHERE pexp_id = ?", params = list(pexp_id))
  expect_equal(row$pexp_status, "done")
  expect_equal(row$pexp_run_id, run_id)
})

test_that("db_plan_experiment() markiert einen 'done'-Eintrag als 'stale', wenn sich der Config-Hash aendert", {
  db <- make_schema_db()
  on.exit(dbDisconnect(db$con))
  wf_id <- db_get_or_create_workflow(db$con, db$proj_id, "script", "wf")
  run_id <- db_create_run(db$con, wf_id, log_baseline_provenance = FALSE)

  pexp_id <- db_plan_experiment(db$con, db$proj_id, "090_ranger_tuning @ full", config_hash = "hash-10pct")
  db_complete_experiment(db$con, pexp_id, run_id)

  # Simuliert den s6e9-Fall: dieselbe Label, aber die Konfiguration hat sich
  # geaendert (10%-Subset -> volle Daten), ohne dass ein neuer Run erfolgt
  # ist - db_plan_experiment() muss das erkennen.
  db_plan_experiment(db$con, db$proj_id, "090_ranger_tuning @ full", config_hash = "hash-full")

  row <- dbGetQuery(db$con, "SELECT pexp_status, pexp_config_hash FROM planned_experiment WHERE pexp_id = ?", params = list(pexp_id))
  expect_equal(row$pexp_status, "stale")
  expect_equal(row$pexp_config_hash, "hash-full")
})

test_that("db_plan_experiment() bleibt 'done', wenn sich der Config-Hash NICHT aendert", {
  db <- make_schema_db()
  on.exit(dbDisconnect(db$con))
  wf_id <- db_get_or_create_workflow(db$con, db$proj_id, "script", "wf")
  run_id <- db_create_run(db$con, wf_id, log_baseline_provenance = FALSE)

  pexp_id <- db_plan_experiment(db$con, db$proj_id, "label-z", config_hash = "hash-a")
  db_complete_experiment(db$con, pexp_id, run_id)
  db_plan_experiment(db$con, db$proj_id, "label-z", config_hash = "hash-a")

  status <- dbGetQuery(db$con, "SELECT pexp_status FROM planned_experiment WHERE pexp_id = ?", params = list(pexp_id))$pexp_status
  expect_equal(status, "done")
})

test_that("db_plan_experiment() lehnt eine ungueltige priority ab", {
  db <- make_schema_db()
  on.exit(dbDisconnect(db$con))
  expect_error(
    db_plan_experiment(db$con, db$proj_id, "label-bad", priority = "urgent"),
    "priority"
  )
})

test_that("db_close_experiment() setzt 'failed'/'skipped' korrekt, inkl. Notizen", {
  db <- make_schema_db()
  on.exit(dbDisconnect(db$con))

  pexp_id <- db_plan_experiment(db$con, db$proj_id, "label-fail")
  db_close_experiment(db$con, pexp_id, "failed", notes = "OOM")
  row <- dbGetQuery(db$con, "SELECT pexp_status, pexp_notes FROM planned_experiment WHERE pexp_id = ?", params = list(pexp_id))
  expect_equal(row$pexp_status, "failed")
  expect_equal(row$pexp_notes, "OOM")

  pexp_id2 <- db_plan_experiment(db$con, db$proj_id, "label-skip")
  db_close_experiment(db$con, pexp_id2, "skipped")
  status2 <- dbGetQuery(db$con, "SELECT pexp_status FROM planned_experiment WHERE pexp_id = ?", params = list(pexp_id2))$pexp_status
  expect_equal(status2, "skipped")
})

test_that("report_planned_experiments() liefert nur offene Eintraege (planned/stale/running), sortiert nach Prioritaet", {
  db <- make_schema_db()
  on.exit(dbDisconnect(db$con))
  wf_id <- db_get_or_create_workflow(db$con, db$proj_id, "script", "wf")
  run_id <- db_create_run(db$con, wf_id, log_baseline_provenance = FALSE)

  id_done <- db_plan_experiment(db$con, db$proj_id, "label-done", priority = "high")
  db_complete_experiment(db$con, id_done, run_id)
  db_plan_experiment(db$con, db$proj_id, "label-low", priority = "low")
  db_plan_experiment(db$con, db$proj_id, "label-high", priority = "high")

  pending <- suppressWarnings(capture.output(res <- report_planned_experiments(db$con)))
  expect_equal(nrow(res), 2)
  expect_setequal(res$pexp_label, c("label-low", "label-high"))
  expect_equal(res$pexp_label[1], "label-high") # hohe Prioritaet zuerst
})

test_that("report_planned_experiments() filtert per proj_name, wenn angegeben", {
  db <- make_schema_db()
  on.exit(dbDisconnect(db$con))
  other_proj_id <- db_get_or_create_project(db$con, paste0("other-proj-", uuid::UUIDgenerate()))

  db_plan_experiment(db$con, db$proj_id, "label-mine")
  db_plan_experiment(db$con, other_proj_id, "label-other")

  this_proj_name <- dbGetQuery(db$con, "SELECT proj_name FROM project WHERE proj_id = ?", params = list(db$proj_id))$proj_name
  invisible(capture.output(res <- report_planned_experiments(db$con, proj_name = this_proj_name)))
  expect_equal(res$pexp_label, "label-mine")
})
