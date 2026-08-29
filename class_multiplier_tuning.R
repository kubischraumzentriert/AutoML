# =====================================================================
# class_multiplier_tuning.R -- Metrik-optimale Klassen-Multiplikatoren
# =====================================================================
# Post-hoc-Baustein fuer schwellenwert-ABHAENGIGE Multiklassen-Metriken
# (v.a. Balanced Accuracy): skaliert die vorhergesagten Klassen-Wahr-
# scheinlichkeiten mit klassenweisen Faktoren, bevor argmax entscheidet
# (`argmax(prob * multiplier)`), und sucht die Faktoren, die die Metrik
# maximieren. Verallgemeinert das binaere Threshold-Tuning auf K Klassen.
#
# Reibung, die das noetig machte: Die frueher in 130 fest verdrahtete
# GRID-Suche `seq(0.5, 6, by=0.5)` traf bei stark unbalancierten Zielen
# regelmaessig ihre Obergrenze (Minderheitsklassen wollen Faktoren weit
# jenseits von 6). Ein kontinuierlicher Optimizer (Nelder-Mead) findet
# das Optimum, ist billiger und skaliert mit der Klassenzahl. Das Grid
# bleibt als robuster STARTPUNKT erhalten (die Verfeinerung kann nie
# schlechter werden als das Grid-Optimum).
#
# Bestaetigt an s6e7/health_condition (3-Klassen/BAcc, OOF): raw argmax
# 0.872 -> Grid 0.936 -> Prior-Korrektur 1/prior 0.943 -> kontinuierlich 0.945
# (Grid rannte in seine Decke 6/6; 1/prior liegt tuning-frei richtig und
# schlaegt das Grid; der Optimizer holt nur noch +0.002 obendrauf). Vgl.
# 2nd-place (getunte Multiplikatoren) und 4th-place (argmax(p/prior)) von
# s6e7 - beide mit dem Metrik-aligned Entscheidungsschritt als groesstem Hebel.

suppressPackageStartupMessages({
  library(mlr3measures)
})

# --- Metrik unter gegebenen Multiplikatoren -------------------------
# metric_fn(truth, response) -> hoeher = besser (Default: Balanced Accuracy).
.mult_metric <- function(probs, truth, classes, mult, metric_fn) {
  wp <- sweep(probs, 2, mult[classes], `*`)
  pred <- factor(classes[max.col(wp, ties.method = "first")], levels = classes)
  metric_fn(truth, pred)
}

#' Wendet fertige Klassen-Multiplikatoren an -> vorhergesagte Klassen-Faktoren.
#' @param probs  Matrix (Zeilen = Beobachtungen, Spalten = Klassen).
#' @param multipliers benannter Vektor (Namen = Klassen).
apply_class_multipliers <- function(probs, multipliers, classes = colnames(probs)) {
  wp <- sweep(probs[, classes, drop = FALSE], 2, multipliers[classes], `*`)
  factor(classes[max.col(wp, ties.method = "first")], levels = classes)
}

#' Prior-Korrektur in geschlossener Form: Multiplikatoren = 1 / Klassen-Prior,
#' auf die Mehrheitsklasse (Faktor 1) normiert. `argmax(prob / prior)` ist die
#' Bayes-optimale Entscheidungsregel fuer Balanced Accuracy (Makro-Recall) bei
#' gut kalibrierten Wahrscheinlichkeiten - Zero-Tuning, kein Tune/Eval-Split
#' noetig. Warnung: NICHT mit Trainings-Klassengewichtung stapeln (beide loesen
#' dasselbe Problem -> Ueberkorrektur der Minderheitsklassen). Auf UNgewichtete
#' Modelle anwenden. Verifiziert an s6e7/health_condition: schlaegt die reine
#' Grid-Suche und liefert ~97% des Multiplikator-Hebels ohne Optimierung.
#' @param truth Faktor der Trainings-/Tune-Labels (liefert die Priors).
prior_correction_multipliers <- function(truth, classes = levels(truth)) {
  truth <- factor(as.character(truth), levels = classes)
  prior <- as.numeric(table(truth)[classes]) / length(truth)
  ref <- which.max(prior)                       # Mehrheitsklasse -> Faktor 1
  setNames(prior[ref] / prior, classes)
}

#' Sucht metrik-optimale Klassen-Multiplikatoren.
#'
#' Referenzklasse (die haeufigste in `truth`) bleibt bei Faktor 1 fixiert -
#' nur Verhaeltnisse zaehlen fuer argmax, und ein aufwaertsgerichtetes Grid
#' auf den uebrigen Klassen erreicht die noetigen grossen Minderheitsfaktoren.
#'
#' @param probs Matrix (Spalten = Klassen), Zeilen = Beobachtungen.
#' @param truth Faktor gleicher Laenge, Levels = `classes`.
#' @param grid  Grid fuer die uebrigen Klassen (robuster Startpunkt/Fallback).
#' @param extra_starts optionale weitere Startpunkte (Liste benannter Vektoren).
#' @param metric_fn Metrik(truth, response), hoeher = besser.
#' @return list(multipliers, bacc, grid_multipliers, grid_bacc,
#'   prior_multipliers, prior_bacc, reference_class).
tune_class_multipliers <- function(probs, truth, classes = colnames(probs),
                                   grid = seq(0.5, 6, by = 0.5),
                                   extra_starts = list(),
                                   metric_fn = mlr3measures::bacc) {
  probs <- probs[, classes, drop = FALSE]
  truth <- factor(as.character(truth), levels = classes)
  score <- function(mult) .mult_metric(probs, truth, classes, mult, metric_fn)

  ref <- classes[which.max(as.integer(table(truth)[classes]))]   # Referenz = Mehrheit
  others <- setdiff(classes, ref)
  base1 <- setNames(rep(1, length(classes)), classes)

  # 1) Grid als robuster Startpunkt - NUR wenn die Kombinatorik praktikabel
  # bleibt. `length(grid)^length(others)` waechst exponentiell mit der
  # Klassenzahl (Klasse-1-Referenz -> `others` = Klassen-1 freie
  # Dimensionen): bei 3 Klassen (2 Dimensionen) harmlose 144 Kombinationen,
  # bei 10 Klassen (9 Dimensionen, echter Fund 2026-08-29,
  # `openml-cc18-optdigits`) bereits 12^9 ≈ 5.2 Mrd. Zeilen -> OOM-Absturz
  # ("cannot allocate vector of size 38.4 Gb"). Oberhalb der Schwelle wird
  # der volle Grid-Durchlauf uebersprungen (grid_best/grid_bacc bleiben die
  # Identitaet als harmloser Platzhalter) - Schritt 1b (Prior-Korrektur)
  # und Schritt 2 (Nelder-Mead, dimensionsunabhaengig in der Rechenzeit)
  # uebernehmen dann allein die Rolle des robusten Startpunkts.
  max_grid_combos <- 200000
  grid_combo_count <- length(grid)^length(others)
  grid_best <- base1; grid_bacc <- score(base1)
  if (grid_combo_count <= max_grid_combos) {
    combos <- as.matrix(expand.grid(replicate(length(others), grid, simplify = FALSE)))
    for (i in seq_len(nrow(combos))) {
      m <- base1; m[others] <- as.numeric(combos[i, ])
      b <- score(m); if (b > grid_bacc) { grid_bacc <- b; grid_best <- m }
    }
  }

  # 1b) Prior-Korrektur (1/prior) als prinzipieller, tuning-freier Startpunkt -
  # schlaegt das Grid, wenn dieses in seine Obergrenze laeuft (Minderheitsfaktoren
  # jenseits von 6). Referenz = dieselbe Mehrheitsklasse.
  m_prior <- prior_correction_multipliers(truth, classes)
  prior_bacc <- score(m_prior)

  # 2) Kontinuierliche Verfeinerung, mult = exp(theta) > 0 - geseedet von
  # Grid-Optimum UND Prior-Korrektur (+ optionalen extra_starts).
  obj <- function(theta) { m <- base1; m[others] <- exp(theta); -score(m) }
  to_theta <- function(m) log(pmax(m[others], 1e-4))
  starts <- c(list(grid_best, m_prior), extra_starts)
  if (prior_bacc > grid_bacc) { best <- m_prior; best_bacc <- prior_bacc }
  else { best <- grid_best; best_bacc <- grid_bacc }

  if (length(others) == 1) {
    # Binaere Aufgabe (2 Klassen): genau 1 freier Multiplikator. Nelder-Mead
    # ist fuer mehrdimensionale Probleme gebaut und warnt bei 1D explizit auf
    # eine zuverlaessigere Alternative (siehe optim()-Dokumentation) -
    # optimize() (Brent) statt Nelder-Mead. Kein Start-Loop noetig:
    # optimize() durchsucht das gesamte Intervall direkt, unabhaengig vom
    # Startwert - reine Erste-Anwendung-Reibung (2026-08-14, openml-credit-g,
    # erstes binaere Projekt nach dem Threshold-Tuning-Backport), siehe
    # TARGETS.md.
    o <- tryCatch(optimize(obj, interval = c(log(1e-4), log(1e4)), tol = 1e-8),
                  error = function(e) NULL)
    if (!is.null(o)) {
      b <- -o$objective
      if (b > best_bacc) { best_bacc <- b; m <- base1; m[others] <- exp(o$minimum); best <- m }
    }
  } else {
    # >=3 Klassen: >=2 freie Multiplikatoren, Nelder-Mead mit mehreren
    # Startpunkten (Grid-Optimum, Prior-Korrektur, optionale extra_starts).
    for (st in starts) {
      o <- tryCatch(optim(to_theta(st), obj, method = "Nelder-Mead",
                          control = list(maxit = 1000, reltol = 1e-11)),
                    error = function(e) NULL)
      if (is.null(o)) next
      b <- -o$value
      if (b > best_bacc) { best_bacc <- b; m <- base1; m[others] <- exp(o$par); best <- m }
    }
  }

  list(multipliers = best, bacc = best_bacc,
       grid_multipliers = grid_best, grid_bacc = grid_bacc,
       prior_multipliers = m_prior, prior_bacc = prior_bacc,
       reference_class = ref)
}

# --- Nested/gepooltes per-Fold-Multiplikator-Tuning -------------------
# Verallgemeinert die in CreditScoringChallenge/040_threshold_tuning.R
# projekt-lokal gebaute binaere F1-Nested-CV (siehe TARGETS.md) auf
# beliebige Klassenzahl/Metrik, indem sie das bereits vorhandene
# tune_class_multipliers() wiederverwendet statt Suchlogik zu duplizieren.
#
# Problem beim bestehenden 3-Wege-Split (130_threshold_tuning.R): EIN
# stratifizierter Tune-/Eval-Split - die Multiplikatoren werden nur auf
# einem Bruchteil der Daten gesucht, die Eval-Zahl ist eine einzelne,
# potenziell verrauschte Stichprobe. Nested-CV nutzt STATTDESSEN alle
# Zeilen fuer beides: fuer jeden Fold k werden die Multiplikatoren NUR auf
# den OOF-Vorhersagen der UEBRIGEN Folds gesucht und auf Fold k angewendet
# (Fold k war an der Suche unbeteiligt - kein Leck). Gepoolt ueber alle
# Folds ergibt das eine ehrlichere, datensparsamere Schaetzung als der
# einzelne Eval-Split. Die finale Deployment-Multiplikatoren werden
# separat auf ALLEN OOF-Vorhersagen gesucht (bester Punkt fuer die echte
# Submission, nicht Teil der ehrlichen Schaetzung).
#
# @param task mlr3-TaskClassif (bereits vorbereitet, z.B. gewichtet via
#   add_balanced_class_weights() falls gewuenscht).
# @param learner mlr3-Learner mit predict_type = "prob".
# @param folds Anzahl CV-Folds fuer die OOF-Vorhersagen.
# @param metric_fn Metrik(truth, response) fuer die Fold-/Nested-Berichte
#   (Multiplikator-SUCHE selbst optimiert weiterhin die Metrik aus
#   tune_class_multipliers()s eigenem metric_fn-Argument, Default BAcc).
# @return list(fold_info [data.table je Fold: threshold_metric_source,
#   metric_on_fold], nested_metric [gepoolte ehrliche Schaetzung],
#   final_multipliers, final_metric [auf allen OOF, Deployment-Punkt]).
nested_cv_class_multiplier_tuning <- function(task, learner, folds = 5,
                                              classes = task$class_names,
                                              grid = seq(0.5, 6, by = 0.5),
                                              metric_fn = mlr3measures::bacc,
                                              seed = 42) {
  set.seed(seed)
  rr <- mlr3::resample(task, learner, mlr3::rsmp("cv", folds = folds))
  preds <- rr$predictions()

  extract <- function(p) list(
    prob = p$prob[, classes, drop = FALSE],
    truth = factor(as.character(p$truth), levels = classes)
  )
  per_fold <- lapply(preds, extract)

  pooled_response <- vector("list", length(per_fold))
  pooled_truth <- vector("list", length(per_fold))
  fold_info <- vector("list", length(per_fold))

  for (k in seq_along(per_fold)) {
    others <- per_fold[-k]
    others_prob <- do.call(rbind, lapply(others, `[[`, "prob"))
    others_truth <- factor(unlist(lapply(others, function(o) as.character(o$truth))), levels = classes)

    tuned_on_others <- tune_class_multipliers(others_prob, others_truth, classes, grid = grid, metric_fn = metric_fn)
    response_k <- apply_class_multipliers(per_fold[[k]]$prob, tuned_on_others$multipliers, classes)

    pooled_response[[k]] <- response_k
    pooled_truth[[k]] <- per_fold[[k]]$truth
    fold_info[[k]] <- data.table::data.table(
      fold = k,
      metric_on_fold = metric_fn(per_fold[[k]]$truth, response_k),
      multipliers = paste(sprintf("%s=%.2f", names(tuned_on_others$multipliers), tuned_on_others$multipliers), collapse = ", ")
    )
  }

  nested_metric <- metric_fn(
    factor(unlist(lapply(pooled_truth, as.character)), levels = classes),
    factor(unlist(lapply(pooled_response, as.character)), levels = classes)
  )

  # Finale Deployment-Multiplikatoren: auf ALLEN OOF-Vorhersagen gesucht -
  # kein Bestandteil der ehrlichen nested_metric-Schaetzung oben (die darf
  # keine Zeile verwenden, auf der auch die fuer sie geltenden Multiplikatoren
  # gesucht wurden), aber der richtige Punkt fuer die tatsaechliche Submission.
  all_prob <- do.call(rbind, lapply(per_fold, `[[`, "prob"))
  all_truth <- factor(unlist(lapply(per_fold, function(p) as.character(p$truth))), levels = classes)
  final <- tune_class_multipliers(all_prob, all_truth, classes, grid = grid, metric_fn = metric_fn)

  list(
    fold_info = data.table::rbindlist(fold_info),
    nested_metric = nested_metric,
    final_multipliers = final$multipliers,
    final_metric = final$bacc
  )
}
