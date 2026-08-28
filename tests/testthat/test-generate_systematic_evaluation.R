# =====================================================================
# test-generate_systematic_evaluation.R -- Korrektheitstests fuer
# build_systematic_evaluation_pivot()/render_systematic_evaluation_markdown()/
# generate_systematic_evaluation_file() (generate_systematic_evaluation.R).
# =====================================================================
assign("project_dir", testthat::test_path("..", ".."), envir = globalenv())
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(data.table) })
source(testthat::test_path("..", "..", "db_logging.R"))
source(testthat::test_path("..", "..", "evidence_registry.R"))
source(testthat::test_path("..", "..", "generate_systematic_evaluation.R"))

make_test_db <- function() {
  path <- tempfile(fileext = ".sqlite")
  con <- db_connect(path)
  list(con = con, path = path)
}

test_that("build_systematic_evaluation_pivot() liefert leere data.table bei leerer Registry", {
  db <- make_test_db(); on.exit(dbDisconnect(db$con))
  pivot <- build_systematic_evaluation_pivot(db$con)
  expect_equal(nrow(pivot), 0)
})

test_that("build_systematic_evaluation_pivot() pivotiert Projekt x Modul korrekt mit Legenden-Symbol", {
  db <- make_test_db(); on.exit(dbDisconnect(db$con))
  db_log_evidence(db$con, project = "projA", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed", notes = "unauffaellig")
  db_log_evidence(db$con, project = "projA", module = "130_threshold_tuning", role = "score_lever", status = "core_finding")
  db_log_evidence(db$con, project = "projB", module = "015_target_leak_audit", role = "trust_gate", status = "negative")

  pivot <- build_systematic_evaluation_pivot(db$con)
  expect_setequal(pivot$evid_project, c("projA", "projB"))

  rowA <- pivot[evid_project == "projA"]
  expect_equal(rowA[["015_target_leak_audit"]], "✓ (unauffaellig)")
  expect_equal(rowA[["130_threshold_tuning"]], "✓✓")

  rowB <- pivot[evid_project == "projB"]
  expect_equal(rowB[["015_target_leak_audit"]], "✗")
  # projB hat keinen Eintrag fuer dieses Modul - dcast() mit fun.aggregate
  # liefert dafuer "" (nicht NA), render_systematic_evaluation_markdown()
  # behandelt beides gleich (siehe eigener Test dafuer).
  expect_true(is.na(rowB[["130_threshold_tuning"]]) || !nzchar(rowB[["130_threshold_tuning"]]))
})

test_that("build_systematic_evaluation_pivot() fasst mehrere Eintraege fuer dieselbe (Projekt, Modul)-Kombination zusammen statt sie zu ueberschreiben", {
  db <- make_test_db(); on.exit(dbDisconnect(db$con))
  db_log_evidence(db$con, project = "projA", module = "outer_workflow_evaluation", role = "trust_gate", status = "confirmed", notes = "Lauf 1")
  db_log_evidence(db$con, project = "projA", module = "outer_workflow_evaluation", role = "trust_gate", status = "negative", notes = "Lauf 2")

  pivot <- build_systematic_evaluation_pivot(db$con)
  cell <- pivot[["outer_workflow_evaluation"]][1]
  expect_match(cell, "Lauf 1")
  expect_match(cell, "Lauf 2")
  expect_match(cell, ";") # beide Eintraege sichtbar, keiner geht verloren
})

test_that("render_systematic_evaluation_markdown() erzeugt eine gueltige Markdown-Tabelle mit bekannten Spalten zuerst", {
  db <- make_test_db(); on.exit(dbDisconnect(db$con))
  db_log_evidence(db$con, project = "projZ", module = "zzz_custom_module", role = "documentation", status = "open")
  db_log_evidence(db$con, project = "projZ", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed")

  md <- render_systematic_evaluation_markdown(db$con)
  expect_match(md, "\\| Projekt \\|")
  expect_match(md, "`projZ`")
  # Bekanntes Modul (015_...) muss VOR dem unbekannten (zzz_...) stehen.
  pos_known <- regexpr("015_target_leak_audit", md)
  pos_unknown <- regexpr("zzz_custom_module", md)
  expect_true(pos_known < pos_unknown)
})

test_that("render_systematic_evaluation_markdown() liefert einen Hinweistext statt einer leeren Tabelle bei leerer Registry", {
  db <- make_test_db(); on.exit(dbDisconnect(db$con))
  md <- render_systematic_evaluation_markdown(db$con)
  expect_match(md, "Keine Eintraege")
})

test_that("generate_systematic_evaluation_file() schreibt eine lesbare Datei an den angegebenen Pfad", {
  db <- make_test_db(); on.exit(dbDisconnect(db$con))
  db_log_evidence(db$con, project = "projA", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed")

  out_path <- tempfile(fileext = ".md")
  result_path <- generate_systematic_evaluation_file(db$con, out_path = out_path)
  expect_equal(result_path, out_path)
  expect_true(file.exists(out_path))
  content <- readLines(out_path)
  expect_true(any(grepl("projA", content)))
})
