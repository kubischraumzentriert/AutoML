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
#' laufenden Wahrscheinlichkeits-Mittel die Zielmetrik auf `truth` am
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
#' @param probs_list Liste von Wahrscheinlichkeits-Objekten (ein Eintrag je
#'   Kandidat), alle mit identischer Form. Default (Multiclass-BAcc via
#'   `class_names`): Matrizen (Zeilen = Beobachtungen, Spalten = Klassen).
#'   Mit eigenem `metric_fn`: beliebig (z.B. ein Vektor P(positive_class) fuer
#'   binaeres AUC, siehe `predictingsmartphoneAddiction_s6e8/149_ensemble_
#'   selection.R` fuer ein reales Beispiel) - `+`/`/` muessen darauf definiert
#'   sein (Matrizen und numerische Vektoren erfuellen das beide).
#' @param truth Faktor der wahren Klassen, Laenge = nrow()/length() jedes
#'   Eintrags in `probs_list`.
#' @param class_names Zeichenvektor, Spaltenreihenfolge der Matrizen in
#'   `probs_list` - NUR noetig, wenn `metric_fn` NICHT gesetzt ist (Default-
#'   Metrik ist dann Balanced Accuracy via `.bacc_from_probs()`).
#' @param metric_fn optionale eigene Zielmetrik, `function(probs_combined,
#'   truth) -> Skalar, hoeher = besser` (z.B. `function(p, t)
#'   mlr3measures::auc(t, p, positive = "yes")` fuer binaeres AUC auf einem
#'   Wahrscheinlichkeits-Vektor). Wenn gesetzt, wird `class_names` ignoriert.
#' @param rounds Anzahl Greedy-Runden (= maximale Ensemblegroesse, mit
#'   Wiederholungen gezaehlt).
#' @return list(selected [Indizes in `probs_list`/`candidate_labels`, MIT
#'   Wiederholungen = Gewichte], best_bacc [beste waehrend der Suche
#'   beobachtete Zielmetrik - Name aus Kompatibilitaetsgruenden `best_bacc`
#'   auch bei einer anderen `metric_fn`]).
greedy_ensemble_selection <- function(probs_list, truth, class_names = NULL, rounds = 50, metric_fn = NULL) {
  stopifnot(
    "probs_list darf nicht leer sein" = length(probs_list) >= 1,
    "rounds muss mindestens 1 sein" = rounds >= 1
  )
  if (is.null(metric_fn)) {
    stopifnot("class_names ist erforderlich, wenn kein eigenes metric_fn uebergeben wird" = !is.null(class_names))
    metric_fn <- function(probs_combined, truth) .bacc_from_probs(probs_combined, truth, class_names)
  }
  n_candidates <- length(probs_list)
  selected <- integer(0)
  running_sum <- probs_list[[1]] * 0
  best_bacc_so_far <- -Inf
  best_selected_at_step <- integer(0)
  for (round in seq_len(rounds)) {
    gains <- vapply(seq_len(n_candidates), function(i) {
      trial_mean <- (running_sum + probs_list[[i]]) / (length(selected) + 1)
      metric_fn(trial_mean, truth)
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
