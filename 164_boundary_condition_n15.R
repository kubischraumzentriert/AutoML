rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
})

# =====================================================================
# 164_boundary_condition_n15.R -- Grenzbedingung des Level-1-Vorteils
# bei n=15 externen OpenML-CC18-Datensaetzen (2026-11-01).
# =====================================================================
# Frage: Waechst der Vorsprung von `workflow_ranger` gegenueber FAIR
# getunten Baselines mit der Klassen-Unbalanciertheit? (Aussage im
# PAPER_DRAFT Abschnitt 5.3, bisher nur auf n=6 gestuetzt; die Aussage
# "kleiner/unausgeglichener vs. groesser/balanciert" vermengte dort
# Groesse und Unbalanciertheit.)
#
# Vorab festgelegt (vor dem ersten Lauf):
#   - Delta = workflow_ranger - best_single_tuned_model (Inner-Score-Wahl,
#     schaut nie auf den Outer-Test), in Balanced-Accuracy-Punkten.
#   - Unbalanciertheit = log10(Mehrheitsklasse / Minderheitsklasse) im
#     tatsaechlich verwendeten Trainings-Task (task_train_small.rds).
#   - Primaertest: Spearman(Unbalanciertheit, Delta). Die uebrigen
#     Konkurrenten (tuned_lightgbm, tuned_ranger, max der beiden) sind
#     Sensitivitaetspruefungen, keine weiteren Primaertests.
# Eingabe: Ausgabe von 163_benchmark_statistics_report_n15.R. Keine neuen
# Modelllaeufe. Grenzen: n=15, 3 Outer-Folds, Datensatzauswahl vom selben
# Team, Mehrklassen-Unbalanciertheit grob, keine Mehrfachtest-Korrektur
# ueber die Sensitivitaeten.

source("000_config.R")

ml_learning_root <- "C:/Users/HP/ML_Learning"
scores_path <- file.path(artifact_dir, "benchmark_statistics_report_cc18_n15.csv")
if (!file.exists(scores_path)) stop("Zuerst 163_benchmark_statistics_report_n15.R ausfuehren: ", scores_path)

scores <- fread(scores_path)
datasets <- unique(scores$dataset)

info <- rbindlist(lapply(datasets, function(ds) {
  task_path <- file.path(ml_learning_root, paste0("openml-cc18-", ds), "_artifacts", "task_train_small.rds")
  if (!file.exists(task_path)) stop("Task fehlt: ", task_path)
  task <- readRDS(task_path)
  counts <- table(task$truth())
  data.table(dataset = ds, n = task$nrow, k = length(counts), imb = log10(max(counts) / min(counts)))
}))

wide <- dcast(scores, dataset ~ arm, value.var = "mean_score")
tab <- merge(info, wide, by = "dataset")
tab[, `:=`(
  d_best_single = workflow_ranger - best_single_tuned_model,
  d_tuned_lgbm = workflow_ranger - tuned_lightgbm,
  d_tuned_ranger = workflow_ranger - tuned_ranger,
  d_max_tuned = workflow_ranger - pmax(tuned_ranger, tuned_lightgbm)
)]
setorder(tab, -imb)

cat(sprintf("=== Delta workflow_ranger minus Konkurrent (BAcc-Punkte), %d Datensaetze, nach Unbalanciertheit ===\n", nrow(tab)))
print(tab[, .(dataset, n, k, imb = round(imb, 2),
              d_best_single = round(100 * d_best_single, 1), d_tuned_lgbm = round(100 * d_tuned_lgbm, 1),
              d_tuned_ranger = round(100 * d_tuned_ranger, 1))])

delta_cols <- c("d_best_single", "d_tuned_lgbm", "d_tuned_ranger", "d_max_tuned")

cat("\n--- Gepaart: Median/Mittel/Siege, Wilcoxon (zweiseitig) ---\n")
for (v in delta_cols) {
  x <- tab[[v]]
  p <- suppressWarnings(wilcox.test(x, exact = FALSE)$p.value)
  cat(sprintf("%-15s median=%+.2f  mean=%+.2f  Siege=%d/%d  p=%.3f\n", v, 100 * median(x), 100 * mean(x), sum(x > 0), length(x), p))
}

cat("\n--- Grenzbedingung: Spearman(Unbalanciertheit, Delta); d_best_single ist der Primaertest ---\n")
for (v in delta_cols) {
  ct <- suppressWarnings(cor.test(tab$imb, tab[[v]], method = "spearman", exact = FALSE))
  cat(sprintf("%-15s rho=%+.3f  p=%.3f\n", v, ct$estimate, ct$p.value))
}

cat("\n--- Konfundierung mit der Groesse ---\n")
ct <- suppressWarnings(cor.test(tab$imb, log10(tab$n), method = "spearman", exact = FALSE))
cat(sprintf("Unbalanciertheit ~ log10(n): rho=%+.3f p=%.3f\n", ct$estimate, ct$p.value))
ct <- suppressWarnings(cor.test(log10(tab$n), tab$d_best_single, method = "spearman", exact = FALSE))
cat(sprintf("d_best_single ~ log10(n):    rho=%+.3f p=%.3f\n", ct$estimate, ct$p.value))
fit <- lm(d_best_single ~ imb + log10(n), data = tab)
cat("lm(d_best_single ~ imb + log10(n)), Delta in Anteilen (1 = 100 BAcc-Punkte):\n")
print(round(summary(fit)$coefficients, 4))

cat("\n--- Leave-one-out (Primaertest) ---\n")
loo <- vapply(seq_len(nrow(tab)), function(i) suppressWarnings(cor(tab$imb[-i], tab$d_best_single[-i], method = "spearman")), numeric(1))
cat(sprintf("rho ueber LOO: [%.3f, %.3f]\n", min(loo), max(loo)))

out_path <- file.path(artifact_dir, "boundary_condition_n15.csv")
fwrite(tab, out_path)
cat("\nGespeichert:", out_path, "\n")
