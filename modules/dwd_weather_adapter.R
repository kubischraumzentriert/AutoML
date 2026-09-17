# =====================================================================
# dwd_weather_adapter.R -- optionale DWD-Wetteranreicherung
#
# Der Adapter arbeitet nur auf lokal eingefrorenen Wetterdaten. Der
# Download ueber rdwd/DWD wird bewusst davor ausgefuehrt, damit CV-Laeufe
# keine bewegliche externe Quelle verwenden. Alle zeitlichen Joins sind
# rueckblickend (as-of) und koennen keine Wetterdaten aus der Zukunft nutzen.
# =====================================================================

dwd_weather_source_catalog <- function() {
  data.frame(
    source_id = c("rdwd", "dwd_cdc_stations", "dwd_cdc_grids"),
    role = c(
      "R-Zugriff und Auswahlhilfe",
      "Historische Stationsbeobachtungen",
      "Historische Raster- und Radardaten"
    ),
    spatial_temporal = c(
      "wrapper; Aufloesung wird von der gewaehlten DWD-Datei bestimmt",
      "Station; 1 Minute bis Tages-/Monatsdaten",
      "Raster; unter anderem 5-Minuten-, Stunden- und Tagesdaten"
    ),
    url = c(
      "https://brry.github.io/rdwd/index.html",
      "https://opendata.dwd.de/climate_environment/CDC/observations_germany/",
      "https://opendata.dwd.de/climate_environment/CDC/grids_germany/"
    ),
    license = c("DWD-Daten: CC BY 4.0", "CC BY 4.0", "CC BY 4.0"),
    stringsAsFactors = FALSE
  )
}

dwd_weather_adapter_available <- function(min_version = "1.9.17") {
  if (!requireNamespace("rdwd", quietly = TRUE)) return(FALSE)
  tryCatch(
    utils::packageVersion("rdwd") >= as.package_version(min_version),
    error = function(e) FALSE
  )
}

validate_dwd_weather_table <- function(weather_data, station_col = "station_id",
                                        date_col = "date") {
  if (!is.data.frame(weather_data) || nrow(weather_data) == 0L) {
    stop("weather_data muss ein nicht-leeres data.frame sein.", call. = FALSE)
  }
  required <- c(station_col, date_col)
  missing <- setdiff(required, names(weather_data))
  if (length(missing) > 0L) {
    stop(sprintf("weather_data fehlen: %s", paste(missing, collapse = ", ")), call. = FALSE)
  }
  weather_dates <- as.Date(weather_data[[date_col]])
  if (anyNA(weather_dates)) {
    stop("weather_data enthaelt nicht lesbare oder fehlende Wetterdaten.", call. = FALSE)
  }
  key <- do.call(paste, c(weather_data[c(station_col)], list(as.character(weather_dates), sep = "\r")))
  if (anyDuplicated(key)) {
    stop("weather_data hat doppelte Station-/Datums-Schluessel.", call. = FALSE)
  }
  invisible(TRUE)
}

haversine_distance_km <- function(lat1, lon1, lat2, lon2) {
  earth_radius_km <- 6371.0088
  radians <- pi / 180
  d_lat <- (lat2 - lat1) * radians
  d_lon <- (lon2 - lon1) * radians
  a <- sin(d_lat / 2)^2 + cos(lat1 * radians) * cos(lat2 * radians) * sin(d_lon / 2)^2
  2 * earth_radius_km * asin(pmin(1, sqrt(a)))
}

select_nearest_dwd_station <- function(locations, stations,
                                       location_id_col = "location_id",
                                       station_id_col = "station_id",
                                       lat_col = "latitude", lon_col = "longitude") {
  required_locations <- c(location_id_col, lat_col, lon_col)
  required_stations <- c(station_id_col, lat_col, lon_col)
  missing_locations <- setdiff(required_locations, names(locations))
  missing_stations <- setdiff(required_stations, names(stations))
  if (length(missing_locations) > 0L || length(missing_stations) > 0L) {
    stop("locations/stations benoetigen IDs sowie latitude und longitude.", call. = FALSE)
  }
  if (anyNA(locations[c(lat_col, lon_col)]) || anyNA(stations[c(lat_col, lon_col)])) {
    stop("Koordinaten fuer die Stationsauswahl duerfen nicht fehlen.", call. = FALSE)
  }
  if (anyDuplicated(stations[[station_id_col]])) {
    stop("stations muss pro station_id genau eine Koordinate enthalten.", call. = FALSE)
  }

  result <- lapply(seq_len(nrow(locations)), function(i) {
    distance <- haversine_distance_km(
      locations[[lat_col]][i], locations[[lon_col]][i],
      stations[[lat_col]], stations[[lon_col]]
    )
    best <- which.min(distance)
    data.frame(
      location_id = locations[[location_id_col]][i],
      dwd_station_id = stations[[station_id_col]][best],
      distance_km = unname(distance[best]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, result)
}

join_dwd_weather_asof <- function(base_data, weather_data, by,
                                   event_date_col, weather_date_col = "date",
                                   max_lag_days = 0L, feature_prefix = "dwd_") {
  if (!is.data.frame(base_data) || nrow(base_data) == 0L) {
    stop("base_data muss ein nicht-leeres data.frame sein.", call. = FALSE)
  }
  if (!is.character(by) || length(by) == 0L || any(!nzchar(by))) {
    stop("by muss mindestens eine Join-Spalte enthalten.", call. = FALSE)
  }
  required_base <- c(by, event_date_col)
  missing_base <- setdiff(required_base, names(base_data))
  missing_weather <- setdiff(c(by, weather_date_col), names(weather_data))
  if (length(missing_base) > 0L || length(missing_weather) > 0L) {
    stop("base_data/weather_data fehlen Join- oder Datumsspalten.", call. = FALSE)
  }
  if (!is.numeric(max_lag_days) || length(max_lag_days) != 1L ||
      is.na(max_lag_days) || max_lag_days < 0) {
    stop("max_lag_days muss eine nicht-negative Zahl sein.", call. = FALSE)
  }
  if (!is.character(feature_prefix) || length(feature_prefix) != 1L ||
      is.na(feature_prefix) || !nzchar(feature_prefix)) {
    stop("feature_prefix muss ein nicht-leerer String sein.", call. = FALSE)
  }

  validate_external_join_key(base_data, by, "base_data")
  validate_dwd_weather_table(weather_data, station_col = by, date_col = weather_date_col)
  event_dates <- as.Date(base_data[[event_date_col]])
  if (anyNA(event_dates)) stop("base_data enthaelt nicht lesbare Event-Daten.", call. = FALSE)

  weather_dates <- as.Date(weather_data[[weather_date_col]])
  base_key <- do.call(paste, c(base_data[by], list(sep = "\r")))
  weather_key <- do.call(paste, c(weather_data[by], list(sep = "\r")))
  selected <- rep(NA_integer_, nrow(base_data))
  for (i in seq_len(nrow(base_data))) {
    candidates <- which(
      weather_key == base_key[i] &
        weather_dates <= event_dates[i] &
        weather_dates >= event_dates[i] - max_lag_days
    )
    if (length(candidates) > 0L) {
      selected[i] <- candidates[which.max(weather_dates[candidates])]
    }
  }

  feature_names <- setdiff(names(weather_data), c(by, weather_date_col))
  if (length(feature_names) == 0L) {
    stop("weather_data muss mindestens eine Wetter-Feature-Spalte enthalten.", call. = FALSE)
  }
  output_names <- paste0(feature_prefix, feature_names)
  if (anyDuplicated(output_names) || any(output_names %in% names(base_data))) {
    stop("Benannte DWD-Features kollidieren mit base_data.", call. = FALSE)
  }
  result <- base_data
  for (j in seq_along(feature_names)) {
    result[[output_names[j]]] <- weather_data[[feature_names[j]]][selected]
  }
  attr(result, "dwd_weather_match_rate") <- mean(!is.na(selected))
  attr(result, "dwd_weather_max_lag_days") <- max_lag_days
  result
}
