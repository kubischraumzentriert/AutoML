# =====================================================================
# test-multilabel.R -- Korrektheitstests fuer multilabel.R (Metriken,
# Schwellenwertsuche, Binary Relevance, Classifier Chains).
# =====================================================================
suppressPackageStartupMessages({ library(mlr3); library(mlr3learners) })
lgr::get_logger("mlr3")$set_threshold("warn")
source(testthat::test_path("..", "..", "multilabel.R"))

# --- Multi-Label-Metriken: reine Funktionen, Ground Truth von Hand -------

test_that("hamming_loss() zaehlt den Anteil falscher (Zeile,Label)-Paare korrekt", {
  truth <- matrix(c(1, 0, 1, 0, 1, 1, 0, 0, 1, 1, 0, 0), nrow = 3)  # 3x4
  pred <- truth
  pred[1, 1] <- 0; pred[2, 3] <- 1  # 2 von 12 Zellen falsch
  expect_equal(hamming_loss(truth, pred), 2 / 12)
})

test_that("hamming_loss() ist 0 bei perfekter Uebereinstimmung und 1 bei komplett falscher Vorhersage", {
  truth <- matrix(c(1, 0, 0, 1), nrow = 2)
  expect_equal(hamming_loss(truth, truth), 0)
  expect_equal(hamming_loss(truth, 1L - truth), 1)
})

test_that("subset_accuracy() zaehlt nur Zeilen mit EXAKTER Uebereinstimmung ueber alle Labels", {
  truth <- matrix(c(1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 1, 1), nrow = 3)  # 3 Zeilen x 4 Labels
  pred <- truth
  pred[2, 1] <- 1 - pred[2, 1]  # Zeile 2 bekommt genau EINEN Fehler
  expect_equal(subset_accuracy(truth, pred), 2 / 3)  # Zeilen 1+3 exakt, Zeile 2 nicht
})

test_that("f1_binary() reproduziert Precision/Recall/F1 von Hand UND gibt 0 statt NaN bei tp=0", {
  truth <- c(1, 1, 1, 0, 0)
  pred <- c(1, 1, 0, 1, 0)  # tp=2, fp=1, fn=1
  precision <- 2 / 3; recall <- 2 / 3
  expected_f1 <- 2 * precision * recall / (precision + recall)
  expect_equal(f1_binary(truth, pred), expected_f1, tolerance = 1e-10)

  expect_equal(f1_binary(c(1, 1, 1), c(0, 0, 0)), 0)  # tp=0 -> 0, nicht NaN
})

test_that("macro_f1() und micro_f1() unterscheiden sich bei unbalancierten Labelhaeufigkeiten (Makro gewichtet gleich, Mikro nach Haeufigkeit)", {
  # Label A: haeufig UND perfekt vorhergesagt (F1=1). Label B: selten UND
  # komplett falsch vorhergesagt (F1=0). Makro mittelt (1+0)/2=0.5 - Mikro
  # wird vom haeufigen, perfekten Label A dominiert und liegt naeher an 1.
  truth <- cbind(A = rep(1, 20), B = c(rep(1, 2), rep(0, 18)))
  pred <- cbind(A = rep(1, 20), B = c(rep(0, 2), rep(0, 18)))  # B: 2 FN, sonst TN
  expect_equal(macro_f1(truth, pred), 0.5)
  expect_gt(micro_f1(truth, pred), 0.9)  # von Label A dominiert
})

# --- Schwellenwertsuche: reine Funktionen -----------------------------------

test_that("accuracy_at_threshold() zaehlt Treffer bei einer gegebenen Schwelle korrekt", {
  prob <- c(0.1, 0.4, 0.6, 0.9)
  truth01 <- c(0, 0, 1, 1)
  expect_equal(accuracy_at_threshold(prob, truth01, 0.5), 1)  # alle 4 korrekt bei Schwelle 0.5
  expect_equal(accuracy_at_threshold(prob, truth01, 0.05), 0.5)  # alles als "1" vorhergesagt -> nur die 2 echten 1en korrekt
})

test_that("tune_threshold_accuracy() findet die Grid-optimale Schwelle (Ground Truth konstruiert)", {
  set.seed(1)
  truth01 <- rep(c(0, 1), each = 50)
  # Wahrscheinlichkeiten klar um 0.3 (Klasse 0) bzw. 0.7 (Klasse 1) getrennt -
  # jede Schwelle zwischen 0.4 und 0.6 sollte optimal (Accuracy=1) sein.
  prob <- c(rnorm(50, mean = 0.3, sd = 0.02), rnorm(50, mean = 0.7, sd = 0.02))
  best <- tune_threshold_accuracy(prob, truth01, threshold_grid = seq(0.1, 0.9, by = 0.1))
  expect_true(best >= 0.4 && best <= 0.6)
  expect_equal(accuracy_at_threshold(prob, truth01, best), 1)
})

# --- binary_relevance_pool(): braucht echtes mlr3-Training ------------------

make_multilabel_dt <- function(n = 200, seed = 1) {
  set.seed(seed)
  x1 <- rnorm(n); x2 <- rnorm(n)
  data.table::data.table(
    id = seq_len(n), x1 = x1, x2 = x2,
    label_a = as.integer(x1 > 0),          # haengt NUR von x1 ab
    label_b = as.integer(x2 > 0)           # haengt NUR von x2 ab
  )
}

test_that("binary_relevance_pool() liefert je Label unabhaengige Wahrscheinlichkeiten, benannt nach row_id", {
  dt <- make_multilabel_dt()
  train_ids <- 1:150; eval_ids <- 151:200
  res <- binary_relevance_pool(
    dt, feature_cols = c("x1", "x2"), label_cols = c("label_a", "label_b"),
    train_ids = train_ids, predict_ids_list = list(eval = eval_ids),
    learner_constructor = function() lrn("classif.ranger", predict_type = "prob", num.trees = 50)
  )
  expect_named(res$probs, c("label_a", "label_b"))
  expect_named(res$probs$label_a, "eval")
  expect_length(res$probs$label_a$eval, length(eval_ids))
  expect_equal(names(res$probs$label_a$eval), as.character(eval_ids))
  # Je Label wurde ein EIGENER Learner trainiert (2 verschiedene Objekte).
  expect_false(identical(res$learners$label_a, res$learners$label_b))
})

test_that("binary_relevance_pool() maskiert NA-Labels korrekt: NA-Zeilen werden pro Label ausgeschlossen, nicht nur beim Training", {
  dt <- make_multilabel_dt()
  # label_a fuer die Haelfte der Eval-Zeilen absichtlich unbekannt (NA) -
  # simuliert tox21-artige echte fehlende Labels.
  eval_ids <- 151:200
  na_ids <- eval_ids[1:10]
  dt[id %in% na_ids, label_a := NA_integer_]

  res <- binary_relevance_pool(
    dt, feature_cols = c("x1", "x2"), label_cols = c("label_a", "label_b"),
    train_ids = 1:150, predict_ids_list = list(eval = eval_ids),
    learner_constructor = function() lrn("classif.ranger", predict_type = "prob", num.trees = 50)
  )
  # label_a: NA-Zeilen fehlen im Ergebnis (50 - 10 = 40 statt 50).
  expect_length(res$probs$label_a$eval, length(eval_ids) - length(na_ids))
  expect_false(any(na_ids %in% as.integer(names(res$probs$label_a$eval))))
  # label_b: KEINE NAs -> vollstaendig, No-op-Verhalten (wie bei yeast/scene/birds).
  expect_length(res$probs$label_b$eval, length(eval_ids))
})

test_that("binary_relevance_pool() ist bei fixem Seed reproduzierbar", {
  dt <- make_multilabel_dt()
  args <- list(
    dt = dt, feature_cols = c("x1", "x2"), label_cols = "label_a",
    train_ids = 1:150, predict_ids_list = list(eval = 151:200),
    learner_constructor = function() lrn("classif.ranger", predict_type = "prob", num.trees = 20, seed = 1),
    seed = 42
  )
  res1 <- do.call(binary_relevance_pool, args)
  res2 <- do.call(binary_relevance_pool, args)
  expect_equal(res1$probs, res2$probs)
})

# --- classifier_chain_pool(): braucht echtes mlr3-Training ------------------

test_that("classifier_chain_pool() liefert Schwellenwerte und geschwellte Vorhersagen fuer jedes Label in der Kette", {
  dt <- make_multilabel_dt()
  res <- classifier_chain_pool(
    dt, feature_cols = c("x1", "x2"), chain_order = c("label_a", "label_b"),
    train_ids = 1:120, tune_ids = 121:160, eval_ids = 161:200,
    learner_constructor = function() lrn("classif.ranger", predict_type = "prob", num.trees = 50),
    threshold_grid = seq(0.3, 0.7, by = 0.1)
  )
  expect_named(res$thresholds, c("label_a", "label_b"))
  expect_named(res$pred_eval01, c("label_a", "label_b"))
  expect_length(res$pred_eval01$label_a, 40)
  expect_true(all(res$pred_eval01$label_a %in% c(0L, 1L)))
})
