# Prepare a leakage-controlled Destatis/DWD classification pilot: does DWD
# weather enrichment improve prediction of next-month road-accident volume
# in Nordrhein-Westfalen?
#
# Source: GENESIS-Online (Destatis) table 46241-0021 "Unfaelle (polizeilich
# erfasste): Bundeslaender, Monate, Unfallkategorie, Ortslage", downloaded
# 2026-09-17 via the public, unauthenticated REST endpoint
# https://genesis.destatis.de/genesis/api/rest/tables/46241-0021/data
# (JSON-stat format; requires an Accept: application/json header and a
# Referer pointing at the table page - both freely settable, no login/API
# key). Frozen locally as source_genesis_46241-0021.json; no live refetch
# happens inside CV/resampling.
#
# This is a genuinely independent project vs. the campsite pilot: different
# data source (Destatis road-accident statistics instead of tourism), a
# different target mechanism (accident volume vs. overnight demand), and a
# third region/station (Nordrhein-Westfalen/Koeln instead of Brandenburg/
# Potsdam or Bayern/Muenchen).

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

source_path <- file.path(project_dir, "source_genesis_46241-0021.json")
dwd_path <- file.path(
  project_dir, "dwd_koeln", "produkt_klima_tag_19570701_20251231_02667.txt"
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

nrw <- as.data.table(grid)[
  DLAND == "05" & VERUK1 == "UNF-PERS" & VEROL1 == "%TOTAL%" & JAHR <= "2025"
]
nrw[, `:=`(
  year = as.integer(JAHR),
  month = as.integer(sub("MONAT", "", MONAT))
)]
nrw[, date := as.IDate(sprintf("%04d-%02d-01", year, month))]
setorder(nrw, date)
setnames(nrw, "value", "accidents_personal_injury")

if (nrow(nrw) != 180 || anyNA(nrw$accidents_personal_injury)) {
  stop(
    "Unerwartete NRW-Zeitreihe (erwartet 180 vollstaendige Monate 2011-2025): ",
    nrow(nrw), " Zeilen, ", sum(is.na(nrw$accidents_personal_injury)), " NA."
  )
}

# The label is next month's accident volume. The threshold is frozen on the
# chronological training portion, not estimated from the test period.
nrw[, target_next_month := shift(accidents_personal_injury, type = "lead")]
split_date <- as.IDate("2022-01-01")
threshold <- median(
  nrw[date < split_date, target_next_month],
  na.rm = TRUE
)
nrw <- nrw[!is.na(target_next_month)]
nrw[, target := factor(
  ifelse(target_next_month >= threshold, "high", "low"),
  levels = c("low", "high")
)]

# Only information available at prediction time is retained: lagged
# accident counts and calendar signals, no current-period leakage.
base <- nrw[, .(
  id = seq_len(.N), date, year, month,
  accidents_personal_injury_lag1 = accidents_personal_injury,
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
  destatis_table_code = "46241-0021",
  destatis_table = "Unfaelle (polizeilich erfasste): Bundeslaender, Monate, Unfallkategorie, Ortslage",
  bundesland = "Nordrhein-Westfalen",
  dwd_station_id = 2667L,
  dwd_station = "Koeln-Bonn",
  target = "high/low next-month Unfaelle mit Personenschaden",
  split_date = as.character(split_date),
  threshold_training_median = threshold,
  baseline_rows = nrow(base),
  weather_match_rate = mean(!is.na(weather$api_temp_mean))
), file.path(project_dir, "pilot_manifest.csv"))

cat("Pilot-Daten erzeugt (Nordrhein-Westfalen/Koeln, Unfaelle mit Personenschaden):\n")
cat("  Baseline:", nrow(base), "Zeilen\n")
cat("  Wetter-Match-Rate:", sprintf("%.1f%%", 100 * mean(!is.na(weather$api_temp_mean))), "\n")
cat("  Schwelle:", threshold, "\n")
