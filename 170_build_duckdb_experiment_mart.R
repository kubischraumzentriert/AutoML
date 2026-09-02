# =====================================================================
# 170_build_duckdb_experiment_mart.R -- lokaler DuckDB-Analyse-Mart
# =====================================================================
# Siehe docs/reference/REFERENZ_DUCKDB_EXPERIMENT_MART.md fuer die volle Begruendung.
# Bewusst OPTIONAL und OHNE Ruecksicht auf die uebrige Pipeline: keine
# _artifacts-CSVs werden veraendert, keine Abhaengigkeit anderer Skripte
# auf diese Datei. Wenn das Paket `duckdb` fehlt, bricht das Skript frueh
# mit einer klaren Meldung ab statt kryptisch.
#
# Schritte (siehe docs/reference/REFERENZ_DUCKDB_EXPERIMENT_MART.md Abschnitt 12):
# 1. Alle `_artifacts/*_results.csv` erkennen.
# 2. Jede CSV als eigene DuckDB-Tabelle registrieren (1:1-Rohspiegel,
#    IMMER moeglich, unabhaengig vom Spaltenschema).
# 3. Aus dem gemeinsamen Spaltenmuster (`task_id`/`learner_id`/
#    `resampling_id`/`classif.*`/`elapsed_seconds` - die Benchmark-Familie:
#    baseline/boosting/tuning-final/feature_family/class_weight/...) eine
#    normalisierte Langformat-View `experiment_metrics` erzeugen. Tabellen
#    mit ANDEREM Schema (Diagnose-Module wie generalization_gap_results,
#    seed_stability_results, ...) bleiben als eigene Rohtabellen bestehen,
#    fliessen aber NICHT in diese View ein - sie sind strukturell zu
#    unterschiedlich fuer ein gemeinsames Long-Format ohne Informations-
#    verlust.
# 4. Optional CSVs nach `_artifacts/parquet/` spiegeln.
# 5. Kurzer Report: Top-Modelle, teure-aber-wirkungslose Laeufe.
rm(list = ls())

if (!requireNamespace("duckdb", quietly = TRUE)) {
  stop(
    "Paket 'duckdb' ist nicht installiert - dieses Skript ist bewusst ",
    "optional (siehe docs/reference/REFERENZ_DUCKDB_EXPERIMENT_MART.md). ",
    "install.packages('duckdb') ausfuehren, dann erneut versuchen."
  )
}

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  library(data.table)
})

source("000_config.R")

mart_path <- file.path(artifact_dir, "experiment_mart.duckdb")
parquet_dir <- file.path(artifact_dir, "parquet")
dir.create(parquet_dir, showWarnings = FALSE, recursive = TRUE)

# --- Schritt 1: CSVs erkennen -----------------------------------------
csv_files <- list.files(artifact_dir, pattern = "_results\\.csv$", full.names = TRUE)
cat("=== DuckDB-Experiment-Mart ===\n")
cat(length(csv_files), "*_results.csv-Dateien gefunden in", artifact_dir, "\n\n")

if (length(csv_files) == 0) {
  cat("Keine passenden CSVs gefunden - nichts zu tun.\n")
  quit(save = "no", status = 0)
}

con <- dbConnect(duckdb::duckdb(), dbdir = mart_path)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

# --- Schritt 2: jede CSV als eigene Rohtabelle registrieren ------------
table_names <- character(0)
for (f in csv_files) {
  tbl_name <- tools::file_path_sans_ext(basename(f))
  # Quotes um den Pfad: Windows-Pfade/Dateinamen mit Sonderzeichen sicher
  # per DuckDB-Parameterbindung statt Sprintf-Interpolation einbetten.
  dbExecute(con, sprintf(
    "CREATE OR REPLACE TABLE %s AS SELECT * FROM read_csv_auto(?)",
    dbQuoteIdentifier(con, tbl_name)
  ), params = list(f))
  table_names <- c(table_names, tbl_name)
}
cat("Tabellen angelegt:\n"); cat(paste(" -", table_names), sep = "\n")

# --- Schritt 3: normalisierte Langformat-View ueber die Benchmark-Familie -
# Erkennung rein ueber Spaltennamen (kein hartcodierter Dateiname), damit
# neue Benchmark-Skripte automatisch erfasst werden, sobald sie demselben
# Schema folgen.
benchmark_tables <- Filter(function(tbl) {
  cols <- dbListFields(con, tbl)
  all(c("task_id", "learner_id", "resampling_id") %in% cols) &&
    any(grepl("^classif\\.", cols))
}, table_names)

if (length(benchmark_tables) > 0) {
  union_parts <- vapply(benchmark_tables, function(tbl) {
    cols <- dbListFields(con, tbl)
    metric_cols <- grep("^classif\\.", cols, value = TRUE)
    has_elapsed <- "elapsed_seconds" %in% cols
    unpivot_parts <- vapply(metric_cols, function(mc) {
      sprintf(
        "SELECT '%s' AS source_table, task_id, learner_id, resampling_id, '%s' AS metric, %s AS value, %s AS elapsed_seconds FROM %s",
        tbl, mc, dbQuoteIdentifier(con, mc),
        if (has_elapsed) "elapsed_seconds" else "NULL",
        dbQuoteIdentifier(con, tbl)
      )
    }, character(1))
    paste(unpivot_parts, collapse = " UNION ALL ")
  }, character(1))

  view_sql <- paste("CREATE OR REPLACE VIEW experiment_metrics AS", paste(union_parts, collapse = " UNION ALL "))
  dbExecute(con, view_sql)
  cat("\nView 'experiment_metrics' erzeugt aus", length(benchmark_tables), "Tabellen (gemeinsames Benchmark-Schema):\n")
  cat(paste(" -", benchmark_tables), sep = "\n")
} else {
  cat("\nKeine Tabelle mit dem gemeinsamen Benchmark-Schema gefunden - 'experiment_metrics' nicht erzeugt.\n")
}

other_tables <- setdiff(table_names, benchmark_tables)
if (length(other_tables) > 0) {
  cat("\nEigenes Schema, nur als Rohtabelle verfuegbar (kein Teil von 'experiment_metrics'):\n")
  cat(paste(" -", other_tables), sep = "\n")
}

# --- Schritt 4: Parquet-Spiegel -----------------------------------------
for (tbl in table_names) {
  dbExecute(con, sprintf(
    "COPY %s TO ? (FORMAT PARQUET)",
    dbQuoteIdentifier(con, tbl)
  ), params = list(file.path(parquet_dir, paste0(tbl, ".parquet"))))
}
cat("\nParquet-Spiegel geschrieben nach", parquet_dir, "(", length(table_names), "Dateien )\n")

# --- Schritt 5: kurzer Report --------------------------------------------
if (length(benchmark_tables) > 0) {
  cat("\n=== Report: Top-5 nach BAcc (aus 'experiment_metrics') ===\n")
  top <- dbGetQuery(con, "
    SELECT source_table, task_id, learner_id, resampling_id, value AS bacc, elapsed_seconds
    FROM experiment_metrics
    WHERE metric = 'classif.bacc'
    ORDER BY value DESC
    LIMIT 5
  ")
  print(top)

  cat("\n=== Report: teuerste Laeufe (elapsed_seconds), ihr BAcc-Rang ===\n")
  expensive <- dbGetQuery(con, "
    WITH ranked AS (
      SELECT source_table, task_id, learner_id, value AS bacc, elapsed_seconds,
             RANK() OVER (ORDER BY value DESC) AS bacc_rank
      FROM experiment_metrics
      WHERE metric = 'classif.bacc' AND elapsed_seconds IS NOT NULL
    )
    SELECT * FROM ranked
    ORDER BY elapsed_seconds DESC
    LIMIT 5
  ")
  print(expensive)
  cat("\nHinweis: ein hoher elapsed_seconds bei gleichzeitig schlechtem bacc_rank\n")
  cat("markiert einen teuren, aber wirkungslosen Lauf - kein automatisches\n")
  cat("Urteil, nur ein Hinweis fuer die manuelle Durchsicht.\n")
}

cat("\nGespeichert:", mart_path, "\n")
cat("Direkter Zugriff (auch ausserhalb R):",
    "duckdb -readonly", shQuote(mart_path), "\n")
