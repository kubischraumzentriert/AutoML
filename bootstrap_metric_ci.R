# =============================================================================
# bootstrap_metric_ci.R -- Unsicherheit um die FINAL berichtete Metrik
# selbst, nicht um die CV-Schaetzung waehrend der Modellauswahl.
# =============================================================================
# Luecke, per Nutzeranfrage "schlag ein neues Backlog-Thema vor" gefunden
# (2026-09-17): jedes bisherige Endergebnis dieses Templates wird als
# nackte Punktschaetzung berichtet - z.B. `joss/paper.md`: "Balanced
# Accuracy 0.9482 on the full, never-seen test set", ohne jede
# Unsicherheitsangabe. Ist das signifikant besser als 0.945? Als ein
# Konkurrenzmodell mit 0.944? Ohne Konfidenzintervall nicht beurteilbar -
# genau die Luecke, die ein JOSS-/AutoML-Conf-Reviewer typischerweise
# anmerkt. `generalization_gap.R` nutzt Bootstrap bereits, aber nur um
# die CV-Schaetzung selbst zu pruefen (Overfitting-auf-die-Testmethode-
# Diagnose), NICHT um eine Streuung um die finale Zahl auszuweisen -
# anderer Zweck, komplementaer, kein Duplikat.
#
# Methodik: nichtparametrisches Bootstrap UEBER DIE ZEILEN eines bereits
# vorhandenen, fixen Vorhersage-Datensatzes (Holdout/finaler Test) - kein
# Neutraining je Resample (waere bei N=1000+ Resamples unbezahlbar).
# Perzentil-Intervall (Efron 1979) - einfachste, robusteste Variante,
# ausreichend fuer "wie stabil ist diese eine Zahl" ohne die Zusatz-
# annahmen von BCa.

#' Bootstrap-Konfidenzintervall fuer eine beliebige Metrik auf einem
#' fixen Vorhersage-Datensatz.
#'
#' @param truth Vektor/Faktor der wahren Werte (Laenge n).
#' @param pred Vorhersagen gleicher "Zeilenordnung" wie `truth` - entweder
#'   ein Vektor (Response, z.B. fuer BAcc/RMSE) ODER eine Matrix mit einer
#'   Zeile je Beobachtung (Wahrscheinlichkeiten, z.B. fuer AUC/LogLoss).
#' @param metric_fn Funktion(truth, pred) -> ein einzelner numerischer
#'   Metrikwert (z.B. `mlr3measures::bacc`, oder ein eigenes `function(t, p)
#'   mlr3measures::rmse(t, p)`). Muss dieselbe truth/pred-Teilmenge wie
#'   uebergeben akzeptieren (kein interner Modellzugriff).
#' @param B Anzahl Bootstrap-Resamples (Default 2000).
#' @param conf_level Ziel-Konfidenzniveau (Default 0.90 - Template-
#'   Konvention, siehe conformal_prediction.R/quantile_regression.R).
#' @param seed Optional, fuer Reproduzierbarkeit.
#' @return Liste: `point` (Metrik auf den vollen Originaldaten), `ci_lower`,
#'   `ci_upper` (Perzentil-Intervall), `se` (Bootstrap-Standardfehler =
#'   sd() der Resample-Werte), `B`, `conf_level`, `boot_scores` (roher
#'   Vektor, fuer eigene Weiterverarbeitung/Histogramme).
bootstrap_metric_ci <- function(truth, pred, metric_fn, B = 2000,
                                 conf_level = 0.90, seed = NULL) {
  stopifnot(NROW(pred) == length(truth), B >= 100, conf_level > 0, conf_level < 1)
  if (!is.null(seed)) set.seed(seed)
  n <- length(truth)
  is_mat <- is.matrix(pred) || is.data.frame(pred)

  point <- metric_fn(truth, pred)
  boot_scores <- vapply(seq_len(B), function(b) {
    idx <- sample.int(n, n, replace = TRUE)
    pred_b <- if (is_mat) pred[idx, , drop = FALSE] else pred[idx]
    metric_fn(truth[idx], pred_b)
  }, numeric(1))

  alpha <- 1 - conf_level
  ci <- stats::quantile(boot_scores, probs = c(alpha / 2, 1 - alpha / 2), names = FALSE, na.rm = TRUE)

  list(point = point, ci_lower = ci[1], ci_upper = ci[2],
       se = stats::sd(boot_scores, na.rm = TRUE),
       B = B, conf_level = conf_level, boot_scores = boot_scores)
}

#' Gepaarter Bootstrap-Vergleich zweier Modelle auf DEMSELBEN Holdout -
#' beantwortet "ist Modell A wirklich besser als B" statt zwei einzelne
#' CIs nebeneinanderzuhalten (die sich ueberlappen koennen, obwohl der
#' PAARWEISE Unterschied trotzdem verlaesslich positiv ist, weil beide
#' Modelle auf denselben - leichten/schweren - Zeilen mitschwanken).
#'
#' @param truth,pred_a,pred_b Wie bei `bootstrap_metric_ci()`, `pred_a`/
#'   `pred_b` muessen dieselbe Zeilenordnung wie `truth` haben (dieselben
#'   Beobachtungen, zwei Modelle).
#' @param metric_fn,B,conf_level,seed Wie bei `bootstrap_metric_ci()`.
#' @return Liste: `delta` (Metrik(A) - Metrik(B) auf den Originaldaten),
#'   `ci_lower`, `ci_upper` (Perzentil-CI der gepaarten Differenz),
#'   `p_value` (bootstrap-basiert, zweiseitig: 2*min(Anteil delta<=0,
#'   Anteil delta>=0), gedeckelt bei 1), `significant` (CI schliesst 0
#'   aus), `boot_deltas`.
bootstrap_paired_comparison <- function(truth, pred_a, pred_b, metric_fn,
                                         B = 2000, conf_level = 0.90, seed = NULL) {
  stopifnot(NROW(pred_a) == length(truth), NROW(pred_b) == length(truth))
  if (!is.null(seed)) set.seed(seed)
  n <- length(truth)
  is_mat_a <- is.matrix(pred_a) || is.data.frame(pred_a)
  is_mat_b <- is.matrix(pred_b) || is.data.frame(pred_b)

  delta_point <- metric_fn(truth, pred_a) - metric_fn(truth, pred_b)
  boot_deltas <- vapply(seq_len(B), function(b) {
    idx <- sample.int(n, n, replace = TRUE)  # DIESELBEN Zeilen fuer A und B - gepaart.
    a_b <- if (is_mat_a) pred_a[idx, , drop = FALSE] else pred_a[idx]
    b_b <- if (is_mat_b) pred_b[idx, , drop = FALSE] else pred_b[idx]
    metric_fn(truth[idx], a_b) - metric_fn(truth[idx], b_b)
  }, numeric(1))

  alpha <- 1 - conf_level
  ci <- stats::quantile(boot_deltas, probs = c(alpha / 2, 1 - alpha / 2), names = FALSE, na.rm = TRUE)
  p_value <- min(1, 2 * min(mean(boot_deltas <= 0), mean(boot_deltas >= 0)))

  list(delta = delta_point, ci_lower = ci[1], ci_upper = ci[2],
       p_value = p_value, significant = (ci[1] > 0) || (ci[2] < 0),
       B = B, conf_level = conf_level, boot_deltas = boot_deltas)
}

#' Formatiert ein `bootstrap_metric_ci()`-Ergebnis als lesbare Zeile,
#' z.B. fuer Log-Ausgaben/Reports: "0.9482 [90%-CI: 0.9401, 0.9558]".
#' @param result Rueckgabe von `bootstrap_metric_ci()`.
#' @param digits Nachkommastellen (Default 4).
format_metric_ci <- function(result, digits = 4) {
  sprintf("%.*f [%.0f%%-CI: %.*f, %.*f]",
          digits, result$point, result$conf_level * 100,
          digits, result$ci_lower, digits, result$ci_upper)
}
