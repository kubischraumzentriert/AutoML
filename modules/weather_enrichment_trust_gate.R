# =============================================================================
# weather_enrichment_trust_gate.R -- Trust-Gate fuer Baseline-vs.-DWD-Wetter-
# Vergleiche: verlangt eine zweidimensionale Stabilitaetspruefung (Modell-
# Seed UND Split-Ratio), bevor ein Vergleich als "Wetter hilft"/"Wetter
# schadet" berichtet werden darf.
# =============================================================================
# Anlass v1 (siehe docs/research/DWD_WEATHER_INTEGRATION.md, Abschnitt
# "Ursachenanalyse: Seed-Stabilitaet statt Domaenenerklaerung"): die erste
# Runde der DWD-Piloten (5 Faelle, in einem separaten lokalen ML_Learning-
# Repo, nicht Teil dieses Template-Repos) verglich Baseline vs. Wetter mit
# je EINEM Ranger-Modell-Seed bei FIXEM Datensplit. Ergebnis auf den ersten
# Blick: 2 von 5 Faellen positiv, 3 negativ. Eine Pruefung ueber 25 Seeds
# bei fixem Split zeigte: 3 der "negativen" Faelle waren bei 40-52%
# positiver Seeds schlicht Modellrauschen, keine echte Verschlechterung.
# Nur 2 Faelle blieben mit >=96% positiver Seeds robust (v1-Gate,
# split_date-basiert).
#
# Anlass v2 (2026-09-18): der v1-Befund war SELBST nicht robust gegen die
# Wahl des einen fixen Split-Zeitpunkts. Eine Pruefung ueber 5 Split-Ratios
# (15/20/25/30/35% Testanteil, chronologisch) x 10 Seeds = 50 Kombinationen
# je Fall aenderte das Bild erneut: mit dem Standard-Sampling-Seed dieses
# Gates bleibt nur noch EIN Fall (Camping Brandenburg/Potsdam, 96% positiv)
# robust - die anderen vier (u.a. der vorher "robust positive" Verkehrsunfall-
# Fall, jetzt 86%) fallen auf "inconclusive", weil sie an einzelnen
# Split-Punkten kippen. Kein einziger Fall wurde in irgendeiner Pruefrunde
# robust NEGATIV. Split-Wahl ist damit ein eigener, vergleichbar wichtiger
# Rauschkanal wie der Modell-Seed selbst - dieses Gate prueft deshalb jetzt
# BEIDE gemeinsam statt nur den Seed bei fixem Split.
#
# min_share_for_verdict = 0.9 ist NICHT aus einer Formel abgeleitet, sondern
# empirisch an der Faellemenge kalibriert, die den Bedarf fuer dieses Gate
# ausgeloest hat (v1: robuste Cluster bei 96-100%, Rausch-Cluster bei
# 40-52%). split_ratios-Default (0.15/0.20/0.25/0.30/0.35) und
# n_seeds_per_ratio=10 (50 Kombinationen gesamt) sind aus derselben
# Untersuchung uebernommen - kein Dogma, aber der beste verfuegbare,
# empirisch gepruefte Wert. Weitere Faelle koennten beides spaeter
# verschieben.

suppressPackageStartupMessages({
  library(data.table)
})

#' Prueft, ob ein Baseline-vs.-Wetter-Metrikdelta ueber Modell-Seed UND
#' Split-Ratio hinweg stabil gerichtet ist, oder ob es sich um Rauschen
#' (Modell- und/oder Split-Wahl-Rauschen) handelt.
#'
#' Der Testanteil wird chronologisch als die letzten `ratio` Zeilen
#' definiert (kein Zufalls-Resampling, bleibt zeitlich sauber) - fuer jede
#' Ratio in `split_ratios` wird mit `n_seeds_per_ratio` verschiedenen
#' Lerner-Seeds trainiert. Alle `length(split_ratios) * n_seeds_per_ratio`
#' Deltas zusammen bestimmen die Entscheidung.
#'
#' @param baseline_data data.frame/data.table mit Spalten `date`, `target`
#'   und Baseline-Features (keine Wetterspalten), chronologisch sortierbar.
#' @param weather_data data.frame/data.table mit denselben Zeilen/Spalten
#'   plus Wetterfeatures.
#' @param learner_constructor function(seed) -> mlr3-Learner (frisch, noch
#'   nicht trainiert). Muss `predict_type` etc. bereits selbst setzen.
#' @param measure mlr3-Measure (z.B. `msr("classif.bacc")`).
#' @param split_ratios Vektor der Testanteile (Anteil der Zeilen, chronologisch
#'   ans Ende gelegt). Default `c(0.15, 0.20, 0.25, 0.30, 0.35)`.
#' @param n_seeds_per_ratio Anzahl unabhaengiger Lerner-Seeds JE Ratio
#'   (Default 10 - macht mit dem Ratio-Default 50 Kombinationen gesamt).
#' @param drop_cols Spalten, die weder Feature noch Ziel sind (Default: id/date).
#' @param target_col Name der Zielspalte (Default "target").
#' @param sampling_seed Seed, mit dem die Lerner-Seeds selbst gezogen werden
#'   (Reproduzierbarkeit der Pruefung, nicht des Lernens).
#' @param min_share_for_verdict Anteil gleichgerichteter Kombinationen, ab
#'   dem ein Effekt als robust gilt (Default 0.9, siehe Kalibrierung oben).
#' @return Liste: `deltas`/`ratios`/`seeds` (je Laenge n_kombinationen),
#'   `by_ratio` (data.table: Delta-Mittel/Anteil positiv je Ratio - zeigt,
#'   ob der Befund an einem einzelnen Split haengt), `decision` (einer von
#'   "robust_improvement", "robust_regression", "inconclusive"),
#'   `n_kombinationen`, `min_share_for_verdict`.
weather_enrichment_seed_stability_gate <- function(baseline_data, weather_data,
                                                     learner_constructor, measure,
                                                     split_ratios = c(0.15, 0.20, 0.25, 0.30, 0.35),
                                                     n_seeds_per_ratio = 10,
                                                     drop_cols = c("id", "date"),
                                                     target_col = "target",
                                                     sampling_seed = 42,
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
  if (!is.numeric(split_ratios) || length(split_ratios) == 0 ||
      any(split_ratios <= 0) || any(split_ratios >= 1)) {
    stop("split_ratios muss ein Vektor von Werten in (0, 1) sein.", call. = FALSE)
  }

  fit_score <- function(data, ratio, seed) {
    dt <- data.table::as.data.table(data)
    dt[, date := as.Date(date)]
    data.table::setorder(dt, date)
    n <- nrow(dt)
    n_test <- max(1L, round(n * ratio))
    if (n_test >= n) {
      stop("split_ratios erzeugt einen leeren Trainingsanteil.", call. = FALSE)
    }
    train <- dt[seq_len(n - n_test)]
    test <- dt[(n - n_test + 1L):n]
    feature_cols <- setdiff(names(dt), drop_cols)
    train_data <- train[, .SD, .SDcols = feature_cols]
    test_data <- test[, .SD, .SDcols = feature_cols]

    set.seed(seed)
    task <- mlr3::as_task_classif(train_data, target = target_col,
                                   id = paste0("gate_r", ratio, "_s", seed))
    learner <- learner_constructor(seed)
    learner$train(task)
    test_task <- mlr3::as_task_classif(test_data, target = target_col,
                                        id = paste0("gate_r", ratio, "_s", seed, "_test"))
    pred <- learner$predict(test_task)
    pred$score(measure)[[measure$id]]
  }

  set.seed(sampling_seed)
  seeds <- sample.int(1e6, n_seeds_per_ratio)

  grid <- data.table::CJ(ratio = split_ratios, seed = seeds)
  grid[, delta := mapply(function(r, s) {
    fit_score(weather_data, r, s) - fit_score(baseline_data, r, s)
  }, ratio, seed)]

  share_positive <- mean(grid$delta > 0)
  share_negative <- mean(grid$delta < 0)
  decision <- if (share_positive >= min_share_for_verdict) {
    "robust_improvement"
  } else if (share_negative >= min_share_for_verdict) {
    "robust_regression"
  } else {
    "inconclusive"
  }

  by_ratio <- grid[, .(delta_mean = mean(delta), share_positive = mean(delta > 0)), by = ratio]
  data.table::setorder(by_ratio, ratio)

  list(
    deltas = grid$delta, ratios = grid$ratio, seeds = grid$seed,
    by_ratio = by_ratio,
    delta_mean = mean(grid$delta), delta_sd = stats::sd(grid$delta),
    share_positive = share_positive, share_negative = share_negative,
    decision = decision, n_kombinationen = nrow(grid),
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
        "Trust-Gate nicht bestanden: %d/%d Kombinationen (Split-Ratio x Seed) ",
        "positiv, %d/%d negativ (Schwelle %.0f%%) - kein robuster Befund. Ein ",
        "gerichteter Befund ('Wetter hilft'/'Wetter schadet') darf NICHT ",
        "berichtet werden. Siehe weather_enrichment_trust_gate.R (Anlass v2)."
      ),
      round(gate_result$share_positive * gate_result$n_kombinationen), gate_result$n_kombinationen,
      round(gate_result$share_negative * gate_result$n_kombinationen), gate_result$n_kombinationen,
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
