# Registration never guesses a latest model: completed candidates bind CSV SHA to model ID.
resolve_validated_submission <- function(con, project_name, file_info, mconf_id = NULL,
                                         model_name = NULL, workflow_name = NULL) {
  if (length(file_info$sha256) != 1L || is.na(file_info$sha256) ||
      !grepl("^[0-9a-f]{64}$", file_info$sha256)) stop("Submission hash is missing or invalid.", call. = FALSE)
  candidates <- db_list_submission_candidates(con, project_name)
  candidates <- candidates[!is.na(candidates$submission_sha256) &
    candidates$submission_sha256 == file_info$sha256, , drop = FALSE]
  if (!is.null(mconf_id)) candidates <- candidates[candidates$mconf_id == mconf_id, , drop = FALSE]
  if (nrow(candidates) == 0L) stop("No validated candidate matches this submission hash/model; validate the file first.", call. = FALSE)
  if (any(candidates$model_id_count != 1L | candidates$model_hash_count != 1L |
          candidates$file_hash_count != 1L | candidates$status_count != 1L)) {
    stop("Candidate metadata contains conflicting model references.", call. = FALSE)
  }
  records <- lapply(unique(candidates$mconf_id), function(id) {
    db_get_submission_model_record(con, project_name, model_name, workflow_name, mconf_id = id)
  })
  records <- Filter(function(record) nrow(record) == 1L, records)
  if (length(records) == 0L) stop("Candidate model does not belong to the configured project/algorithm/workflow.", call. = FALSE)
  if (length(records) > 1L) stop("Submission bytes match multiple models; supply --mconf-id explicitly.", call. = FALSE)
  model <- records[[1]]
  candidate <- candidates[candidates$mconf_id == model$mconf_id[[1]], , drop = FALSE][1, ]
  model_path <- model$model_path[[1]]
  if (!file.exists(model_path)) stop("Pinned model artifact is missing.", call. = FALSE)
  model_hash <- sha256_file(model_path)
  manifest <- jsonlite::fromJSON(model$mconf_manifest_json[[1]])
  if (!identical(candidate$model_sha256[[1]], model_hash) ||
      !identical(manifest$artifacts$model_artifact_sha256, model_hash)) {
    stop("Pinned model hash differs from candidate or model manifest.", call. = FALSE)
  }
  list(candidate = candidate, model = model, model_hash = model_hash)
}

register_validated_submission <- function(con, project_name, file_info, platform, competition, status,
                                          metric_name = NULL, public_score = NA_real_, private_score = NA_real_,
                                          mconf_id = NULL, model_name = NULL,
                                          workflow_name = NULL, notes = NA_character_) {
  if (!status %in% c("submitted", "late_submission")) stop("Only actual submission statuses may be registered.", call. = FALSE)
  if (any(!is.na(c(public_score, private_score)) & !is.finite(c(public_score, private_score)))) {
    stop("Scores must be finite or unknown.", call. = FALSE)
  }
  pinned <- resolve_validated_submission(con, project_name, file_info, mconf_id, model_name, workflow_name)
  model <- pinned$model
  candidate <- pinned$candidate
  if (is.null(metric_name)) {
    metric_name <- candidate$metric_name[[1]]
    if (is.na(metric_name) || !nzchar(metric_name)) {
      stop("Candidate has no metric metadata; supply --metric-name explicitly.", call. = FALSE)
    }
  }
  model_id <- model$mconf_id[[1]]
  reported_public <- public_score
  reported_private <- private_score
  result <- DBI::dbWithTransaction(con, {
    if (!identical(sha256_file(file_info$path), file_info$sha256) ||
        !identical(sha256_file(model$model_path[[1]]), pinned$model_hash)) {
      stop("Submission/model changed during registration.", call. = FALSE)
    }
    previous <- DBI::dbGetQuery(con, paste("SELECT subm_competition, subm_public_score, subm_private_score, subm_manifest_json",
      "FROM submission_result WHERE subm_mconf_id = ? AND subm_platform = ? AND subm_status = ? AND subm_metric_name = ?"),
      params = list(model_id, platform, status, metric_name))
    if (is.null(competition)) {
      competition <- if (nrow(previous) == 1L && !is.na(previous$subm_competition[[1]])) {
        previous$subm_competition[[1]]
      } else project_name
    }
    if (nrow(previous) == 1L && !is.na(previous$subm_manifest_json[[1]])) {
      old_hash <- jsonlite::fromJSON(previous$subm_manifest_json[[1]])$artifacts$submission_sha256
      if (identical(old_hash, file_info$sha256)) {
        if (is.na(public_score)) public_score <- previous$subm_public_score[[1]]
        if (is.na(private_score)) private_score <- previous$subm_private_score[[1]]
      }
    }
    manifest <- capture_reproducibility_manifest(
      model = list(name = model$mconf_algorithm[[1]], workflow_name = model$model_workflow[[1]], mconf_id = model_id),
      artifacts = list(model_artifact_path = model$model_path[[1]], model_artifact_sha256 = pinned$model_hash,
        submission_path = file_info$path, submission_sha256 = file_info$sha256,
        submission_size_bytes = file_info$size_bytes, submission_mtime = file_info$mtime),
      submission = list(platform = platform, competition = competition, status = status,
        metric_name = metric_name, public_score = public_score, private_score = private_score),
      extra = list(candidate_run_id = candidate$candidate_run_id[[1]],
        reported_public_score = reported_public, reported_private_score = reported_private,
        reported_notes = notes,
        reproducibility_policy = "validated_hash_pinned_no_submission_archive"))
    submission_id <- db_log_submission_result(con, model_id, platform, competition, file_info$path,
      status, metric_name, public_score, private_score, notes, manifest)
    project_id <- db_get_or_create_project(con, project_name)
    workflow_id <- db_get_or_create_workflow(con, project_id, "script", "158_register_submission_result.R")
    event_id <- db_create_run(con, workflow_id, notes = "Submission registration event; no upload performed")
    db_log_run_config(con, event_id, list(event_type = "submission_registration",
      candidate_run_id = candidate$candidate_run_id[[1]], mconf_id = model_id,
      submission_id = submission_id, submission_sha256 = file_info$sha256,
      model_sha256 = pinned$model_hash, platform = platform, competition = competition,
      status = status, metric_name = metric_name, reported_public_score = reported_public,
      reported_private_score = reported_private, public_score = public_score, private_score = private_score,
      reported_notes = notes))
    db_finish_run(con, event_id)
    list(submission_id = submission_id, event_run_id = event_id, mconf_id = model_id,
      candidate_run_id = candidate$candidate_run_id[[1]], public_score = public_score,
      private_score = private_score, model_sha256 = pinned$model_hash, metric_name = metric_name,
      competition = competition)
  })
  result
}
