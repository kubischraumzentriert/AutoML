rm(list = ls())

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(data.table)
})

# =====================================================================
# backfill_cc18_n15_into_experiments_db.R -- traegt die Protokoll-v2-
# Ergebnisse (outer_workflow_evaluation_v2_fair_baselines.R, 3 Outer-Folds,
# Metrik BAcc) der 15 externen OpenML-CC18-Benchmark-Datensaetze
# (docs/research/EXTERNAL_BENCHMARK_SET.md, "Weg B") in die zentrale
# experiments.db nach. Diese 15 Projekte wurden als schlanke Ad-hoc-
# Skripte OHNE eigene experiments.db gefahren - ihre Ergebnisse standen
# bisher nur als Zahlen in BACKLOG.md-Prosa und in der bereits
# vorhandenen Rohwerte-CSV _artifacts/benchmark_statistics_report_cc18_n15.csv
# (Quelle fuer 163_benchmark_statistics_report_n15.R), nicht in der
# zentralen, per SQL abfragbaren Projekt-DB (siehe merge_project_
# experiments.R, das genau diese Luecke beim Lauf am 2026-10-01 aufdeckte).
#
# Einmaliges, historisches Nachtragen (analog migrate_systematic_
# evaluation_to_evidence.R) - KEIN neuer Modell-Lauf, reine Uebernahme
# bereits vorhandener, geloggter Zahlen. Idempotent ueber db_get_or_
# create_project()/_workflow() (UNIQUE-Constraints) - ein project/workflow
# wird nicht doppelt angelegt; metric_result-Zeilen selbst sind nicht
# idempotent geschuetzt, daher vor erneutem Lauf pruefen, ob schon
# vorhanden (siehe Check unten).

project_dir <- "C:/Users/HP/OneDrive/Dokumente/R_Workspace/MLR3_Classifikation"
experiments_db_path <- file.path(project_dir, "_artifacts", "experiments.db")

source(file.path(project_dir, "db_logging.R"))

csv_path <- file.path(project_dir, "_artifacts", "benchmark_statistics_report_cc18_n15.csv")
raw <- fread(csv_path)

# OpenML-Task-/Dataset-IDs, soweit in BACKLOG.md dokumentiert (Weg-B-/n15-
# Erweiterung nennt die DIDs explizit; fuer die urspruenglichen 6 aus der
# P1-Bewertung 2026-08-29 nicht griffbereit dokumentiert -> NA, kein
# Beinbruch, proj_name bleibt der eindeutige Schluessel).
dataset_did <- c(
  "cmc" = NA_character_,
  "blood-transfusion" = NA_character_,
  "ilpd" = NA_character_,
  "sick" = NA_character_,
  "optdigits" = NA_character_,
  "analcatdata-authorship" = NA_character_,
  "phishing-websites" = "4534",
  "qsar-biodeg" = "1494",
  "mfeat-karhunen" = "16",
  "eucalyptus" = "188",
  "ozone-level-8hr" = "1487",
  "dresses-sales" = "23381",
  "jm1" = "1053",
  "mice-protein" = "40966",
  "mfeat-morphological" = "18"
)

algorithm_of_arm <- c(
  "ranger_default" = "ranger",
  "lightgbm_default" = "lightgbm",
  "tuned_ranger" = "ranger",
  "tuned_lightgbm" = "lightgbm",
  "best_single_tuned_model" = "best_single_tuned_model",
  "workflow_ranger" = "ensemble_arm_selection"
)
preprocessing_of_arm <- c(
  "ranger_default" = "impute_median_mode",
  "lightgbm_default" = "impute_median_mode",
  "tuned_ranger" = "impute_median_mode_tuned",
  "tuned_lightgbm" = "impute_median_mode_tuned",
  "best_single_tuned_model" = "impute_median_mode_tuned",
  "workflow_ranger" = "impute_median_mode_tuned"
)

con <- db_connect(db_path = experiments_db_path, project_dir = project_dir)

datasets <- unique(raw$dataset)
cat("Backfill fuer", length(datasets), "CC18-Datensaetze ->", experiments_db_path, "\n\n")

for (ds in datasets) {
  proj_name <- paste0("openml-cc18-", ds)

  already <- dbGetQuery(con, "SELECT proj_id FROM project WHERE proj_name = ?", params = list(proj_name))
  if (nrow(already) > 0) {
    n_existing <- dbGetQuery(con, "
      SELECT COUNT(*) AS n FROM metric_result mr
      JOIN model_config mc ON mc.mconf_id = mr.mres_mconf_id
      JOIN run r ON r.run_id = mc.mconf_run_id
      JOIN workflow wf ON wf.wf_id = r.run_wf_id
      WHERE wf.wf_proj_id = ?
    ", params = list(already$proj_id[1]))$n
    if (n_existing > 0) {
      cat(proj_name, ": bereits vorhanden (", n_existing, " metric_result-Zeilen), uebersprungen.\n", sep = "")
      next
    }
  }

  proj_id <- db_get_or_create_project(
    con, proj_name,
    description = paste0(
      "Externes OpenML-CC18-Benchmark-Set (docs/research/EXTERNAL_BENCHMARK_SET.md, 'Weg B'), ",
      "Protokoll v2 (faire getunte Baselines), nachgetragen aus BACKLOG.md/benchmark_statistics_report_cc18_n15.csv ",
      "am 2026-10-01 - kein eigenes lokales Projektverzeichnis (schlankes Ad-hoc-Skript ohne eigene experiments.db)."
    )
  )
  wf_id <- db_get_or_create_workflow(con, proj_id, "script", "outer_workflow_evaluation_v2_fair_baselines.R")
  run_id <- db_create_run(
    con, wf_id,
    notes = "Historisches Nachtragen (Backfill) bereits vorhandener Protokoll-v2-Ergebnisse in die zentrale DB.",
    log_baseline_provenance = FALSE
  )
  rsmp_id <- db_create_resampling(con, run_id, strategy = "cv", folds = 3)

  rows <- raw[dataset == ds]
  for (i in seq_len(nrow(rows))) {
    row <- rows[i]
    arm <- row$arm
    mconf_id <- db_create_model_config(
      con, run_id,
      task_type = "classif",
      algorithm = algorithm_of_arm[[arm]],
      feature_set = "raw",
      preprocessing = preprocessing_of_arm[[arm]],
      task_id = dataset_did[[ds]],
      hyperparams = list(arm_label = arm)
    )
    db_log_metric_result(con, mconf_id, rsmp_id, "classif.bacc", row$mean_score,
                          elapsed_seconds = row$mean_runtime_sec)
    db_log_metric_result(con, mconf_id, rsmp_id, "classif.bacc_sd", row$sd_score)
    db_log_metric_result(con, mconf_id, rsmp_id, "classif.bacc_worst_fold", row$worst_fold_score)
  }
  db_finish_run(con, run_id)

  cat(proj_name, ": ", nrow(rows), " Arme nachgetragen.\n", sep = "")
}

cat("\n=== Zusammenfassung (CC18-Projekte in der zentralen DB) ===\n")
summary_dt <- dbGetQuery(con, "
  SELECT p.proj_name, COUNT(DISTINCT mc.mconf_id) AS n_model_configs, COUNT(mr.mres_id) AS n_metric_results
  FROM project p
  LEFT JOIN workflow wf ON wf.wf_proj_id = p.proj_id
  LEFT JOIN run r ON r.run_wf_id = wf.wf_id
  LEFT JOIN model_config mc ON mc.mconf_run_id = r.run_id
  LEFT JOIN metric_result mr ON mr.mres_mconf_id = mc.mconf_id
  WHERE p.proj_name LIKE 'openml-cc18-%'
  GROUP BY p.proj_name
  ORDER BY p.proj_name
")
print(summary_dt)

dbDisconnect(con)
