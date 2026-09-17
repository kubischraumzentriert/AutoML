# =============================================================================
# weather_enrichment_trust_gate.R -- Trust-Gate fuer Baseline-vs.-DWD-Wetter-
# Vergleiche: verlangt eine Seed-Stabilitaetspruefung, bevor ein Vergleich
# als "Wetter hilft"/"Wetter schadet" berichtet werden darf.
# =============================================================================
# Anlass (siehe docs/research/DWD_WEATHER_INTEGRATION.md, Abschnitt
# "Ursachenanalyse: Seed-Stabilitaet statt Domaenenerklaerung"): die erste
# Runde der DWD-Piloten (5 Faelle) verglich Baseline vs. Wetter mit je EINEM
# Ranger-Modell-Seed. Ergebnis auf den ersten Blick: 2 von 5 Faellen positiv,
# 3 negativ. Eine Pruefung ueber 25 Seeds (fixer Datensplit, nur der
# Lerner-Seed variiert - analog zu seed_stability.R/092_seed_stability.R)
# zeigte: 3 der "negativen" Faelle waren bei 40-52% positiver Seeds schlicht
# Modellrauschen bei kleinen Testmengen (47-71 Zeilen), keine echte
# Verschlechterung. Nur 2 Faelle blieben mit >=96% positiver Seeds robust.
# Diese Datei macht den korrigierenden Schritt zur Pflicht statt einer
# nachtraeglichen manuellen Korrektur: jeder Baseline-vs.-Wetter-Vergleich in
# diesem Repository muss durch weather_enrichment_seed_stability_gate()
# laufen, und ein gerichteter Befund ("hilft"/"schadet") darf nur berichtet
# werden, wenn assert_weather_enrichment_finding() nicht abbricht.
#
# min_share_for_verdict = 0.9 ist NICHT aus einer Formel abgeleitet, sondern
# empirisch an genau der Faellemenge kalibriert, die den Bedarf fuer dieses
# Gate ausgeloest hat: robuste Faelle lagen bei 96-100% gleichgerichteter
# Seeds, Rausch-Faelle bei 40-52% - 0.9 liegt sicher zwischen beiden
# Clustern. Weitere Faelle koennten diese Schwelle spaeter verschieben; bis
# dahin ist sie der beste verfuegbare Wert, kein Dogma.

suppressPackageStartupMessages({
  library(data.table)
})

#' Prueft, ob ein Baseline-vs.-Wetter-Metrikdelta ueber den Modell-Seed
#' hinweg stabil gerichtet ist, oder ob es sich um Modellrauschen handelt.
#'
#' Datensplit UND Trainingsdaten bleiben je Variante fix - nur der
#' Lerner-Seed variiert (derselbe Rauschkanal wie seed_stability()).
#'
#' @param baseline_data data.frame/data.table mit Spalten `date`, `target`
#'   und Baseline-Features (keine Wetterspalten).
#' @param weather_data data.frame/data.table mit denselben Zeilen/Spalten
#'   plus Wetterfeatures.
#' @param split_date Datum (character/Date): Zeilen davor = Training, ab da
#'   = Test. Identisch fuer beide Varianten.
#' @param learner_constructor function(seed) -> mlr3-Learner (frisch, noch
#'   nicht trainiert). Muss `predict_type` etc. bereits selbst setzen.
#' @param measure mlr3-Measure (z.B. `msr("classif.bacc")`).
#' @param drop_cols Spalten, die weder Feature noch Ziel sind (Default: id/date).
#' @param target_col Name der Zielspalte (Default "target").
#' @param n_seeds Anzahl unabhaengiger Lerner-Seeds (Default 25 - siehe
#'   Anlass oben).
#' @param sampling_seed Seed, mit dem die n_seeds Lerner-Seeds selbst
#'   gezogen werden (Reproduzierbarkeit der Pruefung, nicht des Lernens).
#' @param min_share_for_verdict Anteil gleichgerichteter Seeds, ab dem ein
#'   Effekt als robust gilt (Default 0.9, siehe Kalibrierung oben).
#' @return Liste: `deltas` (Vektor, Laenge n_seeds), `share_positive`,
#'   `share_negative`, `decision` (einer von "robust_improvement",
#'   "robust_regression", "inconclusive"), `n_seeds`, `min_share_for_verdict`.
weather_enrichment_seed_stability_gate <- function(baseline_data, weather_data, split_date,
                                                     learner_constructor, measure,
                                                     drop_cols = c("id", "date"),
                                                     target_col = "target",
                                                     n_seeds = 25, sampling_seed = 42,
                                                     min_share_for_verdict = 0.9) {
  if (!requireNamespace("mlr3", quietly = TRUE)) {
    stop("weather_enrichment_seed_stability_gate() benoetigt das Paket mlr3.", call. = FALSE)
  }
  if (nrow(baseline_data) != nrow(weather_data)) {
    stop("baseline_data und weather_data muessen dieselbe Zeilenzahl haben.", call. = FALSE)
  }
  if (!is.numeric(min_share_for_verdict) || min_share_for_verdict <= 0.5 ||
      min_share_for_verdict > 1) {
    stop("min_share_for_verdict muss in (0.5, 1] liegen.", call. = FALSE)
  }

  fit_score <- function(data, seed) {
    dt <- data.table::as.data.table(data)
    dt[, date := as.Date(date)]
    data.table::setorder(dt, date)
    train <- dt[date < as.Date(split_date)]
    test <- dt[date >= as.Date(split_date)]
    if (nrow(train) == 0 || nrow(test) == 0) {
      stop("split_date erzeugt einen leeren Train- oder Testanteil.", call. = FALSE)
    }
    feature_cols <- setdiff(names(dt), drop_cols)
    train_data <- train[, .SD, .SDcols = feature_cols]
    test_data <- test[, .SD, .SDcols = feature_cols]

    set.seed(seed)
    task <- mlr3::as_task_classif(train_data, target = target_col, id = paste0("gate_s", seed))
    learner <- learner_constructor(seed)
    learner$train(task)
    test_task <- mlr3::as_task_classif(test_data, target = target_col,
                                        id = paste0("gate_s", seed, "_test"))
    pred <- learner$predict(test_task)
    pred$score(measure)[[measure$id]]
  }

  set.seed(sampling_seed)
  seeds <- sample.int(1e6, n_seeds)

  deltas <- vapply(seeds, function(s) {
    fit_score(weather_data, s) - fit_score(baseline_data, s)
  }, numeric(1))

  share_positive <- mean(deltas > 0)
  share_negative <- mean(deltas < 0)
  decision <- if (share_positive >= min_share_for_verdict) {
    "robust_improvement"
  } else if (share_negative >= min_share_for_verdict) {
    "robust_regression"
  } else {
    "inconclusive"
  }

  list(
    deltas = deltas, seeds = seeds,
    delta_mean = mean(deltas), delta_sd = stats::sd(deltas),
    share_positive = share_positive, share_negative = share_negative,
    decision = decision, n_seeds = n_seeds,
    min_share_for_verdict = min_share_for_verdict
  )
}

#' Verlangt, dass ein Baseline-vs.-Wetter-Befund durch das Trust-Gate gedeckt
#' ist, BEVOR er als gerichteter Befund ("Wetter hilft"/"Wetter schadet")
#' berichtet wird. Bricht mit `stop()` ab, wenn die behauptete Richtung nicht
#' zur Gate-Entscheidung passt - macht die Pruefung nicht optional.
#'
#' @param gate_result Rueckgabe von weather_enrichment_seed_stability_gate().
#' @param claimed_direction "improvement", "regression" oder "any" (nur
#'   pruefen, dass ueberhaupt ein robuster Befund vorliegt, egal welche
#'   Richtung).
#' @return TRUE (unsichtbar), wenn der Befund gedeckt ist.
assert_weather_enrichment_finding <- function(gate_result,
                                               claimed_direction = c("improvement", "regression", "any")) {
  claimed_direction <- match.arg(claimed_direction)
  decision <- gate_result$decision

  if (decision == "inconclusive") {
    stop(sprintf(
      paste0(
        "Trust-Gate nicht bestanden: %d/%d Seeds positiv, %d/%d negativ ",
        "(Schwelle %.0f%%) - kein robuster Befund. Ein gerichteter Befund ",
        "('Wetter hilft'/'Wetter schadet') darf NICHT berichtet werden. ",
        "Siehe docs/research/DWD_WEATHER_INTEGRATION.md, ",
        "'Ursachenanalyse: Seed-Stabilitaet statt Domaenenerklaerung'."
      ),
      round(gate_result$share_positive * gate_result$n_seeds), gate_result$n_seeds,
      round(gate_result$share_negative * gate_result$n_seeds), gate_result$n_seeds,
      gate_result$min_share_for_verdict * 100
    ), call. = FALSE)
  }

  if (claimed_direction == "improvement" && decision != "robust_improvement") {
    stop("Trust-Gate: behauptete Richtung 'improvement' passt nicht zur robusten Gegenrichtung ('robust_regression').", call. = FALSE)
  }
  if (claimed_direction == "regression" && decision != "robust_regression") {
    stop("Trust-Gate: behauptete Richtung 'regression' passt nicht zur robusten Gegenrichtung ('robust_improvement').", call. = FALSE)
  }

  invisible(TRUE)
}
