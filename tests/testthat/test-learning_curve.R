# =====================================================================
# test-learning_curve.R -- Korrektheitstests fuer learning_curve()/
# report_learning_curve() (learning_curve.R).
# =====================================================================
# Mehrere Faelle bauen die im Kopfkommentar dokumentierten realen Bugfixes
# als synthetische Regressionstests nach (IQR statt volle Spannweite gegen
# einen Ausreisser bei winzigem n, min_rows_per_fold-Filter gegen einen
# unzuverlaessigen Frueh-Punkt - siehe TARGETS.md fuer die Originalbefunde
# openml-credit-g/wdbc-plateau-test).
suppressPackageStartupMessages(library(mlr3))
lgr::get_logger("mlr3")$set_threshold("warn")
source(testthat::test_path("..", "..", "learning_curve.R"))

# --- report_learning_curve(): reine Logik, kein mlr3-Training noetig -------

test_that("report_learning_curve() erkennt ein klares PLATEAU (reines Rauschen um einen fixen Mittelwert)", {
  # Kein Trend ueber n - val_score schwankt nur durch Rauschen um 0.90.
  set.seed(1)
  lc <- data.table::data.table(
    fraction = seq(1, 7) / 7, n = c(50, 100, 200, 400, 800, 1600, 3200),
    train_score = 0.99, val_score = 0.90 + rnorm(7, sd = 0.003)
  )
  out <- capture.output(res <- report_learning_curve(lc, cv_folds = NULL, min_rows_per_fold = NULL))
  expect_true(any(grepl("=> PLATEAU", out)))
  expect_false(any(grepl("NOCH STEIGEND", out)))
})

test_that("report_learning_curve() erkennt eine klar NOCH STEIGENDE Kurve", {
  lc <- data.table::data.table(
    fraction = c(0.1, 0.2, 0.4, 0.8, 1.0), n = c(50, 100, 200, 400, 500),
    train_score = c(0.99, 0.99, 0.99, 0.99, 0.99),
    val_score = c(0.50, 0.60, 0.70, 0.82, 0.90)  # gleichmaessig steigend
  )
  out <- capture.output(res <- report_learning_curve(lc, cv_folds = NULL, min_rows_per_fold = NULL))
  expect_true(any(grepl("NOCH STEIGEND", out)))
  expect_false(any(grepl("=> PLATEAU", out)))
})

test_that("report_learning_curve() laesst sich durch einen einzelnen Ausreisser bei winzigem n NICHT taeuschen (IQR- statt Range-Fix, openml-credit-g-Muster)", {
  # Kalibriert (siehe Herleitung im PR/Commit): ein extremer Einbruch beim
  # winzigsten n zusammen mit einer frueh saettigenden Kurve druecken
  # gain/VOLLE-SPANNWEITE unter die 10%-Schwelle (waere also PLATEAU),
  # waehrend gain/IQR klar darueber bleibt (korrekt NOCH STEIGEND) - exakt
  # die im Kopfkommentar dokumentierte Bug-Signatur (openml-credit-g: ein
  # Einbruch bei n=20 liess einen tatsaechlich noch steigenden Trend
  # faelschlich als PLATEAU erscheinen).
  n <- c(10, 200, 400, 800, 1600, 3200, 6400, 12800)
  val_score <- c(0.01, 0.85, 0.86, 0.865, 0.868, 0.870, 0.871, 0.872)
  lc <- data.table::data.table(fraction = seq_along(n) / length(n), n = n,
                                train_score = 0.99, val_score = val_score)

  # Gegenprobe: mit der VOLLEN Spannweite als Nenner (die urspruengliche,
  # fehlerhafte Variante) waere die Klassifikation PLATEAU gewesen - bestaetigt,
  # dass dieser Testfall die Bug-Signatur tatsaechlich trifft, nicht nur zufaellig
  # "NOCH STEIGEND" liefert.
  fit <- lm(val_score ~ log(n))
  gain_per_doubling <- unname(coef(fit)["log(n)"]) * log(2)
  expect_lt(gain_per_doubling / (max(val_score) - min(val_score)), 0.10)
  expect_gt(gain_per_doubling / IQR(val_score), 0.10)

  out <- capture.output(res <- report_learning_curve(lc, cv_folds = NULL, min_rows_per_fold = NULL))
  expect_true(any(grepl("NOCH STEIGEND", out)))
  expect_false(any(grepl("=> PLATEAU", out)))
})

test_that("report_learning_curve() schliesst Punkte mit zu wenig Zeilen/Fold VOR der Regression aus (min_rows_per_fold-Fix, wdbc-plateau-test-Muster)", {
  # Fruehe Saettigung (Punkte 2-9 praktisch identisch, reines Rauschen um
  # ~0.95), aber ein winziger erster Punkt (n=6 bei 3 Folds -> 2 Zeilen/Fold,
  # val_score 0.72) soll aus der Regression ausgeschlossen werden, weil er
  # unzuverlaessig ist - sonst wuerde er einen Trend vortaeuschen, den es
  # unter den zuverlaessigen Punkten gar nicht gibt (kalibriert, seed=14).
  set.seed(14)
  n_all <- c(6, 68, 200, 400, 680, 1200, 2000, 3400, 5000)
  lc <- data.table::data.table(
    fraction = seq_along(n_all) / length(n_all), n = n_all, train_score = 0.99,
    val_score = c(0.72, 0.95 + rnorm(8, sd = 0.0015))
  )
  out <- capture.output(res <- report_learning_curve(lc, cv_folds = 3, min_rows_per_fold = 10))
  expect_true(any(grepl("ausgeschlossen", out)))
  expect_true(any(grepl("=> PLATEAU", out)))
})

test_that("report_learning_curve() gibt einen Hinweis statt abzustuerzen, wenn nach dem Filter < 3 Punkte uebrig bleiben", {
  lc <- data.table::data.table(fraction = c(0.01, 0.02), n = c(4, 8), train_score = c(0.9, 0.9), val_score = c(0.5, 0.6))
  out <- capture.output(res <- report_learning_curve(lc, cv_folds = NULL, min_rows_per_fold = NULL))
  expect_true(any(grepl("mindestens 3 fractions", out)))
})

test_that("report_learning_curve() speichert die volle (ungefilterte) Tabelle unter out_path", {
  lc <- data.table::data.table(
    fraction = c(0.2, 0.5, 1.0), n = c(20, 50, 100),
    train_score = c(0.9, 0.9, 0.9), val_score = c(0.5, 0.6, 0.7)
  )
  out_path <- tempfile(fileext = ".csv")
  on.exit(unlink(out_path), add = TRUE)
  invisible(capture.output(report_learning_curve(lc, out_path = out_path, cv_folds = NULL, min_rows_per_fold = NULL)))
  saved <- data.table::fread(out_path)
  expect_equal(nrow(saved), 3)
})

# --- learning_curve(): braucht echtes (kleines) mlr3-Training --------------

test_that("learning_curve() liefert eine Zeile je fraction mit wachsendem n und plausiblen Scores", {
  set.seed(1)
  n <- 300
  x1 <- rnorm(n); x2 <- rnorm(n)
  y <- factor(ifelse(x1 + x2 + rnorm(n, sd = 1) > 0, "pos", "neg"))
  task <- as_task_classif(data.frame(x1 = x1, x2 = x2, y = y), target = "y")

  res <- learning_curve(task, lrn("classif.rpart"), msr("classif.acc"),
                         fractions = c(0.3, 1.0), cv_folds = 3, repeats = 2, seed = 1)
  expect_equal(nrow(res), 2)
  expect_true(res[fraction == 1.0]$n > res[fraction == 0.3]$n)
  expect_true(all(res$val_score >= 0 & res$val_score <= 1))
  expect_true(all(res$train_score >= 0 & res$train_score <= 1))
})

test_that("learning_curve() ist bei fixem Seed reproduzierbar", {
  set.seed(2)
  n <- 200
  x <- rnorm(n)
  y <- factor(ifelse(x + rnorm(n, sd = 0.5) > 0, "a", "b"))
  task <- as_task_classif(data.frame(x = x, y = y), target = "y")

  res1 <- learning_curve(task, lrn("classif.rpart"), msr("classif.acc"), fractions = 0.5, cv_folds = 3, repeats = 2, seed = 9)
  res2 <- learning_curve(task, lrn("classif.rpart"), msr("classif.acc"), fractions = 0.5, cv_folds = 3, repeats = 2, seed = 9)
  expect_equal(res1, res2)
})
