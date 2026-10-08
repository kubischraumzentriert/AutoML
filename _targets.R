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
source(file.path(project_dir, "modules", "submission_contract.R"))
source(file.path(project_dir, "provenance.R"))
source(file.path(project_dir, "modules", "submission_artifacts.R"))
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

# Familie -> Transformationsfunktion: NICHT lokal neu definieren, sondern die
# in 000_config.R zentrale feature_family_functions() nutzen (Clean-Code-
# Review 2026-09-19 fand hier eine weitere unentdeckte Kopie derselben
# Zuordnung, analog zu 025_feature_engineering.R).
family_functions <- feature_family_functions()

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
  enable_class_stratification(as_task_classif(data, target = target_col, id = id))
}

build_combined_features <- function(train, families) {
  set.seed(seed)
  raw_subset <- build_stratified_subset(train)
  Reduce(function(data, family) family_functions[[family]](data), families, raw_subset)
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
      featured <- family_functions[[feature_family_name]](raw_subset)
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
    task <- as_task_classif(train_full_model_data, target = target_col, id = paste0(task_id_prefix, "_full_", submission_model_name))
    enable_class_stratification(apply_positive_class(task, positive_class))
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
  tar_target(final_model_artifacts, {
    persist_targets_submission_model(final_model_full, full_feature_levels,
      model_feature_sets[[submission_model_name]], positive_class, task_full_weighted)
  }, format = "file"),
  tar_target(sample_submission_file, {
    if (file.exists(sample_submission_path)) sample_submission_path else character(0)
  }, format = "file", cue = tar_cue(mode = "always")),
  tar_target(
    submission,
    {
      pinned <- read_targets_submission_model(final_model_artifacts)
      bundle <- pinned$bundle
      prototype <- make_baseline_learner(base_learner_constructors[[submission_model_name]]())
      validate_submission_model(bundle, model_feature_sets[[submission_model_name]],
        prototype$param_set$values, positive_class)
      test <- fread(test_file, colClasses = list(character = id_col))
      test_ids <- test[[id_col]]
      test[, (id_col) := NULL]
      feature_set <- model_feature_sets[[submission_model_name]]
      test <- apply_feature_set(test, feature_set)
      setDT(test)
      test <- align_submission_factor_levels(test, bundle$feature_levels)

      predictions <- bundle$learner$predict_newdata(test)
      expected <- submission_prediction_values(predictions,
        is_threshold_independent_metric(baseline_measure_ids[[1]]), positive_class)
      result <- data.table(test_ids, expected$values)
      setnames(result, c(id_col, target_col))
      sample <- if (length(sample_submission_file)) fread(sample_submission_file,
        colClasses = list(character = id_col)) else NULL
      report <- write_checked_submission(result, submission_path, test_ids, id_col, target_col, expected, sample)
      report <- c(report, list(status = "generated_validated", mconf_id = pinned$reference$mconf_id,
        model_sha256 = pinned$reference$model_sha256, submission_path = submission_path,
        submission_sha256 = sha256_file(submission_path), metric_name = baseline_measure_ids[[1]],
        test_sha256 = sha256_file(test_file), sample_checked = !is.null(sample)))
      log_validated_submission_candidate(report, "_targets_submission")
      submission_path
    },
    format = "file"
  )
)
