# =====================================================================
# test-decision_stability.R -- Korrektheitstests fuer
# decision_stability_report() (decision_stability.R), synthetisch auf
# Entscheidungsfunktionen mit BEKANNTEM/kontrolliertem Stabilitaets-
# verhalten, bevor irgendein echter Lauf damit gemacht wird (siehe
# JOSS_TECHNIQUE_WATCH.md, "kleiner Prototyp -> synthetischer Test ->
# 1-2 reale Projekte").
# =====================================================================
source(testthat::test_path("..", "..", "decision_stability.R"))

test_that("decision_stability_report() erkennt eine IMMER STABILE Entscheidung (Stabilitaet = 1, nicht geflaggt)", {
  always_a <- function(seed) "A"
  res <- suppressWarnings(capture.output(
    out <- decision_stability_report(always_a, n_repeats = 10, label = "test-stable")
  ))
  expect_equal(out$stability, 1)
  expect_equal(out$majority_choice, "A")
  expect_false(out$flagged)
  expect_true(all(out$choices == "A"))
})

test_that("decision_stability_report() erkennt eine DETERMINISTISCH VOM SEED ABHAENGENDE, instabile Entscheidung (geflaggt)", {
  # Wechselt bei jedem Seed zwischen zwei Optionen - Mehrheit haelt bestenfalls 50-60%,
  # klar unter dem Default-Flag-Schwellenwert von 0.7.
  alternating <- function(seed) if (seed %% 2 == 0) "X" else "Y"
  out <- capture.output(res <- decision_stability_report(alternating, n_repeats = 10, label = "test-alternating"))
  expect_lt(res$stability, 0.7)
  expect_true(res$flagged)
  expect_equal(sum(res$table), 10)
})

test_that("decision_stability_report() liefert eine korrekte Haeufigkeitstabelle bei 3 Optionen", {
  # seed 1..9 -> A,A,A,A,A,A,B,B,C (6xA, 2xB, 1xC) - Mehrheit A bei 60%, unter 0.7 -> geflaggt
  three_way <- function(seed) c("A", "A", "A", "A", "A", "A", "B", "B", "C")[seed]
  out <- capture.output(res <- decision_stability_report(three_way, n_repeats = 9, label = "test-threeway"))
  expect_equal(res$majority_choice, "A")
  expect_equal(unname(res$table[["A"]]), 6)
  expect_equal(unname(res$table[["B"]]), 2)
  expect_equal(unname(res$table[["C"]]), 1)
  expect_equal(res$stability, 6 / 9)
  expect_true(res$flagged) # 6/9 = 0.667 < 0.7
})

test_that("decision_stability_report() respektiert einen benutzerdefinierten flag_threshold", {
  mostly_a <- function(seed) if (seed <= 8) "A" else "B" # 8/10 = 0.8
  out1 <- capture.output(res1 <- decision_stability_report(mostly_a, n_repeats = 10, flag_threshold = 0.7))
  expect_false(res1$flagged) # 0.8 >= 0.7
  out2 <- capture.output(res2 <- decision_stability_report(mostly_a, n_repeats = 10, flag_threshold = 0.9))
  expect_true(res2$flagged) # 0.8 < 0.9
})

test_that("decision_stability_report() ist reproduzierbar, wenn decision_fn den seed intern selbst setzt", {
  # Realistischer Anwendungsfall: decision_fn seedet sich selbst (z.B. vor einem
  # Tuning-Lauf), unabhaengig vom globalen RNG-Zustand zum Aufrufzeitpunkt.
  fn <- function(seed) {
    set.seed(seed)
    sample(c("A", "B", "C"), 1)
  }
  set.seed(123) # globaler RNG-Zustand VOR dem 1. Aufruf
  out1 <- capture.output(res1 <- decision_stability_report(fn, n_repeats = 8, seed_start = 1))
  set.seed(999) # bewusst ANDERER globaler Zustand VOR dem 2. Aufruf
  out2 <- capture.output(res2 <- decision_stability_report(fn, n_repeats = 8, seed_start = 1))
  expect_identical(res1$choices, res2$choices)
  expect_identical(res1$stability, res2$stability)
})

test_that("decision_stability_report() bricht bei n_repeats < 2 kontrolliert ab", {
  expect_error(decision_stability_report(function(seed) "A", n_repeats = 1), "n_repeats muss >= 2")
})
