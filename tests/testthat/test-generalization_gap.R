# =====================================================================
# test-generalization_gap.R -- Korrektheitstests fuer cohens_d()/
# bootstrap_score_distribution()/compare_score_distributions()
# (generalization_gap.R).
# =====================================================================
source(testthat::test_path("..", "..", "generalization_gap.R"))

test_that("cohens_d() reproduziert die gepoolte-SD-Formel von Hand", {
  a <- c(1, 2, 3, 4, 5)
  b <- c(3, 4, 5, 6, 7)  # Mittelwert-Differenz = 2, identische Varianz -> Pooled SD = SD(a)
  expected <- (mean(b) - mean(a)) / sd(a)
  expect_equal(cohens_d(a, b), expected, tolerance = 1e-10)
})

test_that("cohens_d() liefert NA statt Division durch 0 bei konstanten Vektoren", {
  expect_true(is.na(cohens_d(rep(1, 5), rep(1, 5))))
})

test_that("bootstrap_score_distribution() liefert n_boot Werte um den wahren Score herum", {
  set.seed(1)
  truth <- rep(c(0, 1), 100)
  response <- truth  # perfekte Vorhersage -> Accuracy exakt 1 in jedem Resample
  acc <- function(t, r) mean(t == r)
  dist <- bootstrap_score_distribution(truth, response, acc, n_boot = 50, seed = 42)
  expect_length(dist, 50)
  expect_true(all(dist == 1))
})

test_that("compare_score_distributions() erkennt eine klare Luecke zwischen zwei Verteilungen", {
  set.seed(2)
  cv_scores <- rnorm(30, mean = 0.90, sd = 0.01)
  test_scores <- rnorm(30, mean = 0.70, sd = 0.01)  # deutlich schlechter -> grosse Luecke
  res <- compare_score_distributions(cv_scores, test_scores, name_a = "cv", name_b = "test")
  expect_lt(res$gap, -0.15)
  expect_lt(res$wilcox_p, 0.01)
})

test_that("compare_score_distributions() zeigt bei identischen Verteilungen keine signifikante Luecke", {
  set.seed(3)
  scores_a <- rnorm(40, mean = 0.85, sd = 0.02)
  scores_b <- rnorm(40, mean = 0.85, sd = 0.02)
  res <- compare_score_distributions(scores_a, scores_b)
  expect_gt(res$wilcox_p, 0.05)
})

test_that("bootstrap_score_distribution() gibt eine verstaendliche Fehlermeldung bei ungleicher Laenge (P0.2-Haertung)", {
  expect_error(bootstrap_score_distribution(c(1, 2, 3), c(1, 2), function(t, r) 0), "gleich lang")
})

test_that("reference_gap_distribution() berechnet die Luecke je Algorithmus korrekt", {
  cv_list <- list(ranger = c(0.80, 0.82), lightgbm = c(0.85, 0.87))
  test_list <- list(ranger = c(0.75, 0.77), lightgbm = c(0.86, 0.88))
  res <- reference_gap_distribution(cv_list, test_list)
  expect_equal(sort(res$algorithm), c("lightgbm", "ranger"))
  expect_equal(res[algorithm == "ranger"]$gap, mean(test_list$ranger) - mean(cv_list$ranger), tolerance = 1e-10)
})

test_that("reference_gap_distribution() gibt eine verstaendliche Fehlermeldung bei nicht uebereinstimmenden Namen (P0.2-Haertung)", {
  expect_error(
    reference_gap_distribution(list(ranger = 1), list(lightgbm = 1)),
    "dieselben"
  )
})
