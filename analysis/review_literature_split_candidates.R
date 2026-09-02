rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
})

project_dir <- normalizePath(".")
source("000_config.R")

out_csv <- file.path(artifact_dir, "literature_split_candidate_review.csv")
out_md <- file.path(artifact_dir, "literature_split_candidate_review.md")

review <- rbindlist(
  list(
    data.table(
      source_key = "fedot_tabular_benchmark_docs",
      source_url = "https://fedot.readthedocs.io/en/yadf/benchmarks/tabular.html",
      dataset = "credit-g",
      openml_dataset_id = 31L,
      metric = "f1",
      local_status_before_review = "split_match_candidate",
      source_confirms = paste(
        "numeric F1 scores for FEDOT/AutoGluon/H2O/TPOT;",
        "OpenML test suite wording;",
        "10 folds run wording"
      ),
      source_missing_for_upgrade = paste(
        "exact OpenML task id;",
        "positive class definition;",
        "paper/framework preprocessing pipeline;",
        "time budget for the F1 table;",
        "seed/repeated-run protocol"
      ),
      local_match = paste(
        "OpenML dataset id 31;",
        "local 10-fold CV F1 exists;",
        "metric family matches after classif.fbeta -> f1 alias"
      ),
      local_mismatch_or_unknown = paste(
        "positive class inferred locally as minority class 'bad';",
        "local mlr3 preprocessing/learners differ from source AutoML harness;",
        "no exact OpenML task id match is proven"
      ),
      review_decision = "keep_context_only",
      next_action = paste(
        "Do not update lres_comparability automatically;",
        "only upgrade after source-level task/positive-class/harness details are proven",
        "or after a paper-identical reproduction harness is implemented."
      )
    ),
    data.table(
      source_key = "lightautoml_openml_table7_2021",
      source_url = "https://www.researchgate.net/publication/354379217_LightAutoML_AutoML_Solution_for_a_Large_Financial_Services_Ecosystem",
      dataset = "credit-g",
      openml_dataset_id = 31L,
      metric = "auc",
      local_status_before_review = "split_match_candidate",
      source_confirms = paste(
        "numeric ROC-AUC scores for LightAutoML/AutoGluon/H2OAutoML/auto-sklearn/Auto-WEKA/TPOT;",
        "10 official OpenML benchmark folds;",
        "1h runtime input limit, 8 CPU, 32 GB RAM per fold in paper appendix"
      ),
      source_missing_for_upgrade = paste(
        "exact OpenML task id in imported table;",
        "class ordering/positive-class convention used for AUC;",
        "framework integration details and benchmark repository commit;",
        "local reproduction does not run the AMLB docker harness"
      ),
      local_match = paste(
        "OpenML dataset id 31;",
        "local 10-fold CV AUC exists;",
        "metric family matches"
      ),
      local_mismatch_or_unknown = paste(
        "local mlr3 learners/preprocessing differ from OpenML AutoML Benchmark harness;",
        "no exact task id/class-ordering equivalence is proven in DB;",
        "hardware/runtime controls differ from paper"
      ),
      review_decision = "keep_context_only",
      next_action = paste(
        "Do not update lres_comparability automatically;",
        "treat as high-quality context and potential reproduction target;",
        "upgrade only after an AMLB-compatible reproduction harness or exact task protocol is documented."
      )
    )
  ),
  fill = TRUE
)

fwrite(review, out_csv)

md <- c(
  "# Literature Split Candidate Review",
  "",
  "Manual review for rows flagged by `classify_literature_comparability.R` as `split_match_candidate`.",
  "",
  "Decision: keep reviewed `credit-g` split candidates at `context_only` for now.",
  "",
  "| Source | Dataset | Metric | Local Status | Source Confirms | Missing For Upgrade | Decision |",
  "|---|---|---|---|---|---|---|"
)
for (i in seq_len(nrow(review))) {
  row <- review[i]
  md <- c(md, sprintf(
    "| `%s` | `%s` | `%s` | `%s` | %s | %s | `%s` |",
    row$source_key,
    row$dataset,
    row$metric,
    row$local_status_before_review,
    row$source_confirms,
    row$source_missing_for_upgrade,
    row$review_decision
  ))
}
md <- c(
  md,
  "",
  "## Practical Consequence",
  "",
  "- The current `split_match_candidate` label is useful as a review queue signal, not as permission to mix scores into local evidence.",
  "- `build_portfolio_warmstart_evidence.R` must continue to ignore literature tables.",
  "- A future upgrade requires either source-level details or a reproduction harness that mirrors the source benchmark conditions."
)
writeLines(md, out_md, useBytes = TRUE)

cat("Literatur-Split-Candidate-Review geschrieben:\n")
cat("  -", out_csv, "\n")
cat("  -", out_md, "\n\n")
print(review[, .(source_key, dataset, metric, review_decision)])
