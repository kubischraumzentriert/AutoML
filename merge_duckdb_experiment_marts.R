# =====================================================================
# merge_duckdb_experiment_marts.R -- projektuebergreifender DuckDB-Mart
# =====================================================================
# Ergaenzt 170_build_duckdb_experiment_mart.R (projekt-lokal) um die in
# REFERENZ_DUCKDB_EXPERIMENT_MART.md Abschnitt 4 vorgesehene Variante
# "template_experiment_mart.duckdb": sammelt `_artifacts/*_results.csv`
# ueber ALLE Projekte hinweg (R_Workspace/ML_Learning-Wurzeln, gleiche
# Auto-Discovery wie merge_project_experiments.R/
# check_project_script_coverage.R - Projekt = Ordner mit `000_config.R`).
#
# Schema-Drift zwischen Projekten (z.B. class_weight_results.csv hat eine
# zusaetzliche weight_power-Spalte, manche Projekte nutzen classif.auc statt
# classif.bacc) wird ueber DuckDBs read_csv_auto(union_by_name=TRUE) geloest
# - fehlende Spalten werden NULL statt eines Fehlers. `filename=TRUE` liefert
# den Ursprungspfad, aus dem der Projektname abgeleitet wird (siehe
# REFERENZ_DUCKDB_EXPERIMENT_MART.md Abschnitt 11: project_name/source_file
# muessen bei projektuebergreifenden Marts immer mitgeschrieben werden).
#
# Bewusst NUR die *_results.csv-Familie (wie 170) - Rohdaten/Modell-RDS
# bleiben aussen vor, das ist eine Analyse-, keine Backup-Schicht.
if (!requireNamespace("duckdb", quietly = TRUE)) {
  stop(
    "Paket 'duckdb' ist nicht installiert - dieses Skript ist bewusst ",
    "optional (siehe REFERENZ_DUCKDB_EXPERIMENT_MART.md). ",
    "install.packages('duckdb') ausfuehren, dann erneut versuchen."
  )
}

suppressPackageStartupMessages({
  library(DBI)
  library(duckdb)
  library(data.table)
})

project_roots <- c(
  "C:/Users/HP/OneDrive/Dokumente/R_Workspace",
  "C:/Users/HP/ML_Learning"
)

# Laeuft mit dem Template-Root als Arbeitsverzeichnis (gleiche Konvention
# wie merge_project_experiments.R/check_project_script_coverage.R) -
# relativer Pfad reicht.
dir.create("_artifacts", showWarnings = FALSE, recursive = TRUE)
mart_path <- "_artifacts/template_experiment_mart.duckdb"

discover_project_dirs <- function(roots) {
  found <- unlist(lapply(roots, function(root) {
    if (!dir.exists(root)) return(character(0))
    list.dirs(root, recursive = FALSE)
  }))
  found <- unique(normalizePath(found, winslash = "/", mustWork = FALSE))
  found[file.exists(file.path(found, "000_config.R"))]
}

project_dirs <- discover_project_dirs(project_roots)
cat("=== Projektuebergreifender DuckDB-Mart ===\n")
cat(length(project_dirs), "Projekte gefunden (Ordner mit 000_config.R)\n\n")

# Alle *_results.csv je Projekt einsammeln, gruppiert nach TABELLENNAME
# (Dateiname ohne .csv) - eine Gruppe pro Skripttyp ueber alle Projekte.
csv_by_table <- list()
for (pdir in project_dirs) {
  artifact_dir_p <- file.path(pdir, "_artifacts")
  if (!dir.exists(artifact_dir_p)) next
  csvs <- list.files(artifact_dir_p, pattern = "_results\\.csv$", full.names = TRUE)
  for (f in csvs) {
    tbl_name <- tools::file_path_sans_ext(basename(f))
    csv_by_table[[tbl_name]] <- c(csv_by_table[[tbl_name]], normalizePath(f, winslash = "/"))
  }
}

cat(length(csv_by_table), "verschiedene Tabellennamen ueber alle Projekte gefunden.\n\n")

con <- dbConnect(duckdb::duckdb(), dbdir = mart_path)
on.exit(dbDisconnect(con, shutdown = TRUE), add = TRUE)

table_names <- character(0)
for (tbl_name in names(csv_by_table)) {
  files <- csv_by_table[[tbl_name]]
  # union_by_name: Spalten werden nach NAME abgeglichen (nicht Position),
  # fehlende Spalten in einer Datei werden NULL statt Fehler. filename=TRUE
  # liefert den Quellpfad je Zeile.
  dbExecute(con, sprintf(
    "CREATE OR REPLACE TABLE %s AS
     SELECT
       regexp_extract(filename, '([^/]+)/_artifacts/[^/]+$', 1) AS project,
       * EXCLUDE (filename)
     FROM read_csv_auto(?, union_by_name = TRUE, filename = TRUE)",
    dbQuoteIdentifier(con, tbl_name)
  ), params = list(list(files)))
  n_projects <- length(unique(dbGetQuery(con, sprintf("SELECT DISTINCT project FROM %s", dbQuoteIdentifier(con, tbl_name)))$project))
  cat(sprintf(" - %-40s %d Datei(en) aus %d Projekt(en)\n", tbl_name, length(files), n_projects))
  table_names <- c(table_names, tbl_name)
}

# --- Normalisierte Langformat-View (identisch zur Logik in 170) ------------
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
        "SELECT project, '%s' AS source_table, task_id, learner_id, resampling_id, '%s' AS metric, %s AS value, %s AS elapsed_seconds FROM %s",
        tbl, mc, dbQuoteIdentifier(con, mc),
        if (has_elapsed) "elapsed_seconds" else "NULL",
        dbQuoteIdentifier(con, tbl)
      )
    }, character(1))
    paste(unpivot_parts, collapse = " UNION ALL ")
  }, character(1))

  dbExecute(con, paste("CREATE OR REPLACE VIEW experiment_metrics AS", paste(union_parts, collapse = " UNION ALL ")))
  cat("\nView 'experiment_metrics' erzeugt aus", length(benchmark_tables), "Tabellen(-familien) ueber alle Projekte.\n")
}

# --- Kurzer Cross-Projekt-Report --------------------------------------------
if (length(benchmark_tables) > 0) {
  cat("\n=== Report: bestes BAcc je Projekt ===\n")
  print(dbGetQuery(con, "
    SELECT project, MAX(value) AS best_bacc
    FROM experiment_metrics
    WHERE metric = 'classif.bacc'
    GROUP BY project
    ORDER BY best_bacc DESC
  "))

  cat("\n=== Report: welche Algorithmen gewinnen wie oft (nach classif.bacc, je Projekt) ===\n")
  print(dbGetQuery(con, "
    WITH ranked AS (
      SELECT project, learner_id, value,
             RANK() OVER (PARTITION BY project ORDER BY value DESC) AS rnk
      FROM experiment_metrics
      WHERE metric = 'classif.bacc'
    )
    SELECT learner_id, COUNT(DISTINCT project) AS n_projects_won
    FROM ranked
    WHERE rnk = 1
    GROUP BY learner_id
    ORDER BY n_projects_won DESC
  "))
}

cat("\nGespeichert:", mart_path, "\n")
