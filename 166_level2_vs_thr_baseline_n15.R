rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
})

# =====================================================================
# 166_level2_vs_thr_baseline_n15.R -- Level 2 gegen schwellenkorrigierte
# Baseline auf den 15 externen OpenML-CC18-Datensaetzen.
# =====================================================================
# Hintergrund: Der Level-2-Lauf (Protokoll v3) wendet die Klassen-
# Multiplikatoren bereits an (Tuning auf dem Inner-Tune-Split). Der bisherige
# Vergleich in PAPER_DRAFT Abschnitt 6 nutzte aber als "best prior" die
# unkorrigierten v2-Baselines. Diese Auswertung ersetzt nur die Referenz
# durch `best_single_tuned_thr` (v4, mit Korrektur). Keine neuen Modelllaeufe.
#
# Vorab festgelegt: Primaer ist der Vorzeichen-Test pro Datensatz auf
# Datensatz-Mittel (wie in Abschnitt 6), d = level2_workflow -
# best_single_tuned_thr. Vorher stehende Referenzzahl: V = 69, p = 0.6387
# (gegen v2-Baseline, 9 Siege / 6 Niederlagen, n = 15).
#
# Sanity-Check: Die Folds sind identisch, wenn Protokoll v3 und v4 die gleichen
# Outer-Scores fuer `ranger_default` liefern (gleicher Seed, gleiche Folds).

ml_learning_root <- "C:/Users/HP/ML_Learning"
source("000_config.R")

boundary_path <- file.path(artifact_dir, "boundary_condition_n15.csv")
if (!file.exists(boundary_path)) stop("Zuerst 164 ausfuehren: ", boundary_path)
boundary <- fread(boundary_path)[, .(dataset, n, k, imb)]

res_path <- function(ds, v) file.path(ml_learning_root, paste0("openml-cc18-", ds), "_artifacts", paste0("outer_workflow_evaluation_", v, "_results.csv"))

per_fold <- rbindlist(lapply(boundary$dataset, function(ds) {
  v3 <- fread(res_path(ds, "v3"))[arm %in% c("level2_workflow", "ranger_default"), .(outer_fold, arm, score)]
  v4 <- fread(res_path(ds, "v4"))[arm %in% c("best_single_tuned_thr", "ranger_default"), .(outer_fold, arm, score)]
  v3 <- dcast(v3, outer_fold ~ arm, value.var = "score")
  v4 <- dcast(v4[arm == "best_single_tuned_thr"], outer_fold ~ arm, value.var = "score")
  m <- merge(v3, v4, by = "outer_fold")
  m[, dataset := ds]
  m
}))

# Fold-Identitaet pruefen: v3 und v4 muessen identische ranger_default-Scores liefern
ident <- rbindlist(lapply(boundary$dataset, function(ds) {
  a <- fread(res_path(ds, "v3"))[arm == "ranger_default", .(outer_fold, s3 = score)]
  b <- fread(res_path(ds, "v4"))[arm == "ranger_default", .(outer_fold, s4 = score)]
  m <- merge(a, b, by = "outer_fold")
  data.table(dataset = ds, max_abs_diff = max(abs(m$s3 - m$s4)))
}))
cat("=== Fold-Identitaet (ranger_default, v3 vs v4) ===\n")
print(ident[, .(dataset, max_abs_diff = signif(max_abs_diff, 3))])
if (any(ident$max_abs_diff > 1e-6)) warning("Folds nicht identisch - Vergleich nicht gepaart belastbar")

ds_tab <- per_fold[, .(level2 = mean(level2_workflow), best_thr = mean(best_single_tuned_thr)), by = dataset]
ds_tab <- merge(boundary, ds_tab, by = "dataset")
ds_tab[, d := level2 - best_thr]
setorder(ds_tab, -imb)

cat(sprintf("\n=== Level 2 - best_single_tuned_thr (BAcc-Punkte), %d Datensaetze, nach Unbalanciertheit ===\n", nrow(ds_tab)))
print(ds_tab[, .(dataset, n, imb = round(imb, 2), level2 = round(100 * level2, 1), best_thr = round(100 * best_thr, 1), d = round(100 * d, 1))])

w <- suppressWarnings(wilcox.test(ds_tab$d, mu = 0, exact = FALSE))
cat(sprintf("\nWins %d / Verluste %d, Median %+.2f, Mittel %+.2f Punkte\n",
            sum(ds_tab$d > 0), sum(ds_tab$d < 0), 100 * median(ds_tab$d), 100 * mean(ds_tab$d)))
cat(sprintf("Wilcoxon (zweiseitig): p = %.4f\n", w$p.value))

ct <- suppressWarnings(cor.test(ds_tab$imb, ds_tab$d, method = "spearman", exact = FALSE))
cat(sprintf("Spearman(Unbalanciertheit, d): rho = %+.3f, p = %.3f\n", ct$estimate, ct$p.value))

out_path <- file.path(artifact_dir, "level2_vs_thr_baseline_n15.csv")
fwrite(ds_tab, out_path)
cat("\nGespeichert:", out_path, "\n")
