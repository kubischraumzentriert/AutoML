library(targets)
library(data.table)
library(mlr3)
library(mlr3learners)
library(mlr3pipelines)
project_dir <- normalizePath(getwd())
source("000_config.R")
source("db_logging.R")
source("provenance.R")
source("modules/submission_contract.R")
source("modules/submission_artifacts.R")
submission_model_name <- "rpart"
make_baseline_learner <- function(base) as_learner(po("imputemedian") %>>% po("imputemode") %>>% base)
expressions <- as.list(parse("production_targets.R"))
production <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("list")), expressions)[[1]]
nodes <- Filter(function(expr) is.call(expr) && identical(expr[[1]], as.name("tar_target")) &&
  as.character(expr[[2]]) %in% c("final_model_artifacts", "submission"), as.list(production)[-1])
c(list(
  tar_target(bundle_file, file.path(artifact_dir, "model.rds"), format = "file"),
  tar_target(bundle, readRDS(bundle_file)),
  tar_target(final_model_full, bundle$learner),
  tar_target(full_feature_levels, bundle$feature_levels),
  tar_target(task_full_weighted, readRDS("task.rds")),
  tar_target(test_file, test_path, format = "file"),
  tar_target(sample_submission_file, sample_submission_path, format = "file")
), lapply(nodes, eval))
