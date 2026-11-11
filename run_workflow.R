rm(list = ls())

# =====================================================================
# run_workflow.R -- fuehrt die Workflow-Schritte in fester Reihenfolge aus,
# protokolliert jeden Schritt (Status, Exit-Code, Dauer) in
# _artifacts/workflow_steps.csv und bricht beim ersten Fehler ab.
# Ziel: ein Befehl, kein manueller Eingriff zwischen den Schritten.
# Die Kaggle-Registrierung (158) und der Upload bleiben bewusst ausserhalb.
# =====================================================================

rscript <- "C:/Users/HP/Programme/R/R-4.5.2/bin/Rscript.exe"

project_dir <- getwd()  # Aufruf aus dem Projektordner

# Vorlauf: Preflight und sauberer Start (leert _artifacts/). Vor allen anderen
# Schritten, damit kein Lauf auf Resten frueherer Laeufe aufsetzt.
from_args <- grep("^--from=", commandArgs(trailingOnly = TRUE), value = TRUE)  # Pflicht: Template-Pfad
# Der Merge (letzter Schritt) schreibt in die zentrale experiments.db des Templates.
# Ohne Template-Pfad wuerde der Merge still ausfallen - daher gar nicht erst starten.
if (length(from_args) == 0L) {
  stop("Aufruf ohne --from=<Template>: der Merge in die zentrale experiments.db braucht den Template-Pfad. Lauf nicht gestartet.", call. = FALSE)
}
template_path <- sub("^--from=", "", from_args[[1L]])
Sys.setenv(AUTOML_MERGE_TEMPLATE_ROOT = template_path)
boot <- system2(rscript, c("bootstrap_project.R", from_args), stdout = TRUE, stderr = TRUE)
if (!is.null(attr(boot, "status")) && attr(boot, "status") != 0L) {
  cat(boot, sep = "\n")
  stop("Bootstrap fehlgeschlagen - Lauf abgebrochen.", call. = FALSE)
}
cat(boot, sep = "\n")

steps <- c(
  "020_task.R",
  "010_eda.R",
  "015_target_leak_audit.R",
  "030_baseline.R",
  "023_learning_curve.R",   # nur Bericht, aendert subset_fraction nicht
  "100_lightgbm_tuning.R",
  "148_select_submission_model.R",
  "150_train_full_model.R",
  "155_predict_submission.R",
  "180_workflow_report.R",
  "merge_project_experiments.R"   # fester Abschluss: Ergebnisse in die zentrale experiments.db des Templates
)

artifact_dir <- file.path(project_dir, "_artifacts")
log_dir <- file.path(artifact_dir, "step_logs")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
steps_path <- file.path(artifact_dir, "workflow_steps.csv")

rows <- list()
for (script in steps) {
  started <- Sys.time()
  log_path <- file.path(log_dir, paste0(tools::file_path_sans_ext(script), ".log"))
  status_code <- system2(rscript, script, stdout = log_path, stderr = TRUE)
  exit_code <- attr(status_code, "status") %||% 0L
  # stderr kommt als R-Objekt zurueck, nicht in die Datei: anhaengen, damit der Fehler im Log steht.
  if (length(status_code) > 0L) cat(status_code, file = log_path, sep = "\n", append = TRUE)
  seconds <- round(as.numeric(difftime(Sys.time(), started, units = "secs")), 1)
  status <- if (exit_code == 0L) "ok" else "failed"
  cat(sprintf("%-32s %-7s %6.1f s  exit=%d\n", script, status, seconds, exit_code))
  rows[[length(rows) + 1L]] <- data.frame(
    step = length(rows) + 1L, script = script, status = status,
    exit_code = exit_code, seconds = seconds,
    started_at = format(started, "%Y-%m-%d %H:%M:%S", tz = "UTC"), log = log_path
  )
  # Protokoll nach jedem Schritt schreiben: 180 liest es schon waehrend des Laufs.
  write.csv(do.call(rbind, rows), steps_path, row.names = FALSE)
  if (exit_code != 0L) {
    stop("Schritt fehlgeschlagen: ", script, " (Log: ", log_path, ")", call. = FALSE)
  }
}

write.csv(do.call(rbind, rows), steps_path, row.names = FALSE)
cat("\nAlle Schritte ok. Protokoll:", steps_path, "\n")
