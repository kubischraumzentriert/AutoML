rm(list = ls())

# =====================================================================
# outer_workflow_evaluation_v4_decision_rule.R -- Benchmark-Protokoll
# Version 4 (Entscheidungsregel). Plan: BACKLOG.md, Abschnitt
# "Protokoll v4 Entscheidungsregel - geplant" (2026-11-01).
# =====================================================================
# Frage: Ist der Vorteil von workflow_ranger gegenueber getunten Baselines
# nur ein Entscheidungsregel-Effekt (Klassen-Multiplikatoren), oder traegt
# die Klassengewichtung zusaetzlich etwas bei?
#
# Gegenueber v2 (Folds, Seed, Tuning-Budget, Metrik BAcc und die Arm-
# Implementierungen bleiben gleich):
# 1. REPRODUKTION: ranger_default, lightgbm_default, tuned_ranger,
#    tuned_lightgbm, best_single_tuned_model und workflow_ranger laufen wie in
#    v2 bei Schwelle 0.5. Eine Abweichung gegen v2 ist ein Befund
#    (Determinismus der Tuner), kein Fehler, der still korrigiert wird.
# 2. NEU *_thr: dieselbe Modellfamilie, aber mit Klassen-Multiplikatoren
#    (tune_class_multipliers, wie workflow_ranger). Die Multiplikatoren werden
#    auf einem 75/25-Split des Outer-Train bestimmt: Der Lerner mit den finalen
#    Hyperparametern wird auf den 75 % trainiert und auf den 25 % optimiert;
#    das Testmodell ist auf dem vollen Outer-Train trainiert. Der Outer-Test
#    fliesst nie in die Auswahl ein.
#      ranger_default_thr, lightgbm_default_thr: nur Regel (ohne Tuning, Gewichte)
#      tuned_ranger_thr, tuned_lightgbm_thr: das getunte Modell aus v2, nur mit Regel
#      best_single_tuned_thr: Auswahl nach dem INNEREN Score MIT Regel. Der
#        Score ist auf dem 25 %-Split in-sample fuer die Schwelle; beide
#        Kandidaten sind dadurch gleich verzerrt.
# 3. ZUFALLSFOLGE: Alle Zusatzschritte laufen in keep_rng(), sodass die
#    Zufallsfolge der v2-Arme unveraendert bleibt.
# 4. FAIL-CLOSED: Fehlt class_multiplier_tuning.R, bricht der Lauf ab.
#    v2 wuerde die Korrektur in diesem Fall stillschweigend auslassen.
#
# Ausfuehrung: wie v2, im Projektordner (ML_Learning/openml-cc18-<ds> bzw.
# Repo-Wurzel). Ausgabe: outer_workflow_evaluation_v4_{results,summary}.csv.
# ADR-008: diese Datei ist neu. Sie wird nach dem ersten berichteten Lauf
# eingefroren; v2 bleibt unveraendert.

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
lgr::get_logger("mlr3")$set_threshold("warn")
lgr::get_logger("bbotk")$set_threshold("warn")

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))
source(file.path(project_dir, "protocols", "outer_workflow_helpers.R"))

# Fail-closed: Die Multiplikator-Korrektur muss vorhanden sein. In den
# ML_Learning-Kopien liegt das Modul im Projektwurzelverzeichnis, im Repo unter modules/.
mult_candidates <- c(
  file.path(project_dir, "modules", "class_multiplier_tuning.R"),
  file.path(project_dir, "class_multiplier_tuning.R")
)
mult_path <- mult_candidates[file.exists(mult_candidates)][1]
if (is.na(mult_path)) stop("class_multiplier_tuning.R fehlt: ", paste(mult_candidates, collapse = " | "))
source(mult_path)

if (!exists("enable_class_stratification")) enable_class_stratification <- ow_enable_class_stratification_fallback
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
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}

task_full <- readRDS(task_train_small_path)
task_full <- enable_class_stratification(task_full)
class_names <- task_full$class_names

tuning_measure_id <- baseline_measure_ids[1]
if (tuning_measure_id != "classif.bacc") {
  stop("Protokoll v4 ist auf classif.bacc spezifiziert, nicht auf ", tuning_measure_id)
}
tuning_measure <- msr(tuning_measure_id)
lightgbm_default_iterations <- if (exists("lightgbm_tuning_final_iterations")) lightgbm_tuning_final_iterations else 200
tuned_baseline_evals <- 15 # identisch zu v2
n_outer_folds <- 3
inner_split_ratio <- 0.75

cat(sprintf(
  "Projekt: %s | Metrik: %s | Tuning-Budget/Arm: %d Evals | Multiplier-Korrektur: %s\n",
  basename(project_dir), tuning_measure_id, tuned_baseline_evals, mult_path
))

make_imputed_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}

score_prediction <- function(pred) pred$score(tuning_measure)

# Wendet Klassen-Multiplikatoren auf die Wahrscheinlichkeiten an und liefert
# eine PredictionClassif mit der angepassten Antwort (wie in workflow_ranger).
apply_multipliers_pred <- function(pred, multipliers) {
  response_adj <- apply_class_multipliers(pred$prob, multipliers, classes = class_names)
  PredictionClassif$new(
    row_ids = pred$row_ids, truth = pred$truth, response = response_adj, prob = pred$prob
  )
}

# Fuehrt expr aus und stellt danach den globalen Zufallszustand wieder her.
keep_rng <- function(expr) {
  had_seed <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  if (had_seed) old_seed <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
  on.exit(if (had_seed) assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
  force(expr)
}

# Klassen-Multiplikatoren aus einem 75/25-Split des Outer-Train. `template` ist
# ein ungetrainierter Lerner mit den finalen Hyperparametern. Liefert die
# Multiplikatoren und den inneren Score (in-sample auf dem 25 %-Split).
fit_multipliers <- function(template, outer_train) {
  keep_rng({
    ids <- partition(outer_train, ratio = inner_split_ratio)
    inner_train <- outer_train$clone(deep = TRUE)$filter(ids$train)
    inner_tune <- outer_train$clone(deep = TRUE)$filter(ids$test)
    learner <- template$clone(deep = TRUE)
    learner$train(inner_train)
    inner_pred <- learner$predict(inner_tune)
    mult <- tune_class_multipliers(inner_pred$prob, inner_pred$truth, classes = class_names)
    list(
      multipliers = mult$multipliers,
      inner_score = score_prediction(apply_multipliers_pred(inner_pred, mult$multipliers))
    )
  })
}

format_mult <- function(m) paste(sprintf("%s=%.3f", names(m), m), collapse = ";")

# Lerner-Vorlage aus einem getunten AutoTuner: der trainierte Lerner traegt
# die Tuning-Ergebnisse. Die Konsistenz wird geprueft (fail-closed).
tuned_template <- function(at) {
  tmpl <- at$learner$clone(deep = TRUE)
  best <- at$tuning_result$learner_param_vals[[1]]
  current <- tmpl$param_set$values
  for (name in names(best)) {
    if (is.null(current[[name]]) || !isTRUE(all.equal(current[[name]], best[[name]]))) {
      stop("Tuning-Parameter nicht konsistent mit dem Lerner: ", name)
    }
  }
  tmpl
}

# --- Default-Lerner (wie ow_run_* in outer_workflow_helpers.R) -----------
ranger_template <- function() {
  make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
}
lightgbm_template <- function() {
  make_imputed_learner(lrn("classif.lightgbm", num_iterations = lightgbm_default_iterations, predict_type = "prob"))
}

# --- Getunte Arme (Code wie v2, zusaetzlich: Rueckgabe des AutoTuners) ----
run_tuned <- function(base_learner, search_space, tuner, outer_train, outer_test) {
  at <- auto_tuner(
    tuner = tuner, learner = base_learner,
    resampling = rsmp("holdout", ratio = inner_split_ratio),
    measure = tuning_measure, search_space = search_space,
    terminator = trm("evals", n_evals = tuned_baseline_evals)
  )
  at$train(outer_train)
  list(
    pred = at$predict(outer_test),
    inner_score = at$tuning_result[[tuning_measure_id]],
    template = tuned_template(at)
  )
}

run_tuned_ranger <- function(outer_train, outer_test) {
  base_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  search_space <- ps(
    classif.ranger.mtry.ratio = p_dbl(0.1, 1),
    classif.ranger.min.node.size = p_int(1, 20),
    classif.ranger.sample.fraction = p_dbl(0.5, 1)
  )
  run_tuned(base_learner, search_space, mlr3tuning::tnr("random_search"), outer_train, outer_test)
}

run_tuned_lightgbm <- function(outer_train, outer_test) {
  base_learner <- make_imputed_learner(
    lrn("classif.lightgbm", num_iterations = 100, bagging_freq = 1, predict_type = "prob")
  )
  search_space <- ps(
    classif.lightgbm.learning_rate = p_dbl(0.01, 0.3),
    classif.lightgbm.num_leaves = p_int(15, 255),
    classif.lightgbm.min_data_in_leaf = p_int(5, 100),
    classif.lightgbm.feature_fraction = p_dbl(0.5, 1.0),
    classif.lightgbm.bagging_fraction = p_dbl(0.5, 1.0)
  )
  run_tuned(base_learner, search_space, mlr3tuning::tnr("mbo"), outer_train, outer_test)
}

# --- workflow_ranger (wie v2) --------------------------------------------
run_workflow_ranger <- function(outer_train, outer_test) {
  weighted_outer_train <- add_balanced_class_weights(outer_train, class_weight_power)
  inner_ids <- partition(outer_train, ratio = inner_split_ratio)
  inner_train_task <- weighted_outer_train$clone(deep = TRUE)$filter(inner_ids$train)
  inner_tune_task <- weighted_outer_train$clone(deep = TRUE)$filter(inner_ids$test)
  inner_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  inner_learner$train(inner_train_task)
  inner_pred <- inner_learner$predict(inner_tune_task)
  mult <- tune_class_multipliers(inner_pred$prob, inner_pred$truth, classes = class_names)
  final_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  final_learner$train(weighted_outer_train)
  test_pred <- final_learner$predict(outer_test)
  list(score = score_prediction(apply_multipliers_pred(test_pred, mult$multipliers)), multipliers = mult$multipliers)
}

# --- Outer-CV-Schleife ----------------------------------------------------
outer_resampling <- rsmp("cv", folds = n_outer_folds)
outer_resampling$instantiate(task_full) # gleicher Seed -> identische Folds wie v1/v2

results <- data.table(
  outer_fold = integer(0), arm = character(0), score = numeric(0),
  runtime_sec = numeric(0), detail = character(0)
)

for (fold in seq_len(n_outer_folds)) {
  outer_train <- task_full$clone(deep = TRUE)$filter(outer_resampling$train_set(fold))
  outer_test <- task_full$clone(deep = TRUE)$filter(outer_resampling$test_set(fold))

  cat(sprintf("\n=== Outer Fold %d/%d (Train n=%d, Test n=%d) ===\n", fold, n_outer_folds, outer_train$nrow, outer_test$nrow))

  record <- function(arm, score, t0, detail = NA_character_, runtime = TRUE) {
    secs <- if (runtime) as.numeric(difftime(Sys.time(), t0, units = "secs")) else NA_real_
    results <<- rbind(results, data.table(outer_fold = fold, arm = arm, score = score, runtime_sec = secs, detail = detail))
    cat(sprintf("  %-24s %s = %.4f%s\n", arm, tuning_measure_id, score,
                if (is.na(detail)) "" else paste0("  [", detail, "]")))
  }

  # Arm 1: ranger_default und seine Entscheidungsregel-Variante
  t0 <- Sys.time()
  rd_learner <- ranger_template()
  rd_learner$train(outer_train)
  rd_pred <- rd_learner$predict(outer_test)
  record("ranger_default", score_prediction(rd_pred), t0)
  rd_mult <- fit_multipliers(ranger_template(), outer_train)
  record("ranger_default_thr", score_prediction(apply_multipliers_pred(rd_pred, rd_mult$multipliers)), t0,
         detail = format_mult(rd_mult$multipliers))

  # Arm 2: lightgbm_default und seine Entscheidungsregel-Variante
  t0 <- Sys.time()
  ld_learner <- lightgbm_template()
  ld_learner$train(outer_train)
  ld_pred <- ld_learner$predict(outer_test)
  record("lightgbm_default", score_prediction(ld_pred), t0)
  ld_mult <- fit_multipliers(lightgbm_template(), outer_train)
  record("lightgbm_default_thr", score_prediction(apply_multipliers_pred(ld_pred, ld_mult$multipliers)), t0,
         detail = format_mult(ld_mult$multipliers))

  # Arm 3: tuned_ranger und tuned_ranger_thr
  t0 <- Sys.time()
  r_tr <- run_tuned_ranger(outer_train, outer_test)
  record("tuned_ranger", score_prediction(r_tr$pred), t0)
  tr_mult <- fit_multipliers(r_tr$template, outer_train)
  tr_thr_score <- score_prediction(apply_multipliers_pred(r_tr$pred, tr_mult$multipliers))
  record("tuned_ranger_thr", tr_thr_score, t0, detail = format_mult(tr_mult$multipliers))

  # Arm 4: tuned_lightgbm und tuned_lightgbm_thr
  t0 <- Sys.time()
  r_tl <- run_tuned_lightgbm(outer_train, outer_test)
  record("tuned_lightgbm", score_prediction(r_tl$pred), t0)
  tl_mult <- fit_multipliers(r_tl$template, outer_train)
  tl_thr_score <- score_prediction(apply_multipliers_pred(r_tl$pred, tl_mult$multipliers))
  record("tuned_lightgbm_thr", tl_thr_score, t0, detail = format_mult(tl_mult$multipliers))

  # Best Single (ohne Regel, wie v2): Auswahl nach INNEREM Score ohne Schwelle
  best_is_ranger <- r_tr$inner_score >= r_tl$inner_score
  record("best_single_tuned_model", if (best_is_ranger) score_prediction(r_tr$pred) else score_prediction(r_tl$pred),
         t0, detail = if (best_is_ranger) "chosen=ranger" else "chosen=lightgbm", runtime = FALSE)

  # Best Single mit Regel: Auswahl nach INNEREM Score MIT Schwelle
  best_thr_is_ranger <- tr_mult$inner_score >= tl_mult$inner_score
  record("best_single_tuned_thr",
         if (best_thr_is_ranger) tr_thr_score else tl_thr_score,
         t0, detail = if (best_thr_is_ranger) "chosen=ranger" else "chosen=lightgbm", runtime = FALSE)

  # Arm 5: workflow_ranger (wie v2)
  t0 <- Sys.time()
  wf <- run_workflow_ranger(outer_train, outer_test)
  record("workflow_ranger", wf$score, t0, detail = format_mult(wf$multipliers))
}

summary_dt <- ow_summarize_results(results, tuning_measure_id)

cat("\n=== Protokoll v4 (Entscheidungsregel): Zusammenfassung ueber", n_outer_folds, "Outer Folds (Metrik:", tuning_measure_id, ") ===\n")
print(summary_dt)

fwrite(results, file.path(artifact_dir, "outer_workflow_evaluation_v4_results.csv"))
fwrite(summary_dt, file.path(artifact_dir, "outer_workflow_evaluation_v4_summary.csv"))
cat("\nErgebnisse gespeichert unter:", artifact_dir, "\n")
