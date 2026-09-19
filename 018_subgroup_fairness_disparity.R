rm(list = ls())
suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
})

# =====================================================================
# 018_subgroup_fairness_disparity.R -- erste Realprojekt-Anwendung von
# subgroup_fairness_disparity.R. Sensible Subgruppe: `gender` (female/
# male/other/leer, siehe README). One-vs-Rest "unhealthy" vs. Rest -
# dieselbe Framing-Entscheidung wie 017_probability_calibration.R
# (Modul ist binaer-only, das Projekt selbst ist 3-klassig).
# =====================================================================

source("000_config.R")
source(file.path(project_dir, "modules", "subgroup_fairness_disparity.R"))
source(file.path(project_dir, "modules", "task_data_coercion.R"))

train <- fread(train_path)
# prepare_classif_task_data() entfernt auch id_col vor dem Task-Bau (Clean-
# Code-Review 2026-09-19 fand einen echten Bug: id_col fehlte hier vorher -
# "id" waere als bedeutungsloses numerisches Feature mittrainiert worden).
prepare_classif_task_data(train, target_col, id_col)

task_full <- as_task_classif(train, target = target_col, id = "fairness_check")
task_full$set_col_roles(target_col, add_to = "stratum")

set.seed(seed)
holdout <- rsmp("holdout", ratio = validation_ratio)
holdout$instantiate(task_full)
train_ids <- holdout$train_set(1)
test_ids <- holdout$test_set(1)

learner <- lrn("classif.lightgbm", num_iterations = 200, predict_type = "response")
learner$train(task_full, row_ids = train_ids)
pred <- learner$predict(task_full, row_ids = test_ids)

ovr_class <- "unhealthy"
response_ovr <- ifelse(as.character(pred$response) == ovr_class, ovr_class, "rest")
truth_ovr <- ifelse(as.character(pred$truth) == ovr_class, ovr_class, "rest")
group <- as.character(train[test_ids, gender])
group[group == ""] <- "(leer)"

cat(sprintf("=== Subgruppen-Fairness: '%s' vs. Rest, Subgruppe = gender (n=%d Held-out) ===\n",
            ovr_class, length(response_ovr)))
cat("Gruppengroessen:\n"); print(table(group))

report <- fairness_disparity_report(response_ovr, truth_ovr, group, positive_class = ovr_class)

cat("\n=== Subgruppen-Metriken ===\n")
print(report$subgroup_metrics)

cat("\n=== Paarweise Disparitaet (nach abs_diff sortiert) ===\n")
setorder(report$pairwise, -abs_diff)
print(report$pairwise)

cat(sprintf("\n%d von %d Paar-Metrik-Kombinationen ueberschreiten die Schwelle (abs_diff>0.1 oder ratio<0.8).\n",
            report$n_flagged, nrow(report$pairwise)))
if (report$n_flagged > 0) {
  cat("=> Auffaellig - PRUEFEN, ob diese Disparitaet inhaltlich erklaerbar ist (z.B. echte\n")
  cat("   Praevalenzunterschiede zwischen Gruppen) oder ein Fairness-Problem darstellt.\n")
  cat("   Dieses Skript liefert Zahlen, kein Urteil - siehe Kopfkommentar des Moduls.\n")
} else {
  cat("=> Keine auffaellige Disparitaet zwischen den gender-Subgruppen gefunden.\n")
}

fwrite(report$subgroup_metrics, file.path(artifact_dir, "fairness_subgroup_metrics.csv"))
fwrite(report$pairwise, file.path(artifact_dir, "fairness_pairwise_disparity.csv"))
cat("\nGespeichert:", file.path(artifact_dir, "fairness_pairwise_disparity.csv"), "\n")
