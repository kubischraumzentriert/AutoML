config_path <- normalizePath(sys.frame(1)$ofile)
project_dir <- dirname(config_path)

train_path <- file.path(project_dir, "train.csv")
test_path <- file.path(project_dir, "test.csv")
sample_submission_path <- file.path(project_dir, "sample_submission.csv")

id_col <- "id"
target_col <- "health_condition"

seed <- 42
subset_fraction <- 0.10

validation_ratio <- 0.80
baseline_measure_ids <- c("classif.bacc", "classif.mcc")
cv_folds <- 5

glmnet_nfolds <- 3
glmnet_nlambda <- 30

artifact_dir <- file.path(project_dir, "_artifacts")
task_train_small_path <- file.path(artifact_dir, "task_train_small.rds")
task_train_small_features_path <- file.path(artifact_dir, "task_train_small_features.rds")

feature_families <- c("bmi", "sleep", "activity", "hydration", "cardio", "interactions")

# Pfad fuer je einen Feature-Task pro Familie (siehe feature_families)
task_train_small_feature_family_path <- function(family) {
  file.path(artifact_dir, paste0("task_train_small_features_", family, ".rds"))
}

selected_families <- c("activity", "cardio", "sleep")
task_train_small_features_selected_path <- file.path(artifact_dir, "task_train_small_features_selected.rds")

baseline_results_path <- file.path(artifact_dir, "baseline_results.csv")
baseline_benchmark_path <- file.path(artifact_dir, "baseline_benchmark.rds")
feature_baseline_results_path <- file.path(artifact_dir, "feature_baseline_results.csv")
feature_baseline_benchmark_path <- file.path(artifact_dir, "feature_baseline_benchmark.rds")
feature_family_results_path <- file.path(artifact_dir, "feature_family_results.csv")
feature_family_benchmark_path <- file.path(artifact_dir, "feature_family_benchmark.rds")
selected_cv_results_path <- file.path(artifact_dir, "selected_cv_results.csv")
selected_cv_benchmark_path <- file.path(artifact_dir, "selected_cv_benchmark.rds")

pipeline_results_path <- file.path(artifact_dir, "pipeline_results.csv")
pipeline_benchmark_path <- file.path(artifact_dir, "pipeline_benchmark.rds")

glmnet_results_path <- file.path(artifact_dir, "glmnet_results.csv")
glmnet_benchmark_path <- file.path(artifact_dir, "glmnet_benchmark.rds")
