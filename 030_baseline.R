rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "005_benchmark_runtime.R"))
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)
warn_high_cardinality_factors(task_train_small)
# Ergaenzende Pruefung (siehe 005_benchmark_runtime.R): die rohe Levelzahl
# allein reicht nicht, um LDA/Multinom-Abstuerze zu vermeiden - auch
# niedrig-kardinale Spalten mit einzelnen seltenen Leveln koennen crashen.
warn_rare_factor_levels(task_train_small)

make_baseline_learner <- function(base_learner) {
  graph <- po("imputemedian") %>>%
    po("imputemode") %>>%
    base_learner

  as_learner(graph)
}

learner_lda <- lrn("classif.lda")
learner_multinom <- lrn("classif.multinom")
learner_ranger <- lrn(
  "classif.ranger",
  num.trees = 200,
  respect.unordered.factors = "order",
  seed = seed
)

if ("trace" %in% learner_multinom$param_set$ids()) {
  learner_multinom$param_set$values$trace <- FALSE
}

# predict_type="prob" fuer alle drei Learner: kostet fuer classif.bacc/
# classif.mcc (Zielmetriken dieses Projekts) nichts, macht das Skript aber
# sofort tauglich fuer eine AUC-/LogLoss-bewertete Uebertragung auf ein neues
# Projekt (baseline_measure_ids dort typischerweise inkl. classif.auc, das
# ohne prob-Vorhersagen fehlschlaegt). Wiederholt aufgetretener Reibungspunkt
# bei der Uebertragung auf playground-series-s6e5/s5e12 (siehe deren
# TEMPLATE_FRICTION.md), hier dauerhaft behoben statt bei jedem neuen Projekt
# erneut nachzuziehen.
learner_lda$predict_type <- "prob"
learner_multinom$predict_type <- "prob"
learner_ranger$predict_type <- "prob"

learners <- list(
  make_baseline_learner(learner_lda),
  make_baseline_learner(learner_multinom),
  make_baseline_learner(learner_ranger)
)

resampling <- rsmp("holdout", ratio = validation_ratio)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small),
  learners = learners,
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

baseline_results_raw <- timed_benchmark$results

baseline_results <- baseline_results_raw[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(baseline_results, baseline_results_path)
saveRDS(timed_benchmark$benchmarks, baseline_benchmark_path)

cat("=== Baseline Ergebnisse ===\n")
print(baseline_results)
cat("\nGespeichert:\n")
cat("Ergebnisse:", baseline_results_path, "\n")
cat("Benchmark :", baseline_benchmark_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "030_baseline.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "Autarke Baseline: LDA, Multinom, Ranger")
db_log_run_config(db_con, db_run_id, list(validation_ratio = validation_ratio))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) list(
    task_type = "classif",
    algorithm = algorithm_from_learner_id(row$learner_id[1]),
    feature_set = feature_set_from_task_id(row$task_id[1]),
    preprocessing = "impute_median_mode",
    class_weight_power = NA_real_,
    task_id = row$task_id[1]
  ),
  resampling_strategy = "holdout", resampling_ratio = validation_ratio, resampling_seed = seed
)

# P3 (2026-08-29-Bewertung, Abschnitt 11): Abschluss-Provenienz mitgeben -
# `resampling`/`task_train_small` sind an dieser Stelle (Ende des Skripts)
# bereits fertig instanziiert bzw. geladen, anders als noch bei
# db_create_run() oben. Demonstriert `finalize_run_provenance()` an einem
# echten, aktiven Skript statt nur isoliert per Unit-Test.
db_finish_run(
  db_con, db_run_id,
  feature_set = colnames(task_train_small$data()),
  resampling = resampling
)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
