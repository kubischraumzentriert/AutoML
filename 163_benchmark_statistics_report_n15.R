rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
})

# =====================================================================
# 163_benchmark_statistics_report_n15.R -- Erweiterung von
# 162_benchmark_statistics_report.R (Autorank/Demsar-2006, JOSS-
# Technique-Watch Kandidat 3) von n=6 auf n=15 externe OpenML-CC18-
# Datensaetze (2026-09-22).
# =====================================================================
# 162 nutzte nur die 6 urspruenglichen externen Datensaetze, weil nur
# diese ein Protokoll-v2-Ergebnis (faire getunte Baselines) hatten - die
# 9 weiteren "Weg B"-Datensaetze (docs/research/EXTERNAL_BENCHMARK_SET.md,
# eingefroren 2026-08-31/09-01) hatten bis dahin nur Decision-Stability-/
# Level-2-Laeufe (Protokoll v3), aber KEIN Protokoll-v2. Nachgeholt
# (2026-09-22): outer_workflow_evaluation_v2_fair_baselines.R fuer alle 9
# in den jeweiligen ML_Learning-Projektordnern nachgefahren (bereits
# vorbereitete task_train_small.rds wiederverwendet, keine neue
# Datenziehung). 162 selbst bleibt als abgeschlossene n=6-Analyse
# unveraendert (analog zur Nicht-in-place-Aenderung bei
# BENCHMARK_PROTOCOL.md/EXTERNAL_BENCHMARK_SET.md) - dieses Skript ist
# die eigenstaendige n=15-Fortsetzung, kein Ersatz.

source("000_config.R")
source(file.path(project_dir, "modules", "benchmark_statistics_report.R"))

ml_learning_root <- "C:/Users/HP/ML_Learning"
cc18_datasets <- c(
  "cmc", "blood-transfusion", "ilpd", "sick", "optdigits", "analcatdata-authorship",
  "phishing-websites", "qsar-biodeg", "mfeat-karhunen", "eucalyptus",
  "ozone-level-8hr", "dresses-sales", "jm1", "mfeat-morphological", "mice-protein"
)

summary_paths <- setNames(
  file.path(ml_learning_root, paste0("openml-cc18-", cc18_datasets), "_artifacts", "outer_workflow_evaluation_v2_summary.csv"),
  cc18_datasets
)
missing <- summary_paths[!file.exists(summary_paths)]
if (length(missing) > 0) {
  stop("Fehlende Protokoll-v2-Summary-Dateien: ", paste(missing, collapse = ", "))
}

arm_scores <- rbindlist(lapply(cc18_datasets, function(ds) {
  dt <- fread(summary_paths[[ds]])
  dt[, dataset := ds]
}))

score_matrix_dt <- dcast(arm_scores, dataset ~ arm, value.var = "mean_score")
arms <- setdiff(names(score_matrix_dt), "dataset")
score_matrix <- as.matrix(score_matrix_dt[, ..arms])
rownames(score_matrix) <- score_matrix_dt$dataset

cat(sprintf("=== Score-Matrix (mean_score je Datensatz x Arm, %d Datensaetze x %d Arme) ===\n", nrow(score_matrix), ncol(score_matrix)))
print(round(score_matrix, 4))

report <- benchmark_statistics_report(score_matrix, higher_better = TRUE)

cat(sprintf("\n=== Methode: %s ===\n", report$method))
cat("\nMittlerer Rang je Arm (1 = ueber alle 15 Datensaetze im Schnitt am besten):\n")
print(sort(report$mean_rank))

if (report$method == "friedman_nemenyi") {
  cat(sprintf("\nFriedman-Test: chi2=%.3f, df=%d, p=%.4f\n",
              report$friedman_statistic, report$friedman_df, report$friedman_p_value))
  cat(sprintf("Nemenyi kritische Differenz (alpha=0.05, k=%d, n=%d): %.3f\n",
              ncol(score_matrix), nrow(score_matrix), report$critical_difference))
  cat("\nSignifikante paarweise Unterschiede (|Rangdifferenz| > kritische Differenz):\n")
  sig <- report$significant_pairs[significant == TRUE]
  if (nrow(sig) == 0) {
    cat("  Keine - trotz unterschiedlicher mittlerer Raenge haelt kein Paar der Nemenyi-Schwelle stand.\n")
  } else {
    print(sig)
  }
}

cat("\n=== Vergleich zur n=6-Analyse (162_benchmark_statistics_report.R) ===\n")
cat("n=6 hatte: Friedman p=0.477 (kein signifikantes Paar), workflow_ranger bester mittlerer Rang (2.17/6).\n")

benchmark_statistics_report_path <- file.path(artifact_dir, "benchmark_statistics_report_cc18_n15.csv")
fwrite(arm_scores, benchmark_statistics_report_path)
cat("\nGespeichert (Rohdaten):", benchmark_statistics_report_path, "\n")
