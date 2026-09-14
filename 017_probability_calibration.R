rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
})

# =====================================================================
# 017_probability_calibration.R -- erste Realprojekt-Anwendung von
# probability_calibration.R. `health_condition` ist 3-klassig - das
# Modul ist bewusst binaer-only (siehe Kopfkommentar), daher hier als
# One-vs-Rest: "unhealthy" (die kleinste, praktisch wichtigste Klasse,
# ~8.4%) gegen den Rest. Standard-Praxis fuer Multiclass-Kalibrierung
# (auch ausserhalb dieses Templates: erst je Klasse pruefen).
# =====================================================================

source("000_config.R")
source(file.path(project_dir, "probability_calibration.R"))

train <- fread(train_path)
date_cols <- names(train)[vapply(train, function(x) inherits(x, c("Date", "IDate", "POSIXct")), logical(1))]
train[, (date_cols) := lapply(.SD, as.numeric), .SDcols = date_cols]
char_cols <- names(train)[vapply(train, is.character, logical(1))]
char_cols <- setdiff(char_cols, target_col)
train[, (char_cols) := lapply(.SD, as.factor), .SDcols = char_cols]
train[, (target_col) := as.factor(get(target_col))]

task_full <- as_task_classif(train, target = target_col, id = "calibration_check")
task_full$set_col_roles(target_col, add_to = "stratum")

set.seed(seed)
holdout <- rsmp("holdout", ratio = validation_ratio)
holdout$instantiate(task_full)
train_ids <- holdout$train_set(1)
test_ids <- holdout$test_set(1)

learner <- lrn("classif.lightgbm", num_iterations = 200, predict_type = "prob")
learner$train(task_full, row_ids = train_ids)
pred <- learner$predict(task_full, row_ids = test_ids)

ovr_class <- "unhealthy"
eval_prob <- pred$prob[, ovr_class]
eval_truth <- factor(ifelse(as.character(pred$truth) == ovr_class, ovr_class, "rest"),
                     levels = c("rest", ovr_class))

cat(sprintf("=== Wahrscheinlichkeitskalibrierung: '%s' vs. Rest (n=%d Held-out) ===\n",
            ovr_class, length(eval_prob)))
report <- calibration_report(eval_prob, eval_truth, positive_class = ovr_class, seed = seed)
print(report)

ece_raw <- report[variant == "raw"]$ece
ece_best_calibrated <- min(report[variant != "raw"]$ece)
cat(sprintf("\nRoh-ECE: %.4f | bester kalibrierter ECE: %.4f | Verbesserung: %.4f\n",
            ece_raw, ece_best_calibrated, ece_raw - ece_best_calibrated))
if (ece_raw - ece_best_calibrated > 0.01) {
  cat("=> Kalibrierung bringt einen spuerbaren Unterschied - die rohen Wahrscheinlichkeiten\n")
  cat("   waren NICHT gut kalibriert (typisches Boosting-Symptom bei Klassenimbalance).\n")
} else {
  cat("=> Rohe Wahrscheinlichkeiten waren bereits gut kalibriert - kein spuerbarer Nutzen\n")
  cat("   durch Post-hoc-Kalibrierung hier.\n")
}

# Reliability-Detail fuer die Roh-Wahrscheinlichkeiten.
raw_ece_detail <- expected_calibration_error(eval_prob, eval_truth, ovr_class, n_bins = 10)
cat("\n=== Reliability-Tabelle (Roh-Wahrscheinlichkeiten, 10 Bins) ===\n")
print(raw_ece_detail$bins)

fwrite(report, file.path(artifact_dir, "probability_calibration_report.csv"))
cat("\nGespeichert:", file.path(artifact_dir, "probability_calibration_report.csv"), "\n")
