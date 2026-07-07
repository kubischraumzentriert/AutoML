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
