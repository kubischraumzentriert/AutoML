# Compares baseline vs. weather-enriched features on the chronological
# high/low next-month death-count target (Sachsen/Dresden). Same standalone
# approach and conventions as the other pilots' compare_pilot.R (seed 42,
# classif.bacc/classif.mcc, ranger).

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
repo_root <- normalizePath(file.path(project_dir, "..", ".."))
source(file.path(repo_root, "modules", "weather_enrichment_trust_gate.R"))

seed <- 42
split_date <- as.IDate("2022-01-01")

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

cat(sprintf("=== Baseline vs. Wetter-Vergleich (Sachsen/Dresden, Sterbefaelle, Einzelseed %d) ===\n", seed))
print(results)

# Trust-Gate (siehe docs/research/DWD_WEATHER_INTEGRATION.md): der
# Einzelseed-Vergleich oben darf NICHT als "hilft"/"schadet"-Befund
# berichtet werden, ohne dass die Richtung ueber mehrere Modell-Seeds
# stabil ist.
baseline_dt <- fread(file.path(project_dir, "pilot_baseline.csv"))
weather_dt <- fread(file.path(project_dir, "pilot_weather.csv"))
gate <- weather_enrichment_seed_stability_gate(
  baseline_dt, weather_dt, split_date,
  learner_constructor = function(s) {
    l <- lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = s)
    l$predict_type <- "prob"
    l
  },
  measure = msr("classif.bacc")
)
cat(sprintf(
  "Trust-Gate (%d Seeds): Delta-Mittel %.4f, %.0f%% positiv, %.0f%% negativ -> %s\n",
  gate$n_seeds, gate$delta_mean, gate$share_positive * 100, gate$share_negative * 100, gate$decision
))
fwrite(
  data.table(decision = gate$decision, delta_mean = gate$delta_mean, delta_sd = gate$delta_sd,
             share_positive = gate$share_positive, share_negative = gate$share_negative,
             n_seeds = gate$n_seeds),
  file.path(project_dir, "pilot_trust_gate_results.csv")
)

if (gate$decision == "inconclusive") {
  cat("KEIN gerichteter Befund berichtbar (Trust-Gate: inconclusive).\n")
} else {
  direction <- if (gate$decision == "robust_improvement") "improvement" else "regression"
  assert_weather_enrichment_finding(gate, direction)
  verb <- if (direction == "improvement") "hilft" else "schadet"
  cat(sprintf("Wetter %s robust (Trust-Gate bestanden).\n", verb))
}
