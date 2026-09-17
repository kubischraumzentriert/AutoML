# =====================================================================
# test-dwd_weather_adapter.R -- deterministische DWD-Adaptertests
# =====================================================================

source(testthat::test_path("..", "..", "modules", "agridatasets_adapter.R"))
source(testthat::test_path("..", "..", "modules", "dwd_weather_adapter.R"))

test_that("DWD-Quellenkatalog enthaelt die drei vorgesehenen Quellen", {
  catalog <- dwd_weather_source_catalog()
  expect_equal(catalog$source_id, c("rdwd", "dwd_cdc_stations", "dwd_cdc_grids"))
  expect_true(all(grepl("https://", catalog$url, fixed = TRUE)))
  expect_true(all(catalog$license == "CC BY 4.0" | catalog$license == "DWD-Daten: CC BY 4.0"))
})

test_that("rdwd-Verfuegbarkeit liefert einen booleschen Wert", {
  expect_type(dwd_weather_adapter_available(), "logical")
  expect_length(dwd_weather_adapter_available(), 1)
})

test_that("validate_dwd_weather_table() akzeptiert eindeutige Stationstage", {
  weather <- data.frame(
    station_id = c("A", "A"),
    date = as.Date(c("2024-05-01", "2024-05-02")),
    rainfall = c(2, 0)
  )
  expect_invisible(validate_dwd_weather_table(weather))
})

test_that("validate_dwd_weather_table() lehnt doppelte Stationstage ab", {
  weather <- data.frame(
    station_id = c("A", "A"),
    date = as.Date(c("2024-05-01", "2024-05-01")),
    rainfall = c(2, 0)
  )
  expect_error(validate_dwd_weather_table(weather), "doppelte")
})

test_that("select_nearest_dwd_station() waehlt deterministisch die naechste Station", {
  locations <- data.frame(location_id = "plot-1", latitude = 50, longitude = 10)
  stations <- data.frame(
    station_id = c("near", "far"),
    latitude = c(50.01, 51), longitude = c(10.01, 11)
  )
  result <- select_nearest_dwd_station(locations, stations)
  expect_equal(result$dwd_station_id, "near")
  expect_lt(result$distance_km, 2)
})

test_that("join_dwd_weather_asof() nutzt keine Wetterdaten aus der Zukunft", {
  base <- data.frame(
    station_id = c("A", "A", "A"),
    event_date = as.Date(c("2024-05-01", "2024-05-02", "2024-05-04")),
    target = c(1, 0, 1)
  )
  weather <- data.frame(
    station_id = c("A", "A", "A"),
    date = as.Date(c("2024-05-01", "2024-05-03", "2024-05-04")),
    rainfall = c(2, 8, 4)
  )

  result <- join_dwd_weather_asof(base, weather, by = "station_id",
                                  event_date_col = "event_date")

  expect_equal(result$dwd_rainfall, c(2, NA, 4))
  expect_equal(attr(result, "dwd_weather_match_rate"), 2 / 3)
})

test_that("join_dwd_weather_asof() kann explizit rueckblickende Lags verwenden", {
  base <- data.frame(station_id = "A", event_date = as.Date("2024-05-02"))
  weather <- data.frame(
    station_id = "A", date = as.Date("2024-05-01"), rainfall = 2
  )
  result <- join_dwd_weather_asof(base, weather, by = "station_id",
                                  event_date_col = "event_date", max_lag_days = 1)
  expect_equal(result$dwd_rainfall, 2)
})

test_that("join_dwd_weather_asof() lehnt Feature-Kollisionen ab", {
  base <- data.frame(station_id = "A", event_date = as.Date("2024-05-01"),
                     dwd_rainfall = 99)
  weather <- data.frame(station_id = "A", date = as.Date("2024-05-01"),
                        rainfall = 2)
  expect_error(
    join_dwd_weather_asof(base, weather, by = "station_id", event_date_col = "event_date"),
    "kollidieren"
  )
})
