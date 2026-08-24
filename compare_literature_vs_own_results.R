rm(list = ls())

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
})

project_dir <- normalizePath(".")
source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

out_csv <- file.path(artifact_dir, "literature_vs_own_results.csv")
out_md <- file.path(artifact_dir, "literature_vs_own_results.md")

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

con <- db_connect()
on.exit(DBI::dbDisconnect(con), add = TRUE)

own <- dbGetQuery(con, "
  SELECT
    proj_name,
    mconf_algorithm,
    mres_measure_name,
    mres_value,
    rsmp_strategy,
    rsmp_folds,
    run_started_at
  FROM v_metric_results
  WHERE mres_value IS NOT NULL
")

lit <- dbGetQuery(con, "
  SELECT
    lsrc_key,
    lsrc_title,
    lres_dataset_name,
    lres_openml_dataset_id,
    lres_method,
    lres_metric_name,
    lres_metric_value,
    lres_result_kind,
    lres_comparability,
    lres_notes
  FROM v_literature_benchmark_results
  WHERE lres_result_kind IN ('dataset_score', 'leaderboard_summary')
    AND lres_metric_value IS NOT NULL
")

if (nrow(own) == 0 || nrow(lit) == 0) {
  stop("Nicht genug Daten fuer Vergleich: own=", nrow(own), ", literature=", nrow(lit))
}

own$dataset_key <- normalize_name(own$proj_name)
own$metric_key <- metric_alias(own$mres_measure_name)
lit$dataset_key <- normalize_name(lit$lres_dataset_name)
lit$metric_key <- metric_alias(lit$lres_metric_name)

own_best <- do.call(rbind, lapply(split(own, paste(own$dataset_key, own$metric_key, own$mconf_algorithm, sep = " :: ")), function(dt) {
  maximize <- !dt$metric_key[1] %in% c("logloss", "loss", "error")
  dt <- dt[order(if (maximize) -dt$mres_value else dt$mres_value, dt$run_started_at), , drop = FALSE]
  dt[1, , drop = FALSE]
}))

comparison <- merge(
  lit,
  own_best,
  by = c("dataset_key", "metric_key"),
  all.x = TRUE,
  suffixes = c("_literature", "_own")
)

comparison$score_delta_own_minus_literature <- comparison$mres_value - comparison$lres_metric_value
comparison$has_local_dataset <- comparison$dataset_key %in% unique(own$dataset_key)
comparison$comparison_status <- ifelse(
  is.na(comparison$mres_value),
  ifelse(comparison$has_local_dataset, "local_dataset_metric_mismatch", "no_local_dataset"),
  ifelse(comparison$lres_comparability == "context_only", "matched_context_only", "matched_check_comparability")
)

comparison <- comparison[order(comparison$comparison_status, comparison$dataset_key, comparison$metric_key, comparison$lres_method), ]
write.csv(comparison, out_csv, row.names = FALSE)

summary_counts <- as.data.frame(table(comparison$comparison_status), stringsAsFactors = FALSE)
names(summary_counts) <- c("status", "n")

matched <- comparison[
  comparison$comparison_status %in% c("matched_context_only", "matched_check_comparability"),
  ,
  drop = FALSE
]
md <- c(
  "# Literature vs Own Results",
  "",
  "This report explicitly compares external literature/benchmark context values against local `v_metric_results`.",
  "",
  "Important: `context_only` rows are not direct evidence of superiority/inferiority because splits, time budgets, frameworks, and preprocessing differ.",
  "",
  "## Summary",
  ""
)
for (i in seq_len(nrow(summary_counts))) {
  md <- c(md, paste0("- ", summary_counts$status[i], ": ", summary_counts$n[i]))
}

md <- c(md, "", "## Matched Examples", "")
if (nrow(matched) == 0) {
  md <- c(md, "No matched dataset/metric pairs found.")
} else {
  shown <- head(matched, 20)
  md <- c(md, "| Dataset | Metric | Literature Method | Literature | Own Algorithm | Own | Delta | Status |")
  md <- c(md, "|---|---|---|---:|---|---:|---:|---|")
  for (i in seq_len(nrow(shown))) {
    row <- shown[i, ]
    md <- c(md, sprintf(
      "| `%s` | `%s` | `%s` | %.4f | `%s` | %.4f | %.4f | `%s` |",
      row$dataset_key, row$metric_key, row$lres_method, row$lres_metric_value,
      row$mconf_algorithm, row$mres_value, row$score_delta_own_minus_literature,
      row$comparison_status
    ))
  }
}

md <- c(
  md,
  "",
  "## Next Use",
  "",
  "Use this as a triage report: `no_local_dataset` rows identify benchmark datasets worth reproducing locally; `local_dataset_metric_mismatch` rows identify local projects where the literature metric should be added deliberately; matched `context_only` rows still need manual comparability review before interpretation."
)

writeLines(md, out_md, useBytes = TRUE)

cat("Literatur-vs-eigene-Ergebnisse geschrieben:\n")
cat("  -", out_csv, "\n")
cat("  -", out_md, "\n\n")
print(summary_counts, row.names = FALSE)
