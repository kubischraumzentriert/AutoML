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
