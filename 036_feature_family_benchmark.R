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

family_task_paths <- vapply(feature_families, task_train_small_feature_family_path, character(1))
if (!all(file.exists(family_task_paths)) || !file.exists(task_train_small_features_path)) {
  source(file.path(project_dir, "025_feature_engineering.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_train_small_features <- readRDS(task_train_small_features_path)
family_tasks <- lapply(family_task_paths, readRDS)

tasks <- c(list(task_train_small), family_tasks, list(task_train_small_features))

make_baseline_learner <- function(base_learner) {
  graph <- po("imputemedian") %>>%
    po("imputemode") %>>%
    base_learner

  as_learner(graph)
}

learner_lda <- lrn("classif.lda")
learner_multinom <- lrn("classif.multinom")
learner_ranger <- lrn(
  "classif.ranger",
  num.trees = 200,
  respect.unordered.factors = "order",
  seed = seed
)

if ("trace" %in% learner_multinom$param_set$ids()) {
  learner_multinom$param_set$values$trace <- FALSE
}

# predict_type="prob" fuer alle drei Learner: siehe 030_baseline.R fuer die
# volle Begruendung (BUGFIX 2026-09-01, gefunden im s6e9-Projekt - dieses
# Skript fehlte bislang, obwohl 030 den identischen Fix schon hatte).
learner_lda$predict_type <- "prob"
learner_multinom$predict_type <- "prob"
learner_ranger$predict_type <- "prob"

learners <- list(
  make_baseline_learner(learner_lda),
  make_baseline_learner(learner_multinom),
  make_baseline_learner(learner_ranger)
)

resampling <- rsmp("holdout", ratio = validation_ratio)

timed_benchmark <- run_timed_benchmark(
  tasks = tasks,
  learners = learners,
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

feature_family_results_raw <- timed_benchmark$results

feature_family_results <- feature_family_results_raw[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(feature_family_results, feature_family_results_path)
saveRDS(timed_benchmark$benchmarks, feature_family_benchmark_path)

cat("=== Feature-Family Benchmark Ergebnisse ===\n")
print(feature_family_results)
cat("\nGespeichert:\n")
cat("Ergebnisse:", feature_family_results_path, "\n")
cat("Benchmark :", feature_family_benchmark_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "036_feature_family_benchmark.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Feature-Familien-Vergleich (Holdout)")
db_log_run_config(db_con, db_run_id, list(validation_ratio = validation_ratio))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) list(
    task_type = "classif",
    algorithm = algorithm_from_learner_id(row$learner_id[1]),
    feature_set = feature_set_from_task_id(row$task_id[1]),
    preprocessing = "impute_median_mode",
    class_weight_power = NA_real_,
    task_id = row$task_id[1]
  ),
  resampling_strategy = "holdout", resampling_ratio = validation_ratio, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
