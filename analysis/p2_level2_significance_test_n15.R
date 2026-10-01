# =====================================================================
# p2_level2_significance_test_n15.R -- Wiederholung von
# p2_level2_significance_test.R (2026-08-30, n=6) auf dem inzwischen auf
# n=15 erweiterten externen Benchmark-Set (Weg B, 1./2. Tranche,
# 2026-08-31/2026-09-01). Demsar (2006) empfiehlt fuer den Wilcoxon-Test
# ~8-10 Datensaetze fuer ausreichende Power - bei n=6 war das Ergebnis
# (V=8, p=0.6875) explizit als unterpowert dokumentiert, nicht als
# belastbarer Nulleffekt. n=15 erreicht diese Schwelle erstmals fuer
# GENAU diesen Test (die Decision-Stability-Korrelation wurde separat
# schon bei n=6/10/15 getestet, siehe PAPER_DRAFT.md Abschnitt 7.3 - der
# urspruengliche Sieg/Niederlage-Signifikanztest selbst aber nie).
#
# Reine Nachanalyse bereits vorhandener, geloggter Zahlen (kein neuer
# Modell-Lauf) - Level2@10-vs-bester-Baseline-Delta je Datensatz, Quellen:
#   - Urspruengliche 6: p2_level2_significance_test.R (Zeilen 39-41)
#   - Weg B, 1. Tranche (+4, n=10): BACKLOG.md "Weg B"-Erweiterung n=6->10
#     (2026-08-31), Level-2-Prototyp-Ergebnisse-Tabelle
#   - Weg B, 2. Tranche (+5, n=15): BACKLOG.md "Weg B", 2. Tranche: n=10->15
#     (2026-09-01), Level-2-Prototyp-Ergebnisse-Tabelle
#
# Einheiten vereinheitlicht auf BAcc-Prozentpunkte (Level2 - beste
# Baseline). Fuer den Wilcoxon-Signed-Rank-Test ist nur Vorzeichen+Rang
# der Differenzen relevant - eine konstante Skalierung (Bruchteil vs.
# Prozentpunkte) aendert weder Vorzeichen noch Rangfolge, der Test ist
# also unveraendert gueltig trotz der zwei unterschiedlich skalierten
# Quelltabellen.

datasets <- c(
  # urspruengliche 6 (P1-Rollout)
  "ilpd", "sick", "blood-transfusion", "cmc", "analcatdata-authorship", "optdigits",
  # Weg B, 1. Tranche (n=10)
  "PhishingWebsites", "qsar-biodeg", "mfeat-karhunen", "eucalyptus",
  # Weg B, 2. Tranche (n=15)
  "ozone-level-8hr", "jm1", "dresses-sales", "MiceProtein", "mfeat-morphological"
)

delta_pts <- c(
  # urspruengliche 6: (level2_10 - best_prior) * 100, aus den Bruchteilen
  # in p2_level2_significance_test.R Zeilen 40-41
  (0.6473 - 0.6840) * 100,  # ilpd
  (0.9723 - 0.9714) * 100,  # sick
  (0.6878 - 0.6576) * 100,  # blood-transfusion
  (0.5113 - 0.5374) * 100,  # cmc
  (0.9731 - 0.9921) * 100,  # analcatdata-authorship
  (0.9859 - 0.9840) * 100,  # optdigits
  # Weg B, 1. Tranche (bereits in BAcc-Punkten, siehe Quelltabelle)
  -0.07,   # PhishingWebsites
  0.28,    # qsar-biodeg
  -0.20,   # mfeat-karhunen
  0.35,    # eucalyptus
  # Weg B, 2. Tranche (bereits in BAcc-Punkten, siehe Quelltabelle)
  20.11,   # ozone-level-8hr
  9.04,    # jm1
  -5.34,   # dresses-sales
  0.56,    # MiceProtein
  0.05     # mfeat-morphological
)
names(delta_pts) <- datasets

cat("=== P2 Level-2 vs. beste Baseline: Delta je Datensatz (BAcc-Punkte, n =", length(delta_pts), ") ===\n")
print(round(delta_pts, 3))
cat("\nMittelwert Delta:", round(mean(delta_pts), 3), " Median:", round(median(delta_pts), 3), "\n")
cat("Siege/Niederlagen (Vorzeichen):\n")
print(table(sign(delta_pts)))

cat("\n=== Wilcoxon Signed-Rank Test (paired, exact, Demsar 2006), n =", length(delta_pts), "===\n")
wt <- wilcox.test(delta_pts, mu = 0, exact = TRUE)
print(wt)

cat("\n=== Zum Vergleich: derselbe Test bei n=6 (p2_level2_significance_test.R) ===\n")
cat("V = 8, p = 0.6875\n")

cat("\n=== Einordnung ===\n")
if (wt$p.value < 0.05) {
  cat("Bei n=15 (ausreichende Power nach Demsar 2006) WIRD der Level-1-vs-\n")
  cat("Level-2-Unterschied statistisch signifikant (p =", round(wt$p.value, 4), ").\n")
  cat("Pruefen, ob dies durch die beiden grossen Ausreisser (ozone-level-8hr\n")
  cat("+20.11, jm1 +9.04 - beide stark unbalancierte binaere Aufgaben) getrieben\n")
  cat("wird, oder ob ein robusteres Bild (z.B. ohne diese 2) weiterhin gilt.\n")
} else {
  cat("Auch bei n=15 (ausreichende Power nach Demsar 2006) bleibt der Level-1-\n")
  cat("vs-Level-2-Unterschied NICHT signifikant (p =", round(wt$p.value, 4), ") - ein\n")
  cat("deutlich belastbareres Nullergebnis als die urspruengliche n=6-Messung,\n")
  cat("da die Stichprobengroessen-Einschraenkung aus 2026-08-30 jetzt behoben ist.\n")
}

# Sensitivitaet: robust gegen die beiden grossen Ausreisser (ozone-level-8hr,
# jm1)? Beide sind extrem unbalancierte binaere Aufgaben, wo Level-2s
# Klassengewichtung+Tuning strukturell besonders viel bringen kann - eine
# andere Projektklasse als die uebrigen 13.
cat("\n=== Sensitivitaet: ohne die 2 staerksten unbalancierten Ausreisser (ozone-level-8hr, jm1) ===\n")
delta_pts_robust <- delta_pts[!names(delta_pts) %in% c("ozone-level-8hr", "jm1")]
cat("n =", length(delta_pts_robust), "\n")
wt_robust <- wilcox.test(delta_pts_robust, mu = 0, exact = TRUE)
print(wt_robust)
