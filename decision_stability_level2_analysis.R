# =====================================================================
# decision_stability_level2_analysis.R -- P2, JOSS-Technique-Watch-
# Prototyp #1 (2026-08-30): Nachanalyse ueber alle 6 externen
# Datensaetze - haengt die Level-2-Arm-Wahl-Stabilitaet mit dem
# urspruenglichen Level-2-Ergebnis (P2-Rollout, siehe BACKLOG.md)
# zusammen?
# =====================================================================
# Werte stammen aus den 6 einzelnen decision_stability_level2_prototype.R-
# Laeufen (Konsolenausgabe/Evidence Registry) und dem urspruenglichen
# Protokoll-v3-Rollout - keine neuen Modell-Laeufe, reine Nachanalyse.

datasets <- c("ilpd", "blood-transfusion", "sick", "cmc", "analcatdata-authorship", "optdigits")
stability <- c(0.70, 0.60, 0.60, 0.50, 0.70, 0.60)
flagged   <- c(FALSE, TRUE, TRUE, TRUE, FALSE, TRUE)
delta_level2 <- c(-3.7, 3.0, 0.1, -2.6, -1.9, 0.2) # Level2@10evals - bisher bester Wert, BAcc-Punkte

df <- data.frame(datasets, stability, flagged, delta_level2)
cat("=== Decision-Stability (Outer-Fold 1) vs. urspruengliches Level-2-Ergebnis ===\n")
print(df)

cat("\nMittlerer Delta bei GEFLAGGTEN (instabilen, <70%) Datensaetzen:", mean(delta_level2[flagged]), "\n")
cat("Mittlerer Delta bei NICHT geflaggten (stabilen, >=70%) Datensaetzen:", mean(delta_level2[!flagged]), "\n")

cat("\n=== Spearman-Korrelation: Stabilitaet vs. Level-2-Delta (n=6, explorativ) ===\n")
print(suppressWarnings(cor.test(stability, delta_level2, method = "spearman")))

cat("\n=== Wilcoxon-Rangsummentest: geflaggt vs. nicht geflaggt ===\n")
print(wilcox.test(delta_level2[flagged], delta_level2[!flagged]))
