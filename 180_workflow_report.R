rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(RSQLite)
})

source("000_config.R")

# =====================================================================
# 180_workflow_report.R -- erzeugt WORKFLOW_REPORT.md automatisch aus
# _artifacts/experiments.db und den Artefakten des Laufs. Keine Modelle
# werden neu gerechnet. Ziel: nach jedem Durchlauf (und vor dem naechsten
# Feature-Zyklus) eine lesbare Zusammenfassung, die als Eingabe fuer die
# naechste Runde dient.
# =====================================================================

con <- dbConnect(SQLite(), experiments_db_path)
on.exit(dbDisconnect(con), add = TRUE)

all_runs <- as.data.table(dbGetQuery(con, "
  SELECT * FROM v_model_results WHERE proj_name = ? ORDER BY run_started_at
", params = list(project_name)))

# Tuning-Trials = Holdout-Ergebnisse aus dem Tuning-Skript (die Suche wertet
# jeden Versuch auf demselben Holdout aus). Die Baseline-Holdouts aus 030
# bleiben dagegen, weil sie einzelne Vergleichswerte sind und keine Suche.
is_trial <- all_runs$rsmp_strategy == "holdout" & all_runs$wf_name != "030_baseline.R"
trials <- all_runs[is_trial]
runs <- all_runs[!is_trial]

# Nur Laeufe dieses Workflow-Durchgangs (ab Start des Schrittprotokolls). Aeltere
# Laeufe bleiben in der Datenbank, gehoeren aber nicht in den Bericht.
steps_file <- file.path(artifact_dir, "workflow_steps.csv")
if (file.exists(steps_file)) {
  # Beide Zeitstempel in UTC: run_started_at kommt aus SQLite (CURRENT_TIMESTAMP),
  # started_at aus run_workflow.R (dort ebenfalls UTC).
  steps_start <- min(as.POSIXct(fread(steps_file)$started_at, tz = "UTC"))
  runs <- runs[as.POSIXct(run_started_at, tz = "UTC") >= steps_start]
}

subs <- as.data.table(dbGetQuery(con, "
  SELECT * FROM v_submission_results WHERE proj_name = ?
", params = list(project_name)))

selection_path <- file.path(artifact_dir, "submission_model_selection.csv")
selection <- if (file.exists(selection_path)) fread(selection_path) else NULL

submission_path <- file.path(project_dir, "submission.csv")
sub_check <- if (file.exists(submission_path)) {
  s <- fread(submission_path)
  list(rows = nrow(s), cols = paste(names(s), collapse = ", "),
       range = paste(round(range(s[[2]]), 4), collapse = " .. "))
} else NULL

intervention_path <- file.path(project_dir, "INTERVENTIONS.md")
n_interventions <- if (file.exists(intervention_path)) {
  sum(grepl("^\\| [0-9]+ \\|", readLines(intervention_path, warn = FALSE)))
} else 0L

fmt <- function(x, d = 4) ifelse(is.na(x), "-", formatC(x, digits = d, format = "f"))

lines <- c(
  paste0("# Workflow-Bericht: ", project_name),
  "",
  paste0("Erzeugt: ", format(Sys.time(), "%Y-%m-%d %H:%M"), " (automatisch durch `180_workflow_report.R`)"),
  "",
  "## Aufgabe",
  "",
  paste0("- Zielspalte: `", target_col, "`"),
  paste0("- Positive Klasse: ", if (is.null(positive_class)) "keine (Labels)" else paste0("`", positive_class, "`")),
  paste0("- Zielmetrik (Kaggle): `", baseline_measure_ids[1], "`"),
  paste0("- Subset-Anteil: ", subset_fraction, " | CV-Folds: ", cv_folds, " | Seed: ", seed),
  "",
  "## Ergebnisse je Modell",
  ""
)

if (nrow(runs) > 0) {
  tab <- runs[, .(
    Algorithmus = mconf_algorithm,
    `Feature-Set` = mconf_feature_set,
    Resampling = paste0(rsmp_strategy, ifelse(is.na(rsmp_folds), "", paste0(" ", rsmp_folds, "-fold"))),
    AUC = fmt(auc),
    LogLoss = fmt(logloss),
    BAcc = fmt(bacc),
    Laufzeit_s = fmt(elapsed_seconds, 1),
    Lauf = substr(run_id, 1, 8)
  )]
  lines <- c(lines, paste0("| ", paste(names(tab), collapse = " | "), " |"),
             paste0("|", paste(rep("---", ncol(tab)), collapse = "|"), "|"),
             apply(tab, 1, function(r) paste0("| ", paste(r, collapse = " | "), " |")), "")
} else {
  lines <- c(lines, "Keine Laeufe in der Datenbank gefunden.", "")
}

if (nrow(trials) > 0) {
  lines <- c(lines,
             paste0("Tuning-Trials (nicht in der Tabelle oben): ", nrow(trials),
                    " Versuche, bester Holdout-Wert ", fmt(max(trials$auc)),
                    ". Dieser Wert ist nach oben verzerrt, weil der beste von vielen Versuchen auf demselben Holdout gewaehlt wurde."),
             "")
}

lines <- c(lines, "## Modellauswahl (148)", "")
if (!is.null(selection)) {
  lines <- c(lines, paste0("Ausgewaehlt: `", selection$algorithm[1], "`"), "",
             "Wichtig: 148 vergleicht die Werte aus der Datenbank. Ob Holdout- und CV-Werte vergleichbar sind, ist manuell zu pruefen (siehe INTERVENTIONS.md).", "")
} else {
  lines <- c(lines, "Keine Auswahl gespeichert (148 nicht gelaufen).", "")
}

lines <- c(lines, "## Submission", "")
if (!is.null(sub_check)) {
  lines <- c(lines,
             paste0("- Datei: `submission.csv`, Zeilen: ", sub_check$rows, ", Spalten: ", sub_check$cols),
             paste0("- Wertebereich der Vorhersage: ", sub_check$range), "")
} else {
  lines <- c(lines, "Keine `submission.csv` gefunden.", "")
}

if (nrow(subs) > 0) {
  lines <- c(lines, "Kaggle-Ergebnis (158):", "",
             paste0("- ", subs$subm_recorded_at, ": ", subs$mconf_algorithm, " -> Public ",
                    fmt(subs$subm_public_score), ", Private ", fmt(subs$subm_private_score)), "")
} else {
  lines <- c(lines, "Noch kein Kaggle-Ergebnis eingetragen (158 nach dem Upload ausfuehren).", "")
}

# Ablauf aus dem Schrittprotokoll von run_workflow.R (Status und Dauer je Schritt).
# Schritte ausserhalb des Protokolls (Kaggle-Upload, 158) sind gestrichelt.
steps_path <- file.path(artifact_dir, "workflow_steps.csv")
if (file.exists(steps_path)) {
  steps_log <- fread(steps_path)
  node_id <- paste0("s", seq_len(nrow(steps_log)))
  node_label <- sprintf("%s<br/>%s, %.1f s", steps_log$script, steps_log$status, steps_log$seconds)
  mm <- c("```mermaid", "flowchart TD")
  mm <- c(mm, sprintf('  %s["%s"]', node_id, node_label))
  if (nrow(steps_log) > 1) {
    mm <- c(mm, sprintf("  %s --> %s", node_id[-length(node_id)], node_id[-1]))
  }
  mm <- c(mm,
          '  kaggle["Upload Kaggle (manuell)"]:::external',
          '  reg["158 Score eintragen (manuell)"]:::external',
          sprintf("  %s -.-> kaggle", node_id[which(steps_log$script == "155_predict_submission.R")]),
          "  kaggle -.-> reg",
          if (any(steps_log$status == "failed")) {
            sprintf("  class %s failed", paste(node_id[steps_log$status == "failed"], collapse = ","))
          },
          "  classDef failed fill:#f8d7da,stroke:#842029",
          "  classDef external stroke-dasharray:4 3,fill:#f5f5f5",
          "```", "")
  lines <- c(lines, "## Ablauf", "", mm,
             "| Schritt | Skript | Status | Sekunden | Start (UTC) | Log |",
             "|---|---|---|---|---|---|",
             sprintf("| %d | %s | %s | %.1f | %s | `%s` |", steps_log$step, steps_log$script,
                     steps_log$status, steps_log$seconds, steps_log$started_at,
                     basename(steps_log$log)),
             "")
} else {
  lines <- c(lines, "## Ablauf", "", "Kein Schrittprotokoll gefunden (run_workflow.R nicht gelaufen).", "")
}

# Lernkurve (023): nur Bericht. Die subset_fraction-Regel aendert sich dadurch
# nicht (Festlegung, siehe competition.json).
lc_path <- file.path(artifact_dir, "learning_curve_results.csv")
lines <- c(lines, "## Lernkurve (023, nur Bericht)", "")
if (file.exists(lc_path)) {
  lc <- fread(lc_path)
  lines <- c(lines,
             "Die Lernkurve prueft nur, ob die Regel fuer subset_fraction plausibel ist. Der Wert wird nicht geaendert.",
             "",
             paste0("Stichprobe: ", paste(sprintf("%.0f%%", 100 * unique(lc[[1]])), collapse = ", ")),
             "")
} else {
  lines <- c(lines, "Keine Lernkurve gefunden (023 nicht gelaufen).", "")
}

lines <- c(lines,
           "## Eingriffe",
           "",
           paste0("Eintraege in `INTERVENTIONS.md`: ", n_interventions, ". Jeder Eintrag benennt, wie er kuenftig automatisiert wird."),
           "",
           "## Offene Fragen",
           "",
           "- Ist der Vergleich in 148 holdout- und CV-konsistent? (Behoben: 148 nutzt nur CV.)",
           "- Welche Feature-Familie ist der naechste Kandidat?")

out_path <- file.path(project_dir, "WORKFLOW_REPORT.md")
writeLines(lines, out_path)
cat("Gespeichert:", out_path, "\n")
