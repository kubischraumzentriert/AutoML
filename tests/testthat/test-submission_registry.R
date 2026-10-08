registry_cli <- new.env(parent = globalenv())
script <- testthat::test_path("..", "..", "158_register_submission_result.R")
expressions <- as.list(parse(script))
definitions <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("<-")) &&
  is.call(expr[[3]]) && identical(expr[[3]][[1]], as.name("function")), expressions)
for (definition in definitions) eval(definition, envir = registry_cli)

test_that("registration CLI parses decimal comma and rejects duplicate or valueless flags", {
  expect_equal(registry_cli$parse_score("0,95785"), 0.95785)
  expect_true(is.na(registry_cli$parse_score("NA")))
  expect_error(registry_cli$parse_score("Inf"), "nicht numerisch")
  expect_identical(registry_cli$parse_cli_args(c("--mconf-id=old-id", "--public-score", "0.9")),
    list("mconf-id" = "old-id", "public-score" = "0.9"))
  expect_error(registry_cli$parse_cli_args(c("--mconf-id=a", "--mconf-id=b")), "Doppeltes")
  expect_error(registry_cli$parse_cli_args("--mconf-id"), "Wert fehlt")
})

test_that("candidate resolver refuses conflicting ledger metadata before model lookup", {
  context <- new.env(parent = globalenv())
  source(testthat::test_path("..", "..", "modules", "submission_registry.R"), local = context)
  hash <- paste(rep("a", 64), collapse = "")
  context$db_list_submission_candidates <- function(con, project_name) data.frame(
    mconf_id = "model", submission_sha256 = hash, model_id_count = 1L,
    model_hash_count = 1L, file_hash_count = 2L, status_count = 1L)
  expect_error(context$resolve_validated_submission(NULL, "project", list(sha256 = hash)), "conflicting")
  expect_error(context$resolve_validated_submission(NULL, "project", list(sha256 = NA_character_)), "missing or invalid")
})
