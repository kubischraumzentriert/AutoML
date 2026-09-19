# =============================================================================
# subgroup_fairness_disparity.R -- performt ein Modell ueber sensible
# Untergruppen hinweg systematisch unterschiedlich gut?
# =============================================================================
# BACKLOG.md-Vorschlag (Bestandsaufnahme 2026-09-14). Unterscheidet sich von
# `segment_metrics.R` (dortiger Fokus: Diagnose, WELCHES Segment schlecht
# performt, z.B. fuer Kandidat 7/9-Diagnosen) - hier geht es um STANDARD-
# Fairness-Metriken mit gaengigen Namen/Schwellenwerten aus der Fairness-
# ML-Literatur (Hardt et al. 2016, "Equality of Opportunity in Supervised
# Learning"; die "4/5-Regel" aus dem US-Fair-Employment-Recht als
# Richtwert-Konvention):
#
#   Demografische Paritaet   - unterscheidet sich die Rate positiver
#                               VORHERSAGEN zwischen Gruppen? (unabhaengig
#                               von der Wahrheit - "wird Gruppe A haeufiger
#                               positiv vorhergesagt als Gruppe B?")
#   Equal Opportunity (TPR)  - unterscheidet sich die Trefferquote UNTER
#                               DEN TATSAECHLICH POSITIVEN zwischen Gruppen?
#                               ("wird ein tatsaechlich positiver Fall in
#                               Gruppe A genauso oft erkannt wie in B?")
#   FPR-Paritaet              - unterscheidet sich die Falsch-Positiv-Rate?
#   Predictive Parity (PPV)  - unterscheidet sich die Praezision (Anteil
#                               tatsaechlich positiver unter den positiv
#                               Vorhergesagten)?
#
# NUR binaere Klassifikation (wie `probability_calibration.R`) - dieselbe
# Positive-Class-Konvention dieses Templates.
#
# WICHTIGER VORBEHALT: dieses Modul prueft NUR, OB eine Disparitaet
# vorliegt, nicht OB sie "ungerecht"/"diskriminierend" im rechtlichen
# oder ethischen Sinn ist - das ist eine Domaenen-/Kontext-Frage, die
# dieses Skript nicht beantworten kann (siehe "Nicht automatisieren"-
# Disziplin des Templates). Es liefert Zahlen, keine Urteile.

#' Standard-Fairness-Metriken je Subgruppe.
#'
#' @param response Vorhergesagte Klasse (Faktor/Charakter).
#' @param truth Wahre Klasse (Faktor/Charakter).
#' @param group Sensible Subgruppen-Variable (Faktor/Charakter, >=2
#'   Auspraegungen).
#' @param positive_class Name der positiven Klasse.
#' @return `data.table`, eine Zeile je Subgruppe: `group`, `n`,
#'   `positive_rate` (demografische Paritaet), `tpr` (Equal Opportunity,
#'   `NA` wenn keine echten Positiven in der Gruppe), `fpr` (`NA` wenn
#'   keine echten Negativen), `ppv` (Predictive Parity, `NA` wenn keine
#'   positiven Vorhersagen).
subgroup_fairness_metrics <- function(response, truth, group, positive_class) {
  stopifnot(
    "response und truth muessen gleich lang sein" = length(response) == length(truth),
    "truth und group muessen gleich lang sein" = length(truth) == length(group)
  )
  dt <- data.table::data.table(
    response = as.character(response), truth = as.character(truth), group = as.character(group)
  )
  dt[, `:=`(pred_pos = response == positive_class, true_pos = truth == positive_class)]

  dt[, .(
    n = .N,
    positive_rate = mean(pred_pos),
    tpr = if (sum(true_pos) > 0) sum(pred_pos & true_pos) / sum(true_pos) else NA_real_,
    fpr = if (sum(!true_pos) > 0) sum(pred_pos & !true_pos) / sum(!true_pos) else NA_real_,
    ppv = if (sum(pred_pos) > 0) sum(pred_pos & true_pos) / sum(pred_pos) else NA_real_
  ), by = group]
}

#' Paarweise Disparitaet zwischen ALLEN Subgruppen-Paaren, je Metrik.
#'
#' @param metrics_dt Rueckgabe von `subgroup_fairness_metrics()`.
#' @param metrics Zu vergleichende Spalten (Default alle 4 Fairness-Metriken).
#' @return `data.table`: `group_a`, `group_b`, `metric`, `value_a`,
#'   `value_b`, `abs_diff`, `ratio` (kleinerer/groesserer Wert, <=1 -
#'   die "4/5-Regel" prueft `ratio < 0.8`). Paare mit `NA` in einer der
#'   beiden Gruppen werden uebersprungen (zu wenig Daten fuer eine
#'   verlaessliche Aussage, kein Fehler).
pairwise_fairness_disparity <- function(metrics_dt, metrics = c("positive_rate", "tpr", "fpr", "ppv")) {
  groups <- metrics_dt$group
  stopifnot("mindestens 2 Subgruppen noetig fuer einen paarweisen Vergleich" = length(groups) >= 2)
  combs <- utils::combn(groups, 2)
  rows <- lapply(metrics, function(m) {
    lapply(seq_len(ncol(combs)), function(j) {
      ga <- combs[1, j]; gb <- combs[2, j]
      va <- metrics_dt[group == ga][[m]]; vb <- metrics_dt[group == gb][[m]]
      if (is.na(va) || is.na(vb)) return(NULL)
      data.table::data.table(
        group_a = ga, group_b = gb, metric = m, value_a = va, value_b = vb,
        abs_diff = abs(va - vb),
        ratio = if (max(va, vb) == 0) NA_real_ else min(va, vb) / max(va, vb)
      )
    })
  })
  data.table::rbindlist(unlist(rows, recursive = FALSE))
}

#' Voller Report: Subgruppen-Metriken + paarweise Disparitaet + Flag,
#' ob irgendein Paar/Metrik die Schwelle ueberschreitet.
#'
#' @param abs_diff_threshold Absolute Differenz, ab der eine Disparitaet
#'   als auffaellig gilt (Default 0.1 = 10 Prozentpunkte).
#' @param ratio_threshold "4/5-Regel"-Schwelle (Default 0.8) - `ratio`
#'   UNTER diesem Wert gilt als auffaellig.
#' @return Liste mit `subgroup_metrics`, `pairwise`, `n_flagged` (Anzahl
#'   Paar-Metrik-Kombinationen, die MINDESTENS eine der beiden Schwellen
#'   verletzen).
fairness_disparity_report <- function(response, truth, group, positive_class,
                                       abs_diff_threshold = 0.1, ratio_threshold = 0.8) {
  subgroup_metrics <- subgroup_fairness_metrics(response, truth, group, positive_class)
  pairwise <- pairwise_fairness_disparity(subgroup_metrics)
  pairwise[, flagged := abs_diff > abs_diff_threshold | (!is.na(ratio) & ratio < ratio_threshold)]
  list(subgroup_metrics = subgroup_metrics, pairwise = pairwise, n_flagged = sum(pairwise$flagged))
}
