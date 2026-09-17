# Ist der beobachtete BAcc-Delta (Wetter minus Baseline) groesser als das
# Rauschen, das allein durch den Ranger-Modell-Seed entsteht (Datensplit
# bleibt fix)? Analog zu 092_seed_stability.R im Template-Root, nur auf die
# 5 DWD-Piloten angewendet statt auf ein einzelnes Projekt.

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
})

root <- "C:/Users/Andre/Documents/AutoML/ML_Learning"
n_seeds <- 25

cases <- list(
  list(name = "Camping Brandenburg", dir = "openml-weather-campsite-dwd",
       base = "pilot_baseline.csv", weather = "pilot_weather.csv", split_date = "2019-01-01"),
  list(name = "Camping Bayern", dir = "openml-weather-campsite-dwd",
       base = "pilot_baseline_bayern.csv", weather = "pilot_weather_bayern.csv", split_date = "2019-01-01"),
  list(name = "Unfaelle NRW", dir = "openml-destatis-accidents-dwd",
       base = "pilot_baseline.csv", weather = "pilot_weather.csv", split_date = "2022-01-01"),
  list(name = "Sterbefaelle Sachsen", dir = "openml-destatis-deaths-dwd",
       base = "pilot_baseline.csv", weather = "pilot_weather.csv", split_date = "2022-01-01"),
  list(name = "Baugewerbe BW", dir = "openml-destatis-construction-dwd",
       base = "pilot_baseline.csv", weather = "pilot_weather.csv", split_date = "2011-01-01")
)

fit_bacc <- function(dt, split_date, seed) {
  dt <- copy(dt)
  dt[, date := as.IDate(date)]
  setorder(dt, date)
  train <- dt[date < as.IDate(split_date)]
  test <- dt[date >= as.IDate(split_date)]
  drop_cols <- c("id", "date")
  train_data <- train[, .SD, .SDcols = setdiff(names(train), drop_cols)]
  test_data <- test[, .SD, .SDcols = setdiff(names(test), drop_cols)]

  set.seed(seed)
  task <- as_task_classif(train_data, target = "target", id = paste0("s", seed))
  learner <- lrn("classif.ranger", num.trees = 200,
                  respect.unordered.factors = "order", seed = seed)
  learner$predict_type <- "prob"
  learner$train(task)
  test_task <- as_task_classif(test_data, target = "target", id = paste0("s", seed, "_test"))
  pred <- learner$predict(test_task)
  pred$score(msr("classif.bacc"))
}

set.seed(1)
seeds <- sample.int(100000, n_seeds)

summary_rows <- list()
for (cs in cases) {
  base_dt <- fread(file.path(root, cs$dir, cs$base))
  weather_dt <- fread(file.path(root, cs$dir, cs$weather))

  deltas <- sapply(seeds, function(sd) {
    fit_bacc(weather_dt, cs$split_date, sd) - fit_bacc(base_dt, cs$split_date, sd)
  })

  summary_rows[[cs$name]] <- data.table(
    fall = cs$name,
    delta_mean = round(mean(deltas), 4),
    delta_sd = round(sd(deltas), 4),
    delta_min = round(min(deltas), 4),
    delta_max = round(max(deltas), 4),
    anteil_positiv = round(mean(deltas > 0), 2),
    anteil_negativ = round(mean(deltas < 0), 2),
    vorzeichen_stabil = (mean(deltas > 0) >= 0.9 || mean(deltas < 0) >= 0.9)
  )
  cat("fertig:", cs$name, "\n")
}

result <- rbindlist(summary_rows)
cat("\n\n=== Seed-Stabilitaet des BAcc-Delta (Wetter - Baseline), ", n_seeds, " Modell-Seeds, fixer Datensplit ===\n", sep="")
print(result)
