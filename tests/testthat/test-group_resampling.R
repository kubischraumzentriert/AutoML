# =====================================================================
# test-group_resampling.R -- Korrektheitstests fuer .eta_squared()/
# .cramers_v()/test_group_significance() (group_resampling.R).
# =====================================================================
# Positiv-/Negativ-Kontrollen nach demselben Muster, mit dem diese Groesse
# diese Session bereits mehrfach manuell (und wieder verworfen) verifiziert
# wurde - siehe REFERENZ_GROUP_AWARE_CV.md.
source(testthat::test_path("..", "..", "group_resampling.R"))

test_that(".eta_squared() erkennt eine Gruppe, die den Zielwert exakt festlegt", {
  # Jede Gruppe hat einen konstanten Zielwert -> between_ss == total_ss -> eta^2 == 1.
  g <- rep(c("a", "b", "c"), each = 10)
  y <- rep(c(1, 5, 9), each = 10)
  expect_equal(.eta_squared(y, g), 1, tolerance = 1e-10)
})

test_that(".eta_squared() liegt nahe 0, wenn die Gruppe keinen Zusammenhang zum Ziel hat", {
  set.seed(1)
  g <- sample(letters[1:5], 500, replace = TRUE)
  y <- rnorm(500)  # unabhaengig von g
  expect_lt(.eta_squared(y, g), 0.02)
})

test_that(".cramers_v() liegt bei 1, wenn die Gruppe den kategorialen Zielwert exakt festlegt", {
  # Wie uci-parkinsons-voice-groupcv: subject legt status deterministisch fest.
  g <- rep(paste0("subj_", 1:20), each = 5)
  y <- rep(c("gesund", "krank"), each = 50)
  expect_equal(.cramers_v(y, g), 1, tolerance = 1e-10)
})

test_that(".cramers_v() liegt nahe 0 bei Unabhaengigkeit von Gruppe und Ziel", {
  set.seed(2)
  g <- sample(letters[1:6], 600, replace = TRUE)
  y <- sample(c("A", "B"), 600, replace = TRUE)
  expect_lt(.cramers_v(y, g), 0.15)
})

test_that(".cramers_v() gibt 0 statt NaN im degenerierten Fall (nur 1 Level)", {
  g <- rep("nur_eine_gruppe", 20)
  y <- sample(c("A", "B"), 20, replace = TRUE)
  expect_equal(.cramers_v(y, g), 0)
})

test_that("test_group_significance() waehlt eta2 fuer numerisches Ziel und cramers_v fuer kategoriales", {
  set.seed(3)
  g <- rep(letters[1:10], each = 10)
  y_num <- rnorm(100)
  y_cat <- factor(sample(c("x", "y"), 100, replace = TRUE))

  res_num <- test_group_significance(y_num, g, n_perm = 99, seed = 42)
  res_cat <- test_group_significance(y_cat, g, n_perm = 99, seed = 42)

  expect_identical(res_num$statistic_name, "eta2")
  expect_identical(res_cat$statistic_name, "cramers_v")
})

test_that("test_group_significance() liefert bei starker Gruppenstruktur einen kleinen p-Wert", {
  g <- rep(paste0("g", 1:20), each = 10)
  y <- rep(seq(0, 100, length.out = 20), each = 10) + rnorm(200, sd = 0.01)
  res <- test_group_significance(y, g, n_perm = 199, seed = 42)
  expect_lt(res$p_value, 0.05)
})

test_that("test_group_significance() liefert bei fehlender Gruppenstruktur KEINEN kleinen p-Wert", {
  set.seed(4)
  g <- sample(paste0("g", 1:20), 400, replace = TRUE)
  y <- rnorm(400)
  res <- test_group_significance(y, g, n_perm = 199, seed = 42)
  expect_gt(res$p_value, 0.05)
})

test_that("test_group_significance() gibt eine verstaendliche Fehlermeldung bei ungleicher Laenge (P0.2-Haertung)", {
  expect_error(test_group_significance(c(1, 2, 3), c("a", "b")), "gleich lang")
})
