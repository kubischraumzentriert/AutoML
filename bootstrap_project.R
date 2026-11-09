rm(list = ls())

# =====================================================================
# bootstrap_project.R -- vor jedem Lauf: optional Skripte aus dem Template
# holen, Projektvorlage pruefen, Artefakte leeren. Ziel: ein Lauf startet nur
# aus einem vollstaendigen, sauberen Stand, nie aus Resten frueherer Laeufe.
#   0. (optional, --from=<Template>) die Skripte, die der Workflow einbindet,
#      aus dem Template holen - projekteigene Dateien bleiben unveraendert
#   1. competition.json vollstaendig (Pflichtfelder)
#   2. Datendateien vorhanden
#   3. Jede Skriptdatei, die ein anderes Skript per "..R" einbindet, existiert
#   4. _artifacts/ und step_logs/ leeren (sauberer Start); experiments.db bleibt
# =====================================================================

project_dir <- getwd()
args <- commandArgs(trailingOnly = TRUE)
clean <- !("--no-clean" %in% args)
from_arg <- grep("^--from=", args, value = TRUE)
template_dir <- if (length(from_arg) > 0L) sub("^--from=", "", from_arg[[1L]]) else NULL

search_dirs <- c("", "modules", "features", "analysis")

# Einstiegspunkte: die Schritte aus run_workflow.R und die Konfiguration.
steps <- c(
  "020_task.R", "010_eda.R", "015_target_leak_audit.R", "030_baseline.R",
  "100_lightgbm_tuning.R", "148_select_submission_model.R",
  "150_train_full_model.R", "155_predict_submission.R", "180_workflow_report.R"
)
# db_schema.sql wird zur Laufzeit gelesen (db_connect), nicht per source() eingebunden.
entry_points <- c(steps, "000_config.R", "db_schema.sql")

# Projekteigene Dateien, die nie aus dem Template ueberschrieben werden:
#  - 000_config.R: die Template-Fassung ist noch die Konfiguration eines anderen
#    Projekts (Health). Aus der Liste nehmen, sobald das Template die
#    competition.json-Fassung enthaelt.
#  - README.md: projektspezifisch.
protected <- c("README.md")

# Mit competition.json wird die wettbewerbsgesteuerte Konfiguration verwendet
# (Template: 000_config_competition.R). Ohne competition.json bleibt es bei der
# Template-000_config.R; der Preflight meldet dann die fehlende Spezifikation.
template_config_name <- function() {
  if (file.exists(file.path(project_dir, "competition.json"))) "000_config_competition.R" else "000_config.R"
}

# Fundstelle eines Skripts im Projekt (oder NA), in derselben Suchreihenfolge
# wie im Workflow.
project_hit <- function(name) {
  hits <- file.path(project_dir, search_dirs, name)
  hits <- hits[file.exists(hits)]
  if (length(hits) == 0L) NA_character_ else hits[[1L]]
}

# Eingebundene "xyz.R"-Namen aus einer Skriptdatei (ohne auskommentierte Zeilen).
deps_of <- function(path) {
  lines <- readLines(path, warn = FALSE)
  lines <- lines[grepl("source(", lines, fixed = TRUE) & !grepl("^\\s*#", lines)]
  unique(gsub('"', "", unlist(regmatches(lines, gregexpr('"[^"/]+[.]R"', lines)))))
}

problems <- character(0)

# 0. Kopieren aus dem Template
# Holt nur, was der Workflow tatsaechlich einbindet (dieselbe Abhaengigkeits-
# suche wie der Preflight). Nicht geschuetzte Dateien werden durch die
# Template-Fassung ersetzt, wenn sie fehlen oder abweichen.
if (!is.null(template_dir)) {
  if (!dir.exists(template_dir)) {
    cat("BOOTSTRAP ABGEBROCHEN: Template nicht gefunden:", template_dir, "\n")
    quit(status = 1L)
  }
  actions <- character(0)
  queue <- entry_points
  seen <- character(0)
  while (length(queue) > 0L) {
    current <- queue[[1L]]
    queue <- queue[-1L]
    if (current %in% seen) next
    seen <- c(seen, current)
    if (!(current %in% protected)) {
      # 000_config.R kommt aus dem Template unter einem anderen Namen, je nach competition.json.
      tpl_name <- if (current == "000_config.R") template_config_name() else current
      tpl_idx <- which(file.exists(file.path(template_dir, search_dirs, tpl_name)))
      if (length(tpl_idx) > 0L) {
        sub_dir <- search_dirs[[tpl_idx[[1L]]]]
        tpl_path <- file.path(template_dir, sub_dir, tpl_name)
        dest <- file.path(project_dir, sub_dir, current)
        same <- file.exists(dest) && unname(tools::md5sum(dest)) == unname(tools::md5sum(tpl_path))
        if (!same) {
          existed <- file.exists(dest)
          dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
          file.copy(tpl_path, dest, overwrite = TRUE)
          actions <- c(actions, paste(if (existed) "aktualisiert" else "kopiert", current))
        }
      }
    }
    path <- project_hit(current)
    if (!is.na(path)) queue <- c(queue, deps_of(path))
  }
  cat("Template-Abgleich (", template_dir, "): ", length(actions), " Aenderung(en)\n", sep = "")
  for (a in actions) cat("  -", a, "\n")
  kept <- intersect(protected, seen)
  if (length(kept) > 0L) cat("  projekteigen, nicht ueberschrieben:", paste(kept, collapse = ", "), "\n")
}

# 1. Spezifikation
required_keys <- c("competition", "task_type", "target_col", "id_col",
                   "positive_class", "metric", "project_name", "seed")
spec_path <- file.path(project_dir, "competition.json")
if (!file.exists(spec_path)) {
  problems <- c(problems, "competition.json fehlt")
} else {
  spec <- jsonlite::fromJSON(spec_path)
  missing_keys <- setdiff(required_keys, names(spec))
  if (length(missing_keys) > 0L) {
    problems <- c(problems, paste("competition.json ohne Felder:", paste(missing_keys, collapse = ", ")))
  }
}

# 2. Daten
for (f in c("train.csv", "test.csv", "sample_submission.csv")) {
  if (!file.exists(file.path(project_dir, f))) problems <- c(problems, paste(f, "fehlt"))
}

# 3. Einbindungen: jede "xyz.R" in einem Skript muss als Datei existieren
#    (Projektwurzel, modules/, features/ oder analysis/).
# Geprueft wird nur, was der Workflow tatsaechlich ausfuehrt: seine Schritte,
# 000_config.R und alles, was diese per source() einbinden (rekursiv).
# Optionale Skripte (z.B. Feature-Familien, die dieses Projekt nicht hat)
# bleiben ausser Betracht.
checked <- character(0)
missing_files <- character(0)
queue <- entry_points
while (length(queue) > 0L) {
  current <- queue[[1L]]
  queue <- queue[-1L]
  if (current %in% checked) next
  checked <- c(checked, current)
  path <- project_hit(current)
  if (is.na(path)) {
    missing_files <- c(missing_files, current)
    next
  }
  queue <- c(queue, deps_of(path))
}
if (length(missing_files) > 0L) {
  problems <- c(problems, paste("fehlende Skripte im Workflow:", paste(unique(missing_files), collapse = ", ")))
}
referenced <- checked

if (length(problems) > 0L) {
  cat("BOOTSTRAP ABGEBROCHEN:\n")
  for (p in problems) cat(" -", p, "\n")
  quit(status = 1L)
}
cat("Preflight ok (", length(referenced), " eingebundene Skripte gefunden)\n", sep = "")

# 4. Sauberer Start
# Die Experiments-DB ist die Historie ueber alle Laeufe und wird NICHT geloescht:
# sie wird vor dem Leeren in _archive/ gesichert und danach wieder eingesetzt.
if (clean) {
  db_path <- file.path(project_dir, "_artifacts", "experiments.db")
  if (file.exists(db_path)) {
    archive_dir <- file.path(project_dir, "_archive")
    dir.create(archive_dir, showWarnings = FALSE)
    file.copy(db_path, file.path(archive_dir, paste0("experiments_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".db")))
    keep_db <- tempfile(fileext = ".db")
    file.copy(db_path, keep_db)
  }
  for (d in c("_artifacts", "_artifacts/step_logs")) {
    unlink(file.path(project_dir, d), recursive = TRUE, force = TRUE)
  }
  dir.create(file.path(project_dir, "_artifacts"), recursive = TRUE, showWarnings = FALSE)
  if (exists("keep_db") && file.exists(keep_db)) file.copy(keep_db, db_path)
  cat("Artefakte geleert (experiments.db erhalten, Sicherung in _archive/).\n")
}
dir.create(file.path(project_dir, "_artifacts", "step_logs"), recursive = TRUE, showWarnings = FALSE)
cat("Bootstrap fertig.\n")
