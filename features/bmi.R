add_bmi_features <- function(data) {
  data %>%
    mutate(
      bmi_category = case_when(
        is.na(bmi) ~ NA_character_,
        bmi < 18.5 ~ "underweight",
        bmi < 25 ~ "normal",
        bmi < 30 ~ "overweight",
        TRUE ~ "obesity"
      )
    )
}
