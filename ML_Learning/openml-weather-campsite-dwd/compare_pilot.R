# Compares baseline vs. weather-enriched features on the chronological
# high/low next-month overnight-demand target, for each (Bundesland,
# DWD-station) case produced by prepare_pilot.R. Deliberately standalone
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
repo_root <- normalizePath(file.path(project_dir, "..", ".."))
source(file.path(repo_root, "modules", "weather_enrichment_trust_gate.R"))

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

run_case <- function(case_label, output_suffix) {
  baseline_result <- evaluate_table(
    file.path(project_dir, paste0("pilot_baseline", output_suffix, ".csv")), "baseline"
  )
  weather_result <- evaluate_table(
    file.path(project_dir, paste0("pilot_weather", output_suffix, ".csv")), "weather"
  )

  results <- rbind(baseline_result, weather_result)
  results[, case := case_label]
  results[, bacc_diff_vs_baseline := bacc - baseline_result$bacc]
  results[, mcc_diff_vs_baseline := mcc - baseline_result$mcc]
  setcolorder(results, c("case", setdiff(names(results), "case")))

  fwrite(results, file.path(project_dir, paste0("pilot_comparison_results", output_suffix, ".csv")))

  cat("=== Baseline vs. Wetter-Vergleich (", case_label, ", Einzelseed ", seed, ") ===\n", sep = "")
  print(results)

  # Trust-Gate (siehe docs/research/DWD_WEATHER_INTEGRATION.md): der
  # Einzelseed-Vergleich oben darf NICHT als "hilft"/"schadet"-Befund
  # berichtet werden, ohne dass die Richtung ueber mehrere Modell-Seeds
  # stabil ist - genau dieser Fehlschluss (Bayern/Sachsen/Baugewerbe im
  # ersten Anlauf) hat dieses Gate ausgeloest.
  baseline_dt <- fread(file.path(project_dir, paste0("pilot_baseline", output_suffix, ".csv")))
  weather_dt <- fread(file.path(project_dir, paste0("pilot_weather", output_suffix, ".csv")))
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
    "Trust-Gate (%d Seeds): Delta-Mittel %.4f, %.0f%% positiv, %.0f%% negativ -> %s\n\n",
    gate$n_seeds, gate$delta_mean, gate$share_positive * 100, gate$share_negative * 100, gate$decision
  ))
  fwrite(
    data.table(case = case_label, decision = gate$decision, delta_mean = gate$delta_mean,
               delta_sd = gate$delta_sd, share_positive = gate$share_positive,
               share_negative = gate$share_negative, n_seeds = gate$n_seeds),
    file.path(project_dir, paste0("pilot_trust_gate_results", output_suffix, ".csv"))
  )

  attr(results, "gate") <- gate
  results
}

brandenburg_results <- run_case("Brandenburg/Potsdam", "")
bayern_results <- run_case("Bayern/Muenchen-Stadt", "_bayern")

fwrite(
  rbind(brandenburg_results, bayern_results),
  file.path(project_dir, "pilot_comparison_results_all.csv")
)

for (res in list(brandenburg_results, bayern_results)) {
  gate <- attr(res, "gate")
  case_label <- res$case[1]
  if (gate$decision == "inconclusive") {
    cat(sprintf("%s: KEIN gerichteter Befund berichtbar (Trust-Gate: inconclusive).\n", case_label))
  } else {
    direction <- if (gate$decision == "robust_improvement") "improvement" else "regression"
    assert_weather_enrichment_finding(gate, direction)
    verb <- if (direction == "improvement") "hilft" else "schadet"
    cat(sprintf("%s: Wetter %s robust (Trust-Gate bestanden).\n", case_label, verb))
  }
}
