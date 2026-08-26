# =====================================================================
# test-univariate_drift.R -- Korrektheitstests fuer
# run_univariate_drift_tests()/report_univariate_drift() (univariate_drift.R).
# =====================================================================
# Positiv-/Negativ-Faelle spiegeln die bereits dokumentierten realen
# Bestaetigungen wider (siehe TARGETS.md: 2 OpenML-Datensaetze, 3 Szenarien -
# echter Zeit-Drift, Zufalls-Kontrolle, konstruierter Drift).
source(testthat::test_path("..", "..", "univariate_drift.R"))

test_that("run_univariate_drift_tests() erkennt echten numerischen Drift (Mittelwert-Verschiebung)", {
  set.seed(1)
  ref <- data.frame(x = rnorm(300, mean = 0, sd = 1))
  new <- data.frame(x = rnorm(300, mean = 3, sd = 1))  # deutliche Verschiebung
  res <- run_univariate_drift_tests(ref, new)
  expect_equal(res$feature, "x")
  expect_equal(res$type, "numeric (KS)")
  expect_lt(res$p_adj_BH, 0.001)
  expect_match(res$effect_size, "^D=")
})

test_that("run_univariate_drift_tests() zeigt KEINEN Drift bei identischer Verteilung (Spezifitaet)", {
  set.seed(2)
  ref <- data.frame(x = rnorm(500))
  new <- data.frame(x = rnorm(500))  # dieselbe Verteilung, andere Stichprobe
  res <- run_univariate_drift_tests(ref, new)
  expect_gt(res$p_adj_BH, 0.05)
})

test_that("run_univariate_drift_tests() erkennt kategorialen Drift (Cramers V)", {
  set.seed(3)
  ref <- data.frame(cat = sample(c("a", "b"), 400, replace = TRUE, prob = c(0.9, 0.1)))
  new <- data.frame(cat = sample(c("a", "b"), 400, replace = TRUE, prob = c(0.1, 0.9)))  # umgekehrte Verteilung
  res <- run_univariate_drift_tests(ref, new)
  expect_equal(res$type, "factor (Chi2)")
  expect_lt(res$p_adj_BH, 0.001)
  expect_match(res$effect_size, "^CramersV=")
})

test_that("run_univariate_drift_tests() zeigt KEINEN Drift bei identischer kategorialer Verteilung", {
  set.seed(4)
  ref <- data.frame(cat = sample(c("a", "b", "c"), 400, replace = TRUE))
  new <- data.frame(cat = sample(c("a", "b", "c"), 400, replace = TRUE))
  res <- run_univariate_drift_tests(ref, new)
  expect_gt(res$p_adj_BH, 0.05)
})

test_that("run_univariate_drift_tests() behandelt konstante numerische Spalten ohne Absturz", {
  ref <- data.frame(x = rep(5, 50))
  new <- data.frame(x = rep(5, 50))
  res <- run_univariate_drift_tests(ref, new)
  expect_true(is.na(res$p_value))
  expect_match(res$effect_size, "konstant")
})

test_that("run_univariate_drift_tests() behandelt eine kategoriale Spalte mit nur 1 Auspraegung ohne Absturz", {
  ref <- data.frame(cat = rep("nur_ein_wert", 30))
  new <- data.frame(cat = rep("nur_ein_wert", 30))
  res <- run_univariate_drift_tests(ref, new)
  expect_true(is.na(res$p_value))
  expect_match(res$effect_size, "nur 1")
})

test_that("run_univariate_drift_tests() wendet BH-Korrektur ueber mehrere Features korrekt an", {
  set.seed(5)
  ref <- data.frame(a = rnorm(300), b = rnorm(300), c = rnorm(300, mean = 5))
  new <- data.frame(a = rnorm(300), b = rnorm(300), c = rnorm(300, mean = 5))
  res <- run_univariate_drift_tests(ref, new)
  expect_equal(nrow(res), 3)
  # BH-adjustierte p-Werte sind nie kleiner als die unadjustierten.
  expect_true(all(res$p_adj_BH >= res$p_value - 1e-10))
  # Ergebnis nach p_adj_BH aufsteigend sortiert.
  expect_equal(res$p_adj_BH, sort(res$p_adj_BH))
})

test_that("run_univariate_drift_tests() bricht mit einer verstaendlichen Fehlermeldung bei unterschiedlichen Spaltennamen ab (P0.2-Haertung)", {
  ref <- data.frame(x = 1:10)
  new <- data.frame(y = 1:10)
  expect_error(run_univariate_drift_tests(ref, new), "dieselben Spaltennamen")
})

test_that("report_univariate_drift() speichert die Ergebnisse und gibt dieselbe Tabelle zurueck", {
  set.seed(6)
  ref <- data.frame(x = rnorm(200))
  new <- data.frame(x = rnorm(200, mean = 4))
  out_path <- tempfile(fileext = ".csv")
  on.exit(unlink(out_path), add = TRUE)
  invisible(capture.output(res <- report_univariate_drift(ref, new, out_path, alpha = 0.05)))
  expect_true(file.exists(out_path))
  saved <- data.table::fread(out_path)
  expect_equal(nrow(saved), nrow(res))
  expect_equal(saved$feature, res$feature)
})
