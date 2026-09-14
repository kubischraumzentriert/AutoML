# =====================================================================
# test-missingness_mechanism_audit.R -- Korrektheitstests fuer
# diagnose_missingness_mechanism()/missingness_mechanism_report()
# (missingness_mechanism_audit.R, BACKLOG.md-Kandidat 27).
# =====================================================================
# Drei konstruierte Faelle mit BEKANNTEM Mechanismus (MCAR/MAR/MNAR-bzgl.-
# Ziel), je einmal mit numerischem und einmal mit kategorialem Ziel -
# "nachrechnen" statt vertrauen, wie bei test-composition_reweighting.R.
source(testthat::test_path("..", "..", "univariate_drift.R"))
source(testthat::test_path("..", "..", "missingness_mechanism_audit.R"))

test_that("MCAR: Fehlen unabhaengig von Ziel UND anderen Features -> kein Hinweis", {
  set.seed(1)
  n <- 1000
  dt <- data.table::data.table(
    x_other = rnorm(n),
    y = rnorm(n),
    z = rnorm(n)
  )
  # Fehlen rein zufaellig, unabhaengig von allem.
  dt[sample(.N, 200), z := NA]
  res <- diagnose_missingness_mechanism(dt, feature = "z", target_col = "y")
  expect_gt(res$target_p_adj, 0.05)
  expect_equal(res$n_feature_hints, 0L)
  expect_match(res$verdict, "kein Hinweis")
})

test_that("MNAR bzgl. Ziel (numerisch): Fehlen haengt vom ZIEL ab -> Ziel-Hinweis erkannt", {
  set.seed(2)
  n <- 1000
  y <- rnorm(n)
  x_other <- rnorm(n)  # unabhaengig vom Fehlmuster
  dt <- data.table::data.table(x_other = x_other, y = y, z = rnorm(n))
  # Hohe y-Werte fehlen systematisch haeufiger (klassisches MNAR-Muster).
  miss_idx <- order(y, decreasing = TRUE)[1:250]
  dt[miss_idx, z := NA]
  res <- diagnose_missingness_mechanism(dt, feature = "z", target_col = "y")
  expect_lt(res$target_p_adj, 0.01)
  expect_match(res$verdict, "Ziel-Hinweis")
})

test_that("MAR: Fehlen haengt von ANDEREM Feature ab, nicht vom Ziel -> Feature-Hinweis erkannt", {
  set.seed(3)
  n <- 1000
  x_other <- rnorm(n)
  y <- rnorm(n)  # unabhaengig vom Fehlmuster
  dt <- data.table::data.table(x_other = x_other, y = y, z = rnorm(n))
  # Fehlen haengt an x_other (hohe x_other-Werte -> z fehlt haeufiger), NICHT an y.
  miss_idx <- order(x_other, decreasing = TRUE)[1:250]
  dt[miss_idx, z := NA]
  res <- diagnose_missingness_mechanism(dt, feature = "z", target_col = "y")
  expect_gt(res$target_p_adj, 0.05)
  expect_gt(res$n_feature_hints, 0L)
  expect_equal(res$top_feature_hint, "x_other")
  expect_match(res$verdict, "Feature-Hinweis")
})

test_that("MNAR bzgl. Ziel funktioniert auch mit KATEGORIALEM Ziel (Chi2 statt t-Test)", {
  set.seed(4)
  n <- 1000
  y <- sample(c("a", "b"), n, replace = TRUE)
  dt <- data.table::data.table(x_other = rnorm(n), y = y, z = rnorm(n))
  # z fehlt fast nur bei y == "a".
  miss_idx <- which(y == "a")[1:300]
  dt[miss_idx, z := NA]
  res <- diagnose_missingness_mechanism(dt, feature = "z", target_col = "y")
  expect_lt(res$target_p_adj, 0.01)
  expect_match(res$verdict, "Ziel-Hinweis")
})

test_that("n_missing == 0 wird sauber uebersprungen (keine Analyse auf leerer Gruppe)", {
  dt <- data.table::data.table(x = rnorm(100), y = rnorm(100), z = rnorm(100))
  res <- diagnose_missingness_mechanism(dt, feature = "z", target_col = "y")
  expect_equal(res$n_missing, 0L)
  expect_match(res$verdict, "uebersprungen")
})

test_that("missingness_mechanism_report() liefert eine Zeile je Spalte mit Missingness, sortiert", {
  set.seed(5)
  n <- 500
  y <- rnorm(n)
  dt <- data.table::data.table(a = rnorm(n), b = rnorm(n), y = y)
  dt[sample(.N, 50), a := NA]  # MCAR
  miss_idx <- order(y, decreasing = TRUE)[1:100]
  dt[miss_idx, b := NA]        # MNAR bzgl. Ziel
  res <- missingness_mechanism_report(dt, target_col = "y")
  expect_equal(nrow(res), 2L)
  expect_true(all(c("a", "b") %in% res$feature))
  expect_match(res[feature == "b"]$verdict, "Ziel-Hinweis")
})

test_that("missingness_mechanism_report() ohne fehlende Werte gibt leere Tabelle zurueck", {
  dt <- data.table::data.table(a = rnorm(50), y = rnorm(50))
  res <- missingness_mechanism_report(dt, target_col = "y")
  expect_equal(nrow(res), 0L)
})
