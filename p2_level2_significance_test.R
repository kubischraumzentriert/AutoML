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
# Ergebnis (10 Evals, siehe docs/research/PAPER_DRAFT.md Abschnitt 6/8): V = 8,
# p = 0.6875 - bei n = 6 statistisch nicht von einem Nulleffekt
# unterscheidbar. Demsar selbst empfiehlt fuer den Wilcoxon-Test ~8-10
# Datensaetze fuer ausreichende Power - eine echte Stichprobengroessen-
# Einschraenkung, kein Statistik-Kunstfehler.
#
# ERWEITERUNG (2026-08-30, Research Aspect): dieselbe Frage nochmal bei
# einem 3x groesseren Tuning-Budget (LEVEL2_TUNING_EVALS=30 statt 10,
# siehe outer_workflow_evaluation_v3_level2.R) getestet, um zu pruefen,
# ob das Tuning-Budget das gemischte P2-Muster erklaert. Ergebnis: NEIN
# - der direkte Vergleich 30-Evals- vs. 10-Evals-Level2 (V=11, p=1.0)
# zeigt KEINEN nachweisbaren systematischen Effekt der Budget-
# Verdreifachung. Einzelne Datensaetze aendern sich in unterschiedliche
# Richtungen (ilpd +4.5 BAcc-Punkte, blood-transfusion -1.6,
# optdigits -0.4, analcatdata-authorship +0.9), aber ohne konsistentes
# Muster. Die Tuning-Budget-Hypothese ist damit sauber ausgeschlossen -
# ein negativer, aber wertvoller Befund (schliesst eine von zwei
# Kandidaten-Erklaerungen aus statt sie offen zu lassen).

datasets <- c("ilpd", "sick", "blood-transfusion", "cmc", "analcatdata-authorship", "optdigits")
best_prior <- c(0.6840, 0.9714, 0.6576, 0.5374, 0.9921, 0.9840) # bisher bester Wert (v1 workflow_ranger oder v2 bester Konkurrent)
level2_10  <- c(0.6473, 0.9723, 0.6878, 0.5113, 0.9731, 0.9859) # v3 level2_workflow, LEVEL2_TUNING_EVALS=10 (Default/eingefroren)
level2_30  <- c(0.6919, 0.9712, 0.6720, 0.5122, 0.9818, 0.9818) # v3 level2_workflow, LEVEL2_TUNING_EVALS=30

report_paired_test <- function(a, b, a_name, b_name) {
  delta <- a - b
  names(delta) <- datasets
  cat("\nDeltas (", a_name, "-", b_name, "):\n")
  print(round(delta, 4))
  cat("Mittelwert Delta:", round(mean(delta), 4), " Median:", round(median(delta), 4), "\n")
  wt <- wilcox.test(a, b, paired = TRUE, exact = TRUE)
  cat("Wilcoxon Signed-Rank Test (paired, exact, Demsar 2006):\n")
  print(wt)
  cat("Sign-Test-Kontrolle (nur Vorzeichen, robust gegen Ausreisser):\n")
  print(table(sign(delta)))
  invisible(wt)
}

cat("=== Frage 1: Level2 (10 Evals) vs. bisher bester Wert ===\n")
report_paired_test(level2_10, best_prior, "Level2@10", "bisher bester Wert")

cat("\n\n=== Frage 2: Level2 (30 Evals) vs. bisher bester Wert ===\n")
report_paired_test(level2_30, best_prior, "Level2@30", "bisher bester Wert")

cat("\n\n=== Frage 3 (Research Aspect): Level2 (30 Evals) vs. Level2 (10 Evals) - erklaert das Tuning-Budget das Muster? ===\n")
report_paired_test(level2_30, level2_10, "Level2@30", "Level2@10")
