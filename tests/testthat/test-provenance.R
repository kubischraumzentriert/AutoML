# =====================================================================
# test-provenance.R -- Korrektheitstests fuer sha256_file()/hash_value()/
# capture_run_provenance() (provenance.R).
# =====================================================================
source(testthat::test_path("..", "..", "provenance.R"))

test_that("sha256_file() liefert NA fuer NULL/nicht existierende Pfade, sonst einen stabilen Hash", {
  expect_true(is.na(sha256_file(NULL)))
  expect_true(is.na(sha256_file(tempfile()))) # existiert nicht

  f <- tempfile()
  writeLines("abc", f)
  h1 <- sha256_file(f)
  h2 <- sha256_file(f)
  expect_equal(h1, h2) # deterministisch bei gleichem Inhalt
  expect_match(h1, "^[0-9a-f]{64}$") # SHA256 = 64 Hex-Zeichen

  writeLines("anderer Inhalt", f)
  expect_false(sha256_file(f) == h1) # Aenderung am Inhalt aendert den Hash
})

test_that("hash_value() liefert NA fuer NULL, sonst einen von der Struktur abhaengigen Hash", {
  expect_true(is.na(hash_value(NULL)))
  expect_equal(hash_value(list(a = 1, b = 2)), hash_value(list(a = 1, b = 2)))
  expect_false(hash_value(list(a = 1, b = 2)) == hash_value(list(a = 1, b = 3)))
})

test_that("capture_run_provenance() ohne Argumente liefert nur R-Version/Pakete (alles andere 'nicht praktikabel')", {
  prov <- capture_run_provenance(packages = character(0))
  expect_false("provenance.train_data_sha256" %in% names(prov))
  expect_false("provenance.config_hash" %in% names(prov))
  expect_equal(prov[["provenance.r_version"]], R.version.string)
  expect_equal(prov[["provenance.packages"]], "")
})

test_that("capture_run_provenance() loggt Trainings-/Testdaten-Hashes, wenn Pfade uebergeben werden", {
  f_train <- tempfile(); writeLines("train", f_train)
  f_test <- tempfile(); writeLines("test", f_test)
  prov <- capture_run_provenance(train_data_path = f_train, test_data_path = f_test, packages = character(0))
  expect_equal(prov[["provenance.train_data_sha256"]], sha256_file(f_train))
  expect_equal(prov[["provenance.test_data_sha256"]], sha256_file(f_test))
  expect_false(prov[["provenance.train_data_sha256"]] == prov[["provenance.test_data_sha256"]])
})

test_that("capture_run_provenance() hasht config_env (Environment ODER Liste identisch)", {
  cfg_list <- list(target_col = "y", seed = 42)
  cfg_env <- list2env(cfg_list)
  prov_list <- capture_run_provenance(config_env = cfg_list, packages = character(0))
  prov_env <- capture_run_provenance(config_env = cfg_env, packages = character(0))
  expect_equal(prov_list[["provenance.config_hash"]], prov_env[["provenance.config_hash"]])

  prov_changed <- capture_run_provenance(config_env = list(target_col = "y", seed = 43), packages = character(0))
  expect_false(prov_changed[["provenance.config_hash"]] == prov_list[["provenance.config_hash"]])
})

test_that("capture_run_provenance() loggt feature_set als Klartext (einzelner String) oder als Hash (Vektor)", {
  prov_label <- capture_run_provenance(feature_set = "raw", packages = character(0))
  expect_equal(prov_label[["provenance.feature_set"]], "raw")
  expect_false("provenance.feature_set_hash" %in% names(prov_label))

  prov_cols <- capture_run_provenance(feature_set = c("a", "b", "c"), packages = character(0))
  expect_false("provenance.feature_set" %in% names(prov_cols))
  expect_equal(prov_cols[["provenance.feature_set_hash"]], hash_value(c("a", "b", "c")))
})

test_that("capture_run_provenance() hasht ein instanziiertes mlr3-Resampling ueber seine tatsaechlichen Fold-Zuweisungen", {
  skip_if_not_installed("mlr3")
  suppressPackageStartupMessages(library(mlr3))
  task <- tsk("iris")
  rsmp1 <- rsmp("cv", folds = 3)
  rsmp1$instantiate(task)
  rsmp2 <- rsmp("cv", folds = 3)
  rsmp2$instantiate(task) # neu instanziiert -> i.d.R. andere Fold-Zuweisung als rsmp1

  prov1 <- capture_run_provenance(resampling = rsmp1, packages = character(0))
  prov1_again <- capture_run_provenance(resampling = rsmp1, packages = character(0))
  expect_equal(prov1[["provenance.resampling_hash"]], prov1_again[["provenance.resampling_hash"]]) # dasselbe Objekt -> derselbe Hash

  set.seed(1) # fixiert rsmp2$instantiate() reproduzierbar unterschiedlich von rsmp1 (kein Seed oben gesetzt)
  rsmp3 <- rsmp("cv", folds = 3)
  rsmp3$instantiate(task)
  prov3 <- capture_run_provenance(resampling = rsmp3, packages = character(0))
  # Fold-Hash haengt von der Zuweisung ab, nicht vom R6-Objekt selbst - zwei
  # unabhaengig instanziierte Resamplings sollten (mit hoher Wahrscheinlichkeit) unterschiedlich hashen.
  expect_false(prov3[["provenance.resampling_hash"]] == prov1[["provenance.resampling_hash"]])
})

test_that("capture_run_provenance() loggt installierte Paketversionen im 'name=version'-Format", {
  prov <- capture_run_provenance(packages = c("testthat"))
  expect_match(prov[["provenance.packages"]], "^testthat=[0-9.]+$")
})

test_that("capture_run_provenance() ist mit db_log_run_config() kompatibel (Integrationstest)", {
  assign("project_dir", testthat::test_path("..", ".."), envir = globalenv())
  suppressPackageStartupMessages({ library(DBI); library(RSQLite) })
  source(testthat::test_path("..", "..", "db_logging.R"))

  path <- tempfile(fileext = ".sqlite")
  con <- db_connect(path)
  on.exit(dbDisconnect(con))

  proj_id <- db_get_or_create_project(con, "prov-test")
  wf_id <- db_get_or_create_workflow(con, proj_id, "script", "provenance_check")
  run_id <- db_create_run(con, wf_id, seed = 1, git_commit = "deadbeef")

  prov <- capture_run_provenance(feature_set = "raw", packages = character(0))
  db_log_run_config(con, run_id, prov)

  rows <- dbGetQuery(con, "SELECT rconf_key, rconf_value FROM run_config WHERE rconf_run_id = ?", params = list(run_id))
  expect_true("provenance.feature_set" %in% rows$rconf_key)
  expect_equal(rows$rconf_value[rows$rconf_key == "provenance.feature_set"], "raw")
  expect_true("provenance.r_version" %in% rows$rconf_key)
})
