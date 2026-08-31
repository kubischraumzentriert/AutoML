# =====================================================================
# test-hard_split_stress_test.R -- Korrektheitstests fuer
# cluster_based_hard_split()/random_split_score_distribution()/
# hard_split_stress_test() (hard_split_stress_test.R), synthetisch auf
# konstruierten Faellen mit BEKANNTEM Extrapolationsverhalten, bevor
# irgendein echter Lauf damit gemacht wird (siehe JOSS_TECHNIQUE_
# WATCH.md, "kleiner Prototyp -> synthetischer Test -> 1-2 reale
# Projekte").
# =====================================================================
source(testthat::test_path("..", "..", "hard_split_stress_test.R"))

suppressPackageStartupMessages(library(mlr3))

make_two_cluster_task <- function(flip_relationship, n_per_cluster = 150, seed = 1) {
  set.seed(seed)
  # x1/x2 definieren NUR die Cluster-Struktur (A um (0,0), B um (10,10)),
  # klar getrennt im Feature-Raum. x3 ist eine dritte, VON DER CLUSTER-
  # ZUGEHOERIGKEIT UNABHAENGIGE Variable (N(0,1) unabhaengig vom Cluster) -
  # nur sie bestimmt die Zielvariable, damit die Regel absolut (nicht
  # cluster-relativ) ist und ein auf einem Cluster trainierter Baum sie
  # bei ECHTER Generalisierung korrekt uebertragen kann.
  x1 <- c(rnorm(n_per_cluster, 0, 1), rnorm(n_per_cluster, 10, 1))
  x2 <- c(rnorm(n_per_cluster, 0, 1), rnorm(n_per_cluster, 10, 1))
  x3 <- rnorm(2 * n_per_cluster, 0, 1)
  cluster <- rep(c("A", "B"), each = n_per_cluster)

  # Ohne flip: target = (x3 > 0) in BEIDEN Clustern identisch -> ein auf A
  # trainierter Baum lernt "x3>0 -> pos" und dieselbe Regel gilt fuer B
  # (echte Generalisierung, kein Extrapolationsrisiko erwartet).
  # Mit flip: in Cluster B ist die Regel UMGEKEHRT (x3<0 -> pos) - ein auf
  # A trainierter Baum hat dieses Muster nie gesehen und wendet die FALSCHE
  # Regel auf B an (garantiertes Extrapolationsversagen erwartet).
  rule_b_flipped <- if (flip_relationship) x3 < 0 else x3 > 0
  y <- ifelse(cluster == "A", ifelse(x3 > 0, "pos", "neg"), ifelse(rule_b_flipped, "pos", "neg"))

  dt <- data.table::data.table(x1 = x1, x2 = x2, x3 = x3, target = factor(y, levels = c("neg", "pos")))
  TaskClassif$new(id = "synth_cluster", backend = dt, target = "target")
}

test_that("cluster_based_hard_split() trennt die beiden klar getrennten Cluster korrekt (kleineres Cluster = Test)", {
  # Absichtlich UNGLEICHE Clustergroessen, damit "kleinstes Cluster" eindeutig ist
  set.seed(1)
  x1 <- c(rnorm(100, 0, 1), rnorm(40, 10, 1))
  x2 <- c(rnorm(100, 0, 1), rnorm(40, 10, 1))
  cluster_true <- rep(c("A", "B"), c(100, 40))
  dt <- data.table::data.table(x1 = x1, x2 = x2, target = factor(sample(c("pos", "neg"), 140, replace = TRUE)))
  task <- TaskClassif$new(id = "synth", backend = dt, target = "target")

  split <- cluster_based_hard_split(task, k = 2, seed = 1)
  expect_equal(length(split$train) + length(split$test), 140)
  expect_equal(length(intersect(split$train, split$test)), 0)
  # Das Test-Set sollte ueberwiegend aus dem kleineren, echten Cluster B stammen
  test_is_cluster_b <- mean(cluster_true[split$test] == "B") > 0.8
  expect_true(test_is_cluster_b)
  expect_equal(split$test_ratio, length(split$test) / 140)
})

test_that("hard_split_stress_test() FLAGGT ein garantiertes Extrapolationsversagen (umgekehrte Regel in Cluster B)", {
  task <- make_two_cluster_task(flip_relationship = TRUE, seed = 42)
  learner_ctor <- function() lrn("classif.rpart")
  measure <- msr("classif.acc")

  out <- capture.output(
    res <- hard_split_stress_test(task, learner_ctor, measure, k = 2, n_repeats = 10, seed = 1, label = "test-flip")
  )
  expect_true(res$flagged)
  expect_lt(res$z, -2)
  # Score auf dem harten Split sollte deutlich schlechter als der Referenzbereich sein
  expect_lt(res$hard_score, res$ref_mean)
})

test_that("hard_split_stress_test() flaggt NICHT, wenn dieselbe Regel in beiden Clustern gilt (echte Generalisierung)", {
  task <- make_two_cluster_task(flip_relationship = FALSE, seed = 42)
  learner_ctor <- function() lrn("classif.rpart")
  measure <- msr("classif.acc")

  out <- capture.output(
    res <- hard_split_stress_test(task, learner_ctor, measure, k = 2, n_repeats = 10, seed = 1, label = "test-noflip")
  )
  expect_false(res$flagged)
  expect_gt(res$z, -2)
})

test_that("random_split_score_distribution() liefert n_repeats Scores mit plausibler Testgroesse", {
  task <- make_two_cluster_task(flip_relationship = FALSE, seed = 7)
  learner_ctor <- function() lrn("classif.rpart")
  measure <- msr("classif.acc")

  scores <- random_split_score_distribution(task, learner_ctor, measure, test_ratio = 0.3, n_repeats = 5, seed = 1)
  expect_equal(length(scores), 5)
  expect_true(all(scores >= 0 & scores <= 1))
})

test_that("cluster_based_hard_split() bricht kontrolliert ab, wenn keine numerischen Features vorhanden sind", {
  dt <- data.table::data.table(
    cat1 = factor(sample(c("a", "b"), 50, replace = TRUE)),
    target = factor(sample(c("pos", "neg"), 50, replace = TRUE))
  )
  task <- TaskClassif$new(id = "no_numeric", backend = dt, target = "target")
  expect_error(cluster_based_hard_split(task), "mindestens 1 numerisches Feature")
})
