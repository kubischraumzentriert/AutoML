rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3measures)
})

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))
source(file.path(project_dir, "class_multiplier_tuning.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)
warn_if_threshold_step_low_value("130_threshold_tuning.R", "Post-hoc-Schwellenwert-Tuning")

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_weighted <- add_balanced_class_weights(task_train_small, class_weight_power)
classes <- task_train_small$class_names

# Stratifizierter 3-Wege-Split: Train (fitten), Tune (Gewichte suchen), Eval
# (final auswerten) - damit das Gewicht-Tuning nicht auf denselben Daten
# passiert, die auch fuer die Bewertung genutzt werden.
target_dt <- data.table(
  row_id = task_train_small$row_ids,
  class = task_train_small$data(cols = target_col)[[target_col]]
)

train_ids <- integer(0)
tune_ids <- integer(0)
eval_ids <- integer(0)

for (cl in classes) {
  ids <- sample(target_dt[class == cl, row_id])
  n <- length(ids)
  n_train <- floor(n * threshold_tuning_train_ratio)
  n_tune <- floor(n * threshold_tuning_tune_ratio)
  train_ids <- c(train_ids, ids[seq_len(n_train)])
  tune_ids <- c(tune_ids, ids[(n_train + 1):(n_train + n_tune)])
  eval_ids <- c(eval_ids, ids[(n_train + n_tune + 1):n])
}

# Klassen-Multiplikator-Suche (argmax(prob * multiplier), BAcc-maximierend)
# liegt jetzt im wiederverwendbaren Modul class_multiplier_tuning.R:
# tune_class_multipliers() nutzt das Grid (threshold_tuning_weight_grid) als
# robusten STARTPUNKT und verfeinert kontinuierlich (Nelder-Mead) - das Grid
# lief bei stark unbalancierten Zielen frueher in seine Obergrenze (6/6).

evaluate_variant <- function(label, task_for_training) {
  learner <- lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations)
  learner$predict_type <- "prob"
  learner$train(task_for_training, row_ids = train_ids)

  pred_tune <- learner$predict(task_for_training, row_ids = tune_ids)
  pred_eval <- learner$predict(task_for_training, row_ids = eval_ids)

  probs_tune <- pred_tune$prob[, classes, drop = FALSE]
  probs_eval <- pred_eval$prob[, classes, drop = FALSE]
  truth_eval <- factor(as.character(pred_eval$truth), levels = classes)

  plain_bacc <- bacc(truth_eval, pred_eval$response)
  plain_mcc <- mcc(truth_eval, pred_eval$response)

  # Multiplikatoren NUR auf dem Tune-Split suchen, auf dem Eval-Split anwenden.
  # Prior-Korrektur (1/prior) ist tuning-frei, geschlossene Form; Grid und
  # kontinuierlich zum Vergleich (kontinuierlich wird u.a. von 1/prior geseedet).
  tune_res <- tune_class_multipliers(probs_tune, pred_tune$truth, classes,
                                     grid = threshold_tuning_weight_grid)
  prior_pred_eval <- apply_class_multipliers(probs_eval, tune_res$prior_multipliers, classes)
  grid_pred_eval <- apply_class_multipliers(probs_eval, tune_res$grid_multipliers, classes)
  cont_pred_eval <- apply_class_multipliers(probs_eval, tune_res$multipliers, classes)

  data.table(
    variante = label,
    bacc_plain = plain_bacc,
    mcc_plain = plain_mcc,
    bacc_prior = bacc(truth_eval, prior_pred_eval),
    bacc_grid = bacc(truth_eval, grid_pred_eval),
    bacc_tuned = bacc(truth_eval, cont_pred_eval),
    mcc_tuned = mcc(truth_eval, cont_pred_eval),
    gewichte = paste(sprintf("%s=%.2f", names(tune_res$multipliers), tune_res$multipliers), collapse = ", ")
  )
}

results <- rbindlist(list(
  evaluate_variant("LightGBM ungewichtet", task_train_small),
  evaluate_variant("LightGBM power=1 (final)", task_weighted)
))

fwrite(results, threshold_tuning_results_path)

# --- Optional: nested/gepooltes per-Fold-Tuning (siehe TARGETS.md) ---------
# Default AUS (threshold_tuning_nested in 000_config.R) - laeuft nur, wenn
# ein Projekt es explizit aktiviert, kein Eingriff in die obigen Ergebnisse.
if (isTRUE(threshold_tuning_nested)) {
  cat("\n=== Nested/gepooltes per-Fold-Multiplikator-Tuning (", threshold_tuning_nested_folds, "-fach CV) ===\n", sep = "")
  learner_nested <- lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations)
  learner_nested$predict_type <- "prob"

  nested_res <- nested_cv_class_multiplier_tuning(
    task_train_small, learner_nested,
    folds = threshold_tuning_nested_folds, classes = classes,
    grid = threshold_tuning_weight_grid, seed = seed
  )

  print(nested_res$fold_info)
  cat(sprintf(
    "\nEhrliche gepoolte BAcc-Schaetzung (nested, kein Datenleck zwischen Suche/Bewertung): %.4f\n",
    nested_res$nested_metric
  ))
  cat(sprintf(
    "Zum Vergleich, 3-Wege-Split oben (LightGBM ungewichtet, kontinuierlich getuned): %.4f\n",
    results$bacc_tuned[1]
  ))
  cat("Finale Deployment-Multiplikatoren (auf allen OOF gesucht):\n")
  cat(paste(sprintf("%s=%.2f", names(nested_res$final_multipliers), nested_res$final_multipliers), collapse = ", "), "\n")

  fwrite(nested_res$fold_info, threshold_tuning_nested_results_path)
  cat("Gespeichert:", threshold_tuning_nested_results_path, "\n")
}

cat("=== Multiklassen-Schwellenwert-Tuning: plain vs. 1/prior vs. Grid vs. kontinuierlich ===\n")
print(results)
cat(sprintf("\n1/prior vs. Grid (BAcc): %+.4f / %+.4f  |  kontinuierlich vs. 1/prior: %+.4f / %+.4f\n",
            results$bacc_prior[1] - results$bacc_grid[1], results$bacc_prior[2] - results$bacc_grid[2],
            results$bacc_tuned[1] - results$bacc_prior[1], results$bacc_tuned[2] - results$bacc_prior[2]))
cat("Hinweis: 1/prior ist tuning-frei (geschlossene Form) und nicht mit Trainings-",
    "Klassengewichtung zu stapeln (Ueberkorrektur).\n", sep = "")
cat("\nGespeichert:", threshold_tuning_results_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
# Kein run_timed_benchmark()-Ergebnis (custom Train/Tune/Eval-Split statt CV/
# Holdout), daher manuelles Logging statt db_log_timed_benchmark(). Pro
# Variante (ungewichtet/power) werden vier model_configs angelegt - "plain"
# (argmax(prob)), "prior_correction" (1/prior, geschlossene Form), "tuned_grid"
# (Grid-Multiplikatoren) und "tuned_continuous" (kontinuierlich verfeinert) -
# damit alle vier unabhaengig abfragbar sind.
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "130_threshold_tuning.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Schwellenwert-Tuning: argmax(prob) vs. argmax(prob * Klassengewicht)")
db_log_run_config(db_con, db_run_id, list(
  threshold_tuning_train_ratio = threshold_tuning_train_ratio,
  threshold_tuning_tune_ratio = threshold_tuning_tune_ratio,
  lightgbm_tuning_final_iterations = lightgbm_tuning_final_iterations,
  class_weight_power = class_weight_power
))

db_rsmp_id <- db_create_resampling(
  db_con, db_run_id, strategy = "custom_split",
  ratio = threshold_tuning_train_ratio, seed = seed
)

variant_class_weight_power <- c(0, class_weight_power)
for (i in seq_len(nrow(results))) {
  power <- variant_class_weight_power[i]

  mconf_plain <- db_create_model_config(
    db_con, db_run_id,
    task_type = "classif", algorithm = "lightgbm", feature_set = "raw",
    preprocessing = "none", class_weight_power = power, task_id = task_train_small$id,
    hyperparams = list(num_iterations = lightgbm_tuning_final_iterations, threshold_strategy = "plain")
  )
  db_log_metric_result(db_con, mconf_plain, db_rsmp_id, "classif.bacc", results$bacc_plain[i])
  db_log_metric_result(db_con, mconf_plain, db_rsmp_id, "classif.mcc", results$mcc_plain[i])

  mconf_prior <- db_create_model_config(
    db_con, db_run_id,
    task_type = "classif", algorithm = "lightgbm", feature_set = "raw",
    preprocessing = "none", class_weight_power = power, task_id = task_train_small$id,
    hyperparams = list(num_iterations = lightgbm_tuning_final_iterations,
                       threshold_strategy = "prior_correction")
  )
  db_log_metric_result(db_con, mconf_prior, db_rsmp_id, "classif.bacc", results$bacc_prior[i])

  mconf_grid <- db_create_model_config(
    db_con, db_run_id,
    task_type = "classif", algorithm = "lightgbm", feature_set = "raw",
    preprocessing = "none", class_weight_power = power, task_id = task_train_small$id,
    hyperparams = list(num_iterations = lightgbm_tuning_final_iterations,
                       threshold_strategy = "tuned_grid")
  )
  db_log_metric_result(db_con, mconf_grid, db_rsmp_id, "classif.bacc", results$bacc_grid[i])

  mconf_tuned <- db_create_model_config(
    db_con, db_run_id,
    task_type = "classif", algorithm = "lightgbm", feature_set = "raw",
    preprocessing = "none", class_weight_power = power, task_id = task_train_small$id,
    hyperparams = list(
      num_iterations = lightgbm_tuning_final_iterations,
      threshold_strategy = "tuned_continuous",
      tuned_weights = results$gewichte[i]
    )
  )
  db_log_metric_result(db_con, mconf_tuned, db_rsmp_id, "classif.bacc", results$bacc_tuned[i])
  db_log_metric_result(db_con, mconf_tuned, db_rsmp_id, "classif.mcc", results$mcc_tuned[i])
}

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
