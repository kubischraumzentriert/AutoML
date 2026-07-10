rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
  library(mlr3measures)
  library(ranger)
  library(kernelshap)
  library(isotree)
})

source("000_config.R")
source(file.path(project_dir, "040_preprocessing.R"))
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_weighted <- add_balanced_class_weights(task_train_small, class_weight_power)

target_col_name <- task_weighted$target_names
feature_cols <- task_weighted$feature_names

# Derselbe Holdout-Split wie in den anderen Skripten (Ranger/LightGBM werden
# hier bewusst NICHT ueber mlr3pipelines-Imputation trainiert, sondern auf
# manuell median/modus-imputierten Daten - das erlaubt direkten Zugriff auf
# das rohe ranger-Fit-Objekt fuer KernelSHAP, ohne durch die Pipeline-
# Verschachtelung (GraphLearner$model$classif.ranger$model) zu muessen.
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

train_features_only <- train_imputed[, ..feature_cols]
eval_features_only <- eval_imputed[, ..feature_cols]

if (length(hard_case_idx) >= 5) {
  iso_model <- isolation.forest(train_features_only, ntrees = 500, nthreads = 1, seed = seed)

  hard_case_scores <- predict(iso_model, eval_features_only[hard_case_idx])
  set.seed(seed)
  baseline_idx <- sample(correct_all_idx, min(5 * length(hard_case_idx), length(correct_all_idx)))
  baseline_scores <- predict(iso_model, eval_features_only[baseline_idx])

  outlier_test <- wilcox.test(hard_case_scores, baseline_scores)

  cat("\nIsolation-Forest-Anomalie-Score (0.5 = normal, -> 1 = Ausreisser):\n")
  cat("  'Alle drei selbstsicher falsch' (n=", length(hard_case_idx), "): Median =", round(median(hard_case_scores), 4), ", Mean =", round(mean(hard_case_scores), 4), "\n")
  cat("  Baseline: alle drei richtig  (n=", length(baseline_idx), "): Median =", round(median(baseline_scores), 4), ", Mean =", round(mean(baseline_scores), 4), "\n")
  cat("  Wilcoxon-Test p-Wert:", signif(outlier_test$p.value, 4), "\n")
} else {
  cat("\nZu wenige Faelle (<5) fuer eine belastbare Isolation-Forest-Auswertung.\n")
}

# "Interessante" Zeilen (falsch klassifiziert ODER unsicher) - Basis fuer den
# TabPFN-Vergleich unten UND fuer das DB-Logging am Skriptende.
low_confidence_idx <- which(ranger_confidence < error_analysis_uncertainty_threshold)
interesting_idx <- union(misclassified_idx, low_confidence_idx)

# --- Teil 2: KernelSHAP - welche Features treiben Ranger in die falsche Klasse? ---
pred_fun <- function(model, newdata) {
  predict(model, data = newdata)$predictions
}

ranger_fit <- learner_ranger$model

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

cat("\nBerechne KernelSHAP fuer", min(error_analysis_shap_sample_size, length(misclassified_idx)), "falsch klassifizierte Zeilen (Ranger, Ziel: vorhergesagte falsche Klasse) ...\n")
shap_errors <- sample_shap_for(misclassified_idx, ranger_response, "falsch klassifiziert")

correct_idx <- which(ranger_response == truth)
cat("Berechne KernelSHAP fuer", min(error_analysis_shap_sample_size, length(correct_idx)), "richtig klassifizierte Zeilen (Baseline-Vergleich) ...\n")
shap_correct <- sample_shap_for(correct_idx, ranger_response, "richtig klassifiziert")

shap_comparison <- rbindlist(list(shap_errors, shap_correct))
shap_wide <- dcast(shap_comparison, feature ~ gruppe, value.var = "mean_abs_shap")
shap_wide[, error_ratio := round(`falsch klassifiziert` / `richtig klassifiziert`, 3)]
setorder(shap_wide, -error_ratio)

fwrite(shap_comparison, error_analysis_shap_importance_path)

cat("\n=== Mean(|SHAP|) je Feature: falsch vs. richtig klassifiziert (Ranger, Verhaeltnis > 1 = ueberproportional an Fehlern beteiligt) ===\n")
print(shap_wide)
cat("\nGespeichert:\n")
cat("Fehler-Details :", error_analysis_results_path, "\n")
cat("SHAP-Vergleich :", error_analysis_shap_importance_path, "\n")

# --- Teil 3: TabPFN - komplett andere Methodik (in-context statt trainiert) ---
# TabPFN ist auf CPU auf ca. 1000 Kontextzeilen begrenzt (siehe 095), daher nur
# ein kleiner, klassenstratifizierter Kontext. Vorhersage NUR auf den
# "interessanten" Zeilen (nicht dem kompletten 13802-Zeilen-Eval-Split), um
# die CPU-Inferenzzeit praktikabel zu halten.
cat("\n=== TabPFN auf den", length(interesting_idx), "'interessanten' Zeilen (Kontext:", error_analysis_tabpfn_context_size, "klassenstratifizierte Zeilen) ===\n")

set.seed(seed)
train_target_vec <- train_imputed[[target_col_name]]
context_frac <- error_analysis_tabpfn_context_size / nrow(train_imputed)
context_idx <- unlist(lapply(split(seq_len(nrow(train_imputed)), train_target_vec), function(idx) {
  sample(idx, max(1, round(length(idx) * context_frac)))
}))
tabpfn_context <- train_imputed[context_idx]

tabpfn_task <- as_task_classif(
  tabpfn_context[, c(target_col_name, feature_cols), with = FALSE],
  target = target_col_name, id = "error_analysis_tabpfn_context"
)

# TabPFN akzeptiert nur logical/integer/numeric, daher one-hot-Encoding wie in 095.
learner_tabpfn <- build_classif_pipeline(
  lrn("classif.tabpfn", device = "cpu"),
  encode_factors = TRUE, scale_numeric = FALSE
)
learner_tabpfn$predict_type <- "prob"
learner_tabpfn$train(tabpfn_task)

pred_tabpfn <- learner_tabpfn$predict_newdata(eval_newdata[interesting_idx], task = tabpfn_task)
tabpfn_response <- pred_tabpfn$response
tabpfn_probs <- pred_tabpfn$prob
tabpfn_correct <- tabpfn_response == truth[interesting_idx]

misclassified_pos <- match(misclassified_idx, interesting_idx)
tabpfn_rescue_rate <- mean(tabpfn_correct[misclassified_pos])

hard_case_pos <- match(hard_case_idx, interesting_idx)
tabpfn_hard_case_rescue_rate <- if (length(hard_case_idx) > 0) mean(tabpfn_correct[hard_case_pos]) else NA_real_

cat("TabPFN 'rettet'", sprintf("%.1f%%", 100 * tabpfn_rescue_rate), "von Rangers", length(misclassified_idx), "Fehlern.\n")
cat("TabPFN 'rettet'", sprintf("%.1f%%", 100 * tabpfn_hard_case_rescue_rate), "der", length(hard_case_idx), "'alle drei selbstsicher falsch'-Zeilen.\n")
cat("(Hinweis: TabPFN nur auf", error_analysis_tabpfn_context_size, "Kontextzeilen trainiert, nicht auf allen", nrow(train_imputed), "- kein fairer Gesamtvergleich, siehe README zu 095.)\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
# Nur die "interessanten" Zeilen (falsch klassifiziert ODER unsicher, siehe
# error_analysis_uncertainty_threshold) werden auf Zeilenebene geloggt - nicht
# der komplette Eval-Split, um die prediction-Tabelle klein zu halten.
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "147_error_analysis_ranger.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Fehleranalyse Ranger: Konfidenz, LightGBM/LDA/TabPFN-Vergleich, Isolation-Forest, KernelSHAP")
db_log_run_config(db_con, db_run_id, list(
  validation_ratio = validation_ratio,
  class_weight_power = class_weight_power,
  error_analysis_uncertainty_threshold = error_analysis_uncertainty_threshold,
  error_analysis_shap_sample_size = error_analysis_shap_sample_size,
  error_analysis_shap_background_size = error_analysis_shap_background_size,
  error_analysis_tabpfn_context_size = error_analysis_tabpfn_context_size
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
mconf_tabpfn <- db_create_model_config(
  db_con, db_run_id,
  task_type = "classif", algorithm = "tabpfn", feature_set = "raw",
  preprocessing = "empty_to_na_onehot", class_weight_power = NA_real_, task_id = task_weighted$id,
  hyperparams = list(
    context_size = error_analysis_tabpfn_context_size,
    note = "nur auf interesting_idx-Teilmenge evaluiert (kleiner Kontext, CPU-Limit), kein repraesentatives bacc/mcc geloggt"
  )
)

db_log_metric_result(db_con, mconf_ranger, db_rsmp_id, "classif.bacc", mlr3measures::bacc(truth, ranger_response))
db_log_metric_result(db_con, mconf_ranger, db_rsmp_id, "classif.mcc", mlr3measures::mcc(truth, ranger_response))
db_log_metric_result(db_con, mconf_lightgbm, db_rsmp_id, "classif.bacc", mlr3measures::bacc(truth, lightgbm_response))
db_log_metric_result(db_con, mconf_lightgbm, db_rsmp_id, "classif.mcc", mlr3measures::mcc(truth, lightgbm_response))
db_log_metric_result(db_con, mconf_lda, db_rsmp_id, "classif.bacc", mlr3measures::bacc(truth, lda_response))
db_log_metric_result(db_con, mconf_lda, db_rsmp_id, "classif.mcc", mlr3measures::mcc(truth, lda_response))
# Kein bacc/mcc fuer TabPFN: nur auf interesting_idx evaluiert, nicht auf dem
# vollen Eval-Split - waere nicht vergleichbar mit den anderen drei Zeilen.

db_log_predictions(
  db_con, mconf_ranger, db_rsmp_id,
  row_ids = eval_ids[interesting_idx], truth = truth[interesting_idx], response = ranger_response[interesting_idx],
  prob_matrix = ranger_probs[interesting_idx, , drop = FALSE]
)
db_log_predictions(
  db_con, mconf_lightgbm, db_rsmp_id,
  row_ids = eval_ids[interesting_idx], truth = truth[interesting_idx], response = lightgbm_response[interesting_idx],
  prob_matrix = lightgbm_probs[interesting_idx, , drop = FALSE]
)
db_log_predictions(
  db_con, mconf_lda, db_rsmp_id,
  row_ids = eval_ids[interesting_idx], truth = truth[interesting_idx], response = lda_response[interesting_idx],
  prob_matrix = lda_probs[interesting_idx, , drop = FALSE]
)
db_log_predictions(
  db_con, mconf_tabpfn, db_rsmp_id,
  row_ids = eval_ids[interesting_idx], truth = truth[interesting_idx], response = tabpfn_response,
  prob_matrix = tabpfn_probs
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "(", length(interesting_idx), "Zeilen x 4 Modelle geloggt)\n")
