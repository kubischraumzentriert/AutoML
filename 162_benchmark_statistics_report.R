rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
})

# =====================================================================
# 162_benchmark_statistics_report.R -- Realprojekt-Anwendung von
# benchmark_statistics_report.R (Backlog-Kandidat "Autorank/Demsar-2006-
# Mehrfach-Datensatz-Statistik", 2026-09-18) auf die bereits vorhandenen
# Protokoll-v2-Ergebnisse (faire getunte Baselines, P1-Bewertung
# 2026-08-29) der 6 externen OpenML-CC18-Datensaetze.
# =====================================================================
# Nutzt AUSSCHLIESSLICH bereits gespeicherte Artefakte (outer_workflow_
# evaluation_v2_summary.csv je Datensatz in den lokalen ML_Learning-
# Projektordnern) - kein neuer, teurer Lauf noetig. Beantwortet die
# bisher nur informell diskutierte Frage "ist ueber alle 6 Datensaetze
# hinweg systematisch EINE Methode besser" - ergaenzt den bereits
# bekannten Einzelbefund je Datensatz (BACKLOG.md "P1, Teil faire
# getunte Baselines") um eine formale Mehrfach-Datensatz-Aussage.

source("000_config.R")
source(file.path(project_dir, "modules", "benchmark_statistics_report.R"))

ml_learning_root <- "C:/Users/HP/ML_Learning"
cc18_datasets <- c("cmc", "blood-transfusion", "ilpd", "sick", "optdigits", "analcatdata-authorship")

summary_paths <- setNames(
  file.path(ml_learning_root, paste0("openml-cc18-", cc18_datasets), "_artifacts", "outer_workflow_evaluation_v2_summary.csv"),
  cc18_datasets
)
missing <- summary_paths[!file.exists(summary_paths)]
if (length(missing) > 0) {
  stop("Fehlende Protokoll-v2-Summary-Dateien (162_benchmark_statistics_report.R erwartet einen bereits gelaufenen Protokoll-v2-Lauf, siehe BACKLOG.md P1): ",
       paste(missing, collapse = ", "))
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
cat("\nMittlerer Rang je Arm (1 = ueber alle 6 Datensaetze im Schnitt am besten):\n")
print(sort(report$mean_rank))

if (report$method == "friedman_nemenyi") {
  cat(sprintf("\nFriedman-Test: chi2=%.3f, df=%d, p=%.4f\n",
              report$friedman_statistic, report$friedman_df, report$friedman_p_value))
  cat(sprintf("Nemenyi kritische Differenz (alpha=0.05, k=%d, n=%d): %.3f\n",
              ncol(score_matrix), nrow(score_matrix), report$critical_difference))
  cat("\nSignifikante paarweise Unterschiede (|Rangdifferenz| > kritische Differenz):\n")
  sig <- report$significant_pairs[significant == TRUE]
  if (nrow(sig) == 0) {
    cat("  Keine - trotz unterschiedlicher mittlerer Raenge haelt kein Paar der Nemenyi-Schwelle stand (nur 6 Datensaetze, wie im JOSS_TECHNIQUE_WATCH.md-Kandidateneintrag selbst vorhergesagt: 'erst bei mehr Datensaetzen aussagekraeftig').\n")
  } else {
    print(sig)
  }
}

benchmark_statistics_report_path <- file.path(artifact_dir, "benchmark_statistics_report_cc18.csv")
fwrite(arm_scores, benchmark_statistics_report_path)
cat("\nGespeichert (Rohdaten):", benchmark_statistics_report_path, "\n")
