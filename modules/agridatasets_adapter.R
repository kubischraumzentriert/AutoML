# =====================================================================
# agridatasets_adapter.R -- optionale Agrardaten-Quelle
#
# Bewusst kein Pflichtbestandteil der Pipeline: agridatasets liefert
# kuratierte Referenzdaten, aber keine allgemeine Wetter-API. Der Adapter
# erzwingt deshalb explizite Schluessel und verhindert stille many-to-many-
# Joins, bevor externe Features in einen Lauf gelangen.
# =====================================================================

agridatasets_available <- function(min_version = "0.1.1") {
  if (!requireNamespace("agridatasets", quietly = TRUE)) return(FALSE)
  tryCatch(
    utils::packageVersion("agridatasets") >= as.package_version(min_version),
    error = function(e) FALSE
  )
}

load_agridatasets_dataset <- function(dataset_name, min_version = "0.1.1") {
  if (!is.character(dataset_name) || length(dataset_name) != 1L ||
      is.na(dataset_name) || !nzchar(dataset_name)) {
    stop("dataset_name muss genau ein nicht-leerer String sein.", call. = FALSE)
  }
  if (!agridatasets_available(min_version)) {
    stop(
      sprintf(
        "Optionales Paket agridatasets >= %s ist nicht installiert.",
        min_version
      ),
      call. = FALSE
    )
  }

  available <- utils::data(package = "agridatasets")$results[, "Item"]
  if (!(dataset_name %in% available)) {
    stop(sprintf("Unbekannter agridatasets-Datensatz: %s", dataset_name), call. = FALSE)
  }

  target <- new.env(parent = emptyenv())
  utils::data(list = dataset_name, package = "agridatasets", envir = target)
  get(dataset_name, envir = target, inherits = FALSE)
}

validate_external_join_key <- function(data, by, label = "Daten") {
  if (!is.data.frame(data)) stop(sprintf("%s muessen ein data.frame sein.", label), call. = FALSE)
  if (!is.character(by) || length(by) == 0L || anyNA(by) || any(!nzchar(by))) {
    stop("by muss mindestens einen gueltigen Spaltennamen enthalten.", call. = FALSE)
  }
  missing <- setdiff(by, names(data))
  if (length(missing) > 0L) {
    stop(sprintf("%s fehlen die Join-Spalten: %s", label, paste(missing, collapse = ", ")), call. = FALSE)
  }
  if (anyNA(data[by])) {
    stop(sprintf("%s enthalten fehlende Werte im Join-Schluessel.", label), call. = FALSE)
  }
  invisible(TRUE)
}

enrich_with_external_features <- function(base_data, external_data, by,
                                           external_prefix = "ext_") {
  validate_external_join_key(base_data, by, "base_data")
  validate_external_join_key(external_data, by, "external_data")
  if (!is.character(external_prefix) || length(external_prefix) != 1L ||
      is.na(external_prefix) || !nzchar(external_prefix)) {
    stop("external_prefix muss ein nicht-leerer String sein.", call. = FALSE)
  }

  if (anyDuplicated(external_data[by])) {
    stop(
      "external_data hat doppelte Join-Schluessel; ein many-to-many-Join ist nicht erlaubt.",
      call. = FALSE
    )
  }
  feature_names <- setdiff(names(external_data), by)
  if (length(feature_names) == 0L) {
    stop("external_data muss mindestens eine Feature-Spalte ausserhalb von by enthalten.", call. = FALSE)
  }

  renamed_features <- paste0(external_prefix, feature_names)
  if (anyDuplicated(renamed_features) || any(renamed_features %in% names(base_data))) {
    stop("Benannte externe Feature-Spalten kollidieren mit base_data.", call. = FALSE)
  }

  external <- external_data[c(by, feature_names)]
  names(external)[match(feature_names, names(external))] <- renamed_features
  row_id <- seq_len(nrow(base_data))
  joined <- merge(
    data.frame(.agridatasets_row_id = row_id, base_data, check.names = FALSE),
    external,
    by = by,
    all.x = TRUE,
    sort = FALSE
  )
  joined <- joined[order(joined$.agridatasets_row_id), , drop = FALSE]
  joined$.agridatasets_row_id <- NULL
  rownames(joined) <- NULL
  joined
}
