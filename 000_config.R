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

glmnet_nfolds <- 3
glmnet_nlambda <- 30

artifact_dir <- file.path(project_dir, "_artifacts")
task_train_small_path <- file.path(artifact_dir, "task_train_small.rds")
task_train_small_features_path <- file.path(artifact_dir, "task_train_small_features.rds")
baseline_results_path <- file.path(artifact_dir, "baseline_results.csv")
baseline_benchmark_path <- file.path(artifact_dir, "baseline_benchmark.rds")
feature_baseline_results_path <- file.path(artifact_dir, "feature_baseline_results.csv")
feature_baseline_benchmark_path <- file.path(artifact_dir, "feature_baseline_benchmark.rds")

pipeline_results_path <- file.path(artifact_dir, "pipeline_results.csv")
pipeline_benchmark_path <- file.path(artifact_dir, "pipeline_benchmark.rds")

glmnet_results_path <- file.path(artifact_dir, "glmnet_results.csv")
glmnet_benchmark_path <- file.path(artifact_dir, "glmnet_benchmark.rds")
