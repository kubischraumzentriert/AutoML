rm(list = ls())

# =====================================================================
# outer_workflow_evaluation_v3_level2.R -- Benchmark-Protokoll Version 3
# (P2 "Level-2 Outer Evaluation prototypisieren", 2026-08-29-Bewertung,
# siehe docs/research/EVALUATION_LEVELS.md): erste Level-2-Umsetzung - Modellwahl UND
# Hyperparameter-Tuning laufen jetzt INNERHALB jedes Outer-Train-Splits,
# nicht nur ein fester Arm-Katalog wie in v1/v2.
# =====================================================================
# Ablauf je Outer-Fold (Level 2, siehe docs/research/EVALUATION_LEVELS.md):
#   1. Inner-Split (75/25) DES Outer-Train (NICHT des Outer-Test).
#   2. Ranger UND LightGBM je per AutoTuner AUF DEM GEWICHTETEN
#      Inner-Train getunt (kleines Budget, `tuned_baseline_evals`).
#   3. Beide getunten Modelle liefern Wahrscheinlichkeiten auf dem
#      Inner-Tune-Split -> Multiplier-Korrektur je Modell UND fuer ein
#      einfaches Wahrscheinlichkeits-Mittel beider (Mini-Ensemble).
#   4. Modellwahl: dasjenige der 3 Kandidaten (Ranger/LightGBM/Ensemble)
#      mit dem besten INNEREN (Inner-Tune-)Score gewinnt - NIE anhand
#      des Outer-Test-Scores.
#   5. Der gewaehlte Kandidat wird (mit den gefundenen Hyperparametern +
#      Multiplikatoren) auf dem VOLLEN Outer-Train final trainiert und
#      GENAU EINMAL auf Outer-Test bewertet.
#
# Baselines (`ranger_default`/`lightgbm_default`) unveraendert aus v1/v2
# als Referenzpunkt mitgefuehrt.
#
# Compute-Budget (dokumentiert): `tuned_baseline_evals = 10` je Tuner
# (kleiner als v2s 15, da hier ZWEI Tuning-Laeufe UND zwei Multiplier-
# Korrekturen pro Outer-Fold anfallen - deutlich teurer als v1/v2, siehe
# BACKLOG.md/P2-Status fuer die Kostenschaetzung).

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
  library(mlr3tuning)
  library(mlr3mbo)
  library(mlr3measures)
  library(paradox)
})
lgr::get_logger("mlr3")$set_threshold("warn")
lgr::get_logger("bbotk")$set_threshold("warn")

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))
has_multiplier_tuning <- file.exists(file.path(project_dir, "class_multiplier_tuning.R"))
if (has_multiplier_tuning) source(file.path(project_dir, "class_multiplier_tuning.R"))
stopifnot("Level-2-Skript braucht class_multiplier_tuning.R im Projektordner" = has_multiplier_tuning)

if (!exists("enable_class_stratification")) {
  enable_class_stratification <- function(task) {
    if (!inherits(task, "TaskClassif")) return(task)
    roles <- task$col_roles
    if (!all(task$target_names %in% roles$stratum)) {
      roles$stratum <- unique(c(roles$stratum, task$target_names))
      task$col_roles <- roles
    }
    task
  }
}
if (!exists("add_balanced_class_weights")) {
  add_balanced_class_weights <- function(task, power) {
    target_values <- task$data(cols = task$target_names)[[task$target_names]]
    class_counts <- table(target_values)
    base_weights <- length(target_values) / (length(class_counts) * class_counts)
    weights <- base_weights^power
    task_weighted <- task$clone(deep = TRUE)
    task_weighted$id <- paste0(task$id, "_weighted_p", power)
    task_weighted$cbind(data.table(weight = as.numeric(weights[as.character(target_values)])))
    task_weighted$set_col_roles("weight", roles = "weights_learner")
    task_weighted
  }
}
if (!exists("class_weight_power")) class_weight_power <- 1.5

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)
if (!file.exists(task_train_small_path)) source(file.path(project_dir, "020_task.R"))

task_full <- readRDS(task_train_small_path)
task_full <- enable_class_stratification(task_full)
class_names <- task_full$class_names
tuning_measure_id <- baseline_measure_ids[1]
tuning_measure <- msr(tuning_measure_id)
lightgbm_default_iterations <- if (exists("lightgbm_tuning_final_iterations")) lightgbm_tuning_final_iterations else 200
tuned_baseline_evals <- as.integer(Sys.getenv("LEVEL2_TUNING_EVALS", "10")) # Compute-Budget, siehe Kopfkommentar
# Ueberschreibbar per Umgebungsvariable LEVEL2_TUNING_EVALS (Default 10,
# identisch zum eingefrorenen Protokoll v3) - fuer den Research-Aspect
# 2026-08-30 (Tuning-Budget-Variation, siehe BACKLOG.md), OHNE das
# frozen Default-Verhalten zu aendern.

metric_fn <- function(truth, response) tuning_measure$score(
  PredictionClassif$new(row_ids = seq_along(truth), truth = truth, response = response)
)

cat(sprintf("Projekt: %s | Primaermetrik: %s | Tuning-Budget/Arm: %d Evals (Level 2)\n",
            basename(project_dir), tuning_measure_id, tuned_baseline_evals))

n_outer_folds <- 3
inner_split_ratio <- 0.75

make_imputed_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}
score_prediction <- function(pred) pred$score(tuning_measure)

run_ranger_default <- function(outer_train, outer_test) {
  learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  learner$train(outer_train)
  score_prediction(learner$predict(outer_test))
}
run_lightgbm_default <- function(outer_train, outer_test) {
  learner <- make_imputed_learner(lrn("classif.lightgbm", num_iterations = lightgbm_default_iterations, predict_type = "prob"))
  learner$train(outer_train)
  score_prediction(learner$predict(outer_test))
}

# --- Level-2-Kern: Modellwahl+Tuning+Korrektur INNERHALB des Outer-Train --
run_level2_workflow <- function(outer_train, outer_test) {
  weighted_outer_train <- add_balanced_class_weights(outer_train, class_weight_power)
  inner_ids <- partition(outer_train, ratio = inner_split_ratio)
  inner_train_task <- weighted_outer_train$clone(deep = TRUE)$filter(inner_ids$train)
  inner_tune_task <- weighted_outer_train$clone(deep = TRUE)$filter(inner_ids$test)

  # --- Ranger: tunen auf Inner-Train, Multiplier auf Inner-Tune -----------
  ranger_search_space <- ps(
    classif.ranger.mtry.ratio = p_dbl(0.1, 1),
    classif.ranger.min.node.size = p_int(1, 20),
    classif.ranger.sample.fraction = p_dbl(0.5, 1)
  )
  at_ranger <- auto_tuner(
    tuner = mlr3tuning::tnr("random_search"),
    learner = make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed)),
    resampling = rsmp("holdout", ratio = inner_split_ratio),
    measure = tuning_measure, search_space = ranger_search_space,
    terminator = trm("evals", n_evals = tuned_baseline_evals)
  )
  at_ranger$train(inner_train_task)
  pred_ranger_inner <- at_ranger$predict(inner_tune_task)
  mult_ranger <- tune_class_multipliers(pred_ranger_inner$prob, pred_ranger_inner$truth, classes = class_names, metric_fn = metric_fn)
  resp_ranger_inner <- apply_class_multipliers(pred_ranger_inner$prob, mult_ranger$multipliers, classes = class_names)
  score_ranger_inner <- metric_fn(pred_ranger_inner$truth, resp_ranger_inner)
  ranger_best_params <- at_ranger$tuning_instance$result_learner_param_vals

  # --- LightGBM: analog ------------------------------------------------
  lightgbm_search_space <- ps(
    classif.lightgbm.learning_rate = p_dbl(0.01, 0.3),
    classif.lightgbm.num_leaves = p_int(15, 255),
    classif.lightgbm.min_data_in_leaf = p_int(5, 100),
    classif.lightgbm.feature_fraction = p_dbl(0.5, 1.0),
    classif.lightgbm.bagging_fraction = p_dbl(0.5, 1.0)
  )
  at_lightgbm <- auto_tuner(
    tuner = mlr3tuning::tnr("mbo"),
    learner = make_imputed_learner(lrn("classif.lightgbm", num_iterations = 100, bagging_freq = 1, predict_type = "prob")),
    resampling = rsmp("holdout", ratio = inner_split_ratio),
    measure = tuning_measure, search_space = lightgbm_search_space,
    terminator = trm("evals", n_evals = tuned_baseline_evals)
  )
  at_lightgbm$train(inner_train_task)
  pred_lgbm_inner <- at_lightgbm$predict(inner_tune_task)
  mult_lgbm <- tune_class_multipliers(pred_lgbm_inner$prob, pred_lgbm_inner$truth, classes = class_names, metric_fn = metric_fn)
  resp_lgbm_inner <- apply_class_multipliers(pred_lgbm_inner$prob, mult_lgbm$multipliers, classes = class_names)
  score_lgbm_inner <- metric_fn(pred_lgbm_inner$truth, resp_lgbm_inner)
  lightgbm_best_params <- at_lightgbm$tuning_instance$result_learner_param_vals

  # --- Mini-Ensemble: Wahrscheinlichkeits-Mittel beider Inner-Modelle ----
  prob_ens_inner <- (pred_ranger_inner$prob + pred_lgbm_inner$prob) / 2
  mult_ens <- tune_class_multipliers(prob_ens_inner, pred_ranger_inner$truth, classes = class_names, metric_fn = metric_fn)
  resp_ens_inner <- apply_class_multipliers(prob_ens_inner, mult_ens$multipliers, classes = class_names)
  score_ens_inner <- metric_fn(pred_ranger_inner$truth, resp_ens_inner)

  # --- Modellwahl NACH INNEREM Score (nie Outer-Test) --------------------
  inner_scores <- c(ranger = score_ranger_inner, lightgbm = score_lgbm_inner, ensemble = score_ens_inner)
  chosen <- names(which.max(inner_scores))

  # --- Finale Modelle auf VOLLEM (gewichtetem) Outer-Train, Vorhersage
  # auf Outer-Test GENAU EINMAL -------------------------------------------
  final_ranger <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  final_ranger$param_set$values <- ranger_best_params
  final_ranger$train(weighted_outer_train)
  pred_ranger_outer <- final_ranger$predict(outer_test)

  final_lightgbm <- make_imputed_learner(lrn("classif.lightgbm", predict_type = "prob"))
  final_lightgbm$param_set$values <- lightgbm_best_params
  final_lightgbm$train(weighted_outer_train)
  pred_lgbm_outer <- final_lightgbm$predict(outer_test)

  if (chosen == "ranger") {
    resp <- apply_class_multipliers(pred_ranger_outer$prob, mult_ranger$multipliers, classes = class_names)
    truth <- pred_ranger_outer$truth
  } else if (chosen == "lightgbm") {
    resp <- apply_class_multipliers(pred_lgbm_outer$prob, mult_lgbm$multipliers, classes = class_names)
    truth <- pred_lgbm_outer$truth
  } else {
    prob_ens_outer <- (pred_ranger_outer$prob + pred_lgbm_outer$prob) / 2
    resp <- apply_class_multipliers(prob_ens_outer, mult_ens$multipliers, classes = class_names)
    truth <- pred_ranger_outer$truth
  }
  outer_score <- metric_fn(truth, resp)
  list(score = outer_score, chosen = chosen, inner_scores = inner_scores)
}

# --- Outer-CV-Schleife ----------------------------------------------------
outer_resampling <- rsmp("cv", folds = n_outer_folds)
outer_resampling$instantiate(task_full) # gleicher Seed -> identische Folds wie v1/v2

results <- data.table(outer_fold = integer(0), arm = character(0), score = numeric(0), runtime_sec = numeric(0))
choices <- data.table(outer_fold = integer(0), chosen = character(0), score_ranger = numeric(0), score_lightgbm = numeric(0), score_ensemble = numeric(0))

for (fold in seq_len(n_outer_folds)) {
  train_ids <- outer_resampling$train_set(fold)
  test_ids <- outer_resampling$test_set(fold)
  outer_train <- task_full$clone(deep = TRUE)$filter(train_ids)
  outer_test <- task_full$clone(deep = TRUE)$filter(test_ids)

  cat(sprintf("\n=== Outer Fold %d/%d (Train n=%d, Test n=%d) ===\n", fold, n_outer_folds, outer_train$nrow, outer_test$nrow))

  t0 <- Sys.time()
  s_rd <- run_ranger_default(outer_train, outer_test)
  results <- rbind(results, data.table(outer_fold = fold, arm = "ranger_default", score = s_rd, runtime_sec = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  cat(sprintf("  ranger_default    %s = %.4f\n", tuning_measure_id, s_rd))

  t0 <- Sys.time()
  s_ld <- run_lightgbm_default(outer_train, outer_test)
  results <- rbind(results, data.table(outer_fold = fold, arm = "lightgbm_default", score = s_ld, runtime_sec = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  cat(sprintf("  lightgbm_default  %s = %.4f\n", tuning_measure_id, s_ld))

  t0 <- Sys.time()
  r_l2 <- run_level2_workflow(outer_train, outer_test)
  results <- rbind(results, data.table(outer_fold = fold, arm = "level2_workflow", score = r_l2$score, runtime_sec = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  choices <- rbind(choices, data.table(
    outer_fold = fold, chosen = r_l2$chosen,
    score_ranger = r_l2$inner_scores[["ranger"]], score_lightgbm = r_l2$inner_scores[["lightgbm"]], score_ensemble = r_l2$inner_scores[["ensemble"]]
  ))
  cat(sprintf("  level2_workflow   %s = %.4f  (gewaehlt: %s, Inner-Scores: ranger=%.4f lightgbm=%.4f ensemble=%.4f)\n",
              tuning_measure_id, r_l2$score, r_l2$chosen, r_l2$inner_scores[["ranger"]], r_l2$inner_scores[["lightgbm"]], r_l2$inner_scores[["ensemble"]]))
}

direction_max <- !(tuning_measure_id %in% c("classif.logloss", "classif.ce", "classif.bbrier", "classif.mbrier"))
summary_dt <- results[, .(
  mean_score = mean(score), sd_score = sd(score),
  worst_fold_score = if (direction_max) min(score) else max(score),
  mean_runtime_sec = mean(runtime_sec, na.rm = TRUE)
), by = arm][order(if (direction_max) -mean_score else mean_score)]

cat("\n=== Protokoll v3 (Level 2): Zusammenfassung ueber", n_outer_folds, "Outer Folds (Metrik:", tuning_measure_id, ") ===\n")
print(summary_dt)
cat("\nModellwahl je Outer-Fold:\n")
print(choices)

fwrite(results, file.path(artifact_dir, "outer_workflow_evaluation_v3_results.csv"))
fwrite(summary_dt, file.path(artifact_dir, "outer_workflow_evaluation_v3_summary.csv"))
fwrite(choices, file.path(artifact_dir, "outer_workflow_evaluation_v3_choices.csv"))
cat("\nErgebnisse gespeichert unter:", artifact_dir, "\n")
