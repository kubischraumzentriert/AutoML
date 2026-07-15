rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(ranger)
  library(kernelshap)
})

source("000_config.R")

# Vierter Baustein der Fehleranalyse: welche Features treiben Ranger in die
# falsche Klasse? Laedt Modelle+Indizes-Artefakte, kein erneutes Training -
# nur diesen einen (teuren) Schritt isoliert laufen lassen, ohne Training/
# Confidence-Analyse/Isolation Forest jedes Mal zu wiederholen.
if (!file.exists(error_analysis_indices_path)) {
  source(file.path(project_dir, "147_error_analysis_ranger_confidence.R"))
}
models <- readRDS(error_analysis_models_path)
indices <- readRDS(error_analysis_indices_path)

feature_cols <- models$feature_cols
train_features_only <- models$train_imputed[, ..feature_cols]
eval_features_only <- models$eval_imputed[, ..feature_cols]
ranger_response <- models$ranger_response

misclassified_idx <- indices$misclassified_idx
correct_idx <- indices$correct_idx

pred_fun <- function(model, newdata) {
  predict(model, data = newdata)$predictions
}

ranger_fit <- models$learner_ranger$model

set.seed(seed)
bg_idx <- sample(nrow(train_features_only), min(error_analysis_shap_background_size, nrow(train_features_only)))
bg_X <- train_features_only[bg_idx]

sample_shap_for <- function(idx_pool, pred_classes, label) {
  n_sample <- min(error_analysis_shap_sample_size, length(idx_pool))
  sampled_idx <- sample(idx_pool, n_sample)
  X <- eval_features_only[sampled_idx]

  shap_result <- kernelshap(ranger_fit, X = X, bg_X = bg_X, pred_fun = pred_fun, verbose = FALSE)

  sampled_classes <- as.character(pred_classes[sampled_idx])
  shap_for_class <- do.call(rbind, lapply(seq_along(sampled_idx), function(i) {
    shap_result$S[[sampled_classes[i]]][i, ]
  }))
  colnames(shap_for_class) <- feature_cols

  data.table(
    feature = feature_cols,
    mean_abs_shap = colMeans(abs(shap_for_class)),
    mean_shap = colMeans(shap_for_class),
    gruppe = label,
    n = n_sample
  )
}

cat("Berechne KernelSHAP fuer", min(error_analysis_shap_sample_size, length(misclassified_idx)), "falsch klassifizierte Zeilen (Ranger, Ziel: vorhergesagte falsche Klasse) ...\n")
shap_errors <- sample_shap_for(misclassified_idx, ranger_response, "falsch klassifiziert")

cat("Berechne KernelSHAP fuer", min(error_analysis_shap_sample_size, length(correct_idx)), "richtig klassifizierte Zeilen (Baseline-Vergleich) ...\n")
shap_correct <- sample_shap_for(correct_idx, ranger_response, "richtig klassifiziert")

shap_comparison <- rbindlist(list(shap_errors, shap_correct))
shap_wide <- dcast(shap_comparison, feature ~ gruppe, value.var = "mean_abs_shap")
shap_wide[, error_ratio := round(`falsch klassifiziert` / `richtig klassifiziert`, 3)]
setorder(shap_wide, -error_ratio)

fwrite(shap_comparison, error_analysis_shap_importance_path)

cat("\n=== Mean(|SHAP|) je Feature: falsch vs. richtig klassifiziert (Ranger, Verhaeltnis > 1 = ueberproportional an Fehlern beteiligt) ===\n")
print(shap_wide)
cat("\nGespeichert:", error_analysis_shap_importance_path, "\n")
