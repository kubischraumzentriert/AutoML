rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(RSQLite)
})

project_dir <- normalizePath(".")
source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

out_csv <- file.path(artifact_dir, "literature_comparability_triage.csv")
out_md <- file.path(artifact_dir, "literature_comparability_triage.md")

normalize_name <- function(x) {
  x <- tolower(x)
  x <- gsub("^openml-", "", x)
  x <- gsub("^dataset_[0-9]+_", "", x)
  x <- gsub("_", "-", x)
  aliases <- c(
    "adult-income" = "adult",
    "amazon-access" = "amazon-employee-access",
    "amazon-employee-access" = "amazon-employee-access",
    "bank-marketing-ensemble-test" = "bank-marketing",
    "credit-g" = "credit-g"
  )
  x <- ifelse(x %in% names(aliases), aliases[x], x)
  x
}

metric_alias <- function(x) {
  x <- tolower(x)
  aliases <- c(
    "classif.acc" = "accuracy",
    "acc" = "accuracy",
    "accuracy" = "accuracy",
    "classif.auc" = "auc",
    "auc" = "auc",
    "classif.bacc" = "bacc",
    "bacc" = "bacc",
    "classif.mcc" = "mcc",
    "mcc" = "mcc",
    "classif.fbeta" = "f1",
    "f1" = "f1"
  )
  unname(ifelse(x %in% names(aliases), aliases[x], x))
}

parse_literature_folds <- function(x) {
  x <- tolower(ifelse(is.na(x), "", x))
  fifelse(grepl("10\\s*-?\\s*fold|10\\s+fold|10.*fold", x), 10L,
    fifelse(grepl("5\\s*-?\\s*fold|5\\s+fold|5.*fold", x), 5L, NA_integer_)
  )
}

collapse_unique <- function(x) {
  x <- unique(na.omit(as.character(x)))
  if (length(x) == 0) NA_character_ else paste(sort(x), collapse = "; ")
}

con <- db_connect()
on.exit(DBI::dbDisconnect(con), add = TRUE)

lit <- as.data.table(dbGetQuery(con, "
  SELECT
    lsrc_key,
    lsrc_source_type,
    lres_key,
    lres_dataset_name,
    lres_openml_dataset_id,
    lres_method,
    lres_metric_name,
    lres_metric_value,
    lres_result_kind,
    lres_comparability,
    lres_resampling,
    lres_time_budget_minutes,
    lres_notes
  FROM v_literature_benchmark_results
"))

own <- as.data.table(dbGetQuery(con, "
  SELECT
    proj_name,
    mconf_algorithm,
    mres_measure_name,
    mres_value,
    rsmp_strategy,
    rsmp_folds,
    rsmp_ratio
  FROM v_metric_results
  WHERE mres_value IS NOT NULL
"))

lit[, dataset_key := normalize_name(lres_dataset_name)]
lit[, metric_key := metric_alias(lres_metric_name)]
lit[, has_openml_dataset_id := !is.na(lres_openml_dataset_id)]
lit[, has_metric_value := !is.na(lres_metric_value)]
lit[, literature_folds := parse_literature_folds(lres_resampling)]

own[, dataset_key := normalize_name(proj_name)]
own[, metric_key := metric_alias(mres_measure_name)]

local_datasets <- unique(own[, .(dataset_key)])
local_metrics <- unique(own[, .(dataset_key, metric_key)])
local_summary <- own[
  ,
  .(
    local_algorithms = collapse_unique(mconf_algorithm),
    local_resampling = collapse_unique(paste0(rsmp_strategy, ifelse(is.na(rsmp_folds), "", paste0(":", rsmp_folds)))),
    local_cv_folds = collapse_unique(rsmp_folds[rsmp_strategy == "cv"])
  ),
  by = .(dataset_key, metric_key)
]

triage <- merge(lit, local_datasets[, has_local_dataset := TRUE], by = "dataset_key", all.x = TRUE)
triage[is.na(has_local_dataset), has_local_dataset := FALSE]
triage <- merge(triage, local_metrics[, has_local_metric := TRUE], by = c("dataset_key", "metric_key"), all.x = TRUE)
triage[is.na(has_local_metric), has_local_metric := FALSE]
triage <- merge(triage, local_summary, by = c("dataset_key", "metric_key"), all.x = TRUE)

triage[, local_fold_match := FALSE]
triage[!is.na(literature_folds) & !is.na(local_cv_folds), local_fold_match := mapply(
  function(lit_folds, local_folds) as.character(lit_folds) %in% unlist(strsplit(local_folds, "; ", fixed = TRUE)),
  literature_folds,
  local_cv_folds
)]

triage[, suggested_comparability := fifelse(
  lres_result_kind %in% c("leaderboard_summary", "metadata_only") | metric_key %in% c("avg_rank", "avg_rescaled_loss", "champion_count", "reverse_position_sum", "n_features", "n_rows"),
  "aggregate_or_metadata_context",
  fifelse(
    !has_metric_value,
    "score_missing_in_seed",
    fifelse(
      !has_openml_dataset_id,
      "source_context_missing_openml_id",
      fifelse(
        !has_local_dataset,
        "openml_reproduction_candidate",
        fifelse(
          !has_local_metric,
          "local_metric_gap",
          fifelse(
            local_fold_match,
            "split_match_candidate",
            fifelse(!is.na(literature_folds), "resampling_mismatch_context", "metric_match_only")
          )
        )
      )
    )
  )
)]

triage[, recommended_action := fifelse(
  suggested_comparability == "split_match_candidate",
  "Manual source check: verify positive class, preprocessing, time budget and exact OpenML task before upgrading beyond context_only.",
  fifelse(
    suggested_comparability == "resampling_mismatch_context",
    "Keep context_only or rerun local experiment with source-compatible resampling.",
    fifelse(
      suggested_comparability == "openml_reproduction_candidate",
      "Consider creating a local reproduction project if source has enough split/metric detail.",
      fifelse(
        suggested_comparability == "local_metric_gap",
        "Add the missing local metric deliberately before comparing.",
        fifelse(
          suggested_comparability == "score_missing_in_seed",
          "Fix seed/import if the source contains a numeric score; otherwise recode as metadata_only.",
          "Keep context_only; do not use as direct model evidence."
        )
      )
    )
  )
)]

setcolorder(triage, c(
  "suggested_comparability", "recommended_action",
  "dataset_key", "metric_key", "lsrc_key", "lres_dataset_name",
  "lres_openml_dataset_id", "lres_method", "lres_metric_name",
  "lres_metric_value", "lres_result_kind", "lres_comparability",
  "lres_resampling", "literature_folds", "has_local_dataset",
  "has_local_metric", "local_algorithms", "local_resampling", "local_cv_folds"
))
setorder(triage, suggested_comparability, dataset_key, metric_key, lres_method)

fwrite(triage, out_csv)

counts <- triage[, .N, by = suggested_comparability][order(-N, suggested_comparability)]
examples <- triage[
  ,
  .SD[seq_len(min(.N, 4L))],
  by = suggested_comparability
][order(suggested_comparability, dataset_key)]

md <- c(
  "# Literature Comparability Triage",
  "",
  "This report proposes conservative comparability labels for literature benchmark rows.",
  "",
  "Important: the script does not update the database. It is a review queue; manual source checks are still required before changing `lres_comparability`.",
  "",
  "## Summary",
  ""
)
md <- c(md, sprintf("- %s: %d", counts$suggested_comparability, counts$N))
md <- c(
  md,
  "",
  "## Label Meaning",
  "",
  "- `split_match_candidate`: OpenML ID, numeric score, local metric and literature/local CV folds line up; still requires source-level checks.",
  "- `resampling_mismatch_context`: local metric exists, but the known literature resampling does not match local resampling.",
  "- `openml_reproduction_candidate`: numeric OpenML dataset score exists, but no local dataset is present yet.",
  "- `aggregate_or_metadata_context`: aggregate leaderboard or dataset metadata; not a direct dataset-score comparison.",
  "- `source_context_missing_openml_id`: score exists, but OpenML ID is missing.",
  "- `local_metric_gap`: local dataset exists, but the literature metric is missing locally.",
  "- `score_missing_in_seed`: row lacks a numeric score and should be fixed or recoded.",
  "",
  "## Examples",
  "",
  "| Suggested | Dataset | Metric | Method | Literature | Current | Local Resampling | Action |",
  "|---|---|---|---|---:|---|---|---|"
)
for (i in seq_len(nrow(examples))) {
  row <- examples[i]
  md <- c(md, sprintf(
    "| `%s` | `%s` | `%s` | `%s` | %s | `%s` | `%s` | %s |",
    row$suggested_comparability,
    row$dataset_key,
    row$metric_key,
    row$lres_method,
    ifelse(is.na(row$lres_metric_value), "NA", sprintf("%.4f", row$lres_metric_value)),
    row$lres_comparability,
    ifelse(is.na(row$local_resampling), "NA", row$local_resampling),
    row$recommended_action
  ))
}
writeLines(md, out_md, useBytes = TRUE)

cat("Literatur-Comparability-Triage geschrieben:\n")
cat("  -", out_csv, "\n")
cat("  -", out_md, "\n\n")
print(counts)
