# =====================================================================
# test-config_validation.R -- Korrektheitstests fuer validate_config()
# (config_validation.R).
# =====================================================================
# Jeder Testfall baut sein eigenes, isoliertes Environment (list2env()) und
# uebergibt es explizit an validate_config(env = ...) - unabhaengig vom
# echten, geladenen 000_config.R dieses Repos (das per E2E-Test unten
# separat als Spezifitaetskontrolle geprueft wird: die ECHTE Config muss
# fehlerfrei durchgehen).
source(testthat::test_path("..", "..", "config_validation.R"))

base_valid_env <- function(overrides = list()) {
  defaults <- list(
    target_col = "y", id_col = "id", positive_class = NULL,
    baseline_measure_ids = c("classif.bacc"),
    validation_ratio = 0.8, subset_fraction = 0.1, cv_folds = 5,
    class_weight_power = 1.5,
    base_learner_constructors = list(ranger = function() NULL, lightgbm = function() NULL),
    model_feature_sets = list(ranger = "raw"),
    model_class_weight_power = list(ranger = 1.5),
    submission_model_override = "ranger",
    label_cols = character(0), directional_expectation_specs = list()
  )
  # KEIN utils::modifyList() - das mergt rekursiv in verschachtelte Listen
  # und verwirft dabei unbenannte Listenelemente (wie unsere Spec-Listen in
  # directional_expectation_specs) still, statt sie zu ersetzen. Ein
  # simpler Top-Level-Ersatz je Schluessel ist hier das tatsaechlich
  # gewuenschte Verhalten.
  for (nm in names(overrides)) defaults[[nm]] <- overrides[[nm]]
  list2env(defaults)
}

test_that("validate_config() ist bei einer gueltigen Config still (keine Fehler/Warnungen)", {
  expect_true(validate_config(env = base_valid_env()))
  expect_silent(validate_config(env = base_valid_env()))
})

test_that("validate_config() erkennt ein fehlendes/leeres target_col", {
  expect_error(validate_config(env = base_valid_env(list(target_col = ""))), "target_col")
  expect_error(validate_config(env = base_valid_env(list(target_col = NULL))), "target_col")
})

test_that("validate_config() erkennt eine unbekannte mlr3-Mass-ID (Tippfehler-Schutz)", {
  expect_error(
    validate_config(env = base_valid_env(list(baseline_measure_ids = "classif.nichtexistent"))),
    "unbekannte mlr3-Mass-IDs"
  )
})

test_that("validate_config() akzeptiert eine gueltige, aber ungewoehnliche Mass-ID (z.B. AUC)", {
  expect_true(validate_config(env = base_valid_env(list(baseline_measure_ids = "classif.auc", positive_class = "yes"))))
})

test_that("validate_config() warnt (nicht fatal), wenn positive_class bei einer schwellenwertunabhaengigen Metrik NULL ist", {
  expect_warning(
    validate_config(env = base_valid_env(list(baseline_measure_ids = "classif.auc", positive_class = NULL))),
    "positive_class ist NULL"
  )
})

test_that("validate_config() erzwingt bei Multi-Label genug Platz fuer die Eval-Menge", {
  expect_error(
    validate_config(env = base_valid_env(list(
      label_cols = c("a", "b"), multilabel_train_ratio = 0.7, multilabel_tune_ratio = 0.5
    ))),
    "kein Platz fuer die Eval-Menge"
  )
  # 0.6 + 0.2 < 1 -> gueltig, kein Fehler.
  expect_true(validate_config(env = base_valid_env(list(
    label_cols = c("a", "b"), multilabel_train_ratio = 0.6, multilabel_tune_ratio = 0.2
  ))))
})

test_that("validate_config() erkennt target_col innerhalb von label_cols als Konflikt", {
  expect_error(
    validate_config(env = base_valid_env(list(
      label_cols = c("y", "b"), multilabel_train_ratio = 0.6, multilabel_tune_ratio = 0.2
    ))),
    "target_col taucht auch in label_cols"
  )
})

test_that("validate_config() erkennt Split-/Budget-Anteile ausserhalb (0,1]", {
  expect_error(validate_config(env = base_valid_env(list(validation_ratio = 1.5))), "validation_ratio")
  expect_error(validate_config(env = base_valid_env(list(validation_ratio = 0))), "validation_ratio")
  expect_error(validate_config(env = base_valid_env(list(subset_fraction = 0))), "subset_fraction")
  expect_true(validate_config(env = base_valid_env(list(subset_fraction = 1))))  # 1 ist erlaubt (allow_one)
})

test_that("validate_config() erkennt cv_folds < 2 oder nicht-ganzzahlig", {
  expect_error(validate_config(env = base_valid_env(list(cv_folds = 1))), "cv_folds")
  expect_error(validate_config(env = base_valid_env(list(cv_folds = 2.5))), "cv_folds")
})

test_that("validate_config() erkennt negatives class_weight_power", {
  expect_error(validate_config(env = base_valid_env(list(class_weight_power = -1))), "class_weight_power")
})

test_that("validate_config() findet Tippfehler in Modellnamen (model_feature_sets/model_class_weight_power/submission_model_override)", {
  expect_error(
    validate_config(env = base_valid_env(list(model_feature_sets = list(lgihtgbm = "raw")))),
    "model_feature_sets"
  )
  expect_error(
    validate_config(env = base_valid_env(list(model_class_weight_power = list(lgihtgbm = 1.5)))),
    "model_class_weight_power"
  )
  expect_error(
    validate_config(env = base_valid_env(list(submission_model_override = "lgihtgbm"))),
    "submission_model_override"
  )
})

test_that("validate_config() prueft directional_expectation_specs auf Pflichtfelder je Typ", {
  expect_error(
    validate_config(env = base_valid_env(list(directional_expectation_specs = list(
      list(feature = "x", type = "numeric", direction = "increasing", favorable_class = "yes")  # kein delta
    )))),
    "braucht ein 'delta'-Feld"
  )
  expect_error(
    validate_config(env = base_valid_env(list(directional_expectation_specs = list(
      list(feature = "x", type = "ordinal", direction = "increasing", favorable_class = "yes")  # kein level_order
    )))),
    "braucht ein 'level_order'-Feld"
  )
  expect_error(
    validate_config(env = base_valid_env(list(directional_expectation_specs = list(
      list(feature = "x", type = "numeric", delta = 1, direction = "sideways", favorable_class = "yes")
    )))),
    "increasing.*decreasing"
  )
  # Gueltige Spec darf keinen Fehler werfen.
  expect_true(validate_config(env = base_valid_env(list(directional_expectation_specs = list(
    list(feature = "x", type = "numeric", delta = 1, direction = "increasing", favorable_class = "yes")
  )))))
})

test_that("validate_config() sammelt MEHRERE Fehler in einer einzigen Meldung statt beim ersten abzubrechen", {
  err <- tryCatch(
    validate_config(env = base_valid_env(list(target_col = "", cv_folds = 1))),
    error = function(e) e
  )
  expect_match(conditionMessage(err), "target_col")
  expect_match(conditionMessage(err), "cv_folds")
  expect_match(conditionMessage(err), "2 Problem")
})

# --- End-to-End-Spezifitaetskontrolle: die ECHTE 000_config.R dieses Repos
# MUSS fehlerfrei durchgehen (regressionsgetestet gegen health_condition,
# analog zum etablierten Muster bei anderen Guards in diesem Template). ---

test_that("validate_config() ist bei der ECHTEN 000_config.R des Template-eigenen Projekts still", {
  config_env <- new.env()
  # `project_dir` vorab setzen: 000_config.R leitet es sonst ueber
  # sys.frame(1)$ofile ab - das funktioniert nur bei einem direkten
  # Top-Level-source()-Aufruf (wie in den numerierten Skripten), nicht bei
  # der tieferen Aufrufkette hier (testthat -> test_that -> source()). Der
  # Guard `if (!exists("project_dir"))` in 000_config.R ist genau fuer
  # diesen Fall gedacht.
  config_env$project_dir <- testthat::test_path("..", "..")
  source(testthat::test_path("..", "..", "000_config.R"), local = config_env)
  expect_true(validate_config(env = config_env))
  expect_silent(validate_config(env = config_env))
})
