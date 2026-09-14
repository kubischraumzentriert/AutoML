# =====================================================================
# test-probability_calibration.R -- Korrektheitstests fuer
# expected_calibration_error()/brier_score()/fit_platt_scaling()/
# fit_isotonic_calibration()/calibration_report()
# (probability_calibration.R, BACKLOG.md-Vorschlag "Wahrscheinlichkeits-
# kalibrierung").
# =====================================================================
source(testthat::test_path("..", "..", "probability_calibration.R"))

test_that("expected_calibration_error(): perfekt kalibrierte Wahrscheinlichkeiten -> ECE nahe 0", {
  set.seed(1)
  n <- 5000
  prob <- runif(n)
  truth <- factor(ifelse(runif(n) < prob, "pos", "neg"), levels = c("neg", "pos"))
  res <- expected_calibration_error(prob, truth, positive_class = "pos", n_bins = 10)
  expect_lt(res$ece, 0.03)
})

test_that("expected_calibration_error(): systematisch zu extreme Wahrscheinlichkeiten -> hoher ECE", {
  set.seed(2)
  n <- 5000
  true_prob <- runif(n, 0.3, 0.7)
  truth <- factor(ifelse(runif(n) < true_prob, "pos", "neg"), levels = c("neg", "pos"))
  # Overconfident: Modell drueckt Wahrscheinlichkeiten Richtung 0/1, obwohl
  # die tatsaechliche Trefferquote nahe 0.5 bleibt (klassisches Boosting-Symptom).
  overconfident_prob <- plogis(qlogis(true_prob) * 3)
  res <- expected_calibration_error(overconfident_prob, truth, positive_class = "pos", n_bins = 10)
  expect_gt(res$ece, 0.15)
})

test_that("brier_score(): perfekte Vorhersage -> 0, komplett falsche -> 1", {
  truth <- factor(c("pos", "pos", "neg", "neg"), levels = c("neg", "pos"))
  expect_equal(brier_score(c(1, 1, 0, 0), truth, "pos"), 0)
  expect_equal(brier_score(c(0, 0, 1, 1), truth, "pos"), 1)
})

test_that("fit_platt_scaling() korrigiert systematische Overconfidence auf einer Bestaetigungsmenge", {
  set.seed(3)
  n <- 4000
  true_prob <- runif(n, 0.2, 0.8)
  truth <- factor(ifelse(runif(n) < true_prob, "pos", "neg"), levels = c("neg", "pos"))
  overconfident_prob <- plogis(qlogis(true_prob) * 4)

  idx <- sample(n, n / 2)
  platt <- fit_platt_scaling(overconfident_prob[idx], truth[idx], "pos")
  calibrated <- pmin(pmax(platt$predict_fn(overconfident_prob[-idx]), 0), 1)

  ece_raw <- expected_calibration_error(overconfident_prob[-idx], truth[-idx], "pos")$ece
  ece_platt <- expected_calibration_error(calibrated, truth[-idx], "pos")$ece
  expect_lt(ece_platt, ece_raw)
})

test_that("fit_isotonic_calibration() korrigiert systematische Overconfidence auf einer Bestaetigungsmenge", {
  set.seed(4)
  n <- 4000
  true_prob <- runif(n, 0.2, 0.8)
  truth <- factor(ifelse(runif(n) < true_prob, "pos", "neg"), levels = c("neg", "pos"))
  overconfident_prob <- plogis(qlogis(true_prob) * 4)

  idx <- sample(n, n / 2)
  iso <- fit_isotonic_calibration(overconfident_prob[idx], truth[idx], "pos")
  calibrated <- pmin(pmax(iso$predict_fn(overconfident_prob[-idx]), 0), 1)

  ece_raw <- expected_calibration_error(overconfident_prob[-idx], truth[-idx], "pos")$ece
  ece_iso <- expected_calibration_error(calibrated, truth[-idx], "pos")$ece
  expect_lt(ece_iso, ece_raw)
})

test_that("calibration_report() liefert 3 Zeilen (raw/platt/isotonic) und verbessert den ECE", {
  set.seed(5)
  n <- 6000
  true_prob <- runif(n, 0.2, 0.8)
  truth <- factor(ifelse(runif(n) < true_prob, "pos", "neg"), levels = c("neg", "pos"))
  overconfident_prob <- plogis(qlogis(true_prob) * 4)

  res <- calibration_report(overconfident_prob, truth, positive_class = "pos", seed = 42)
  expect_equal(nrow(res), 3L)
  expect_setequal(res$variant, c("raw", "platt", "isotonic"))
  raw_ece <- res[variant == "raw"]$ece
  expect_true(res[variant == "platt"]$ece < raw_ece)
  expect_true(res[variant == "isotonic"]$ece < raw_ece)
})

test_that("calibration_report() aendert bereits gut kalibrierte Wahrscheinlichkeiten NICHT wesentlich", {
  set.seed(6)
  n <- 6000
  prob <- runif(n)
  truth <- factor(ifelse(runif(n) < prob, "pos", "neg"), levels = c("neg", "pos"))
  res <- calibration_report(prob, truth, positive_class = "pos", seed = 42)
  # Alle 3 Varianten sollten einen niedrigen ECE haben, keine "Verschlimmbesserung".
  expect_true(all(res$ece < 0.05))
})
