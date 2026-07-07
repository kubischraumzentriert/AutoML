rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(tidyverse)
  library(mlr3)
})

source("000_config.R")

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

train <- fread(train_path)

train_small <- train %>%
  as_tibble() %>%
  group_by(.data[[target_col]]) %>%
  slice_sample(prop = subset_fraction) %>%
  ungroup() %>%
  select(-all_of(id_col)) %>%
  mutate(
    across(where(is.character), as.factor),
    !!target_col := as.factor(.data[[target_col]])
  )

task_train_small <- as_task_classif(
  train_small,
  target = target_col,
  id = "health_condition_10pct"
)

saveRDS(task_train_small, task_train_small_path)

cat("=== mlr3 Task gespeichert ===\n")
cat("Pfad:", task_train_small_path, "\n")
print(task_train_small)
cat("\nFeature Types:\n")
print(task_train_small$feature_types)
