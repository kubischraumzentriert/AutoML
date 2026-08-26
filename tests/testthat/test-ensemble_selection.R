# =====================================================================
# test-ensemble_selection.R -- Korrektheitstests fuer
# greedy_ensemble_selection()/.bacc_from_probs() (ensemble_selection.R).
# =====================================================================
# Kernszenario nach dem im externen Review vorgeschlagenen Muster:
# Kandidat A stark, B schwaecher aber komplementaer, C reines Rauschen ->
# A/B sollen gewaehlt werden, C soll (praktisch) kein Gewicht bekommen.
suppressPackageStartupMessages(library(mlr3measures))
source(testthat::test_path("..", "..", "ensemble_selection.R"))

class_names <- c("pos", "neg")

make_truth_and_probs <- function(n, seed) {
  set.seed(seed)
  truth <- factor(sample(class_names, n, replace = TRUE), levels = class_names)
  list(truth = truth, n = n)
}

# Wahrscheinlichkeitsmatrix, die mit Wahrscheinlichkeit `p_correct` die
# wahre Klasse stark bevorzugt, sonst zufaellig rauscht - p_correct=1
# entspricht einem (fast) perfekten Modell. WICHTIG: der "sonst"-Zweig
# rauscht rein zufaellig OHNE jeden Bezug zu `truth` (0.5/0.5) - bei
# p_correct=0.5 also ein Modell, das nur bei der Haelfte der Zeilen
# ueberhaupt Signal zeigt, bei der anderen Haelfte reines Rauschen ist
# (NICHT zu verwechseln mit "immer nur maessig richtig").
make_probs <- function(truth, p_correct, seed) {
  set.seed(seed)
  n <- length(truth)
  m <- matrix(0.5, nrow = n, ncol = 2, dimnames = list(NULL, class_names))
  hit <- runif(n) < p_correct
  for (i in seq_len(n)) {
    if (hit[i]) {
      m[i, as.character(truth[i])] <- 0.9
      m[i, setdiff(class_names, as.character(truth[i]))] <- 0.1
    } else {
      m[i, ] <- c(0.5, 0.5)
    }
  }
  m
}

# Echtes Rauschen: Wahrscheinlichkeiten VOELLIG unabhaengig von `truth` -
# zufaellige (aber gueltige) Verteilungen ohne jeden Bezug zur Zielklasse.
make_noise_probs <- function(truth, seed) {
  set.seed(seed)
  n <- length(truth)
  m <- matrix(runif(n * 2, 0.2, 0.8), nrow = n, ncol = 2, dimnames = list(NULL, class_names))
  m / rowSums(m)
}

test_that(".bacc_from_probs() liefert BAcc=1 bei perfekter Vorhersage", {
  truth <- factor(c("pos", "pos", "neg", "neg"), levels = class_names)
  probs <- matrix(c(0.9, 0.9, 0.1, 0.1, 0.1, 0.1, 0.9, 0.9), nrow = 4,
                   dimnames = list(NULL, class_names))
  expect_equal(.bacc_from_probs(probs, truth, class_names), 1)
})

test_that("greedy_ensemble_selection() waehlt starke/komplementaere Modelle, meidet reines Rauschen", {
  # Realistischer nachgebaut als ein 148_ensemble_candidate_pool.R-Pool:
  # mehrere Varianten eines starken (A1-A3) und eines schwaecheren, aber
  # eigenstaendig informativen Kandidaten (B1-B2), plus GENAU EIN reiner
  # Rauschkandidat (voellig unabhaengig von `truth`, siehe make_noise_probs()).
  td <- make_truth_and_probs(1000, seed = 1)
  truth <- td$truth

  probs_list <- list(
    A1 = make_probs(truth, p_correct = 0.9, seed = 10),
    A2 = make_probs(truth, p_correct = 0.9, seed = 11),
    A3 = make_probs(truth, p_correct = 0.9, seed = 12),
    B1 = make_probs(truth, p_correct = 0.7, seed = 20),
    B2 = make_probs(truth, p_correct = 0.7, seed = 21),
    C_noise = make_noise_probs(truth, seed = 30)
  )
  res <- greedy_ensemble_selection(probs_list, truth, class_names, rounds = 50)
  counts <- table(names(probs_list)[res$selected])

  # Mindestens einer der starken A-Kandidaten muss gewaehlt werden.
  expect_true(any(c("A1", "A2", "A3") %in% names(counts)))
  # Reines Rauschen darf UEBERHAUPT NICHT gewaehlt werden.
  expect_false("C_noise" %in% names(counts))
})

test_that("greedy_ensemble_selection() bevorzugt bei identischen Kandidaten irrelevant welchen (Tie-Break deterministisch)", {
  td <- make_truth_and_probs(100, seed = 2)
  truth <- td$truth
  probs <- make_probs(truth, p_correct = 0.8, seed = 40)
  probs_list <- list(A = probs, B = probs)  # zwei IDENTISCHE Kandidaten
  res1 <- greedy_ensemble_selection(probs_list, truth, class_names, rounds = 5)
  res2 <- greedy_ensemble_selection(probs_list, truth, class_names, rounds = 5)
  expect_identical(res1$selected, res2$selected)  # deterministisch (kein Zufall in der Funktion selbst)
})

test_that("greedy_ensemble_selection() liefert nie eine schlechtere Selektions-BAcc als das beste Einzelmodell", {
  td <- make_truth_and_probs(300, seed = 3)
  truth <- td$truth
  probs_a <- make_probs(truth, p_correct = 0.9, seed = 50)
  probs_b <- make_probs(truth, p_correct = 0.5, seed = 60)
  best_single_bacc <- max(
    .bacc_from_probs(probs_a, truth, class_names),
    .bacc_from_probs(probs_b, truth, class_names)
  )
  res <- greedy_ensemble_selection(list(probs_a, probs_b), truth, class_names, rounds = 20)
  expect_gte(res$best_bacc, best_single_bacc)
})

test_that("greedy_ensemble_selection() funktioniert mit eigenem metric_fn auf einem Wahrscheinlichkeits-VEKTOR (binaeres AUC)", {
  # Reales Vorbild: predictingsmartphoneAddiction_s6e8/149_ensemble_selection.R
  # nutzt AUC auf P(positive_class) statt Multiclass-BAcc auf einer Matrix -
  # derselbe Algorithmus, andere Zielmetrik/Datenform.
  set.seed(5)
  n <- 500
  truth <- factor(sample(c("yes", "no"), n, replace = TRUE), levels = c("yes", "no"))

  make_auc_probs <- function(strength, seed) {
    set.seed(seed)
    score <- ifelse(truth == "yes", 1, 0) * strength + rnorm(n, sd = 1 - strength * 0.5)
    (score - min(score)) / (max(score) - min(score))
  }
  probs_strong <- make_auc_probs(0.9, seed = 100)
  probs_weak <- make_auc_probs(0.3, seed = 200)

  auc_fn <- function(p, t) mlr3measures::auc(t, p, positive = "yes")
  best_single_auc <- max(auc_fn(probs_strong, truth), auc_fn(probs_weak, truth))

  res <- greedy_ensemble_selection(
    list(strong = probs_strong, weak = probs_weak), truth,
    metric_fn = auc_fn, rounds = 20
  )
  expect_gte(res$best_bacc, best_single_auc)
  expect_true(1 %in% res$selected)  # der starke Kandidat (Index 1) muss gezogen werden
})

test_that("greedy_ensemble_selection() gibt verstaendliche Fehlermeldungen bei ungueltigen Argumenten (P0.2-Haertung)", {
  expect_error(greedy_ensemble_selection(list(), factor("a"), rounds = 5), "probs_list darf nicht leer sein")
  expect_error(
    greedy_ensemble_selection(list(matrix(1)), factor("a"), rounds = 0),
    "rounds muss mindestens 1 sein"
  )
  expect_error(
    greedy_ensemble_selection(list(matrix(1)), factor("a"), class_names = NULL, rounds = 1),
    "class_names ist erforderlich"
  )
})
