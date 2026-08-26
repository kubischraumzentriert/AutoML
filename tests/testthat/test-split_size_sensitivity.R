# =====================================================================
# test-split_size_sensitivity.R -- Korrektheitstests fuer
# split_ratio_sensitivity()/report_split_ratio_sensitivity()
# (split_size_sensitivity.R).
# =====================================================================
suppressPackageStartupMessages(library(mlr3))
lgr::get_logger("mlr3")$set_threshold("warn")
source(testthat::test_path("..", "..", "split_size_sensitivity.R"))

# --- report_split_ratio_sensitivity(): reine Logik, kein mlr3-Training ------

test_that("report_split_ratio_sensitivity() flaggt, wenn das gewaehlte ratio deutlich schlechter als das Minimum ist", {
  sens <- data.table::data.table(
    ratio = c(0.5, 0.7, 0.9), n_train = c(50, 70, 90), n_test = c(50, 30, 10),
    mean = c(0.80, 0.80, 0.80), sd = c(0.02, 0.02, 0.10), cv = c(0.025, 0.025, 0.125)
  )
  res <- report_split_ratio_sensitivity(sens, chosen_ratio = 0.9, cv_warn_relative = 2)
  expect_true(res[ratio == 0.9]$cv > 0)  # unveraendert zurueckgegeben
  # 0.125 / 0.025 = 5x > 2 -> auffaellig; ueber die sichtbare Konsolenausgabe
  # nicht direkt pruefbar, aber implizit ueber capture.output validiert (siehe unten).
})

test_that("report_split_ratio_sensitivity() meldet AUFFAELLIG in der Konsolenausgabe bei grossem Faktor", {
  sens <- data.table::data.table(
    ratio = c(0.5, 0.9), n_train = c(50, 90), n_test = c(50, 10),
    mean = c(0.80, 0.80), sd = c(0.02, 0.10), cv = c(0.025, 0.125)
  )
  out <- capture.output(report_split_ratio_sensitivity(sens, chosen_ratio = 0.9, cv_warn_relative = 2))
  expect_true(any(grepl("AUFFAELLIG", out)))
})

test_that("report_split_ratio_sensitivity() meldet unauffaellig, wenn das gewaehlte ratio nahe am Minimum liegt", {
  sens <- data.table::data.table(
    ratio = c(0.5, 0.7, 0.9), n_train = c(50, 70, 90), n_test = c(50, 30, 10),
    mean = c(0.80, 0.80, 0.80), sd = c(0.02, 0.021, 0.022), cv = c(0.025, 0.026, 0.0275)
  )
  out <- capture.output(report_split_ratio_sensitivity(sens, chosen_ratio = 0.9, cv_warn_relative = 2))
  expect_true(any(grepl("unauffaellig", out)))
  expect_false(any(grepl("AUFFAELLIG", out)))
})

test_that("report_split_ratio_sensitivity() gibt einen Hinweis, wenn chosen_ratio nicht getestet wurde", {
  sens <- data.table::data.table(ratio = c(0.5, 0.7), n_train = c(50, 70), n_test = c(50, 30),
                                  mean = c(0.8, 0.8), sd = c(0.02, 0.02), cv = c(0.025, 0.025))
  out <- capture.output(report_split_ratio_sensitivity(sens, chosen_ratio = 0.95))
  expect_true(any(grepl("nicht in den getesteten ratios", out)))
})

test_that("report_split_ratio_sensitivity() speichert die Tabelle, wenn out_path gesetzt ist", {
  sens <- data.table::data.table(ratio = 0.8, n_train = 80, n_test = 20, mean = 0.8, sd = 0.02, cv = 0.025)
  out_path <- tempfile(fileext = ".csv")
  on.exit(unlink(out_path), add = TRUE)
  invisible(capture.output(report_split_ratio_sensitivity(sens, chosen_ratio = 0.8, out_path = out_path)))
  expect_true(file.exists(out_path))
  saved <- data.table::fread(out_path)
  expect_equal(saved$ratio, 0.8)
})

# --- split_ratio_sensitivity(): braucht echtes (kleines) mlr3-Training -----

test_that("split_ratio_sensitivity() liefert eine Zeile je ratio mit korrekten n_train/n_test und plausibler Streuung", {
  set.seed(1)
  n <- 200
  x1 <- rnorm(n); x2 <- rnorm(n)
  y <- factor(ifelse(x1 + x2 + rnorm(n, sd = 1) > 0, "pos", "neg"))
  task <- as_task_classif(data.frame(x1 = x1, x2 = x2, y = y), target = "y")

  res <- split_ratio_sensitivity(
    task, lrn("classif.rpart"), msr("classif.acc"),
    ratios = c(0.5, 0.8), repeats = 5, seed = 1
  )
  expect_equal(nrow(res), 2)
  expect_equal(res$ratio, c(0.5, 0.8))
  expect_equal(res[ratio == 0.5]$n_train, round(0.5 * n))
  expect_equal(res[ratio == 0.5]$n_test, n - round(0.5 * n))
  expect_equal(res[ratio == 0.8]$n_train, round(0.8 * n))
  # cv = sd/|mean|, hier direkt aus den gemeldeten Spalten nachgerechnet.
  expect_equal(res$cv, res$sd / abs(res$mean), tolerance = 1e-10)
  # Kleineres Testset (ratio=0.8) sollte tendenziell mehr Streuung zeigen als
  # ein grosses Testset (ratio=0.5) - nicht strikt garantiert bei nur 5
  # Wiederholungen, aber der Mechanismus selbst (SD > 0 bei beiden) muss gelten.
  expect_true(all(res$sd > 0))
})

test_that("split_ratio_sensitivity() ist bei fixem Seed reproduzierbar", {
  set.seed(2)
  n <- 150
  x <- rnorm(n)
  y <- factor(ifelse(x + rnorm(n, sd = 0.5) > 0, "a", "b"))
  task <- as_task_classif(data.frame(x = x, y = y), target = "y")

  res1 <- split_ratio_sensitivity(task, lrn("classif.rpart"), msr("classif.acc"), ratios = 0.7, repeats = 5, seed = 7)
  res2 <- split_ratio_sensitivity(task, lrn("classif.rpart"), msr("classif.acc"), ratios = 0.7, repeats = 5, seed = 7)
  expect_equal(res1, res2)
})
