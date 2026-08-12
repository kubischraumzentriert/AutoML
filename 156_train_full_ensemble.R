rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

# Schliesst die bisher offene Luecke (siehe TARGETS.md): 149_ensemble_
# selection.R liefert nur eine Entscheidung ("Greedy-Ensemble gewinnt"),
# 150_train_full_model.R kann aber nur EIN benanntes Modell auf vollen Daten
# trainieren. Dieses Skript trainiert stattdessen jeden EINDEUTIGEN
# ausgewaehlten Kandidaten aus `ensemble_composition_path` (nicht jede
# Wiederholung einzeln - die Wiederholung wird stattdessen als Gewicht beim
# Vorhersage-Mitteln in 157 verwendet) auf dem vollen Trainingsdatensatz.
if (!file.exists(ensemble_composition_path)) {
  stop("Ensemble-Zusammensetzung fehlt. Erst 149_ensemble_selection.R ausfuehren.")
}
composition <- readRDS(ensemble_composition_path)
target_col_name <- composition$target_col_name

train <- fread(train_path)
train[, (id_col) := NULL]
feature_char_cols <- setdiff(names(train)[vapply(train, is.character, logical(1))], target_col_name)
train[, (feature_char_cols) := lapply(.SD, as.factor), .SDcols = feature_char_cols]
train[, (target_col_name) := as.factor(get(target_col_name))]

# Faktorstufen mitspeichern (siehe 150_train_full_model.R) - 157 bildet
# test.csv exakt auf dieselben Stufen ab, unabhaengig von der Stufenmenge
# dort.
feature_levels <- lapply(train[, ..feature_char_cols], levels)

task_full <- as_task_classif(train, target = target_col_name, id = paste0(task_id_prefix, "_full_ensemble"))
# Gewichtet, IDENTISCH zum etablierten Deployment-Pfad (150_train_full_
# model.R nutzt denselben add_balanced_class_weights()-Helfer) - behebt
# denselben Bug wie in 148_ensemble_candidate_pool.R (siehe dort/TARGETS.md):
# ungewichtetes Training kostete bei diesem Projekt ~0.07-0.09 BAcc.
task_full_weighted <- add_balanced_class_weights(task_full, class_weight_power)

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

# Identischer Kandidaten-Aufbau wie 148_ensemble_candidate_pool.R, nur jetzt
# mit Imputations-Pipeline (148 nutzte bereits manuell imputierte Daten aus
# dem 147-Artefakt; hier wird auf rohem train.csv wie in 150 trainiert).
# use_weighted signalisiert, ob der Basis-Learner Gewichte unterstuetzt
# (z.B. LDA nicht - kommt hier aber nicht vor, alle drei Familien
# unterstuetzen weights_learner).
make_candidate_learner <- function(family, params) {
  if (family == "ranger") {
    base <- lrn(
      "classif.ranger", predict_type = "prob", seed = seed, respect.unordered.factors = "order",
      num.trees = 200, mtry.ratio = params$mtry.ratio, min.node.size = params$min.node.size
    )
  } else if (family == "lightgbm") {
    base <- lrn(
      "classif.lightgbm", predict_type = "prob", num_iterations = 200,
      num_leaves = params$num_leaves, learning_rate = params$learning_rate, feature_fraction = params$feature_fraction
    )
  } else {
    base <- lrn(
      "classif.catboost", predict_type = "prob", logging_level = "Silent",
      depth = params$depth, learning_rate = params$learning_rate, iterations = params$iterations
    )
  }
  list(learner = make_baseline_learner(base), use_weighted = "weights" %in% base$properties)
}

cat(sprintf("=== Ensemble-Volltraining: %d eindeutige Kandidaten ===\n", length(composition$selected_composition)))
t0 <- Sys.time()
trained_members <- lapply(composition$selected_composition, function(member) {
  cat(sprintf("  %s (Gewicht %d/%d) ...\n", member$label, member$weight,
              sum(vapply(composition$selected_composition, function(m) m$weight, integer(1)))))
  built <- make_candidate_learner(member$spec$family, member$spec$params)
  fit_task <- if (built$use_weighted) task_full_weighted else task_full
  built$learner$train(fit_task)
  list(learner = built$learner, weight = member$weight, label = member$label)
})
cat(sprintf("Ensemble-Training fertig: %.1f Minuten\n", as.numeric(Sys.time() - t0, units = "mins")))

# --- Experiment-Tracking (SQLite) -------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "156_train_full_ensemble.R")
composition_str <- paste(sprintf("%s:%d", vapply(trained_members, `[[`, character(1), "label"),
                                  vapply(trained_members, `[[`, integer(1), "weight")), collapse = ", ")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = sprintf(
  "Ensemble-Volltraining: %d Mitglieder (%s)", length(trained_members), composition_str
))

model_path <- final_ensemble_full_path(db_run_id)
saveRDS(
  list(members = trained_members, feature_levels = feature_levels,
       class_names = composition$class_names, target_col_name = target_col_name),
  model_path
)

mconf_id <- db_create_model_config(
  db_con, db_run_id,
  task_type = "classif", algorithm = "ensemble", feature_set = "raw",
  preprocessing = "impute_median_mode", class_weight_power = NA_real_, task_id = task_full$id,
  hyperparams = list(model_artifact_path = model_path, n_members = length(trained_members), composition = composition_str)
)

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)

cat("\nZusammensetzung:", composition_str, "\n")
cat("Gespeichert:", model_path, "\n")
cat("Experiment-DB:", experiments_db_path, "(run_id", db_run_id, ")\n")
