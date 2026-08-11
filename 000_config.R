if (!exists("project_dir")) {
  config_path <- normalizePath(sys.frame(1)$ofile)
  project_dir <- dirname(config_path)
}

train_path <- file.path(project_dir, "train.csv")
test_path <- file.path(project_dir, "test.csv")
sample_submission_path <- file.path(project_dir, "sample_submission.csv")

id_col <- "id"
target_col <- "health_condition"

# Positive Klasse fuer BINAERE Aufgaben mit wahrscheinlichkeitsbasierter
# Zielmetrik (AUC/LogLoss): dann gibt 155_predict_submission.R P(positive) aus
# statt Klassen-Labels, und die positive Klasse wird in 020_task.R gesetzt.
# NULL = Multiclass ODER label-basierte Metrik (BAcc/MCC) -> Labels wie bisher
# (dieses Projekt: health_condition, 3-Klassen/BAcc -> NULL, rueckwirkungsfrei).
positive_class <- NULL

# Experiment-Tracking (SQLite, siehe db_schema.sql/db_logging.R)
project_name <- "playground-series-s6e7-health-condition"

seed <- 42
subset_fraction <- 0.10

# --- Task-ID-Praefix ---------------------------------------------------------
# Aus target_col + subset_fraction abgeleitet statt in 020_task.R/
# 025_feature_engineering.R/_targets.R als Literal-String wiederholt zu
# werden (frueher z.B. "health_condition_10pct" hart codiert an mehreren
# Stellen - bei einer Uebertragung auf ein neues Projekt musste man das an
# jeder Stelle synchron aendern, ohne dass die TARGETS.md-Checkliste das
# erwaehnte). Fuer target_col = "health_condition" identisch zum bisherigen
# Literal, daher rueckwirkungsfrei fuer dieses Projekt.
camel_to_snake_case <- function(x) {
  x <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", x)
  tolower(x)
}
task_id_prefix <- paste0(camel_to_snake_case(target_col), "_", subset_fraction * 100, "pct")

validation_ratio <- 0.80
baseline_measure_ids <- c("classif.bacc", "classif.mcc")
cv_folds <- 5

# mlr3 stratifiziert anhand der Task-Rolle "stratum". Klassifikationstasks
# erhalten deshalb ihre Zielspalte auch als Stratum, damit Holdout und CV die
# Klassenanteile erhalten. Bereits gesetzte, projektspezifische Strata bleiben
# dabei unveraendert bestehen.
enable_class_stratification <- function(task) {
  if (!inherits(task, "TaskClassif")) {
    return(task)
  }

  roles <- task$col_roles
  if (!all(task$target_names %in% roles$stratum)) {
    roles$stratum <- unique(c(roles$stratum, task$target_names))
    task$col_roles <- roles
  }

  task
}

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
surrogate_guided_feature_spec_path <- file.path(artifact_dir, "surrogate_guided_feature_spec.rds")
surrogate_guided_feature_spec_csv_path <- file.path(artifact_dir, "surrogate_guided_feature_spec.csv")
task_train_small_surrogate_guided_path <- file.path(artifact_dir, "task_train_small_surrogate_guided.rds")
surrogate_guided_results_path <- file.path(artifact_dir, "surrogate_guided_results.csv")
surrogate_guided_benchmark_path <- file.path(artifact_dir, "surrogate_guided_benchmark.rds")

# Surrogate-guided Feature-Kandidaten fuer lineare Surrogat-Modelle:
# Ein kleines rpart-Ensemble entdeckt stabile Interaktionspaare auf einem
# Discovery-Split; schnelle lineare Modelle pruefen diese expliziten Features
# separat, um Leakage zu begrenzen.
surrogate_guided_discovery_ratio <- 0.60
surrogate_guided_scout <- "rpart_ensemble"
surrogate_guided_rpart_runs <- 5
surrogate_guided_rpart_subsample_ratio <- 0.80
surrogate_guided_rpart_maxdepth <- 6
surrogate_guided_rpart_cp <- 0.001
surrogate_guided_rpart_minsplit <- 50
surrogate_guided_max_pairs <- 12
surrogate_guided_min_pair_count <- 3
surrogate_guided_operations <- c("product", "ratio_ab", "ratio_ba", "absdiff")
surrogate_guided_eval_max_rows <- 12000
surrogate_guided_cv_folds <- 3
surrogate_guided_liblinear_type <- 0
surrogate_guided_liblinear_cost <- 1
surrogate_guided_liblinear_bias <- 1

pipeline_results_path <- file.path(artifact_dir, "pipeline_results.csv")
pipeline_benchmark_path <- file.path(artifact_dir, "pipeline_benchmark.rds")

glmnet_results_path <- file.path(artifact_dir, "glmnet_results.csv")
glmnet_benchmark_path <- file.path(artifact_dir, "glmnet_benchmark.rds")

# 080 (Ranger + LightGBM, native Faktor-Behandlung, kein One-Hot noetig) und
# 081 (XGBoost, braucht 040_preprocessing.R-One-Hot) getrennt - so laesst sich
# der guenstige Teil ohne die XGBoost-Preprocessing-Abhaengigkeit laufen
# (frueher gebuendelt in 080_boosting_benchmark.R, siehe TARGETS.md-Backlog).
boosting_results_path <- file.path(artifact_dir, "boosting_results.csv")
boosting_benchmark_path <- file.path(artifact_dir, "boosting_benchmark.rds")
xgboost_results_path <- file.path(artifact_dir, "xgboost_results.csv")
xgboost_benchmark_path <- file.path(artifact_dir, "xgboost_benchmark.rds")

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

# Gestufte Adversarial Validation + ESS (rueckgefuehrt aus dem Regression-018 /
# credit-scoring-015): ESS/n der OOF-Propensity-Gewichte zeigt, ob Reweighting
# stabil waere (klein => nutzlos); optionale Stufen schliessen verdaechtige
# Feature-Gruppen aus, um zu sehen, welche den Shift treibt. Als benannte Liste
# Gruppenname -> Spaltenvektor, z.B. list(ids = c("lender_id","country_id")).
# Default leer -> nur Gesamt-AUC/ESS, kein Eingriff ins bestehende Benchmark/DB.
adversarial_staged_exclude <- list()
adversarial_staged_results_path <- file.path(artifact_dir, "adversarial_staged_results.csv")

# Univariate Drift-Tests (KS je stetigem Feature, Chi-Quadrat je kategorialem
# Feature, BH-korrigiert) - Ergaenzung zur Adversarial-Validation-AUC, siehe
# univariate_drift.R. Sagt WELCHE Features driften, nicht nur ob insgesamt
# trennbar. An 2 OpenML-Datensaetzen/3 Szenarien verifiziert, siehe TARGETS.md.
univariate_drift_results_path <- file.path(artifact_dir, "univariate_drift_results.csv")
univariate_drift_alpha <- 0.05

# Target-Leak-Audit (015): eine zu gute Baseline auf einer schweren/
# unbalancierten Aufgabe ist ein Warnsignal, kein Erfolg - siehe README
# "Target-Leakage-Audit". CV<->LB-Uebereinstimmung faengt einen Leak NICHT
# (das Artefakt steckt auch in den Testdaten) - nur ein Feature-Audit tut das.
leak_audit_importance_share_threshold <- 0.50  # 1 Feature traegt >50% der Gain-Importance
leak_audit_suspect_top_n <- 8                  # max. Anzahl Verdaechtiger fuer die Zerlegung
leak_audit_determinism_min_n <- 30             # Mindestgruppengroesse fuer einen Determinismus-Fund
leak_audit_determinism_eps <- 1e-9             # Toleranz um Anteil = 1 (numerische Rundung)
leak_audit_cardinality_max <- 30               # nur Spalten mit <= so vielen eindeutigen Werten pruefen
# Optional: kategoriale Spalten, gegen die verdaechtige NUMERISCHE Features per
# Within-Stratum-Trennung geprueft werden (siehe README, Schritt 2 des Audits).
# Default leer = dieser Schritt wird uebersprungen (projektspezifisches Wissen
# noetig, welche Spalte "eigentlich neutral" sein sollte).
leak_audit_stratify_cols <- character(0)
leak_audit_importance_path <- file.path(artifact_dir, "leak_audit_importance.csv")
leak_audit_determinism_path <- file.path(artifact_dir, "leak_audit_determinism.csv")
leak_audit_stratum_path <- file.path(artifact_dir, "leak_audit_within_stratum.csv")
leak_audit_decomposition_path <- file.path(artifact_dir, "leak_audit_decomposition.csv")

lightgbm_empty_string_results_path <- file.path(artifact_dir, "lightgbm_empty_string_results.csv")

catboost_results_path <- file.path(artifact_dir, "catboost_results.csv")
catboost_iterations <- 200

class_weight_power_extended_grid <- c(1, 1.25, 1.5, 1.75, 2, 2.5, 3)
class_weight_power_extended_results_path <- file.path(artifact_dir, "class_weight_power_extended_results.csv")

# run_id macht jede gespeicherte Modell-Datei eindeutig - ein neuer
# Trainingslauf ueberschreibt nicht mehr kommentarlos die vorherige. Der zur
# aktuellen run_id passende Pfad wird als "model_artifact_path"-Hyperparameter
# in experiments.db geloggt (siehe 150_train_full_model.R) und von dort ueber
# db_get_latest_model_artifact_path() (db_logging.R) wieder gefunden (siehe
# 155_predict_submission.R) - kein fixer Dateiname mehr noetig.
final_model_full_path <- function(model_name, run_id) {
  file.path(artifact_dir, paste0("final_model_", model_name, "_full_", run_id, ".rds"))
}
submission_path <- file.path(project_dir, "submission.csv")
submission_model_selection_path <- file.path(artifact_dir, "submission_model_selection.csv")

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
  if (feature_set == "surrogate_guided") return(task_train_small_surrogate_guided_path)
  if (feature_set %in% feature_families) return(task_train_small_feature_family_path(feature_set))
  stop("Unbekanntes Feature-Set: ", feature_set)
}

# Wendet dieselbe Feature-Set-Logik auf beliebige Daten an (Train-Subset,
# Full-Train oder test.csv). Die add_*_features-Funktionen muessen vorher aus
# features/*.R geladen sein; fuer feature_set = "raw" bleibt der Datensatz
# unveraendert.
apply_feature_set <- function(data, feature_set) {
  if (feature_set == "raw") {
    return(data)
  }

  if (feature_set == "surrogate_guided") {
    if (!exists("add_surrogate_guided_features")) {
      stop("Feature-Set 'surrogate_guided' benoetigt source('features/surrogate_guided.R').")
    }
    if (!file.exists(surrogate_guided_feature_spec_path)) {
      stop(
        "Feature-Set 'surrogate_guided' benoetigt ", surrogate_guided_feature_spec_path,
        " - erst 038_surrogate_guided_features.R ausfuehren."
      )
    }
    spec <- readRDS(surrogate_guided_feature_spec_path)
    return(add_surrogate_guided_features(data, spec, operations = surrogate_guided_operations))
  }

  families <- switch(feature_set,
    features = feature_families,
    selected = selected_families,
    feature_set
  )

  unknown_families <- setdiff(families, feature_families)
  if (length(unknown_families) > 0) {
    stop("Unbekanntes Feature-Set: ", feature_set)
  }

  feature_family_functions <- list(
    bmi = add_bmi_features,
    sleep = add_sleep_features,
    activity = add_activity_features,
    hydration = add_hydration_features,
    cardio = add_cardio_features,
    interactions = add_interaction_features
  )

  Reduce(
    function(current_data, family) feature_family_functions[[family]](current_data),
    families,
    data
  )
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

# --- Auswahl des Submission-Modells -----------------------------------------
# Bewusst NICHT als statischer submission_model_name-Wert: welcher Algorithmus
# gewinnt ist ein Workflow-ERGEBNIS (aus den Benchmarks in experiments.db,
# siehe 148_select_submission_model.R), keine Config-Eingabe. 000_config.R
# bleibt dadurch reine Basis-Konfiguration.
#
# submission_model_override: auf einen Modellnamen gesetzt (statt NULL) heisst
# "diesen erzwingen, nicht automatisch waehlen". Hier bewusst auf "ranger"
# gesetzt: das ist die in README.md ausfuehrlich hergeleitete Entscheidung
# (BAcc/MCC-Abwaegung, Klassengewichtung, Feature-Family-CV-Befund) - eine rein
# metrikgetriebene Auto-Auswahl (148) wuerde diese Nuancen nicht erfassen. Bei
# einem neuen Projekt auf NULL setzen, um automatisch das per Metrik beste
# Modell aus 148 zu uebernehmen (dort erst pruefen, per CV bestaetigen).
submission_model_override <- "ranger"

# Ermittelt das tatsaechlich zu trainierende Modell fuer die finale Kaggle-
# Submission (siehe 150_train_full_model.R). Erst 148_select_submission_model.R
# ausfuehren, wenn submission_model_override NULL ist, sonst schlaegt dies fehl.
resolve_submission_model_name <- function() {
  if (!is.null(submission_model_override)) {
    return(submission_model_override)
  }
  if (!file.exists(submission_model_selection_path)) {
    stop(
      "submission_model_override ist NULL und ", submission_model_selection_path,
      " existiert nicht - erst 148_select_submission_model.R ausfuehren, ",
      "oder submission_model_override explizit setzen."
    )
  }
  selection <- read.csv(submission_model_selection_path, stringsAsFactors = FALSE)
  selection$algorithm[1]
}

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

# Fehleranalyse (siehe 147_error_analysis_ranger_*.R): Stichprobengroessen
# fuer KernelSHAP (exakte Berechnung ueber alle Feature-Teilmengen ist bei
# mehr Zeilen zu teuer) und Ergebnispfade.
error_analysis_shap_sample_size <- 100
error_analysis_shap_background_size <- 100
error_analysis_results_path <- file.path(artifact_dir, "error_analysis_results.csv")
error_analysis_shap_importance_path <- file.path(artifact_dir, "error_analysis_shap_importance.csv")

# Artefakte, die die Fehleranalyse-Skripte lose koppeln, statt alles in einem
# Skript zu buendeln: 147_..._models.R trainiert einmal (manuell median/
# modus-imputiert, siehe dort) und speichert Modelle + Vorhersagen hier,
# 147_..._confidence.R baut darauf auf und speichert die abgeleiteten
# Zeilen-Indizes (misclassified/hard_case/...) hier - Isolation Forest,
# KernelSHAP und TabPFN laden beide Artefakte, statt selbst neu zu
# trainieren. Vorteil: z.B. nur die DB-Logging-Zeilen in `_models.R` aendern
# und testen, ohne KernelSHAP/TabPFN jedes Mal neu laufen zu lassen.
error_analysis_models_path <- file.path(artifact_dir, "error_analysis_models.rds")
error_analysis_indices_path <- file.path(artifact_dir, "error_analysis_indices.rds")

# Schwelle, unterhalb derer eine Vorhersage als "unsicher" gilt (bei 3 Klassen
# kein willkuerlicher Wert: darunter war nicht mal die vorhergesagte Klasse
# selbst mehrheitsfaehig). Bestimmt, welche Zeilen 147 per db_log_predictions()
# in die DB schreibt - falsch klassifiziert ODER unsicher, nicht alle Zeilen
# (siehe db_schema.sql, Tabelle prediction).
error_analysis_uncertainty_threshold <- 0.5

# TabPFN-Kontextgroesse fuer die Fehleranalyse (147): knapp unter dem CPU-Limit
# von 1000 Trainingszeilen (siehe 095_tabpfn_benchmark.R), klassenstratifiziert
# gezogen. TabPFN wird hier NICHT auf dem kompletten Eval-Split ausgewertet,
# sondern nur auf den "interessanten" Zeilen (siehe error_analysis_uncertainty_threshold).
error_analysis_tabpfn_context_size <- 999

# Segmentmetriken (147_error_analysis_ranger_segments.R): baut auf dem
# `error_analysis_models_path`-Artefakt auf (kein erneutes Training). Prueft
# je Spalte in `segment_metric_cols`, ob BAcc/MCC in einer Untergruppe deutlich
# von der Gesamt-BAcc abweicht - eine Gesamtmetrik kann eine schwache
# Untergruppen-Performance verstecken (Simpson-Paradoxon), siehe TARGETS.md.
# Default leer -> Segmentmetriken uebersprungen, kein Eingriff ins bestehende
# Fehleranalyse-Logging. Segmentspalten muessen unter den Modell-Features
# liegen (im `eval_imputed`-Teil des Artefakts enthalten).
segment_metric_cols <- character(0)
segment_metric_warn_gap <- 0.05
segment_metrics_path <- file.path(artifact_dir, "segment_metrics.csv")

# Modell-Sanity-Checks (147_error_analysis_ranger_sanity_checks.R, siehe
# sanity_checks.R und TARGETS.md): Perturbation-/Invarianz-/Directional-
# Expectation-Tests nach Huyen (2022) Kap. 6, verifiziert an synthetischer
# Ground Truth + 2 realen Projekten (health_condition, drivendata-pump-it-up).
# Bauen wie die Segmentmetriken auf `error_analysis_models_path` auf (kein
# erneutes Training). Alle drei Listen default leer -> Skript uebersprungen,
# kein Eingriff ins bestehende Fehleranalyse-Logging.

# Perturbation: numerische Spalten (MUESSEN dbl-typisiert sein - int-Spalten
# wie z.B. Codes/Zaehler wuerden beim Rausch-Hinzufuegen den mlr3-Typcheck
# beim predict_newdata verletzen, siehe TARGETS.md/PumpItUp-Erfahrung).
perturbation_test_cols <- character(0)
perturbation_noise_sd_frac <- 0.05
perturbation_warn_drop <- 0.05

# Invarianz: Spalten, die laut fachlicher Einschaetzung KEINE kausale
# Bedeutung fuer die Zielgroesse haben sollten (Kandidaten-Check, keine
# endgueltige Aussage - siehe TARGETS.md).
invariance_test_cols <- character(0)
invariance_warn_flip_rate <- 0.05

# Directional Expectation: Liste von Specs, je eine pro Feature mit bekannter
# monotoner Domainbeziehung. Jede Spec:
#   feature           - Spaltenname
#   type              - "numeric" (+ delta) oder "ordinal" (+ level_order,
#                        aufsteigend sortiert, siehe build_ordinal_shift_fn())
#   delta             - nur bei type="numeric": Verschiebungsgroesse
#   level_order       - nur bei type="ordinal": aufsteigende Stufen-Reihenfolge
#   direction         - "increasing" (P(favorable_class) soll bei der
#                        Verschiebung nicht SINKEN) oder "decreasing" (soll
#                        nicht STEIGEN)
#   favorable_class   - Klasse, deren P beobachtet wird
# Beispiel (health_condition, NICHT aktiv - siehe TARGETS.md fuer die
# tatsaechlich gemessenen Zahlen):
#   list(feature = "stress_level", type = "ordinal",
#        level_order = c("low", "medium", "high"), direction = "decreasing",
#        favorable_class = "fit")
directional_expectation_specs <- list()
directional_warn_violation_rate <- 0.30
directional_effect_threshold <- 0.05
directional_warn_effect_share <- 0.05

sanity_check_results_path <- file.path(artifact_dir, "sanity_check_results.csv")

# Caruana-Greedy-Ensemble-Selection (148_ensemble_candidate_pool.R +
# 149_ensemble_selection.R, siehe TARGETS.md): statt ein Einzelmodell zu
# waehlen (148_select_submission_model.R) oder wenige Modelle
# gleichzugewichten, ein Pool trainierter Modelle per gieriger
# Vorwaertsauswahl (mit Wiederholung erlaubt, Caruana et al. 2004) zu einem
# Ensemble kombinieren. An 2 unabhaengigen OpenML-Datensaetzen verifiziert
# (bank-marketing/electricity, siehe TARGETS.md) - Backport-Kriterium
# erfuellt. Baut auf `error_analysis_models_path` (147, train/eval-Split +
# manuell imputierte Daten) auf, kein neuer Split.
# ensemble_pool_n_per_family: Anzahl Kandidaten je Modellfamilie
# (Ranger/LightGBM/CatBoost) im Kandidaten-Pool.
ensemble_pool_n_per_family <- 8L
ensemble_candidate_pool_path <- file.path(artifact_dir, "ensemble_candidate_pool.rds")
# ensemble_selection_rounds: max. Ensemblegroesse (mit Wiederholung) der
# gierigen Selektion. ensemble_selection_valid_ratio: Anteil des 147-Eval-
# Splits, der fuer die Selektion selbst verwendet wird (Rest = unberuehrte
# Bestaetigungsmenge, verhindert Ueberanpassung der Selektion an sich selbst).
ensemble_selection_rounds <- 50L
ensemble_selection_valid_ratio <- 0.5
ensemble_selection_results_path <- file.path(artifact_dir, "ensemble_selection_results.csv")

# --- Helfer fuer das Experiment-Tracking (siehe db_logging.R) ---------------
# Leitet aus einem mlr3-Task-Id (z.B. "<task_id_prefix>_sleep_weighted_p1.5")
# ein feature_set-Label fuer model_config ab. Referenziert task_id_prefix
# statt eigener Literal-Strings - 020_task.R/025_feature_engineering.R/
# 095_tabpfn_benchmark.R/_targets.R muessen dieselbe Variable verwenden.
feature_set_from_task_id <- function(task_id) {
  task_id <- sub("_weighted.*$", "", task_id)
  if (task_id == task_id_prefix) return("raw")
  if (task_id == paste0(task_id_prefix, "_raw_eval")) return("raw")
  if (task_id == paste0(task_id_prefix, "_features")) return("features")
  if (task_id == paste0(task_id_prefix, "_selected")) return("selected")
  if (task_id == paste0(task_id_prefix, "_surrogate_guided")) return("surrogate_guided")
  if (task_id == paste0(task_id_prefix, "_surrogate_guided_eval")) return("surrogate_guided")
  if (task_id == sub("_10pct$", "_tabpfn_subset", task_id_prefix)) return("raw")
  suffix <- sub(paste0("^", task_id_prefix, "_"), "", task_id)
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
