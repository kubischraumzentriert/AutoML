# =====================================================================
# decision_stability_level2_analysis_weg_b.R -- P2, JOSS-Technique-Watch-
# Prototyp #1 (2026-08-31): "Weg B"-Erweiterung von n=6 auf n=10
# Datensaetze x alle 3 Outer-Folds (30 statt 18 Einzelmessungen) - haengt
# die Level-2-Arm-Wahl-Stabilitaet mit dem urspruenglichen Level-2-
# Ergebnis zusammen? Erweitert decision_stability_level2_analysis.R
# (dort: n=6, "Weg A" - mehr Outer-Folds statt neuer Datensaetze) um die
# 4 in EXTERNAL_BENCHMARK_SET.md eingefrorenen neuen Datensaetze.
# =====================================================================
# Werte stammen aus den 12 neuen decision_stability_level2_prototype.R-
# Laeufen (DECISION_STABILITY_OUTER_FOLD=1/2/3 x 4 Datensaetze) und den 4
# neuen outer_workflow_evaluation_v3_level2.R-Laeufen - keine erneuten
# Modell-Laeufe fuer die urspruenglichen 6, reine Nachanalyse-Erweiterung.

datasets <- c(
  "ilpd", "blood-transfusion", "sick", "cmc", "analcatdata-authorship", "optdigits",
  "phishing-websites", "qsar-biodeg", "mfeat-karhunen", "eucalyptus"
)
weg <- c(rep("A (urspruengliche 6)", 6), rep("B (neue 4)", 4))

# Stabilitaet je Datensatz x Fold.
stab_fold1 <- c(0.70, 0.60, 0.60, 0.50, 0.70, 0.60,  0.70, 0.50, 0.50, 0.50)
stab_fold2 <- c(0.70, 0.50, 1.00, 0.40, 0.80, 0.60,  0.60, 0.50, 0.40, 0.60)
stab_fold3 <- c(0.50, 0.60, 0.80, 0.50, 0.70, 0.60,  0.60, 0.50, 0.40, 0.60)
avg_stability <- (stab_fold1 + stab_fold2 + stab_fold3) / 3

# Level2@10evals - bester Baseline-Arm (mean_score), BAcc-Punkte*100 (Datensatz-Ebene).
# Urspruengliche 6 unveraendert; die neuen 4 aus outer_workflow_evaluation_v3_level2.R
# (level2_workflow mean_score - bester Baseline-Arm mean_score, siehe BACKLOG.md).
delta_level2 <- c(-3.7, 3.0, 0.1, -2.6, -1.9, 0.2,  -0.07, 0.28, -0.20, 0.35)

df <- data.frame(datasets, weg, stab_fold1, stab_fold2, stab_fold3, avg_stability, delta_level2)
cat("=== Decision-Stability ueber alle 3 Outer-Folds vs. Level-2-Ergebnis (n=10) ===\n")
print(df)

cat("\n=== Innerhalb-Datensatz-Konsistenz (Spannweite = max-min Stabilitaet ueber 3 Folds) ===\n")
spread <- apply(cbind(stab_fold1, stab_fold2, stab_fold3), 1, function(x) max(x) - min(x))
names(spread) <- datasets
print(round(spread, 2))

cat("\n=== Deskriptiv ueber alle 30 Einzelmessungen ===\n")
all_stab <- c(stab_fold1, stab_fold2, stab_fold3)
cat("Median:", median(all_stab), " Mittelwert:", round(mean(all_stab), 3),
    " Anteil geflaggt (<70%):", round(mean(all_stab < 0.7), 3), "von 30\n")

cat("\n=== Spearman: MITTLERE Stabilitaet ueber alle 3 Folds vs. Level-2-Delta (n=10, Weg A+B kombiniert) ===\n")
print(suppressWarnings(cor.test(avg_stability, delta_level2, method = "spearman")))

cat("\n=== Vergleich: n=6 (Weg A) vs. n=10 (Weg A+B) - haelt die Nicht-Korrelation stand? ===\n")
print(suppressWarnings(cor.test(avg_stability[weg == "A (urspruengliche 6)"], delta_level2[weg == "A (urspruengliche 6)"], method = "spearman")))
cat("\n(zum Vergleich, nur die neuen 4 - n zu klein fuer einen eigenen Test, nur deskriptiv)\n")
print(df[weg == "B (neue 4)", c("datasets", "avg_stability", "delta_level2")])
