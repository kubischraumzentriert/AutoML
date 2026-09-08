rm(list = ls())

suppressPackageStartupMessages({
  library(DBI)
})

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))
source(file.path(project_dir, "provenance.R"))

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
        value <- "TRUE"
      } else {
        i <- i + 1L
        value <- args[[i]]
      }
    }

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
  if (!file.exists(source_path)) {
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

latest_model_artifact_info <- function(con, model_name, workflow_name) {
  model_path <- db_get_latest_model_artifact_path(con, model_name, workflow_name = workflow_name)
  if (is.na(model_path) || !nzchar(model_path) || !file.exists(model_path)) {
    return(list(path = NA_character_, sha256 = NA_character_))
  }
  normalized_path <- normalizePath(model_path, winslash = "/", mustWork = TRUE)
  list(path = normalized_path, sha256 = sha256_file(normalized_path))
}

args <- parse_cli_args()

submission_file <- normalizePath(
  arg_value(args, "submission-path", submission_path),
  winslash = "/",
  mustWork = FALSE
)
platform <- arg_value(args, "platform", Sys.getenv("SUBMISSION_PLATFORM", "kaggle"))
competition <- arg_value(args, "competition", Sys.getenv("SUBMISSION_COMPETITION", project_name))
status <- arg_value(args, "status", "submitted")
metric_name <- arg_value(args, "metric-name", baseline_measure_ids[[1]])
public_score <- parse_score(arg_value(args, "public-score", NA_character_))
private_score <- parse_score(arg_value(args, "private-score", NA_character_))
model_name <- arg_value(args, "model-name", resolve_submission_model_name())
workflow_name <- arg_value(args, "workflow-name", "150_train_full_model.R")
mconf_id <- arg_value(args, "mconf-id", NA_character_)
user_notes <- arg_value(args, "notes", "")

if (!status %in% c("submitted", "late_submission")) {
  stop("status muss 'submitted' oder 'late_submission' sein.", call. = FALSE)
}

con <- db_connect()
on.exit(DBI::dbDisconnect(con), add = TRUE)

if (is.na(mconf_id) || !nzchar(mconf_id)) {
  mconf_id <- db_get_latest_model_config_id(con, model_name, workflow_name = workflow_name)
}
if (is.na(mconf_id) || !nzchar(mconf_id)) {
  stop(
    "Keine passende model_config gefunden. Erst 150_train_full_model.R ausfuehren ",
    "oder --mconf-id explizit uebergeben.",
    call. = FALSE
  )
}

submission_info <- submission_file_info(submission_file)
model_info <- latest_model_artifact_info(con, model_name, workflow_name)
manifest <- capture_reproducibility_manifest(
  model = list(name = model_name, workflow_name = workflow_name, mconf_id = mconf_id),
  artifacts = list(
    model_artifact_path = model_info$path,
    model_artifact_sha256 = model_info$sha256,
    submission_path = submission_info$path,
    submission_sha256 = submission_info$sha256,
    submission_size_bytes = submission_info$size_bytes,
    submission_mtime = submission_info$mtime
  ),
  submission = list(
    platform = platform,
    competition = competition,
    status = status,
    metric_name = metric_name,
    public_score = public_score,
    private_score = private_score
  ),
  extra = list(reproducibility_policy = "no_submission_archive_required")
)

subm_id <- db_log_submission_result(
  con = con,
  mconf_id = mconf_id,
  platform = platform,
  competition = competition,
  file_path = submission_info$path,
  status = status,
  metric_name = metric_name,
  public_score = public_score,
  private_score = private_score,
  notes = if (nzchar(user_notes)) user_notes else NA_character_,
  manifest = manifest
)

cat("=== Submission registriert ===\n")
cat("submission_id:", subm_id, "\n")
cat("mconf_id:", mconf_id, "\n")
cat("platform:", platform, "\n")
cat("competition:", competition, "\n")
cat("metric:", metric_name, "\n")
cat("public_score:", ifelse(is.na(public_score), "NA", public_score), "\n")
cat("private_score:", ifelse(is.na(private_score), "NA", private_score), "\n")
cat("submission_sha256:", submission_info$sha256, "\n")
cat("submission_file:", submission_info$path, "\n")
cat("model_artifact_sha256:", model_info$sha256, "\n")
cat("policy: no submission copy archived; reproducibility comes from model/config/git/provenance\n")
