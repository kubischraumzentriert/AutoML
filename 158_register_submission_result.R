rm(list = ls())

suppressPackageStartupMessages({
  library(DBI)
})

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))
source(file.path(project_dir, "provenance.R"))
source(file.path(project_dir, "modules", "submission_registry.R"))

parse_cli_args <- function(args = commandArgs(trailingOnly = TRUE)) {
  out <- list()
  i <- 1L
  while (i <= length(args)) {
    arg <- args[[i]]
    if (!startsWith(arg, "--")) {
      stop("Unerwartetes Argument: ", arg, call. = FALSE)
    }

    stripped <- sub("^--", "", arg)
    if (grepl("=", stripped, fixed = TRUE)) {
      parts <- strsplit(stripped, "=", fixed = TRUE)[[1]]
      key <- parts[[1]]
      value <- paste(parts[-1], collapse = "=")
    } else {
      key <- stripped
      if (i == length(args) || startsWith(args[[i + 1L]], "--")) {
        stop("Wert fehlt fuer --", key, call. = FALSE)
      } else {
        i <- i + 1L
        value <- args[[i]]
      }
    }

    if (key %in% names(out)) stop("Doppeltes Argument: --", key, call. = FALSE)
    out[[key]] <- value
    i <- i + 1L
  }
  out
}

arg_value <- function(args, key, default = NULL) {
  value <- args[[key]]
  if (is.null(value) || !nzchar(value)) default else value
}

parse_score <- function(value) {
  if (is.null(value) || length(value) == 0 || is.na(value) || !nzchar(value) || identical(tolower(value), "na")) {
    return(NA_real_)
  }
  score <- suppressWarnings(as.numeric(gsub(",", ".", value, fixed = TRUE)))
  if (!is.finite(score)) {
    stop("Score ist nicht numerisch: ", value, call. = FALSE)
  }
  score
}

submission_file_info <- function(source_path) {
  if (!file.exists(source_path) || dir.exists(source_path)) {
    stop("Submission-Datei nicht gefunden: ", source_path, call. = FALSE)
  }

  normalized_path <- normalizePath(source_path, winslash = "/", mustWork = TRUE)
  info <- file.info(normalized_path)
  list(
    path = normalized_path,
    size_bytes = as.numeric(info$size),
    mtime = format(info$mtime, "%Y-%m-%d %H:%M:%S %Z"),
    sha256 = sha256_file(normalized_path)
  )
}

run_submission_registration <- function() {
  args <- parse_cli_args()
  allowed <- c("submission-path", "platform", "competition", "status", "metric-name",
    "public-score", "private-score", "model-name", "workflow-name", "mconf-id", "notes")
  if (any(!names(args) %in% allowed)) stop("Unknown registration argument: ", paste(setdiff(names(args), allowed), collapse = ", "))
  submission_file <- arg_value(args, "submission-path", submission_path)
  file_info <- submission_file_info(submission_file)
  platform <- arg_value(args, "platform", Sys.getenv("SUBMISSION_PLATFORM", "kaggle"))
  environment_competition <- Sys.getenv("SUBMISSION_COMPETITION", "")
  competition <- arg_value(args, "competition", if (nzchar(environment_competition)) environment_competition else NULL)
  status <- arg_value(args, "status", "submitted")
  metric_name <- arg_value(args, "metric-name", NULL)
  public_score <- parse_score(arg_value(args, "public-score", NA_character_))
  private_score <- parse_score(arg_value(args, "private-score", NA_character_))
  model_name <- arg_value(args, "model-name", NULL)
  workflow_name <- arg_value(args, "workflow-name", NULL)
  mconf_id <- arg_value(args, "mconf-id", NULL)
  user_notes <- arg_value(args, "notes", NA_character_)
  con <- db_connect()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  result <- register_validated_submission(con, project_name, file_info, platform, competition,
    status, metric_name, public_score, private_score, mconf_id, model_name, workflow_name, user_notes)
  cat("=== Validated submission registered (no upload performed) ===\n")
  cat("submission_id:", result$submission_id, "\nmconf_id:", result$mconf_id,
    "\ncandidate_run_id:", result$candidate_run_id, "\nevent_run_id:", result$event_run_id, "\n")
  cat("platform:", platform, "\ncompetition:", result$competition, "\nmetric:", result$metric_name, "\n")
  cat("public_score:", result$public_score, "\nprivate_score:", result$private_score, "\n")
  cat("submission_sha256:", file_info$sha256, "\nmodel_sha256:", result$model_sha256,
    "\nsubmission_file:", file_info$path, "\n")
}
run_submission_registration()
