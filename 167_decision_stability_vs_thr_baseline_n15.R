rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
})
source("000_config.R")

# =====================================================================
# 167_decision_stability_vs_thr_baseline_n15.R -- Abschnitt 7.3 neu
# gerechnet: Stabilitaet der Level-2-Modellwahl gegen Level-2-Erfolg, wenn
# der Erfolg gegen die schwellenkorrigierte Baseline gemessen wird.
# =====================================================================
# Stabilitaetswerte: unveraendert aus analysis/decision_stability_level2_
# analysis_n15.R (45 Einzelmessungen, je 3 Outer-Folds). Keine neuen Laeufe.
# Erfolg: d = level2_workflow - best_single_tuned_thr, Datensatz-Mittel,
# aus level2_vs_thr_baseline_n15.csv (Skript 166). Das ersetzt die frueheren
# Deltas gegen die unkorrigierte v2-Baseline.
#
# Vorab festgelegt: gleiche Tests wie in analysis/decision_stability_level2_
# analysis_n15.R (Spearman, mittlere Stabilitaet ueber 3 Folds, n = 6, 10, 15).

datasets <- c(
  "ilpd", "blood-transfusion", "sick", "cmc", "analcatdata-authorship", "optdigits",
  "phishing-websites", "qsar-biodeg", "mfeat-karhunen", "eucalyptus",
  "ozone-level-8hr", "dresses-sales", "jm1", "mice-protein", "mfeat-morphological"
)
tranche <- c(rep("1", 6), rep("2", 4), rep("3", 5))

stab_fold1 <- c(0.70, 0.60, 0.60, 0.50, 0.70, 0.60,  0.70, 0.50, 0.50, 0.50,  0.70, 0.60, 0.60, 0.60, 0.50)
stab_fold2 <- c(0.70, 0.50, 1.00, 0.40, 0.80, 0.60,  0.60, 0.50, 0.40, 0.60,  0.60, 0.80, 0.50, 0.70, 0.60)
stab_fold3 <- c(0.50, 0.60, 0.80, 0.50, 0.70, 0.60,  0.60, 0.50, 0.40, 0.60,  0.90, 0.50, 0.50, 0.40, 0.70)
avg_stability <- (stab_fold1 + stab_fold2 + stab_fold3) / 3

delta_path <- file.path(artifact_dir, "level2_vs_thr_baseline_n15.csv")
if (!file.exists(delta_path)) stop("Zuerst 166_level2_vs_thr_baseline_n15.R ausfuehren: ", delta_path)
delta_tab <- fread(delta_path)[, .(dataset, d)]
delta_level2 <- delta_tab[match(datasets, dataset), d] * 100
if (anyNA(delta_level2)) stop("Datensatz-Zuordnung fehlgeschlagen")

df <- data.frame(datasets, tranche, avg_stability, delta_thr = round(delta_level2, 2))
cat("=== Stabilitaet (Mittel ueber 3 Folds) vs. Level-2-Delta gegen korrigierte Baseline ===\n")
print(df)

cat("\n=== Spearman: Stabilitaet vs. Delta (korrigierte Baseline) ===\n")
sp <- function(x, y) suppressWarnings(cor.test(x, y, method = "spearman", exact = FALSE))
sub_n6 <- tranche == "1"
sub_n10 <- tranche %in% c("1", "2")
for (lab in c("n=6", "n=10", "n=15")) {
  idx <- switch(lab, "n=6" = sub_n6, "n=10" = sub_n10, "n=15" = rep(TRUE, length(datasets)))
  ct <- sp(avg_stability[idx], delta_level2[idx])
  cat(sprintf("%-6s rho=%+.3f  p=%.3f\n", lab, ct$estimate, ct$p.value))
}

cat("\n=== Vorher (unkorrigierte v2-Baseline, Analyse von n=15) ===\n")
old_delta <- c(-3.7, 3.0, 0.1, -2.6, -1.9, 0.2, -0.07, 0.28, -0.20, 0.35, 20.11, -5.34, 9.04, 0.56, 0.05)
ct <- sp(avg_stability, old_delta)
cat(sprintf("n=15 rho=%+.3f  p=%.3f\n", ct$estimate, ct$p.value))

cat("\n=== Leave-one-out (n=15, korrigiert) ===\n")
loo <- vapply(seq_along(datasets), function(i) suppressWarnings(cor(avg_stability[-i], delta_level2[-i], method = "spearman")), numeric(1))
cat(sprintf("rho ueber LOO: [%.3f, %.3f]\n", min(loo), max(loo)))

out_path <- file.path(artifact_dir, "decision_stability_vs_thr_baseline_n15.csv")
fwrite(df, out_path)
cat("\nGespeichert:", out_path, "\n")
