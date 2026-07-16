rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
  library(mlr3tuning)
  library(mlr3mbo)
  library(paradox)
})

source("000_config.R")
source(file.path(project_dir, "005_benchmark_runtime.R"))
source(file.path(project_dir, "006_tuning_diagnostics.R"))
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_train_small <- enable_class_stratification(task_train_small)

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

# Suchphase: kleineres num_iterations fuer vertretbare Laufzeit, Holdout statt
# CV. bagging_freq wird fixiert, da bagging_fraction sonst wirkungslos bleibt.
# predict_type="prob" gesetzt, damit auch eine schwellenwertunabhaengige
# Zielmetrik (z.B. classif.auc) funktioniert.
search_learner <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_search_iterations, bagging_freq = 1, predict_type = "prob")
)

search_space <- ps(
  classif.lightgbm.learning_rate = p_dbl(0.01, 0.3),
  classif.lightgbm.num_leaves = p_int(15, 255),
  classif.lightgbm.min_data_in_leaf = p_int(5, 100),
  classif.lightgbm.feature_fraction = p_dbl(0.5, 1.0),
  classif.lightgbm.bagging_fraction = p_dbl(0.5, 1.0)
)

instance <- ti(
  task = task_train_small,
  learner = search_learner,
  resampling = rsmp("holdout", ratio = validation_ratio),
  measures = msr(tuning_measure_id),
  search_space = search_space,
  terminator = trm("evals", n_evals = lightgbm_tuning_evals)
)

# Bayesian Optimization statt Random Search: LightGBM hat mehr interagierende
# Hyperparameter als Ranger, bei guenstigen Einzel-Evaluationen lohnt sich ein
# Surrogatmodell (Default: Gaussian Process via DiceKriging).
tuner <- tnr("mbo")
tuner$optimize(instance)

# Prueft, ob echte sequenzielle Verfeinerung stattfand (nicht nur ein
# Initialdesign, siehe TARGETS.md-Backlog) und gibt einen groben Plateau-
# Indikator aus - VOR dem Finalvergleich, damit man ein Ergebnis aus einem
# reinen Initialdesign nicht ungeprueft per CV bestaetigen laesst.
diagnose_mbo_search(instance, tuning_measure_id)

archive_dt <- as.data.table(instance$archive$data)
list_cols <- names(archive_dt)[vapply(archive_dt, is.list, logical(1))]
fwrite(archive_dt[, setdiff(names(archive_dt), list_cols), with = FALSE], lightgbm_tuning_search_results_path)
saveRDS(instance, lightgbm_tuning_instance_path)

cat("=== LightGBM-Tuning: Suchergebnisse (Zielmetrik:", tuning_measure_id, ") ===\n")
print(instance$archive$data[, c(
  "classif.lightgbm.learning_rate",
  "classif.lightgbm.num_leaves",
  "classif.lightgbm.min_data_in_leaf",
  "classif.lightgbm.feature_fraction",
  "classif.lightgbm.bagging_fraction",
  tuning_measure_id
), with = FALSE])
cat("\nBeste Konfiguration (Suchphase, num_iterations =", lightgbm_tuning_search_iterations, "):\n")
print(instance$result_learner_param_vals)

# Finalvergleich: Default- vs. getuntes LightGBM mit vollem num_iterations, per CV.
best_params <- instance$result_learner_param_vals
best_params[["classif.lightgbm.num_iterations"]] <- lightgbm_tuning_final_iterations

learner_lightgbm_tuned <- make_baseline_learner(
  lrn("classif.lightgbm", predict_type = "prob"),
  id = "lightgbm_tuned"
)
learner_lightgbm_tuned$param_set$values <- best_params

learner_lightgbm_default <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations, predict_type = "prob"),
  id = "lightgbm_default"
)

resampling <- rsmp("cv", folds = cv_folds)

# Grobe Laufzeitschaetzung aus der zuletzt geloggten LightGBM-Holdout-
# Laufzeit, VOR dem eigentlichen CV-Lauf mitgeteilt (siehe README-Backlog).
db_con_estimate <- db_connect()
estimate_cv_runtime(db_con_estimate, project_name, "lightgbm", folds = cv_folds * 2)
DBI::dbDisconnect(db_con_estimate)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_train_small),
  learners = list(learner_lightgbm_default, learner_lightgbm_tuned),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

lightgbm_tuning_final_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(lightgbm_tuning_final_results, lightgbm_tuning_final_results_path)

cat("\n=== LightGBM-Tuning: Finalvergleich (Rohfeatures, 5-fache CV, num_iterations =", lightgbm_tuning_final_iterations, ") ===\n")
print(lightgbm_tuning_final_results)
cat("\nGespeichert:\n")
cat("Suchergebnisse:", lightgbm_tuning_search_results_path, "\n")
cat("Finalvergleich :", lightgbm_tuning_final_results_path, "\n")
cat("Tuning-Instanz :", lightgbm_tuning_instance_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "100_lightgbm_tuning.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = paste0("LightGBM-Tuning ohne Klassengewichtung (Bayesian Optimization, Zielmetrik ", tuning_measure_id, ")"))
db_log_run_config(db_con, db_run_id, list(
  cv_folds = cv_folds,
  validation_ratio = validation_ratio,
  tuning_measure_id = tuning_measure_id,
  lightgbm_tuning_search_iterations = lightgbm_tuning_search_iterations,
  lightgbm_tuning_evals = lightgbm_tuning_evals,
  lightgbm_tuning_final_iterations = lightgbm_tuning_final_iterations
))

db_rsmp_search_id <- db_create_resampling(db_con, db_run_id, strategy = "holdout", ratio = validation_ratio, seed = seed)
for (i in seq_len(nrow(archive_dt))) {
  row <- archive_dt[i]
  mconf_id <- db_create_model_config(
    db_con, db_run_id,
    task_type = "classif", algorithm = "lightgbm", feature_set = "raw",
    preprocessing = "impute_median_mode", class_weight_power = NA_real_, task_id = task_train_small$id,
    hyperparams = list(
      num_iterations = lightgbm_tuning_search_iterations,
      learning_rate = row$classif.lightgbm.learning_rate,
      num_leaves = row$classif.lightgbm.num_leaves,
      min_data_in_leaf = row$classif.lightgbm.min_data_in_leaf,
      feature_fraction = row$classif.lightgbm.feature_fraction,
      bagging_fraction = row$classif.lightgbm.bagging_fraction
    )
  )
  db_log_metric_result(db_con, mconf_id, db_rsmp_search_id, tuning_measure_id, row[[tuning_measure_id]])
}

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) {
    hyperparams <- if (grepl("lightgbm_tuned", row$learner_id[1])) {
      setNames(
        best_params[c("classif.lightgbm.learning_rate", "classif.lightgbm.num_leaves", "classif.lightgbm.min_data_in_leaf", "classif.lightgbm.feature_fraction", "classif.lightgbm.bagging_fraction", "classif.lightgbm.num_iterations")],
        c("learning_rate", "num_leaves", "min_data_in_leaf", "feature_fraction", "bagging_fraction", "num_iterations")
      )
    } else {
      list(num_iterations = lightgbm_tuning_final_iterations)
    }
    list(
      task_type = "classif", algorithm = "lightgbm", feature_set = feature_set_from_task_id(row$task_id[1]),
      preprocessing = "impute_median_mode", class_weight_power = NA_real_, task_id = row$task_id[1],
      hyperparams = hyperparams
    )
  },
  resampling_strategy = "cv", resampling_folds = cv_folds, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
