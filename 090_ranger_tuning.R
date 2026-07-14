rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
  library(mlr3tuning)
  library(paradox)
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

# Tuning-Zielmetrik = baseline_measure_ids[1] statt hart codiertem
# classif.bacc - fuer dieses Projekt identisch (BAcc ist hier die
# Zielmetrik), aber bei einer Uebertragung auf ein Projekt mit anderer
# Zielmetrik (z.B. AUC) muss das Tuning nach DIESER Metrik suchen, nicht nach
# BAcc. Wiederholter Reibungspunkt bei playground-series-s6e5/s5e12 (siehe
# deren TEMPLATE_FRICTION.md), hier dauerhaft behoben.
tuning_measure_id <- baseline_measure_ids[1]

make_baseline_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}

# Suchphase: kleineres num.trees fuer vertretbare Laufzeit, Holdout statt CV.
# predict_type="prob" gesetzt, damit auch eine schwellenwertunabhaengige
# Zielmetrik (z.B. classif.auc) funktioniert, ohne dass jedes neue Projekt
# das nachziehen muss.
search_learner <- make_baseline_learner(
  lrn(
    "classif.ranger",
    num.trees = ranger_tuning_search_trees,
    respect.unordered.factors = "order",
    seed = seed,
    predict_type = "prob"
  )
)

search_space <- ps(
  classif.ranger.mtry.ratio = p_dbl(0.1, 1),
  classif.ranger.min.node.size = p_int(1, 20),
  classif.ranger.sample.fraction = p_dbl(0.5, 1)
)

instance <- ti(
  task = task_train_small,
  learner = search_learner,
  resampling = rsmp("holdout", ratio = validation_ratio),
  measures = msr(tuning_measure_id),
  search_space = search_space,
  terminator = trm("evals", n_evals = ranger_tuning_evals)
)

tuner <- tnr("random_search")
tuner$optimize(instance)

archive_dt <- as.data.table(instance$archive$data)
list_cols <- names(archive_dt)[vapply(archive_dt, is.list, logical(1))]
fwrite(archive_dt[, setdiff(names(archive_dt), list_cols), with = FALSE], ranger_tuning_search_results_path)
saveRDS(instance, ranger_tuning_instance_path)

cat("=== Ranger-Tuning: Suchergebnisse (Zielmetrik:", tuning_measure_id, ") ===\n")
print(instance$archive$data[, c(
  "classif.ranger.mtry.ratio",
  "classif.ranger.min.node.size",
  "classif.ranger.sample.fraction",
  tuning_measure_id
), with = FALSE])
cat("\nBeste Konfiguration (Suchphase, num.trees =", ranger_tuning_search_trees, "):\n")
print(instance$result_learner_param_vals)

# Finalvergleich: Default- vs. getunter Ranger mit vollem num.trees, per CV.
best_params <- instance$result_learner_param_vals
best_params[["classif.ranger.num.trees"]] <- ranger_tuning_final_trees

learner_ranger_tuned <- make_baseline_learner(
  lrn("classif.ranger", respect.unordered.factors = "order", seed = seed, predict_type = "prob"),
  id = "ranger_tuned"
)
learner_ranger_tuned$param_set$values <- best_params

learner_ranger_default <- make_baseline_learner(
  lrn(
    "classif.ranger",
    num.trees = ranger_tuning_final_trees,
    respect.unordered.factors = "order",
    seed = seed,
    predict_type = "prob"
  ),
  id = "ranger_default"
)

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small),
  learners = list(learner_ranger_default, learner_ranger_tuned),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

ranger_tuning_final_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(ranger_tuning_final_results, ranger_tuning_final_results_path)

cat("\n=== Ranger-Tuning: Finalvergleich (Rohfeatures, 5-fache CV, num.trees =", ranger_tuning_final_trees, ") ===\n")
print(ranger_tuning_final_results)
cat("\nGespeichert:\n")
cat("Suchergebnisse:", ranger_tuning_search_results_path, "\n")
cat("Finalvergleich :", ranger_tuning_final_results_path, "\n")
cat("Tuning-Instanz :", ranger_tuning_instance_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "090_ranger_tuning.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = paste0("Ranger-Tuning ohne Klassengewichtung (Random Search, Zielmetrik ", tuning_measure_id, ")"))
db_log_run_config(db_con, db_run_id, list(
  cv_folds = cv_folds,
  validation_ratio = validation_ratio,
  tuning_measure_id = tuning_measure_id,
  ranger_tuning_search_trees = ranger_tuning_search_trees,
  ranger_tuning_evals = ranger_tuning_evals,
  ranger_tuning_final_trees = ranger_tuning_final_trees
))

db_rsmp_search_id <- db_create_resampling(db_con, db_run_id, strategy = "holdout", ratio = validation_ratio, seed = seed)
for (i in seq_len(nrow(archive_dt))) {
  row <- archive_dt[i]
  mconf_id <- db_create_model_config(
    db_con, db_run_id,
    task_type = "classif", algorithm = "ranger", feature_set = "raw",
    preprocessing = "impute_median_mode", class_weight_power = NA_real_, task_id = task_train_small$id,
    hyperparams = list(
      num.trees = ranger_tuning_search_trees,
      mtry.ratio = row$classif.ranger.mtry.ratio,
      min.node.size = row$classif.ranger.min.node.size,
      sample.fraction = row$classif.ranger.sample.fraction
    )
  )
  db_log_metric_result(db_con, mconf_id, db_rsmp_search_id, tuning_measure_id, row[[tuning_measure_id]])
}

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) {
    hyperparams <- if (grepl("ranger_tuned", row$learner_id[1])) {
      setNames(
        best_params[c("classif.ranger.mtry.ratio", "classif.ranger.min.node.size", "classif.ranger.sample.fraction", "classif.ranger.num.trees")],
        c("mtry.ratio", "min.node.size", "sample.fraction", "num.trees")
      )
    } else {
      list(num.trees = ranger_tuning_final_trees)
    }
    list(
      task_type = "classif", algorithm = "ranger", feature_set = feature_set_from_task_id(row$task_id[1]),
      preprocessing = "impute_median_mode", class_weight_power = NA_real_, task_id = row$task_id[1],
      hyperparams = hyperparams
    )
  },
  resampling_strategy = "cv", resampling_folds = cv_folds, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
