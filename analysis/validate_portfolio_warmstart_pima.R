rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

template_dir <- normalizePath(".")
pima_dir <- normalizePath("C:/Users/HP/ML_Learning/pima-diabetes-sentinel-test")

out_dir <- file.path(template_dir, "_artifacts")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
out_csv <- file.path(out_dir, "portfolio_warmstart_pima_validation.csv")
out_md <- file.path(out_dir, "portfolio_warmstart_pima_validation.md")

set.seed(42)
lgr::get_logger("mlr3")$set_threshold("warn")

train <- fread(file.path(pima_dir, "train.csv"))
train[, target := as.factor(target)]
task <- as_task_classif(train, target = "target", id = "pima_raw", positive = "1")
roles <- task$col_roles
roles$stratum <- "target"
task$col_roles <- roles

make_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% base_learner)
}

lightgbm <- make_learner(lrn("classif.lightgbm", num_iterations = 200, predict_type = "prob"))
ranger <- make_learner(lrn(
  "classif.ranger",
  num.trees = 300,
  respect.unordered.factors = "order",
  seed = 42,
  predict_type = "prob"
))

folds <- rsmp("cv", folds = 5)
folds$instantiate(task)

run_candidate <- function(learner, label) {
  started <- Sys.time()
  rr <- resample(task, learner, folds, store_models = FALSE)
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  pred <- rr$prediction()
  list(
    label = label,
    prediction = pred,
    metrics = data.table(
      candidate = label,
      bacc = pred$score(msr("classif.bacc")),
      auc = pred$score(msr("classif.auc")),
      mcc = pred$score(msr("classif.mcc")),
      elapsed_seconds = elapsed
    )
  )
}

cat("Laeuft: LightGBM (5-fold CV) ...\n")
lgb_res <- run_candidate(lightgbm, "lightgbm")

cat("Laeuft: Ranger (5-fold CV) ...\n")
ranger_res <- run_candidate(ranger, "ranger")

make_prob_dt <- function(pred) {
  prob <- as.data.table(pred$prob)
  prob[, row_id := pred$row_ids]
  prob[, truth := pred$truth]
  prob
}

lgb_prob <- make_prob_dt(lgb_res$prediction)
ranger_prob <- make_prob_dt(ranger_res$prediction)
prob_cols <- setdiff(intersect(names(lgb_prob), names(ranger_prob)), c("row_id", "truth"))
ens <- merge(lgb_prob, ranger_prob, by = c("row_id", "truth"), suffixes = c("_lgb", "_ranger"))
for (cls in prob_cols) {
  ens[, (cls) := (get(paste0(cls, "_lgb")) + get(paste0(cls, "_ranger"))) / 2]
}
ens[, response := prob_cols[max.col(as.matrix(.SD), ties.method = "first")], .SDcols = prob_cols]

truth <- factor(ens$truth, levels = task$class_names)
response <- factor(ens$response, levels = task$class_names)
positive <- task$positive
positive_prob <- ens[[positive]]
cm <- table(truth = truth, response = response)
recalls <- diag(cm) / rowSums(cm)
bacc <- mean(recalls, na.rm = TRUE)
auc <- mlr3measures::auc(truth, positive_prob, positive = positive)
mcc <- mlr3measures::mcc(truth, response)

results <- rbindlist(list(
  lgb_res$metrics,
  ranger_res$metrics,
  data.table(
    candidate = "probability_average_ensemble",
    bacc = bacc,
    auc = auc,
    mcc = mcc,
    elapsed_seconds = lgb_res$metrics$elapsed_seconds + ranger_res$metrics$elapsed_seconds
  )
), fill = TRUE)

results[, rank_bacc := rank(-bacc, ties.method = "min")]
results <- results[order(rank_bacc, candidate)]
fwrite(results, out_csv)

winner <- results[rank_bacc == 1][1]
md <- c(
  "# Pima Portfolio-Warmstart Validation",
  "",
  "- Pre-registered file: `docs/research/PORTFOLIO_WARMSTART_PREREG_PIMA.md`",
  "- Project: `pima-diabetes-sentinel-test`",
  "- Protocol: 5-fold CV, raw sentinel variant, no tuning, no external data",
  "- Recommended sequence tested: `lightgbm -> ranger -> ensemble`",
  "",
  "## Results",
  "",
  "| Candidate | BAcc | AUC | MCC | Seconds | Rank |",
  "|---|---:|---:|---:|---:|---:|"
)
for (i in seq_len(nrow(results))) {
  row <- results[i]
  md <- c(md, sprintf(
    "| `%s` | %.4f | %.4f | %.4f | %.1f | %d |",
    row$candidate, row$bacc, row$auc, row$mcc, row$elapsed_seconds, row$rank_bacc
  ))
}
md <- c(
  md,
  "",
  "## Interpretation",
  "",
  sprintf(
    "Winner by BAcc: `%s` (%.4f). This is the third pre-registered project validation for the portfolio warmstart line.",
    winner$candidate, winner$bacc
  )
)
writeLines(md, out_md, useBytes = TRUE)

cat("Pima Warmstart-Validierung geschrieben:\n")
cat("  -", out_csv, "\n")
cat("  -", out_md, "\n\n")
print(results)
