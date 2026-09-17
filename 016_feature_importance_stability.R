rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
})

# =====================================================================
# 016_feature_importance_stability.R -- erste Realprojekt-Anwendung von
# feature_importance_stability.R: ist die von 015_target_leak_audit.R
# genutzte Gain-Importance-Rangfolge (EIN einziger Trainingslauf auf dem
# vollen Task) stabil, oder haette ein anderer Fold-Split ein anderes
# Bild gezeigt?
# =====================================================================
# Trainiert denselben Learner-Typ (classif.lightgbm) ueber 5 Folds einer
# stratifizierten CV, sammelt importance() je Fold, vergleicht mit dem
# EINZELLAUF-Ergebnis aus 015 (leak_audit_importance_path).

source("000_config.R")
source(file.path(project_dir, "modules", "feature_importance_stability.R"))

if (!file.exists(leak_audit_importance_path)) {
  stop("Einzellauf-Importance fehlt. Erst 015_target_leak_audit.R ausfuehren.")
}
single_run_importance <- fread(leak_audit_importance_path)

train <- fread(train_path)
date_cols <- names(train)[vapply(train, function(x) inherits(x, c("Date", "IDate", "POSIXct")), logical(1))]
train[, (date_cols) := lapply(.SD, as.numeric), .SDcols = date_cols]
char_cols <- names(train)[vapply(train, is.character, logical(1))]
train[, (char_cols) := lapply(.SD, as.factor), .SDcols = char_cols]
train[, (target_col) := as.factor(get(target_col))]
task_full <- as_task_classif(train, target = target_col, id = "importance_stability")
task_full$set_col_roles(target_col, add_to = "stratum")

set.seed(seed)
rsmp_cv <- rsmp("cv", folds = 5L)
rsmp_cv$instantiate(task_full)
folds <- lapply(seq_len(rsmp_cv$iters), function(i) list(train = rsmp_cv$train_set(i)))

train_fn <- function(train_ids) {
  lr <- lrn("classif.lightgbm", num_iterations = 200, predict_type = "prob")
  lr$train(task_full, row_ids = train_ids)
  lr
}

cat("=== Feature-Importance-Stabilitaet ueber 5 Folds ===\n")
mat <- collect_importance_across_folds(folds, train_fn)

rank_cor <- pairwise_rank_correlation(mat)
cat(sprintf("Mittlere paarweise Spearman-Rangkorrelation (10 Fold-Paare): %.3f\n", rank_cor$mean_correlation))

topk_overlap <- pairwise_topk_overlap(mat, k = 5)
cat(sprintf("Mittlerer Top-5-Jaccard-Overlap (10 Fold-Paare): %.3f\n", topk_overlap$mean_jaccard))

report <- feature_importance_stability_report(mat, k = 5)
cat("\n=== Stabilitaets-Report (bestes Feature zuerst) ===\n")
print(report)

# --- Vergleich mit dem 015-Einzellauf: bleibt das dortige "Top-verdaechtige"
# Feature auch hier durchgehend an der Spitze? -----------------------------
top_suspect <- single_run_importance[1, feature]
suspect_row <- report[feature == top_suspect]
cat(sprintf("\n=== Vergleich mit 015-Einzellauf ===\n"))
cat(sprintf("015 (Einzellauf) staerkstes Feature: %s (share=%.3f)\n", top_suspect, single_run_importance[1, share]))
cat(sprintf("Hier (5-Fold-Stabilitaet): mean_rank=%.2f, sd_rank=%.2f, top5_share=%.2f\n",
            suspect_row$mean_rank, suspect_row$sd_rank, suspect_row$topk_share))
if (suspect_row$sd_rank < 1 && suspect_row$topk_share == 1) {
  cat("=> Bestaetigt: das verdaechtigste Feature aus 015 ist ueber alle Folds hinweg stabil top-platziert -\n")
  cat("   der Einzellauf war KEIN Zufallsartefakt.\n")
} else {
  cat("=> WARNUNG: das verdaechtigste Feature aus 015 ist NICHT durchgehend stabil top-platziert -\n")
  cat("   der Einzellauf-Befund sollte mit Vorsicht behandelt werden, ggf. mehr Folds/Seeds pruefen.\n")
}

fwrite(report, file.path(artifact_dir, "feature_importance_stability_report.csv"))
cat("\nGespeichert:", file.path(artifact_dir, "feature_importance_stability_report.csv"), "\n")
