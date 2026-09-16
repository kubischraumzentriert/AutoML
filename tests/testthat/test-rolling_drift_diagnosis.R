# =====================================================================
# test-rolling_drift_diagnosis.R -- Korrektheitstests fuer
# assign_time_windows()/rolling_univariate_drift()/drift_trend_test()
# (rolling_drift_diagnosis.R, BACKLOG.md-Kandidat 3). Identisch zu den
# manuellen Faellen im Regression-Template (test_rolling_drift_
# diagnosis.R), nur im hiesigen testthat-Stil.
# =====================================================================
source(testthat::test_path("..", "..", "univariate_drift.R"))
source(testthat::test_path("..", "..", "rolling_drift_diagnosis.R"))

test_that("assign_time_windows() teilt chronologisch korrekt und etwa gleich gross", {
  set.seed(1)
  n <- 1000
  time <- sample(seq_len(n))
  w <- assign_time_windows(time, k = 5L)
  expect_equal(length(unique(w)), 5L)
  expect_true(all(time[w == 1] <= 200))
  expect_true(all(time[w == 5] > 800))
  expect_lte(max(table(w)) - min(table(w)), 1)
})

test_that("rolling_univariate_drift()/drift_trend_test(): kein Drift -> kein Trend", {
  set.seed(2)
  n <- 5000
  dt <- data.table::data.table(time = seq_len(n), x = rnorm(n), y = rnorm(n))
  w <- assign_time_windows(dt$time, k = 6L)
  res <- rolling_univariate_drift(dt, w, feature_cols = c("x", "y"))
  trend <- drift_trend_test(res)
  expect_equal(nrow(res), 5L)
  expect_false(trend$trend_detected)
})

test_that("echter monotoner Trend wird erkannt (rho stark positiv)", {
  set.seed(3)
  n <- 6000
  time <- seq_len(n)
  dt <- data.table::data.table(time = time, x = time / n * 5 + rnorm(n, sd = 0.3))
  w <- assign_time_windows(dt$time, k = 6L)
  res <- rolling_univariate_drift(dt, w, feature_cols = "x")
  trend <- drift_trend_test(res)
  expect_true(all(diff(res$mean_effect_size) >= -0.05))
  expect_true(trend$trend_detected)
  expect_gt(trend$rho, 0.8)
})

test_that("einmaliger Fenster-Ausreisser wird NICHT als systematischer Trend erkannt", {
  set.seed(4)
  n <- 6000
  time <- seq_len(n)
  w <- assign_time_windows(time, k = 6L)
  x <- rnorm(n)
  x[w == 4] <- x[w == 4] + 3
  dt <- data.table::data.table(time = time, x = x)
  res <- rolling_univariate_drift(dt, w, feature_cols = "x")
  trend <- drift_trend_test(res)
  expect_equal(res[which.max(mean_effect_size)]$window_id, 4L)
  expect_false(trend$trend_detected)
})

test_that("drift_trend_test() mit < 3 Fenstern gibt sauber NA/FALSE zurueck (kein Fehler)", {
  res <- data.table::data.table(window_id = c(2L, 3L), n = c(10L, 10L), mean_effect_size = c(0.1, 0.2))
  trend <- drift_trend_test(res)
  expect_true(is.na(trend$rho))
  expect_false(trend$trend_detected)
})
