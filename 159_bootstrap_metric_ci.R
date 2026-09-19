rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3pipelines)
  library(mlr3measures)
})

# =====================================================================
# 159_bootstrap_metric_ci.R -- Realprojekt-Anwendung von
# bootstrap_metric_ci.R (Backlog-Kandidat "Bootstrap-CI fuer die finale
# Metrik", 2026-09-17) an `health_condition`.
# =====================================================================
# Der bisher berichtete Endwert (README.md/joss/paper.md: BAcc 0.9482)
# ist eine Kaggle-Leaderboard-Zahl - die echten Test-Labels dafuer liegen
# NICHT lokal vor (kein reproduzierbares Bootstrap moeglich, siehe
# README_DETAILS.md "Ranger-Stand BAcc 0.9482 (Platz 618/1104)"). Dieses
# Skript demonstriert das Modul stattdessen ehrlich an dem, was lokal
# tatsaechlich vorliegt: gepoolte Out-of-Fold-Vorhersagen (5-fach CV) des
# TATSAECHLICH gelebten Workflows (klassengewichteter Ranger) auf dem
# 10%-Trainingssubset - liefert ein CI fuer die interne CV-Schaetzung
# selbst UND einen gepaarten Vergleich ggue. ungewichtetem Default-Ranger
# (beantwortet "ist die Klassengewichtung wirklich besser, nicht nur
# zufaellig", analog zum bereits mehrfach gefuehrten Vergleich in
# outer_workflow_evaluation*.R, hier aber guenstig per einfacher CV statt
# Outer-CV-Protokoll).

source("000_config.R")
source(file.path(project_dir, "modules", "bootstrap_metric_ci.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_full <- readRDS(task_train_small_path)
task_full <- enable_class_stratification(task_full)
class_names <- task_full$class_names
tuning_measure_id <- baseline_measure_ids[1]
tuning_measure <- msr(tuning_measure_id)

make_imputed_learner <- function(base_learner) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  as_learner(graph)
}

n_folds <- 5L
resampling <- rsmp("cv", folds = n_folds)
resampling$instantiate(task_full)

weighted_task <- add_balanced_class_weights(task_full, class_weight_power)

cat(sprintf("=== %d-fach OOF: workflow_ranger (klassengewichtet) vs. ranger_default ===\n", n_folds))
oof_workflow <- vector("list", n_folds)
oof_default <- vector("list", n_folds)

for (fold in seq_len(n_folds)) {
  train_ids <- resampling$train_set(fold)
  test_ids <- resampling$test_set(fold)

  learner_workflow <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  learner_workflow$train(weighted_task$clone(deep = TRUE)$filter(train_ids))
  pred_workflow <- learner_workflow$predict(task_full$clone(deep = TRUE)$filter(test_ids))

  learner_default <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  learner_default$train(task_full$clone(deep = TRUE)$filter(train_ids))
  pred_default <- learner_default$predict(task_full$clone(deep = TRUE)$filter(test_ids))

  oof_workflow[[fold]] <- data.table(row_id = test_ids, truth = as.character(pred_workflow$truth), response = as.character(pred_workflow$response))
  oof_default[[fold]] <- data.table(row_id = test_ids, truth = as.character(pred_default$truth), response = as.character(pred_default$response))
  cat(sprintf("  Fold %d/%d fertig\n", fold, n_folds))
}

oof_workflow <- rbindlist(oof_workflow)[order(row_id)]
oof_default <- rbindlist(oof_default)[order(row_id)]
stopifnot("oof_workflow und oof_default muessen dieselben row_ids in derselben Reihenfolge haben (fuer einen gepaarten Vergleich)" = identical(oof_workflow$row_id, oof_default$row_id))

truth <- factor(oof_workflow$truth, levels = class_names)
resp_workflow <- factor(oof_workflow$response, levels = class_names)
resp_default <- factor(oof_default$response, levels = class_names)

bacc_fn <- function(t, r) mlr3measures::bacc(truth = t, response = r)

ci_workflow <- bootstrap_metric_ci(truth, resp_workflow, bacc_fn, B = 2000, conf_level = 0.90, seed = seed)
ci_default <- bootstrap_metric_ci(truth, resp_default, bacc_fn, B = 2000, conf_level = 0.90, seed = seed)
comparison <- bootstrap_paired_comparison(truth, resp_workflow, resp_default, bacc_fn, B = 2000, conf_level = 0.90, seed = seed)

cat("\n=== Ergebnis ===\n")
cat(sprintf("workflow_ranger (gewichtet):  BAcc = %s\n", format_metric_ci(ci_workflow)))
cat(sprintf("ranger_default (ungewichtet): BAcc = %s\n", format_metric_ci(ci_default)))
cat(sprintf("Gepaarter Unterschied (workflow - default): %.4f [%.0f%%-CI: %.4f, %.4f], p=%.4f, signifikant=%s\n",
            comparison$delta, comparison$conf_level * 100, comparison$ci_lower, comparison$ci_upper,
            comparison$p_value, comparison$significant))

results <- data.table(
  arm = c("workflow_ranger", "ranger_default"),
  point = c(ci_workflow$point, ci_default$point),
  ci_lower = c(ci_workflow$ci_lower, ci_default$ci_lower),
  ci_upper = c(ci_workflow$ci_upper, ci_default$ci_upper)
)
bootstrap_metric_ci_results_path <- file.path(artifact_dir, "bootstrap_metric_ci_results.csv")
fwrite(results, bootstrap_metric_ci_results_path)
cat("\nGespeichert:", bootstrap_metric_ci_results_path, "\n")
