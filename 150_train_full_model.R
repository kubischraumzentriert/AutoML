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
source(file.path(project_dir, "provenance.R"))
source(file.path(project_dir, "modules", "final_model_spec.R"))
# Alle features/*.R laden statt einzelne Familien-Dateien hartzucodieren -
# bei einem neuen Projekt ohne (oder mit anderen) Feature-Familien sourct das
# unveraendert genau die vorhandenen Dateien, statt beim Kopieren mit "file
# not found" abzustuerzen (zwei unabhaengige Uebertragungen - s6e5, s5e12 -
# scheiterten hier bis das generalisiert wurde). Dateien enthalten nur
# Funktionsdefinitionen, Ladereihenfolge ist daher unerheblich.
for (f in list.files(file.path(project_dir, "features"), pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

final_model_spec <- read_final_model_spec(final_model_spec_path)
model_name <- final_model_spec$model$name
feature_set <- final_model_spec$model$feature_set

if (!model_name %in% names(base_learner_constructors)) {
  stop("Final-model spec refers to an unknown learner: ", model_name, call. = FALSE)
}
current_constructor <- base_learner_constructors[[model_name]]
current_base_learner <- current_constructor()
configured_weight_power <- if (!is.null(model_class_weight_power) &&
                                model_name %in% names(model_class_weight_power)) {
  unname(model_class_weight_power[[model_name]])
} else {
  NULL
}
validate_final_model_spec_context(
  final_model_spec,
  expected = list(
    project_name = project_name,
    target_col = target_col,
    model_name = model_name,
    feature_set = feature_set,
    preprocessing = "impute_median_mode",
    predict_type = current_base_learner$predict_type,
    class_weight_power = configured_weight_power,
    positive_class = positive_class,
    seed = seed,
    learner_params = current_base_learner$param_set$values,
    constructor_hash = final_model_spec_constructor_hash(current_constructor),
    feature_transform_hash = feature_transform_function_hash(feature_set)
  )
)

train <- fread(train_path)
train[, (id_col) := NULL]
train <- apply_feature_set(train, feature_set)

feature_char_cols <- setdiff(names(train)[vapply(train, is.character, logical(1))], target_col)
train[, (feature_char_cols) := lapply(.SD, as.factor), .SDcols = feature_char_cols]
train[, (target_col) := as.factor(get(target_col))]

# Faktorstufen der Merkmale mit dem Modell mitspeichern, damit 155 test.csv
# exakt auf dieselben Stufen abbildet (unabhaengig davon, ob im Test-Set
# zufaellig alle Stufen vorkommen). Zielspalte bewusst ausgeschlossen - die
# gibt es in test.csv nicht.
feature_levels <- lapply(train[, ..feature_char_cols], levels)

task_full <- as_task_classif(train, target = target_col, id = paste0(task_id_prefix, "_full_", model_name))
task_full <- apply_positive_class(task_full, positive_class)

weight_power <- final_model_spec$model$class_weight_power
if (!is.null(weight_power) && weight_power != 0) {
  task_full <- add_balanced_class_weights(task_full, weight_power)
}

cat("=== Finales Training auf vollem Trainingsdatensatz ===\n")
cat("Modell:", model_name, "\n")
cat("Feature-Set:", feature_set, "\n")
cat("Zeilen:", task_full$nrow, " Features:", length(task_full$feature_names), "\n")
if (!is.null(weight_power) && weight_power != 0) {
  cat("class_weight_power:", weight_power, "\n")
}

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

base_learner <- apply_final_model_spec(current_base_learner, final_model_spec)
learner_full <- make_baseline_learner(base_learner)
if (!final_model_spec$model$predict_type %in% learner_full$predict_types) {
  stop("Final-model spec predict_type is unsupported by the imputation pipeline.", call. = FALSE)
}
learner_full$predict_type <- final_model_spec$model$predict_type
learner_full$train(task_full)

# --- Experiment-Tracking (SQLite) -------------------------------------------
# run_id macht die gespeicherte Modell-Datei eindeutig (siehe
# final_model_full_path() in 000_config.R) - ein neuer Lauf ueberschreibt die
# vorherige Datei nicht mehr kommentarlos. Der Pfad wird als Hyperparameter
# geloggt und von 155_predict_submission.R ueber
# db_get_latest_model_artifact_path() wiedergefunden.
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "150_train_full_model.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = paste0("Finales Training auf vollem Trainingsdatensatz (", model_name, ")"))

model_path <- final_model_full_path(model_name, db_run_id)
saveRDS(
  list(learner = learner_full, feature_levels = feature_levels, feature_set = feature_set,
       positive_class = task_full$positive,
       final_model_spec_hash = final_model_spec$spec_hash,
       final_model_spec_version = final_model_spec$schema_version),
  model_path
)

mconf_full <- db_create_model_config(
  db_con, db_run_id,
  task_type = "classif", algorithm = model_name, feature_set = feature_set,
  preprocessing = "impute_median_mode",
  class_weight_power = if (!is.null(weight_power)) weight_power else NA_real_,
  task_id = task_full$id,
  hyperparams = list(
    model_artifact_path = model_path,
    final_model_spec_path = final_model_spec_path,
    final_model_spec_hash = final_model_spec$spec_hash
  ),
  manifest = capture_reproducibility_manifest(
    model = list(
      name = model_name,
      task_type = "classif",
      learner_id = learner_full$id,
      predict_type = learner_full$predict_type,
      positive_class = task_full$positive,
      class_weight_power = if (!is.null(weight_power)) weight_power else NA_real_,
      hyperparams = learner_full$param_set$values,
      final_model_spec_hash = final_model_spec$spec_hash,
      final_model_spec_version = final_model_spec$schema_version
    ),
    preprocessing = list(label = "impute_median_mode", factor_levels_saved = TRUE),
    features = list(
      feature_set = feature_set,
      feature_names_hash = hash_value(task_full$feature_names),
      feature_transform_hash = feature_transform_function_hash(feature_set)
    ),
    artifacts = list(model_artifact_path = model_path, model_artifact_sha256 = sha256_file(model_path)),
    extra = list(
      seed = seed,
      task_id = task_full$id,
      rows = task_full$nrow,
      features = length(task_full$feature_names),
      final_model_spec_hash = final_model_spec$spec_hash
    )
  )
)

db_finish_run(
  db_con, db_run_id,
  train_data_path = train_path,
  feature_set = task_full$feature_names,
  model_artifact_path = model_path
)
DBI::dbDisconnect(db_con)

cat("\nGespeichert:", model_path, "\n")
cat("Experiment-DB:", experiments_db_path, "(run_id", db_run_id, ")\n")
