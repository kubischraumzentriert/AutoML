# =====================================================================
# 136_generalization_gap.R -- formale Generalisierungsluecken-Pruefung
# (siehe generalization_gap.R und docs/reference/REFERENZ_GENERALIZATION_GAP.md).
# =====================================================================
# Vergleicht CV-Score-Verteilung (auf einem Trainingsanteil) gegen eine
# Bootstrap-Verteilung auf einem komplett unberuehrten Testanteil, fuer
# die per Suche GETUNTEN Ranger-/LightGBM-Konfigurationen aus 090/100.
# Referenzbereich aus den ungetunten Learnern in base_learner_constructors
# (000_config.R) zeigt die "normale" Hintergrund-Luecke fuer dieses
# Projekt - der z-Score der getunten Kandidaten dagegen ist das eigentliche
# Flagging-Kriterium (siehe generalization_gap.R fuer die Begruendung,
# warum NICHT der direkte paarweise Signifikanztest).
#
# Setzt 090_ranger_tuning.R/100_lightgbm_tuning.R voraus (deren
# *_tuning_instance_path-Artefakte). Fehlt einer der beiden, wird der
# jeweilige Kandidat uebersprungen (kein Fehler) - liegt keiner vor, bricht
# das Skript mit einer klaren Meldung ab.
rm(list = ls())
suppressPackageStartupMessages({
  library(data.table); library(mlr3); library(mlr3learners)
  library(mlr3extralearners); library(mlr3pipelines); library(mlr3measures)
})

source("000_config.R")
source(file.path(project_dir, "generalization_gap.R"))
source(file.path(project_dir, "db_logging.R"))
set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}
task_full <- readRDS(task_train_small_path)
dt <- task_full$data()

# Stratifizierter Split, GETRENNT von validation_ratio (siehe Kommentar zu
# generalization_gap_test_ratio in 000_config.R).
set.seed(seed)
test_idx <- unlist(lapply(split(seq_len(nrow(dt)), dt[[target_col]]), function(ix) {
  n_test <- round(generalization_gap_test_ratio * length(ix))
  if (n_test < 1) n_test <- min(1, length(ix))
  sample(ix, size = n_test)
}))
train_idx <- setdiff(seq_len(nrow(dt)), test_idx)

make_pipeline_learner <- function(base_learner) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  as_learner(graph)
}

# Referenzbereich: alle ungetunten Learner aus base_learner_constructors.
reference_learners <- lapply(base_learner_constructors, function(ctor) make_pipeline_learner(ctor()))

# Getunte Kandidaten aus den 090/100-Tuning-Instanzen (falls vorhanden).
build_tuned_learner_from_instance <- function(instance_path, learner_id, final_override) {
  if (!file.exists(instance_path)) return(NULL)
  inst <- readRDS(instance_path)
  best <- inst$result_learner_param_vals
  names(best) <- sub(paste0("^", learner_id, "\\."), "", names(best))
  best <- utils::modifyList(best, final_override)
  learner <- lrn(learner_id)
  learner$param_set$values <- utils::modifyList(learner$param_set$values, best)
  make_pipeline_learner(learner)
}

candidate_learners <- list()
if (exists("ranger_tuning_instance_path")) {
  l <- build_tuned_learner_from_instance(ranger_tuning_instance_path, "classif.ranger",
                                          list(num.trees = ranger_tuning_final_trees))
  if (!is.null(l)) candidate_learners$ranger_tuned <- l
}
if (exists("lightgbm_tuning_instance_path")) {
  l <- build_tuned_learner_from_instance(lightgbm_tuning_instance_path, "classif.lightgbm",
                                          list(num_iterations = lightgbm_tuning_final_iterations))
  if (!is.null(l)) candidate_learners$lightgbm_tuned <- l
}

if (length(candidate_learners) == 0) {
  stop(
    "Keine getunte Kandidaten-Instanz gefunden (weder ranger_tuning_instance_path ",
    "noch lightgbm_tuning_instance_path existieren) - erst 090_ranger_tuning.R ",
    "und/oder 100_lightgbm_tuning.R ausfuehren."
  )
}

task_train <- task_full$clone(deep = TRUE)$filter(train_idx)
task_test <- task_full$clone(deep = TRUE)$filter(test_idx)
resampling <- rsmp("cv", folds = cv_folds)

run_learner <- function(nm, learner) {
  cat("=== ", nm, " ===\n", sep = "")
  set.seed(seed)
  rr <- resample(task_train, learner$clone(deep = TRUE), resampling)
  cv <- rr$score(msr(baseline_measure_ids[1]))[[baseline_measure_ids[1]]]
  cat("CV-Scores: ", paste(round(cv, 4), collapse = ", "), "\n")

  fit <- learner$clone(deep = TRUE)
  fit$train(task_train)
  pred <- fit$predict(task_test)
  # Nimmt eine klassenresponse-basierte Zielmetrik an (BAcc/MCC/Accuracy -
  # so an beiden Bestaetigungsprojekten verifiziert). Bei einer wahrschein-
  # lichkeitsbasierten Metrik (AUC/LogLoss) muesste measure_fn stattdessen
  # auf pred$prob operieren - hier NICHT abgedeckt, analog zur bestehenden
  # Einschraenkung bei 130_threshold_tuning.R/146 (siehe deren Kopfkommentar).
  measure_name <- sub("^classif\\.", "", baseline_measure_ids[1])
  measure_fn <- get(measure_name, envir = asNamespace("mlr3measures"))
  test_boot <- bootstrap_score_distribution(pred$truth, pred$response, measure_fn,
                                             n_boot = generalization_gap_n_boot, seed = seed)
  cat("Test-Bootstrap-Mittel: ", round(mean(test_boot), 4), "\n\n")
  list(cv = cv, test = test_boot)
}

ref_results <- Map(run_learner, names(reference_learners), reference_learners)
reference_gaps <- reference_gap_distribution(
  lapply(ref_results, `[[`, "cv"), lapply(ref_results, `[[`, "test")
)
cat("\n--- Referenz-Luecken (", length(reference_learners), " ungetunte Baselines) ---\n", sep = "")
print(reference_gaps)

results <- rbindlist(lapply(names(candidate_learners), function(nm) {
  res <- run_learner(nm, candidate_learners[[nm]])
  generalization_gap_report(nm, res$cv, res$test, reference_gaps)
}))

fwrite(results, generalization_gap_results_path)
cat("\nGespeichert:", generalization_gap_results_path, "\n")

db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "136_generalization_gap.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed,
  notes = paste0("Generalisierungsluecke: ", nrow(reference_gaps), " Referenz-Baselines, ",
                  length(candidate_learners), " getunte Kandidaten"))
db_log_run_config(db_con, db_run_id, list(
  generalization_gap_test_ratio = generalization_gap_test_ratio,
  generalization_gap_n_boot = generalization_gap_n_boot
))
db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
