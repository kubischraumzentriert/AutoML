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

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

# Ranger als bekannte Referenz (siehe 037), lightgbm verarbeitet Faktoren nativ
# wie Ranger, xgboost braucht dagegen numerische Eingaben (one-hot encodiert).
learner_ranger <- make_baseline_learner(
  lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = seed)
)

learner_lightgbm <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = 200)
)

learner_xgboost <- build_classif_pipeline(
  lrn("classif.xgboost", nrounds = 200),
  encode_factors = TRUE,
  scale_numeric = FALSE
)

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small),
  learners = list(learner_ranger, learner_lightgbm, learner_xgboost),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

boosting_results_raw <- timed_benchmark$results

boosting_results <- boosting_results_raw[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(boosting_results, boosting_results_path)
saveRDS(timed_benchmark$benchmarks, boosting_benchmark_path)

cat("=== Boosting-Benchmark (Rohfeatures, 5-fache CV) ===\n")
print(boosting_results)
cat("\nGespeichert:\n")
cat("Ergebnisse:", boosting_results_path, "\n")
cat("Benchmark :", boosting_benchmark_path, "\n")
