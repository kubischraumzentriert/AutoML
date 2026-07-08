rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

feature_set_task_paths <- vapply(model_feature_sets, resolve_task_path, character(1))
if (!all(file.exists(feature_set_task_paths))) {
  source(file.path(project_dir, "025_feature_engineering.R"))
}

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

cat("=== Finale Modelle ===\n")

for (model_name in names(model_feature_sets)) {
  feature_set <- model_feature_sets[[model_name]]
  task <- readRDS(resolve_task_path(feature_set))

  weight_power <- model_class_weight_power[[model_name]]
  if (!is.null(weight_power) && weight_power != 0) {
    task <- add_balanced_class_weights(task, weight_power)
  }

  learner <- make_baseline_learner(base_learner_constructors[[model_name]]())

  set.seed(seed)
  learner$train(task)

  saveRDS(learner, final_model_path(model_name))

  cat("Modell      :", model_name, "\n")
  cat("Feature-Set :", feature_set, "(Task:", task$id, ")\n")
  if (!is.null(weight_power) && weight_power != 0) {
    cat("Gewichtung  : power =", weight_power, "\n")
  }
  cat("Gespeichert :", final_model_path(model_name), "\n\n")
}
