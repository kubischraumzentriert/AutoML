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

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_train_small <- readRDS(task_train_small_path)
task_weighted <- add_balanced_class_weights(task_train_small, class_weight_power)

make_baseline_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}

# Wiederholt 090_ranger_tuning.R, diesmal auf dem power=1.5-gewichteten Task -
# die Zielfunktionslandschaft ist mit Gewichtung eine andere als ohne, das
# fruehere Tuning-Ergebnis (ungewichtet) ist hier nicht uebertragbar.
search_learner <- make_baseline_learner(
  lrn(
    "classif.ranger",
    num.trees = ranger_tuning_search_trees,
    respect.unordered.factors = "order",
    seed = seed
  )
)

search_space <- ps(
  classif.ranger.mtry.ratio = p_dbl(0.1, 1),
  classif.ranger.min.node.size = p_int(1, 20),
  classif.ranger.sample.fraction = p_dbl(0.5, 1)
)

instance <- ti(
  task = task_weighted,
  learner = search_learner,
  resampling = rsmp("holdout", ratio = validation_ratio),
  measures = msr("classif.bacc"),
  search_space = search_space,
  terminator = trm("evals", n_evals = ranger_tuning_evals)
)

tuner <- tnr("random_search")
tuner$optimize(instance)

archive_dt <- as.data.table(instance$archive$data)
list_cols <- names(archive_dt)[vapply(archive_dt, is.list, logical(1))]
fwrite(archive_dt[, setdiff(names(archive_dt), list_cols), with = FALSE], ranger_weighted_tuning_search_results_path)
saveRDS(instance, ranger_weighted_tuning_instance_path)

cat("=== Ranger-Tuning (gewichtet): Suchergebnisse ===\n")
print(instance$archive$data[, c(
  "classif.ranger.mtry.ratio",
  "classif.ranger.min.node.size",
  "classif.ranger.sample.fraction",
  "classif.bacc"
), with = FALSE])
cat("\nBeste Konfiguration (Suchphase, num.trees =", ranger_tuning_search_trees, "):\n")
print(instance$result_learner_param_vals)

# Finalvergleich: Default- vs. getunter gewichteter Ranger, volles num.trees, per CV.
best_params <- instance$result_learner_param_vals
best_params[["classif.ranger.num.trees"]] <- ranger_tuning_final_trees

learner_ranger_tuned <- make_baseline_learner(
  lrn("classif.ranger", respect.unordered.factors = "order", seed = seed),
  id = "ranger_weighted_tuned"
)
learner_ranger_tuned$param_set$values <- best_params

learner_ranger_default <- make_baseline_learner(
  lrn(
    "classif.ranger",
    num.trees = ranger_tuning_final_trees,
    respect.unordered.factors = "order",
    seed = seed
  ),
  id = "ranger_weighted_default"
)

resampling <- rsmp("cv", folds = cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_weighted),
  learners = list(learner_ranger_default, learner_ranger_tuned),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

ranger_weighted_tuning_final_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(ranger_weighted_tuning_final_results, ranger_weighted_tuning_final_results_path)

cat("\n=== Ranger-Tuning (gewichtet): Finalvergleich (power =", class_weight_power, ", 5-fache CV, num.trees =", ranger_tuning_final_trees, ") ===\n")
print(ranger_weighted_tuning_final_results)
cat("\nGespeichert:\n")
cat("Suchergebnisse:", ranger_weighted_tuning_search_results_path, "\n")
cat("Finalvergleich :", ranger_weighted_tuning_final_results_path, "\n")
cat("Tuning-Instanz :", ranger_weighted_tuning_instance_path, "\n")
