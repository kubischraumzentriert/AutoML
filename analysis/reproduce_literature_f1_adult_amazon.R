rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(RSQLite)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

project_dir <- normalizePath(".")
source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

out_csv <- file.path(artifact_dir, "literature_metric_reproduction_f1.csv")
out_md <- file.path(artifact_dir, "literature_metric_reproduction_f1.md")

adult_dir <- "C:/Users/HP/ML_Learning/openml-adult-income"
amazon_dir <- "C:/Users/HP/ML_Learning/openml-amazon-access"

set.seed(42)
lgr::get_logger("mlr3")$set_threshold("warn")

set_minority_positive <- function(task) {
  truth <- task$truth()
  counts <- table(truth)
  positive <- names(counts)[which.min(counts)]
  task$positive <- positive
  positive
}

make_f1_measure <- function() {
  msr("classif.fbeta", beta = 1)
}

run_cv <- function(task, learners, project_label, preprocessing_labels, notes, folds = 5L) {
  positive <- set_minority_positive(task)
  resampling <- rsmp("cv", folds = folds)
  resampling$instantiate(task)
  f1_measure <- make_f1_measure()
  measure_names <- c("classif.fbeta", "classif.auc", "classif.bacc")

  con <- db_connect()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  proj_id <- db_get_or_create_project(con, project_label)
  wf_id <- db_get_or_create_workflow(con, proj_id, "script", "reproduce_literature_f1_adult_amazon.R")
  run_id <- db_create_run(con, wf_id, seed = 42, notes = notes)
  db_log_run_config(con, run_id, list(cv_folds = folds, positive_class = positive, reproduction_metric = "classif.fbeta(beta=1)"))
  rsmp_id <- db_create_resampling(con, run_id, strategy = "cv", folds = folds, seed = 42)

  rows <- list()
  for (i in seq_along(learners)) {
    learner <- learners[[i]]
    label <- learner$id
    cat("Laeuft:", project_label, "-", label, "\n")
    started <- Sys.time()
    rr <- resample(task, learner, resampling, store_models = FALSE)
    elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
    pred <- rr$prediction()
    f1 <- pred$score(f1_measure)
    auc <- pred$score(msr("classif.auc"))
    bacc <- pred$score(msr("classif.bacc"))

    mconf_id <- db_create_model_config(
      con, run_id,
      task_type = "classif",
      algorithm = sub("_.*$", "", label),
      feature_set = "raw",
      preprocessing = preprocessing_labels[[i]],
      class_weight_power = NA_real_,
      task_id = task$id,
      hyperparams = list(learner_id = label, positive_class = positive)
    )
    db_log_metric_result(con, mconf_id, rsmp_id, "classif.fbeta", f1, elapsed_seconds = elapsed)
    db_log_metric_result(con, mconf_id, rsmp_id, "classif.auc", auc, elapsed_seconds = elapsed)
    db_log_metric_result(con, mconf_id, rsmp_id, "classif.bacc", bacc, elapsed_seconds = elapsed)

    rows[[length(rows) + 1L]] <- data.table(
      project = project_label,
      learner = label,
      positive_class = positive,
      f1 = f1,
      auc = auc,
      bacc = bacc,
      elapsed_seconds = elapsed
    )
  }
  db_finish_run(con, run_id)
  rbindlist(rows)
}

adult_task <- readRDS(file.path(adult_dir, "_artifacts", "task_train_small.rds"))$clone(deep = TRUE)
adult_learners <- list(
  as_learner(po("imputemedian") %>>% po("imputemode") %>>%
    po("collapsefactors", no_collapse_above_absolute = 20, no_collapse_above_prevalence = 1, target_level_count = 2) %>>%
    lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = 42, predict_type = "prob")),
  as_learner(po("imputemedian") %>>% po("imputemode") %>>%
    po("collapsefactors", no_collapse_above_absolute = 20, no_collapse_above_prevalence = 1, target_level_count = 2) %>>%
    lrn("classif.multinom", predict_type = "prob", trace = FALSE))
)
adult_learners[[1]]$id <- "ranger_collapsefactors"
adult_learners[[2]]$id <- "multinom_collapsefactors"

amazon_task <- readRDS(file.path(amazon_dir, "_artifacts", "task_train_small.rds"))$clone(deep = TRUE)
source(file.path(amazon_dir, "features", "target_encoding.R"))
amazon_learners <- list(
  as_learner(po("imputemode") %>>% lrn("classif.lightgbm", num_iterations = 200, predict_type = "prob")),
  as_learner(build_target_encoded_pipeline(lrn("classif.ranger", num.trees = 200, seed = 42, predict_type = "prob"), smoothing = 20))
)
amazon_learners[[1]]$id <- "lightgbm_native"
amazon_learners[[2]]$id <- "ranger_target"

results <- rbindlist(list(
  run_cv(
    adult_task,
    adult_learners,
    "openml-adult-income",
    c("impute_median_mode_collapsefactors", "impute_median_mode_collapsefactors"),
    "Literature metric reproduction: local F1 for adult, minority class positive."
  ),
  run_cv(
    amazon_task,
    amazon_learners,
    "openml-amazon-access",
    c("native_factors", "target_encoding"),
    "Literature metric reproduction: local F1 for Amazon Employee Access, minority class positive."
  )
))

results[, rank_f1 := rank(-f1, ties.method = "min"), by = project]
setorder(results, project, rank_f1, learner)
fwrite(results, out_csv)

md <- c(
  "# Literature Metric Reproduction: F1",
  "",
  "Local F1 was logged for datasets that already existed locally but had only literature F1 context rows.",
  "",
  "Important: this is still not a direct paper reproduction. It uses local mlr3 tasks, local preprocessing choices, and local CV.",
  "",
  "| Project | Learner | Positive | F1 | AUC | BAcc | Seconds | Rank |",
  "|---|---|---|---:|---:|---:|---:|---:|"
)
for (i in seq_len(nrow(results))) {
  row <- results[i]
  md <- c(md, sprintf(
    "| `%s` | `%s` | `%s` | %.4f | %.4f | %.4f | %.1f | %d |",
    row$project, row$learner, row$positive_class, row$f1, row$auc, row$bacc,
    row$elapsed_seconds, row$rank_f1
  ))
}
writeLines(md, out_md, useBytes = TRUE)

cat("F1-Reproduktion geschrieben:\n")
cat("  -", out_csv, "\n")
cat("  -", out_md, "\n\n")
print(results)
