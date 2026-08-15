# =====================================================================
# 023_learning_curve.R -- Lernkurve (siehe learning_curve.R und
# TARGETS.md fuer Herkunft/Verifikation): prueft, ob subset_fraction
# selbst gut kalibriert ist.
# =====================================================================
# Arbeitet bewusst NICHT auf task_train_small (das ist ja schon das
# subset_fraction-Sample) sondern auf einem eigens geladenen Volltask -
# sonst koennte man nie ueber den bisherigen subset_fraction-Punkt
# hinaus testen. Nutzt task_full_path, falls das Projekt einen solchen
# Task bereits speichert (z.B. openml-satimage-multiclass), sonst wird
# train.csv direkt gelesen (Best-Effort-Generik, siehe unten).
rm(list = ls())
suppressPackageStartupMessages({
  library(data.table); library(mlr3); library(mlr3learners); library(DBI)
})

source("000_config.R")
source(file.path(project_dir, "learning_curve.R"))
source(file.path(project_dir, "db_logging.R"))
set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (exists("task_full_path") && file.exists(task_full_path)) {
  task_full <- readRDS(task_full_path)
} else {
  full_dt <- fread(train_path)
  # any(): id_col kann ein Vektor sein (siehe 015_target_leak_audit.R fuer
  # die identische Begruendung) - ein einzelnes %in% ergaebe sonst einen
  # Vektor, den if() bei Laenge > 1 ablehnt.
  if (exists("id_col") && !is.null(id_col) && any(id_col %in% names(full_dt))) {
    full_dt[, (id_col) := NULL]
  }
  full_dt[, (target_col) := as.factor(get(target_col))]
  char_cols <- names(full_dt)[vapply(full_dt, is.character, logical(1))]
  if (length(char_cols) > 0) full_dt[, (char_cols) := lapply(.SD, as.factor), .SDcols = char_cols]
  task_full <- as_task_classif(full_dt, target = target_col)
}
n_full <- task_full$nrow
cat("Volldatensatz:", n_full, "Zeilen (aktueller subset_fraction:", subset_fraction, ")\n")

fractions <- learning_curve_fractions[learning_curve_fractions * n_full <= learning_curve_max_rows]
if (!(subset_fraction %in% fractions) && subset_fraction * n_full <= learning_curve_max_rows) {
  fractions <- sort(unique(c(fractions, subset_fraction)))
}
if (length(fractions) < 3) {
  stop("Zu wenige fractions unterhalb learning_curve_max_rows (", learning_curve_max_rows,
       ") fuer eine Trend-Einordnung - max_rows erhoehen oder pruefen, ob das ueberhaupt sinnvoll ist.")
}
cat("Getestete fractions:", paste(fractions, collapse = ", "), "\n")

learner <- lrn("classif.ranger", num.trees = 100, respect.unordered.factors = "order", seed = seed)
measure <- msr(baseline_measure_ids[1])

lc <- learning_curve(task_full, learner, measure, fractions,
                      cv_folds = learning_curve_cv_folds,
                      repeats = learning_curve_repeats, seed = seed)
report_learning_curve(lc, out_path = learning_curve_results_path,
                       plateau_relative = learning_curve_plateau_relative)

# --- Experiment-Tracking (SQLite) -------------------------------------------
# Ein model_config je fraction (hyperparams: train_fraction, n_train), zwei
# metric_result-Zeilen je Punkt (Validierung + Training, per Suffix
# unterschieden) - so bleibt die Lernkurve mit denselben generischen Tabellen
# abfragbar wie jeder andere Benchmark, keine Schema-Erweiterung noetig.
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "023_learning_curve.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed,
  notes = paste0("Lernkurve: ", nrow(lc), " Punkte, Lerner=", learner$id))
db_log_run_config(db_con, db_run_id, list(
  learning_curve_max_rows = learning_curve_max_rows,
  learning_curve_repeats = learning_curve_repeats,
  learning_curve_cv_folds = learning_curve_cv_folds
))
rsmp_id <- db_create_resampling(db_con, db_run_id, strategy = "cv",
                                 folds = learning_curve_cv_folds, seed = seed)
for (i in seq_len(nrow(lc))) {
  mconf_id <- db_create_model_config(
    db_con, db_run_id, task_type = "classif", algorithm = algorithm_from_learner_id(learner$id),
    feature_set = "raw", task_id = task_full$id,
    hyperparams = list(train_fraction = lc$fraction[i], n_train = lc$n[i])
  )
  db_log_metric_result(db_con, mconf_id, rsmp_id, baseline_measure_ids[1], lc$val_score[i])
  db_log_metric_result(db_con, mconf_id, rsmp_id, paste0(baseline_measure_ids[1], "_train"), lc$train_score[i])
}
db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
