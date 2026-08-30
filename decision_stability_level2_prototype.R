rm(list = ls())

# =====================================================================
# decision_stability_level2_prototype.R -- P2, JOSS-Technique-Watch-
# Prototyp #1 (2026-08-30, VeridicalFlow/PCS-inspiriert, siehe
# JOSS_TECHNIQUE_WATCH.md + decision_stability.R).
# =====================================================================
# Wendet decision_stability_report() auf die konkreteste, bereits
# instrumentierte kategoriale Entscheidung dieses Templates an: welcher
# Kandidat (ranger/lightgbm/ensemble) beim Level-2-Protokoll (v3, siehe
# outer_workflow_evaluation_v3_level2.R) fuer den ERSTEN Outer-Fold
# gewinnt. Outer-Train bleibt FIX (derselbe Outer-Resampling-Seed wie
# im eingefrorenen Protokoll v3 - identisch zu den bereits bekannten
# Ergebnissen) - NUR der Inner-Split-Seed (der die 75/25-Aufteilung von
# outer_train in inner_train/inner_tune bestimmt) variiert je
# Wiederholung. Frage: waere bei einer leicht anderen, ebenso
# plausiblen Inner-Split-Ziehung dieselbe Modellwahl herausgekommen?
#
# Bewusst NUR Outer-Fold 1 und NUR die INNERE Modellwahl (kein finales
# Refit/Outer-Test-Scoring, das waere fuer die Stabilitaetsfrage nicht
# noetig und wuerde die Kosten unnoetig verdoppeln).

suppressPackageStartupMessages({
  library(data.table); library(mlr3); library(mlr3learners); library(mlr3extralearners)
  library(mlr3pipelines); library(mlr3tuning); library(mlr3mbo); library(mlr3measures); library(paradox)
})
lgr::get_logger("mlr3")$set_threshold("warn")
lgr::get_logger("bbotk")$set_threshold("warn")

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))
source(file.path(project_dir, "class_multiplier_tuning.R"))
source(file.path(project_dir, "decision_stability.R"))

if (!exists("add_balanced_class_weights")) {
  add_balanced_class_weights <- function(task, power) {
    target_values <- task$data(cols = task$target_names)[[task$target_names]]
    class_counts <- table(target_values)
    base_weights <- length(target_values) / (length(class_counts) * class_counts)
    weights <- base_weights^power
    task_weighted <- task$clone(deep = TRUE)
    task_weighted$id <- paste0(task$id, "_weighted_p", power)
    task_weighted$cbind(data.table(weight = as.numeric(weights[as.character(target_values)])))
    task_weighted$set_col_roles("weight", roles = "weights_learner")
    task_weighted
  }
}
if (!exists("class_weight_power")) class_weight_power <- 1.5

set.seed(seed)
task_full <- readRDS(task_train_small_path)
class_names <- task_full$class_names
tuning_measure_id <- baseline_measure_ids[1]
tuning_measure <- msr(tuning_measure_id)
tuned_baseline_evals <- as.integer(Sys.getenv("LEVEL2_TUNING_EVALS", "10"))
inner_split_ratio <- 0.75

metric_fn <- function(truth, response) tuning_measure$score(
  PredictionClassif$new(row_ids = seq_along(truth), truth = truth, response = response)
)
make_imputed_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}

# Outer-Fold FIXIEREN - IDENTISCH zum eingefrorenen Protokoll v3.
# Ueberschreibbar per Umgebungsvariable DECISION_STABILITY_OUTER_FOLD
# (Default 1) - fuer den n-Erhoehungs-Schritt "Weg A" (2026-08-30,
# siehe BACKLOG.md): dieselben 6 Datensaetze, aber Fold 2/3 statt nur
# Fold 1, OHNE neue Datensaetze zu brauchen.
outer_fold <- as.integer(Sys.getenv("DECISION_STABILITY_OUTER_FOLD", "1"))
outer_resampling <- rsmp("cv", folds = 3)
outer_resampling$instantiate(task_full)
outer_train <- task_full$clone(deep = TRUE)$filter(outer_resampling$train_set(outer_fold))
weighted_outer_train <- add_balanced_class_weights(outer_train, class_weight_power)

cat(sprintf("Projekt: %s | Outer-Fold %d (Train n=%d) FIX, nur Inner-Split-Seed variiert | Budget: %d Evals/Arm\n",
            basename(project_dir), outer_fold, outer_train$nrow, tuned_baseline_evals))

level2_inner_choice <- function(inner_seed) {
  set.seed(inner_seed)
  inner_ids <- partition(outer_train, ratio = inner_split_ratio)
  inner_train_task <- weighted_outer_train$clone(deep = TRUE)$filter(inner_ids$train)
  inner_tune_task <- weighted_outer_train$clone(deep = TRUE)$filter(inner_ids$test)

  ranger_search_space <- ps(
    classif.ranger.mtry.ratio = p_dbl(0.1, 1),
    classif.ranger.min.node.size = p_int(1, 20),
    classif.ranger.sample.fraction = p_dbl(0.5, 1)
  )
  at_ranger <- auto_tuner(
    tuner = mlr3tuning::tnr("random_search"),
    learner = make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = inner_seed)),
    resampling = rsmp("holdout", ratio = inner_split_ratio),
    measure = tuning_measure, search_space = ranger_search_space,
    terminator = trm("evals", n_evals = tuned_baseline_evals)
  )
  at_ranger$train(inner_train_task)
  pred_ranger_inner <- at_ranger$predict(inner_tune_task)
  mult_ranger <- tune_class_multipliers(pred_ranger_inner$prob, pred_ranger_inner$truth, classes = class_names, metric_fn = metric_fn)
  resp_ranger_inner <- apply_class_multipliers(pred_ranger_inner$prob, mult_ranger$multipliers, classes = class_names)
  score_ranger_inner <- metric_fn(pred_ranger_inner$truth, resp_ranger_inner)

  lightgbm_search_space <- ps(
    classif.lightgbm.learning_rate = p_dbl(0.01, 0.3),
    classif.lightgbm.num_leaves = p_int(15, 255),
    classif.lightgbm.min_data_in_leaf = p_int(5, 100),
    classif.lightgbm.feature_fraction = p_dbl(0.5, 1.0),
    classif.lightgbm.bagging_fraction = p_dbl(0.5, 1.0)
  )
  at_lightgbm <- auto_tuner(
    tuner = mlr3tuning::tnr("mbo"),
    learner = make_imputed_learner(lrn("classif.lightgbm", num_iterations = 100, bagging_freq = 1, predict_type = "prob")),
    resampling = rsmp("holdout", ratio = inner_split_ratio),
    measure = tuning_measure, search_space = lightgbm_search_space,
    terminator = trm("evals", n_evals = tuned_baseline_evals)
  )
  at_lightgbm$train(inner_train_task)
  pred_lgbm_inner <- at_lightgbm$predict(inner_tune_task)
  mult_lgbm <- tune_class_multipliers(pred_lgbm_inner$prob, pred_lgbm_inner$truth, classes = class_names, metric_fn = metric_fn)
  resp_lgbm_inner <- apply_class_multipliers(pred_lgbm_inner$prob, mult_lgbm$multipliers, classes = class_names)
  score_lgbm_inner <- metric_fn(pred_lgbm_inner$truth, resp_lgbm_inner)

  prob_ens_inner <- (pred_ranger_inner$prob + pred_lgbm_inner$prob) / 2
  mult_ens <- tune_class_multipliers(prob_ens_inner, pred_ranger_inner$truth, classes = class_names, metric_fn = metric_fn)
  resp_ens_inner <- apply_class_multipliers(prob_ens_inner, mult_ens$multipliers, classes = class_names)
  score_ens_inner <- metric_fn(pred_ranger_inner$truth, resp_ens_inner)

  inner_scores <- c(ranger = score_ranger_inner, lightgbm = score_lgbm_inner, ensemble = score_ens_inner)
  names(which.max(inner_scores))
}

report <- decision_stability_report(
  level2_inner_choice, n_repeats = 10, seed_start = 1,
  label = sprintf("%s, Level-2-Arm-Wahl, Outer-Fold %d (Inner-Split-Seed variiert)", basename(project_dir), outer_fold)
)

out_path <- file.path(artifact_dir, sprintf("decision_stability_level2_report_fold%d.rds", outer_fold))
saveRDS(report, out_path)
cat("\nGespeichert:", out_path, "\n")
