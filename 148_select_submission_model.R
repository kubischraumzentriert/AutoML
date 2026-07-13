rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
})

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

# Ermittelt datengetrieben (aus experiments.db, nicht aus Gedaechtnis/Bauch-
# gefuehl) den Algorithmus mit dem besten Wert der ersten Zielmetrik
# (baseline_measure_ids[1]) auf dem Roh-Feature-Set. Erster Schritt Richtung
# eines Workflows, der auch ohne KI im Loop durchlaufen kann - schreibt nur
# eine Empfehlung + Artefakt, uebernimmt sie aber NICHT automatisch in
# 000_config.R (submission_model_override bleibt die bewusste, dokumentierte
# Entscheidung fuer dieses Projekt - siehe Kommentar dort).
#
# Beachte: einige Modelle wurden mit Klassengewichtung getestet - diese
# Laeufe werden ebenfalls als feature_set="raw" geloggt (siehe
# feature_set_from_task_id()), zaehlen hier also mit. Das waehlt nur den
# Algorithmus; ob/mit welchem class_weight_power das finale Modell trainiert
# wird, bleibt eine gesonderte Entscheidung (model_class_weight_power).
primary_metric <- baseline_measure_ids[1]

db_con <- db_connect()
candidates <- dbGetQuery(
  db_con,
  "
  SELECT mc.mconf_algorithm AS algorithm, MAX(mr.mres_value) AS best_value
  FROM metric_result mr
  JOIN model_config mc ON mc.mconf_id = mr.mres_mconf_id
  JOIN run r ON r.run_id = mc.mconf_run_id
  JOIN workflow wf ON wf.wf_id = r.run_wf_id
  JOIN project p ON p.proj_id = wf.wf_proj_id
  WHERE p.proj_name = ?
    AND mr.mres_measure_name = ?
    AND mr.mres_fold IS NULL
    AND mc.mconf_feature_set = 'raw'
  GROUP BY mc.mconf_algorithm
  ORDER BY best_value DESC
  ",
  params = list(project_name, primary_metric)
)
DBI::dbDisconnect(db_con)

setDT(candidates)

if (nrow(candidates) == 0) {
  stop(
    "Keine geloggten Ergebnisse fuer Metrik '", primary_metric,
    "' auf Feature-Set 'raw' in experiments.db gefunden - erst Baseline-/",
    "Boosting-Skripte laufen lassen (030/080/etc.)."
  )
}

recommended_submission_model_name <- candidates$algorithm[1]

cat("=== Bestes", primary_metric, "je Algorithmus (Rohfeatures, aus experiments.db) ===\n")
print(candidates)

cat(
  "\nEmpfehlung: submission_model_override <- \"", recommended_submission_model_name, "\" (",
  primary_metric, " = ", candidates$best_value[1], ")\n",
  sep = ""
)
cat("Uebernimmt NICHT automatisch in 000_config.R - das bleibt ein\n")
cat("bestaetigter Schritt (KI/Nutzer prueft die Empfehlung, siehe README).\n")

fwrite(candidates, submission_model_selection_path)
cat("\nGespeichert:", submission_model_selection_path, "\n")
