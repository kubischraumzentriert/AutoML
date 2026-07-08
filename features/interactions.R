add_interaction_features <- function(data) {
  data %>%
    mutate(
      stress_sleep_quality = str_c(stress_level, sleep_quality, sep = "__"),
      activity_smoking_alcohol = str_c(physical_activity_level, smoking_alcohol, sep = "__"),
      diet_activity = str_c(diet_type, physical_activity_level, sep = "__")
    )
}
