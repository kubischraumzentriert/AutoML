# =====================================================================
# test-bootstrap_metric_ci.R -- Korrektheitstests fuer
# bootstrap_metric_ci()/bootstrap_paired_comparison()/format_metric_ci()
# (bootstrap_metric_ci.R, Backlog-Kandidat "Bootstrap-CI fuer die finale
# Metrik", 2026-09-17).
# =====================================================================
source(testthat::test_path("..", "..", "modules", "bootstrap_metric_ci.R"))

accuracy_fn <- function(truth, pred) mean(truth == pred)

test_that("bootstrap_metric_ci(): point-Schaetzung = exakte Metrik auf den Originaldaten", {
  set.seed(1)
  truth <- sample(c(0, 1), 200, replace = TRUE)
  pred <- truth
  pred[sample(200, 20)] <- 1 - pred[sample(200, 20)]  # etwas Rauschen
  res <- bootstrap_metric_ci(truth, pred, accuracy_fn, B = 500, seed = 2)
  expect_equal(res$point, accuracy_fn(truth, pred))
})

test_that("bootstrap_metric_ci(): CI schliesst die Punktschaetzung ueblicherweise ein", {
  set.seed(3)
  truth <- sample(c(0, 1), 300, replace = TRUE, prob = c(0.4, 0.6))
  pred <- truth
  pred[sample(300, 60)] <- 1 - pred[sample(300, 60)]
  res <- bootstrap_metric_ci(truth, pred, accuracy_fn, B = 1000, seed = 4)
  expect_true(res$ci_lower <= res$point + 1e-9)
  expect_true(res$ci_upper >= res$point - 1e-9)
  expect_true(res$ci_lower < res$ci_upper)
})

test_that("bootstrap_metric_ci(): mehr Daten -> engeres CI (weniger Bootstrap-Varianz)", {
  set.seed(5)
  make_data <- function(n) {
    truth <- sample(c(0, 1), n, replace = TRUE)
    pred <- truth
    flip_n <- round(n * 0.15)
    pred[sample(n, flip_n)] <- 1 - pred[sample(n, flip_n)]
    list(truth = truth, pred = pred)
  }
  small <- make_data(50)
  large <- make_data(2000)
  res_small <- bootstrap_metric_ci(small$truth, small$pred, accuracy_fn, B = 1000, seed = 6)
  res_large <- bootstrap_metric_ci(large$truth, large$pred, accuracy_fn, B = 1000, seed = 7)
  width_small <- res_small$ci_upper - res_small$ci_lower
  width_large <- res_large$ci_upper - res_large$ci_lower
  expect_gt(width_small, width_large)
})

test_that("bootstrap_metric_ci(): hoeheres Konfidenzniveau -> breiteres CI", {
  set.seed(8)
  truth <- sample(c(0, 1), 300, replace = TRUE)
  pred <- truth
  pred[sample(300, 50)] <- 1 - pred[sample(300, 50)]
  res_80 <- bootstrap_metric_ci(truth, pred, accuracy_fn, B = 1500, conf_level = 0.80, seed = 9)
  res_99 <- bootstrap_metric_ci(truth, pred, accuracy_fn, B = 1500, conf_level = 0.99, seed = 9)
  expect_gt(res_99$ci_upper - res_99$ci_lower, res_80$ci_upper - res_80$ci_lower)
})

test_that("bootstrap_metric_ci(): funktioniert auch mit Wahrscheinlichkeits-Matrix-Vorhersagen (z.B. fuer AUC)", {
  set.seed(10)
  n <- 200
  truth <- factor(sample(c("no", "yes"), n, replace = TRUE), levels = c("no", "yes"))
  prob_yes <- ifelse(truth == "yes", runif(n, 0.4, 1), runif(n, 0, 0.6))
  prob_mat <- cbind(no = 1 - prob_yes, yes = prob_yes)
  auc_fn <- function(t, p) mlr3measures::auc(t, p[, "yes"], positive = "yes")
  res <- bootstrap_metric_ci(truth, prob_mat, auc_fn, B = 500, seed = 11)
  expect_true(res$point > 0.5)
  expect_true(res$ci_lower <= res$point && res$point <= res$ci_upper)
})

test_that("bootstrap_metric_ci(): Deckungseigenschaft (90%-CI enthaelt den wahren Wert in ~90% der Wiederholungen)", {
  # Klassischer Bootstrap-Coverage-Check: bekannte DGP (Bernoulli(p=0.8)
  # Korrektheitsindikator), viele unabhaengige Realisierungen, je eine
  # eigene Bootstrap-CI-Berechnung - Anteil der Wiederholungen, die p
  # wirklich einschliessen, sollte nahe am Ziel-Konfidenzniveau liegen.
  set.seed(12)
  true_p <- 0.8
  n <- 150
  n_reps <- 200
  covered <- vapply(seq_len(n_reps), function(i) {
    correct <- rbinom(n, 1, true_p)
    res <- bootstrap_metric_ci(rep(1, n), correct, function(t, p) mean(p == 1),
                                B = 300, conf_level = 0.90)
    res$ci_lower <= true_p && true_p <= res$ci_upper
  }, logical(1))
  coverage <- mean(covered)
  expect_gt(coverage, 0.78)  # grosszuegige Toleranz um 0.90 (n_reps=200, Monte-Carlo-Rauschen)
  expect_lt(coverage, 0.99)
})

test_that("bootstrap_paired_comparison(): identische Vorhersagen -> delta=0 und CI=[0,0] exakt", {
  set.seed(13)
  truth <- sample(c(0, 1), 200, replace = TRUE)
  pred <- truth
  pred[sample(200, 30)] <- 1 - pred[sample(200, 30)]
  res <- bootstrap_paired_comparison(truth, pred, pred, accuracy_fn, B = 300, seed = 14)
  expect_equal(res$delta, 0)
  expect_equal(res$ci_lower, 0)
  expect_equal(res$ci_upper, 0)
  expect_false(res$significant)
  expect_equal(res$p_value, 1)
})

test_that("bootstrap_paired_comparison(): klar besseres Modell A -> positives, signifikantes delta", {
  set.seed(15)
  n <- 300
  truth <- sample(c(0, 1), n, replace = TRUE)
  pred_a <- truth  # perfekt
  pred_b <- sample(c(0, 1), n, replace = TRUE)  # reines Raten
  res <- bootstrap_paired_comparison(truth, pred_a, pred_b, accuracy_fn, B = 1000, seed = 16)
  expect_gt(res$delta, 0.3)
  expect_true(res$significant)
  expect_lt(res$ci_lower, res$delta)
  expect_lt(res$p_value, 0.05)
})

test_that("bootstrap_paired_comparison(): kaum unterschiedliche Modelle -> CI schliesst 0 meist ein", {
  set.seed(17)
  n <- 400
  truth <- sample(c(0, 1), n, replace = TRUE)
  pred_a <- truth; pred_a[sample(n, 40)] <- 1 - pred_a[sample(n, 40)]
  pred_b <- truth; pred_b[sample(n, 42)] <- 1 - pred_b[sample(n, 42)]  # fast gleich viel Rauschen
  res <- bootstrap_paired_comparison(truth, pred_a, pred_b, accuracy_fn, B = 1000, seed = 18)
  expect_false(res$significant)
})

test_that("format_metric_ci(): erzeugt die erwartete lesbare Form", {
  res <- list(point = 0.94823, ci_lower = 0.94011, ci_upper = 0.95580, conf_level = 0.90)
  txt <- format_metric_ci(res, digits = 4)
  expect_match(txt, "^0\\.9482 \\[90%-CI: 0\\.9401, 0\\.9558\\]$")
})
