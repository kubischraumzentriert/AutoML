if (!exists("project_dir")) {
  config_path <- normalizePath(sys.frame(1)$ofile)
  project_dir <- dirname(config_path)
}

train_path <- file.path(project_dir, "train.csv")
test_path <- file.path(project_dir, "test.csv")
sample_submission_path <- file.path(project_dir, "sample_submission.csv")

id_col <- "id"
target_col <- "health_condition"

# Experiment-Tracking (SQLite, siehe db_schema.sql/db_logging.R)
project_name <- "playground-series-s6e7-health-condition"

seed <- 42
subset_fraction <- 0.10

validation_ratio <- 0.80
baseline_measure_ids <- c("classif.bacc", "classif.mcc")
cv_folds <- 5

glmnet_nfolds <- 3
glmnet_nlambda <- 30

artifact_dir <- file.path(project_dir, "_artifacts")
experiments_db_path <- file.path(artifact_dir, "experiments.db")
task_train_small_path <- file.path(artifact_dir, "task_train_small.rds")
task_train_small_features_path <- file.path(artifact_dir, "task_train_small_features.rds")

feature_families <- c("bmi", "sleep", "activity", "hydration", "cardio", "interactions")

# Pfad fuer je einen Feature-Task pro Familie (siehe feature_families)
task_train_small_feature_family_path <- function(family) {
  file.path(artifact_dir, paste0("task_train_small_features_", family, ".rds"))
}

selected_families <- c("activity", "cardio", "sleep")
task_train_small_features_selected_path <- file.path(artifact_dir, "task_train_small_features_selected.rds")

baseline_results_path <- file.path(artifact_dir, "baseline_results.csv")
baseline_benchmark_path <- file.path(artifact_dir, "baseline_benchmark.rds")
feature_baseline_results_path <- file.path(artifact_dir, "feature_baseline_results.csv")
feature_baseline_benchmark_path <- file.path(artifact_dir, "feature_baseline_benchmark.rds")
feature_family_results_path <- file.path(artifact_dir, "feature_family_results.csv")
feature_family_benchmark_path <- file.path(artifact_dir, "feature_family_benchmark.rds")
selected_cv_results_path <- file.path(artifact_dir, "selected_cv_results.csv")
selected_cv_benchmark_path <- file.path(artifact_dir, "selected_cv_benchmark.rds")

pipeline_results_path <- file.path(artifact_dir, "pipeline_results.csv")
pipeline_benchmark_path <- file.path(artifact_dir, "pipeline_benchmark.rds")

glmnet_results_path <- file.path(artifact_dir, "glmnet_results.csv")
glmnet_benchmark_path <- file.path(artifact_dir, "glmnet_benchmark.rds")

boosting_results_path <- file.path(artifact_dir, "boosting_results.csv")
boosting_benchmark_path <- file.path(artifact_dir, "boosting_benchmark.rds")

ranger_tuning_search_results_path <- file.path(artifact_dir, "ranger_tuning_search_results.csv")
ranger_tuning_final_results_path <- file.path(artifact_dir, "ranger_tuning_final_results.csv")
ranger_tuning_instance_path <- file.path(artifact_dir, "ranger_tuning_instance.rds")

ranger_tuning_search_trees <- 100
ranger_tuning_evals <- 20
ranger_tuning_final_trees <- 200

lightgbm_tuning_search_results_path <- file.path(artifact_dir, "lightgbm_tuning_search_results.csv")
lightgbm_tuning_final_results_path <- file.path(artifact_dir, "lightgbm_tuning_final_results.csv")
lightgbm_tuning_instance_path <- file.path(artifact_dir, "lightgbm_tuning_instance.rds")

lightgbm_tuning_search_iterations <- 100
lightgbm_tuning_evals <- 25
lightgbm_tuning_final_iterations <- 200

class_weight_results_path <- file.path(artifact_dir, "class_weight_results.csv")
lightgbm_family_results_path <- file.path(artifact_dir, "lightgbm_family_results.csv")

adversarial_validation_results_path <- file.path(artifact_dir, "adversarial_validation_results.csv")
adversarial_validation_importance_path <- file.path(artifact_dir, "adversarial_validation_importance.csv")
adversarial_validation_iterations <- 100
adversarial_validation_cv_folds <- 3

lightgbm_empty_string_results_path <- file.path(artifact_dir, "lightgbm_empty_string_results.csv")

catboost_results_path <- file.path(artifact_dir, "catboost_results.csv")
catboost_iterations <- 200

class_weight_power_extended_grid <- c(1, 1.25, 1.5, 1.75, 2, 2.5, 3)
class_weight_power_extended_results_path <- file.path(artifact_dir, "class_weight_power_extended_results.csv")

final_model_full_path <- function(model_name) {
  file.path(artifact_dir, paste0("final_model_", model_name, "_full.rds"))
}
submission_path <- file.path(project_dir, "submission.csv")

ensemble_candidates_results_path <- file.path(artifact_dir, "ensemble_candidates_results.csv")
ensemble_ranger_lightgbm_results_path <- file.path(artifact_dir, "ensemble_ranger_lightgbm_results.csv")

ranger_weighted_tuning_search_results_path <- file.path(artifact_dir, "ranger_weighted_tuning_search_results.csv")
ranger_weighted_tuning_final_results_path <- file.path(artifact_dir, "ranger_weighted_tuning_final_results.csv")
ranger_weighted_tuning_instance_path <- file.path(artifact_dir, "ranger_weighted_tuning_instance.rds")

# Schwellenwert-Tuning: 3-Wege-Split (Train/Tune/Eval), Gewichte pro Klasse
# werden auf dem Tune-Split gesucht (argmax(prob * weight)), um BAcc direkt zu
# optimieren - unabhaengig von Trainings-Klassengewichten (siehe README).
threshold_tuning_train_ratio <- 0.6
threshold_tuning_tune_ratio <- 0.2
threshold_tuning_weight_grid <- seq(0.5, 6, by = 0.5)
threshold_tuning_results_path <- file.path(artifact_dir, "threshold_tuning_results.csv")
threshold_tuning_ranger_results_path <- file.path(artifact_dir, "threshold_tuning_ranger_results.csv")

# TabPFN hat eine begrenzte Kontextlaenge (Vortrainings-Limits fuer Zeilen-
# /Feature-Anzahl) und erlaubt auf CPU standardmaessig nur bis zu 1000
# Trainingszeilen. Bei validation_ratio = 0.80 muss die Subset-Groesse daher
# unter 1000 / validation_ratio bleiben.
tabpfn_subset_size <- 1200
task_tabpfn_path <- file.path(artifact_dir, "task_tabpfn.rds")
tabpfn_results_path <- file.path(artifact_dir, "tabpfn_results.csv")

# --- Modell-Feature-Set-Zuordnung -------------------------------------------
# Legt fest, welches Feature-Set (siehe resolve_task_path) je Learner beim
# finalen Training verwendet wird (aktueller Stand: siehe README, per CV
# bestaetigt). Bei einem neuen Klassifikationsaufgaben-Workflow genuegt es,
# diese Zuordnung und die Feature-Familien in features/*.R zu ersetzen - der
# Rest der Pipeline (u.a. 070_final_models.R) bleibt unveraendert.
model_feature_sets <- list(
  lda = "raw",
  multinom = "selected",
  ranger = "raw"
)

resolve_task_path <- function(feature_set) {
  if (feature_set == "raw") return(task_train_small_path)
  if (feature_set == "features") return(task_train_small_features_path)
  if (feature_set == "selected") return(task_train_small_features_selected_path)
  if (feature_set %in% feature_families) return(task_train_small_feature_family_path(feature_set))
  stop("Unbekanntes Feature-Set: ", feature_set)
}

final_model_path <- function(model_name) {
  file.path(artifact_dir, paste0("final_model_", model_name, ".rds"))
}

# Basis-Learner-Konstruktoren je Modellname (ohne Imputations-Pipeline - die
# wenden die Trainingsskripte selbst an, siehe make_baseline_learner in
# 070/140/150). Bei einem neuen Klassifikationsaufgaben-Workflow bleibt diese
# Liste gleich, sofern dieselben Modellnamen weiterverwendet werden - sonst
# genuegt es, sie zu ergaenzen.
base_learner_constructors <- list(
  lda = function() lrn("classif.lda"),
  multinom = function() {
    learner <- lrn("classif.multinom")
    if ("trace" %in% learner$param_set$ids()) {
      learner$param_set$values$trace <- FALSE
    }
    learner
  },
  ranger = function() lrn("classif.ranger", num.trees = 200, respect.unordered.factors = "order", seed = seed),
  lightgbm = function() lrn("classif.lightgbm", num_iterations = lightgbm_tuning_final_iterations)
)

# Welches Modell aus model_feature_sets fuer die finale Kaggle-Submission auf
# dem vollen Datensatz trainiert wird (siehe 150_train_full_model.R).
submission_model_name <- "ranger"

# Balancierte Klassengewichte mit Daempfung: power = 0 -> ungewichtet,
# power = 1 -> volle Balance (weight_i = n_gesamt / (n_klassen * n_klasse_i)).
# Siehe README "Klassengewichtung" fuer die Abwaegung BAcc vs. MCC.
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

# Kaggle bewertet ausschliesslich per BAcc (nicht MCC). power = 1.5 liegt nahe
# am beobachteten BAcc-Peak (~1.75, siehe README "Klassengewichtung ueber
# power=1 hinaus"), mit spuerbar besserem MCC als am exakten Peak - der
# robustere Punkt auf einem sonst flachen Plateau.
class_weight_power <- 1.5

# Modelle, auf die beim finalen Training Klassengewichte angewendet werden
# (siehe 070_final_models.R). Nur Modelle mit Eintrag hier werden gewichtet.
model_class_weight_power <- list(
  ranger = class_weight_power
)

# Fehleranalyse (siehe 147_error_analysis_ranger.R): Stichprobengroessen fuer
# KernelSHAP (exakte Berechnung ueber alle Feature-Teilmengen ist bei mehr
# Zeilen zu teuer) und Ergebnispfade.
error_analysis_shap_sample_size <- 100
error_analysis_shap_background_size <- 100
error_analysis_results_path <- file.path(artifact_dir, "error_analysis_results.csv")
error_analysis_shap_importance_path <- file.path(artifact_dir, "error_analysis_shap_importance.csv")

# Schwelle, unterhalb derer eine Vorhersage als "unsicher" gilt (bei 3 Klassen
# kein willkuerlicher Wert: darunter war nicht mal die vorhergesagte Klasse
# selbst mehrheitsfaehig). Bestimmt, welche Zeilen 147 per db_log_predictions()
# in die DB schreibt - falsch klassifiziert ODER unsicher, nicht alle Zeilen
# (siehe db_schema.sql, Tabelle prediction).
error_analysis_uncertainty_threshold <- 0.5

# --- Helfer fuer das Experiment-Tracking (siehe db_logging.R) ---------------
# Leitet aus einem mlr3-Task-Id (z.B. "health_condition_10pct_sleep_weighted_p1.5")
# ein feature_set-Label fuer model_config ab.
feature_set_from_task_id <- function(task_id) {
  task_id <- sub("_weighted.*$", "", task_id)
  if (task_id == "health_condition_10pct") return("raw")
  if (task_id == "health_condition_10pct_features") return("features")
  if (task_id == "health_condition_10pct_selected") return("selected")
  if (task_id == "health_condition_tabpfn_subset") return("raw")
  suffix <- sub("^health_condition_10pct_", "", task_id)
  suffix
}

# Leitet aus einem (ggf. durch mlr3pipelines zusammengesetzten) Learner-Id
# den Algorithmus-Namen ab, z.B. "imputemedian.imputemode.classif.ranger" ->
# "ranger". Bei eigens vergebenen Ids ohne "classif."-Praefix (z.B.
# "...encode_factors_one_hot.glmnet_ridge") wird das letzte Punkt-Segment
# genommen; bei einfachen Ids ohne Punkte (z.B. "ranger_tuned") bleibt die Id
# unveraendert.
algorithm_from_learner_id <- function(learner_id) {
  if (grepl("classif\\.", learner_id)) {
    return(sub(".*classif\\.", "", learner_id))
  }
  parts <- strsplit(learner_id, "\\.", fixed = FALSE)[[1]]
  parts[length(parts)]
}
