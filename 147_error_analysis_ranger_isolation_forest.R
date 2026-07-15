rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(isotree)
})

source("000_config.R")

# Dritter Baustein der Fehleranalyse: sind die "alle Modelle einig falsch"-
# Faelle (hard_case_idx, aus 147_..._confidence.R) Ausreisser im Feature-
# Raum oder eher Grenzfaelle/Label-Rauschen? Laedt Modelle+Indizes-Artefakte,
# kein erneutes Training.
if (!file.exists(error_analysis_indices_path)) {
  source(file.path(project_dir, "147_error_analysis_ranger_confidence.R"))
}
models <- readRDS(error_analysis_models_path)
indices <- readRDS(error_analysis_indices_path)

# data.tables ..x-Syntax braucht einen einfachen lokalen Variablennamen, kein
# verschachteltes $-Zugriff wie ..models$feature_cols - daher erst extrahieren.
feature_cols <- models$feature_cols
train_features_only <- models$train_imputed[, ..feature_cols]
eval_features_only <- models$eval_imputed[, ..feature_cols]

hard_case_idx <- indices$hard_case_idx
correct_all_idx <- indices$correct_all_idx

if (length(hard_case_idx) >= 5) {
  iso_model <- isolation.forest(train_features_only, ntrees = 500, nthreads = 1, seed = seed)

  hard_case_scores <- predict(iso_model, eval_features_only[hard_case_idx])
  set.seed(seed)
  baseline_idx <- sample(correct_all_idx, min(5 * length(hard_case_idx), length(correct_all_idx)))
  baseline_scores <- predict(iso_model, eval_features_only[baseline_idx])

  outlier_test <- wilcox.test(hard_case_scores, baseline_scores)

  cat("=== Isolation-Forest-Anomalie-Score (0.5 = normal, -> 1 = Ausreisser) ===\n")
  cat("  'Alle drei selbstsicher falsch' (n=", length(hard_case_idx), "): Median =", round(median(hard_case_scores), 4), ", Mean =", round(mean(hard_case_scores), 4), "\n")
  cat("  Baseline: alle drei richtig  (n=", length(baseline_idx), "): Median =", round(median(baseline_scores), 4), ", Mean =", round(mean(baseline_scores), 4), "\n")
  cat("  Wilcoxon-Test p-Wert:", signif(outlier_test$p.value, 4), "\n")
} else {
  cat("Zu wenige Faelle (<5) fuer eine belastbare Isolation-Forest-Auswertung.\n")
}
