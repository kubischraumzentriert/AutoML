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

train <- fread(train_path)
train[, (id_col) := NULL]

feature_char_cols <- setdiff(names(train)[vapply(train, is.character, logical(1))], target_col)
train[, (feature_char_cols) := lapply(.SD, as.factor), .SDcols = feature_char_cols]
train[, (target_col) := as.factor(get(target_col))]

# Faktorstufen der Merkmale mit dem Modell mitspeichern, damit 155 test.csv
# exakt auf dieselben Stufen abbilden kann (unabhaengig davon, ob im Test-Set
# zufaellig alle Stufen vorkommen). Zielspalte bewusst ausgeschlossen - die
# gibt es in test.csv nicht.
feature_levels <- lapply(train[, ..feature_char_cols], levels)

task_full <- as_task_classif(train, target = target_col, id = "health_condition_full")
task_full_weighted <- add_balanced_class_weights(task_full, class_weight_power)

cat("=== Finales LightGBM-Training auf vollem Trainingsdatensatz ===\n")
cat("Zeilen:", task_full$nrow, " Features:", length(task_full$feature_names), "\n")
cat("class_weight_power:", class_weight_power, "\n")

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

learner_lightgbm_full <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations)
)

learner_lightgbm_full$train(task_full_weighted)

saveRDS(
  list(learner = learner_lightgbm_full, feature_levels = feature_levels),
  final_model_lightgbm_full_path
)

cat("\nGespeichert:", final_model_lightgbm_full_path, "\n")
