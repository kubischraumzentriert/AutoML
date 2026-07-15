suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
})

# Laedt die zuletzt geloggten Vorhersagen eines Algorithmus aus experiments.db
# (neuester run_started_at je mconf_algorithm) und gibt Wahrheit + vorher-
# gesagte Wahrscheinlichkeit der positiven Klasse als data.table zurueck.
# Funktioniert nur sinnvoll, wenn dieser Run VOLLSTAENDIG geloggt wurde (alle
# Eval-Zeilen, nicht nur die "interessante" Teilmenge aus 147 vor 2026-07-15)
# - print_n zeigt die geladene Zeilenzahl zur Plausibilitaetspruefung an.
load_latest_predictions <- function(con, algorithm, positive_class = "1") {
  latest_run <- dbGetQuery(con, "
    SELECT r.run_id, r.run_started_at, mc.mconf_id
    FROM prediction pr
    JOIN model_config mc ON mc.mconf_id = pr.pred_mconf_id
    JOIN run r ON r.run_id = mc.mconf_run_id
    WHERE mc.mconf_algorithm = ?
    ORDER BY r.run_started_at DESC
    LIMIT 1
  ", params = list(algorithm))

  if (nrow(latest_run) == 0) {
    stop("Keine geloggten Vorhersagen fuer Algorithmus '", algorithm, "' gefunden - erst ein Skript mit db_log_predictions() laufen lassen (z.B. 147).")
  }

  mconf_id <- latest_run$mconf_id[1]

  preds <- setDT(dbGetQuery(con, "
    SELECT pr.pred_seq, pr.pred_row_id, pr.pred_truth, pr.pred_response, pp.pprob_class, pp.pprob_value
    FROM prediction pr
    JOIN prediction_prob pp ON pp.pprob_pred_seq = pr.pred_seq
    WHERE pr.pred_mconf_id = ?
  ", params = list(mconf_id)))

  if (!(positive_class %in% preds$pprob_class)) {
    stop(
      "Positive Klasse '", positive_class, "' nicht unter den geloggten Wahrscheinlichkeitsspalten (",
      paste(unique(preds$pprob_class), collapse = ", "), ")."
    )
  }

  wide <- preds[pprob_class == positive_class, .(pred_seq, pred_row_id, pred_truth, prob_positive = pprob_value)]

  cat(
    "Geladen: Algorithmus '", algorithm, "', Run ", latest_run$run_started_at[1],
    ", ", nrow(wide), " Zeilen (positive Klasse: '", positive_class, "').\n",
    sep = ""
  )

  wide
}

# Schwellenwert-Sweep ueber alle eindeutigen vorhergesagten Wahrscheinlich-
# keiten (absteigend), liefert in EINEM Durchgang sowohl ROC- (tpr/fpr) als
# auch PR-Kurvenpunkte (precision/recall = tpr). Bei Wahrscheinlichkeits-
# Gleichstand wird nur der letzte (niedrigste TPR/FPR bei diesem Wert)
# Punkt behalten, um die Punktezahl bei grossen Datensaetzen klein zu halten.
# Funktioniert nicht nur fuer binaere Aufgaben: "truth == positive" fasst bei
# >=3 Klassen automatisch alle anderen Klassen als "negativ" zusammen, das
# Ergebnis ist dann eine One-vs-Rest-Kurve fuer genau die gewaehlte Klasse.
compute_classif_curves <- function(truth, prob_positive, positive) {
  ord <- order(prob_positive, decreasing = TRUE)
  truth_sorted <- truth[ord]
  prob_sorted <- prob_positive[ord]
  is_positive <- truth_sorted == positive

  n_pos <- sum(is_positive)
  n_neg <- sum(!is_positive)
  if (n_pos == 0 || n_neg == 0) {
    stop("Beide Klassen muessen in truth vorkommen (n_pos=", n_pos, ", n_neg=", n_neg, ").")
  }

  tp <- cumsum(is_positive)
  fp <- cumsum(!is_positive)

  tpr <- tp / n_pos
  fpr <- fp / n_neg
  precision <- tp / (tp + fp)

  keep <- !duplicated(prob_sorted, fromLast = TRUE)

  curve <- data.table(
    threshold = prob_sorted[keep],
    tpr = tpr[keep], fpr = fpr[keep],
    precision = precision[keep], recall = tpr[keep]
  )

  # Startpunkte ergaenzen (Konvention wie z.B. scikit-learn): ROC beginnt bei
  # (FPR=0, TPR=0), PR beginnt bei (Recall=0, Precision=1) - vor der ersten
  # tatsaechlichen Vorhersage ist noch nichts als positiv klassifiziert.
  curve <- rbindlist(list(
    data.table(threshold = Inf, tpr = 0, fpr = 0, precision = 1, recall = 0),
    curve
  ))

  curve
}

# Flaeche unter einer Kurve per Trapezregel - fuer ROC-AUC (x=fpr, y=tpr) und
# PR-AUC/Average Precision (x=recall, y=precision) gleichermassen nutzbar.
# Dient als Cross-Check gegen den in metric_result geloggten classif.auc-Wert.
curve_auc <- function(x, y) {
  ord <- order(x)
  x <- x[ord]
  y <- y[ord]
  sum(diff(x) * (head(y, -1) + tail(y, -1)) / 2)
}
