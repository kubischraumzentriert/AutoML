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
# 0.872 -> Grid 0.937 -> kontinuierlich 0.946 (Grid rannte in 6/6, der
# Optimizer fand fit ~20-38, unhealthy ~14-19). Vgl. 2nd-place-Loesung
# (Nelder-Mead-Multiplikatoren als groesster Einzelhebel, +0.06 BAcc).

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
#' @return list(multipliers, bacc, grid_multipliers, grid_bacc, reference_class).
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

  # 1) Grid als robuster Startpunkt.
  combos <- as.matrix(expand.grid(replicate(length(others), grid, simplify = FALSE)))
  grid_best <- base1; grid_bacc <- score(base1)
  for (i in seq_len(nrow(combos))) {
    m <- base1; m[others] <- as.numeric(combos[i, ])
    b <- score(m); if (b > grid_bacc) { grid_bacc <- b; grid_best <- m }
  }

  # 2) Kontinuierliche Verfeinerung (Nelder-Mead), mult = exp(theta) > 0.
  obj <- function(theta) { m <- base1; m[others] <- exp(theta); -score(m) }
  to_theta <- function(m) log(pmax(m[others], 1e-4))
  starts <- c(list(to_theta(grid_best)), lapply(extra_starts, to_theta))
  best <- grid_best; best_bacc <- grid_bacc
  for (st in starts) {
    o <- tryCatch(optim(st, obj, method = "Nelder-Mead",
                        control = list(maxit = 1000, reltol = 1e-11)),
                  error = function(e) NULL)
    if (is.null(o)) next
    b <- -o$value
    if (b > best_bacc) { best_bacc <- b; m <- base1; m[others] <- exp(o$par); best <- m }
  }

  list(multipliers = best, bacc = best_bacc,
       grid_multipliers = grid_best, grid_bacc = grid_bacc,
       reference_class = ref)
}
