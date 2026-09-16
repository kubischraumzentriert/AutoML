# =====================================================================
# outer_workflow_helpers.R -- gemeinsame Plumbing-Bausteine fuer die
# versionierten outer_workflow_evaluation*.R-Benchmark-Protokolle
# (outer_workflow_evaluation_template.R, _v2_fair_baselines.R,
# _v3_level2.R). Extrahiert aus identischem, mehrfach kopiertem Code
# (Fallback-Shims fuer aeltere Projekte, Standard-Arme Ranger/LightGBM-
# default, Zusammenfassungs-Aggregation) -- NICHT aus der fachlichen
# Differenz je Version (Arm-Katalog/Tuning-Budget bleibt bewusst je
# Skript eigenstaendig, damit jede Version weiterhin der exakte,
# eingefrorene Snapshot ihrer jeweiligen datierten Bewertung bleibt,
# siehe BACKLOG.md).
#
# Hintergrund: der merge()-sort=FALSE-Bug (WORKFLOW_GUARDS.md in
# MLR3_Regression) zeigte, dass identischer, mehrfach kopierter Code
# leicht auseinanderlaeuft -- ein Fix an einer Kopie erreicht die
# anderen nicht automatisch. `outer_workflow_evaluation.R` (der
# urspruengliche P1.1-Prototyp mit eigener, hartkodierter BAcc-Scoring-
# Logik) bleibt bewusst UNVERAENDERT und nutzt diese Datei nicht -- er
# ist das historische Original, auf dem die generalisierte Vorlage
# aufbaut, kein aktiv weiterentwickeltes Protokoll.

ow_enable_class_stratification_fallback <- function(task) {
  if (!inherits(task, "TaskClassif")) return(task)
  roles <- task$col_roles
  if (!all(task$target_names %in% roles$stratum)) {
    roles$stratum <- unique(c(roles$stratum, task$target_names))
    task$col_roles <- roles
  }
  task
}

ow_add_balanced_class_weights_fallback <- function(task, power) {
  target_values <- task$data(cols = task$target_names)[[task$target_names]]
  class_counts <- table(target_values)
  base_weights <- length(target_values) / (length(class_counts) * class_counts)
  weights <- base_weights^power
  task_weighted <- task$clone(deep = TRUE)
  task_weighted$id <- paste0(task$id, "_weighted_p", power)
  task_weighted$cbind(data.table::data.table(weight = as.numeric(weights[as.character(target_values)])))
  task_weighted$set_col_roles("weight", roles = "weights_learner")
  task_weighted
}

ow_make_imputed_learner <- function(base_learner, id = NULL) {
  graph <- mlr3pipelines::po("imputemedian") %>>% mlr3pipelines::po("imputemode") %>>% base_learner
  learner <- mlr3pipelines::as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}

ow_run_ranger_default <- function(outer_train, outer_test, tuning_measure, seed) {
  learner <- ow_make_imputed_learner(mlr3::lrn("classif.ranger", predict_type = "prob", seed = seed))
  learner$train(outer_train)
  learner$predict(outer_test)$score(tuning_measure)
}

ow_run_lightgbm_default <- function(outer_train, outer_test, tuning_measure, lightgbm_default_iterations) {
  learner <- ow_make_imputed_learner(
    mlr3::lrn("classif.lightgbm", num_iterations = lightgbm_default_iterations, predict_type = "prob")
  )
  learner$train(outer_train)
  learner$predict(outer_test)$score(tuning_measure)
}

# direction_max-Logik + Aggregation ueber die Outer Folds -- identisch
# in template/v2/v3 dupliziert gewesen.
ow_summarize_results <- function(results, tuning_measure_id) {
  direction_max <- !(tuning_measure_id %in% c("classif.logloss", "classif.ce", "classif.bbrier", "classif.mbrier"))
  results[, .(
    mean_score = mean(score), sd_score = sd(score),
    worst_fold_score = if (direction_max) min(score) else max(score),
    mean_runtime_sec = mean(runtime_sec, na.rm = TRUE)
  ), by = arm][order(if (direction_max) -mean_score else mean_score)]
}
