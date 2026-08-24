rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

project_dir <- normalizePath(".")
source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

out_csv <- file.path(artifact_dir, "literature_metric_reproduction_f1_credit_bank.csv")
out_md <- file.path(artifact_dir, "literature_metric_reproduction_f1_credit_bank.md")

credit_dir <- "C:/Users/HP/ML_Learning/openml-credit-g"
bank_dir <- "C:/Users/HP/ML_Learning/openml-bank-marketing-ensemble-test"

set.seed(42)
lgr::get_logger("mlr3")$set_threshold("warn")

set_minority_positive <- function(task) {
  truth <- task$truth()
  counts <- table(truth)
  positive <- names(counts)[which.min(counts)]
  task$positive <- positive
  positive
}

f1_binary <- function(truth, prob, threshold = 0.5) {
  pred <- as.integer(prob >= threshold)
  tp <- sum(truth == 1L & pred == 1L)
  fp <- sum(truth == 0L & pred == 1L)
  fn <- sum(truth == 1L & pred == 0L)
  denom <- 2 * tp + fp + fn
  if (denom == 0) NA_real_ else (2 * tp) / denom
}

bacc_binary <- function(truth, prob, threshold = 0.5) {
  pred <- as.integer(prob >= threshold)
  tpr <- sum(truth == 1L & pred == 1L) / sum(truth == 1L)
  tnr <- sum(truth == 0L & pred == 0L) / sum(truth == 0L)
  mean(c(tpr, tnr), na.rm = TRUE)
}

auc_binary <- function(truth, prob) {
  r <- rank(prob)
  n_pos <- sum(truth == 1L)
  n_neg <- sum(truth == 0L)
  (sum(r[truth == 1L]) - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg)
}

log_metric_row <- function(con, run_id, rsmp_id, project_label, learner_label,
                           algorithm, preprocessing, task_id, positive_class,
                           f1, auc, bacc, elapsed_seconds = NA_real_,
                           extra_hyperparams = list()) {
  mconf_id <- db_create_model_config(
    con, run_id,
    task_type = "classif",
    algorithm = algorithm,
    feature_set = "raw",
    preprocessing = preprocessing,
    class_weight_power = NA_real_,
    task_id = task_id,
    hyperparams = c(list(learner_id = learner_label, positive_class = positive_class), extra_hyperparams)
  )
  db_log_metric_result(con, mconf_id, rsmp_id, "classif.fbeta", f1, elapsed_seconds = elapsed_seconds)
  db_log_metric_result(con, mconf_id, rsmp_id, "classif.auc", auc, elapsed_seconds = elapsed_seconds)
  db_log_metric_result(con, mconf_id, rsmp_id, "classif.bacc", bacc, elapsed_seconds = elapsed_seconds)

  data.table(
    project = project_label,
    learner = learner_label,
    positive_class = positive_class,
    split = ifelse(is.na(extra_hyperparams$split), NA_character_, extra_hyperparams$split),
    f1 = f1,
    auc = auc,
    bacc = bacc,
    elapsed_seconds = elapsed_seconds
  )
}

run_credit_g <- function() {
  task <- readRDS(file.path(credit_dir, "_artifacts", "task_train_small.rds"))$clone(deep = TRUE)
  positive <- set_minority_positive(task)
  folds <- 10L
  resampling <- rsmp("cv", folds = folds)
  resampling$instantiate(task)
  f1_measure <- msr("classif.fbeta", beta = 1)

  learners <- list(
    as_learner(po("imputemedian") %>>% po("imputemode") %>>%
      lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = 42, predict_type = "prob")),
    as_learner(po("imputemedian") %>>% po("imputemode") %>>%
      lrn("classif.lightgbm", num_iterations = 200, predict_type = "prob"))
  )
  learners[[1]]$id <- "ranger_10fold"
  learners[[2]]$id <- "lightgbm_10fold"

  con <- db_connect()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  proj_id <- db_get_or_create_project(con, "openml-credit-g")
  wf_id <- db_get_or_create_workflow(con, proj_id, "script", "reproduce_literature_f1_credit_bank.R")
  run_id <- db_create_run(con, wf_id, seed = 42, notes = "Literature metric reproduction: local 10-fold F1 for credit-g.")
  db_log_run_config(con, run_id, list(cv_folds = folds, positive_class = positive, reproduction_metric = "classif.fbeta(beta=1)"))
  rsmp_id <- db_create_resampling(con, run_id, strategy = "cv", folds = folds, seed = 42)

  rows <- list()
  for (learner in learners) {
    label <- learner$id
    cat("Laeuft: openml-credit-g -", label, "\n")
    started <- Sys.time()
    rr <- resample(task, learner, resampling, store_models = FALSE)
    elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
    pred <- rr$prediction()
    f1 <- pred$score(f1_measure)
    auc <- pred$score(msr("classif.auc"))
    bacc <- pred$score(msr("classif.bacc"))

    rows[[length(rows) + 1L]] <- log_metric_row(
      con, run_id, rsmp_id,
      "openml-credit-g", label, sub("_.*$", "", label),
      "impute_median_mode", task$id, positive, f1, auc, bacc, elapsed,
      list(split = "10-fold-cv")
    )
  }
  db_finish_run(con, run_id)
  rbindlist(rows)
}

run_bank_marketing <- function() {
  bank <- readRDS(file.path(bank_dir, "ensemble_selection_result.rds"))
  truth <- as.integer(bank$yte)
  best_prob <- bank$Pte[, bank$best_idx]
  equal_prob <- rowMeans(bank$Pte)
  greedy_prob <- rowMeans(bank$Pte[, bank$selected, drop = FALSE])

  candidates <- list(
    list(label = paste0("best_single_", bank$labels[bank$best_idx]), algorithm = sub("_.*$", "", bank$labels[bank$best_idx]), prob = best_prob),
    list(label = "equal_blend_all_models", algorithm = "ensemble", prob = equal_prob),
    list(label = "greedy_ensemble_valid_selected", algorithm = "ensemble", prob = greedy_prob)
  )

  con <- db_connect()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  proj_id <- db_get_or_create_project(con, "openml-bank-marketing-ensemble-test")
  wf_id <- db_get_or_create_workflow(con, proj_id, "script", "reproduce_literature_f1_credit_bank.R")
  run_id <- db_create_run(con, wf_id, seed = 42, notes = "Literature metric reproduction: local F1 from existing bank-marketing holdout predictions.")
  db_log_run_config(con, run_id, list(test_ratio = 0.25, positive_class = "2", reproduction_metric = "F1 at threshold 0.5"))
  rsmp_id <- db_create_resampling(con, run_id, strategy = "holdout", ratio = 0.25, seed = 42)

  rows <- list()
  for (candidate in candidates) {
    rows[[length(rows) + 1L]] <- log_metric_row(
      con, run_id, rsmp_id,
      "openml-bank-marketing-ensemble-test",
      candidate$label,
      candidate$algorithm,
      "factor_integer_encoding_existing_holdout_predictions",
      "bank_marketing_test",
      "2",
      f1_binary(truth, candidate$prob),
      auc_binary(truth, candidate$prob),
      bacc_binary(truth, candidate$prob),
      NA_real_,
      list(split = "train-valid-test-holdout", threshold = 0.5)
    )
  }
  db_finish_run(con, run_id)
  rbindlist(rows)
}

results <- rbindlist(list(run_credit_g(), run_bank_marketing()), fill = TRUE)
results[, rank_f1 := rank(-f1, ties.method = "min"), by = project]
setorder(results, project, rank_f1, learner)
fwrite(results, out_csv)

md <- c(
  "# Literature Metric Reproduction: F1 Credit-G And Bank-Marketing",
  "",
  "Local F1 was logged for two literature rows that had OpenML IDs and local project evidence.",
  "",
  "Important: these are still `context_only` comparisons. `credit-g` uses local 10-fold CV; `bank-marketing` uses existing train/valid/test holdout predictions from the ensemble-selection verification, not the source paper's exact benchmark harness.",
  "",
  "| Project | Learner | Positive | Split | F1 | AUC | BAcc | Seconds | Rank |",
  "|---|---|---|---|---:|---:|---:|---:|---:|"
)
for (i in seq_len(nrow(results))) {
  row <- results[i]
  sec <- ifelse(is.na(row$elapsed_seconds), NA_real_, row$elapsed_seconds)
  md <- c(md, sprintf(
    "| `%s` | `%s` | `%s` | `%s` | %.4f | %.4f | %.4f | %s | %d |",
    row$project, row$learner, row$positive_class, row$split,
    row$f1, row$auc, row$bacc,
    ifelse(is.na(sec), "NA", sprintf("%.1f", sec)),
    row$rank_f1
  ))
}
writeLines(md, out_md, useBytes = TRUE)

cat("F1-Reproduktion geschrieben:\n")
cat("  -", out_csv, "\n")
cat("  -", out_md, "\n\n")
print(results)
