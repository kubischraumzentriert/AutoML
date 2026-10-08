suppressPackageStartupMessages(library(testthat))
source(testthat::test_path("..", "..", "modules", "lightgbm_seed_thread.R"))

test_that("seed/thread grid is explicit and rejects invalid thread settings", {
  grid <- lightgbm_seed_thread_grid(c(42, 43), c(1, 4))
  expect_equal(nrow(grid), 4L)
  expect_identical(grid$seed, c(42L, 43L, 42L, 43L))
  expect_error(lightgbm_seed_thread_grid(42, 0), "positive integer")
  expect_error(lightgbm_seed_thread_grid(42, 1.5), "positive integer")
})

test_that("paired summary preserves seed pairing and computes thread deltas", {
  results <- data.table::data.table(
    seed = c(42L, 42L, 43L, 43L), num_threads = c(1L, 4L, 1L, 4L),
    classif.auc = c(.80, .81, .70, .69)
  )
  paired <- paired_seed_thread_summary(results, "classif.auc")
  expect_equal(paired$delta_high_minus_low, c(.01, -.01))
  summary <- summarize_seed_thread_check(results, "classif.auc")
  expect_equal(summary$n_runs, 4L)
  expect_equal(summary$mean_paired_delta_high_minus_low, 0)
  expect_error(paired_seed_thread_summary(results[-1], "classif.auc"), "exactly two")
})
