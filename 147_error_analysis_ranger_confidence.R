rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
})

source("000_config.R")

# Zweiter Baustein der Fehleranalyse: laedt die in 147_..._models.R
# gespeicherten Vorhersagen (kein erneutes Training) und berechnet die
# Rescue-Rate-Analyse + "alle Modelle einig falsch"-Faelle. Speichert die
# abgeleiteten Zeilen-Indizes als eigenes Artefakt fuer nachgelagerte
# Skripte (Isolation Forest, KernelSHAP, TabPFN).
if (!file.exists(error_analysis_models_path)) {
  source(file.path(project_dir, "147_error_analysis_ranger_models.R"))
}
models <- readRDS(error_analysis_models_path)
invisible(list2env(models, envir = environment()))

# --- Teil 1: Ranger-Fehler - Sicherheit & haette LightGBM richtig gelegen? -
misclassified_idx <- which(ranger_response != truth)

error_dt <- data.table(
  truth = truth[misclassified_idx],
  ranger_pred = ranger_response[misclassified_idx],
  ranger_confidence = ranger_confidence[misclassified_idx],
  ranger_true_class_prob = ranger_true_class_prob[misclassified_idx],
  lightgbm_pred = lightgbm_response[misclassified_idx],
  lightgbm_confidence = lightgbm_confidence[misclassified_idx],
  lightgbm_correct = lightgbm_response[misclassified_idx] == truth[misclassified_idx],
  lda_pred = lda_response[misclassified_idx],
  lda_confidence = lda_confidence[misclassified_idx],
  lda_correct = lda_response[misclassified_idx] == truth[misclassified_idx]
)
# 0.5 ist bei 3 Klassen kein willkuerlicher Bruchteil: darunter war nicht mal
# die vorhergesagte Klasse selbst mehrheitsfaehig (Ranger "unsicher"), darueber
# war sich Ranger trotz falscher Antwort mehrheitlich sicher ("selbstsicher falsch").
error_dt[, ranger_confidence_bucket := fifelse(ranger_confidence < 0.5, "unsicher (<0.5)", "selbstsicher falsch (>=0.5)")]

rescue_summary <- error_dt[, .(
  n_fehler = .N,
  lightgbm_rescue_rate = round(mean(lightgbm_correct), 4),
  lda_rescue_rate = round(mean(lda_correct), 4),
  mean_ranger_confidence = round(mean(ranger_confidence), 4)
), by = ranger_confidence_bucket]
setorder(rescue_summary, ranger_confidence_bucket)

overall_rescue_rate <- mean(error_dt$lightgbm_correct)
overall_lda_rescue_rate <- mean(error_dt$lda_correct)

# Bonus (symmetrisch): rettet umgekehrt Ranger LightGBMs Fehler?
lightgbm_misclassified_idx <- which(lightgbm_response != truth)
lightgbm_error_dt <- data.table(
  truth = truth[lightgbm_misclassified_idx],
  lightgbm_pred = lightgbm_response[lightgbm_misclassified_idx],
  lightgbm_confidence = lightgbm_confidence[lightgbm_misclassified_idx],
  ranger_correct = ranger_response[lightgbm_misclassified_idx] == truth[lightgbm_misclassified_idx]
)
lightgbm_rescued_by_ranger_rate <- mean(lightgbm_error_dt$ranger_correct)

fwrite(error_dt, error_analysis_results_path)

cat("=== Ranger-Fehler: Sicherheit vs. LightGBM/LDA-Vergleich (Eval-Split,", nrow(error_dt), "von", length(truth), "Zeilen falsch) ===\n")
print(rescue_summary)
cat("\nLightGBM 'rettet' insgesamt", sprintf("%.1f%%", 100 * overall_rescue_rate), "von Rangers Fehlern (waere selbst richtig gelegen).\n")
cat("LDA 'rettet' insgesamt", sprintf("%.1f%%", 100 * overall_lda_rescue_rate), "von Rangers Fehlern.\n")
cat("Zum Vergleich (umgekehrt): Ranger rettet", sprintf("%.1f%%", 100 * lightgbm_rescued_by_ranger_rate), "von LightGBMs Fehlern (", length(lightgbm_misclassified_idx), "Zeilen).\n")

# --- Teil 1b: Isolierte "alle drei selbstsicher falsch"-Faelle - Ausreisser? ---
# Staerkeres Signal als ein Einzelmodell-Fehler: drei strukturell verschiedene
# Modellfamilien (Baum-Ensemble, Boosting, linear) irren sich unabhaengig auf
# derselben Zeile. Kandidaten fuer entweder Feature-Raum-Ausreisser oder
# Grenzfaelle/Label-Rauschen (siehe README-Diskussion).
hard_case_idx <- which(
  ranger_response != truth & lightgbm_response != truth & lda_response != truth &
    ranger_confidence >= error_analysis_uncertainty_threshold
)
same_wrong_class <- ranger_response[hard_case_idx] == lightgbm_response[hard_case_idx] &
  ranger_response[hard_case_idx] == lda_response[hard_case_idx]

cat("\n=== 'Alle drei Modelle selbstsicher falsch' (Ranger, LightGBM, LDA) ===\n")
cat(length(hard_case_idx), "von", length(misclassified_idx), "Ranger-Fehlern sind auch fuer LightGBM UND LDA falsch, bei Ranger-Konfidenz >=", error_analysis_uncertainty_threshold, ".\n")
cat(sum(same_wrong_class), "von", length(hard_case_idx), "davon sagen sogar dieselbe falsche Klasse voraus.\n")

correct_all_idx <- which(ranger_response == truth & lightgbm_response == truth & lda_response == truth)
correct_idx <- which(ranger_response == truth)
low_confidence_idx <- which(ranger_confidence < error_analysis_uncertainty_threshold)
interesting_idx <- union(misclassified_idx, low_confidence_idx)

indices <- list(
  misclassified_idx = misclassified_idx,
  hard_case_idx = hard_case_idx,
  correct_all_idx = correct_all_idx,
  correct_idx = correct_idx,
  low_confidence_idx = low_confidence_idx,
  interesting_idx = interesting_idx
)
saveRDS(indices, error_analysis_indices_path)

cat("\nGespeichert:\n")
cat("Fehler-Details:", error_analysis_results_path, "\n")
cat("Indizes       :", error_analysis_indices_path, "\n")
