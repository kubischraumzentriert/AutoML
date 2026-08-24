rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
})

template_dir <- normalizePath(".")
pump_dir <- normalizePath("C:/Users/HP/ML_Learning/PumpItUp")
source(file.path(pump_dir, "000_config.R"))

out_dir <- file.path(template_dir, "_artifacts")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
out_csv <- file.path(out_dir, "portfolio_warmstart_pumpitup_validation.csv")
out_md <- file.path(out_dir, "portfolio_warmstart_pumpitup_validation.md")

set.seed(seed)
lgr::get_logger("mlr3")$set_threshold("warn")

train <- merge(fread(train_values_path), fread(train_labels_path), by = id_col)

prep <- function(dt) {
  dt <- copy(dt)
  for (col in c("construction_year", "gps_height", "population", "amount_tsh", "longitude", "latitude")) {
    dt[get(col) == 0, (col) := NA]
  }
  dt[, date_recorded := as.IDate(date_recorded)]
  dt[, date_year := as.integer(format(date_recorded, "%Y"))]
  dt[, date_month := as.integer(format(date_recorded, "%m"))]
  dt[, pump_age := fifelse(!is.na(construction_year), date_year - construction_year, NA_real_)]
  dt
}

to_factors <- function(dt) {
  char_cols <- names(dt)[vapply(dt, is.character, logical(1))]
  for (col in char_cols) {
    set(dt, j = col, value = as.factor(dt[[col]]))
  }
  dt
}

make_task <- function(dt, id) {
  task <- as_task_classif(dt, target = target_col, id = id)
  roles <- task$col_roles
  roles$stratum <- target_col
  task$col_roles <- roles
  task
}

drop_always <- c(
  "recorded_by", "num_private", "wpt_name", "date_recorded",
  "quantity_group", "payment_type", id_col
)
high_card <- c("funder", "installer", "ward", "subvillage")

train <- prep(train)
train[, (target_col) := as.factor(get(target_col))]

rest <- setdiff(names(train), c(drop_always, target_col, high_card))

native_dt <- to_factors(copy(train)[, c(rest, "funder", "installer", "ward", target_col), with = FALSE])
task_lgb <- make_task(native_dt, "pump_lightgbm_native")

freq_dt <- copy(train)
for (col in high_card) {
  counts <- freq_dt[, .N, by = col]
  setnames(counts, "N", paste0(col, "_freq"))
  freq_dt <- counts[freq_dt, on = col]
}
freq_cols <- paste0(high_card, "_freq")
freq_dt <- to_factors(freq_dt[, c(rest, freq_cols, target_col), with = FALSE])
task_ranger <- make_task(freq_dt, "pump_ranger_frequency")

folds <- rsmp("cv", folds = 3)
folds$instantiate(task_lgb)

task_lgb$row_roles$use <- task_lgb$row_ids
task_ranger$row_roles$use <- task_lgb$row_ids

run_candidate <- function(task, learner, label) {
  started <- Sys.time()
  rr <- resample(task, learner, folds, store_models = FALSE)
  elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))
  pred <- rr$prediction()
  list(
    label = label,
    prediction = pred,
    metrics = data.table(
      candidate = label,
      accuracy = pred$score(msr("classif.acc")),
      bacc = pred$score(msr("classif.bacc")),
      mcc = pred$score(msr("classif.mcc")),
      elapsed_seconds = elapsed
    )
  )
}

cat("Laeuft: LightGBM native (3-fold CV) ...\n")
lgb <- lrn("classif.lightgbm", num_iterations = 200, learning_rate = 0.05, predict_type = "prob")
lgb_res <- run_candidate(task_lgb, lgb, "lightgbm_native")

cat("Laeuft: Ranger frequency encoded (3-fold CV) ...\n")
ranger <- lrn(
  "classif.ranger",
  num.trees = 300,
  respect.unordered.factors = "order",
  predict_type = "prob"
)
ranger_res <- run_candidate(task_ranger, ranger, "ranger_frequency")

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

truth <- factor(ens$truth, levels = levels(train[[target_col]]))
response <- factor(ens$response, levels = levels(train[[target_col]]))
cm <- table(truth = truth, response = response)
acc <- sum(diag(cm)) / sum(cm)
recalls <- diag(cm) / rowSums(cm)
bacc <- mean(recalls, na.rm = TRUE)
mcc <- mlr3measures::mcc(truth, response)

results <- rbindlist(list(
  lgb_res$metrics,
  ranger_res$metrics,
  data.table(
    candidate = "probability_average_ensemble",
    accuracy = acc,
    bacc = bacc,
    mcc = mcc,
    elapsed_seconds = lgb_res$metrics$elapsed_seconds + ranger_res$metrics$elapsed_seconds
  )
), fill = TRUE)

results[, rank_accuracy := rank(-accuracy, ties.method = "min")]
results <- results[order(rank_accuracy, candidate)]
fwrite(results, out_csv)

winner <- results[rank_accuracy == 1][1]
md <- c(
  "# PumpItUp Portfolio-Warmstart Validation",
  "",
  "- Pre-registered file: `PORTFOLIO_WARMSTART_PREREG_PUMPITUP.md`",
  "- Project: `drivendata-pump-it-up`",
  "- Protocol: 3-fold CV, no tuning, no external data",
  "- Recommended sequence tested: `lightgbm -> ranger -> ensemble`",
  "",
  "## Results",
  "",
  "| Candidate | Accuracy | BAcc | MCC | Seconds | Rank |",
  "|---|---:|---:|---:|---:|---:|"
)
for (i in seq_len(nrow(results))) {
  row <- results[i]
  md <- c(md, sprintf(
    "| `%s` | %.4f | %.4f | %.4f | %.1f | %d |",
    row$candidate, row$accuracy, row$bacc, row$mcc, row$elapsed_seconds, row$rank_accuracy
  ))
}
md <- c(
  md,
  "",
  "## Interpretation",
  "",
  sprintf(
    "Winner by Accuracy: `%s` (%.4f). This validates whether the pre-registered warmstart candidates are practically useful on this held-out local project.",
    winner$candidate, winner$accuracy
  )
)
writeLines(md, out_md, useBytes = TRUE)

cat("PumpItUp Warmstart-Validierung geschrieben:\n")
cat("  -", out_csv, "\n")
cat("  -", out_md, "\n\n")
print(results)
