# =============================================================================
# decision_stability.R -- P2, JOSS-Technique-Watch-Prototyp #1 (2026-08-30,
# siehe JOSS_TECHNIQUE_WATCH.md, inspiriert durch VeridicalFlow/PCS -
# Duncan et al. 2022, JOSS 10.21105/joss.03895).
# =============================================================================
# LUECKE, die dieses Modul schliesst: `seed_stability.R` misst, wie sehr der
# SCORE (eine kontinuierliche Zahl) bei fixen Daten allein durch den Lerner-
# Seed schwankt. Es beantwortet NICHT die Frage, ob eine kategoriale
# ENTSCHEIDUNG (welches Modell gewinnt, welcher Ensemble-Kandidat wird
# gewaehlt, welcher Threshold-Bucket) unter denselben kleinen Variationen
# STABIL bleibt oder bei einer anderen Ziehung leicht kippt. Eine Entscheidung
# kann bei praktisch identischem Score trotzdem knapp/instabil sein (z.B.
# Inner-Scores 0.973 vs. 0.974 vs. 0.975 - "der Sieger" ist dann eher Zufall
# als ein robuster Befund). Genau das ist die Kernidee von VeridicalFlow's
# PCS-Rahmenwerk (Predictability, Computability, STABILITY): nicht nur "was
# wurde entschieden", sondern "haette eine leicht andere, ebenso plausible
# Ausgangslage dieselbe Entscheidung ergeben?".
#
# Bewusst GENERISCH gehalten (keine feste Kopplung an Level 2 oder ein
# bestimmtes Skript) - der Aufrufer liefert eine beliebige
# "Entscheidungsfunktion" (seed -> ein einzelnes Ergebnis), dieses Modul
# wiederholt sie unter variierenden Seeds und fasst zusammen, wie oft
# dieselbe Entscheidung herauskommt. Dieselbe Grundidee laesst sich damit
# spaeter auf jede kategoriale Workflow-Entscheidung anwenden (Modellwahl,
# Ensemble-Mitgliedschaft, Feature-Auswahl-Cutoff, ...), nicht nur auf den
# ersten Anwendungsfall unten.

#' Wiederholt eine kategoriale Entscheidungsfunktion unter variierenden
#' Seeds und fasst zusammen, wie stabil die Entscheidung ist.
#'
#' @param decision_fn function(seed) -> ein einzelner Wert (character oder
#'   scalar), der die getroffene Entscheidung bei diesem Seed repraesentiert
#'   (z.B. "ranger"/"lightgbm"/"ensemble"). Darf beliebig teuer sein (z.B.
#'   ein komplettes Tuning) - dieses Modul kuemmert sich nur um Wiederholung
#'   + Zusammenfassung, nicht um die Kosten-Kontrolle selbst (siehe
#'   `n_repeats`, klein halten bei teuren `decision_fn`).
#' @param n_repeats Anzahl der Wiederholungen (Default 10 - bewusst klein,
#'   analog zu `seed_stability.R`s Default, da `decision_fn` typischerweise
#'   ein vollstaendiges Training/Tuning ist, kein billiger Check).
#' @param seed_start Basis-Seed fuer die Ziehung der `n_repeats`
#'   Wiederholungs-Seeds (deterministisch/reproduzierbar).
#' @param label Freitext-Label fuer die Ausgabe (z.B. "Level-2-Arm-Wahl,
#'   ilpd, Outer-Fold 1").
#' @param flag_threshold Schwelle fuer "AUFFAELLIG" (Default 0.7 - wenn die
#'   haeufigste Entscheidung bei WENIGER als 70% der Wiederholungen
#'   herauskommt, ist die Entscheidung fragiler als ein einfacher
#'   Mehrheits-Konsens; siehe Dokumentation unten fuer die Begruendung
#'   dieses Defaults, kein bewiesener, universeller Wert).
#' @return Liste: `choices` (Vektor der `n_repeats` Einzelentscheidungen),
#'   `table` (Haeufigkeitstabelle), `majority_choice`, `stability`
#'   (Anteil der Wiederholungen, die mit `majority_choice` uebereinstimmen,
#'   0-1), `flagged` (logisch, `stability < flag_threshold`).
decision_stability_report <- function(decision_fn, n_repeats = 10, seed_start = 1,
                                       label = "decision", flag_threshold = 0.7) {
  stopifnot("n_repeats muss >= 2 sein, sonst ist 'Stabilitaet' nicht sinnvoll definiert" = n_repeats >= 2)
  seeds <- seed_start + seq_len(n_repeats) - 1L
  choices <- vapply(seeds, function(s) as.character(decision_fn(s)), character(1))

  tab <- sort(table(choices), decreasing = TRUE)
  majority_choice <- names(tab)[1]
  stability <- unname(tab[1]) / n_repeats
  flagged <- stability < flag_threshold

  cat(sprintf("=== Decision-Stability-Report: %s ===\n", label))
  cat(sprintf("%d Wiederholungen (Seeds %d-%d)\n", n_repeats, seeds[1], seeds[n_repeats]))
  cat("Verteilung:", paste(names(tab), tab, sep = "=", collapse = ", "), "\n")
  cat(sprintf("Mehrheitsentscheidung: %s (%.0f%% der Wiederholungen)\n", majority_choice, stability * 100))
  if (flagged) {
    cat(sprintf(
      "=> AUFFAELLIG: die Mehrheitsentscheidung stimmt in weniger als %.0f%% der Wiederholungen ueberein -\n",
      flag_threshold * 100
    ))
    cat("   diese Entscheidung ist fragil/knapp, nicht robust. Reaktion: das gemeldete 'Ergebnis'\n")
    cat("   (z.B. 'Modell X gewinnt') nicht als stabilen Befund behandeln, sondern als eine von\n")
    cat("   mehreren plausiblen Ausgaengen - ggf. mehrere Kandidaten gleichwertig behandeln statt\n")
    cat("   einen einzelnen Sieger zu verkuenden.\n")
  } else {
    cat(sprintf("=> unauffaellig: die Entscheidung ist stabil (>=%.0f%% Uebereinstimmung).\n", flag_threshold * 100))
  }

  invisible(list(
    choices = choices, table = tab, majority_choice = majority_choice,
    stability = stability, flagged = flagged
  ))
}
