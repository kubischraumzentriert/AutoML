# =====================================================================
# test-feature_importance_stability.R -- Korrektheitstests fuer
# collect_importance_across_folds()/pairwise_rank_correlation()/
# pairwise_topk_overlap()/feature_importance_stability_report()
# (feature_importance_stability.R, BACKLOG.md-Kandidat "Feature-
# Importance-Stabilitaet").
# =====================================================================
source(testthat::test_path("..", "..", "modules", "feature_importance_stability.R"))

test_that("collect_importance_across_folds() baut eine Features x Folds-Matrix", {
  imp_list <- list(c(a = 5, b = 3, c = 1), c(a = 6, b = 2, c = 0), c(a = 4, b = 4))
  i <- 0
  train_fn <- function(train_ids) {
    i <<- i + 1
    structure(list(importance = function() imp_list[[i]]), class = "fake_learner")
  }
  folds <- list(list(train = 1:5), list(train = 6:10), list(train = 11:15))
  mat <- collect_importance_across_folds(folds, train_fn)
  expect_equal(dim(mat), c(3L, 3L))
  expect_equal(mat["a", ], c(`1` = 5, `2` = 6, `3` = 4), ignore_attr = TRUE)
  # Fold 3 nennt "c" nicht -> 0, nicht NA (siehe Doku: echtes Ergebnis, kein fehlender Wert).
  expect_equal(unname(mat["c", 3]), 0)
})

test_that("pairwise_rank_correlation(): identische Rangfolgen -> Korrelation 1", {
  mat <- cbind(f1 = c(a = 10, b = 5, c = 1), f2 = c(a = 20, b = 8, c = 2), f3 = c(a = 15, b = 6, c = 0.5))
  res <- pairwise_rank_correlation(mat)
  expect_equal(nrow(res$pairwise), 3L)  # 3 Folds -> 3 Paare
  expect_equal(res$mean_correlation, 1, tolerance = 1e-9)
})

test_that("pairwise_rank_correlation(): komplett umgekehrte Rangfolge -> Korrelation -1", {
  mat <- cbind(f1 = c(a = 10, b = 5, c = 1), f2 = c(a = 1, b = 5.5, c = 10))
  res <- pairwise_rank_correlation(mat)
  expect_equal(res$mean_correlation, -1, tolerance = 1e-9)
})

test_that("pairwise_topk_overlap(): identische Top-k-Mengen -> Jaccard 1", {
  mat <- cbind(f1 = c(a = 10, b = 8, c = 1, d = 0.5), f2 = c(a = 20, b = 15, c = 0.1, d = 0.05))
  res <- pairwise_topk_overlap(mat, k = 2)
  expect_equal(res$mean_jaccard, 1)
})

test_that("pairwise_topk_overlap(): disjunkte Top-k-Mengen -> Jaccard 0", {
  mat <- cbind(f1 = c(a = 10, b = 8, c = 1, d = 0.5), f2 = c(a = 0.1, b = 0.2, c = 10, d = 8))
  res <- pairwise_topk_overlap(mat, k = 2)
  expect_equal(res$mean_jaccard, 0)
})

test_that("feature_importance_stability_report(): stabiles Feature hat sd_rank=0, topk_share=1", {
  # "a" ist in jedem Fold Rang 1, "b"/"c" wechseln sich in Rang 2/3 ab.
  mat <- cbind(f1 = c(a = 10, b = 5, c = 1), f2 = c(a = 10, b = 1, c = 5), f3 = c(a = 10, b = 5, c = 1))
  res <- feature_importance_stability_report(mat, k = 1)
  a_row <- res[feature == "a"]
  expect_equal(a_row$sd_rank, 0)
  expect_equal(a_row$topk_share, 1)
  expect_equal(res$feature[1], "a")  # bestes mean_rank zuerst sortiert
})

test_that("Integrationscheck: echtes mlr3-Modell, starkes vs. Rauschen-Feature", {
  skip_if_not_installed("ranger")
  suppressPackageStartupMessages(library(mlr3learners))
  set.seed(1)
  n <- 1500
  # 10 reine Rauschen-Features (nicht nur 3) - bei 5-fachen CV-Folds
  # (die sich zu 80% ueberlappen) kann EINZELNES Rauschen durch Zufall
  # eine scheinbar stabile Rangfolge zeigen; mit mehr Rauschen-Features
  # wird die AGGREGIERTE Aussage ("Rauschen im Mittel instabiler als
  # das echte Signal") robust pruefbar, ohne von einem Einzelausreisser
  # abzuhaengen - selbst eine reale Eigenschaft von CV-basierten
  # Stabilitaets-Checks (hohe Fold-Ueberlappung taeuscht Stabilitaet
  # leichter vor als unabhaengige Resamples).
  noise_dt <- data.table::as.data.table(matrix(rnorm(n * 10), ncol = 10))
  data.table::setnames(noise_dt, paste0("x_noise", 1:10))
  dt <- data.table::data.table(x_strong = rnorm(n))
  dt <- cbind(dt, noise_dt)
  dt[, y := as.factor(as.integer(x_strong + rnorm(n, sd = 0.3) > 0))]
  task <- mlr3::as_task_classif(dt, target = "y", id = "importance_stability_test")

  set.seed(2)
  rsmp_cv <- mlr3::rsmp("cv", folds = 5L)
  rsmp_cv$instantiate(task)
  folds <- lapply(seq_len(rsmp_cv$iters), function(i) list(train = rsmp_cv$train_set(i)))

  train_fn <- function(train_ids) {
    lr <- mlr3::lrn("classif.ranger", importance = "impurity")
    lr$train(task, row_ids = train_ids)
    lr
  }
  mat <- collect_importance_across_folds(folds, train_fn)
  report <- feature_importance_stability_report(mat, k = 1)

  strong_row <- report[feature == "x_strong"]
  noise_rows <- report[feature != "x_strong"]
  expect_equal(strong_row$mean_rank, 1)
  expect_equal(strong_row$sd_rank, 0)
  expect_equal(strong_row$topk_share, 1)
  # Im Mittel sollten die Rauschen-Features eine deutlich hoehere
  # Rang-Streuung haben als das durchgehend dominante Signal-Feature -
  # einzelne Ausreisser (siehe Kommentar oben) sind erwartbar und kein
  # Fehlschlag.
  expect_gt(mean(noise_rows$sd_rank), strong_row$sd_rank)
})
