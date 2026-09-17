# Prepare a leakage-controlled OpenML/DWD classification pilot.

suppressPackageStartupMessages({
  library(data.table)
})

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
project_dir <- if (length(script_arg)) {
  normalizePath(dirname(sub("^--file=", "", script_arg[[1]])))
} else {
  normalizePath(getwd())
}
source_path <- file.path(project_dir, "source.arff")
dwd_path <- file.path(
  project_dir, "dwd_potsdam",
  "produkt_klima_tag_18930101_20251231_03987.txt"
)

if (!file.exists(source_path) || !file.exists(dwd_path)) {
  stop("OpenML- oder DWD-Quelldatei fehlt.")
}

openml <- fread(
  source_path,
  skip = "@DATA",
  header = FALSE,
  na.strings = "?",
  strip.white = TRUE
)
openml_names <- c(
  "land", "date", "arrivals", "arrivals_yoy_pct", "overnights",
  "overnights_yoy_pct", "stay_length", "mean_air_temp_max",
  "mean_air_temp_mean", "mean_air_temp_min", "mean_drought_index",
  "mean_evapo_p", "mean_evapo_r", "mean_frost_depth", "mean_precipitation",
  "mean_soil_moist", "mean_soil_temperature_5cm", "mean_sunshine_duration",
  "std_air_temp_max", "std_air_temp_mean", "std_air_temp_min",
  "std_drought_index", "std_evapo_p", "std_evapo_r", "std_frost_depth",
  "std_precipitation", "std_soil_moist", "std_soil_temperature_5cm",
  "std_sunshine_duration", "camping_sites", "holiday_sites",
  "holiday_sites_open", "holiday_pitches", "holiday_pitches_open",
  "change_holiday_pitches_open_yoy", "share_holiday_pitches_open"
)
setnames(openml, openml_names)
openml <- openml[land == "Brandenburg"]
openml[, date := as.IDate(date)]
setorder(openml, date)

# The label is next month's overnight demand. The threshold is frozen on the
# chronological training portion, not estimated from the test period.
openml[, target_next_month := shift(overnights, type = "lead")]
split_date <- as.IDate("2019-01-01")
threshold <- median(
  openml[date < split_date, target_next_month],
  na.rm = TRUE
)
openml <- openml[!is.na(target_next_month)]
openml[, target := factor(
  ifelse(target_next_month >= threshold, "high", "low"),
  levels = c("low", "high")
)]

# Only information available at prediction time is retained. Current-period
# demand variables are explicitly represented as lagged business signals.
base <- openml[, .(
  id = seq_len(.N), date,
  year = as.integer(format(date, "%Y")),
  month = as.integer(format(date, "%m")),
  arrivals_lag1 = arrivals, overnights_lag1 = overnights,
  stay_length, camping_sites, holiday_sites, holiday_sites_open,
  holiday_pitches, holiday_pitches_open,
  target
)]

dwd <- fread(dwd_path, sep = ";", na.strings = "-999", strip.white = TRUE)
dwd[, date := as.IDate(as.character(MESS_DATUM), format = "%Y%m%d")]
dwd[, `:=`(
  year = as.integer(format(date, "%Y")),
  month = as.integer(format(date, "%m")),
  api_temp_mean = TMK, api_temp_max = TXK, api_temp_min = TNK,
  api_precipitation = RSK, api_sunshine = SDK,
  api_humidity = UPM, api_pressure = PM
)]
dwd_monthly <- dwd[, .(
  api_temp_mean = mean(api_temp_mean, na.rm = TRUE),
  api_temp_max = mean(api_temp_max, na.rm = TRUE),
  api_temp_min = mean(api_temp_min, na.rm = TRUE),
  api_precipitation = sum(api_precipitation, na.rm = TRUE),
  api_sunshine = sum(api_sunshine, na.rm = TRUE),
  api_humidity = mean(api_humidity, na.rm = TRUE),
  api_pressure = mean(api_pressure, na.rm = TRUE),
  api_days = .N
), by = .(year, month)]

weather <- merge(base, dwd_monthly, by = c("year", "month"), all.x = TRUE)
setorder(weather, date)
weather[, id := seq_len(.N)]

fwrite(base, file.path(project_dir, "pilot_baseline.csv"))
fwrite(weather, file.path(project_dir, "pilot_weather.csv"))
fwrite(data.table(
  openml_dataset_id = 46263L,
  openml_dataset = "weather_and_campsite_germany",
  dwd_station_id = 3987L,
  dwd_station = "Potsdam",
  target = "high/low next-month overnight demand",
  split_date = as.character(split_date),
  threshold_training_median = threshold,
  baseline_rows = nrow(base),
  weather_match_rate = mean(!is.na(weather$api_temp_mean))
), file.path(project_dir, "pilot_manifest.csv"))

cat("Pilot-Daten erzeugt:\n")
cat("  Baseline:", nrow(base), "Zeilen\n")
cat("  Wetter-Match-Rate:", sprintf("%.1f%%", 100 * mean(!is.na(weather$api_temp_mean))), "\n")
cat("  Schwelle:", threshold, "\n")
