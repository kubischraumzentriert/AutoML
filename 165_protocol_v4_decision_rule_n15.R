rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
})

# =====================================================================
# 165_protocol_v4_decision_rule_n15.R -- Auswertung Protokoll v4
# (Entscheidungsregel) auf den 15 externen OpenML-CC18-Datensaetzen.
# =====================================================================
# Frage: Stammt der Vorsprung von `workflow_ranger` gegenueber der besten
# getunten Baseline nur aus der Entscheidungsregel (Klassen-Multiplikatoren
# auf die Wahrscheinlichkeiten), oder traegt die Klassengewichtung im
# Training zusaetzlich etwas bei?
#
# Vorab festgelegt (vor dem Lauf von v4, siehe BACKLOG.md "Protokoll v4"):
#   - Primaertest: d_thr = workflow_ranger - best_single_tuned_thr
#     (Inner-Score-Wahl, schaut nie auf den Outer-Test), in BAcc-Punkten.
#   - Grenzbedingung: Spearman(Unbalanciertheit, d_thr). Unbalanciertheit
#     kommt aus 164 (boundary_condition_n15.csv, log10 Mehrheit/Minderheit).
#   - Attribution (zusaetzlich, deskriptiv):
#       rule_default = ranger_default_thr - ranger_default
#           (Entscheidungsregel allein, Default-Modell)
#       rule_tuned   = tuned_ranger_thr - tuned_ranger
#           (Entscheidungsregel allein, getuntes Modell)
#       weighting    = workflow_ranger - ranger_default_thr
#           (Rest: Klassengewichtung + Multiplier-Tuning gegenueber
#            Default mit Schwelle)
# Eingabe: Ausgaben von Protokoll v4 je Datensatz unter
#   ML_Learning/openml-cc18-<ds>/_artifacts/outer_workflow_evaluation_v4_summary.csv
# sowie _artifacts/boundary_condition_n15.csv aus 164.
# Keine neuen Modelllaeufe. Grenzen: n=15, 3 Outer-Folds, Datensatzauswahl
# vom selben Team, keine Mehrfachtest-Korrektur ueber die Attributionen.

source("000_config.R")

ml_learning_root <- "C:/Users/HP/ML_Learning"
boundary_path <- file.path(artifact_dir, "boundary_condition_n15.csv")
if (!file.exists(boundary_path)) stop("Zuerst 164_boundary_condition_n15.R ausfuehren: ", boundary_path)
boundary <- fread(boundary_path)[, .(dataset, n, k, imb)]

summary_path <- function(ds) file.path(ml_learning_root, paste0("openml-cc18-", ds), "_artifacts", "outer_workflow_evaluation_v4_summary.csv")
missing <- boundary$dataset[!file.exists(summary_path(boundary$dataset))]
if (length(missing)) stop("v4-Summary fehlt fuer: ", paste(missing, collapse = ", "))

long <- rbindlist(lapply(boundary$dataset, function(ds) {
  s <- fread(summary_path(ds))
  s[, dataset := ds]
  s[, .(dataset, arm, mean_score)]
}))
wide <- dcast(long, dataset ~ arm, value.var = "mean_score")
tab <- merge(boundary, wide, by = "dataset")

tab[, `:=`(
  d_thr = workflow_ranger - best_single_tuned_thr,
  rule_default = ranger_default_thr - ranger_default,
  rule_tuned = tuned_ranger_thr - tuned_ranger,
  weighting = workflow_ranger - ranger_default_thr,
  d_ranger_thr = workflow_ranger - tuned_ranger_thr
)]
setorder(tab, -imb)

cat(sprintf("=== Protokoll v4, %d Datensaetze, nach Unbalanciertheit ===\n", nrow(tab)))
print(tab[, .(dataset, n, k, imb = round(imb, 2),
              d_thr = round(100 * d_thr, 1),
              rule_default = round(100 * rule_default, 1),
              rule_tuned = round(100 * rule_tuned, 1),
              weighting = round(100 * weighting, 1))])

delta_cols <- c("d_thr", "d_ranger_thr", "rule_default", "rule_tuned", "weighting")

cat("\n--- Gepaart: Median/Mittel/Siege, Wilcoxon (zweiseitig) ---\n")
for (v in delta_cols) {
  x <- tab[[v]]
  p <- suppressWarnings(wilcox.test(x, exact = FALSE)$p.value)
  cat(sprintf("%-13s median=%+.2f  mean=%+.2f  Siege=%d/%d  p=%.3f\n", v, 100 * median(x), 100 * mean(x), sum(x > 0), length(x), p))
}

cat("\n--- Grenzbedingung: Spearman(Unbalanciertheit, Delta); d_thr ist der Primaertest ---\n")
for (v in delta_cols) {
  ct <- suppressWarnings(cor.test(tab$imb, tab[[v]], method = "spearman", exact = FALSE))
  cat(sprintf("%-13s rho=%+.3f  p=%.3f\n", v, ct$estimate, ct$p.value))
}

cat("\n--- Leave-one-out (Primaertest d_thr) ---\n")
loo <- vapply(seq_len(nrow(tab)), function(i) suppressWarnings(cor(tab$imb[-i], tab$d_thr[-i], method = "spearman")), numeric(1))
cat(sprintf("rho ueber LOO: [%.3f, %.3f]\n", min(loo), max(loo)))

# --- Streuung der Klassen-Multiplikatoren (Fold-Ebene) ---
# Spannweite je Fold = max/min ueber die Klassen-Multiplikatoren. Der
# Multiplikator-Vektor ist nur bis auf einen gemeinsamen Faktor bestimmt,
# daher zaehlt das Verhaeltnis max/min, nicht der Absolutwert.
spread_arms <- c("workflow_ranger", "ranger_default_thr", "tuned_ranger_thr", "lightgbm_default_thr", "tuned_lightgbm_thr")
spread <- rbindlist(lapply(boundary$dataset, function(ds) {
  r <- fread(file.path(ml_learning_root, paste0("openml-cc18-", ds), "_artifacts", "outer_workflow_evaluation_v4_results.csv"))
  r <- r[arm %in% spread_arms & nzchar(detail)]
  r[, {
    vals <- as.numeric(sub(".*=", "", strsplit(detail, ";", fixed = TRUE)[[1]]))
    list(dataset = ds, outer_fold = outer_fold, spread = max(vals) / min(vals), max_mult = max(vals))
  }, by = .(arm, outer_fold, detail)]
}))

cat("\n--- Multiplikator-Streuung (max/min je Fold), Median und Maximum je Arm ---\n")
spread_sum <- spread[, .(median_spread = median(spread), max_spread = max(spread),
                         max_mult = max(max_mult), n_folds = .N), by = arm]
print(spread_sum[, .(arm, n_folds, median_spread = round(median_spread, 2),
                     max_spread = round(max_spread, 1), max_mult = round(max_mult, 1))])
cat("Extremwerte (max/min > 10):\n")
print(spread[spread > 10, .(dataset, arm, outer_fold, spread = round(spread, 1))])

out_path <- file.path(artifact_dir, "protocol_v4_decision_rule_n15.csv")
fwrite(tab, out_path)
cat("\nGespeichert:", out_path, "\n")
