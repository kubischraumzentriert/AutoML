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

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)

make_baseline_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}

# Suchphase: kleineres num_iterations fuer vertretbare Laufzeit, Holdout statt
# CV. bagging_freq wird fixiert, da bagging_fraction sonst wirkungslos bleibt.
search_learner <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_search_iterations, bagging_freq = 1)
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
  measures = msr("classif.bacc"),
  search_space = search_space,
  terminator = trm("evals", n_evals = lightgbm_tuning_evals)
)

# Bayesian Optimization statt Random Search: LightGBM hat mehr interagierende
# Hyperparameter als Ranger, bei guenstigen Einzel-Evaluationen lohnt sich ein
# Surrogatmodell (Default: Gaussian Process via DiceKriging).
tuner <- tnr("mbo")
tuner$optimize(instance)

archive_dt <- as.data.table(instance$archive$data)
list_cols <- names(archive_dt)[vapply(archive_dt, is.list, logical(1))]
fwrite(archive_dt[, setdiff(names(archive_dt), list_cols), with = FALSE], lightgbm_tuning_search_results_path)
saveRDS(instance, lightgbm_tuning_instance_path)

cat("=== LightGBM-Tuning: Suchergebnisse ===\n")
print(instance$archive$data[, c(
  "classif.lightgbm.learning_rate",
  "classif.lightgbm.num_leaves",
  "classif.lightgbm.min_data_in_leaf",
  "classif.lightgbm.feature_fraction",
  "classif.lightgbm.bagging_fraction",
  "classif.bacc"
), with = FALSE])
cat("\nBeste Konfiguration (Suchphase, num_iterations =", lightgbm_tuning_search_iterations, "):\n")
print(instance$result_learner_param_vals)

# Finalvergleich: Default- vs. getuntes LightGBM mit vollem num_iterations, per CV.
best_params <- instance$result_learner_param_vals
best_params[["classif.lightgbm.num_iterations"]] <- lightgbm_tuning_final_iterations

learner_lightgbm_tuned <- make_baseline_learner(
  lrn("classif.lightgbm"),
  id = "lightgbm_tuned"
)
learner_lightgbm_tuned$param_set$values <- best_params

learner_lightgbm_default <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations),
  id = "lightgbm_default"
)

resampling <- rsmp("cv", folds = cv_folds)

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
