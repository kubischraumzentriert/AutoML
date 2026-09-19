# =============================================================================
# probability_calibration.R -- sind die von einem Klassifikator gelieferten
# Wahrscheinlichkeiten (`predict_type = "prob"`) selbst kalibriert?
# =============================================================================
# BACKLOG.md-Vorschlag (Bestandsaufnahme 2026-09-14). `predict_type="prob"`
# wird im gesamten Template durchgaengig genutzt (Schwellenwert-Tuning,
# Klassen-Multiplier, Ensemble-Blends, Conformal-/Quantil-Intervalle),
# aber nie geprueft, ob "P(Klasse)=0.8" tatsaechlich bedeutet, dass unter
# allen so vorhergesagten Faellen auch ~80% wirklich diese Klasse sind.
# Ein Modell kann eine PERFEKTE Rangfolge (hohe AUC) und trotzdem schlecht
# kalibrierte Wahrscheinlichkeiten haben (klassisches Boosting-Symptom:
# Vorhersagen werden zu extrem, nahe 0/1 gedrueckt) - AUC/BAcc sehen das
# NICHT, nur ein Kalibrierungs-Check.
#
# Nur binaere Klassifikation (die Positive-Class-Konvention dieses
# Templates) - Multiclass-Kalibrierung braucht ein anderes Konzept
# (Top-Label- oder klassenweise Kalibrierung) und ist bewusst NICHT Teil
# dieses ersten Moduls.

#' Expected Calibration Error (ECE, Naeini et al. 2015) - bins die
#' vorhergesagten Wahrscheinlichkeiten, vergleicht je Bin die MITTLERE
#' vorhergesagte Wahrscheinlichkeit mit der TATSAECHLICHEN Trefferquote.
#'
#' @param prob Numerischer Vektor, P(positive_class) je Beobachtung.
#' @param truth Faktor/Charakter-Vektor der wahren Klassen.
#' @param positive_class Name der positiven Klasse.
#' @param n_bins Anzahl gleich breiter Bins ueber [0, 1] (Default 10).
#' @return Liste mit `ece` (gewichteter mittlerer |Gap|, 0 = perfekt
#'   kalibriert) und `bins` (`data.table` je Bin: `n`, `mean_predicted`,
#'   `empirical_rate`, `gap`).
expected_calibration_error <- function(prob, truth, positive_class, n_bins = 10) {
  stopifnot(
    "prob und truth muessen gleich lang sein" = length(prob) == length(truth),
    "prob muss Wahrscheinlichkeiten im Bereich [0, 1] enthalten" = all(prob >= 0 & prob <= 1)
  )
  is_positive <- as.integer(as.character(truth) == positive_class)
  bin_edges <- seq(0, 1, length.out = n_bins + 1)
  # rightmost.closed, damit prob==1 noch in den letzten Bin faellt.
  bin_id <- cut(prob, breaks = bin_edges, include.lowest = TRUE, labels = FALSE)

  bins <- data.table::data.table(prob = prob, is_positive = is_positive, bin_id = bin_id)[
    , .(n = .N, mean_predicted = mean(prob), empirical_rate = mean(is_positive)), by = bin_id
  ]
  bins[, gap := abs(mean_predicted - empirical_rate)]
  data.table::setorder(bins, bin_id)

  ece <- sum(bins$n * bins$gap) / sum(bins$n)
  list(ece = ece, bins = bins)
}

#' Brier-Score (mittlerer quadratischer Fehler der Wahrscheinlichkeits-
#' vorhersage) - ergaenzend zum ECE, da ECE bei wenigen Bins/kleinem n
#' instabil werden kann.
brier_score <- function(prob, truth, positive_class) {
  is_positive <- as.integer(as.character(truth) == positive_class)
  mean((prob - is_positive)^2)
}

#' Platt-Scaling: logistische Regression der wahren Klasse auf die rohe
#' Wahrscheinlichkeit (vereinfachte Variante - Platt (1999) nutzt intern
#' den Logit-Score, hier die Modell-Wahrscheinlichkeit direkt als
#' Praediktor, was fuer die meisten Baum-/Boosting-Modelle aequivalent
#' funktioniert). NUR auf einer Kalibrierungsmenge fitten, die das
#' Basismodell nie zum Training gesehen hat.
#'
#' @return Liste mit `model` (das gefittete `glm`-Objekt) und einer
#'   Funktion `predict_fn(new_prob)` fuer neue Rohwerte.
fit_platt_scaling <- function(calib_prob, calib_truth, positive_class) {
  is_positive <- as.integer(as.character(calib_truth) == positive_class)
  fit <- suppressWarnings(stats::glm(is_positive ~ calib_prob, family = stats::binomial()))
  predict_fn <- function(new_prob) {
    as.numeric(stats::predict(fit, newdata = data.frame(calib_prob = new_prob), type = "response"))
  }
  list(model = fit, predict_fn = predict_fn)
}

#' Isotonic-Regression-Kalibrierung (monotone, nichtparametrische
#' Abbildung roh -> kalibriert). NUR auf einer Kalibrierungsmenge fitten.
#'
#' @return Liste mit `fit` (`stats::isoreg`-Objekt) und `predict_fn`
#'   (lineare Interpolation zwischen den isotonischen Stufen, Extrapolation
#'   an den Raendern konstant).
fit_isotonic_calibration <- function(calib_prob, calib_truth, positive_class) {
  is_positive <- as.integer(as.character(calib_truth) == positive_class)
  ord <- order(calib_prob)
  iso <- stats::isoreg(calib_prob[ord], is_positive[ord])
  x_sorted <- calib_prob[ord]
  y_fitted <- iso$yf
  predict_fn <- function(new_prob) {
    stats::approx(x_sorted, y_fitted, xout = new_prob, rule = 2, ties = mean)$y
  }
  list(fit = iso, predict_fn = predict_fn)
}

#' Vollstaendiger Kalibrierungs-Report: teilt eine Eval-Menge in
#' Kalibrierung/Bestaetigung, fittet Platt + Isotonic auf der
#' Kalibrierungshaelfte, vergleicht ECE/Brier VOR und NACH Kalibrierung
#' auf der (von der Kalibrierung unberuehrten) Bestaetigungshaelfte.
#'
#' @param eval_prob,eval_truth Wahrscheinlichkeiten/Wahrheit auf einer
#'   Menge, die das Basismodell nie zum TRAINING gesehen hat (z.B. ein
#'   Held-out-Test).
#' @param calib_ratio Anteil fuer die Kalibrierung (Default 0.5).
#' @param seed Fuer den Kalibrierung/Bestaetigung-Split.
#' @return `data.table`, eine Zeile je Variante (`raw`/`platt`/`isotonic`).
calibration_report <- function(eval_prob, eval_truth, positive_class,
                                n_bins = 10, calib_ratio = 0.5, seed = 1) {
  n <- length(eval_prob)
  set.seed(seed)
  calib_idx <- sample(n, round(calib_ratio * n))
  conf_idx <- setdiff(seq_len(n), calib_idx)

  calib_prob <- eval_prob[calib_idx]; calib_truth <- eval_truth[calib_idx]
  conf_prob <- eval_prob[conf_idx]; conf_truth <- eval_truth[conf_idx]

  platt <- fit_platt_scaling(calib_prob, calib_truth, positive_class)
  isotonic <- fit_isotonic_calibration(calib_prob, calib_truth, positive_class)

  conf_prob_platt <- pmin(pmax(platt$predict_fn(conf_prob), 0), 1)
  conf_prob_iso <- pmin(pmax(isotonic$predict_fn(conf_prob), 0), 1)

  variants <- list(raw = conf_prob, platt = conf_prob_platt, isotonic = conf_prob_iso)
  rows <- lapply(names(variants), function(v) {
    ece_res <- expected_calibration_error(variants[[v]], conf_truth, positive_class, n_bins)
    data.table::data.table(
      variant = v, n_confirmation = length(conf_idx),
      ece = ece_res$ece, brier = brier_score(variants[[v]], conf_truth, positive_class)
    )
  })
  data.table::rbindlist(rows)
}
