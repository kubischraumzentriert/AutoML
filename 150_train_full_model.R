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

model_name <- resolve_submission_model_name()
feature_set <- model_feature_sets[[model_name]]
if (feature_set != "raw") {
  stop("150_train_full_model.R unterstuetzt aktuell nur feature_set = 'raw' fuer das Submission-Modell.")
}

train <- fread(train_path)
train[, (id_col) := NULL]

feature_char_cols <- setdiff(names(train)[vapply(train, is.character, logical(1))], target_col)
train[, (feature_char_cols) := lapply(.SD, as.factor), .SDcols = feature_char_cols]
train[, (target_col) := as.factor(get(target_col))]

# Faktorstufen der Merkmale mit dem Modell mitspeichern, damit 155 test.csv
# exakt auf dieselben Stufen abbildet (unabhaengig davon, ob im Test-Set
# zufaellig alle Stufen vorkommen). Zielspalte bewusst ausgeschlossen - die
# gibt es in test.csv nicht.
feature_levels <- lapply(train[, ..feature_char_cols], levels)

task_full <- as_task_classif(train, target = target_col, id = paste0(task_id_prefix, "_full_", model_name))

weight_power <- model_class_weight_power[[model_name]]
if (!is.null(weight_power) && weight_power != 0) {
  task_full <- add_balanced_class_weights(task_full, weight_power)
}

cat("=== Finales Training auf vollem Trainingsdatensatz ===\n")
cat("Modell:", model_name, "\n")
cat("Zeilen:", task_full$nrow, " Features:", length(task_full$feature_names), "\n")
if (!is.null(weight_power) && weight_power != 0) {
  cat("class_weight_power:", weight_power, "\n")
}

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

learner_full <- make_baseline_learner(base_learner_constructors[[model_name]]())
learner_full$train(task_full)

saveRDS(
  list(learner = learner_full, feature_levels = feature_levels),
  final_model_full_path(model_name)
)

cat("\nGespeichert:", final_model_full_path(model_name), "\n")
