rm(list = ls())

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
})

# =====================================================================
# merge_project_experiments.R -- konsolidiert die projekteigenen
# experiments.db-Dateien aller ML_Learning-Standalone-Projekte in diese
# zentrale Template-Datenbank, damit sich projektuebergreifende Muster
# per SQL abfragen lassen (z.B. "wie oft hat Tuning den Default
# tatsaechlich geschlagen"), statt nur in README-Prosa.
# =====================================================================
# KANONISCHE VERSION dieses Skripts - liegt hier im Template-Root
# (2026-09-22, Nutzeranregung), NICHT nur als Ad-hoc-Kopie in einzelnen
# ML_Learning-Projektordnern. Frueher hatte jedes Projekt seine eigene
# Kopie mit einer HART CODIERTEN source_db_paths-Liste (z.B. `openml-
# house-prices-regression/merge_project_experiments.R` listete nur
# s6e5/s6e6/s5e12) - bei jedem neuen Projekt musste diese Liste manuell
# erweitert werden, was sie garantiert veralten liess (2026-09-22
# gefunden: 4+ fehlende Projekte - s6e9, 15x openml-cc18-*, Allstate,
# Zindi-Climate-Risk - in der zentralen DB). Diese Version DISKUTIERT
# das strukturell: automatische Verzeichnis-Discovery statt einer Liste,
# die jemand pflegen muesste.
#
# Bewusst NUR die aggregierten Tabellen (project/workflow/run/run_config/
# model_config/resampling/hyperparam/metric_result) - NICHT prediction/
# prediction_prob. Gruende:
# 1. Zeilenebene ist projektspezifisch (row_id/truth/response beziehen sich
#    auf unterschiedliche Datensaetze/Zielspalten) - projektuebergreifend
#    nicht sinnvoll vergleichbar, nur innerhalb EINES Projekts fuer
#    Fehleranalyse (147) relevant.
# 2. prediction/prediction_prob nutzen bewusst lokale INTEGER-Keys
#    (pred_seq/pprob_pred_seq) statt UUIDs (siehe db_schema.sql-Kommentar,
#    Platzgrund) - ein Merge muesste diese Keys umschreiben. Ohne echten
#    Nutzen (Punkt 1) lohnt sich dieser Aufwand nicht.
# Die projekteigenen experiments.db-Dateien bleiben unveraendert und
# behalten ihre vollstaendigen prediction-Daten fuer lokale Fehleranalyse.
#
# Alle uebrigen Tabellen referenzieren sich ausschliesslich ueber UUID-Text-
# Spalten (<praefix>_id) - ein einfaches INSERT SELECT reicht, keine
# Schluessel-Neuvergabe noetig (siehe db_schema.sql-Kopfkommentar).
#
# Idempotent: ein Projekt (per proj_name) wird nur gemergt, wenn es in der
# Ziel-DB noch nicht existiert - mehrfaches Ausfuehren ist gefahrlos.

target_db_path <- file.path(normalizePath(getwd()), "_artifacts", "experiments.db")

# Automatische Discovery statt gepflegter Liste: jede
# <ordner>/_artifacts/experiments.db unterhalb von ML_Learning UND
# unterhalb des MLR3_Regression-Repos (dort koennen ebenfalls
# Standalone-Projekte mit eigener experiments.db liegen), AUSSER der
# Ziel-DB selbst. search_roots so anpassen, falls weitere Fundorte
# dazukommen.
search_roots <- c(
  "C:/Users/HP/ML_Learning",
  "C:/Users/HP/OneDrive/Dokumente/R_Workspace/MLR3_Regression"
)
source_db_paths <- unique(unlist(lapply(search_roots, function(root) {
  if (!dir.exists(root)) return(character(0))
  list.files(root, pattern = "^experiments\\.db$", recursive = TRUE, full.names = TRUE)
})))
source_db_paths <- source_db_paths[normalizePath(source_db_paths, mustWork = FALSE) != normalizePath(target_db_path, mustWork = FALSE)]
names(source_db_paths) <- source_db_paths

# Tabellen in Fremdschluessel-Abhaengigkeitsreihenfolge (Eltern vor Kindern).
merge_tables <- c(
  "project", "workflow", "run", "run_config",
  "model_config", "resampling", "hyperparam", "metric_result"
)

if (!file.exists(target_db_path)) {
  stop("Ziel-DB nicht gefunden: ", target_db_path)
}

cat("Gefundene Quell-DBs (", length(source_db_paths), "):\n", sep = "")
cat(paste(" -", source_db_paths), sep = "\n")
cat("\n")

# Backup der Ziel-DB, bevor irgendetwas geschrieben wird.
backup_path <- sub(
  "\\.db$",
  paste0("_backup_", format(Sys.time(), "%Y%m%dT%H%M%S"), ".db"),
  target_db_path
)
file.copy(target_db_path, backup_path)
cat("Backup der Ziel-DB angelegt:", backup_path, "\n\n")

con <- dbConnect(RSQLite::SQLite(), target_db_path)
dbExecute(con, "PRAGMA foreign_keys = ON;")

existing_projects <- dbGetQuery(con, "SELECT proj_name FROM project")$proj_name

for (source_path in source_db_paths) {
  cat("=== ", source_path, " ===\n", sep = "")

  source_proj_name <- {
    src_con <- dbConnect(RSQLite::SQLite(), source_path)
    proj_name <- tryCatch(dbGetQuery(src_con, "SELECT proj_name FROM project")$proj_name, error = function(e) character(0))
    dbDisconnect(src_con)
    proj_name
  }

  if (length(source_proj_name) == 0) {
    cat("  Keine project-Zeile in der Quelle gefunden, uebersprungen.\n\n")
    next
  }
  if (length(source_proj_name) > 1) {
    cat("  Mehr als 1 project-Zeile in der Quelle (", paste(source_proj_name, collapse = ", "), ") - unerwartet, uebersprungen.\n\n", sep = "")
    next
  }
  if (source_proj_name %in% existing_projects) {
    cat("  Bereits gemergt (proj_name '", source_proj_name, "' existiert schon), uebersprungen.\n\n", sep = "")
    next
  }

  dbExecute(con, sprintf("ATTACH DATABASE '%s' AS src", source_path))

  dbBegin(con)
  tryCatch({
    for (tbl in merge_tables) {
      # Jede Tabelle hat eine lokale INTEGER-PRIMARY-KEY-Spalte (<praefix>_seq,
      # SQLite-rowid-Alias) - die NICHT mitkopiert werden darf (kollidiert
      # sonst mit bereits vorhandenen Zeilen in der Ziel-Tabelle). Alle
      # anderen Spalten haengen an UUID-Text-Schluesseln, die kollisionsfrei
      # sind. Spaltenliste dynamisch aus PRAGMA table_info ermitteln (pk=1
      # markiert die auszuschliessende Spalte) statt hart zu codieren.
      #
      # NUR die SCHNITTMENGE der Spalten von Ziel UND Quelle (Schema-Drift
      # zwischen Projekten ist normal - z.B. hatten aeltere Projektkopien
      # noch kein run_manifest_json/mconf_manifest_json, siehe Kommentar
      # oben). Eine reine Ziel-Spaltenliste wuerde bei jeder fehlenden
      # Quellspalte mit "no such column" abbrechen; fehlende Zielspalten
      # bleiben beim INSERT einfach NULL/Default.
      target_cols <- dbGetQuery(con, sprintf("PRAGMA table_info(%s)", tbl))
      source_cols <- dbGetQuery(con, sprintf("PRAGMA src.table_info(%s)", tbl))
      cols <- intersect(target_cols$name[target_cols$pk == 0], source_cols$name[source_cols$pk == 0])
      col_list <- paste(cols, collapse = ", ")

      n_before <- dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", tbl))$n
      dbExecute(con, sprintf("INSERT INTO %s (%s) SELECT %s FROM src.%s", tbl, col_list, col_list, tbl))
      n_after <- dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", tbl))$n
      cat(sprintf("  %-14s +%d Zeilen (%d -> %d)\n", tbl, n_after - n_before, n_before, n_after))
    }
    dbCommit(con)
    existing_projects <- c(existing_projects, source_proj_name)
    cat("  Gemergt: '", source_proj_name, "'\n\n", sep = "")
  }, error = function(e) {
    dbRollback(con)
    cat("  FEHLER, Merge fuer dieses Projekt zurueckgerollt:", conditionMessage(e), "\n\n")
  })

  dbExecute(con, "DETACH DATABASE src")
}

cat("=== Zusammenfassung Ziel-DB (", target_db_path, ") ===\n", sep = "")
summary_dt <- dbGetQuery(con, "
  SELECT p.proj_name, COUNT(DISTINCT mc.mconf_id) AS n_model_configs, COUNT(mr.mres_id) AS n_metric_results
  FROM project p
  LEFT JOIN workflow wf ON wf.wf_proj_id = p.proj_id
  LEFT JOIN run r ON r.run_wf_id = wf.wf_id
  LEFT JOIN model_config mc ON mc.mconf_run_id = r.run_id
  LEFT JOIN metric_result mr ON mr.mres_mconf_id = mc.mconf_id
  GROUP BY p.proj_name
  ORDER BY p.proj_name
")
print(summary_dt)

dbDisconnect(con)
