# =====================================================================
# test-task_data_coercion.R -- Korrektheitstests fuer
# prepare_classif_task_data() (modules/task_data_coercion.R).
# =====================================================================
# Kernbeweis fuer den bei der Extraktion gefundenen Bug: id_col wird
# IMMER entfernt, bevor der Task gebaut werden wuerde - vorher fehlte das
# in 3 von 4 aufrufenden Skripten (016/017/018), "id" waere dort als
# bedeutungsloses numerisches Feature mittrainiert worden.
library(data.table)

source(testthat::test_path("..", "..", "modules", "task_data_coercion.R"))

test_that("entfernt id_col, wenn vorhanden", {
  dt <- data.table(id = 1:3, x = c(1.1, 2.2, 3.3), y = c("a", "b", "a"))
  prepare_classif_task_data(dt, target_col = "y", id_col = "id")
  expect_false("id" %in% names(dt))
})

test_that("id_col kann ein Vektor sein (any()-Semantik, analog 015/020_task.R)", {
  dt <- data.table(id = 1:3, block = c("t1", "t2", "t3"), x = c(1, 2, 3), y = c("a", "b", "a"))
  prepare_classif_task_data(dt, target_col = "y", id_col = c("id", "block"))
  expect_false(any(c("id", "block") %in% names(dt)))
})

test_that("keine Fehlermeldung, wenn id_col NULL oder nicht vorhanden ist", {
  dt <- data.table(x = c(1, 2, 3), y = c("a", "b", "a"))
  expect_silent(prepare_classif_task_data(copy(dt), target_col = "y", id_col = NULL))
  expect_silent(prepare_classif_task_data(copy(dt), target_col = "y", id_col = "does_not_exist"))
})

test_that("Date/IDate/POSIXct-Spalten werden numerisch, nicht fallengelassen", {
  dt <- data.table(
    d1 = as.Date(c("2026-01-01", "2026-01-02")),
    d2 = as.IDate(c("2026-01-01", "2026-01-02")),
    d3 = as.POSIXct(c("2026-01-01 00:00:00", "2026-01-02 00:00:00"), tz = "UTC"),
    y = c("a", "b")
  )
  prepare_classif_task_data(dt, target_col = "y")
  expect_true(all(vapply(dt[, .(d1, d2, d3)], is.numeric, logical(1))))
})

test_that("character-Spalten (ausser target_col) werden zu Faktoren", {
  dt <- data.table(cat = c("x", "y", "x"), y = c("a", "b", "a"))
  prepare_classif_task_data(dt, target_col = "y")
  expect_true(is.factor(dt$cat))
})

test_that("target_col wird immer zu Faktor, auch wenn urspruenglich numerisch/character", {
  dt_num <- data.table(x = c(1, 2, 3), y = c(0, 1, 0))
  prepare_classif_task_data(dt_num, target_col = "y")
  expect_true(is.factor(dt_num$y))

  dt_chr <- data.table(x = c(1, 2, 3), y = c("a", "b", "a"))
  prepare_classif_task_data(dt_chr, target_col = "y")
  expect_true(is.factor(dt_chr$y))
})

test_that("aendert dt in-place UND gibt sie (unsichtbar) zurueck", {
  dt <- data.table(x = c(1, 2, 3), y = c("a", "b", "a"))
  result <- prepare_classif_task_data(dt, target_col = "y")
  expect_identical(result, dt)
  expect_true(is.factor(dt$y))
})
