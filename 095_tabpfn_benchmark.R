rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(tidyverse)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "005_benchmark_runtime.R"))
source(file.path(project_dir, "040_preprocessing.R"))
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

train <- fread(train_path)
tabpfn_fraction <- tabpfn_subset_size / nrow(train)

train_tabpfn <- train %>%
  as_tibble() %>%
  group_by(.data[[target_col]]) %>%
  slice_sample(prop = tabpfn_fraction) %>%
  ungroup() %>%
  select(-all_of(id_col)) %>%
  mutate(
    across(where(is.character), as.factor),
    !!target_col := as.factor(.data[[target_col]])
  )

task_tabpfn <- as_task_classif(train_tabpfn, target = target_col, id = sub("_10pct$", "_tabpfn_subset", task_id_prefix))
saveRDS(task_tabpfn, task_tabpfn_path)

cat("TabPFN-Subset:", task_tabpfn$nrow, "Zeilen (Ziel:", tabpfn_subset_size, ")\n\n")

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

# Ranger und LightGBM auf demselben kleinen Subset als Referenz, damit der
# TabPFN-Vergleich nicht gegen die grossen Benchmarks aus 080/090 schielt,
# die auf einem 20x groesseren Subset liefen.
learner_ranger <- make_baseline_learner(
  lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = seed)
)
learner_lightgbm <- make_baseline_learner(
  lrn("classif.lightgbm", num_iterations = 200)
)

# TabPFN akzeptiert nur logical/integer/numeric, daher one-hot-Encoding wie
# bei xgboost.
learner_tabpfn <- build_classif_pipeline(
  lrn("classif.tabpfn", device = "cpu"),
  encode_factors = TRUE,
  scale_numeric = FALSE
)

resampling <- rsmp("holdout", ratio = validation_ratio)

timed_benchmark <- run_timed_benchmark(
  tasks = list(task_tabpfn),
  learners = list(learner_ranger, learner_lightgbm, learner_tabpfn),
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

tabpfn_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(tabpfn_results, tabpfn_results_path)

cat("=== TabPFN vs. Ranger/LightGBM (kleines Subset, Holdout) ===\n")
print(tabpfn_results)
cat("\nGespeichert:", tabpfn_results_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "095_tabpfn_benchmark.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "TabPFN vs. Ranger/LightGBM auf CPU-Mini-Subset")
db_log_run_config(db_con, db_run_id, list(validation_ratio = validation_ratio, tabpfn_subset_size = tabpfn_subset_size))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) {
    algorithm <- algorithm_from_learner_id(row$learner_id[1])
    list(
      task_type = "classif",
      algorithm = algorithm,
      feature_set = feature_set_from_task_id(row$task_id[1]),
      preprocessing = if (algorithm == "tabpfn") "empty_to_na_onehot" else "impute_median_mode",
      class_weight_power = NA_real_,
      task_id = row$task_id[1]
    )
  },
  resampling_strategy = "holdout", resampling_ratio = validation_ratio, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
