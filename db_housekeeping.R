# =====================================================================
# db_housekeeping.R -- P2.1 (ChatGPTs korrigierter Plan): lokaler
# Diagnose-Helfer fuer die zentrale, gemergte Experiment-DB.
# =====================================================================
# db_housekeeping_check() beantwortet "ist ein Merge noetig, und gibt es
# Datenqualitaetsprobleme?", OHNE selbst irgendetwas zu schreiben - ein
# tatsaechlicher Merge bleibt bewusst der explizite, separate Schritt
# `merge_project_experiments.R` (siehe Plan: "Die Diagnose darf keine DB
# veraendern. Ein tatsaechlicher Merge bleibt bewusst explizit.").
#
# `discover_source_db_paths()` UND die Pfad-Konstanten sind aus
# `merge_project_experiments.R` HIERHER verschoben (nicht dupliziert) -
# beide Skripte muessen dieselben Projekte finden, sonst driften Diagnose
# und tatsaechlicher Merge auseinander. `merge_project_experiments.R`
# sourced diese Datei jetzt, statt die Logik ein zweites Mal zu definieren
# (analog zum `target_leak_audit_helpers.R`-Vorbild aus P0.1: Verhalten
# unveraendert, nur an einer Stelle definiert).

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(data.table)
})

target_db_path <- "C:/Users/HP/OneDrive/Dokumente/R_Workspace/MLR3_Classifikation/_artifacts/experiments.db"

project_roots <- c(
  "C:/Users/HP/OneDrive/Dokumente/R_Workspace",
  "C:/Users/HP/ML_Learning"
)
exclude_dirs <- c("MLR3_Classifikation", "MLR3_Regression")

discover_source_db_paths <- function(roots, exclude, target) {
  target_norm <- normalizePath(target, winslash = "/", mustWork = FALSE)
  found <- unlist(lapply(roots, function(root) {
    if (!dir.exists(root)) return(character(0))
    Sys.glob(file.path(root, "*", "_artifacts", "experiments.db"))
  }))
  found <- unique(normalizePath(found, winslash = "/", mustWork = FALSE))
  found <- found[found != target_norm]
  project_dir_name <- basename(dirname(dirname(found)))
  found <- found[!project_dir_name %in% exclude]
  project_dir_name <- basename(dirname(dirname(found)))
  setNames(found, project_dir_name)
}

#' Rein lesende Diagnose der zentralen, gemergten Experiment-DB gegen die
#' aktuell auffindbaren Projekt-DBs - schreibt NIE in eine DB.
#'
#' @param target Pfad zur zentralen Ziel-DB (Default: `target_db_path`).
#' @param sources Benannter Vektor Quell-DB-Pfade (Default: Auto-Discovery
#'   wie in `merge_project_experiments.R`).
#' @return Unsichtbar eine Liste mit den einzelnen Befund-`data.table`s
#'   (`missing_projects`, `new_runs`, `duplicate_metrics`,
#'   `incomplete_runs`, `runs_without_commit`, `backups`) - zusaetzlich
#'   zur Konsolen-Ausgabe fuer eine programmatische Weiterverarbeitung.
db_housekeeping_check <- function(target = target_db_path, sources = NULL) {
  if (!file.exists(target)) {
    stop("Ziel-DB nicht gefunden: ", target, " - erst einen initialen Merge durchfuehren.")
  }
  if (is.null(sources)) {
    sources <- discover_source_db_paths(project_roots, exclude_dirs, target)
  }

  cat("=== DB-Housekeeping-Check (rein lesend, keine Schreibzugriffe) ===\n\n")

  last_merge_time <- file.info(target)$mtime
  cat("Letzte Aenderung der Ziel-DB (Proxy fuer 'letzter Merge'):", format(last_merge_time), "\n\n")

  # flags = SQLITE_RO erzwingt read-only auf DB-Ebene (nicht nur per
  # Konvention "wir rufen halt kein dbExecute() auf") - ein versehentlicher
  # Schreibversuch schlaegt fehl, statt still zu funktionieren.
  con <- dbConnect(RSQLite::SQLite(), target, flags = RSQLite::SQLITE_RO)
  on.exit(dbDisconnect(con))

  target_projects <- dbGetQuery(con, "SELECT proj_id, proj_name FROM project")

  # --- Fehlende Projekte: lokal vorhanden, aber noch nie gemergt --------
  missing_projects <- data.table(project = setdiff(names(sources), target_projects$proj_name))
  if (nrow(missing_projects) > 0) {
    cat("FEHLENDE PROJEKTE (lokale DB existiert, aber noch nie gemergt):\n")
    print(missing_projects)
  } else {
    cat("Keine fehlenden Projekte - jede lokal gefundene Projekt-DB ist mindestens einmal gemergt.\n")
  }
  cat("\n")

  # --- Neue Runs: Projekt bereits gemergt, aber lokal Runs, die die
  # Ziel-DB noch nicht kennt (per run_id) -------------------------------
  new_runs_list <- list()
  for (project_label in intersect(names(sources), target_projects$proj_name)) {
    source_path <- sources[[project_label]]
    if (!file.exists(source_path)) next
    src_con <- dbConnect(RSQLite::SQLite(), source_path, flags = RSQLite::SQLITE_RO)
    src_runs <- tryCatch(
      dbGetQuery(src_con, "
        SELECT r.run_id, r.run_started_at, r.run_git_commit
        FROM run r JOIN workflow wf ON wf.wf_id = r.run_wf_id
        JOIN project p ON p.proj_id = wf.wf_proj_id
        WHERE p.proj_name = ?", params = list(project_label)
      ),
      error = function(e) data.frame()
    )
    dbDisconnect(src_con)
    if (nrow(src_runs) == 0) next
    placeholders <- paste(rep("?", nrow(src_runs)), collapse = ", ")
    known_ids <- dbGetQuery(
      con, sprintf("SELECT run_id FROM run WHERE run_id IN (%s)", placeholders),
      params = as.list(src_runs$run_id)
    )$run_id
    new_ids <- setdiff(src_runs$run_id, known_ids)
    if (length(new_ids) > 0) {
      new_runs_list[[project_label]] <- nrow(src_runs[src_runs$run_id %in% new_ids, ])
    }
  }
  new_runs <- data.table(project = names(new_runs_list), n_new_runs = unlist(new_runs_list, use.names = FALSE))
  if (nrow(new_runs) > 0) {
    cat("NEUE RUNS (lokal vorhanden, in der Ziel-DB noch nicht gemergt):\n")
    print(new_runs)
  } else {
    cat("Keine neuen Runs - alle lokal auffindbaren Runs sind bereits gemergt.\n")
  }
  cat("\n")

  # --- Moegliche Duplikate: mehrere metric_result-Zeilen fuer dieselbe
  # (Model-Config, Metrik, Fold)-Kombination - sollte eindeutig sein, ist
  # aber nicht per DB-Constraint erzwungen. ------------------------------
  duplicate_metrics <- as.data.table(dbGetQuery(con, "
    SELECT mres_mconf_id, mres_measure_name, mres_fold, COUNT(*) AS n
    FROM metric_result
    GROUP BY mres_mconf_id, mres_measure_name, mres_fold
    HAVING COUNT(*) > 1
  "))
  if (nrow(duplicate_metrics) > 0) {
    cat("MOEGLICHE DUPLIKATE (mehrere metric_result-Zeilen fuer dieselbe Model-Config/Metrik/Fold):\n")
    print(duplicate_metrics)
  } else {
    cat("Keine moeglichen Duplikate in metric_result gefunden.\n")
  }
  cat("\n")

  # --- Unvollstaendige Runs: run_finished_at IS NULL (z.B. abgebrochenes
  # Skript) --------------------------------------------------------------
  incomplete_runs <- as.data.table(dbGetQuery(con, "
    SELECT p.proj_name, wf.wf_name, r.run_id, r.run_started_at
    FROM run r
    JOIN workflow wf ON wf.wf_id = r.run_wf_id
    JOIN project p ON p.proj_id = wf.wf_proj_id
    WHERE r.run_finished_at IS NULL
    ORDER BY r.run_started_at
  "))
  if (nrow(incomplete_runs) > 0) {
    cat("UNVOLLSTAENDIGE RUNS (run_finished_at IS NULL):\n")
    print(incomplete_runs)
  } else {
    cat("Keine unvollstaendigen Runs.\n")
  }
  cat("\n")

  # --- Runs ohne Git Commit ---------------------------------------------
  runs_without_commit <- as.data.table(dbGetQuery(con, "
    SELECT p.proj_name, wf.wf_name, r.run_id, r.run_started_at
    FROM run r
    JOIN workflow wf ON wf.wf_id = r.run_wf_id
    JOIN project p ON p.proj_id = wf.wf_proj_id
    WHERE r.run_git_commit IS NULL OR r.run_git_commit = ''
    ORDER BY r.run_started_at
  "))
  if (nrow(runs_without_commit) > 0) {
    cat("RUNS OHNE GIT COMMIT:\n")
    print(runs_without_commit)
  } else {
    cat("Alle Runs haben einen Git Commit protokolliert.\n")
  }
  cat("\n")

  # --- Backups: Anzahl + Speicherverbrauch (optional laut Plan) ---------
  # sub() nur anwenden, wenn `target` tatsaechlich auf ".db" endet (immer
  # der Fall in der Produktion, siehe 000_config.R) - sonst waere
  # backup_pattern identisch zu `target` selbst (kein Match, kein Ersatz)
  # und Sys.glob() wuerde die Ziel-DB faelschlich als eigenes Backup zaehlen.
  backup_files <- if (grepl("\\.db$", target)) {
    Sys.glob(sub("\\.db$", "_backup_*.db", target))
  } else {
    character(0)
  }
  backups <- data.table(
    file = backup_files,
    size_mb = if (length(backup_files) > 0) round(file.size(backup_files) / 1024^2, 1) else numeric(0)
  )
  cat(sprintf(
    "BACKUPS: %d Datei(en), %.1f MB gesamt.\n",
    nrow(backups), sum(backups$size_mb)
  ))
  if (nrow(backups) > 3) {
    cat("Hinweis: mehr als 3 Backups vorhanden - manuelles Aufraeumen erwaegen (kein automatisches Loeschen durch diese Funktion).\n")
  }

  invisible(list(
    missing_projects = missing_projects,
    new_runs = new_runs,
    duplicate_metrics = duplicate_metrics,
    incomplete_runs = incomplete_runs,
    runs_without_commit = runs_without_commit,
    backups = backups
  ))
}
