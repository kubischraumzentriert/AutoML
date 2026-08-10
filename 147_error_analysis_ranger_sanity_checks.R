rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3measures)
})

source("000_config.R")
source(file.path(project_dir, "sanity_checks.R"))

# Modell-Sanity-Checks (siehe WorkflowDescription.md Phase 11, sanity_checks.R,
# TARGETS.md): Perturbation-/Invarianz-/Directional-Expectation-Tests nach
# Huyen (2022) Kap. 6. Baut auf dem `147_error_analysis_ranger_models.R`-
# Artefakt auf, kein erneutes Training - loses Kopplungsmuster wie die
# uebrigen 147-Skripte.
if (!length(perturbation_test_cols) && !length(invariance_test_cols) && !length(directional_expectation_specs)) {
  cat("Keine perturbation_test_cols/invariance_test_cols/directional_expectation_specs in 000_config.R gesetzt. Sanity-Checks uebersprungen.\n")
  quit(save = "no", status = 0)
}
if (!file.exists(error_analysis_models_path)) {
  stop("Fehleranalyse-Modelle fehlen. Erst 147_error_analysis_ranger_models.R ausfuehren.")
}

models <- readRDS(error_analysis_models_path)
target_col_name <- models$target_col_name
feature_cols <- models$feature_cols
learner_ranger <- models$learner_ranger

# Referenz-Task nur fuer Spalten-/Level-Metadaten bei predict_newdata() -
# kein erneutes Training (learner_ranger ist bereits trainiert).
train_task <- as_task_classif(
  models$train_imputed[, c(target_col_name, feature_cols), with = FALSE],
  target = target_col_name, id = "sanity_check_train"
)
eval_dt <- as.data.frame(models$eval_imputed)
truth <- models$truth

predict_response <- function(nd) learner_ranger$predict_newdata(nd, task = train_task)$response
predict_prob <- function(nd, class_name) learner_ranger$predict_newdata(nd, task = train_task)$prob[, class_name]

results <- list()

# --- 1) Perturbation -------------------------------------------------------
if (length(perturbation_test_cols)) {
  missing_cols <- setdiff(perturbation_test_cols, names(eval_dt))
  if (length(missing_cols)) stop("perturbation_test_cols nicht im Eval-Set: ", paste(missing_cols, collapse = ", "))

  res <- run_perturbation_test(predict_response, eval_dt, perturbation_test_cols, truth,
                                mlr3measures::bacc, noise_sd_frac = perturbation_noise_sd_frac)
  warn <- res$drop > perturbation_warn_drop
  cat(sprintf("=== Perturbation-Test (%s, %.0f%% SD-Rauschen) ===\n",
              paste(perturbation_test_cols, collapse = ", "), perturbation_noise_sd_frac * 100))
  cat(sprintf("baseline BAcc=%.4f  perturbed BAcc=%.4f (sd=%.4f)  drop=%.4f%s\n\n",
              res$baseline_metric, res$perturbed_metric_mean, res$perturbed_metric_sd, res$drop,
              if (warn) sprintf(" -- WARNUNG: Drop > %.2f", perturbation_warn_drop) else ""))
  results$perturbation <- data.table(
    test = "perturbation", feature = paste(perturbation_test_cols, collapse = "+"),
    value = res$drop, metric = "bacc_drop", warn = warn
  )
}

# --- 2) Invarianz ------------------------------------------------------------
if (length(invariance_test_cols)) {
  missing_cols <- setdiff(invariance_test_cols, names(eval_dt))
  if (length(missing_cols)) stop("invariance_test_cols nicht im Eval-Set: ", paste(missing_cols, collapse = ", "))

  results$invariance <- rbindlist(lapply(invariance_test_cols, function(col) {
    res <- run_invariance_test(predict_response, eval_dt, col)
    warn <- res$flip_rate_mean > invariance_warn_flip_rate
    cat(sprintf("=== Invarianz-Test (Spalte '%s' gemischt) ===\n", col))
    cat(sprintf("flip_rate=%.4f (sd=%.4f)%s\n\n", res$flip_rate_mean, res$flip_rate_sd,
                if (warn) sprintf(" -- WARNUNG: flip_rate > %.2f", invariance_warn_flip_rate) else ""))
    data.table(test = "invariance", feature = col, value = res$flip_rate_mean, metric = "flip_rate", warn = warn)
  }))
}

# --- 3) Directional Expectation ----------------------------------------------
if (length(directional_expectation_specs)) {
  results$directional <- rbindlist(lapply(directional_expectation_specs, function(spec) {
    if (!spec$feature %in% names(eval_dt)) stop("directional_expectation_specs: Feature nicht im Eval-Set: ", spec$feature)

    shift_fn <- if (identical(spec$type, "ordinal")) {
      build_ordinal_shift_fn(spec$level_order)
    } else {
      delta <- spec$delta
      function(x) x + delta
    }
    predict_prob_fn <- function(nd) predict_prob(nd, spec$favorable_class)

    eval_subset <- eval_dt[!is.na(eval_dt[[spec$feature]]) & eval_dt[[spec$feature]] != "", ]
    res <- run_directional_test(predict_prob_fn, eval_subset, spec$feature, shift_fn, direction = spec$direction)
    effect_share <- mean(res$violation & abs(res$diff) > directional_effect_threshold)

    warn <- res$violation_rate > directional_warn_violation_rate || effect_share > directional_warn_effect_share
    cat(sprintf("=== Directional-Expectation-Test (%s, direction=%s, favorable_class=%s, n=%d) ===\n",
                spec$feature, spec$direction, spec$favorable_class, nrow(eval_subset)))
    cat(sprintf("violation_rate=%.4f  mean_diff=%.4f  share mit |diff|>%.2f=%.4f%s\n\n",
                res$violation_rate, res$mean_diff, directional_effect_threshold, effect_share,
                if (warn) " -- WARNUNG" else ""))
    data.table(test = "directional", feature = spec$feature, value = res$violation_rate,
               metric = "violation_rate", effect_share = effect_share, warn = warn)
  }), fill = TRUE)
}

all_results <- rbindlist(results, fill = TRUE)
fwrite(all_results, sanity_check_results_path)

flagged <- all_results[warn == TRUE]
if (nrow(flagged)) {
  cat(sprintf("=== WARNUNG: %d Sanity-Check(s) ueber der Schwelle ===\n", nrow(flagged)))
  print(flagged)
} else {
  cat("Keine Sanity-Check-Warnung ueber der Schwelle - unauffaellig.\n")
}
cat("\nGespeichert:", sanity_check_results_path, "\n")
