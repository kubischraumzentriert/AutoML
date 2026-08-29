# =====================================================================
# test-class_multiplier_tuning.R -- Korrektheitstests fuer
# apply_class_multipliers()/prior_correction_multipliers()/
# tune_class_multipliers() (class_multiplier_tuning.R).
# =====================================================================
source(testthat::test_path("..", "..", "class_multiplier_tuning.R"))

test_that("apply_class_multipliers() reproduziert argmax(prob * multiplier) von Hand", {
  probs <- matrix(
    c(0.5, 0.3, 0.2,   # Zeile 1: roher argmax = A, 0.2*3=0.6 > 0.5 -> kippt zu C
      0.3, 0.6, 0.1),  # Zeile 2: roher argmax = B, 0.1*3=0.3 < 0.6 -> bleibt B
    nrow = 2, byrow = TRUE, dimnames = list(NULL, c("A", "B", "C"))
  )
  mult <- c(A = 1, B = 1, C = 3)
  pred <- apply_class_multipliers(probs, mult)
  expect_identical(as.character(pred), c("C", "B"))
})

test_that("prior_correction_multipliers() liefert 1/prior, normiert auf die Mehrheitsklasse", {
  # 50 A, 30 B, 20 C -> prior = 0.5/0.3/0.2, Referenz A (Faktor 1).
  truth <- factor(c(rep("A", 50), rep("B", 30), rep("C", 20)), levels = c("A", "B", "C"))
  mult <- prior_correction_multipliers(truth)
  expect_equal(unname(mult["A"]), 1, tolerance = 1e-10)
  expect_equal(unname(mult["B"]), 0.5 / 0.3, tolerance = 1e-10)
  expect_equal(unname(mult["C"]), 0.5 / 0.2, tolerance = 1e-10)
})

test_that("tune_class_multipliers() verbessert BAcc mindestens auf das Grid-/Prior-Niveau", {
  # Stark unbalanciertes 3-Klassen-Problem, roher argmax uebersieht die
  # Minderheitsklassen fast komplett (typisches Symptom, das den Multiplikator-
  # Mechanismus ueberhaupt motiviert hat, siehe Kopfkommentar der Datei).
  set.seed(42)
  n <- 300
  truth <- factor(sample(c("A", "B", "C"), n, replace = TRUE, prob = c(0.8, 0.15, 0.05)),
                  levels = c("A", "B", "C"))
  # Wahrscheinlichkeiten leicht informativ, aber A dominiert fast immer den rohen argmax.
  probs <- matrix(0, nrow = n, ncol = 3, dimnames = list(NULL, c("A", "B", "C")))
  for (i in seq_len(n)) {
    base <- c(A = 0.6, B = 0.25, C = 0.15)
    base[as.character(truth[i])] <- base[as.character(truth[i])] + 0.15
    probs[i, ] <- base / sum(base)
  }
  res <- tune_class_multipliers(probs, truth, grid = seq(0.5, 4, by = 0.5))

  raw_pred <- factor(colnames(probs)[max.col(probs, ties.method = "first")], levels = levels(truth))
  raw_bacc <- mlr3measures::bacc(truth, raw_pred)

  expect_gte(res$bacc, res$grid_bacc)
  expect_gte(res$bacc, res$prior_bacc)
  expect_gte(res$bacc, raw_bacc)
  expect_equal(unname(res$multipliers[res$reference_class]), 1)
})

test_that("tune_class_multipliers() explodiert bei vielen Klassen nicht kombinatorisch (P1-Fund, openml-cc18-optdigits)", {
  # 10 Klassen -> 9 freie Multiplikator-Dimensionen. Vor dem Fix versuchte
  # `expand.grid(replicate(9, grid, ...))` mit dem Default-Grid (12 Werte)
  # eine 12^9 ~ 5.2-Mrd.-Zeilen-Matrix zu allozieren ("cannot allocate
  # vector of size 38.4 Gb") - realer Absturz beim P1-Lauf gegen
  # `openml-cc18-optdigits` (2026-08-29). Dieser Test reproduziert die
  # Dimensionalitaet synthetisch und muss ohne OOM/Haenger durchlaufen.
  set.seed(1)
  n <- 200
  k <- 10
  classes <- LETTERS[1:k]
  truth <- factor(sample(classes, n, replace = TRUE), levels = classes)
  probs <- matrix(runif(n * k), nrow = n, ncol = k, dimnames = list(NULL, classes))
  probs <- probs / rowSums(probs)

  expect_error(
    res <- tune_class_multipliers(probs, truth, grid = seq(0.5, 6, by = 0.5)),
    NA # kein Fehler/Absturz erwartet
  )
  expect_equal(length(res$multipliers), k)
  expect_true(is.finite(res$bacc))
  expect_equal(unname(res$multipliers[res$reference_class]), 1)
})

test_that("tune_class_multipliers() nutzt das Grid weiterhin voll aus, wenn die Kombinatorik klein bleibt (Regressionsschutz)", {
  # Bei wenigen Klassen (hier 3, wie im bereits bestehenden Test oben)
  # darf der Fix aus dem vorigen Test NICHT dazu fuehren, dass der
  # Grid-Schritt uebersprungen wird - `grid_bacc` muss weiterhin besser
  # als der triviale Identitaets-Score sein koennen.
  set.seed(42)
  n <- 300
  truth <- factor(sample(c("A", "B", "C"), n, replace = TRUE, prob = c(0.8, 0.15, 0.05)),
                  levels = c("A", "B", "C"))
  probs <- matrix(0, nrow = n, ncol = 3, dimnames = list(NULL, c("A", "B", "C")))
  for (i in seq_len(n)) {
    base <- c(A = 0.6, B = 0.25, C = 0.15)
    base[as.character(truth[i])] <- base[as.character(truth[i])] + 0.15
    probs[i, ] <- base / sum(base)
  }
  res <- tune_class_multipliers(probs, truth, grid = seq(0.5, 4, by = 0.5))
  identity_bacc <- mlr3measures::bacc(truth, factor(colnames(probs)[max.col(probs, ties.method = "first")], levels = levels(truth)))
  expect_gt(res$grid_bacc, identity_bacc) # das Grid muss tatsaechlich etwas gefunden haben, nicht nur die Identitaet
})
