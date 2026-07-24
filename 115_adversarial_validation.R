rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3measures)
})

source("000_config.R")
source(file.path(project_dir, "005_benchmark_runtime.R"))
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

# Adversarial Validation: kann ein Klassifikator Train- von Test-Zeilen
# unterscheiden? AUC nahe 0.5 = Train/Test aehnlich verteilt, CV-Ergebnisse
# sollten sich aufs Leaderboard uebertragen. AUC deutlich > 0.5 = Distribution
# Shift, CV-basierte Entscheidungen mit Vorsicht behandeln.
train <- fread(train_path)
test <- fread(test_path)

train[, (target_col) := NULL]
train[, is_test := 0L]
test[, is_test := 1L]

combined <- rbindlist(list(train, test), use.names = TRUE)
combined[, (id_col) := NULL]
combined[, is_test := factor(is_test, levels = c(0, 1))]
combined[, names(combined)[sapply(combined, is.character)] := lapply(.SD, as.factor), .SDcols = is.character]

task_adversarial <- as_task_classif(combined, target = "is_test", positive = "1", id = "adversarial_validation")
task_adversarial <- enable_class_stratification(task_adversarial)

# LightGBM verarbeitet fehlende Werte nativ (Property "missings"), daher ohne
# Imputations-Pipeline - das vereinfacht auch den Zugriff auf importance().
learner_adversarial <- lrn(
  "classif.lightgbm",
  num_iterations = adversarial_validation_iterations
)
learner_adversarial$predict_type <- "prob"

resampling <- rsmp("cv", folds = adversarial_validation_cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_adversarial),
  learners = list(learner_adversarial),
  resampling = resampling,
  measures = msr("classif.auc")
)

adversarial_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", "classif.auc", "elapsed_seconds"),
  with = FALSE
]

fwrite(adversarial_results, adversarial_validation_results_path)

cat("=== Adversarial Validation: Train vs. Test unterscheidbar? ===\n")
print(adversarial_results)
cat("\nInterpretation: AUC nahe 0.5 = kein Distribution Shift, AUC deutlich > 0.5 = Shift.\n")

# Feature Importance auf einem vollen Fit, um im Fall eines Shifts die
# treibenden Merkmale zu identifizieren.
learner_full_fit <- learner_adversarial$clone(deep = TRUE)
learner_full_fit$train(task_adversarial)

importance <- learner_full_fit$importance()
importance_dt <- data.table(feature = names(importance), gain = as.numeric(importance))
setorder(importance_dt, -gain)

fwrite(importance_dt, adversarial_validation_importance_path)

cat("\n=== Feature Importance des Adversarial-Klassifikators ===\n")
print(importance_dt)
cat("\nGespeichert:\n")
cat("Ergebnisse:", adversarial_validation_results_path, "\n")
cat("Importance:", adversarial_validation_importance_path, "\n")

# --- ESS + gestufte Adversarial Validation (Rueckfuehrung aus Regression-018) --
# ESS/n der OOF-Propensity-Gewichte (Reweighting-Machbarkeit) direkt aus einem
# separaten resample() berechnet; optionale Stufen isolieren den Rest-Shift ohne
# verdaechtige Feature-Gruppen. Additiv - beruehrt das bestehende Benchmark/DB-
# Logging nicht; Default (adversarial_staged_exclude = list()) = nur Gesamt-AUC/ESS.
compute_auc_ess <- function(task_adv) {
  rr <- resample(task_adv, learner_adversarial$clone(deep = TRUE),
                 rsmp("cv", folds = adversarial_validation_cv_folds))
  pred <- rr$prediction()
  p <- pred$prob[, "1"]; truth <- pred$truth == "1"
  r <- rank(p, ties.method = "average")
  n1 <- as.numeric(sum(truth)); n0 <- as.numeric(sum(!truth))  # numeric: n1*n0 sonst int-Overflow
  auc <- (sum(r[truth]) - n1 * (n1 + 1) / 2) / (n1 * n0)
  ptr <- pmin(0.999, pmax(0.001, p[!truth])); w <- ptr / (1 - ptr)
  list(auc = auc, ess_ratio = (sum(w)^2 / sum(w^2)) / length(w))
}
base_ae <- compute_auc_ess(task_adversarial)
staged <- data.table(stage = "all_features", auc = base_ae$auc, ess_ratio = base_ae$ess_ratio)
for (nm in names(adversarial_staged_exclude)) {
  keep <- setdiff(task_adversarial$feature_names, adversarial_staged_exclude[[nm]])
  s <- compute_auc_ess(task_adversarial$clone(deep = TRUE)$select(keep))
  staged <- rbind(staged, data.table(stage = paste0("ohne_", nm), auc = s$auc, ess_ratio = s$ess_ratio))
}
fwrite(staged, adversarial_staged_results_path)
cat("\n=== Gestufte Adversarial Validation + ESS ===\n")
print(staged)
cat("ESS/n klein => Reweighting instabil/nutzlos; AUC-Abfall ueber Stufen zeigt die Shift-treibende Gruppe.\n")
cat("Gestuft:", adversarial_staged_results_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "115_adversarial_validation.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Adversarial Validation: Train vs. Test unterscheidbar?")
db_log_run_config(db_con, db_run_id, list(
  adversarial_validation_cv_folds = adversarial_validation_cv_folds,
  adversarial_validation_iterations = adversarial_validation_iterations
))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = "classif.auc",
  model_config_fn = function(row) list(
    task_type = "classif", algorithm = "lightgbm", feature_set = "adversarial",
    preprocessing = "none", class_weight_power = NA_real_, task_id = row$task_id[1],
    hyperparams = list(num_iterations = adversarial_validation_iterations)
  ),
  resampling_strategy = "cv", resampling_folds = adversarial_validation_cv_folds, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
