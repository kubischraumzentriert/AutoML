# =====================================================================
# decision_stability_level2_analysis.R -- P2, JOSS-Technique-Watch-
# Prototyp #1 (2026-08-30): Nachanalyse ueber alle 6 externen
# Datensaetze x alle 3 Outer-Folds (18 Einzelmessungen, "Weg A" -
# mehr Outer-Folds statt neuer Datensaetze) - haengt die Level-2-Arm-
# Wahl-Stabilitaet mit dem urspruenglichen Level-2-Ergebnis (P2-Rollout,
# siehe BACKLOG.md) zusammen?
# =====================================================================
# Werte stammen aus den 18 einzelnen decision_stability_level2_prototype.R-
# Laeufen (Konsolenausgabe/Evidence Registry, DECISION_STABILITY_OUTER_
# FOLD=1/2/3) und dem urspruenglichen Protokoll-v3-Rollout - keine neuen
# Modell-Laeufe fuer die Delta-Werte, reine Nachanalyse.

datasets <- c("ilpd", "blood-transfusion", "sick", "cmc", "analcatdata-authorship", "optdigits")

# Stabilitaet je Datensatz x Fold (aus allen 18 Einzellaeufen)
stab_fold1 <- c(0.70, 0.60, 0.60, 0.50, 0.70, 0.60)
stab_fold2 <- c(0.70, 0.50, 1.00, 0.40, 0.80, 0.60)
stab_fold3 <- c(0.50, 0.60, 0.80, 0.50, 0.70, 0.60)
avg_stability <- (stab_fold1 + stab_fold2 + stab_fold3) / 3
flagged_fold1 <- stab_fold1 < 0.7 # nur zum Vergleich mit dem urspruenglichen n=6/Fold-1-Befund

delta_level2 <- c(-3.7, 3.0, 0.1, -2.6, -1.9, 0.2) # Level2@10evals - bisher bester Wert, BAcc-Punkte (Datensatz-Ebene, unveraendert)

df <- data.frame(datasets, stab_fold1, stab_fold2, stab_fold3, avg_stability, delta_level2)
cat("=== Decision-Stability ueber alle 3 Outer-Folds vs. urspruengliches Level-2-Ergebnis ===\n")
print(df)

cat("\n=== Innerhalb-Datensatz-Konsistenz (Spannweite = max-min Stabilitaet ueber 3 Folds) ===\n")
spread <- apply(cbind(stab_fold1, stab_fold2, stab_fold3), 1, function(x) max(x) - min(x))
names(spread) <- datasets
print(round(spread, 2))

cat("\n=== Deskriptiv ueber alle 18 Einzelmessungen ===\n")
all_stab <- c(stab_fold1, stab_fold2, stab_fold3)
cat("Median:", median(all_stab), " Mittelwert:", round(mean(all_stab), 3),
    " Anteil geflaggt (<70%):", round(mean(all_stab < 0.7), 3), "von 18\n")

cat("\n=== Spearman: NUR Fold 1 (urspruenglicher n=6-Befund, zum Vergleich) ===\n")
print(suppressWarnings(cor.test(stab_fold1, delta_level2, method = "spearman")))

cat("\n=== Spearman: MITTLERE Stabilitaet ueber alle 3 Folds vs. Level-2-Delta (n=6) ===\n")
cat("WICHTIG: dies ist der robustere Wert nach der 'Weg A'-Erweiterung -\n")
cat("die Korrelation aus dem Fold-1-only-Befund haelt NICHT stand.\n\n")
print(suppressWarnings(cor.test(avg_stability, delta_level2, method = "spearman")))
