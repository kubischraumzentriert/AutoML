suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
})

# Warnt (statt spaeter mit einem kryptischen lda.default-Fehler abzubrechen),
# wenn ein Faktor-Feature so hochkardinal ist, dass eine One-Hot-Kodierung
# (implizit bei classif.lda/classif.multinom) zu Spalten fuehrt, die
# innerhalb einer Zielklasse konstant sind. Aufgetreten bei einer
# Uebertragung dieses Templates auf ein Projekt mit einer 887-Level-Spalte
# (siehe TEMPLATE_FRICTION.md des jeweiligen Projekts) - das gesunde
# Gesundheitsdaten-Set hier hat keine derart hochkardinalen Spalten, daher
# rueckwirkungsfrei, aber als Absicherung fuer kuenftige Uebertragungen
# nuetzlich. threshold ist eine Faustregel, keine harte Grenze.
warn_high_cardinality_factors <- function(task, threshold = 50) {
  feature_types <- task$feature_types
  factor_cols <- feature_types[type %in% c("factor", "ordered"), id]
  if (length(factor_cols) == 0) {
    return(invisible(NULL))
  }

  data <- task$data(cols = factor_cols)
  cardinalities <- vapply(data, function(x) length(unique(x)), integer(1))
  high_card <- cardinalities[cardinalities > threshold]

  if (length(high_card) > 0) {
    warning(
      "Hochkardinale Faktor-Spalte(n) gefunden (> ", threshold, " Auspraegungen): ",
      paste(names(high_card), "=", high_card, collapse = ", "),
      " - LDA/Multinom kodieren Faktoren implizit als One-Hot und koennen bei ",
      "so vielen Auspraegungen abstuerzen (Spalten konstant innerhalb einer ",
      "Klasse). Erwaegen, die Spalte(n) fuer diese Modelle auszuschliessen ",
      "oder sinnvoll zu kodieren (Frequenz-/Zielkodierung), bevor 030/037/",
      "080 laufen.",
      call. = FALSE
    )
  }

  invisible(high_card)
}

run_timed_benchmark <- function(tasks, learners, resampling, measures) {
  benchmark_results <- list()
  result_rows <- list()
  score_rows <- list()
  run_id <- 1L

  for (task in tasks) {
    task_resampling <- resampling$clone(deep = TRUE)
    task_resampling$instantiate(task)

    for (learner in learners) {
      design <- data.table(
        task = list(task),
        learner = list(learner),
        resampling = list(task_resampling$clone(deep = TRUE))
      )

      timing <- system.time({
        benchmark_result <- benchmark(design)
      })

      result <- benchmark_result$aggregate(measures = measures)
      result[, elapsed_seconds := as.numeric(timing[["elapsed"]])]

      # Werte pro einzelnem Resampling-Fold (nicht nur aggregiert) - fuer das
      # Experiment-Tracking (siehe db_logging.R, metric_result.mres_fold).
      scores <- benchmark_result$score(measures = measures)
      scores[, elapsed_seconds := as.numeric(timing[["elapsed"]])]

      benchmark_results[[run_id]] <- benchmark_result
      result_rows[[run_id]] <- result
      score_rows[[run_id]] <- scores
      run_id <- run_id + 1L
    }
  }

  list(
    results = rbindlist(result_rows, fill = TRUE),
    scores = rbindlist(score_rows, fill = TRUE),
    benchmarks = benchmark_results
  )
}
