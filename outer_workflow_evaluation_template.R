rm(list = ls())

# =====================================================================
# outer_workflow_evaluation.R -- Phase C (2026-08-28 Bewertung, Hebel 1):
# Full-Workflow Outer Evaluation, generalisierte Fassung fuer beliebige
# Projekte (nicht nur health_condition wie im urspruenglichen P1.1-
# Prototyp). 3 Outer Folds, 3 Vergleichs-Arme.
# =====================================================================
# Generalisierung ggue. dem P1.1-Original (MLR3_Classifikation/
# outer_workflow_evaluation.R):
# 1. Scoring generisch ueber `msr(tuning_measure_id)$score()` statt
#    hartkodiertem `mlr3measures::bacc()` - funktioniert fuer JEDE
#    Primaermetrik (BAcc, AUC, LogLoss, F-beta, ...), nicht nur BAcc.
# 2. Der "lightgbm_tuned"-Arm ist HIER BEWUSST WEGGELASSEN - der P1.1-
#    Prototyp zeigte dort keinen Vorteil ggue. Default-LightGBM
#    (konsistent mit der bereits dokumentierten Hyperband-/Successive-
#    Halving-Erfahrung dieses Templates), und der Arm war mit Abstand der
#    teuerste (~5 Min./Fold). Eine bereits negative Frage 6x zu wiederholen
#    haette Rechenzeit gekostet, ohne neue Information zu liefern.
# 3. Der "workflow_ranger"-Arm passt sich an, WAS im Projekt tatsaechlich
#    vorhanden ist: Multiplier-Tuning (`class_multiplier_tuning.R`) nur,
#    wenn (a) die Datei im Projekt existiert UND (b) die Primaermetrik
#    schwellenwertABHAENGIG ist (`is_threshold_independent_metric()`,
#    db_logging.R) - bei AUC/LogLoss/PRAUC ist Multiplier-Tuning
#    methodisch nicht sinnvoll (Argmax-Neugewichtung aendert nichts an
#    einer Rangfolgen-Metrik). Sonst: nur klassengewichtetes Training,
#    kein Multiplier-Schritt - entspricht der bereits in
#    docs/research/SYSTEMATIC_EVALUATION.md dokumentierten Konvention dieses Templates
#    ("Threshold-Tuning strukturell uebersprungen bei
#    schwellenwertunabhaengiger Zielmetrik").
#
# WIEDERVERWENDUNG: dies ist die Vorlage, die fuer Phase C (2026-08-28
# Bewertung) in 6 `ML_Learning`-Projektordner kopiert wurde (dort jeweils
# als `outer_workflow_evaluation.R`, mit projektspezifischen Kommentaren
# zu den unten genannten Fallbacks). Ergebnisse/Befunde: siehe
# BACKLOG.md "Naechste Bewertung 2026-08-28"/Phase C - wichtigster
# Befund: der klassengewichtete `workflow_ranger`-Arm generalisiert NUR
# bei einer zur Zielmetrik passenden Korrekturkette (Gewichtung +
# Multiplier/Threshold bei schwellenwertabhaengigen Metriken wie BAcc),
# nicht bei reiner Gewichtung ohne Korrektur (faellt bei Accuracy-/
# F-beta-primaeren Aufgaben drastisch ab, siehe CreditScoringChallenge/
# PumpItUp). Beim Kopieren in ein neues Projekt: `class_weight_power`-
# und Task-Pfad-Fallbacks unten pruefen, falls das Zielprojekt aeltere
# Konventionen nutzt (kein `task_train_small_path`/`020_task.R`, kein
# gesetztes `class_weight_power`).

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
  library(mlr3measures)
})

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))
has_multiplier_tuning <- file.exists(file.path(project_dir, "class_multiplier_tuning.R"))
if (has_multiplier_tuning) source(file.path(project_dir, "class_multiplier_tuning.R"))

# Fallbacks fuer aeltere Projekte, die noch vor
# `enable_class_stratification()`/`add_balanced_class_weights()`/
# `class_weight_power` als Standard-Konvention entstanden.
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
cat(sprintf(
  "Projekt: %s | Primaermetrik: %s (schwellenwertunabhaengig: %s) | Multiplier-Tuning im workflow-Arm: %s\n",
  basename(project_dir), tuning_measure_id, threshold_independent, use_multiplier_tuning
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

# --- Arm 1: Default Ranger ----------------------------------------------
run_ranger_default <- function(outer_train, outer_test) {
  learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  learner$train(outer_train)
  score_prediction(learner$predict(outer_test))
}

# --- Arm 2: Default LightGBM ----------------------------------------------
run_lightgbm_default <- function(outer_train, outer_test) {
  learner <- make_imputed_learner(
    lrn("classif.lightgbm", num_iterations = lightgbm_default_iterations, predict_type = "prob")
  )
  learner$train(outer_train)
  score_prediction(learner$predict(outer_test))
}

# --- Arm 3: der reale Projekt-Workflow (gewichtet, ggf. + Multiplier) ---
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
outer_resampling$instantiate(task_full)

results <- data.table(outer_fold = integer(0), arm = character(0), score = numeric(0), runtime_sec = numeric(0))
arms <- list(
  ranger_default = run_ranger_default,
  lightgbm_default = run_lightgbm_default,
  workflow_ranger = run_workflow_ranger
)

for (fold in seq_len(n_outer_folds)) {
  train_ids <- outer_resampling$train_set(fold)
  test_ids <- outer_resampling$test_set(fold)
  outer_train <- task_full$clone(deep = TRUE)$filter(train_ids)
  outer_test <- task_full$clone(deep = TRUE)$filter(test_ids)

  cat(sprintf("\n=== Outer Fold %d/%d (Train n=%d, Test n=%d) ===\n", fold, n_outer_folds, outer_train$nrow, outer_test$nrow))

  for (arm_name in names(arms)) {
    t0 <- Sys.time()
    score <- arms[[arm_name]](outer_train, outer_test)
    runtime_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("  %-18s %s = %.4f  (%.1fs)\n", arm_name, tuning_measure_id, score, runtime_sec))
    results <- rbind(results, data.table(outer_fold = fold, arm = arm_name, score = score, runtime_sec = runtime_sec))
  }
}

direction_max <- !(tuning_measure_id %in% c("classif.logloss", "classif.ce", "classif.bbrier", "classif.mbrier"))
summary_dt <- results[, .(
  mean_score = mean(score), sd_score = sd(score),
  worst_fold_score = if (direction_max) min(score) else max(score),
  mean_runtime_sec = mean(runtime_sec)
), by = arm][order(if (direction_max) -mean_score else mean_score)]

cat("\n=== Phase-C Outer-Workflow-Evaluation: Zusammenfassung ueber", n_outer_folds, "Outer Folds (Metrik:", tuning_measure_id, ") ===\n")
print(summary_dt)

outer_workflow_evaluation_results_path <- file.path(artifact_dir, "outer_workflow_evaluation_results.csv")
outer_workflow_evaluation_summary_path <- file.path(artifact_dir, "outer_workflow_evaluation_summary.csv")
fwrite(results, outer_workflow_evaluation_results_path)
fwrite(summary_dt, outer_workflow_evaluation_summary_path)
cat("\nDetailergebnisse:", outer_workflow_evaluation_results_path, "\n")
cat("Zusammenfassung:  ", outer_workflow_evaluation_summary_path, "\n")
