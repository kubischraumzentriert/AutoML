rm(list = ls())

# =====================================================================
# outer_workflow_evaluation_v2_fair_baselines.R -- Benchmark-Protokoll
# Version 2 (P1 "faire Baselines", 2026-08-29-Bewertung): erweitert
# Protokoll v1 (outer_workflow_evaluation_template.R) um 2 GETUNTE
# Baseline-Arme + einen daraus abgeleiteten "Best Single Tuned Model"-
# Arm - Reaktion auf den Kritikpunkt "Default-Hyperparameter zu
# schwache Baseline fuer ein Research-Paper".
# =====================================================================
# Aenderungen ggue. v1 (siehe docs/research/BENCHMARK_PROTOCOL.md fuer die volle
# v1-Spezifikation, hier NUR die Differenz):
# 1. NEU: `tuned_ranger` - `AutoTuner` (mlr3tuning) mit Random-Search-
#    Budget `tuned_baseline_evals` (fest = 15, siehe unten), Inner-
#    Resampling = Holdout(0.75) INNERHALB des Outer-Train (der
#    AutoTuner tuned NUR auf diesem Split, das finale Modell wird intern
#    automatisch auf dem VOLLEN Outer-Train nachtrainiert - Outer-Test
#    bleibt unberuehrt).
# 2. NEU: `tuned_lightgbm` - analog, MBO-Tuner (mehr interagierende
#    Hyperparameter als Ranger, siehe 100_lightgbm_tuning.R), gleiches
#    Budget.
# 3. NEU: `best_single_tuned_model` - KEIN eigenes Training - waehlt
#    zwischen `tuned_ranger`/`tuned_lightgbm` anhand ihres INNEREN
#    Tuning-Validierungswerts (NICHT Outer-Test!) und uebernimmt dessen
#    bereits berechneten Outer-Test-Score. Reprsentiert "was, wenn man
#    einfach nur das beste einzelne getunte Modell genommen haette,
#    ohne Klassengewichtung/Multiplier".
# 4. `ranger_default`/`lightgbm_default`/`workflow_ranger` UNVERAENDERT
#    aus v1 uebernommen.
#
# Compute-Budget (dokumentiert, wie vom Plan gefordert): pro Outer-Fold
# und Datensatz kommen 2 zusaetzliche AutoTuner-Laeufe mit je 15
# Evaluationen dazu (15x Ranger-Fit auf dem Inner-Train + 1
# Refit auf vollem Outer-Train; 15x LightGBM-Fit + 1 Refit) - das
# Random-Search-Budget wurde bewusst KLEINER als 100_lightgbm_tuning.R's
# volles Template-Default (25 MBO-Evals) gewaehlt, weil dieser Arm 3x pro
# Datensatz (3 Outer Folds) x 6 Datensaetze laeuft, nicht einmalig.

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

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_full <- readRDS(task_train_small_path)
task_full <- enable_class_stratification(task_full)
class_names <- task_full$class_names
tuning_measure_id <- baseline_measure_ids[1]
tuning_measure <- msr(tuning_measure_id)
threshold_independent <- is_threshold_independent_metric(tuning_measure_id)
lightgbm_default_iterations <- if (exists("lightgbm_tuning_final_iterations")) lightgbm_tuning_final_iterations else 200

use_multiplier_tuning <- has_multiplier_tuning && !threshold_independent
tuned_baseline_evals <- 15 # Compute-Budget, siehe Kopfkommentar

cat(sprintf(
  "Projekt: %s | Primaermetrik: %s | Multiplier-Tuning: %s | Tuning-Budget/Arm: %d Evals\n",
  basename(project_dir), tuning_measure_id, use_multiplier_tuning, tuned_baseline_evals
))

n_outer_folds <- 3
inner_split_ratio <- 0.75

make_imputed_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}

score_prediction <- function(pred) pred$score(tuning_measure)

# --- Arm 1+2: Default Ranger/LightGBM (unveraendert aus v1) -------------
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

# --- Arm 3: Tuned Ranger (NEU in v2) -------------------------------------
run_tuned_ranger <- function(outer_train, outer_test) {
  base_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  search_space <- ps(
    classif.ranger.mtry.ratio = p_dbl(0.1, 1),
    classif.ranger.min.node.size = p_int(1, 20),
    classif.ranger.sample.fraction = p_dbl(0.5, 1)
  )
  at <- auto_tuner(
    tuner = mlr3tuning::tnr("random_search"), learner = base_learner, # explizit qualifiziert, siehe P1.1-Namenskollisionsfund (mlr3measures::tnr())
    resampling = rsmp("holdout", ratio = inner_split_ratio),
    measure = tuning_measure, search_space = search_space,
    terminator = trm("evals", n_evals = tuned_baseline_evals)
  )
  at$train(outer_train)
  inner_score <- at$tuning_result[[tuning_measure_id]]
  list(score = score_prediction(at$predict(outer_test)), inner_score = inner_score)
}

# --- Arm 4: Tuned LightGBM (NEU in v2) -----------------------------------
run_tuned_lightgbm <- function(outer_train, outer_test) {
  base_learner <- make_imputed_learner(
    lrn("classif.lightgbm", num_iterations = 100, bagging_freq = 1, predict_type = "prob")
  )
  search_space <- ps(
    classif.lightgbm.learning_rate = p_dbl(0.01, 0.3),
    classif.lightgbm.num_leaves = p_int(15, 255),
    classif.lightgbm.min_data_in_leaf = p_int(5, 100),
    classif.lightgbm.feature_fraction = p_dbl(0.5, 1.0),
    classif.lightgbm.bagging_fraction = p_dbl(0.5, 1.0)
  )
  at <- auto_tuner(
    tuner = mlr3tuning::tnr("mbo"), learner = base_learner, # explizit qualifiziert, siehe P1.1-Namenskollisionsfund (mlr3measures::tnr())
    resampling = rsmp("holdout", ratio = inner_split_ratio),
    measure = tuning_measure, search_space = search_space,
    terminator = trm("evals", n_evals = tuned_baseline_evals)
  )
  at$train(outer_train)
  inner_score <- at$tuning_result[[tuning_measure_id]]
  list(score = score_prediction(at$predict(outer_test)), inner_score = inner_score)
}

# --- Arm 5: der reale Projekt-Workflow (unveraendert aus v1) -------------
run_workflow_ranger <- function(outer_train, outer_test) {
  weighted_outer_train <- add_balanced_class_weights(outer_train, class_weight_power)
  if (use_multiplier_tuning) {
    inner_ids <- partition(outer_train, ratio = inner_split_ratio)
    inner_train_task <- weighted_outer_train$clone(deep = TRUE)$filter(inner_ids$train)
    inner_tune_task <- weighted_outer_train$clone(deep = TRUE)$filter(inner_ids$test)
    inner_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
    inner_learner$train(inner_train_task)
    inner_pred <- inner_learner$predict(inner_tune_task)
    mult <- tune_class_multipliers(inner_pred$prob, inner_pred$truth, classes = class_names)
    final_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
    final_learner$train(weighted_outer_train)
    test_pred <- final_learner$predict(outer_test)
    response_adj <- apply_class_multipliers(test_pred$prob, mult$multipliers, classes = class_names)
    adjusted_pred <- PredictionClassif$new(
      row_ids = test_pred$row_ids, truth = test_pred$truth, response = response_adj, prob = test_pred$prob
    )
    score_prediction(adjusted_pred)
  } else {
    final_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
    final_learner$train(weighted_outer_train)
    score_prediction(final_learner$predict(outer_test))
  }
}

# --- Outer-CV-Schleife ----------------------------------------------------
outer_resampling <- rsmp("cv", folds = n_outer_folds)
outer_resampling$instantiate(task_full) # gleicher Seed -> identische Folds wie Protokoll v1

results <- data.table(outer_fold = integer(0), arm = character(0), score = numeric(0), runtime_sec = numeric(0))

for (fold in seq_len(n_outer_folds)) {
  train_ids <- outer_resampling$train_set(fold)
  test_ids <- outer_resampling$test_set(fold)
  outer_train <- task_full$clone(deep = TRUE)$filter(train_ids)
  outer_test <- task_full$clone(deep = TRUE)$filter(test_ids)

  cat(sprintf("\n=== Outer Fold %d/%d (Train n=%d, Test n=%d) ===\n", fold, n_outer_folds, outer_train$nrow, outer_test$nrow))

  t0 <- Sys.time()
  s_rd <- run_ranger_default(outer_train, outer_test)
  results <- rbind(results, data.table(outer_fold = fold, arm = "ranger_default", score = s_rd, runtime_sec = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  cat(sprintf("  ranger_default        %s = %.4f\n", tuning_measure_id, s_rd))

  t0 <- Sys.time()
  s_ld <- run_lightgbm_default(outer_train, outer_test)
  results <- rbind(results, data.table(outer_fold = fold, arm = "lightgbm_default", score = s_ld, runtime_sec = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  cat(sprintf("  lightgbm_default      %s = %.4f\n", tuning_measure_id, s_ld))

  t0 <- Sys.time()
  r_tr <- run_tuned_ranger(outer_train, outer_test)
  results <- rbind(results, data.table(outer_fold = fold, arm = "tuned_ranger", score = r_tr$score, runtime_sec = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  cat(sprintf("  tuned_ranger          %s = %.4f  (inner: %.4f)\n", tuning_measure_id, r_tr$score, r_tr$inner_score))

  t0 <- Sys.time()
  r_tl <- run_tuned_lightgbm(outer_train, outer_test)
  results <- rbind(results, data.table(outer_fold = fold, arm = "tuned_lightgbm", score = r_tl$score, runtime_sec = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  cat(sprintf("  tuned_lightgbm        %s = %.4f  (inner: %.4f)\n", tuning_measure_id, r_tl$score, r_tl$inner_score))

  # Best Single Tuned Model: Auswahl nach INNEREM Tuning-Score, NICHT nach Outer-Test.
  best_is_ranger <- r_tr$inner_score >= r_tl$inner_score
  s_best <- if (best_is_ranger) r_tr$score else r_tl$score
  results <- rbind(results, data.table(outer_fold = fold, arm = "best_single_tuned_model", score = s_best, runtime_sec = NA_real_))
  cat(sprintf("  best_single_tuned     %s = %.4f  (gewaehlt: %s, nach Inner-Score)\n", tuning_measure_id, s_best, if (best_is_ranger) "ranger" else "lightgbm"))

  t0 <- Sys.time()
  s_wf <- run_workflow_ranger(outer_train, outer_test)
  results <- rbind(results, data.table(outer_fold = fold, arm = "workflow_ranger", score = s_wf, runtime_sec = as.numeric(difftime(Sys.time(), t0, units = "secs"))))
  cat(sprintf("  workflow_ranger       %s = %.4f\n", tuning_measure_id, s_wf))
}

direction_max <- !(tuning_measure_id %in% c("classif.logloss", "classif.ce", "classif.bbrier", "classif.mbrier"))
summary_dt <- results[, .(
  mean_score = mean(score), sd_score = sd(score),
  worst_fold_score = if (direction_max) min(score) else max(score),
  mean_runtime_sec = mean(runtime_sec, na.rm = TRUE)
), by = arm][order(if (direction_max) -mean_score else mean_score)]

cat("\n=== Protokoll v2 (faire Baselines): Zusammenfassung ueber", n_outer_folds, "Outer Folds (Metrik:", tuning_measure_id, ") ===\n")
print(summary_dt)

fwrite(results, file.path(artifact_dir, "outer_workflow_evaluation_v2_results.csv"))
fwrite(summary_dt, file.path(artifact_dir, "outer_workflow_evaluation_v2_summary.csv"))
cat("\nErgebnisse gespeichert unter:", artifact_dir, "\n")
