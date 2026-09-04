rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "040_preprocessing.R"))
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)

# Fuenfter Baustein der Fehleranalyse: TabPFN als komplett andere Methodik
# (in-context statt trainiert). Laedt Modelle+Indizes-Artefakte, kein
# erneutes Training der Vergleichsmodelle - nur diesen einen (teuren) Schritt
# isoliert laufen lassen.
if (!file.exists(error_analysis_indices_path)) {
  source(file.path(project_dir, "147_error_analysis_ranger_confidence.R"))
}
models <- readRDS(error_analysis_models_path)
indices <- readRDS(error_analysis_indices_path)

target_col_name <- models$target_col_name
feature_cols <- models$feature_cols
train_imputed <- models$train_imputed
eval_newdata <- models$eval_imputed[, c(target_col_name, feature_cols), with = FALSE]
truth <- models$truth

misclassified_idx <- indices$misclassified_idx
hard_case_idx <- indices$hard_case_idx
interesting_idx <- indices$interesting_idx

# TabPFN ist auf CPU auf ca. 1000 Kontextzeilen begrenzt (siehe 095), daher nur
# ein kleiner, klassenstratifizierter Kontext. Vorhersage NUR auf den
# "interessanten" Zeilen (nicht dem kompletten Eval-Split), um die
# CPU-Inferenzzeit praktikabel zu halten.
#
# Zusaetzliche Kappung auf error_analysis_tabpfn_query_sample_size (siehe
# 000_config.R) - bei grossen Eval-Splits kann interesting_idx selbst schon
# zu gross fuer eine praktikable CPU-Laufzeit sein (Fund: s6e9, 2026-09-04).
# Klassenstratifizierte Zufallsstichprobe statt der ersten N, damit die
# Rescue-Rate weiterhin repraesentativ bleibt.
if (length(interesting_idx) > error_analysis_tabpfn_query_sample_size) {
  set.seed(seed)
  interesting_strata <- split(interesting_idx, truth[interesting_idx])
  frac <- error_analysis_tabpfn_query_sample_size / length(interesting_idx)
  interesting_idx <- unlist(lapply(interesting_strata, function(idx) {
    sample(idx, max(1, round(length(idx) * frac)))
  }))
  cat("Hinweis:", length(indices$interesting_idx), "'interessante' Zeilen auf",
      length(interesting_idx), "klassenstratifiziert per Zufall reduziert (error_analysis_tabpfn_query_sample_size).\n")
}

cat("=== TabPFN auf den", length(interesting_idx), "'interessanten' Zeilen (Kontext:", error_analysis_tabpfn_context_size, "klassenstratifizierte Zeilen) ===\n")

set.seed(seed)
train_target_vec <- train_imputed[[target_col_name]]
context_frac <- error_analysis_tabpfn_context_size / nrow(train_imputed)
context_idx <- unlist(lapply(split(seq_len(nrow(train_imputed)), train_target_vec), function(idx) {
  sample(idx, max(1, round(length(idx) * context_frac)))
}))
tabpfn_context <- train_imputed[context_idx]

tabpfn_task <- as_task_classif(
  tabpfn_context[, c(target_col_name, feature_cols), with = FALSE],
  target = target_col_name, id = "error_analysis_tabpfn_context"
)

# TabPFN akzeptiert nur logical/integer/numeric, daher one-hot-Encoding wie in 095.
learner_tabpfn <- build_classif_pipeline(
  lrn("classif.tabpfn", device = "cpu"),
  encode_factors = TRUE, scale_numeric = FALSE
)
learner_tabpfn$predict_type <- "prob"
learner_tabpfn$train(tabpfn_task)

pred_tabpfn <- learner_tabpfn$predict_newdata(eval_newdata[interesting_idx], task = tabpfn_task)
tabpfn_response <- pred_tabpfn$response
tabpfn_probs <- pred_tabpfn$prob
tabpfn_correct <- tabpfn_response == truth[interesting_idx]

# na.rm=TRUE: bei einer Stichprobenreduktion (s.o.) sind misclassified_idx/
# hard_case_idx weiterhin die VOLLSTAENDIGEN Mengen aus 147_..._confidence.R,
# nicht jede davon liegt in der reduzierten interesting_idx-Stichprobe -
# match() liefert dafuer NA, ohne na.rm wuerde die Rate selbst zu NA werden.
misclassified_pos <- match(misclassified_idx, interesting_idx)
tabpfn_rescue_rate <- mean(tabpfn_correct[misclassified_pos], na.rm = TRUE)

hard_case_pos <- match(hard_case_idx, interesting_idx)
tabpfn_hard_case_rescue_rate <- if (length(hard_case_idx) > 0) mean(tabpfn_correct[hard_case_pos], na.rm = TRUE) else NA_real_

cat("TabPFN 'rettet'", sprintf("%.1f%%", 100 * tabpfn_rescue_rate), "von",
    sum(!is.na(misclassified_pos)), "in der Stichprobe enthaltenen Rangers-Fehlern (von", length(misclassified_idx), "insgesamt).\n")
cat("TabPFN 'rettet'", sprintf("%.1f%%", 100 * tabpfn_hard_case_rescue_rate), "der",
    sum(!is.na(hard_case_pos)), "in der Stichprobe enthaltenen 'alle drei selbstsicher falsch'-Zeilen (von", length(hard_case_idx), "insgesamt).\n")
cat("(Hinweis: TabPFN nur auf", error_analysis_tabpfn_context_size, "Kontextzeilen trainiert, nicht auf allen", nrow(train_imputed), "- kein fairer Gesamtvergleich, siehe README zu 095.)\n")

# --- Experiment-Tracking (SQLite) -------------------------------------------
# Nur die "interessanten" Zeilen werden geloggt (nicht der komplette
# Eval-Split) - TabPFN wurde ohnehin nur auf dieser Teilmenge ausgewertet
# (CPU-Kontextlimit), ein vollstaendiges Logging waere hier nicht moeglich.
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "147_error_analysis_ranger_tabpfn.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Fehleranalyse TabPFN-Vergleich auf interesting_idx-Teilmenge")
db_log_run_config(db_con, db_run_id, list(
  validation_ratio = validation_ratio,
  class_weight_power = class_weight_power,
  # tatsaechlich verwendeter Wert (kann bei binaeren Aufgaben vom
  # konfigurierten Default abweichen, siehe 147_error_analysis_ranger_
  # confidence.R) statt des rohen Config-Defaults geloggt.
  error_analysis_uncertainty_threshold = if (is.null(indices$effective_uncertainty_threshold)) {
    error_analysis_uncertainty_threshold
  } else {
    indices$effective_uncertainty_threshold
  },
  error_analysis_tabpfn_context_size = error_analysis_tabpfn_context_size
))

db_rsmp_id <- db_create_resampling(
  db_con, db_run_id, strategy = "custom_split",
  ratio = validation_ratio, seed = seed
)

mconf_tabpfn <- db_create_model_config(
  db_con, db_run_id,
  task_type = "classif", algorithm = "tabpfn", feature_set = "raw",
  preprocessing = "empty_to_na_onehot", class_weight_power = NA_real_, task_id = models$task_id,
  hyperparams = list(
    context_size = error_analysis_tabpfn_context_size,
    note = "nur auf interesting_idx-Teilmenge evaluiert (kleiner Kontext, CPU-Limit), kein repraesentatives bacc/mcc geloggt"
  )
)

db_log_predictions(
  db_con, mconf_tabpfn, db_rsmp_id,
  row_ids = models$eval_ids[interesting_idx], truth = truth[interesting_idx], response = tabpfn_response,
  prob_matrix = tabpfn_probs
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "(", length(interesting_idx), "Zeilen TabPFN geloggt)\n")
