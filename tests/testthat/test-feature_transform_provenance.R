# =====================================================================
# test-feature_transform_provenance.R -- Korrektheitstests fuer
# feature_transform_function_hash() (000_config.R).
# =====================================================================
# ReciPies-Gegenpruefung (docs/research/JOSS_TECHNIQUE_WATCH.md Kandidat
# #5): die bereits bestehende feature_names_hash-Provenienz (provenance.R,
# genutzt in 150/156) hasht nur die RESULTIERENDEN Spaltennamen, nicht
# die Transformationslogik selbst - ein stiller Verhaltenswechsel in
# einer add_*_features()-Funktion, der keine Spalten hinzufuegt/entfernt/
# umbenennt, bliebe damit unbemerkt. Das zentrale Verhalten, das dieser
# Testfile absichert: AENDERT SICH EINE FUNKTION INHALTLICH, AENDERT SICH
# DER HASH - auch bei unveraenderten Ausgabe-Spaltennamen (siehe Testfall
# weiter unten, der genau das mit zwei verschieden definierten Umgebungen
# demonstriert).
#
# `000_config.R` ist keine eigenstaendige Modul-Datei (ADR-007, Config
# eines konkreten Projekts) - Sourcing-Muster daher identisch zur
# End-to-End-Spezifitaetskontrolle in test-config_validation.R: `source()`
# in ein isoliertes Environment, `project_dir` vorab gesetzt (der Guard
# in 000_config.R braucht das ausserhalb eines direkten Top-Level-
# source()-Aufrufs). `provenance.R` (liefert hash_value()) UND alle
# features/*.R (liefern add_*_features()) werden zusaetzlich in dasselbe
# Environment gesourct, genau wie es 150_train_full_model.R zur Laufzeit
# tut.

load_real_config_env <- function() {
  env <- new.env()
  env$project_dir <- testthat::test_path("..", "..")
  source(testthat::test_path("..", "..", "000_config.R"), local = env)
  source(testthat::test_path("..", "..", "provenance.R"), local = env)
  for (f in list.files(testthat::test_path("..", "..", "features"), pattern = "\\.R$", full.names = TRUE)) {
    source(f, local = env)
  }
  env
}

config_env <- load_real_config_env()

test_that("feature_transform_function_hash() ist NA fuer 'raw' und 'surrogate_guided'", {
  expect_true(is.na(config_env$feature_transform_function_hash("raw")))
  expect_true(is.na(config_env$feature_transform_function_hash("surrogate_guided")))
})

test_that("feature_transform_function_hash() ist deterministisch fuer denselben feature_set", {
  h1 <- config_env$feature_transform_function_hash("selected")
  h2 <- config_env$feature_transform_function_hash("selected")
  expect_identical(h1, h2)
  expect_false(is.na(h1))
})

test_that("feature_transform_function_hash() unterscheidet verschiedene feature_sets", {
  h_features <- config_env$feature_transform_function_hash("features")
  h_selected <- config_env$feature_transform_function_hash("selected")
  h_bmi <- config_env$feature_transform_function_hash("bmi")
  expect_false(identical(h_features, h_selected))
  expect_false(identical(h_features, h_bmi))
  expect_false(identical(h_selected, h_bmi))
})

test_that("feature_transform_function_hash() ist unabhaengig von der Familienreihenfolge (nur vom Familien-SATZ)", {
  # 'selected' (activity, cardio, sleep) enthaelt dieselben Familien wie
  # ein manuell in anderer Reihenfolge zusammengestellter Vektor - sortiert
  # intern, muss also denselben Hash liefern.
  h_selected <- config_env$feature_transform_function_hash("selected")
  h_manual <- with(config_env, {
    ordered_families <- sort(c("sleep", "activity", "cardio"))
    functions_by_family <- feature_family_functions()
    bodies <- lapply(ordered_families, function(family) deparse(functions_by_family[[family]]))
    names(bodies) <- ordered_families
    hash_value(bodies)
  })
  expect_identical(h_selected, h_manual)
})

test_that("feature_transform_function_hash() meldet ein unbekanntes Feature-Set als Fehler", {
  expect_error(config_env$feature_transform_function_hash("does_not_exist"), "Unbekanntes Feature-Set")
})

test_that("feature_transform_function_hash() aendert sich, wenn eine Familienfunktion sich inhaltlich aendert (Kernbeweis der ReciPies-Luecke)", {
  # Zwei Kopien desselben Environments: eine mit der echten add_bmi_features(),
  # eine mit einer inhaltlich veraenderten Version DERSELBEN Funktion (andere
  # Formel, aber identischer Rueckgabe-Spaltenname "bmi_category") - simuliert
  # genau die Luecke, die feature_names_hash NICHT gefangen haette.
  env_unchanged <- load_real_config_env()
  env_changed <- load_real_config_env()
  env_changed$add_bmi_features <- function(data) {
    data$bmi_category <- "changed_logic_same_column_name"
    data
  }

  h_unchanged <- env_unchanged$feature_transform_function_hash("bmi")
  h_changed <- env_changed$feature_transform_function_hash("bmi")

  expect_false(identical(h_unchanged, h_changed))
})

test_that("feature_transform_function_hash() bleibt gleich, wenn NUR eine NICHT beteiligte Funktion sich aendert", {
  # 'bmi' als feature_set nutzt ausschliesslich add_bmi_features() - eine
  # Aenderung an add_sleep_features() (nicht Teil dieses feature_sets) darf
  # den Hash NICHT beeinflussen.
  env_unchanged <- load_real_config_env()
  env_changed <- load_real_config_env()
  env_changed$add_sleep_features <- function(data) data

  h_unchanged <- env_unchanged$feature_transform_function_hash("bmi")
  h_changed <- env_changed$feature_transform_function_hash("bmi")

  expect_identical(h_unchanged, h_changed)
})

# --- End-to-End-Spezifitaetskontrolle: die ECHTE 000_config.R dieses
# Repos MUSS fuer alle tatsaechlich verwendeten Feature-Sets (siehe
# model_feature_sets) fehlerfrei durchlaufen. ---

test_that("feature_transform_function_hash() laeuft fuer alle in model_feature_sets verwendeten Feature-Sets der ECHTEN Config fehlerfrei durch", {
  used_feature_sets <- unique(unlist(config_env$model_feature_sets))
  for (fs in used_feature_sets) {
    result <- config_env$feature_transform_function_hash(fs)
    expect_true(is.na(result) || (is.character(result) && nzchar(result)))
  }
})
