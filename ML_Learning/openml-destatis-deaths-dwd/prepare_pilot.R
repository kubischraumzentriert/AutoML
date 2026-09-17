# Prepare a leakage-controlled Destatis/DWD classification pilot: does DWD
# weather enrichment improve prediction of next-month death counts in
# Sachsen? Motivation: excess winter mortality (cold months associate with
# higher deaths, mainly cardiovascular/respiratory) is a documented
# mechanism, distinct from the campsite (tourism demand) and accident
# (road-safety) pilots.
#
# Source: GENESIS-Online (Destatis) table 12613-0012 "Gestorbene:
# Bundeslaender, Monate", downloaded 2026-09-17 via the same public,
# unauthenticated REST endpoint used for the accident pilot (see that
# project's prepare_pilot.R header for the request details). Frozen locally
# as source_genesis_12613-0012.json; no live refetch inside CV/resampling.
#
# Third independent project (after campsite/tourism and Verkehrsunfaelle/
# road-accidents): different data source, different target mechanism, and a
# fourth region/station (Sachsen/Dresden - not yet used by the other
# pilots).

suppressPackageStartupMessages({
  library(data.table)
  library(jsonlite)
})

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
project_dir <- if (length(script_arg)) {
  normalizePath(dirname(sub("^--file=", "", script_arg[[1]])))
} else {
  normalizePath(getwd())
}

source_path <- file.path(project_dir, "source_genesis_12613-0012.json")
dwd_path <- file.path(
  project_dir, "dwd_dresden", "produkt_klima_tag_19340101_20251231_01048.txt"
)
if (!file.exists(source_path) || !file.exists(dwd_path)) {
  stop("GENESIS- oder DWD-Quelldatei fehlt.")
}

raw <- fromJSON(source_path, simplifyVector = FALSE)
ds <- raw$data[[1]]
ids <- unlist(ds$id)
sizes <- unlist(ds$size)
values <- as.numeric(vapply(ds$value, function(v) if (is.null(v)) NA_real_ else v, numeric(1)))

dim_labels <- lapply(ids, function(d) {
  idx <- ds$dimension[[d]]$category$index
  labels <- names(idx)
  labels[order(unlist(idx))]
})
names(dim_labels) <- ids

# JSON-stat value array: the LAST id varies fastest. expand.grid()'s first
# argument varies fastest by default, so passing dimensions in reverse id
# order (last id first) reproduces the same flattening order as `values`.
grid <- do.call(expand.grid, c(
  rev(dim_labels),
  list(KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
))
grid <- grid[, rev(names(grid))]
grid$value <- values

sachsen <- as.data.table(grid)[DLAND == "14" & JAHR >= "2011" & JAHR <= "2025"]
sachsen[, `:=`(
  year = as.integer(JAHR),
  month = as.integer(sub("MONAT", "", MONAT))
)]
sachsen[, date := as.IDate(sprintf("%04d-%02d-01", year, month))]
setorder(sachsen, date)
setnames(sachsen, "value", "deaths")

if (nrow(sachsen) != 180 || anyNA(sachsen$deaths)) {
  stop(
    "Unerwartete Sachsen-Zeitreihe (erwartet 180 vollstaendige Monate 2011-2025): ",
    nrow(sachsen), " Zeilen, ", sum(is.na(sachsen$deaths)), " NA."
  )
}

# The label is next month's death count. The threshold is frozen on the
# chronological training portion, not estimated from the test period.
sachsen[, target_next_month := shift(deaths, type = "lead")]
split_date <- as.IDate("2022-01-01")
threshold <- median(
  sachsen[date < split_date, target_next_month],
  na.rm = TRUE
)
sachsen <- sachsen[!is.na(target_next_month)]
sachsen[, target := factor(
  ifelse(target_next_month >= threshold, "high", "low"),
  levels = c("low", "high")
)]

# Only information available at prediction time is retained: lagged deaths
# and calendar signals, no current-period leakage.
base <- sachsen[, .(
  id = seq_len(.N), date, year, month,
  deaths_lag1 = deaths,
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
  destatis_table_code = "12613-0012",
  destatis_table = "Gestorbene: Bundeslaender, Monate",
  bundesland = "Sachsen",
  dwd_station_id = 1048L,
  dwd_station = "Dresden-Klotzsche",
  target = "high/low next-month Gestorbene",
  split_date = as.character(split_date),
  threshold_training_median = threshold,
  baseline_rows = nrow(base),
  weather_match_rate = mean(!is.na(weather$api_temp_mean))
), file.path(project_dir, "pilot_manifest.csv"))

cat("Pilot-Daten erzeugt (Sachsen/Dresden, Sterbefaelle):\n")
cat("  Baseline:", nrow(base), "Zeilen\n")
cat("  Wetter-Match-Rate:", sprintf("%.1f%%", 100 * mean(!is.na(weather$api_temp_mean))), "\n")
cat("  Schwelle:", threshold, "\n")
