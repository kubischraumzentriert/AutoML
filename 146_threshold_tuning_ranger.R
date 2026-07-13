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

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)
warn_if_threshold_step_low_value("146_threshold_tuning_ranger.R", "Post-hoc-Schwellenwert-Tuning")

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_weighted <- add_balanced_class_weights(task_train_small, class_weight_power)
classes <- task_train_small$class_names

# Wiederholt 130_threshold_tuning.R fuer Ranger statt LightGBM - Ranger liefert
# Wahrscheinlichkeiten ueber Stimmenanteile der Baeume (Probability Forest,
# siehe README), nicht ueber eine Log-Loss-optimierte Likelihood wie LightGBM.
# Interessant zu pruefen, ob post-hoc-Gewichtung bei diesen "weicheren"
# Wahrscheinlichkeiten aehnlich stark greift.

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

# Sucht Klassengewichte (argmax(prob * weight)), die BAcc auf `probs`/`truth`
# maximieren. Eine Klasse bleibt bei Gewicht 1 fixiert (nur Verhaeltnisse
# zaehlen).
search_class_weights <- function(probs, truth, classes, grid) {
  best_bacc <- -Inf
  best_weights <- setNames(rep(1, length(classes)), classes)

  grid_combinations <- expand.grid(replicate(length(classes) - 1, grid, simplify = FALSE))

  for (i in seq_len(nrow(grid_combinations))) {
    weights <- setNames(c(1, as.numeric(grid_combinations[i, ])), classes)
    weighted_probs <- sweep(probs, 2, weights[colnames(probs)], `*`)
    pred <- factor(colnames(weighted_probs)[max.col(weighted_probs, ties.method = "first")], levels = classes)
    current_bacc <- bacc(truth, pred)
    if (current_bacc > best_bacc) {
      best_bacc <- current_bacc
      best_weights <- weights
    }
  }

  list(weights = best_weights, bacc = best_bacc)
}

evaluate_variant <- function(label, task_for_training) {
  learner <- lrn(
    "classif.ranger",
    num.trees = ranger_tuning_final_trees,
    respect.unordered.factors = "order",
    seed = seed
  )
  learner$predict_type <- "prob"
  learner$train(task_for_training, row_ids = train_ids)

  pred_tune <- learner$predict(task_for_training, row_ids = tune_ids)
  pred_eval <- learner$predict(task_for_training, row_ids = eval_ids)

  probs_tune <- pred_tune$prob
  probs_eval <- pred_eval$prob
  truth_tune <- pred_tune$truth
  truth_eval <- pred_eval$truth

  plain_bacc <- bacc(truth_eval, pred_eval$response)
  plain_mcc <- mcc(truth_eval, pred_eval$response)

  search_result <- search_class_weights(probs_tune, truth_tune, classes, threshold_tuning_weight_grid)

  weighted_probs_eval <- sweep(probs_eval, 2, search_result$weights[colnames(probs_eval)], `*`)
  tuned_pred_eval <- factor(colnames(weighted_probs_eval)[max.col(weighted_probs_eval, ties.method = "first")], levels = classes)
  tuned_bacc <- bacc(truth_eval, tuned_pred_eval)
  tuned_mcc <- mcc(truth_eval, tuned_pred_eval)

  data.table(
    variante = label,
    bacc_plain = plain_bacc,
    mcc_plain = plain_mcc,
    bacc_tuned = tuned_bacc,
    mcc_tuned = tuned_mcc,
    gewichte = paste(sprintf("%s=%.1f", names(search_result$weights), search_result$weights), collapse = ", ")
  )
}

results <- rbindlist(list(
  evaluate_variant("Ranger ungewichtet", task_train_small),
  evaluate_variant(sprintf("Ranger power=%s (final)", class_weight_power), task_weighted)
))

fwrite(results, threshold_tuning_ranger_results_path)

cat("=== Schwellenwert-Tuning (Ranger): argmax(prob) vs. argmax(prob * Gewicht) ===\n")
print(results)
cat("\nGespeichert:", threshold_tuning_ranger_results_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
# Gleiches Muster wie 130_threshold_tuning.R: kein run_timed_benchmark()-
# Ergebnis (custom Train/Tune/Eval-Split), daher manuelles Logging. Pro
# Variante (ungewichtet/power) werden zwei model_configs angelegt - "plain"
# (argmax(prob)) und "tuned" (argmax(prob * Gewicht)).
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "146_threshold_tuning_ranger.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Schwellenwert-Tuning fuer Ranger: argmax(prob) vs. argmax(prob * Klassengewicht)")
db_log_run_config(db_con, db_run_id, list(
  threshold_tuning_train_ratio = threshold_tuning_train_ratio,
  threshold_tuning_tune_ratio = threshold_tuning_tune_ratio,
  ranger_tuning_final_trees = ranger_tuning_final_trees,
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
    task_type = "classif", algorithm = "ranger", feature_set = "raw",
    preprocessing = "none", class_weight_power = power, task_id = task_train_small$id,
    hyperparams = list(num.trees = ranger_tuning_final_trees, threshold_strategy = "plain")
  )
  db_log_metric_result(db_con, mconf_plain, db_rsmp_id, "classif.bacc", results$bacc_plain[i])
  db_log_metric_result(db_con, mconf_plain, db_rsmp_id, "classif.mcc", results$mcc_plain[i])

  mconf_tuned <- db_create_model_config(
    db_con, db_run_id,
    task_type = "classif", algorithm = "ranger", feature_set = "raw",
    preprocessing = "none", class_weight_power = power, task_id = task_train_small$id,
    hyperparams = list(
      num.trees = ranger_tuning_final_trees,
      threshold_strategy = "tuned",
      tuned_weights = results$gewichte[i]
    )
  )
  db_log_metric_result(db_con, mconf_tuned, db_rsmp_id, "classif.bacc", results$bacc_tuned[i])
  db_log_metric_result(db_con, mconf_tuned, db_rsmp_id, "classif.mcc", results$mcc_tuned[i])
}

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
