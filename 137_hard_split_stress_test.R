# =====================================================================
# 137_hard_split_stress_test.R -- Extrapolations-Stresstest (siehe
# hard_split_stress_test.R und JOSS_TECHNIQUE_WATCH.md, astartes-
# inspiriert - Burns et al. 2023, JOSS 10.21105/joss.05996).
# =====================================================================
# Ergaenzt 136_generalization_gap.R (dort: CV- vs. Bootstrap-Test-Verteilung
# bei ZUFAELLIGEM Split - misst Interpolations-Optimismus) UM einen
# strukturell schwierigeren, distanzbasierten Split: das kleinste
# k-means-Cluster (auf den numerischen Features) wird als Test-Set gehalten,
# der Rest ist Training - eine Extrapolations-Herausforderung, die ein
# zufaelliger CV-Score nicht sichtbar macht. Bewusst der UNGETUNTE
# base_learner_constructors$ranger statt getunter 090/100-Kandidaten (reiner
# Diagnose-Check, kein Score-Hebel, braucht deshalb keine Tuning-Instanzen -
# deutlich guenstiger als 136).
#
# An 6 unabhaengigen CC18-Datensaetzen verifiziert (siehe BACKLOG.md,
# 2026-08-31): 4/6 klar auffaellig, 2/6 unauffaellig (1x davon sogar minimal
# BESSER als der Referenzbereich) - ADR-003-Bestaetigungsschwelle erfuellt.
rm(list = ls())
suppressPackageStartupMessages({
  library(data.table); library(mlr3); library(mlr3learners); library(mlr3pipelines); library(mlr3measures)
})

source("000_config.R")
source(file.path(project_dir, "hard_split_stress_test.R"))
source(file.path(project_dir, "db_logging.R"))
set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}
task_full <- readRDS(task_train_small_path)

tuning_measure_id <- baseline_measure_ids[1]
tuning_measure <- msr(tuning_measure_id)
higher_is_better <- !(tuning_measure_id %in% c("classif.logloss", "classif.ce", "classif.bbrier", "classif.mbrier"))

make_ranger_ctor <- function() {
  function() {
    graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner_constructors$ranger()
    as_learner(graph)
  }
}

report <- hard_split_stress_test(
  task_full, make_ranger_ctor(), tuning_measure,
  k = hard_split_stress_test_k, n_repeats = hard_split_stress_test_n_repeats,
  seed = seed, higher_is_better = higher_is_better,
  flag_threshold_z = hard_split_stress_test_flag_threshold_z, label = project_name
)

results <- data.table(
  project = project_name, metric = tuning_measure_id,
  k = hard_split_stress_test_k, n_test = round(report$test_ratio * task_full$nrow),
  test_ratio = report$test_ratio, hard_score = report$hard_score,
  ref_mean = report$ref_mean, ref_sd = report$ref_sd, z = report$z, flagged = report$flagged
)
fwrite(results, hard_split_stress_test_results_path)
cat("\nGespeichert:", hard_split_stress_test_results_path, "\n")

db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "137_hard_split_stress_test.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed,
  notes = sprintf("Hard-Split-Stresstest: z=%.2f (%s)", report$z, if (report$flagged) "AUFFAELLIG" else "unauffaellig"))
db_log_run_config(db_con, db_run_id, list(
  hard_split_stress_test_k = hard_split_stress_test_k,
  hard_split_stress_test_n_repeats = hard_split_stress_test_n_repeats,
  hard_split_stress_test_flag_threshold_z = hard_split_stress_test_flag_threshold_z
))
db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
