suppressPackageStartupMessages({
  library(data.table)
})

# Diagnostiziert nach einem tnr("mbo")-Lauf, ob echte sequenzielle Bayesian-
# Optimization-Verfeinerung stattgefunden hat, oder ob das gesamte Budget im
# (quasi-zufaelligen) Initialdesign aufgebraucht wurde. mlr3mbo's
# Initialdesign skaliert standardmaessig mit ~4x Anzahl Suchraum-Parameter -
# wird der Suchraum erweitert, ohne das Eval-Budget entsprechend zu erhoehen,
# landen ALLE Punkte in Batch 1 und es gibt keine einzige echte
# Verfeinerung, ohne dass ein Fehler oder eine Warnung erscheint (gefunden
# bei einer Uebertragung dieses Templates auf ein Projekt mit erweitertem
# LightGBM-Suchraum, siehe TARGETS.md-Backlog).
#
# Gibt zusaetzlich einen groben Plateau-Indikator aus: Spannweite/SD der
# Zielmetrik ueber alle Archiv-Punkte sowie R^2 eines linearen Modells
# (Zielmetrik ~ alle numerischen Suchraum-Parameter). Kleine Spannweite +
# niedriges/moderates R^2 spricht fuer ein Plateau (mehr Budget bringt
# vermutlich wenig); grosse Spannweite oder ein klar erkennbares R^2 spricht
# dafuer, dass sich mehr Suchbudget lohnen koennte. Das ist eine Faustregel-
# Einschaetzung, kein Beweis - bei Unsicherheit lieber gegenpruefen.
#
# instance: die tar_target/ti()-Instanz NACH tuner$optimize(instance).
# target_metric: Spaltenname der Zielmetrik im Archiv (z.B. "classif.auc").
diagnose_mbo_search <- function(instance, target_metric) {
  archive_dt <- as.data.table(instance$archive$data)

  non_param_cols <- c(target_metric, "runtime_learners", "batch_nr", "warnings", "errors", "timestamp", "uhash")
  numeric_param_cols <- setdiff(
    names(archive_dt)[vapply(archive_dt, is.numeric, logical(1))],
    non_param_cols
  )

  n_batches <- length(unique(archive_dt$batch_nr))
  metric_vals <- archive_dt[[target_metric]]
  metric_range <- range(metric_vals)
  metric_spread <- diff(metric_range)
  metric_sd <- sd(metric_vals)

  cat("=== mbo-Suchdiagnose (", nrow(archive_dt), " Punkte, ", n_batches, " Batch(es)) ===\n", sep = "")
  if (n_batches == 1) {
    cat("WARNUNG: Alle Punkte in einem einzigen Batch - das gesamte Budget ging\n")
    cat("vermutlich ins Initialdesign, es gab KEINE echte sequenzielle\n")
    cat("Bayesian-Optimization-Verfeinerung. Ergebnis mit Vorsicht behandeln -\n")
    cat("nicht als 'Bayesian-optimiert' vertrauen, unbedingt per CV gegenpruefen,\n")
    cat("bevor es uebernommen wird. Budget erhoehen (Faustregel: >= 4x Anzahl\n")
    cat("Suchraum-Parameter + 10-20 fuer Verfeinerung) und erneut laufen lassen.\n")
  } else {
    cat("OK: ", n_batches, " Batches - es fand sequenzielle Verfeinerung statt.\n", sep = "")
  }

  cat(
    "\n", target_metric, "-Spannweite: [", round(metric_range[1], 4), ", ", round(metric_range[2], 4),
    "] (Spanne ", round(metric_spread, 4), ", SD ", round(metric_sd, 4), ")\n",
    sep = ""
  )

  r_squared <- NA_real_
  if (length(numeric_param_cols) >= 1 && nrow(archive_dt) > length(numeric_param_cols) + 1) {
    formula_str <- paste(target_metric, "~", paste(numeric_param_cols, collapse = " + "))
    fit <- lm(as.formula(formula_str), data = archive_dt)
    r_squared <- summary(fit)$r.squared
    cat("Lineares Modell (", target_metric, " ~ alle Suchraum-Parameter): R^2 = ", round(r_squared, 3), "\n", sep = "")
  }

  cat("\nEinschaetzung: ")
  if (metric_spread < 0.02 && (is.na(r_squared) || r_squared < 0.7)) {
    cat("Schmales Plateau - weiteres Suchbudget bringt vermutlich nur geringe Verbesserung.\n")
  } else if (metric_spread >= 0.02) {
    cat("Deutliche Spannweite zwischen den Konfigurationen - mehr Suchbudget koennte sich lohnen.\n")
  } else {
    cat("Uneindeutig - bei Bedarf mit mehr Budget/Wiederholungen gegenpruefen.\n")
  }

  invisible(list(
    n_batches = n_batches, metric_range = metric_range,
    metric_spread = metric_spread, metric_sd = metric_sd, r_squared = r_squared
  ))
}
