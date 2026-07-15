rm(list = ls())

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

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

# Erster Baustein der Fehleranalyse (siehe ANLEITUNG.md Phase 11): trainiert
# die drei Vergleichsmodelle EINMAL auf dem Holdout-Split, speichert Modelle +
# Vorhersagen als Artefakt und loggt vollstaendig nach experiments.db. Die
# nachgelagerten Skripte (_confidence.R, _isolation_forest.R, _kernelshap.R,
# _tabpfn.R) laden dieses Artefakt, statt selbst neu zu trainieren - lose
# Kopplung statt eines einzigen grossen Skripts, das bei jeder Aenderung
# (z.B. am DB-Logging) komplett neu laufen muss, inklusive der teuren
# KernelSHAP-/TabPFN-Teile.
if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_weighted <- add_balanced_class_weights(task_train_small, class_weight_power)

target_col_name <- task_weighted$target_names
feature_cols <- task_weighted$feature_names

# Ranger/LightGBM/LDA werden hier bewusst NICHT ueber mlr3pipelines-Imputation
# trainiert, sondern auf manuell median/modus-imputierten Daten - das erlaubt
# direkten Zugriff auf das rohe ranger-Fit-Objekt fuer KernelSHAP (spaeteres
# Skript), ohne durch die Pipeline-Verschachtelung
# (GraphLearner$model$classif.ranger$model) zu muessen.
resampling <- rsmp("holdout", ratio = validation_ratio)
resampling$instantiate(task_weighted)
train_ids <- resampling$train_set(1)
eval_ids <- resampling$test_set(1)

train_dt <- task_weighted$data(rows = train_ids, cols = c(target_col_name, feature_cols, "weight"))
eval_dt <- task_weighted$data(rows = eval_ids, cols = c(target_col_name, feature_cols, "weight"))

numeric_cols <- setdiff(names(train_dt)[vapply(train_dt, is.numeric, logical(1))], "weight")
factor_cols <- names(train_dt)[vapply(train_dt, function(x) is.factor(x) || is.character(x), logical(1))]

medians <- vapply(train_dt[, ..numeric_cols], median, numeric(1), na.rm = TRUE)
modes <- vapply(train_dt[, ..factor_cols], function(x) names(sort(table(x), decreasing = TRUE))[1], character(1))

impute_dt <- function(dt) {
  dt <- copy(dt)
  for (col in numeric_cols) dt[is.na(get(col)), (col) := medians[[col]]]
  for (col in factor_cols) dt[is.na(get(col)), (col) := modes[[col]]]
  dt
}

train_imputed <- impute_dt(train_dt)
eval_imputed <- impute_dt(eval_dt)

# Trainingstask ohne mlr3pipelines-Imputation (bereits manuell imputiert oben).
train_task <- as_task_classif(train_imputed[, c(target_col_name, feature_cols), with = FALSE], target = target_col_name, id = "error_analysis_train")
train_task$cbind(data.table(weight = train_imputed$weight))
train_task$set_col_roles("weight", roles = "weights_learner")

learner_ranger <- lrn(
  "classif.ranger",
  num.trees = 200, respect.unordered.factors = "order", seed = seed,
  predict_type = "prob"
)
learner_lightgbm <- lrn(
  "classif.lightgbm",
  num_iterations = lightgbm_tuning_final_iterations,
  predict_type = "prob"
)
# LDA unterstuetzt (anders als Ranger/LightGBM) keine Gewichte - mlr3 bricht
# sonst mit einem Fehler ab. use_weights = "ignore" traininiert LDA bewusst
# ungewichtet auf demselben Task (konsistent mit der README-Feststellung,
# dass LDA in diesem Projekt nirgends gewichtet trainiert wird).
learner_lda <- lrn("classif.lda", predict_type = "prob", use_weights = "ignore")

learner_ranger$train(train_task)
learner_lightgbm$train(train_task)
learner_lda$train(train_task)

eval_newdata <- eval_imputed[, c(target_col_name, feature_cols), with = FALSE]
pred_ranger <- learner_ranger$predict_newdata(eval_newdata, task = train_task)
pred_lightgbm <- learner_lightgbm$predict_newdata(eval_newdata, task = train_task)
pred_lda <- learner_lda$predict_newdata(eval_newdata, task = train_task)

truth <- pred_ranger$truth
ranger_response <- pred_ranger$response
ranger_probs <- pred_ranger$prob
ranger_confidence <- apply(ranger_probs, 1, max)
ranger_true_class_prob <- ranger_probs[cbind(seq_len(nrow(ranger_probs)), match(as.character(truth), colnames(ranger_probs)))]

lightgbm_response <- pred_lightgbm$response
lightgbm_probs <- pred_lightgbm$prob
lightgbm_confidence <- apply(lightgbm_probs, 1, max)

lda_response <- pred_lda$response
lda_probs <- pred_lda$prob
lda_confidence <- apply(lda_probs, 1, max)

models <- list(
  train_ids = train_ids, eval_ids = eval_ids, truth = truth,
  target_col_name = target_col_name, feature_cols = feature_cols,
  train_imputed = train_imputed, eval_imputed = eval_imputed,
  learner_ranger = learner_ranger,
  ranger_response = ranger_response, ranger_probs = ranger_probs,
  ranger_confidence = ranger_confidence, ranger_true_class_prob = ranger_true_class_prob,
  lightgbm_response = lightgbm_response, lightgbm_probs = lightgbm_probs, lightgbm_confidence = lightgbm_confidence,
  lda_response = lda_response, lda_probs = lda_probs, lda_confidence = lda_confidence,
  task_id = task_weighted$id
)
saveRDS(models, error_analysis_models_path)

cat("=== Modelle trainiert, Vorhersagen gespeichert ===\n")
cat("Artefakt:", error_analysis_models_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "147_error_analysis_ranger_models.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Fehleranalyse-Modelle: Ranger/LightGBM/LDA trainiert, vollstaendiges Prediction-Logging fuer ROC/PR-Kurven")
db_log_run_config(db_con, db_run_id, list(
  validation_ratio = validation_ratio,
  class_weight_power = class_weight_power
))

db_rsmp_id <- db_create_resampling(
  db_con, db_run_id, strategy = "custom_split",
  ratio = validation_ratio, seed = seed
)

mconf_ranger <- db_create_model_config(
  db_con, db_run_id,
  task_type = "classif", algorithm = "ranger", feature_set = "raw",
  preprocessing = "impute_median_mode", class_weight_power = class_weight_power, task_id = task_weighted$id,
  hyperparams = list(num.trees = 200)
)
mconf_lightgbm <- db_create_model_config(
  db_con, db_run_id,
  task_type = "classif", algorithm = "lightgbm", feature_set = "raw",
  preprocessing = "impute_median_mode", class_weight_power = class_weight_power, task_id = task_weighted$id,
  hyperparams = list(num_iterations = lightgbm_tuning_final_iterations)
)
mconf_lda <- db_create_model_config(
  db_con, db_run_id,
  task_type = "classif", algorithm = "lda", feature_set = "raw",
  preprocessing = "impute_median_mode", class_weight_power = NA_real_, task_id = task_weighted$id,
  hyperparams = list(note = "use_weights=ignore (LDA unterstuetzt keine Gewichte)")
)

db_log_metric_result(db_con, mconf_ranger, db_rsmp_id, "classif.bacc", mlr3measures::bacc(truth, ranger_response))
db_log_metric_result(db_con, mconf_ranger, db_rsmp_id, "classif.mcc", mlr3measures::mcc(truth, ranger_response))
db_log_metric_result(db_con, mconf_lightgbm, db_rsmp_id, "classif.bacc", mlr3measures::bacc(truth, lightgbm_response))
db_log_metric_result(db_con, mconf_lightgbm, db_rsmp_id, "classif.mcc", mlr3measures::mcc(truth, lightgbm_response))
db_log_metric_result(db_con, mconf_lda, db_rsmp_id, "classif.bacc", mlr3measures::bacc(truth, lda_response))
db_log_metric_result(db_con, mconf_lda, db_rsmp_id, "classif.mcc", mlr3measures::mcc(truth, lda_response))

# Vollstaendiges Logging (ALLE Eval-Zeilen) - ermoeglicht ROC-/PR-Kurven per
# SQL (160_plot_roc_curve.R/161_plot_pr_curve.R), ohne die Modelle dafuer
# erneut trainieren zu muessen.
db_log_predictions(db_con, mconf_ranger, db_rsmp_id, row_ids = eval_ids, truth = truth, response = ranger_response, prob_matrix = ranger_probs)
db_log_predictions(db_con, mconf_lightgbm, db_rsmp_id, row_ids = eval_ids, truth = truth, response = lightgbm_response, prob_matrix = lightgbm_probs)
db_log_predictions(db_con, mconf_lda, db_rsmp_id, row_ids = eval_ids, truth = truth, response = lda_response, prob_matrix = lda_probs)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "(", length(eval_ids), "Zeilen x 3 Modelle vollstaendig geloggt)\n")
