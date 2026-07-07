rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(tidyverse)
  library(mlr3)
})

source("000_config.R")

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

safe_divide <- function(numerator, denominator) {
  if_else(
    is.na(numerator) | is.na(denominator) | denominator == 0,
    NA_real_,
    numerator / denominator
  )
}

add_health_features <- function(data) {
  data %>%
    mutate(
      bmi_category = case_when(
        is.na(bmi) ~ NA_character_,
        bmi < 18.5 ~ "underweight",
        bmi < 25 ~ "normal",
        bmi < 30 ~ "overweight",
        TRUE ~ "obesity"
      ),
      sleep_deficit_7h = pmax(0, 7 - sleep_duration),
      sleep_excess_9h = pmax(0, sleep_duration - 9),
      sleep_distance_from_8h = abs(sleep_duration - 8),
      steps_per_exercise_min = safe_divide(step_count, exercise_duration),
      calories_per_step = safe_divide(calorie_expenditure, step_count),
      calories_per_exercise_min = safe_divide(calorie_expenditure, exercise_duration),
      calories_per_bmi = safe_divide(calorie_expenditure, bmi),
      water_per_1000_calories = safe_divide(water_intake * 1000, calorie_expenditure),
      water_per_exercise_min = safe_divide(water_intake, exercise_duration),
      heart_rate_per_bmi = safe_divide(heart_rate, bmi),
      cardio_strain_proxy = heart_rate * bmi,
      steps_per_sleep_hour = safe_divide(step_count, sleep_duration),
      exercise_per_sleep_hour = safe_divide(exercise_duration, sleep_duration),
      stress_sleep_quality = str_c(stress_level, sleep_quality, sep = "__"),
      activity_smoking_alcohol = str_c(physical_activity_level, smoking_alcohol, sep = "__"),
      diet_activity = str_c(diet_type, physical_activity_level, sep = "__")
    )
}

train <- fread(train_path)

train_small_features <- train %>%
  as_tibble() %>%
  group_by(.data[[target_col]]) %>%
  slice_sample(prop = subset_fraction) %>%
  ungroup() %>%
  select(-all_of(id_col)) %>%
  add_health_features() %>%
  mutate(
    across(where(is.character), as.factor),
    !!target_col := as.factor(.data[[target_col]])
  )

task_train_small_features <- as_task_classif(
  train_small_features,
  target = target_col,
  id = "health_condition_10pct_features"
)

saveRDS(task_train_small_features, task_train_small_features_path)

cat("=== Feature Engineering Task gespeichert ===\n")
cat("Pfad:", task_train_small_features_path, "\n")
print(task_train_small_features)
cat("\nNeue Features:\n")
print(setdiff(names(train_small_features), names(train)))
