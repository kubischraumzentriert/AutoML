# =====================================================================
# test-subgroup_fairness_disparity.R -- Korrektheitstests fuer
# subgroup_fairness_metrics()/pairwise_fairness_disparity()/
# fairness_disparity_report() (subgroup_fairness_disparity.R,
# BACKLOG.md-Kandidat 4).
# =====================================================================
source(testthat::test_path("..", "..", "subgroup_fairness_disparity.R"))

test_that("subgroup_fairness_metrics(): bekannte Zahlen aus einer konstruierten 2x2-Tabelle", {
  # Gruppe A: 10 Faelle - 6 TP, 2 FN (8 echte Pos), 1 FP, 1 TN (2 echte Neg).
  response <- c(rep("pos", 7), rep("neg", 3))
  truth <- c(rep("pos", 6), "neg", rep("pos", 2), "neg")
  group <- rep("A", 10)
  res <- subgroup_fairness_metrics(response, truth, group, positive_class = "pos")
  expect_equal(res$n, 10)
  expect_equal(res$positive_rate, 0.7)      # 7 von 10 positiv vorhergesagt
  expect_equal(res$tpr, 6 / 8)               # 6 von 8 echten Positiven erkannt
  expect_equal(res$fpr, 1 / 2)               # 1 von 2 echten Negativen faelschlich positiv
  expect_equal(res$ppv, 6 / 7)               # 6 von 7 positiven Vorhersagen stimmten
})

test_that("subgroup_fairness_metrics(): NA bei fehlenden echten Positiven/Negativen/Vorhersagen", {
  # Nur echte Negative -> tpr NA. Keine positiven Vorhersagen -> ppv NA.
  response <- rep("neg", 5)
  truth <- rep("neg", 5)
  group <- rep("A", 5)
  res <- subgroup_fairness_metrics(response, truth, group, positive_class = "pos")
  expect_true(is.na(res$tpr))
  expect_true(is.na(res$ppv))
  expect_equal(res$fpr, 0)  # 5 echte Negative, 0 davon faelschlich positiv
})

test_that("pairwise_fairness_disparity(): identische Gruppen -> abs_diff=0, ratio=1", {
  metrics_dt <- data.table::data.table(
    group = c("A", "B"), n = c(100, 100), positive_rate = c(0.5, 0.5),
    tpr = c(0.8, 0.8), fpr = c(0.1, 0.1), ppv = c(0.7, 0.7)
  )
  res <- pairwise_fairness_disparity(metrics_dt)
  expect_true(all(res$abs_diff == 0))
  expect_true(all(res$ratio == 1))
})

test_that("pairwise_fairness_disparity(): bekannte Differenz korrekt berechnet", {
  metrics_dt <- data.table::data.table(
    group = c("A", "B"), n = c(100, 100), positive_rate = c(0.6, 0.3),
    tpr = c(0.9, 0.9), fpr = c(0.1, 0.1), ppv = c(0.8, 0.8)
  )
  res <- pairwise_fairness_disparity(metrics_dt, metrics = "positive_rate")
  expect_equal(res$abs_diff, 0.3)
  expect_equal(res$ratio, 0.5)  # 0.3/0.6
})

test_that("pairwise_fairness_disparity(): NA-Metrik wird uebersprungen, kein Fehler", {
  metrics_dt <- data.table::data.table(
    group = c("A", "B"), n = c(100, 100), positive_rate = c(0.5, 0.5),
    tpr = c(NA_real_, 0.8), fpr = c(0.1, 0.1), ppv = c(0.7, 0.7)
  )
  res <- pairwise_fairness_disparity(metrics_dt)
  expect_false("tpr" %in% res$metric)
  expect_true(all(c("positive_rate", "fpr", "ppv") %in% res$metric))
})

test_that("fairness_disparity_report(): faires Modell (Gruppe unabhaengig von Vorhersage) -> keine Flags", {
  set.seed(1)
  n <- 4000
  truth <- factor(sample(c("pos", "neg"), n, replace = TRUE, prob = c(0.3, 0.7)))
  group <- sample(c("A", "B"), n, replace = TRUE)
  # Response haengt NUR von truth ab (80% korrekt), NICHT von group.
  response <- ifelse(runif(n) < 0.8, as.character(truth),
                     ifelse(truth == "pos", "neg", "pos"))
  res <- fairness_disparity_report(response, truth, group, positive_class = "pos")
  expect_equal(res$n_flagged, 0L)
})

test_that("fairness_disparity_report(): unfaires Modell (systematischer TPR-Gap) -> Flags", {
  set.seed(2)
  n <- 4000
  truth <- factor(sample(c("pos", "neg"), n, replace = TRUE, prob = c(0.3, 0.7)))
  group <- sample(c("A", "B"), n, replace = TRUE)
  # In Gruppe A werden 90% der echten Positiven erkannt, in Gruppe B nur 40%
  # (grosser, konstruierter Equal-Opportunity-Gap).
  detect_prob <- ifelse(group == "A", 0.9, 0.4)
  response <- character(n)
  response[truth == "pos"] <- ifelse(runif(sum(truth == "pos")) < detect_prob[truth == "pos"], "pos", "neg")
  response[truth == "neg"] <- "neg"  # keine falsch-positiven, isoliert den TPR-Effekt
  res <- fairness_disparity_report(response, truth, group, positive_class = "pos")
  expect_gt(res$n_flagged, 0L)
  tpr_row <- res$pairwise[metric == "tpr"]
  expect_true(tpr_row$flagged)
  expect_gt(tpr_row$abs_diff, 0.3)
})
