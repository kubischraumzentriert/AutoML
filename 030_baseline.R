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

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)

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

learners <- list(
  make_baseline_learner(learner_lda),
  make_baseline_learner(learner_multinom),
  make_baseline_learner(learner_ranger)
)

resampling <- rsmp("holdout", ratio = validation_ratio)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small),
  learners = learners,
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

baseline_results_raw <- timed_benchmark$results

baseline_results <- baseline_results_raw[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(baseline_results, baseline_results_path)
saveRDS(timed_benchmark$benchmarks, baseline_benchmark_path)

cat("=== Baseline Ergebnisse ===\n")
print(baseline_results)
cat("\nGespeichert:\n")
cat("Ergebnisse:", baseline_results_path, "\n")
cat("Benchmark :", baseline_benchmark_path, "\n")
