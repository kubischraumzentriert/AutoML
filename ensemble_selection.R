# =====================================================================
# ensemble_selection.R -- Caruana-Greedy-Ensemble-Selection als Funktion
# =====================================================================
# Extrahiert aus 149_ensemble_selection.R (2026-08-19), Anlass: externes
# Review bemaengelte zutreffend, dass Ensemble Selection nur als Skript-
# logik existiert, keine eigenstaendige, testbare Funktion. Verhalten
# 1:1 aus dem urspruenglichen Inline-Code uebernommen (siehe
# tests/testthat/test-ensemble_selection.R fuer die Korrektheitstests:
# synthetischer Pool mit starkem Kandidaten A, komplementaerem, aber
# schwaecherem B und reinem Rauschen C - erwartet A/B gewaehlt, C nicht).
# Caruana et al. 2004, wie in Auto-sklearn. Bestaetigt an mehreren
# unabhaengigen OpenML-Datensaetzen (siehe TARGETS.md/
# REFERENZ_ENSEMBLE_SELECTION.md).

#' Balanced Accuracy aus einer Wahrscheinlichkeits-Matrix (argmax-Entscheidung).
#' @param prob_mat Matrix (Zeilen = Beobachtungen, Spalten = Klassen).
#' @param truth Faktor der wahren Klassen, Laenge = nrow(prob_mat).
#' @param class_names Zeichenvektor, Spaltenreihenfolge von `prob_mat`.
.bacc_from_probs <- function(prob_mat, truth, class_names) {
  response <- factor(class_names[max.col(prob_mat, ties.method = "first")], levels = levels(truth))
  mlr3measures::bacc(truth, response)
}

#' Caruana Greedy Ensemble Selection (Caruana et al. 2004, wie in Auto-sklearn).
#'
#' Waehlt iterativ MIT Zuruecklegen den Kandidaten, dessen Hinzunahme zum
#' laufenden Wahrscheinlichkeits-Mittel die Balanced Accuracy auf `truth` am
#' staerksten erhoeht (ein Kandidat kann mehrfach gewaehlt werden - das
#' entspricht einem hoeheren Gewicht im finalen Blend). Die Rueckgabe ist der
#' BESTE waehrend der gesamten Suche beobachtete Ensemble-Zustand, nicht
#' zwingend der Zustand nach der letzten Runde (die Suche kann sich nach dem
#' Optimum wieder verschlechtern, wenn kein Kandidat mehr hilft).
#'
#' WICHTIG: `probs`/`truth` sollten eine von der spaeteren Bestaetigungsmenge
#' getrennte Selektionsmenge sein (sonst ueberpasst sich die Selektion an sich
#' selbst) - das ist Aufgabe des Aufrufers, nicht dieser Funktion.
#'
#' @param probs_list Liste von Wahrscheinlichkeits-Matrizen (ein Eintrag je
#'   Kandidat), alle mit identischer Dimension (Zeilen = Beobachtungen,
#'   Spalten = `class_names`).
#' @param truth Faktor der wahren Klassen, Laenge = nrow(jede Matrix in
#'   `probs_list`).
#' @param class_names Zeichenvektor, Spaltenreihenfolge der Matrizen in
#'   `probs_list`.
#' @param rounds Anzahl Greedy-Runden (= maximale Ensemblegroesse, mit
#'   Wiederholungen gezaehlt).
#' @return list(selected [Indizes in `probs_list`/`candidate_labels`, MIT
#'   Wiederholungen = Gewichte], best_bacc [beste waehrend der Suche
#'   beobachtete Balanced Accuracy]).
greedy_ensemble_selection <- function(probs_list, truth, class_names, rounds = 50) {
  stopifnot(length(probs_list) >= 1, rounds >= 1)
  n_candidates <- length(probs_list)
  n_rows <- length(truth)
  selected <- integer(0)
  running_sum <- matrix(0, nrow = n_rows, ncol = length(class_names))
  best_bacc_so_far <- -Inf
  best_selected_at_step <- integer(0)
  for (round in seq_len(rounds)) {
    gains <- vapply(seq_len(n_candidates), function(i) {
      trial_mean <- (running_sum + probs_list[[i]]) / (length(selected) + 1)
      .bacc_from_probs(trial_mean, truth, class_names)
    }, numeric(1))
    best_gain_idx <- which.max(gains)
    selected <- c(selected, best_gain_idx)
    running_sum <- running_sum + probs_list[[best_gain_idx]]
    if (gains[best_gain_idx] > best_bacc_so_far) {
      best_bacc_so_far <- gains[best_gain_idx]
      best_selected_at_step <- selected
    }
  }
  list(selected = best_selected_at_step, best_bacc = best_bacc_so_far)
}
