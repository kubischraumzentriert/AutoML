if (!exists("project_dir")) project_dir <- dirname(normalizePath(sys.frame(1)$ofile))
fixture <- readRDS(file.path(project_dir, "fixture_settings.rds"))
train_path <- file.path(project_dir, "train.csv")
test_path <- file.path(project_dir, "test.csv")
sample_submission_path <- file.path(project_dir, "sample_submission.csv")
artifact_dir <- file.path(project_dir, "_artifacts")
experiments_db_path <- file.path(artifact_dir, "experiments.db")
submission_path <- file.path(project_dir, "submission.csv")
submission_ensemble_path <- file.path(project_dir, "submission_ensemble.csv")
id_col <- "id"
target_col <- "outcome"
project_name <- "submission-fixture"
seed <- 42L
positive_class <- fixture$positive_class
baseline_measure_ids <- fixture$measures
model_feature_sets <- list(rpart = "raw")
base_learner_constructors <- list(rpart = function() {
  mlr3::lrn("classif.rpart", cp = fixture$cp, minsplit = 2L, predict_type = "prob")
})
resolve_submission_model_name <- function() "rpart"
apply_feature_set <- function(test, feature_set) test
feature_transform_function_hash <- function(feature_set) NA_character_
