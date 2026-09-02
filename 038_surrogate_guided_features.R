rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(tidyverse)
  library(rpart)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "005_benchmark_runtime.R"))
source(file.path(project_dir, "040_preprocessing.R"))
source(file.path(project_dir, "db_logging.R"))
source(file.path(project_dir, "features", "utils.R"))
source(file.path(project_dir, "features", "surrogate_guided.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_raw <- readRDS(task_train_small_path)
task_raw <- enable_class_stratification(task_raw)

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

sample_stratified_rows <- function(task, rows, max_rows = Inf, ratio = 1) {
  frame <- data.table(
    row_id = rows,
    target = task$data(rows = rows, cols = target_col)[[target_col]]
  )

  if (is.finite(max_rows) && nrow(frame) > max_rows) {
    ratio <- min(ratio, max_rows / nrow(frame))
  }

  frame[
    ,
    .(row_id = sample(row_id, max(1L, floor(.N * ratio)))),
    by = target
  ]$row_id
}

count_rpart_path_interactions <- function(model) {
  frame <- model$frame
  nodes <- as.integer(row.names(frame))
  node_vars <- setNames(as.character(frame$var), nodes)

  walk_node <- function(node_id, path_features = character()) {
    current_var <- node_vars[[as.character(node_id)]]
    if (is.null(current_var) || identical(current_var, "<leaf>")) {
      return(data.table(feature_a = character(), feature_b = character(), pair_count = integer()))
    }

    path_pairs <- data.table(feature_a = character(), feature_b = character(), pair_count = integer())
    previous_features <- unique(path_features)
    if (length(previous_features) > 0) {
      path_pairs <- rbindlist(
        lapply(previous_features, function(previous_feature) {
          pair <- sort(c(previous_feature, current_var))
          data.table(feature_a = pair[1], feature_b = pair[2], pair_count = 1L)
        })
      )
    }

    child_pairs <- rbindlist(
      list(
        if ((node_id * 2L) %in% nodes) walk_node(node_id * 2L, c(path_features, current_var)),
        if ((node_id * 2L + 1L) %in% nodes) walk_node(node_id * 2L + 1L, c(path_features, current_var))
      ),
      fill = TRUE
    )

    rbindlist(list(path_pairs, child_pairs), fill = TRUE)
  }

  walk_node(1L)
}

extract_rpart_interaction_pairs <- function(task, discovery_rows, numeric_features) {
  discovery_data <- task$data(rows = discovery_rows)
  formula <- as.formula(paste(target_col, "~ ."))

  all_pairs <- rbindlist(
    lapply(seq_len(surrogate_guided_rpart_runs), function(run_id) {
      set.seed(seed + run_id)
      run_rows <- sample_stratified_rows(
        task,
        discovery_rows,
        ratio = surrogate_guided_rpart_subsample_ratio
      )
      run_data <- discovery_data[match(run_rows, discovery_rows), ]

      elapsed <- system.time({
        model <- rpart::rpart(
          formula,
          data = run_data,
          method = "class",
          control = rpart.control(
            maxdepth = surrogate_guided_rpart_maxdepth,
            cp = surrogate_guided_rpart_cp,
            minsplit = surrogate_guided_rpart_minsplit,
            xval = 0
          )
        )
      })[["elapsed"]]

      pairs <- count_rpart_path_interactions(model)
      if (nrow(pairs) == 0) {
        return(pairs)
      }
      pairs[, `:=`(run_id = run_id, scout_elapsed_seconds = elapsed)]
      pairs
    }),
    fill = TRUE
  )

  if (nrow(all_pairs) == 0) {
    return(data.table(feature_a = character(), feature_b = character(), pair_count = integer()))
  }

  all_pairs[
    feature_a %in% numeric_features & feature_b %in% numeric_features & feature_a != feature_b,
    .(
      pair_count = sum(pair_count),
      run_count = uniqueN(run_id),
      scout_elapsed_seconds = sum(unique(scout_elapsed_seconds))
    ),
    by = .(feature_a, feature_b)
  ][
    pair_count >= surrogate_guided_min_pair_count
  ][
    order(-run_count, -pair_count)
  ][
    seq_len(min(.N, surrogate_guided_max_pairs))
  ]
}

finalize_task <- function(data, id) {
  data <- data %>%
    mutate(
      across(where(is.character), as.factor),
      !!target_col := as.factor(.data[[target_col]])
    )

  enable_class_stratification(as_task_classif(data, target = target_col, id = id))
}

raw_data <- task_raw$data()
numeric_features <- task_raw$feature_types[type %in% c("numeric", "integer"), id]

discovery_resampling <- rsmp("holdout", ratio = surrogate_guided_discovery_ratio)
discovery_resampling$instantiate(task_raw)
discovery_rows <- discovery_resampling$train_set(1)
evaluation_rows <- discovery_resampling$test_set(1)

evaluation_rows <- sample_stratified_rows(
  task_raw,
  evaluation_rows,
  max_rows = surrogate_guided_eval_max_rows
)

surrogate_spec <- extract_rpart_interaction_pairs(task_raw, discovery_rows, numeric_features)
surrogate_spec[, source := "rpart_path_cooccurrence"]
surrogate_spec[, operations := paste(surrogate_guided_operations, collapse = ",")]

saveRDS(surrogate_spec, surrogate_guided_feature_spec_path)
fwrite(surrogate_spec, surrogate_guided_feature_spec_csv_path)

raw_surrogate_data <- add_surrogate_guided_features(raw_data, surrogate_spec, operations = surrogate_guided_operations)
task_surrogate <- finalize_task(raw_surrogate_data, id = paste0(task_id_prefix, "_surrogate_guided"))
saveRDS(task_surrogate, task_train_small_surrogate_guided_path)

raw_eval <- raw_data[evaluation_rows, ]
raw_eval_task <- finalize_task(raw_eval, id = paste0(task_id_prefix, "_raw_eval"))
surrogate_eval <- add_surrogate_guided_features(raw_eval, surrogate_spec, operations = surrogate_guided_operations)
surrogate_eval_task <- finalize_task(surrogate_eval, id = paste0(task_id_prefix, "_surrogate_guided_eval"))

# predict_type="prob" fuer beide Learner: siehe 030_baseline.R fuer die
# volle Begruendung (BUGFIX 2026-09-01, gefunden im s6e9-Projekt - dieses
# Skript fehlte bislang, obwohl 030 den identischen Fix schon hatte).
# liblinear type=0 (L2-regularisierte logistische Regression) unterstuetzt
# Wahrscheinlichkeitsausgabe - andere liblinear-Typen (z.B. SVM-Varianten)
# ggf. nicht, hier unkritisch da der Default-Typ dieses Projekts type=0 ist.
learner_multinom <- lrn("classif.multinom")
if ("trace" %in% learner_multinom$param_set$ids()) {
  learner_multinom$param_set$values$trace <- FALSE
}
learner_multinom$predict_type <- "prob"

learner_liblinear_base <- lrn(
  "classif.liblinear",
  id = "liblinear_l2r_lr",
  type = surrogate_guided_liblinear_type,
  cost = surrogate_guided_liblinear_cost,
  bias = surrogate_guided_liblinear_bias
)
learner_liblinear_base$predict_type <- "prob"
learner_liblinear <- build_classif_pipeline(
  learner_liblinear_base,
  encode_factors = TRUE,
  scale_numeric = TRUE
)

learners <- list(
  make_baseline_learner(learner_multinom),
  learner_liblinear
)

resampling <- rsmp("cv", folds = surrogate_guided_cv_folds)

timed_benchmark <- run_timed_benchmark(
  tasks = list(raw_eval_task, surrogate_eval_task),
  learners = learners,
  resampling = resampling,
  measures = msrs(baseline_measure_ids)
)

surrogate_guided_results <- timed_benchmark$results[
  ,
  c("task_id", "learner_id", "resampling_id", baseline_measure_ids, "elapsed_seconds"),
  with = FALSE
]

fwrite(surrogate_guided_results, surrogate_guided_results_path)
saveRDS(timed_benchmark$benchmarks, surrogate_guided_benchmark_path)

cat("=== Surrogate-guided Feature Engineering ===\n")
cat("Scout:", surrogate_guided_scout, "\n")
cat("Discovery-Zeilen:", length(discovery_rows), "\n")
cat("Evaluation-Zeilen:", length(evaluation_rows), "\n")
cat("Gefundene Interaktionspaare:", nrow(surrogate_spec), "\n\n")
print(surrogate_spec)
cat("\n=== Surrogat-Benchmark (Evaluation-Split, CV) ===\n")
print(surrogate_guided_results)
cat("\nGespeichert:\n")
cat("Feature-Spezifikation:", surrogate_guided_feature_spec_path, "\n")
cat("Feature-Spezifikation CSV:", surrogate_guided_feature_spec_csv_path, "\n")
cat("Task:", task_train_small_surrogate_guided_path, "\n")
cat("Ergebnisse:", surrogate_guided_results_path, "\n")
cat("Benchmark :", surrogate_guided_benchmark_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "038_surrogate_guided_features.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "rpart-Ensemble-gefuehrte Interaktionsfeatures fuer schnelle lineare Surrogatmodelle")
db_log_run_config(db_con, db_run_id, list(
  scout = surrogate_guided_scout,
  discovery_ratio = surrogate_guided_discovery_ratio,
  rpart_runs = surrogate_guided_rpart_runs,
  rpart_subsample_ratio = surrogate_guided_rpart_subsample_ratio,
  rpart_maxdepth = surrogate_guided_rpart_maxdepth,
  rpart_cp = surrogate_guided_rpart_cp,
  rpart_minsplit = surrogate_guided_rpart_minsplit,
  max_pairs = surrogate_guided_max_pairs,
  min_pair_count = surrogate_guided_min_pair_count,
  eval_max_rows = surrogate_guided_eval_max_rows,
  operations = paste(surrogate_guided_operations, collapse = ","),
  cv_folds = surrogate_guided_cv_folds,
  liblinear_type = surrogate_guided_liblinear_type,
  liblinear_cost = surrogate_guided_liblinear_cost
))

db_log_timed_benchmark(
  db_con, db_run_id, timed_benchmark, measure_names = baseline_measure_ids,
  model_config_fn = function(row) list(
    task_type = "classif",
    algorithm = algorithm_from_learner_id(row$learner_id[1]),
    feature_set = feature_set_from_task_id(row$task_id[1]),
    preprocessing = if (grepl("liblinear", row$learner_id[1])) "empty_to_na_onehot_scale" else "impute_median_mode",
    class_weight_power = NA_real_,
    task_id = row$task_id[1],
    hyperparams = list(
      scout = surrogate_guided_scout,
      rpart_runs = surrogate_guided_rpart_runs,
      rpart_maxdepth = surrogate_guided_rpart_maxdepth,
      max_pairs = surrogate_guided_max_pairs,
      min_pair_count = surrogate_guided_min_pair_count,
      eval_max_rows = surrogate_guided_eval_max_rows,
      liblinear_type = surrogate_guided_liblinear_type,
      liblinear_cost = surrogate_guided_liblinear_cost
    )
  ),
  resampling_strategy = "cv", resampling_folds = surrogate_guided_cv_folds, resampling_seed = seed
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
