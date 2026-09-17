# Compares baseline vs. weather-enriched features on the chronological
# high/low next-month overnight-demand target. Deliberately standalone
# instead of sourcing the repo-root 000_config.R pipeline: that config is
# hardwired to the health_condition project (random stratified subsampling),
# which conflicts with this pilot's chronological, no-shuffle split
# requirement (see HANDOFF_CLAUDE.md). Reuses the repo's conventions that do
# transfer cleanly: seed 42, classif.bacc/classif.mcc, ranger as the
# reference learner.

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
})

script_arg <- grep("^--file=", commandArgs(), value = TRUE)
project_dir <- if (length(script_arg)) {
  normalizePath(dirname(sub("^--file=", "", script_arg[[1]])))
} else {
  normalizePath(getwd())
}

seed <- 42
split_date <- as.IDate("2019-01-01")

evaluate_table <- function(path, label) {
  dt <- fread(path)
  dt[, date := as.IDate(date)]
  setorder(dt, date)

  train <- dt[date < split_date]
  test <- dt[date >= split_date]

  drop_cols <- c("id", "date")
  train_task_data <- train[, .SD, .SDcols = setdiff(names(train), drop_cols)]
  test_task_data <- test[, .SD, .SDcols = setdiff(names(test), drop_cols)]

  set.seed(seed)
  task <- as_task_classif(train_task_data, target = "target", id = label)

  learner <- lrn("classif.ranger", num.trees = 200,
                  respect.unordered.factors = "order", seed = seed)
  learner$predict_type <- "prob"
  learner$train(task)

  test_task <- as_task_classif(test_task_data, target = "target", id = paste0(label, "_test"))
  pred <- learner$predict(test_task)

  data.table(
    variant = label,
    train_rows = nrow(train),
    test_rows = nrow(test),
    bacc = pred$score(msr("classif.bacc")),
    mcc = pred$score(msr("classif.mcc"))
  )
}

baseline_result <- evaluate_table(
  file.path(project_dir, "pilot_baseline.csv"), "baseline"
)
weather_result <- evaluate_table(
  file.path(project_dir, "pilot_weather.csv"), "weather"
)

results <- rbind(baseline_result, weather_result)
results[, bacc_diff_vs_baseline := bacc - baseline_result$bacc]
results[, mcc_diff_vs_baseline := mcc - baseline_result$mcc]

fwrite(results, file.path(project_dir, "pilot_comparison_results.csv"))

cat("=== Baseline vs. Wetter-Vergleich ===\n")
print(results)
