# Helpers for safe, read-only snapshots of SQLite source databases.

create_sqlite_snapshot <- function(source_path, snapshot_dir = tempdir()) {
  if (!file.exists(source_path) || dir.exists(source_path)) {
    stop("SQLite-Quelle nicht gefunden: ", source_path, call. = FALSE)
  }
  dir.create(snapshot_dir, recursive = TRUE, showWarnings = FALSE)
  snapshot_path <- tempfile(pattern = "automl_merge_snapshot_", tmpdir = snapshot_dir, fileext = ".db")

  source_con <- tryCatch(
    DBI::dbConnect(RSQLite::SQLite(), source_path),
    error = function(error) {
      stop("SQLite-Quelle konnte nicht geoeffnet werden: ", conditionMessage(error), call. = FALSE)
    }
  )
  on.exit(DBI::dbDisconnect(source_con), add = TRUE)

  vacuum_sql <- paste0("VACUUM INTO ", DBI::dbQuoteString(source_con, snapshot_path))
  tryCatch(
    DBI::dbExecute(source_con, vacuum_sql),
    error = function(error) {
      stop(
        "Konsistenter SQLite-Snapshot konnte nicht erzeugt werden: ",
        conditionMessage(error),
        call. = FALSE
      )
    }
  )
  if (!file.exists(snapshot_path) || file.info(snapshot_path)$size <= 0) {
    stop("SQLite-Snapshot wurde nicht erzeugt: ", snapshot_path, call. = FALSE)
  }

  snapshot_con <- DBI::dbConnect(RSQLite::SQLite(), snapshot_path, flags = RSQLite::SQLITE_RO)
  on.exit(DBI::dbDisconnect(snapshot_con), add = TRUE)
  DBI::dbGetQuery(snapshot_con, "SELECT name FROM sqlite_master LIMIT 1")
  snapshot_path
}
