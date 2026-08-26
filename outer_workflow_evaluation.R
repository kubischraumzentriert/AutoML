# =====================================================================
# outer_workflow_evaluation.R -- P1.1 (ChatGPTs korrigierter Plan):
# "Full-Workflow Outer Evaluation" -- Prototyp.
# =====================================================================
# Frage: wie gut generalisiert der TATSAECHLICH gelebte AutoML-Workflow
# dieses Projekts (klassengewichtetes Ranger-Training via
# add_balanced_class_weights() + BAcc-optimales Multiplier-Tuning via
# class_multiplier_tuning.R), verglichen mit einfacheren Baselines, auf
# echten Outer-Test-Folds, die NIE von irgendeiner Inner-Entscheidung
# (Hyperparameter-Suche, Multiplier-Tuning) beruehrt werden?
#
# Scope laut Nutzerentscheidung: Prototyp zuerst, NUR health_condition,
# 3 Outer Folds (nicht die von ChatGPT vorgeschlagenen >=2 Projekte / >=1
# Datensatz-Minimum wird hier bewusst auf 1 reduziert - siehe BACKLOG.md
# P1.1-Status fuer die Begruendung).
#
# 4 Vergleichs-Arme je Outer-Fold:
#   1. ranger_default   -- ungewichteter Ranger, Default-Hyperparameter.
#   2. lightgbm_default -- ungewichtetes LightGBM, Default-Hyperparameter
#                           (num_iterations = lightgbm_tuning_final_iterations).
#   3. lightgbm_tuned    -- kleines MBO-Suchbudget auf einem Inner-Train/
#                           Tune-Split des Outer-Train, finales Modell mit
#                           den gefundenen Hyperparametern auf dem VOLLEN
#                           Outer-Train (reduziertes Budget ggue. 100_light-
#                           gbm_tuning.R wegen 3x Wiederholung, siehe unten).
#   4. workflow_ranger   -- der ECHTE Projekt-Workflow: klassengewichteter
#                           Ranger (power = class_weight_power), die
#                           Multiplier werden auf einem Inner-Tune-Split
#                           gesucht (tune_class_multipliers()), das finale
#                           Modell wird auf dem VOLLEN Outer-Train trainiert.
#
# Leckage-Garantie (Kernkriterium von P1.1): jeder Outer-Test-Fold wird
# GENAU EINMAL angefasst -- fuer die finale Vorhersage von bereits fertig
# entschiedenen Modellen/Hyperparametern/Multiplikatoren. Keine Inner-
# Entscheidung (Tuning, Multiplier-Suche) sieht jemals Outer-Test-Zeilen.

rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
  library(mlr3tuning)
  library(mlr3mbo)
  library(mlr3measures)
  library(paradox)
})

source("000_config.R")
source(file.path(project_dir, "class_multiplier_tuning.R"))
source(file.path(project_dir, "db_logging.R"))

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

# Reduziertes Suchbudget fuer den Tuned-LightGBM-Arm: dieser Arm laeuft
# EINMAL PRO OUTER FOLD (3x) statt einmal insgesamt wie in
# 100_lightgbm_tuning.R -- beim vollen lightgbm_tuning_evals-Budget waere
# der Prototyp unverhaeltnismaessig teuer. 8 MBO-Evaluationen reichen fuer
# einen fairen "leicht getunt vs. Default"-Vergleich, sind aber NICHT als
# Ersatz fuer das ausfuehrliche 100_lightgbm_tuning.R zu verstehen.
outer_lightgbm_tuning_evals <- 8

n_outer_folds <- 3
inner_split_ratio <- 0.75 # Anteil von Outer-Train, der als Inner-Train dient

make_imputed_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}

bacc_from_response <- function(truth, response) {
  mlr3measures::bacc(truth = truth, response = response)
}

# --- Arm 1: Default Ranger ----------------------------------------------
run_ranger_default <- function(outer_train, outer_test) {
  learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  learner$train(outer_train)
  pred <- learner$predict(outer_test)
  bacc_from_response(pred$truth, pred$response)
}

# --- Arm 2: Default LightGBM ---------------------------------------------
run_lightgbm_default <- function(outer_train, outer_test) {
  learner <- make_imputed_learner(
    lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations, predict_type = "prob")
  )
  learner$train(outer_train)
  pred <- learner$predict(outer_test)
  bacc_from_response(pred$truth, pred$response)
}

# --- Arm 3: leicht getuntes LightGBM (Inner-Suche NUR auf Outer-Train) ---
run_lightgbm_tuned <- function(outer_train, outer_test) {
  inner_ids <- partition(outer_train, ratio = inner_split_ratio)

  search_learner <- make_imputed_learner(
    lrn("classif.lightgbm", num_iterations = lightgbm_tuning_search_iterations, bagging_freq = 1, predict_type = "prob")
  )
  search_space <- ps(
    classif.lightgbm.learning_rate = p_dbl(0.01, 0.3),
    classif.lightgbm.num_leaves = p_int(15, 255),
    classif.lightgbm.min_data_in_leaf = p_int(5, 100),
    classif.lightgbm.feature_fraction = p_dbl(0.5, 1.0),
    classif.lightgbm.bagging_fraction = p_dbl(0.5, 1.0)
  )
  instance <- ti(
    task = outer_train,
    learner = search_learner,
    resampling = rsmp("custom")$instantiate(outer_train, train_sets = list(inner_ids$train), test_sets = list(inner_ids$test)),
    measures = tuning_measure,
    search_space = search_space,
    terminator = trm("evals", n_evals = outer_lightgbm_tuning_evals)
  )
  mlr3tuning::tnr("mbo")$optimize(instance) # mlr3measures::tnr() (true negative rate) ueberschreibt sonst mlr3tuning::tnr()

  best_params <- instance$result_learner_param_vals
  best_params[["classif.lightgbm.num_iterations"]] <- lightgbm_tuning_final_iterations

  final_learner <- make_imputed_learner(lrn("classif.lightgbm", predict_type = "prob"))
  final_learner$param_set$values <- best_params
  final_learner$train(outer_train) # voller Outer-Train, NICHT nur inner_ids$train
  pred <- final_learner$predict(outer_test)
  bacc_from_response(pred$truth, pred$response)
}

# --- Arm 4: der echte Projekt-Workflow (gewichteter Ranger + Multiplier) -
run_workflow_ranger <- function(outer_train, outer_test) {
  inner_ids <- partition(outer_train, ratio = inner_split_ratio)

  weighted_outer_train <- add_balanced_class_weights(outer_train, class_weight_power)
  inner_train_task <- weighted_outer_train$clone(deep = TRUE)$filter(inner_ids$train)
  inner_tune_task <- weighted_outer_train$clone(deep = TRUE)$filter(inner_ids$test)

  inner_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  inner_learner$train(inner_train_task)
  inner_pred <- inner_learner$predict(inner_tune_task)
  probs_inner <- inner_pred$prob

  mult <- tune_class_multipliers(probs_inner, inner_pred$truth, classes = class_names)

  final_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  final_learner$train(weighted_outer_train) # voller (gewichteter) Outer-Train
  test_pred <- final_learner$predict(outer_test)
  response_adj <- apply_class_multipliers(test_pred$prob, mult$multipliers, classes = class_names)
  bacc_from_response(test_pred$truth, response_adj)
}

# --- Outer-CV-Schleife ----------------------------------------------------
outer_resampling <- rsmp("cv", folds = n_outer_folds)
outer_resampling$instantiate(task_full)

results <- data.table(
  outer_fold = integer(0), arm = character(0), bacc = numeric(0), runtime_sec = numeric(0)
)

arms <- list(
  ranger_default = run_ranger_default,
  lightgbm_default = run_lightgbm_default,
  lightgbm_tuned = run_lightgbm_tuned,
  workflow_ranger = run_workflow_ranger
)

for (fold in seq_len(n_outer_folds)) {
  train_ids <- outer_resampling$train_set(fold)
  test_ids <- outer_resampling$test_set(fold)
  outer_train <- task_full$clone(deep = TRUE)$filter(train_ids)
  outer_test <- task_full$clone(deep = TRUE)$filter(test_ids)

  cat(sprintf("\n=== Outer Fold %d/%d (Train n=%d, Test n=%d) ===\n", fold, n_outer_folds, outer_train$nrow, outer_test$nrow))

  for (arm_name in names(arms)) {
    t0 <- Sys.time()
    bacc <- arms[[arm_name]](outer_train, outer_test)
    runtime_sec <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("  %-18s BAcc = %.4f  (%.1fs)\n", arm_name, bacc, runtime_sec))
    results <- rbind(results, data.table(outer_fold = fold, arm = arm_name, bacc = bacc, runtime_sec = runtime_sec))
  }
}

summary_dt <- results[, .(
  mean_bacc = mean(bacc), sd_bacc = sd(bacc), worst_fold_bacc = min(bacc),
  mean_runtime_sec = mean(runtime_sec)
), by = arm][order(-mean_bacc)]

cat("\n=== P1.1-Prototyp: Zusammenfassung ueber", n_outer_folds, "Outer Folds ===\n")
print(summary_dt)

outer_workflow_evaluation_results_path <- file.path(artifact_dir, "outer_workflow_evaluation_results.csv")
outer_workflow_evaluation_summary_path <- file.path(artifact_dir, "outer_workflow_evaluation_summary.csv")
fwrite(results, outer_workflow_evaluation_results_path)
fwrite(summary_dt, outer_workflow_evaluation_summary_path)
cat("\nDetailergebnisse:", outer_workflow_evaluation_results_path, "\n")
cat("Zusammenfassung:  ", outer_workflow_evaluation_summary_path, "\n")
