rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(tidyverse)
  library(mlr3)
})

source("000_config.R")
source(file.path(project_dir, "features", "utils.R"))
source(file.path(project_dir, "features", "bmi.R"))
source(file.path(project_dir, "features", "sleep.R"))
source(file.path(project_dir, "features", "activity.R"))
source(file.path(project_dir, "features", "hydration.R"))
source(file.path(project_dir, "features", "cardio.R"))
source(file.path(project_dir, "features", "interactions.R"))

dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

feature_family_functions <- list(
  bmi = add_bmi_features,
  sleep = add_sleep_features,
  activity = add_activity_features,
  hydration = add_hydration_features,
  cardio = add_cardio_features,
  interactions = add_interaction_features
)

train <- fread(train_path)

build_stratified_subset <- function(train) {
  train %>%
    as_tibble() %>%
    group_by(.data[[target_col]]) %>%
    slice_sample(prop = subset_fraction) %>%
    ungroup() %>%
    select(-all_of(id_col))
}

finalize_task <- function(data, id) {
  data <- data %>%
    mutate(
      across(where(is.character), as.factor),
      !!target_col := as.factor(.data[[target_col]])
    )

  # BUGFIX (2026-09-01, gefunden im s6e9-Projekt): fehlte bisher hier,
  # unbemerkt weil health_condition (3-Klassen, positive_class=NULL) davon
  # nicht betroffen ist. Bei einer binaeren Aufgabe mit gesetzter
  # positive_class waehlte mlr3 sonst die erste Faktorstufe als "positiv"
  # statt der konfigurierten Klasse - inkonsistent mit 020_task.R, das
  # dieselbe Logik bereits richtig anwendet. Ohne diesen Fix wuerden die
  # "features"/"selected"-Feature-Set-Tasks (036/037/070/155 etc.) mit
  # einer ANDEREN positiven Klasse arbeiten als "raw" (020_task.R) -
  # AUC bleibt dabei zufaellig unveraendert (symmetrisch bei Tausch der
  # positiven Klasse), aber eine finale Submission auf einem dieser
  # Feature-Sets wuerde P(falsche Klasse) statt P(target_col) ausgeben.
  task_args <- list(data, target = target_col, id = id)
  if (!is.null(positive_class) && nlevels(data[[target_col]]) == 2) {
    task_args$positive <- positive_class
  }
  enable_class_stratification(do.call(as_task_classif, task_args))
}

cat("=== Feature-Family Tasks ===\n")

for (family in feature_families) {
  set.seed(seed)
  raw_subset <- build_stratified_subset(train)
  featured <- feature_family_functions[[family]](raw_subset)
  task <- finalize_task(featured, id = paste0(task_id_prefix, "_", family))
  saveRDS(task, task_train_small_feature_family_path(family))

  cat("Familie:", family, "\n")
  cat("  Pfad       :", task_train_small_feature_family_path(family), "\n")
  cat("  Neue Features:", paste(setdiff(names(featured), names(raw_subset)), collapse = ", "), "\n")
}

build_combined_features <- function(families) {
  set.seed(seed)
  raw_subset <- build_stratified_subset(train)
  Reduce(
    function(data, family) feature_family_functions[[family]](data),
    families,
    raw_subset
  )
}

train_small_features <- build_combined_features(feature_families)
task_train_small_features <- finalize_task(
  train_small_features,
  id = paste0(task_id_prefix, "_features")
)
saveRDS(task_train_small_features, task_train_small_features_path)

cat("\n=== Kombinierter Feature Task gespeichert ===\n")
cat("Pfad:", task_train_small_features_path, "\n")
print(task_train_small_features)
cat("\nNeue Features (kombiniert):\n")
print(setdiff(names(train_small_features), names(train)))

train_small_features_selected <- build_combined_features(selected_families)
task_train_small_features_selected <- finalize_task(
  train_small_features_selected,
  id = paste0(task_id_prefix, "_selected")
)
saveRDS(task_train_small_features_selected, task_train_small_features_selected_path)

cat("\n=== Ausgewaehlter Feature Task gespeichert (", paste(selected_families, collapse = "+"), ") ===\n")
cat("Pfad:", task_train_small_features_selected_path, "\n")
print(task_train_small_features_selected)
cat("\nNeue Features (ausgewaehlt):\n")
print(setdiff(names(train_small_features_selected), names(train)))
