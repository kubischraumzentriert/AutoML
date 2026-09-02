rm(list = ls())

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
})

project_dir <- normalizePath(".")
source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

# Speichert den Referenzpool aus dem Meta-Learning-Warmstart-Verifikationslauf
# (2026-08-10, siehe TARGETS.md "Meta-Learning-Warmstart") als eigenes
# "Projekt" in der zentralen experiments.db - Meta-Features + beste bekannte
# LightGBM-Konfiguration je Referenz-Datensatz, wiederverwendbar fuer einen
# kuenftigen zweiten Warmstart-Versuch (z.B. groesserer Pool, mehr Meta-
# Features), statt die 8 OpenML-Datensaetze erneut abzufragen und die
# Zufallssuche zu wiederholen. KEIN echtes Kaggle-Projekt - kein Eintrag,
# der in `merge_project_experiments.R`s Auto-Discovery aufgegriffen wird
# (dessen Quellen sind Projekt-eigene `_artifacts/experiments.db`-Dateien
# unter `R_Workspace`/`ML_Learning`, dieses "Projekt" existiert nur hier).
#
# Meta-Features und Konfigurationen aus dem gecachten Lauf uebernommen:
cached_path <- "C:/Users/HP/ML_Learning/openml-drift-detection-test/meta_warmstart_result.rds"
if (!file.exists(cached_path)) stop("Gecachter Referenzpool-Lauf nicht gefunden: ", cached_path)
cached <- readRDS(cached_path)

# Beste AUC je Referenz-Datensatz stand nur in der Konsolenausgabe von
# 020_meta_learning_warmstart_test.R (Lauf vom 2026-08-10, 8-Datensatz-
# Version mit fixiertem min_data_in_leaf=20), hier uebernommen statt die
# Zufallssuche zu wiederholen.
reference_info <- list(
  credit_g          = list(openml_id = 31,   n_rows = 1000, best_auc = 0.7871),
  phoneme           = list(openml_id = 1489, n_rows = 5404, best_auc = 0.9614),
  spambase          = list(openml_id = 44,   n_rows = 4601, best_auc = 0.9917),
  kc1               = list(openml_id = 1067, n_rows = 2109, best_auc = 0.8193),
  diabetes          = list(openml_id = 37,   n_rows = 768,  best_auc = 0.8300),
  kr_vs_kp          = list(openml_id = 3,    n_rows = 3196, best_auc = 1.0000),
  blood_transfusion = list(openml_id = 1464, n_rows = 748,  best_auc = 0.7375),
  ilpd              = list(openml_id = 1480, n_rows = 583,  best_auc = 0.6499)
)
FIXED_MIN_DATA_IN_LEAF <- 20L  # war im Lauf fixiert, nicht Teil der Zufallssuche

missing <- setdiff(names(reference_info), names(cached$ref_meta))
if (length(missing)) stop("Referenz-Datensaetze im Cache nicht gefunden: ", paste(missing, collapse = ", "))

con <- db_connect()
proj_id <- db_get_or_create_project(
  con, "meta-learning-reference-pool",
  description = paste(
    "Offline-Referenzpool fuer Meta-Learning-Warmstart von tnr('mbo')",
    "(Auto-sklearn-Rezept, 'Automated Machine Learning' Kap. 2/6) -",
    "Meta-Features + beste bekannte LightGBM-Konfiguration je Referenz-Datensatz.",
    "KEIN echtes Kaggle-Projekt. Erster Warmstart-Versuch mit diesem Pool",
    "(2026-08-10) zeigte keinen robusten Effekt (siehe TARGETS.md) - Pool hier",
    "aufbewahrt, um ohne erneute OpenML-Abfragen an einem groesseren/",
    "verfeinerten Versuch weiterzuarbeiten."
  )
)
wf_id <- db_get_or_create_workflow(con, proj_id, "script", "build_meta_learning_reference_pool.R")

for (nm in names(reference_info)) {
  info <- reference_info[[nm]]
  mf <- as.list(cached$ref_meta[[nm]])
  cfg <- cached$ref_config[[nm]]

  run_id <- db_create_run(
    con, wf_id, seed = 42,
    notes = sprintf("%s (OpenML id %d, %d Zeilen)", nm, info$openml_id, info$n_rows)
  )
  db_log_run_config(con, run_id, c(
    mf,
    list(dataset_name = nm, openml_id = info$openml_id, n_rows_raw = info$n_rows)
  ))

  rsmp_id <- db_create_resampling(con, run_id, strategy = "holdout", ratio = 0.75, seed = 42)
  mconf_id <- db_create_model_config(
    con, run_id,
    task_type = "classif", algorithm = "lightgbm", feature_set = "raw",
    preprocessing = "none", task_id = nm,
    hyperparams = c(as.list(cfg), list(min_data_in_leaf = FIXED_MIN_DATA_IN_LEAF))
  )
  db_log_metric_result(con, mconf_id, rsmp_id, "classif.auc", info$best_auc)
  db_finish_run(con, run_id)

  cat(sprintf("Geloggt: %-18s AUC=%.4f  (run_id=%s)\n", nm, info$best_auc, run_id))
}

DBI::dbDisconnect(con)
cat("\nReferenzpool gespeichert in:", experiments_db_path, "(Projekt 'meta-learning-reference-pool')\n")
cat("Abfrage-Beispiel fuer Meta-Features:\n")
cat("  SELECT r.run_notes, rc.rconf_key, rc.rconf_value FROM run r\n")
cat("  JOIN run_config rc ON rc.rconf_run_id = r.run_id\n")
cat("  JOIN workflow wf ON wf.wf_id = r.run_wf_id\n")
cat("  JOIN project p ON p.proj_id = wf.wf_proj_id\n")
cat("  WHERE p.proj_name = 'meta-learning-reference-pool';\n")
