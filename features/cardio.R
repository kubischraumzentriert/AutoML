add_cardio_features <- function(data) {
  data %>%
    mutate(
      heart_rate_per_bmi = safe_divide(heart_rate, bmi),
      cardio_strain_proxy = heart_rate * bmi,
      calories_per_bmi = safe_divide(calorie_expenditure, bmi)
    )
}
