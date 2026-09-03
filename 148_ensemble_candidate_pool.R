rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")

# Kandidaten-Pool fuer die Caruana-Greedy-Ensemble-Selection (siehe
# TARGETS.md, 149_ensemble_selection.R). Baut auf dem `147_error_analysis_
# ranger_models.R`-Artefakt auf (train_imputed/eval_imputed, derselbe
# Train/Eval-Split) - kein neuer Split, loses Kopplungsmuster wie die
# uebrigen 147-Folgeskripte. Trainiert einen Pool aus Ranger/LightGBM/
# CatBoost mit variierten Hyperparametern (analog zur Standalone-
# Verifikation in ML_Learning/openml-bank-marketing-ensemble-test/,
# 3 statt 4 Familien - xgboost ist keine Standard-Familie in diesem
# Template, mtry ausgelassen zugunsten der 3 bereits ueberall genutzten
# Familien) und speichert die Wahrscheinlichkeits-Matrizen auf dem Eval-Split
# fuer JEDEN Kandidaten - das war die Integrationshuerde: die uebrigen
# Benchmark-Skripte loggen nur die finale Metrik, nicht die Vorhersagen
# jedes Kandidaten auf einem gemeinsamen Holdout.
if (!file.exists(error_analysis_models_path)) {
  stop("Fehleranalyse-Modelle fehlen. Erst 147_error_analysis_ranger_models.R ausfuehren.")
}
models <- readRDS(error_analysis_models_path)

target_col_name <- models$target_col_name
feature_cols <- models$feature_cols

# Gewichteter Task, IDENTISCH zum Muster in 147_error_analysis_ranger_
# models.R - train_imputed enthaelt die "weight"-Spalte (class_weight_power,
# siehe 000_config.R), die frueher hier faelschlich weggelassen wurde
# (siehe TARGETS.md: der ganze Pool lief dadurch ungewichtet, ~0.07-0.09
# BAcc unter dem etablierten gewichteten Ranger-Deployment). Nicht jeder
# Learner unterstuetzt Gewichte (z.B. LDA nicht) - hier per
# `"weights" %in% learner$properties` je Kandidat geprueft, mit Fallback auf
# den ungewichteten Task.
train_task <- as_task_classif(
  models$train_imputed[, c(target_col_name, feature_cols), with = FALSE],
  target = target_col_name, id = "ensemble_pool_train"
)
train_task_weighted <- train_task$clone()
train_task_weighted$cbind(data.table(weight = models$train_imputed$weight))
train_task_weighted$set_col_roles("weight", roles = "weights_learner")

eval_newdata <- models$eval_imputed[, c(target_col_name, feature_cols), with = FALSE]
truth <- models$truth
class_names <- train_task$class_names

set.seed(seed)
n_per_family <- ensemble_pool_n_per_family

sample_grid <- function(grid, n) grid[sample.int(nrow(grid), min(n, nrow(grid))), , drop = FALSE]

ranger_grid <- sample_grid(expand.grid(
  mtry.ratio = c(0.3, 0.5, 0.7, 1.0), min.node.size = c(1L, 5L, 10L, 20L)
), n_per_family)
lightgbm_grid <- sample_grid(expand.grid(
  num_leaves = c(15L, 31L, 63L, 127L), learning_rate = c(0.01, 0.05, 0.1), feature_fraction = c(0.6, 0.8, 1.0)
), n_per_family)
catboost_grid <- sample_grid(expand.grid(
  depth = c(4L, 6L, 8L), learning_rate = c(0.01, 0.05, 0.1), iterations = c(100L, 200L)
), n_per_family)

# CatBoost (mlr3) akzeptiert keine integer-Spalten (siehe
# 125_catboost_benchmark.R/BACKLOG.md, 2026-09-02) - hier ueber eine
# vorgeschaltete colapply-PipeOp geloest, da train_task/train_task_weighted
# bereits fertige integer-Spalten enthalten koennen (147 liefert manuell
# imputierte Rohdaten, keine mlr3pipelines-Imputation). Die "weights"-
# Eigenschaft bleibt beim GraphLearner erhalten (verifiziert), der
# Gewichtungs-Fallback oben funktioniert daher unveraendert.
make_learner <- function(family, params) {
  if (family == "ranger") {
    lrn("classif.ranger", predict_type = "prob", seed = seed, respect.unordered.factors = "order",
        num.trees = 200, mtry.ratio = params$mtry.ratio, min.node.size = params$min.node.size)
  } else if (family == "lightgbm") {
    lrn("classif.lightgbm", predict_type = "prob", num_iterations = 200,
        num_leaves = params$num_leaves, learning_rate = params$learning_rate, feature_fraction = params$feature_fraction)
  } else {
    catboost_base <- lrn("classif.catboost", predict_type = "prob", logging_level = "Silent",
        depth = params$depth, learning_rate = params$learning_rate, iterations = params$iterations)
    graph_learner <- as_learner(
      po("colapply", applicator = as.numeric, affect_columns = selector_type("integer")) %>>% catboost_base
    )
    graph_learner$predict_type <- "prob"
    graph_learner
  }
}

candidate_specs <- c(
  lapply(seq_len(nrow(ranger_grid)), function(i) list(family = "ranger", params = as.list(ranger_grid[i, ]))),
  lapply(seq_len(nrow(lightgbm_grid)), function(i) list(family = "lightgbm", params = as.list(lightgbm_grid[i, ]))),
  lapply(seq_len(nrow(catboost_grid)), function(i) list(family = "catboost", params = as.list(catboost_grid[i, ])))
)
cat(sprintf("Kandidaten-Pool: %d Modelle (%d ranger / %d lightgbm / %d catboost)\n",
            length(candidate_specs), nrow(ranger_grid), nrow(lightgbm_grid), nrow(catboost_grid)))

t0 <- Sys.time()
prob_list <- vector("list", length(candidate_specs))
labels <- character(length(candidate_specs))
families <- character(length(candidate_specs))
n_weighted <- 0L
for (i in seq_along(candidate_specs)) {
  spec <- candidate_specs[[i]]
  learner <- make_learner(spec$family, spec$params)
  use_weighted <- "weights" %in% learner$properties
  if (use_weighted) n_weighted <- n_weighted + 1L
  fit_task <- if (use_weighted) train_task_weighted else train_task
  learner$train(fit_task)
  pred <- learner$predict_newdata(eval_newdata, task = fit_task)
  prob_list[[i]] <- pred$prob[, class_names, drop = FALSE]
  labels[i] <- sprintf("%s_%d", spec$family, i)
  families[i] <- spec$family
  if (i %% 5 == 0) cat(sprintf("  %d/%d Kandidaten fertig (%.0fs)\n", i, length(candidate_specs), as.numeric(Sys.time() - t0, units = "secs")))
}
cat(sprintf("Gewichtet trainiert: %d/%d Kandidaten (class_weight_power=%.2f)\n",
            n_weighted, length(candidate_specs), class_weight_power))
cat(sprintf("Pool-Training fertig: %.1f Minuten\n", as.numeric(Sys.time() - t0, units = "mins")))

saveRDS(
  list(
    labels = labels, families = families, candidate_specs = candidate_specs,
    class_names = class_names, prob_list = prob_list, truth = truth,
    target_col_name = target_col_name
  ),
  ensemble_candidate_pool_path
)
cat("Gespeichert:", ensemble_candidate_pool_path, "\n")
