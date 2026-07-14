library(targets)

# Deckt den etablierten *finalen* Workflow ab (Task-Erzeugung, Feature-
# Familien, finale Modelle auf dem 10%-Subset, volles Training, Submission) -
# nicht die explorativen Einzel-Experimente (030-145), die eher Analyse-
# Werkzeuge fuer die Modellauswahl sind als Teil einer wiederholbaren
# Produktions-Pipeline. tar_make() ersetzt das manuelle Nacheinander-Ausfuehren
# von 020/025/070/150/155 durch einen expliziten, cachenden Abhaengigkeits-
# graphen: bei einer Config-Aenderung (z.B. class_weight_power) rechnet
# tar_make() automatisch nur die betroffenen nachgelagerten Ziele neu.

project_dir <- normalizePath(getwd())
source("000_config.R")
source(file.path(project_dir, "db_logging.R"))
# _targets.R wird bei jedem tar_make()-Aufruf frisch neu ausgefuehrt (nicht
# gecacht wie die Ziele selbst) - der aufgeloeste Wert spiegelt daher immer
# den aktuellen Stand von submission_model_override/submission_model_selection.csv
# wider und fliesst korrekt in den Hash der abhaengigen Ziele ein (siehe
# TEMPLATE_FRICTION.md des s6e5-Projekts fuer die Herleitung).
submission_model_name <- resolve_submission_model_name()
source(file.path(project_dir, "features", "utils.R"))
source(file.path(project_dir, "features", "bmi.R"))
source(file.path(project_dir, "features", "sleep.R"))
source(file.path(project_dir, "features", "activity.R"))
source(file.path(project_dir, "features", "hydration.R"))
source(file.path(project_dir, "features", "cardio.R"))
source(file.path(project_dir, "features", "interactions.R"))
source(file.path(project_dir, "features", "surrogate_guided.R"))

tar_option_set(
  packages = c(
    "data.table", "tidyverse", "mlr3", "mlr3learners",
    "mlr3extralearners", "mlr3pipelines"
  )
)

feature_family_functions <- list(
  bmi = add_bmi_features,
  sleep = add_sleep_features,
  activity = add_activity_features,
  hydration = add_hydration_features,
  cardio = add_cardio_features,
  interactions = add_interaction_features
)

build_stratified_subset <- function(train) {
  train %>%
    as_tibble() %>%
    group_by(.data[[target_col]]) %>%
    slice_sample(prop = subset_fraction) %>%
    ungroup() %>%
    select(-all_of(id_col))
}

finalize_task <- function(data, id) {
  data <- data %>%
    mutate(
      across(where(is.character), as.factor),
      !!target_col := as.factor(.data[[target_col]])
    )
  as_task_classif(data, target = target_col, id = id)
}

build_combined_features <- function(train, families) {
  set.seed(seed)
  raw_subset <- build_stratified_subset(train)
  Reduce(function(data, family) feature_family_functions[[family]](data), families, raw_subset)
}

make_baseline_learner <- function(base_learner) {
  as_learner(po("imputemedian") %>>% po("imputemode") %>>% base_learner)
}

list(
  # --- Rohdaten & 10%-Subset-Tasks (entspricht 020/025) ---------------------
  tar_target(train_raw_file, train_path, format = "file"),
  tar_target(train_raw, fread(train_raw_file)),

  tar_target(feature_family_name, feature_families),
  tar_target(
    task_family,
    {
      set.seed(seed)
      raw_subset <- build_stratified_subset(train_raw)
      featured <- feature_family_functions[[feature_family_name]](raw_subset)
      finalize_task(featured, id = paste0(task_id_prefix, "_", feature_family_name))
    },
    pattern = map(feature_family_name),
    iteration = "list"
  ),

  tar_target(task_raw, {
    set.seed(seed)
    finalize_task(build_stratified_subset(train_raw), id = task_id_prefix)
  }),

  tar_target(task_combined, {
    finalize_task(
      build_combined_features(train_raw, feature_families),
      id = paste0(task_id_prefix, "_features")
    )
  }),

  tar_target(task_selected, {
    finalize_task(
      build_combined_features(train_raw, selected_families),
      id = paste0(task_id_prefix, "_selected")
    )
  }),

  # --- Finale Modelle auf dem Subset (entspricht 070) ------------------------
  tar_target(model_name, names(model_feature_sets)),
  tar_target(
    final_model_subset,
    {
      feature_set <- model_feature_sets[[model_name]]
      task <- switch(feature_set,
        raw = task_raw,
        features = task_combined,
        selected = task_selected,
        surrogate_guided = finalize_task(
          apply_feature_set(task_raw$data(), "surrogate_guided"),
          id = paste0(task_id_prefix, "_surrogate_guided")
        ),
        stop("Feature-Familien-Tasks sind in der Pipeline nicht direkt indexierbar - ", feature_set, " wird von keinem Modell in model_feature_sets verwendet.")
      )

      weight_power <- model_class_weight_power[[model_name]]
      if (!is.null(weight_power) && weight_power != 0) {
        task <- add_balanced_class_weights(task, weight_power)
      }

      learner <- make_baseline_learner(base_learner_constructors[[model_name]]())
      set.seed(seed)
      learner$train(task)
      learner
    },
    pattern = map(model_name),
    iteration = "list"
  ),

  # --- Volles Training & Submission (entspricht 150/155) --------------------
  tar_target(train_full_file, train_path, format = "file"),
  tar_target(train_full, {
    train <- fread(train_full_file)
    train[, (id_col) := NULL]
    train
  }),

  tar_target(train_full_model_data, {
    feature_set <- model_feature_sets[[submission_model_name]]
    train <- apply_feature_set(train_full, feature_set)
    setDT(train)
    feature_char_cols <- setdiff(names(train)[vapply(train, is.character, logical(1))], target_col)
    train[, (feature_char_cols) := lapply(.SD, as.factor), .SDcols = feature_char_cols]
    train[, (target_col) := as.factor(get(target_col))]
    train
  }),

  tar_target(full_feature_levels, {
    feature_char_cols <- setdiff(names(train_full_model_data)[vapply(train_full_model_data, is.factor, logical(1))], target_col)
    lapply(train_full_model_data[, ..feature_char_cols], levels)
  }),

  tar_target(task_full, {
    as_task_classif(train_full_model_data, target = target_col, id = paste0(task_id_prefix, "_full_", submission_model_name))
  }),

  tar_target(task_full_weighted, {
    weight_power <- model_class_weight_power[[submission_model_name]]
    if (!is.null(weight_power) && weight_power != 0) {
      add_balanced_class_weights(task_full, weight_power)
    } else {
      task_full
    }
  }),

  tar_target(final_model_full, {
    learner <- make_baseline_learner(base_learner_constructors[[submission_model_name]]())
    learner$train(task_full_weighted)
    learner
  }),

  tar_target(test_file, test_path, format = "file"),
  tar_target(
    submission,
    {
      test <- fread(test_file)
      test_ids <- test[[id_col]]
      test[, (id_col) := NULL]
      feature_set <- model_feature_sets[[submission_model_name]]
      test <- apply_feature_set(test, feature_set)
      setDT(test)
      for (col in names(full_feature_levels)) {
        test[[col]] <- factor(test[[col]], levels = full_feature_levels[[col]])
      }

      predictions <- final_model_full$predict_newdata(test)
      result <- data.table(id = test_ids, response = predictions$response)
      setnames(result, "id", id_col)
      setnames(result, "response", target_col)
      fwrite(result, submission_path)
      submission_path
    },
    format = "file"
  )
)
