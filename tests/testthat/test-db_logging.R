# =====================================================================
# test-db_logging.R -- Korrektheitstests fuer db_logging.R.
# =====================================================================
# db_connect() haengt von `project_dir` (fuer db_schema.sql) ab - vor dem
# Sourcen gesetzt, damit auch db_connect() selbst (nicht nur die spaeteren
# Aufrufe) korrekt funktioniert. Jeder Test bekommt eine eigene, frische
# Datei-DB (kein :memory: - dbConnect(RSQLite::SQLite(), ":memory:") wuerde
# theoretisch auch gehen, aber Datei-basiert spiegelt den echten
# Produktionspfad naeher, siehe db_connect()s WAL-Pragma).
# In globalenv() gesetzt (nicht nur lokal im Testfile), weil db_connect()
# `project_dir` als freie Variable ueber seine Definitionsumgebung aufloest
# (source() ohne local=TRUE definiert die Funktion in .GlobalEnv) - ein
# testthat-sandboxed lokales `project_dir <-` waere fuer die Funktion selbst
# unsichtbar.
assign("project_dir", testthat::test_path("..", ".."), envir = globalenv())
suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
source(testthat::test_path("..", "..", "db_logging.R"))

make_test_db <- function() {
  path <- tempfile(fileext = ".sqlite")
  con <- db_connect(path)
  list(con = con, path = path)
}

# --- is_threshold_independent_metric(): rein, kein DB-Zugriff --------------

test_that("is_threshold_independent_metric() erkennt Rangfolge-/Kalibrierungs-Metriken", {
  expect_true(is_threshold_independent_metric("classif.auc"))
  expect_true(is_threshold_independent_metric("classif.logloss"))
  expect_false(is_threshold_independent_metric("classif.bacc"))
  expect_false(is_threshold_independent_metric("classif.mcc"))
})

# --- warn_if_threshold_step_low_value(): rein (cat()-Ausgabe), aber haengt
# von der globalen `baseline_measure_ids` ab (wie 000_config.R sie setzt) -
# analog zu `project_dir` oben in globalenv() gesetzt, jeweils vor dem
# entsprechenden Testfall auf den zu pruefenden Fall umgestellt. Deckt die
# drei Zweige ab, die db_logging.R als Kalibrierungs-/Schwellenwert-Hinweis
# fuer Gewichtungs- vs. Post-hoc-Schwellenwert-Schritte unterscheidet (siehe
# REFERENZ_PROBABILITY_CALIBRATION.md fuer den theoretischen Hintergrund -
# diese Funktion ist der einzige TEMPLATE-CODE-Baustein dazu, das Dokument
# selbst ist explizit reine Referenz ohne Code-Aenderung).

test_that("warn_if_threshold_step_low_value() warnt bei einer Gewichtungsstufe UND kalibrierungssensitiver Metrik (LogLoss)", {
  assign("baseline_measure_ids", c("classif.logloss"), envir = globalenv())
  out <- capture.output(warn_if_threshold_step_low_value("105", "Klassengewichtung", is_weighting_step = TRUE))
  expect_true(any(grepl("kalibrierungssensitiv", out)))
})

test_that("warn_if_threshold_step_low_value() meldet 'wenig Effekt' bei einer reinen Rangfolge-Metrik (AUC), unabhaengig vom Schritt-Typ", {
  assign("baseline_measure_ids", c("classif.auc"), envir = globalenv())
  out_weighting <- capture.output(warn_if_threshold_step_low_value("105", "Klassengewichtung", is_weighting_step = TRUE))
  out_threshold <- capture.output(warn_if_threshold_step_low_value("130", "Schwellenwert-Tuning", is_weighting_step = FALSE))
  # AUC ist schwellenwertunabhaengig UND NICHT kalibrierungssensitiv -> in
  # BEIDEN Faellen "wenig/kein Effekt", nicht der Kalibrierungs-Sonderfall.
  expect_true(any(grepl("wenig/keinen Effekt", out_weighting)))
  expect_true(any(grepl("wenig/keinen Effekt", out_threshold)))
  expect_false(any(grepl("kalibrierungssensitiv", out_weighting)))
})

test_that("warn_if_threshold_step_low_value() meldet 'relevant' bei einer schwellenwertabhaengigen Metrik (BAcc)", {
  assign("baseline_measure_ids", c("classif.bacc"), envir = globalenv())
  out <- capture.output(warn_if_threshold_step_low_value("130", "Schwellenwert-Tuning", is_weighting_step = FALSE))
  expect_true(any(grepl("ist hier relevant", out)))
})

# --- db_connect()/Schema --------------------------------------------------

test_that("db_connect() legt eine funktionsfaehige DB mit dem erwarteten Schema an", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  tables <- dbListTables(db$con)
  expect_true(all(c("project", "workflow", "run", "model_config", "metric_result") %in% tables))
})

test_that("db_connect() ist idempotent (zweimaliges Verbinden auf denselben Pfad bricht nicht)", {
  path <- tempfile(fileext = ".sqlite")
  con1 <- db_connect(path)
  dbDisconnect(con1)
  con2 <- db_connect(path)  # CREATE TABLE IF NOT EXISTS darf nicht scheitern
  on.exit({ dbDisconnect(con2); unlink(path) })
  expect_true("project" %in% dbListTables(con2))
})

# --- get_or_create-Idempotenz ----------------------------------------------

test_that("db_get_or_create_project() gibt beim 2. Aufruf dieselbe ID zurueck, statt zu duplizieren", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  id1 <- db_get_or_create_project(db$con, "mein_projekt")
  id2 <- db_get_or_create_project(db$con, "mein_projekt")
  expect_identical(id1, id2)
  n <- dbGetQuery(db$con, "SELECT COUNT(*) AS n FROM project")$n
  expect_equal(n, 1)
})

test_that("db_get_or_create_workflow() gibt beim 2. Aufruf dieselbe ID zurueck, statt zu duplizieren", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  proj_id <- db_get_or_create_project(db$con, "p")
  wf1 <- db_get_or_create_workflow(db$con, proj_id, "script", "030_baseline.R")
  wf2 <- db_get_or_create_workflow(db$con, proj_id, "script", "030_baseline.R")
  expect_identical(wf1, wf2)
  n <- dbGetQuery(db$con, "SELECT COUNT(*) AS n FROM workflow")$n
  expect_equal(n, 1)
})

test_that("db_get_or_create_workflow() unterscheidet gleichnamige Workflows unterschiedlichen Typs", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  proj_id <- db_get_or_create_project(db$con, "p")
  wf_script <- db_get_or_create_workflow(db$con, proj_id, "script", "x")
  wf_targets <- db_get_or_create_workflow(db$con, proj_id, "targets", "x")
  expect_false(identical(wf_script, wf_targets))
})

# --- run/run_config/model_config/resampling/metric_result -----------------

test_that("db_create_run()/db_finish_run() setzen run_finished_at korrekt", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  proj_id <- db_get_or_create_project(db$con, "p")
  wf_id <- db_get_or_create_workflow(db$con, proj_id, "script", "s.R")
  run_id <- db_create_run(db$con, wf_id, seed = 42, git_commit = "abc123", notes = "test")

  before <- dbGetQuery(db$con, "SELECT run_finished_at FROM run WHERE run_id = ?", params = list(run_id))
  expect_true(is.na(before$run_finished_at[1]))

  db_finish_run(db$con, run_id)
  after <- dbGetQuery(db$con, "SELECT run_finished_at, run_seed, run_git_commit FROM run WHERE run_id = ?",
                       params = list(run_id))
  expect_false(is.na(after$run_finished_at[1]))
  expect_equal(after$run_seed[1], 42)
  expect_equal(after$run_git_commit[1], "abc123")
})

test_that("db_log_run_config() loggt jeden Eintrag als eigene Zeile", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  proj_id <- db_get_or_create_project(db$con, "p")
  wf_id <- db_get_or_create_workflow(db$con, proj_id, "script", "s.R")
  run_id <- db_create_run(db$con, wf_id)

  db_log_run_config(db$con, run_id, list(cv_folds = 5, seed = 42))
  rows <- dbGetQuery(db$con, "SELECT rconf_key, rconf_value FROM run_config WHERE rconf_run_id = ? ORDER BY rconf_key",
                      params = list(run_id))
  expect_equal(rows$rconf_key, c("cv_folds", "seed"))
  expect_equal(rows$rconf_value, c("5", "42"))
})

test_that("db_create_model_config() loggt die Model-Config UND ihre Hyperparameter", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  proj_id <- db_get_or_create_project(db$con, "p")
  wf_id <- db_get_or_create_workflow(db$con, proj_id, "script", "s.R")
  run_id <- db_create_run(db$con, wf_id)

  mconf_id <- db_create_model_config(
    db$con, run_id, task_type = "classif", algorithm = "ranger", feature_set = "raw",
    preprocessing = "impute_median_mode", class_weight_power = 1.5, task_id = "t1",
    hyperparams = list(num.trees = 200, mtry.ratio = 0.5)
  )
  mc <- dbGetQuery(db$con, "SELECT mconf_algorithm, mconf_class_weight_power FROM model_config WHERE mconf_id = ?",
                    params = list(mconf_id))
  expect_equal(mc$mconf_algorithm[1], "ranger")
  expect_equal(mc$mconf_class_weight_power[1], 1.5)

  hp <- dbGetQuery(db$con, "SELECT hparam_name, hparam_value FROM hyperparam WHERE hparam_mconf_id = ? ORDER BY hparam_name",
                    params = list(mconf_id))
  expect_equal(hp$hparam_name, c("mtry.ratio", "num.trees"))
  expect_equal(hp$hparam_value, c("0.5", "200"))
})

test_that("db_create_resampling()/db_log_metric_result() loggen korrekt verknuepft", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  proj_id <- db_get_or_create_project(db$con, "p")
  wf_id <- db_get_or_create_workflow(db$con, proj_id, "script", "s.R")
  run_id <- db_create_run(db$con, wf_id)
  mconf_id <- db_create_model_config(db$con, run_id, task_type = "classif", algorithm = "ranger")
  rsmp_id <- db_create_resampling(db$con, run_id, strategy = "cv", folds = 5, seed = 42)

  db_log_metric_result(db$con, mconf_id, rsmp_id, "classif.bacc", 0.87, fold = 1, elapsed_seconds = 3.2)
  row <- dbGetQuery(db$con, "SELECT mres_measure_name, mres_value, mres_fold FROM metric_result WHERE mres_mconf_id = ?",
                     params = list(mconf_id))
  expect_equal(row$mres_measure_name[1], "classif.bacc")
  expect_equal(row$mres_value[1], 0.87)
  expect_equal(row$mres_fold[1], 1)
})

# --- db_log_predictions(): pred_seq-Vergabe + prob-Entrollung --------------

test_that("db_log_predictions() vergibt fortlaufende pred_seq und entrollt die Wahrscheinlichkeitsmatrix korrekt", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  proj_id <- db_get_or_create_project(db$con, "p")
  wf_id <- db_get_or_create_workflow(db$con, proj_id, "script", "s.R")
  run_id <- db_create_run(db$con, wf_id)
  mconf_id <- db_create_model_config(db$con, run_id, task_type = "classif", algorithm = "ranger")
  rsmp_id <- db_create_resampling(db$con, run_id, strategy = "holdout", ratio = 0.8)

  prob_matrix <- matrix(c(0.9, 0.2, 0.1, 0.8), nrow = 2, dimnames = list(NULL, c("classA", "classB")))
  seqs <- db_log_predictions(
    db$con, mconf_id, rsmp_id, row_ids = c(10L, 11L),
    truth = c("classA", "classB"), response = c("classA", "classB"), prob_matrix = prob_matrix
  )
  expect_length(seqs, 2)
  expect_equal(seqs, sort(seqs))  # fortlaufend/aufsteigend

  preds <- dbGetQuery(db$con, "SELECT pred_row_id, pred_truth, pred_response FROM prediction ORDER BY pred_seq")
  expect_equal(preds$pred_row_id, c(10L, 11L))

  probs <- dbGetQuery(db$con, "SELECT pprob_pred_seq, pprob_class, pprob_value FROM prediction_prob ORDER BY pprob_pred_seq, pprob_class")
  expect_equal(nrow(probs), 4)  # 2 Zeilen x 2 Klassen
  row1_classA <- probs[probs$pprob_pred_seq == seqs[1] & probs$pprob_class == "classA", "pprob_value"]
  expect_equal(row1_classA, 0.9)
})

test_that("db_log_predictions() vergibt beim 2. Aufruf pred_seq OHNE Kollision mit dem 1.", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  proj_id <- db_get_or_create_project(db$con, "p")
  wf_id <- db_get_or_create_workflow(db$con, proj_id, "script", "s.R")
  run_id <- db_create_run(db$con, wf_id)
  mconf_id <- db_create_model_config(db$con, run_id, task_type = "classif", algorithm = "ranger")
  rsmp_id <- db_create_resampling(db$con, run_id, strategy = "holdout", ratio = 0.8)
  prob_matrix <- matrix(c(0.9, 0.1), nrow = 1, dimnames = list(NULL, c("classA", "classB")))

  seqs1 <- db_log_predictions(db$con, mconf_id, rsmp_id, row_ids = 1L, truth = "classA",
                               response = "classA", prob_matrix = prob_matrix)
  seqs2 <- db_log_predictions(db$con, mconf_id, rsmp_id, row_ids = 2L, truth = "classA",
                               response = "classA", prob_matrix = prob_matrix)
  expect_true(seqs2 > seqs1)
  n <- dbGetQuery(db$con, "SELECT COUNT(*) AS n FROM prediction")$n
  expect_equal(n, 2)
})

# --- db_log_submission_result(): Upsert-Verhalten --------------------------

test_that("db_log_submission_result() legt beim 1. Aufruf an, aktualisiert beim 2. (kein Duplikat)", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  proj_id <- db_get_or_create_project(db$con, "p")
  wf_id <- db_get_or_create_workflow(db$con, proj_id, "script", "s.R")
  run_id <- db_create_run(db$con, wf_id)
  mconf_id <- db_create_model_config(db$con, run_id, task_type = "classif", algorithm = "ranger")

  id1 <- db_log_submission_result(db$con, mconf_id, "kaggle", "comp1", "sub.csv", "submitted",
                                   "classif.bacc", public_score = 0.80)
  id2 <- db_log_submission_result(db$con, mconf_id, "kaggle", "comp1", "sub_v2.csv", "submitted",
                                   "classif.bacc", public_score = 0.85)
  expect_identical(id1, id2)  # kein neuer Eintrag, derselbe upgedatet

  rows <- dbGetQuery(db$con, "SELECT subm_public_score, subm_file_path FROM submission_result WHERE subm_mconf_id = ?",
                      params = list(mconf_id))
  expect_equal(nrow(rows), 1)
  expect_equal(rows$subm_public_score[1], 0.85)
  expect_equal(rows$subm_file_path[1], "sub_v2.csv")
})

# --- db_get_latest_model_artifact_path()/db_get_latest_model_config_id() --

test_that("db_get_latest_model_artifact_path() findet den Pfad des ZULETZT trainierten Modells", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  proj_id <- db_get_or_create_project(db$con, "p")
  wf_id <- db_get_or_create_workflow(db$con, proj_id, "script", "150_train_full_model.R")

  run_old <- db_create_run(db$con, wf_id)
  mconf_old <- db_create_model_config(db$con, run_old, task_type = "classif", algorithm = "ranger",
                                       hyperparams = list(model_artifact_path = "old_model.rds"))
  run_new <- db_create_run(db$con, wf_id)
  mconf_new <- db_create_model_config(db$con, run_new, task_type = "classif", algorithm = "ranger",
                                       hyperparams = list(model_artifact_path = "new_model.rds"))
  # run_started_at hat nur Sekundenaufloesung (datetime('now')) - explizit
  # auseinanderziehen, damit die "zuletzt trainiert"-Reihenfolge deterministisch
  # ist, statt sich auf Timing im Testlauf zu verlassen.
  dbExecute(db$con, "UPDATE run SET run_started_at = '2020-01-01T00:00:00' WHERE run_id = ?", params = list(run_old))
  dbExecute(db$con, "UPDATE run SET run_started_at = '2020-01-02T00:00:00' WHERE run_id = ?", params = list(run_new))

  path <- db_get_latest_model_artifact_path(db$con, "ranger", workflow_name = "150_train_full_model.R")
  expect_equal(path, "new_model.rds")

  latest_mconf <- db_get_latest_model_config_id(db$con, "ranger", workflow_name = "150_train_full_model.R")
  expect_equal(latest_mconf, mconf_new)
})

test_that("db_get_latest_model_artifact_path() gibt NA zurueck, wenn nichts geloggt ist", {
  db <- make_test_db()
  on.exit({ dbDisconnect(db$con); unlink(db$path) })
  expect_true(is.na(db_get_latest_model_artifact_path(db$con, "unbekannter_algorithmus")))
})
