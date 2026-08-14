rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(tidyverse)
  library(mlr3)
})

source("000_config.R")
source(file.path(project_dir, "005_benchmark_runtime.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

train <- fread(train_path)
# Auf der vollen Rohspalte, VOR slice_sample()/as.factor() - faengt auch
# Faelle ab, in denen eine kaputte Zeile durch Zufall aus dem
# subset_fraction-Subset herausfaellt (siehe TARGETS.md, "Ranger-Absturz
# bei leerer Zielklasse").
check_target_column(train[[target_col]])

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

# Bei binaeren Aufgaben mit gesetzter positive_class die positive Klasse
# explizit festlegen, damit AUC/PRAUC und die Submission (155) konsistent
# P(positive) verwenden (mlr3 waehlt sonst die erste Faktorstufe). Bei >2
# Klassen oder positive_class = NULL bleibt das mlr3-Default -> unveraendert.
task_args <- list(train_small, target = target_col, id = task_id_prefix)
if (!is.null(positive_class) && nlevels(train_small[[target_col]]) == 2) {
  task_args$positive <- positive_class
}
task_train_small <- do.call(as_task_classif, task_args)
task_train_small <- enable_class_stratification(task_train_small)

saveRDS(task_train_small, task_train_small_path)

cat("=== mlr3 Task gespeichert ===\n")
cat("Pfad:", task_train_small_path, "\n")
print(task_train_small)
cat("\nFeature Types:\n")
print(task_train_small$feature_types)
