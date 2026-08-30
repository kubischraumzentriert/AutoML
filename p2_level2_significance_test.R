# =====================================================================
# p2_level2_significance_test.R -- P2/Paper-Nachpruefung (2026-08-30):
# formaler Signifikanztest fuer den Level-1-vs-Level-2-Vergleich ueber
# die 6 externen P1-Datensaetze, statt nur informell "3 Siege/3
# Niederlagen" zu berichten.
# =====================================================================
# Methodik nach Demsar (2006), "Statistical Comparisons of Classifiers
# over Multiple Data Sets", JMLR - der Standard-Ansatz fuer den
# Vergleich zweier Verfahren ueber mehrere Datensaetze hinweg (auch
# implementiert im Python-Paket Autorank, Herbold 2020, JOSS - hier
# bewusst NICHT uebernommen, sondern dieselbe Methodik nativ in R
# angewendet, konsistent mit der R-only-Policy dieses Repos).
#
# WICHTIG: EIN aggregierter Wert pro Datensatz (nicht pro Outer-Fold) -
# Folds innerhalb eines Datensatzes sind nicht unabhaengig, ein Test auf
# Fold-Ebene wuerde die Stichprobengroesse kuenstlich aufblaehen und zu
# optimistische p-Werte liefern. Die Werte unten stammen direkt aus
# BACKLOG.md/P2-Status (v1/v2/v3-Zusammenfassungs-CSVs je Projekt).
#
# Ergebnis (siehe PAPER_DRAFT.md Abschnitt 6/8): V = 8, p = 0.6875 -
# bei n = 6 statistisch nicht von einem Nulleffekt unterscheidbar.
# Demsar selbst empfiehlt fuer den Wilcoxon-Test ~8-10 Datensaetze fuer
# ausreichende Power - das ist eine echte Stichprobengroessen-
# Einschraenkung, kein Statistik-Kunstfehler.

datasets <- c("ilpd", "sick", "blood-transfusion", "cmc", "analcatdata-authorship", "optdigits")
best_prior <- c(0.6840, 0.9714, 0.6576, 0.5374, 0.9921, 0.9840) # bisher bester Wert (v1 workflow_ranger oder v2 bester Konkurrent)
level2     <- c(0.6473, 0.9723, 0.6878, 0.5113, 0.9731, 0.9859) # v3 level2_workflow

delta <- level2 - best_prior
names(delta) <- datasets
cat("Deltas (Level2 - bisher bester Wert):\n")
print(round(delta, 4))
cat("\nMittelwert Delta:", round(mean(delta), 4), "\n")
cat("Median Delta:", round(median(delta), 4), "\n")

wt <- wilcox.test(level2, best_prior, paired = TRUE, exact = TRUE)
cat("\n=== Wilcoxon Signed-Rank Test (paired, exact, Demsar 2006) ===\n")
print(wt)

cat("\nSign-Test-Kontrolle (nur Vorzeichen, robust gegen Ausreisser):\n")
print(table(sign(delta)))
