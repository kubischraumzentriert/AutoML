rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3measures)
})

source("000_config.R")

# Segmentmetriken (siehe WorkflowDescription.md Phase 11): eine Gesamt-Metrik
# kann eine schwache Untergruppen-Performance verstecken (Simpson-Paradoxon -
# Modell A kann in JEDER Untergruppe schlechter sein als Modell B und trotzdem
# insgesamt besser abschneiden, wenn die Gruppengroessen unterschiedlich sind).
# Baut auf dem `147_error_analysis_ranger_models.R`-Artefakt auf, kein
# erneutes Training - loses Kopplungsmuster wie die uebrigen 147-Skripte.
if (!length(segment_metric_cols)) {
  cat("Keine segment_metric_cols in 000_config.R gesetzt. Segmentmetriken uebersprungen.\n")
  quit(save = "no", status = 0)
}
if (!file.exists(error_analysis_models_path)) {
  stop("Fehleranalyse-Modelle fehlen. Erst 147_error_analysis_ranger_models.R ausfuehren.")
}

models <- readRDS(error_analysis_models_path)

missing_cols <- setdiff(segment_metric_cols, names(models$eval_imputed))
if (length(missing_cols)) {
  stop("Segmentspalten nicht im Fehleranalyse-Eval-Set (nur Modell-Features verfuegbar): ",
       paste(missing_cols, collapse = ", "))
}

truth <- models$truth
model_responses <- list(ranger = models$ranger_response, lightgbm = models$lightgbm_response, lda = models$lda_response)

compute_segment_metrics <- function(seg_col) {
  seg_vals <- as.character(models$eval_imputed[[seg_col]])
  rbindlist(lapply(names(model_responses), function(model_name) {
    response <- model_responses[[model_name]]
    dt <- data.table(segment_value = seg_vals, truth = truth, response = response)
    dt[, .(
      n = .N,
      bacc = mlr3measures::bacc(truth, response),
      mcc = mlr3measures::mcc(truth, response)
    ), by = segment_value][, `:=`(segment_col = seg_col, model = model_name)][]
  }))
}

results <- rbindlist(lapply(segment_metric_cols, compute_segment_metrics), fill = TRUE)
setcolorder(results, c("segment_col", "segment_value", "model", "n", "bacc", "mcc"))

# Ueberall-Referenz je (segment_col, model): zeilengewichteter Mittelwert der
# Segment-BAcc - nicht identisch mit der ungewichteten Gesamt-BAcc, aber der
# richtige Vergleichspunkt fuer "wie weit weicht dieses Segment vom Rest ab".
overall <- results[, .(bacc_overall = weighted.mean(bacc, n)), by = .(segment_col, model)]
results <- merge(results, overall, by = c("segment_col", "model"), sort = FALSE)
results[, gap := bacc_overall - bacc]
setorder(results, segment_col, model, -gap)

flagged <- results[gap > segment_metric_warn_gap]

fwrite(results, segment_metrics_path)

cat("=== Segmentmetriken (Klassifikation) ===\n")
print(results)
if (nrow(flagged)) {
  cat(sprintf("\n=== WARNUNG: %d Segment(e) mit BAcc-Luecke > %.2f ===\n", nrow(flagged), segment_metric_warn_gap))
  print(flagged[, .(segment_col, segment_value, model, n, bacc, bacc_overall, gap)])
  cat("\nEin Modell mit guter Gesamt-BAcc kann trotzdem auf einer Untergruppe deutlich\n")
  cat("schlechter sein (Simpson-Paradoxon) - vor einer Modellwahl pruefen, ob eine\n")
  cat("betroffene Gruppe fachlich kritisch ist.\n")
} else {
  cat(sprintf("\nKeine Segmente mit BAcc-Luecke > %.2f - unauffaellig.\n", segment_metric_warn_gap))
}
cat("\nGespeichert:", segment_metrics_path, "\n")
