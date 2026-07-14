rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(tidyverse)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "features", "utils.R"))
source(file.path(project_dir, "features", "bmi.R"))
source(file.path(project_dir, "features", "sleep.R"))
source(file.path(project_dir, "features", "activity.R"))
source(file.path(project_dir, "features", "hydration.R"))
source(file.path(project_dir, "features", "cardio.R"))
source(file.path(project_dir, "features", "interactions.R"))
source(file.path(project_dir, "features", "surrogate_guided.R"))

model_name <- resolve_submission_model_name()
feature_set <- model_feature_sets[[model_name]]

if (!file.exists(final_model_full_path(model_name))) {
  source(file.path(project_dir, "150_train_full_model.R"))
}

model_bundle <- readRDS(final_model_full_path(model_name))
learner <- model_bundle$learner
feature_levels <- model_bundle$feature_levels
if ("feature_set" %in% names(model_bundle)) {
  trained_feature_set <- model_bundle$feature_set
} else if (identical(feature_set, "raw")) {
  trained_feature_set <- "raw"
} else {
  stop(
    "Das gespeicherte Modell enthaelt noch keine feature_set-Information, ",
    "die aktuelle Config erwartet aber feature_set = '", feature_set,
    "'. Bitte 150_train_full_model.R erneut ausfuehren."
  )
}
if (!identical(trained_feature_set, feature_set)) {
  stop(
    "Das gespeicherte Modell wurde mit feature_set = '", trained_feature_set,
    "' trainiert, die aktuelle Config erwartet aber '", feature_set,
    "'. Bitte 150_train_full_model.R erneut ausfuehren."
  )
}

test <- fread(test_path)
test_ids <- test[[id_col]]
test[, (id_col) := NULL]
test <- apply_feature_set(test, feature_set)

# Faktorstufen exakt an das Training angleichen (nicht per as.factor() neu
# ableiten), damit unterschiedliche Stufenmengen zwischen Train und Test die
# Vorhersage nicht verfaelschen.
for (col in names(feature_levels)) {
  test[[col]] <- factor(test[[col]], levels = feature_levels[[col]])
}

predictions <- learner$predict_newdata(test)

# target_col direkt verwendet statt eines hartcodierten Zwischenspaltennamens
# (frueher "health_condition" fest verdrahtet - bei einer Uebertragung auf
# ein neues Projekt mit anderer Zielspalte war das leicht zu uebersehen).
submission <- data.table(id = test_ids, response = predictions$response)
setnames(submission, "id", id_col)
setnames(submission, "response", target_col)

fwrite(submission, submission_path)

cat("=== Submission erzeugt ===\n")
cat("Zeilen:", nrow(submission), "\n")
cat("Klassenverteilung:\n")
print(table(submission[[target_col]]))
cat("\nGespeichert:", submission_path, "\n")
