add_activity_features <- function(data) {
  data %>%
    mutate(
      steps_per_exercise_min = safe_divide(step_count, exercise_duration),
      calories_per_step = safe_divide(calorie_expenditure, step_count),
      calories_per_exercise_min = safe_divide(calorie_expenditure, exercise_duration),
      steps_per_sleep_hour = safe_divide(step_count, sleep_duration),
      exercise_per_sleep_hour = safe_divide(exercise_duration, sleep_duration)
    )
}
