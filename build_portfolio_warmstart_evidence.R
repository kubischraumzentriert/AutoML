rm(list = ls())

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
})

project_dir <- normalizePath(".")
source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

out_dir <- file.path(project_dir, "_artifacts")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

minimize_measures <- c(
  "classif.logloss", "classif.ce", "classif.bbrier", "classif.mbrier"
)

direction_for_measure <- function(measure) {
  ifelse(measure %in% minimize_measures, "minimize", "maximize")
}

score_to_loss <- function(value, measure) {
  ifelse(measure %in% minimize_measures, value, -value)
}

assign_role <- function(n_projects, win_rate, top3_rate, median_regret, median_elapsed_seconds) {
  if (n_projects < 2) {
    return("observe_more")
  }
  if (win_rate >= 0.25 || (top3_rate >= 0.60 && median_regret <= 0.01)) {
    return("core_portfolio")
  }
  if (top3_rate >= 0.35 && median_regret <= 0.03) {
    return("candidate_portfolio")
  }
  if (!is.na(median_elapsed_seconds) && median_elapsed_seconds > 300 && top3_rate < 0.25) {
    return("expensive_low_priority")
  }
  "low_priority"
}

normalize_algorithm_family <- function(algorithm) {
  family <- algorithm
  family[family %in% c("lgbm")] <- "lightgbm"
  family[grepl("^ranger", family)] <- "ranger"
  family[grepl("^rpart", family)] <- "rpart"
  family[grepl("^glmnet", family)] <- "glmnet"
  family[family %in% c("weighted_ensemble", "greedy_ensemble", "equal_blend", "ensemble_ranger_lightgbm")] <- "ensemble"
  family
}

con <- db_connect()
on.exit(DBI::dbDisconnect(con), add = TRUE)

metric_rows <- dbGetQuery(con, "
  SELECT
    proj_name,
    wf_name,
    run_started_at,
    mconf_algorithm,
    mconf_feature_set,
    mconf_preprocessing,
    mres_measure_name,
    mres_value,
    mres_elapsed_seconds,
    rsmp_strategy,
    rsmp_folds,
    rsmp_ratio,
    hyperparams
  FROM v_metric_results
  WHERE mres_value IS NOT NULL
    AND proj_name <> 'meta-learning-reference-pool'
    AND mconf_task_type = 'classif'
")

if (nrow(metric_rows) == 0) {
  stop("Keine aggregierten Klassifikationsmetriken in v_metric_results gefunden.")
}

metric_rows$direction <- direction_for_measure(metric_rows$mres_measure_name)
metric_rows$loss <- score_to_loss(metric_rows$mres_value, metric_rows$mres_measure_name)
metric_rows$project_metric <- paste(metric_rows$proj_name, metric_rows$mres_measure_name, sep = " :: ")

best_config_rows <- do.call(rbind, lapply(split(metric_rows, metric_rows$project_metric), function(dt) {
  dt <- dt[order(dt$loss, dt$run_started_at), , drop = FALSE]
  best_loss <- dt$loss[1]
  dt$regret <- dt$loss - best_loss
  dt$rank_overall <- rank(dt$loss, ties.method = "min")
  dt
}))

algorithm_best_rows <- do.call(rbind, lapply(
  split(best_config_rows, paste(best_config_rows$project_metric, best_config_rows$mconf_algorithm, sep = " :: ")),
  function(dt) {
    dt <- dt[order(dt$loss, dt$run_started_at), , drop = FALSE]
    dt[1, , drop = FALSE]
  }
))

algorithm_best_rows <- do.call(rbind, lapply(split(algorithm_best_rows, algorithm_best_rows$project_metric), function(dt) {
  dt <- dt[order(dt$loss, dt$mconf_algorithm), , drop = FALSE]
  dt$rank_algorithm <- rank(dt$loss, ties.method = "min")
  best_loss <- min(dt$loss)
  dt$algorithm_regret <- dt$loss - best_loss
  dt$algorithm_family <- normalize_algorithm_family(dt$mconf_algorithm)
  dt
}))

write.csv(
  algorithm_best_rows[order(algorithm_best_rows$proj_name, algorithm_best_rows$mres_measure_name, algorithm_best_rows$rank_algorithm), ],
  file.path(out_dir, "portfolio_warmstart_algorithm_best.csv"),
  row.names = FALSE
)

family_best_rows <- do.call(rbind, lapply(
  split(algorithm_best_rows, paste(algorithm_best_rows$project_metric, algorithm_best_rows$algorithm_family, sep = " :: ")),
  function(dt) {
    dt <- dt[order(dt$loss, dt$mconf_algorithm), , drop = FALSE]
    dt[1, , drop = FALSE]
  }
))

family_best_rows <- do.call(rbind, lapply(split(family_best_rows, family_best_rows$project_metric), function(dt) {
  dt <- dt[order(dt$loss, dt$algorithm_family), , drop = FALSE]
  dt$rank_family <- rank(dt$loss, ties.method = "min")
  best_loss <- min(dt$loss)
  dt$family_regret <- dt$loss - best_loss
  dt
}))

summary_rows <- do.call(rbind, lapply(split(family_best_rows, family_best_rows$algorithm_family), function(dt) {
  n_projects <- length(unique(dt$project_metric))
  wins <- sum(dt$rank_family == 1)
  top3 <- sum(dt$rank_family <= 3)
  median_elapsed <- median(dt$mres_elapsed_seconds, na.rm = TRUE)
  if (!is.finite(median_elapsed)) median_elapsed <- NA_real_
  median_regret <- median(dt$family_regret, na.rm = TRUE)
  if (!is.finite(median_regret)) median_regret <- NA_real_

  data.frame(
    algorithm_family = dt$algorithm_family[1],
    observed_variants = paste(sort(unique(dt$mconf_algorithm)), collapse = ";"),
    n_project_metrics = n_projects,
    wins = wins,
    top3 = top3,
    win_rate = wins / n_projects,
    top3_rate = top3 / n_projects,
    median_regret = median_regret,
    mean_regret = mean(dt$family_regret, na.rm = TRUE),
    median_elapsed_seconds = median_elapsed,
    role = assign_role(n_projects, wins / n_projects, top3 / n_projects, median_regret, median_elapsed),
    stringsAsFactors = FALSE
  )
}))

summary_rows <- summary_rows[order(
  match(summary_rows$role, c("core_portfolio", "candidate_portfolio", "observe_more", "low_priority", "expensive_low_priority")),
  -summary_rows$top3_rate,
  summary_rows$median_regret,
  summary_rows$median_elapsed_seconds
), ]

write.csv(summary_rows, file.path(out_dir, "portfolio_warmstart_summary.csv"), row.names = FALSE)

cat("Portfolio-Warmstart-Evidenz geschrieben:\n")
cat("  -", file.path(out_dir, "portfolio_warmstart_algorithm_best.csv"), "\n")
cat("  -", file.path(out_dir, "portfolio_warmstart_summary.csv"), "\n\n")
cat("Top-Rollen:\n")
print(summary_rows, row.names = FALSE)
