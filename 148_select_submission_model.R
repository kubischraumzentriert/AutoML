rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "005_benchmark_runtime.R"))
source(file.path(project_dir, "db_logging.R"))
source(file.path(project_dir, "provenance.R"))
source(file.path(project_dir, "modules", "final_model_spec.R"))
for (f in list.files(file.path(project_dir, "features"), pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

# Die Auswahl bleibt datengetrieben. Fuer die finale Spezifikation werden aber
# auch die konkrete Kandidatenkonfiguration und deren Herkunft festgehalten.
primary_metric <- baseline_measure_ids[1]

# Gleiches Protokoll fuer alle Kandidaten: 5-fold CV auf Rohfeatures. Fehlt
# fuer einen Algorithmus ein CV-Ergebnis in experiments.db, wird es hier
# nachgerechnet und geloggt. Vorher wurden Holdout-Werte der Baselines gegen
# Tuning-Versuche verglichen (INTERVENTIONS.md, Eingriff 9).
make_cv_learner <- function(constructor) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% constructor())
}

eligible_cv <- intersect(names(base_learner_constructors), names(model_feature_sets))
eligible_cv <- eligible_cv[vapply(eligible_cv, function(a) identical(unname(model_feature_sets[[a]]), "raw"), logical(1))]

db_con <- db_connect()

# Jeder Lauf rechnet die CV-Gegenpruefung fuer alle Kandidaten selbst und
# protokolliert sie im Lauf. Keine Wiederverwendung aelterer Werte aus der
# Datenbank: so zeigt der Bericht die Grundlage der Auswahl vollstaendig.
missing_cv <- eligible_cv

if (length(missing_cv) > 0L) {
  cat("CV-Gegenpruefung je Kandidat:", paste(missing_cv, collapse = ", "), "\n")
  task_cv <- readRDS(task_train_small_path)
  cv_learners <- lapply(missing_cv, function(a) make_cv_learner(base_learner_constructors[[a]]))
  names(cv_learners) <- missing_cv
  cv_bench <- run_timed_benchmark(
    tasks = list(task_cv),
    learners = cv_learners,
    resampling = rsmp("cv", folds = cv_folds),
    measures = msrs(baseline_measure_ids)
  )

  db_proj_id <- db_get_or_create_project(db_con, project_name)
  db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "148_select_submission_model.R")
  db_run_id <- db_create_run(db_con, db_wf_id, seed = seed,
                             notes = "CV-Gegenpruefung fuer Modellauswahl (gleiches Protokoll je Kandidat)")
  db_log_timed_benchmark(
    db_con, db_run_id, cv_bench, measure_names = baseline_measure_ids,
    model_config_fn = function(row) {
      list(
        task_type = "classif",
        algorithm = sub("^.*classif\\.", "", row$learner_id[1]),
        feature_set = "raw",
        preprocessing = "impute_median_mode",
        class_weight_power = NA_real_,
        task_id = row$task_id[1],
        hyperparams = list()
      )
    },
    resampling_strategy = "cv", resampling_folds = cv_folds, resampling_seed = seed
  )
  db_finish_run(db_con, db_run_id)
}

candidates_raw <- dbGetQuery(
  db_con,
  "
  SELECT mc.mconf_id,
         mc.mconf_run_id AS run_id,
         mc.mconf_algorithm AS algorithm,
         mc.mconf_feature_set AS candidate_feature_set,
         mc.mconf_class_weight_power AS candidate_class_weight_power,
         mr.mres_value AS best_value
  FROM metric_result mr
  JOIN model_config mc ON mc.mconf_id = mr.mres_mconf_id
  JOIN resampling rs ON rs.rsmp_id = mr.mres_rsmp_id
  JOIN run r ON r.run_id = mc.mconf_run_id
  JOIN workflow wf ON wf.wf_id = r.run_wf_id
  JOIN project p ON p.proj_id = wf.wf_proj_id
  WHERE p.proj_name = ?
    AND mr.mres_measure_name = ?
    AND mr.mres_fold IS NULL
    AND rs.rsmp_strategy = 'cv'
    AND rs.rsmp_folds = ?
    AND mc.mconf_feature_set = 'raw'
    AND mr.mres_value IS NOT NULL
  ",
  params = list(project_name, primary_metric, cv_folds)
)
DBI::dbDisconnect(db_con)

setDT(candidates_raw)
if (nrow(candidates_raw) == 0L) {
  stop(
    "Keine geloggten Ergebnisse fuer Metrik '", primary_metric,
    "' auf Feature-Set 'raw' in experiments.db gefunden - erst Baseline-/",
    "Boosting-Skripte laufen lassen (030/080/etc.)."
  )
}

# Nur Modelle mit einem reproduzierbaren Final-Trainingspfad duerfen
# automatisch ausgewaehlt werden. Ensemble-/Hilfsalgorithmen bleiben in der DB,
# werden aber nicht faelschlich als direkt trainierbare Submission behandelt.
eligible_models <- intersect(names(base_learner_constructors), names(model_feature_sets))
candidates_raw <- candidates_raw[algorithm %in% eligible_models]
if (nrow(candidates_raw) == 0L) {
  stop(
    "Keine geloggten raw-Kandidaten besitzen einen Final-Trainingspfad in ",
    "base_learner_constructors und model_feature_sets.",
    call. = FALSE
  )
}

# Deterministische Auswahl: bester Wert je Algorithmus, bei Gleichstand
# kleinste mconf_id als stabile Tie-Break-Regel.
setorder(candidates_raw, -best_value, algorithm, mconf_id)
candidates <- candidates_raw[, .SD[1L], by = algorithm]
setorder(candidates, -best_value, algorithm, mconf_id)
candidates[, selected := FALSE]

configured_override <- if (exists("submission_model_override", inherits = FALSE)) {
  submission_model_override
} else {
  NULL
}
selected_model_name <- if (is.null(configured_override)) {
  candidates$algorithm[[1L]]
} else {
  configured_override
}

if (!is.character(selected_model_name) || length(selected_model_name) != 1L ||
    !nzchar(selected_model_name)) {
  stop("submission_model_override muss NULL oder genau ein Modellname sein.", call. = FALSE)
}
if (!selected_model_name %in% candidates$algorithm) {
  stop(
    "Das ausgewaehlte Modell '", selected_model_name,
    "' hat keinen passenden raw-Kandidaten in experiments.db. Erst Benchmark/",
    "Tuning fuer dieses Modell ausfuehren oder Override korrigieren.",
    call. = FALSE
  )
}
if (!selected_model_name %in% names(base_learner_constructors)) {
  stop("Kein base_learner_constructor fuer das ausgewaehlte Modell: ", selected_model_name,
       call. = FALSE)
}
if (!selected_model_name %in% names(model_feature_sets)) {
  stop("Kein model_feature_sets-Eintrag fuer das ausgewaehlte Modell: ", selected_model_name,
       call. = FALSE)
}

selected_row <- candidates[algorithm == selected_model_name][1L]
candidates[algorithm == selected_model_name, selected := TRUE]

feature_set <- unname(model_feature_sets[[selected_model_name]])
base_learner <- base_learner_constructors[[selected_model_name]]()
weight_power <- if (!is.null(model_class_weight_power) &&
                     selected_model_name %in% names(model_class_weight_power)) {
  unname(model_class_weight_power[[selected_model_name]])
} else {
  NULL
}
feature_transform_hash <- feature_transform_function_hash(feature_set)

selection <- list(
  metric_name = primary_metric,
  metric_value = selected_row$best_value[[1L]],
  candidate_mconf_id = selected_row$mconf_id[[1L]],
  candidate_run_id = selected_row$run_id[[1L]],
  candidate_algorithm = selected_row$algorithm[[1L]],
  candidate_feature_set = selected_row$candidate_feature_set[[1L]],
  candidate_class_weight_power = selected_row$candidate_class_weight_power[[1L]],
  selection_source = if (is.null(configured_override)) "metric_selection" else "config_override"
)

final_model_spec <- build_final_model_spec(
  model_name = selected_model_name,
  project_name = project_name,
  target_col = target_col,
  feature_set = feature_set,
  preprocessing = "impute_median_mode",
  positive_class = positive_class,
  class_weight_power = weight_power,
  seed = seed,
  base_learner = base_learner,
  constructor = base_learner_constructors[[selected_model_name]],
  selection = selection,
  feature_transform_hash = feature_transform_hash,
  decision_threshold = NULL
)
spec_paths <- write_final_model_spec(final_model_spec, final_model_spec_path)

cat("=== Bestes", primary_metric, "je Algorithmus (Rohfeatures, aus experiments.db) ===\n")
print(candidates)
cat(
  "\nAusgewaehlt: submission_model_override <- \"", selected_model_name,
  "\" (", primary_metric, " = ", selected_row$best_value[[1L]], ")\n", sep = ""
)
cat("Auswahlquelle: ", selection$selection_source, "\n", sep = "")
cat("Final-model spec hash: ", final_model_spec$spec_hash, "\n", sep = "")
cat("Gespeichert: ", spec_paths$current_path, "\n", sep = "")
cat("Versioniert: ", spec_paths$versioned_path, "\n", sep = "")
fwrite(candidates, submission_model_selection_path)
cat("Auswahlprotokoll: ", submission_model_selection_path, "\n", sep = "")

rm(list = ls())
