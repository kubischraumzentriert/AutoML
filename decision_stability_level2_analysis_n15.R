# =====================================================================
# decision_stability_level2_analysis_n15.R -- P2, JOSS-Technique-Watch-
# Prototyp #1 (2026-09-01): Erweiterung von n=10 auf n=15 Datensaetze x
# alle 3 Outer-Folds (45 statt 30 Einzelmessungen) - haengt die Level-2-
# Arm-Wahl-Stabilitaet mit dem urspruenglichen Level-2-Ergebnis zusammen?
# Erweitert decision_stability_level2_analysis_weg_b.R (dort: n=10) um
# die 5 in EXTERNAL_BENCHMARK_SET.md eingefrorenen "Weg B, 2. Tranche"-
# Datensaetze.
# =====================================================================
# Werte stammen aus den 15 neuen decision_stability_level2_prototype.R-
# Laeufen (DECISION_STABILITY_OUTER_FOLD=1/2/3 x 5 Datensaetze) und den 5
# neuen outer_workflow_evaluation_v3_level2.R-Laeufen - keine erneuten
# Modell-Laeufe fuer die urspruenglichen 10, reine Nachanalyse-Erweiterung.

datasets <- c(
  "ilpd", "blood-transfusion", "sick", "cmc", "analcatdata-authorship", "optdigits",
  "phishing-websites", "qsar-biodeg", "mfeat-karhunen", "eucalyptus",
  "ozone-level-8hr", "dresses-sales", "jm1", "mice-protein", "mfeat-morphological"
)
tranche <- c(rep("1 (urspruengliche 6)", 6), rep("2 (Weg B, 1. Tranche)", 4), rep("3 (Weg B, 2. Tranche, n=15)", 5))

stab_fold1 <- c(0.70, 0.60, 0.60, 0.50, 0.70, 0.60,  0.70, 0.50, 0.50, 0.50,  0.70, 0.60, 0.60, 0.60, 0.50)
stab_fold2 <- c(0.70, 0.50, 1.00, 0.40, 0.80, 0.60,  0.60, 0.50, 0.40, 0.60,  0.60, 0.80, 0.50, 0.70, 0.60)
stab_fold3 <- c(0.50, 0.60, 0.80, 0.50, 0.70, 0.60,  0.60, 0.50, 0.40, 0.60,  0.90, 0.50, 0.50, 0.40, 0.70)
avg_stability <- (stab_fold1 + stab_fold2 + stab_fold3) / 3

# Level2@10evals - bester Baseline-Arm (mean_score), BAcc-Punkte*100 (Datensatz-Ebene).
delta_level2 <- c(
  -3.7, 3.0, 0.1, -2.6, -1.9, 0.2,          # urspruengliche 6
  -0.07, 0.28, -0.20, 0.35,                  # Weg B, 1. Tranche
  20.11, -5.34, 9.04, 0.56, 0.05             # Weg B, 2. Tranche (n=15)
)

df <- data.frame(datasets, tranche, stab_fold1, stab_fold2, stab_fold3, avg_stability, delta_level2)
cat("=== Decision-Stability ueber alle 3 Outer-Folds vs. Level-2-Ergebnis (n=15) ===\n")
print(df)

cat("\n=== Innerhalb-Datensatz-Konsistenz (Spannweite = max-min Stabilitaet ueber 3 Folds) ===\n")
spread <- apply(cbind(stab_fold1, stab_fold2, stab_fold3), 1, function(x) max(x) - min(x))
names(spread) <- datasets
print(round(spread, 2))

cat("\n=== Deskriptiv ueber alle 45 Einzelmessungen ===\n")
all_stab <- c(stab_fold1, stab_fold2, stab_fold3)
cat("Median:", median(all_stab), " Mittelwert:", round(mean(all_stab), 3),
    " Anteil geflaggt (<70%):", round(mean(all_stab < 0.7), 3), "von 45\n")

cat("\n=== Spearman: MITTLERE Stabilitaet ueber alle 3 Folds vs. Level-2-Delta (n=15, alle 3 Tranchen kombiniert) ===\n")
print(suppressWarnings(cor.test(avg_stability, delta_level2, method = "spearman")))

cat("\n=== Vergleich: n=6 vs. n=10 vs. n=15 - haelt die Nicht-Korrelation stand? ===\n")
cat("n=6 (nur urspruengliche):\n")
print(suppressWarnings(cor.test(avg_stability[tranche == "1 (urspruengliche 6)"], delta_level2[tranche == "1 (urspruengliche 6)"], method = "spearman"))$estimate)
cat("n=10 (urspruengliche 6 + Weg B 1. Tranche):\n")
sub_n10 <- tranche %in% c("1 (urspruengliche 6)", "2 (Weg B, 1. Tranche)")
print(suppressWarnings(cor.test(avg_stability[sub_n10], delta_level2[sub_n10], method = "spearman"))$estimate)
cat("n=15 (alle):\n")
print(suppressWarnings(cor.test(avg_stability, delta_level2, method = "spearman"))$estimate)

cat("\n=== Einzelfall-Hinweis: ozone-level-8hr kombiniert HOHE Stabilitaet (70/60/90%) MIT dem groessten\n")
cat("Level-2-Vorteil (+20.1 BAcc-Punkte) - genau in die 'Stabilitaet korreliert mit Erfolg'-Richtung, aber\n")
cat("ein einzelner Datenpunkt aendert die Gesamtkorrelation nicht signifikant (siehe rho oben).\n")
