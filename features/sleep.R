add_sleep_features <- function(data) {
  data %>%
    mutate(
      sleep_deficit_7h = pmax(0, 7 - sleep_duration),
      sleep_excess_9h = pmax(0, sleep_duration - 9),
      sleep_distance_from_8h = abs(sleep_duration - 8)
    )
}
