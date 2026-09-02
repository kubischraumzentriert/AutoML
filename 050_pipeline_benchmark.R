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
source(file.path(project_dir, "040_preprocessing.R"))
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)

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
  build_classif_pipeline(learner_lda),
  build_classif_pipeline(learner_multinom),
  build_classif_pipeline(learner_ranger)
)

resampling <- rsmp("holdout", ratio = validation_ratio)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small),
  learners = learners,
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

pipeline_results_raw <- timed_benchmark$results

pipeline_results <- pipeline_results_raw[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(pipeline_results, pipeline_results_path)
saveRDS(timed_benchmark$benchmarks, pipeline_benchmark_path)

cat("=== Pipeline Benchmark Ergebnisse ===\n")
print(pipeline_results)
cat("\nGespeichert:\n")
cat("Ergebnisse:", pipeline_results_path, "\n")
cat("Benchmark :", pipeline_benchmark_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "050_pipeline_benchmark.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Allgemeine Preprocessing-Pipeline (empty_to_na, Impute, fixfactors)")
db_log_run_config(db_con, db_run_id, list(validation_ratio = validation_ratio))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) list(
    task_type = "classif",
    algorithm = algorithm_from_learner_id(row$learner_id[1]),
    feature_set = feature_set_from_task_id(row$task_id[1]),
    preprocessing = "empty_to_na_impute_fixfactors",
    class_weight_power = NA_real_,
    task_id = row$task_id[1]
  ),
  resampling_strategy = "holdout", resampling_ratio = validation_ratio, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
