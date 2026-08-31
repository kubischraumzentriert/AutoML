rm(list = ls())

# =====================================================================
# hard_split_stress_test_prototype.R -- P2, JOSS-Technique-Watch-
# Prototyp #2 (2026-08-31, astartes-inspiriert, siehe
# JOSS_TECHNIQUE_WATCH.md + hard_split_stress_test.R).
# =====================================================================
# Wendet hard_split_stress_test() auf ein reales Projekt an: ein
# ungetunter, klassengewichteter Ranger (dieselbe Grundkonfiguration wie
# `workflow_ranger` in den Outer-Evaluation-Protokollen, aber OHNE
# Tuning - dieses Modul ist ein Diagnose-Check, kein Benchmark-Arm).

suppressPackageStartupMessages({
  library(data.table); library(mlr3); library(mlr3learners); library(mlr3pipelines); library(mlr3measures)
})
lgr::get_logger("mlr3")$set_threshold("warn")

source("000_config.R")
source(file.path(project_dir, "hard_split_stress_test.R"))

if (!exists("enable_class_stratification")) {
  enable_class_stratification <- function(task) task
}

set.seed(seed)
task_full <- readRDS(task_train_small_path)
tuning_measure_id <- baseline_measure_ids[1]
tuning_measure <- msr(tuning_measure_id)

make_ranger_ctor <- function() {
  function() {
    graph <- po("imputemedian") %>>% po("imputemode") %>>% lrn("classif.ranger", predict_type = "prob", seed = seed)
    as_learner(graph)
  }
}

cat(sprintf("Projekt: %s | Metrik: %s | Lerner: ungetunter Ranger (kein Tuning, reiner Diagnose-Check)\n",
            basename(project_dir), tuning_measure_id))

report <- hard_split_stress_test(
  task_full, make_ranger_ctor(), tuning_measure,
  k = 2, n_repeats = 10, seed = seed,
  higher_is_better = !(tuning_measure_id %in% c("classif.logloss", "classif.ce", "classif.bbrier", "classif.mbrier")),
  label = basename(project_dir)
)

saveRDS(report, file.path(artifact_dir, "hard_split_stress_test_report.rds"))
cat("\nGespeichert:", file.path(artifact_dir, "hard_split_stress_test_report.rds"), "\n")
