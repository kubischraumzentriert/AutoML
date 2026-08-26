# =====================================================================
# test-seed_stability.R -- Korrektheitstests fuer seed_stability()/
# hyperparam_jitter_stability()/report_stability() (seed_stability.R).
# =====================================================================
suppressPackageStartupMessages({
  library(mlr3)
  library(mlr3learners)
})
source(testthat::test_path("..", "..", "seed_stability.R"))

# --- report_stability(): reine Statistik, kein mlr3-Training noetig --------

test_that("report_stability() flaggt, wenn die Eigen-Streuung die CV-Referenz-Streuung uebersteigt", {
  own_scores <- c(0.5, 0.9, 0.3, 0.8, 0.4)  # grosse Streuung
  cv_scores <- c(0.70, 0.71, 0.69, 0.70, 0.705)  # kleine Streuung (Referenz)
  res <- report_stability("test_gross", own_scores, cv_scores, cv_warn_relative = 0.5)
  expect_true(res$flagged)
  expect_gt(res$relative, 0.5)
})

test_that("report_stability() flaggt NICHT, wenn die Eigen-Streuung klein gegenueber der CV-Referenz ist", {
  own_scores <- c(0.700, 0.701, 0.699, 0.700, 0.7005)  # kleine Streuung
  cv_scores <- c(0.5, 0.9, 0.3, 0.8, 0.4)  # grosse Streuung (Referenz)
  res <- report_stability("test_klein", own_scores, cv_scores, cv_warn_relative = 0.5)
  expect_false(res$flagged)
  expect_lt(res$relative, 0.5)
})

test_that("report_stability() liefert NA statt Division durch 0 bei konstanter CV-Referenz", {
  res <- report_stability("test_konstant", c(0.1, 0.2, 0.3), rep(0.7, 5))
  expect_true(is.na(res$relative))
  expect_false(res$flagged)  # NA darf NICHT als "auffaellig" durchrutschen
})

test_that("report_stability() respektiert einen custom cv_warn_relative-Schwellenwert", {
  own_scores <- c(0.60, 0.65, 0.62)
  cv_scores <- c(0.60, 0.70, 0.65)
  res_locker <- report_stability("a", own_scores, cv_scores, cv_warn_relative = 5)
  res_streng <- report_stability("b", own_scores, cv_scores, cv_warn_relative = 0.01)
  expect_false(res_locker$flagged)
  expect_true(res_streng$flagged)
})

test_that("report_stability() haengt bei wiederholtem Aufruf mit demselben out_path an, statt zu ueberschreiben", {
  out_path <- tempfile(fileext = ".csv")
  on.exit(unlink(out_path), add = TRUE)
  invisible(capture.output(report_stability("erster", c(1, 2, 3), c(1, 1, 1), out_path)))
  invisible(capture.output(report_stability("zweiter", c(1, 2, 3), c(1, 1, 1), out_path)))
  saved <- data.table::fread(out_path)
  expect_equal(nrow(saved), 2)
  expect_equal(saved$check, c("erster", "zweiter"))
})

# --- seed_stability(): braucht echte mlr3-Learner (variiert nur der Seed) --

make_tiny_task <- function() {
  set.seed(1)
  n <- 120
  x1 <- rnorm(n); x2 <- rnorm(n)
  y <- factor(ifelse(x1 + x2 + rnorm(n, sd = 1.5) > 0, "pos", "neg"))
  as_task_classif(data.frame(x1 = x1, x2 = x2, y = y), target = "y")
}

test_that("seed_stability() zeigt SD=0 bei einem seed-UNEMPFINDLICHEN Lerner (Spezifitaet)", {
  task <- make_tiny_task()
  scores <- seed_stability(
    task, task, learner_constructor = function(s) lrn("classif.rpart"),  # ignoriert s
    measure = msr("classif.acc"), n_seeds = 4, seed = 1
  )
  expect_length(scores, 4)
  expect_equal(sd(scores), 0)
})

test_that("seed_stability() zeigt SD>0 bei einem seed-EMPFINDLICHEN Lerner (Ranger)", {
  task <- make_tiny_task()
  scores <- seed_stability(
    task, task,
    learner_constructor = function(s) lrn("classif.ranger", num.trees = 5, seed = s),
    measure = msr("classif.acc"), n_seeds = 5, seed = 1
  )
  expect_length(scores, 5)
  expect_gt(sd(scores), 0)
})

# --- hyperparam_jitter_stability(): Plumbing pruefen (Werte korrekt gezogen,
# Scores je Zug berechnet) -----------------------------------------------

test_that("hyperparam_jitter_stability() zieht die konfigurierten Parameter und liefert einen Score je Zug", {
  task <- make_tiny_task()
  res <- hyperparam_jitter_stability(
    task, task,
    base_params = list(cp = 0.05),
    jitter_fns = list(cp = function(v) v * c(0.5, 1, 1.5, 2, 2.5)[sample.int(5, 1)]),
    learner_ctor = function(p) lrn("classif.rpart", cp = p$cp),
    measure = msr("classif.acc"), n_jitter = 6, seed = 1
  )
  expect_length(res$scores, 6)
  expect_equal(nrow(res$params), 6)
  expect_true(all(res$params$cp > 0))
  expect_true(all(res$scores >= 0 & res$scores <= 1))
})

test_that("hyperparam_jitter_stability() ist bei fixem Seed reproduzierbar", {
  task <- make_tiny_task()
  args <- list(
    task_train = task, task_test = task, base_params = list(cp = 0.05),
    jitter_fns = list(cp = function(v) v * runif(1, 0.5, 2)),
    learner_ctor = function(p) lrn("classif.rpart", cp = p$cp),
    measure = msr("classif.acc"), n_jitter = 5, seed = 42
  )
  res1 <- do.call(hyperparam_jitter_stability, args)
  res2 <- do.call(hyperparam_jitter_stability, args)
  expect_equal(res1$scores, res2$scores)
  expect_equal(res1$params$cp, res2$params$cp)
})
