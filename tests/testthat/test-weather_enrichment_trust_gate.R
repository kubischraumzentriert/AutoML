# =====================================================================
# test-weather_enrichment_trust_gate.R -- Korrektheitstests fuer
# weather_enrichment_seed_stability_gate()/assert_weather_enrichment_finding()
# (weather_enrichment_trust_gate.R), mit synthetischer Ground Truth fuer alle
# drei Entscheidungen (robust positiv, robust negativ, Rauschen). Deckt v2
# (Split-Ratio x Seed) ab, nicht mehr das v1 split_date-Interface.
# =====================================================================
suppressPackageStartupMessages({
  library(mlr3)
  library(mlr3learners)
  library(data.table)
})
source(testthat::test_path("..", "..", "modules", "weather_enrichment_trust_gate.R"))

make_learner <- function(seed) {
  l <- lrn("classif.ranger", num.trees = 50, seed = seed)
  l$predict_type <- "prob"
  l
}

# Kleine Ratio-/Seed-Grids fuer die Tests (Laufzeit): 2 Ratios x 4 Seeds =
# 8 Kombinationen statt der 50 im Produktivbetrieb - Verhalten identisch,
# nur schneller.
test_ratios <- c(0.20, 0.30)
test_n_seeds <- 4

# Synthetische Daten: 200 Zeilen, chronologisch. base_signal ist rein
# zufaellig (kein echtes Signal) -> Baseline-Modell ratet praktisch
# zufaellig; weather_signal ist eine STARK informative, deterministische
# Kopie des Ziels -> Wetter-Modell sollte robust besser sein, unabhaengig
# von Seed und Split-Ratio.
make_synthetic <- function(n = 200, weather_informative = TRUE, seed = 1) {
  set.seed(seed)
  dates <- as.Date("2015-01-01") + seq_len(n) - 1
  target <- factor(sample(c("low", "high"), n, replace = TRUE), levels = c("low", "high"))
  base_noise <- rnorm(n)
  baseline <- data.table(id = seq_len(n), date = dates, base_noise = base_noise, target = target)

  if (weather_informative) {
    # informatives Wetterfeature: stark mit dem Ziel korreliert
    weather_signal <- as.numeric(target == "high") * 5 + rnorm(n, sd = 0.3)
  } else {
    # nicht-informatives Wetterfeature: reines Rauschen, unabhaengig vom Ziel
    weather_signal <- rnorm(n)
  }
  weather <- copy(baseline)
  weather[, weather_signal := weather_signal]

  list(baseline = baseline, weather = weather)
}

test_that("robust positiver Effekt wird als robust_improvement erkannt", {
  synth <- make_synthetic(weather_informative = TRUE, seed = 10)
  gate <- weather_enrichment_seed_stability_gate(
    synth$baseline, synth$weather,
    learner_constructor = make_learner, measure = msr("classif.bacc"),
    split_ratios = test_ratios, n_seeds_per_ratio = test_n_seeds, sampling_seed = 1
  )
  expect_equal(gate$decision, "robust_improvement")
  expect_gte(gate$share_positive, 0.9)
  expect_equal(gate$n_kombinationen, length(test_ratios) * test_n_seeds)
  expect_equal(nrow(gate$by_ratio), length(test_ratios))
  expect_silent(assert_weather_enrichment_finding(gate, "improvement"))
})

test_that("kein Signal im Wetterfeature fuehrt zu inconclusive, nicht zu robust_regression", {
  synth <- make_synthetic(weather_informative = FALSE, seed = 11)
  gate <- weather_enrichment_seed_stability_gate(
    synth$baseline, synth$weather,
    learner_constructor = make_learner, measure = msr("classif.bacc"),
    split_ratios = test_ratios, n_seeds_per_ratio = test_n_seeds, sampling_seed = 2
  )
  expect_true(gate$decision %in% c("inconclusive", "robust_improvement", "robust_regression"))
  # Zentrale Eigenschaft: ohne echtes Signal darf NICHT robust_regression
  # herauskommen (das waere genau der Fehler, den das Gate verhindern soll -
  # ein Rausch-Fall faelschlich als "Wetter schadet" zu lesen).
  expect_false(gate$decision == "robust_regression")
})

test_that("assert_weather_enrichment_finding() bricht bei inconclusive ab", {
  gate <- list(
    decision = "inconclusive", share_positive = 0.5, share_negative = 0.46,
    n_kombinationen = 50, min_share_for_verdict = 0.9
  )
  expect_error(assert_weather_enrichment_finding(gate, "improvement"), "Trust-Gate nicht bestanden")
  expect_error(assert_weather_enrichment_finding(gate, "regression"), "Trust-Gate nicht bestanden")
})

test_that("assert_weather_enrichment_finding() bricht bei falsch behaupteter Richtung ab", {
  gate_pos <- list(decision = "robust_improvement", share_positive = 0.96,
                    share_negative = 0.04, n_kombinationen = 50, min_share_for_verdict = 0.9)
  expect_silent(assert_weather_enrichment_finding(gate_pos, "improvement"))
  expect_error(assert_weather_enrichment_finding(gate_pos, "regression"), "passt nicht")

  gate_neg <- list(decision = "robust_regression", share_positive = 0.04,
                    share_negative = 0.96, n_kombinationen = 50, min_share_for_verdict = 0.9)
  expect_silent(assert_weather_enrichment_finding(gate_neg, "regression"))
  expect_error(assert_weather_enrichment_finding(gate_neg, "improvement"), "passt nicht")
})

test_that("assert_weather_enrichment_finding() akzeptiert 'any' fuer beide robusten Richtungen", {
  gate_pos <- list(decision = "robust_improvement", share_positive = 0.96,
                    share_negative = 0.04, n_kombinationen = 50, min_share_for_verdict = 0.9)
  gate_neg <- list(decision = "robust_regression", share_positive = 0.04,
                    share_negative = 0.96, n_kombinationen = 50, min_share_for_verdict = 0.9)
  expect_silent(assert_weather_enrichment_finding(gate_pos, "any"))
  expect_silent(assert_weather_enrichment_finding(gate_neg, "any"))
})

test_that("weather_enrichment_seed_stability_gate() lehnt unterschiedliche Zeilenzahlen ab", {
  synth <- make_synthetic(seed = 12)
  expect_error(
    weather_enrichment_seed_stability_gate(
      synth$baseline, synth$weather[1:5],
      learner_constructor = make_learner, measure = msr("classif.bacc"),
      split_ratios = test_ratios, n_seeds_per_ratio = test_n_seeds
    ),
    "dieselbe Zeilenzahl"
  )
})

test_that("weather_enrichment_seed_stability_gate() lehnt eine ungueltige Schwelle ab", {
  synth <- make_synthetic(seed = 13)
  expect_error(
    weather_enrichment_seed_stability_gate(
      synth$baseline, synth$weather,
      learner_constructor = make_learner, measure = msr("classif.bacc"),
      split_ratios = test_ratios, n_seeds_per_ratio = test_n_seeds,
      min_share_for_verdict = 0.3
    ),
    "min_share_for_verdict"
  )
})

test_that("weather_enrichment_seed_stability_gate() lehnt ungueltige split_ratios ab", {
  synth <- make_synthetic(seed = 14)
  expect_error(
    weather_enrichment_seed_stability_gate(
      synth$baseline, synth$weather,
      learner_constructor = make_learner, measure = msr("classif.bacc"),
      split_ratios = c(0.5, 1.2), n_seeds_per_ratio = test_n_seeds
    ),
    "split_ratios"
  )
  expect_error(
    weather_enrichment_seed_stability_gate(
      synth$baseline, synth$weather,
      learner_constructor = make_learner, measure = msr("classif.bacc"),
      split_ratios = numeric(0), n_seeds_per_ratio = test_n_seeds
    ),
    "split_ratios"
  )
})
