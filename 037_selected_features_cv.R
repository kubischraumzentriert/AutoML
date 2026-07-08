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
if (!file.exists(task_train_small_features_selected_path)) {
  source(file.path(project_dir, "025_feature_engineering.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_train_small_features_selected <- readRDS(task_train_small_features_selected_path)

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

learner_lda <- make_baseline_learner(lrn("classif.lda"))

learner_multinom_base <- lrn("classif.multinom")
if ("trace" %in% learner_multinom_base$param_set$ids()) {
  learner_multinom_base$param_set$values$trace <- FALSE
}
learner_multinom <- make_baseline_learner(learner_multinom_base)

learner_ranger <- make_baseline_learner(
  lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = seed)
)

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
