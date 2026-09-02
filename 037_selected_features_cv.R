rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "005_benchmark_runtime.R"))
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}
if (!file.exists(task_train_small_features_selected_path)) {
  source(file.path(project_dir, "025_feature_engineering.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_train_small_features_selected <- readRDS(task_train_small_features_selected_path)

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

# predict_type="prob" JEWEILS VOR dem Wrap in make_baseline_learner() gesetzt
# (auf dem Basis-Learner, nicht dem fertigen GraphLearner) - siehe
# 030_baseline.R fuer die volle Begruendung (BUGFIX 2026-09-01, gefunden im
# s6e9-Projekt - dieses Skript fehlte bislang, obwohl 030 den identischen
# Fix schon hatte).
learner_lda_base <- lrn("classif.lda")
learner_lda_base$predict_type <- "prob"
learner_lda <- make_baseline_learner(learner_lda_base)

learner_multinom_base <- lrn("classif.multinom")
if ("trace" %in% learner_multinom_base$param_set$ids()) {
  learner_multinom_base$param_set$values$trace <- FALSE
}
learner_multinom_base$predict_type <- "prob"
learner_multinom <- make_baseline_learner(learner_multinom_base)

learner_ranger_base <- lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = seed)
learner_ranger_base$predict_type <- "prob"
learner_ranger <- make_baseline_learner(learner_ranger_base)

resampling <- rsmp("cv", folds = cv_folds)

# LDA bleibt auf Rohfeatures (reagiert empfindlich auf Kollinearitaet durch engineered Features).
lda_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small),
  learners = list(learner_lda),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

# Multinom und Ranger auf Rohfeatures und auf dem ausgewaehlten Feature-Set
# (Aktivitaet + Cardio + Schlaf), damit der CV-Vergleich fair ist.
selected_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small, task_train_small_features_selected),
  learners = list(learner_multinom, learner_ranger),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

selected_cv_results_raw <- rbindlist(
  list(lda_benchmark$results, selected_benchmark$results),
  fill = TRUE
)

selected_cv_results <- selected_cv_results_raw[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(selected_cv_results, selected_cv_results_path)
saveRDS(
  c(lda_benchmark$benchmarks, selected_benchmark$benchmarks),
  selected_cv_benchmark_path
)

cat("=== Selected-Features CV Ergebnisse ===\n")
print(selected_cv_results)
cat("\nGespeichert:\n")
cat("Ergebnisse:", selected_cv_results_path, "\n")
cat("Benchmark :", selected_cv_benchmark_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "037_selected_features_cv.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Familien-Auswahl per CV bestaetigt (LDA roh, Multinom/Ranger roh vs. ausgewaehlt)")
db_log_run_config(db_con, db_run_id, list(cv_folds = cv_folds))

model_config_fn_037 <- function(row) list(
  task_type = "classif",
  algorithm = algorithm_from_learner_id(row$learner_id[1]),
  feature_set = feature_set_from_task_id(row$task_id[1]),
  preprocessing = "impute_median_mode",
  class_weight_power = NA_real_,
  task_id = row$task_id[1]
)

db_log_timed_benchmark(
  db_con, db_run_id, lda_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = model_config_fn_037,
  resampling_strategy = "cv", resampling_folds = cv_folds, resampling_seed = seed
)
db_log_timed_benchmark(
  db_con, db_run_id, selected_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = model_config_fn_037,
  resampling_strategy = "cv", resampling_folds = cv_folds, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
