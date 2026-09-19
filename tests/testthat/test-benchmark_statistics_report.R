# =====================================================================
# test-benchmark_statistics_report.R -- Korrektheitstests fuer
# paired_wilcoxon_report()/friedman_nemenyi_report()/
# benchmark_statistics_report() (benchmark_statistics_report.R,
# Backlog-Kandidat "Autorank/Demsar-2006-Mehrfach-Datensatz-Statistik",
# 2026-09-18).
# =====================================================================
source(testthat::test_path("..", "..", "modules", "benchmark_statistics_report.R"))

test_that("paired_wilcoxon_report(): klar bessere Methode -> alle Wins, kleines p", {
  set.seed(1)
  n <- 12
  y <- runif(n, 0.5, 0.6)
  x <- y + 0.1 + runif(n, 0, 0.01)  # x konsequent besser, kleiner Jitter
  res <- paired_wilcoxon_report(x, y, higher_better = TRUE)
  expect_equal(res$wins_x, n)
  expect_equal(res$wins_y, 0)
  expect_gt(res$median_diff, 0)
  expect_lt(res$p_value, 0.01)
  expect_equal(res$n, n)
})

test_that("paired_wilcoxon_report(): higher_better=FALSE dreht die Gewinn-Richtung korrekt um", {
  set.seed(2)
  n <- 12
  y <- runif(n, 0.5, 0.6)
  x <- y - 0.1  # x hat NIEDRIGERE Werte - bei higher_better=FALSE ist das "besser"
  res <- paired_wilcoxon_report(x, y, higher_better = FALSE)
  expect_equal(res$wins_x, n)
  expect_gt(res$median_diff, 0)  # "x besser" bleibt positiv kodiert
})

test_that("friedman_nemenyi_report(): perfekt konsistente Rangfolge -> exakte mean_rank + korrekte CD-Schwelle", {
  set.seed(3)
  n <- 10
  # A immer am besten, B mittel, C am schlechtesten - fixer Abstand (0.3)
  # deutlich groesser als der max. Jitter (0.05), damit die Rangfolge je
  # Datensatz garantiert A>B>C bleibt (kein Ranktausch durch Rauschen).
  score_matrix <- data.frame(
    A = runif(n, 0, 0.05) + 0.6,
    B = runif(n, 0, 0.05) + 0.3,
    C = runif(n, 0, 0.05)
  )
  res <- friedman_nemenyi_report(score_matrix, higher_better = TRUE)
  expect_equal(unname(res$mean_rank["A"]), 1)
  expect_equal(unname(res$mean_rank["B"]), 2)
  expect_equal(unname(res$mean_rank["C"]), 3)
  expect_lt(res$friedman_p_value, 0.01)

  expected_cd <- 2.343 * sqrt(3 * 4 / (6 * n))
  expect_equal(res$critical_difference, expected_cd, tolerance = 1e-8)

  ac <- res$significant_pairs[method_a == "A" & method_b == "C"]
  expect_true(ac$significant)  # |1-3|=2 > CD (~1.05)
  ab <- res$significant_pairs[method_a == "A" & method_b == "B"]
  expect_false(ab$significant)  # |1-2|=1 < CD - demonstriert die Schwelle, nicht nur "irgendein Unterschied"
})

test_that("friedman_nemenyi_report(): exakt gleiche Rangverteilung (Latin Square) -> keine signifikanten Paare", {
  # 3 Methoden, jede bekommt in rotierender Reihenfolge jeden Rang gleich oft -
  # mean_rank exakt gleich (2,2,2), Friedman-Statistik exakt 0.
  score_matrix <- data.frame(
    A = c(3, 2, 1, 3, 2, 1),
    B = c(2, 1, 3, 2, 1, 3),
    C = c(1, 3, 2, 1, 3, 2)
  )
  res <- friedman_nemenyi_report(score_matrix, higher_better = TRUE)
  expect_equal(unname(res$mean_rank), c(2, 2, 2))
  expect_equal(res$friedman_statistic, 0)
  expect_false(any(res$significant_pairs$significant))
})

test_that("friedman_nemenyi_report(): lehnt k<3, fehlende Spaltennamen und alpha!=0.05 ab", {
  two_col <- data.frame(A = 1:5, B = 5:1)
  expect_error(friedman_nemenyi_report(two_col), "mindestens 3 Methoden")

  no_names <- matrix(runif(15), ncol = 3)
  expect_error(friedman_nemenyi_report(no_names))

  three_col <- data.frame(A = 1:5, B = 5:1, C = 3:7)
  expect_error(friedman_nemenyi_report(three_col, alpha = 0.10), "alpha=0.05")
})

test_that("benchmark_statistics_report(): waehlt Wilcoxon bei k=2, Friedman+Nemenyi bei k>=3", {
  set.seed(4)
  two_col <- data.frame(A = runif(8, 0.6, 0.7), B = runif(8, 0.4, 0.5))
  res2 <- benchmark_statistics_report(two_col, higher_better = TRUE)
  expect_equal(res2$method, "wilcoxon")
  expect_true("mean_rank" %in% names(res2))

  three_col <- data.frame(A = runif(8, 0.8, 0.9), B = runif(8, 0.5, 0.6), C = runif(8, 0.1, 0.2))
  res3 <- benchmark_statistics_report(three_col, higher_better = TRUE)
  expect_equal(res3$method, "friedman_nemenyi")
  expect_true("critical_difference" %in% names(res3))
})

test_that("benchmark_statistics_report(): k=1 wird abgelehnt", {
  one_col <- data.frame(A = 1:5)
  expect_error(benchmark_statistics_report(one_col))
})
