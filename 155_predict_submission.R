rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")

model_name <- resolve_submission_model_name()

if (!file.exists(final_model_full_path(model_name))) {
  source(file.path(project_dir, "150_train_full_model.R"))
}

model_bundle <- readRDS(final_model_full_path(model_name))
learner <- model_bundle$learner
feature_levels <- model_bundle$feature_levels

test <- fread(test_path)
test_ids <- test[[id_col]]
test[, (id_col) := NULL]

# Faktorstufen exakt an das Training angleichen (nicht per as.factor() neu
# ableiten), damit unterschiedliche Stufenmengen zwischen Train und Test die
# Vorhersage nicht verfaelschen.
for (col in names(feature_levels)) {
  test[[col]] <- factor(test[[col]], levels = feature_levels[[col]])
}

predictions <- learner$predict_newdata(test)

submission <- data.table(id = test_ids, health_condition = predictions$response)
setnames(submission, "id", id_col)
setnames(submission, "health_condition", target_col)

fwrite(submission, submission_path)

cat("=== Submission erzeugt ===\n")
cat("Zeilen:", nrow(submission), "\n")
cat("Klassenverteilung:\n")
print(table(submission[[target_col]]))
cat("\nGespeichert:", submission_path, "\n")
