add_hydration_features <- function(data) {
  data %>%
    mutate(
      water_per_1000_calories = safe_divide(water_intake * 1000, calorie_expenditure),
      water_per_exercise_min = safe_divide(water_intake, exercise_duration)
    )
}
