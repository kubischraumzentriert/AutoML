# Prepare a leakage-controlled Destatis/DWD classification pilot: does DWD
# weather enrichment improve prediction of next-month construction-industry
# turnover in Baden-Wuerttemberg? Motivation: outdoor construction work
# (Bauhauptgewerbe) is directly weather-gated - frost/snow halt site work,
# a mechanism distinct from tourism demand, road-accident risk, and winter
# excess mortality used in the other three pilots.
#
# Source: GENESIS-Online (Destatis) table 44111-0003 "Geleistete
# Arbeitsstunden, Baugewerblicher Umsatz im Bauhauptgewerbe (alle Betriebe):
# Bundeslaender, Monate (bis 2016), Bauarten", downloaded 2026-09-17 via the
# same public, unauthenticated REST endpoint used for the other Destatis
# pilots. Frozen locally as source_genesis_44111-0003.json; no live refetch
# inside CV/resampling.
#
# IMPORTANT data-quality note: the regional/monthly breakdown of this table
# was discontinued after 2016 (values are 0, not NA, from 2017 onward - not
# a real "no construction" reading but a discontinued series). The pilot
# therefore uses 1995-2016 instead of the other pilots' 2011-2025 window;
# still 22 full years of monthly data.
#
# Fourth independent project overall (after campsite/tourism, Verkehrsunfaelle/
# road-accidents, Sterbefaelle/mortality): different data source, different
# target mechanism, and a fifth region/station (Baden-Wuerttemberg/Stuttgart -
# not yet used by the other pilots).

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

source_path <- file.path(project_dir, "source_genesis_44111-0003.json")
dwd_path <- file.path(
  project_dir, "dwd_stuttgart", "produkt_klima_tag_19580101_20251231_04928.txt"
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
gdt <- as.data.table(grid)

# BAUAR9 ("Bauarten") has no %TOTAL% category - sum the 7 mutually exclusive
# construction types to get total monthly turnover.
bw_turnover <- gdt[
  DLAND == "08" & content == "UMS009$QMU" & JAHR >= "1995" & JAHR <= "2016",
  .(turnover = sum(value)), by = .(JAHR, MONAT)
]
bw_turnover[, `:=`(
  year = as.integer(JAHR),
  month = as.integer(sub("MONAT", "", MONAT))
)]
bw_turnover[, date := as.IDate(sprintf("%04d-%02d-01", year, month))]
setorder(bw_turnover, date)

if (nrow(bw_turnover) != 264 || anyNA(bw_turnover$turnover)) {
  stop(
    "Unerwartete Baden-Wuerttemberg-Zeitreihe (erwartet 264 vollstaendige Monate 1995-2016): ",
    nrow(bw_turnover), " Zeilen, ", sum(is.na(bw_turnover$turnover)), " NA."
  )
}

# The label is next month's construction turnover. The threshold is frozen
# on the chronological training portion, not estimated from the test period.
bw_turnover[, target_next_month := shift(turnover, type = "lead")]
split_date <- as.IDate("2011-01-01")
threshold <- median(
  bw_turnover[date < split_date, target_next_month],
  na.rm = TRUE
)
bw_turnover <- bw_turnover[!is.na(target_next_month)]
bw_turnover[, target := factor(
  ifelse(target_next_month >= threshold, "high", "low"),
  levels = c("low", "high")
)]

# Only information available at prediction time is retained: lagged
# turnover and calendar signals, no current-period leakage.
base <- bw_turnover[, .(
  id = seq_len(.N), date, year, month,
  turnover_lag1 = turnover,
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
  destatis_table_code = "44111-0003",
  destatis_table = "Baugewerblicher Umsatz im Bauhauptgewerbe: Bundeslaender, Monate (bis 2016), Bauarten",
  bundesland = "Baden-Wuerttemberg",
  dwd_station_id = 4928L,
  dwd_station = "Stuttgart-Schnarrenberg",
  target = "high/low next-month Baugewerblicher Umsatz",
  split_date = as.character(split_date),
  threshold_training_median = threshold,
  baseline_rows = nrow(base),
  weather_match_rate = mean(!is.na(weather$api_temp_mean))
), file.path(project_dir, "pilot_manifest.csv"))

cat("Pilot-Daten erzeugt (Baden-Wuerttemberg/Stuttgart, Baugewerblicher Umsatz):\n")
cat("  Baseline:", nrow(base), "Zeilen\n")
cat("  Wetter-Match-Rate:", sprintf("%.1f%%", 100 * mean(!is.na(weather$api_temp_mean))), "\n")
cat("  Schwelle:", threshold, "\n")
