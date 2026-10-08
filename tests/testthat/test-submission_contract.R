library(data.table)
source(testthat::test_path("..", "..", "modules", "submission_contract.R"))

binary_prediction <- function() list(prob = cbind("FALSE" = c(0.8, 0.3), "TRUE" = c(0.2, 0.7)),
  response = factor(c("FALSE", "TRUE")))

test_that("binary probability contract catches complements, IDs, schema and invalid values", {
  expected <- submission_prediction_values(binary_prediction(), TRUE, "TRUE")
  valid <- data.table(id = c("001", "002"), target = expected$values)
  check <- function(value, sample = valid) validate_submission_table(value, valid$id, "id", "target", expected, sample)
  expect_true(check(valid)$valid)
  bad <- copy(valid); bad$target <- 1 - bad$target
  expect_error(check(bad), "selected model probability")
  expect_error(check(valid[2:1]), "ID order")
  bad <- copy(valid); bad$id[2] <- bad$id[1]
  expect_error(check(bad), "unique")
  bad <- copy(valid); bad$id[2] <- NA_character_
  expect_error(check(bad), "nonmissing")
  bad <- copy(valid); bad$target[1] <- Inf
  expect_error(check(bad), "finite")
  bad$target[1] <- 1.1
  expect_error(check(bad), "finite")
  bad$target <- as.character(valid$target)
  expect_error(check(bad), "numeric")
  expect_error(check(valid[, .(target, id)]), "columns/order")
  expect_error(check(valid, valid[2:1]), "Sample submission ID")
  expect_error(check(valid, data.table(id = valid$id, wrong = 0)), "Sample submission columns")
  expect_error(check(valid[0]), "nonempty")
})

test_that("constant probabilities and labels including leading zeros are valid", {
  prediction <- binary_prediction(); prediction$prob[,] <- 0.5
  expected <- submission_prediction_values(prediction, TRUE, "TRUE")
  expect_true(validate_submission_table(data.table(id = 1:2, target = c(0.5, 0.5)),
    1:2, "id", "target", expected)$valid)
  labels <- submission_prediction_values(list(prob = NULL, response = factor(c("001", "002"))), FALSE)
  expect_true(validate_submission_table(data.table(id = c("a", "b"), target = labels$values),
    c("a", "b"), "id", "target", labels)$valid)
  expect_warning(submission_prediction_values(binary_prediction(), TRUE), "legacy export")
  expect_error(submission_prediction_values(binary_prediction(), TRUE, "other"), "not a prediction class")
  malformed <- binary_prediction(); malformed$prob[1, ] <- c(0.8, 0.8)
  expect_error(submission_prediction_values(malformed, TRUE, "TRUE"), "sum to one")
  expect_error(submission_prediction_values(list(prob = matrix(1/3, 2, 3), response = factor(c("a", "b"))), TRUE), "explicit column mapping")
})

test_that("factor alignment preserves missing values and refuses silent unknown-to-NA conversion", {
  original <- data.table(category = c("b", NA, "a"))
  aligned <- align_submission_factor_levels(original, list(category = c("a", "b")))
  expect_identical(levels(aligned$category), c("a", "b"))
  expect_identical(as.character(aligned$category), original$category)
  expect_true(is.character(original$category))
  expect_error(align_submission_factor_levels(data.table(category = "unknown"), list(category = c("a", "b"))), "Unknown test factor")
  expect_error(align_submission_factor_levels(data.table(x = 1), list(category = "a")), "Missing categorical")
})

test_that("model contract verifies parameters and class while supporting legacy raw bundles", {
  bundle <- list(learner = list(param_set = list(values = list(seed = 42L, trees = 100L))),
    feature_set = "raw", positive_class = "TRUE")
  expect_silent(validate_submission_model(bundle, "raw", list(trees = 100L, seed = 42L), "TRUE"))
  expect_error(validate_submission_model(bundle, "selected", list(seed = 42L, trees = 100L)), "feature_set")
  expect_error(validate_submission_model(bundle, "raw", list(seed = 42L, trees = 200L)), "parameters")
  expect_error(validate_submission_model(bundle, "raw", list(seed = 42L, trees = 100L), "FALSE"), "positive class")
  bundle$feature_set <- NULL; bundle$positive_class <- NULL
  expect_silent(validate_submission_model(bundle, "raw", list(seed = 42L, trees = 100L)))
})

test_that("staged CSV export preserves legacy labels and leaves prior files intact on rejection", {
  path <- tempfile(fileext = ".csv")
  legacy <- tempfile(fileext = ".csv")
  on.exit(unlink(c(path, legacy)), add = TRUE)
  expected <- submission_prediction_values(list(prob = NULL, response = factor(c("001", "002"))), FALSE)
  valid <- data.table(id = c("001", "002"), target = expected$values)
  fwrite(valid, legacy)
  expect_true(write_checked_submission(valid, path, valid$id, "id", "target", expected, valid)$valid)
  expect_identical(readLines(path), readLines(legacy))
  expect_identical(read_submission_csv(path, "id", "target", "label")$target, c("001", "002"))
  expect_error(write_checked_submission(valid[2:1], path, valid$id, "id", "target", expected), "ID order")
  expect_identical(readLines(path), readLines(legacy))
})

test_that("smoke fixture mirrors the production positive-class helper", {
  root <- normalizePath(testthat::test_path("..", ".."))
  production <- new.env(); production$project_dir <- root
  smoke <- new.env(); smoke$project_dir <- file.path(root, "ci_smoke_test")
  source(file.path(root, "000_config.R"), local = production)
  source(file.path(root, "ci_smoke_test", "000_config.R"), local = smoke)
  expect_identical(body(production$apply_positive_class), body(smoke$apply_positive_class))
  expect_identical(formals(production$apply_positive_class), formals(smoke$apply_positive_class))
})
