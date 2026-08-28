rm(list = ls())

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
})

# Konsolidiert die projekteigenen experiments.db-Dateien mehrerer
# abgeschlossener Kaggle-Projekte in die zentrale Template-Datenbank, damit
# sich spaeter projektuebergreifende Muster per SQL abfragen lassen (z.B.
# "wie oft hat Tuning den Default tatsaechlich geschlagen", "AUC- vs.
# BAcc-Projekte im Vergleich"), statt nur in README/TEMPLATE_FRICTION-Prosa.
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
#
# Quellen werden AUTOMATISCH unter den bekannten Projekt-Wurzeln gesucht
# (`R_Workspace`, `ML_Learning`), statt eine Liste manuell zu pflegen - eine
# hardcodierte Liste veraltet zuverlaessig (Stand vor dieser Aenderung: nur
# 3 sehr alte Projekte drin, obwohl seither ein Dutzend weitere liefen).
# Die beiden Template-Repos selbst (deren EIGENE `_artifacts/experiments.db`
# das Merge-Ziel bzw. das Pendant fuer Regression ist) werden ausgeschlossen,
# um kein Projekt versehentlich mit sich selbst oder dem falschen Template
# zu mergen.

# target_db_path/project_roots/exclude_dirs/discover_source_db_paths() sind
# nach db_housekeeping.R ausgelagert (P2.1) - dieses Skript UND
# db_housekeeping_check() muessen dieselben Projekte finden, sonst driften
# Diagnose und tatsaechlicher Merge auseinander. Verhalten unveraendert,
# nur an einer Stelle definiert statt dupliziert.
source("db_housekeeping.R")

# Auf "classification" gefiltert (DB-Domain-Trennung, siehe
# db_housekeeping.R/detect_problem_type() und BACKLOG.md "Naechste
# Bewertung 2026-08-28") - Akzeptanzkriterium: "ein Classification-Merge
# kann kein Regression-Projekt aufnehmen". Der Aufgabentyp wird aus den
# bereits geloggten Metrik-Praefixen (`classif.`/`regr.`) der jeweiligen
# Projekt-DB abgeleitet, kein neues Feld noetig.
source_db_paths <- discover_source_db_paths_by_type(project_roots, exclude_dirs, target_db_path, expected_type = "classification")
cat("Gefundene Classification-Quell-DBs (", length(source_db_paths), "):\n", sep = "")
for (nm in names(source_db_paths)) cat("  -", nm, "->", source_db_paths[[nm]], "\n")
cat("\n")

excluded <- attr(source_db_paths, "excluded")
if (!is.null(excluded) && nrow(excluded) > 0) {
  cat("Ausgeschlossen (Regression-Aufgabentyp erkannt, NICHT gemergt):\n")
  print(excluded)
  cat("\n")
}
needs_review <- attr(source_db_paths, "needs_review")
if (!is.null(needs_review) && nrow(needs_review) > 0) {
  cat("Hinweis - unklarer Aufgabentyp, TROTZDEM gemergt (manuell pruefen):\n")
  print(needs_review)
  cat("\n")
}

# Tabellen in Fremdschluessel-Abhaengigkeitsreihenfolge (Eltern vor Kindern),
# mit ihrer jeweiligen UUID-Text-Schluesselspalte (NICHT die lokale
# INTEGER-<praefix>_seq-Spalte - diese ist SQLite-rowid-Alias und darf nicht
# mitkopiert werden, siehe Kommentar unten).
merge_tables <- c(
  project = "proj_id", workflow = "wf_id", run = "run_id", run_config = "rconf_id",
  model_config = "mconf_id", resampling = "rsmp_id", hyperparam = "hparam_id",
  metric_result = "mres_id",
  # P1.2 Evidence Registry (siehe BACKLOG.md): keine FK-Abhaengigkeit zu den
  # Tabellen oben, deshalb an beliebiger Stelle in der Liste einfuegbar -
  # ans Ende gesetzt, um den bestehenden Lauf nicht umzusortieren.
  evidence = "evid_id"
)

if (!file.exists(target_db_path)) {
  stop("Ziel-DB nicht gefunden: ", target_db_path)
}

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

# INKREMENTELL statt "einmal pro Projekt": frueher wurde eine Quelle komplett
# uebersprungen, sobald ihr proj_name schon IRGENDWANN gemergt worden war -
# das verbarg neue Runs, die LOKAL nach diesem ersten Merge dazukamen (Fund
# 2026-08-14: `openml-satimage-multiclass` hatte lokal 6 Runs, zentral nur
# die ersten 3 vom Erst-Merge im Juli - 3 neuere Runs aus dieser Session
# blieben unsichtbar, "Bereits vollstaendig gemergt" war fuer den PROJEKT-
# NAMEN korrekt, aber irrefuehrend fuer den tatsaechlichen Dateninhalt).
# Jetzt: JEDE Quelle wird immer verarbeitet, aber pro Tabelle nur Zeilen
# eingefuegt, deren UUID-Schluessel im Ziel noch NICHT existiert (siehe
# merge_tables oben) - idempotent UND inkrementell in einem, ohne
# proj_name-basierte Vorab-Pruefung.
for (project_label in names(source_db_paths)) {
  source_path <- source_db_paths[[project_label]]

  cat("=== ", project_label, " ===\n", sep = "")

  if (!file.exists(source_path)) {
    cat("  Quelle fehlt, uebersprungen:", source_path, "\n\n")
    next
  }

  dbExecute(con, sprintf("ATTACH DATABASE '%s' AS src", source_path))

  dbBegin(con)
  tryCatch({
    any_new <- FALSE
    for (tbl in names(merge_tables)) {
      id_col <- merge_tables[[tbl]]
      # Spaltenliste dynamisch aus PRAGMA table_info ermitteln (pk=1
      # markiert die auszuschliessende lokale INTEGER-<praefix>_seq-Spalte,
      # SQLite-rowid-Alias, NICHT mitkopieren - kollidiert sonst mit
      # bereits vorhandenen Zeilen).
      col_info <- dbGetQuery(con, sprintf("PRAGMA table_info(%s)", tbl))
      cols <- col_info$name[col_info$pk == 0]
      col_list <- paste(cols, collapse = ", ")

      n_before <- dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", tbl))$n
      dbExecute(con, sprintf(
        "INSERT INTO %s (%s) SELECT %s FROM src.%s WHERE %s NOT IN (SELECT %s FROM %s)",
        tbl, col_list, col_list, tbl, id_col, id_col, tbl
      ))
      n_after <- dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", tbl))$n
      if (n_after > n_before) any_new <- TRUE
      cat(sprintf("  %-14s +%d Zeilen (%d -> %d)\n", tbl, n_after - n_before, n_before, n_after))
    }
    dbCommit(con)
    if (any_new) cat("  Gemergt (inkl. neuer Zeilen).\n\n") else cat("  Keine neuen Zeilen (bereits aktuell).\n\n")
  }, error = function(e) {
    dbRollback(con)
    cat("  FEHLER, Merge fuer diese Quelle zurueckgerollt:", conditionMessage(e), "\n\n")
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
