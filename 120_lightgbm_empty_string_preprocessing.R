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
task_weighted <- add_balanced_class_weights(task_train_small, class_weight_power)

# Variante A: "" bleibt eigene Faktorstufe (aktueller Ansatz in 070_final_models.R).
make_baseline_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}
learner_keep_empty <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations),
  id = "lightgbm_keep_empty"
)

# Variante B: "" -> NA -> Imputation via empty_factor_to_na (040_preprocessing.R).
learner_na_impute <- build_classif_pipeline(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations),
  encode_factors = FALSE,
  scale_numeric = FALSE
)
learner_na_impute$id <- "lightgbm_na_impute"

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_weighted),
  learners = list(learner_keep_empty, learner_na_impute),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

lightgbm_empty_string_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(lightgbm_empty_string_results, lightgbm_empty_string_results_path)

cat("=== LightGBM: '' behalten vs. '' -> NA -> Imputation (power =", class_weight_power, ", 5-fache CV) ===\n")
print(lightgbm_empty_string_results)
cat("\nGespeichert:", lightgbm_empty_string_results_path, "\n")
