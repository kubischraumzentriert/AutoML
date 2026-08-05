rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(tidyverse)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
})

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))
# Alle features/*.R laden statt einzelne Familien-Dateien hartzucodieren -
# siehe 150_train_full_model.R fuer die Begruendung (zwei unabhaengige
# Uebertragungen, s6e5/s5e12, scheiterten an fehlenden Feature-Dateien).
for (f in list.files(file.path(project_dir, "features"), pattern = "\\.R$", full.names = TRUE)) {
  source(f)
}

model_name <- resolve_submission_model_name()
feature_set <- model_feature_sets[[model_name]]

# Der Modell-Pfad ist an eine run_id gebunden (siehe 000_config.R/
# 150_train_full_model.R) - kein fixer Dateiname mehr. Wird ueber die zuletzt
# in experiments.db geloggte model_artifact_path fuer diesen Algorithmus
# gefunden; existiert noch keiner, wird 150 einmal ausgefuehrt.
db_con <- db_connect()
model_path <- db_get_latest_model_artifact_path(db_con, model_name)
DBI::dbDisconnect(db_con)

if (is.na(model_path) || !file.exists(model_path)) {
  source(file.path(project_dir, "150_train_full_model.R"))
  db_con <- db_connect()
  model_path <- db_get_latest_model_artifact_path(db_con, model_name)
  DBI::dbDisconnect(db_con)
}

model_bundle <- readRDS(model_path)
learner <- model_bundle$learner
feature_levels <- model_bundle$feature_levels
if ("feature_set" %in% names(model_bundle)) {
  trained_feature_set <- model_bundle$feature_set
} else if (identical(feature_set, "raw")) {
  trained_feature_set <- "raw"
} else {
  stop(
    "Das gespeicherte Modell enthaelt noch keine feature_set-Information, ",
    "die aktuelle Config erwartet aber feature_set = '", feature_set,
    "'. Bitte 150_train_full_model.R erneut ausfuehren."
  )
}
if (!identical(trained_feature_set, feature_set)) {
  stop(
    "Das gespeicherte Modell wurde mit feature_set = '", trained_feature_set,
    "' trainiert, die aktuelle Config erwartet aber '", feature_set,
    "'. Bitte 150_train_full_model.R erneut ausfuehren."
  )
}

test <- fread(test_path)
test_ids <- test[[id_col]]
test[, (id_col) := NULL]
test <- apply_feature_set(test, feature_set)

# Faktorstufen exakt an das Training angleichen (nicht per as.factor() neu
# ableiten), damit unterschiedliche Stufenmengen zwischen Train und Test die
# Vorhersage nicht verfaelschen.
for (col in names(feature_levels)) {
  test[[col]] <- factor(test[[col]], levels = feature_levels[[col]])
}

predictions <- learner$predict_newdata(test)

# Submission-Format haengt an der ZIELMETRIK (baseline_measure_ids[1]):
# - schwellenwert-UNABHAENGIG (AUC/LogLoss/PRAUC) + BINAER -> Wahrscheinlichkeit
#   der positiven Klasse P(positive). Kaggle-AUC/-LogLoss erwarten prob, NICHT
#   das Klassen-Label. Die positive Klasse kommt aus positive_class (000_config).
# - sonst (BAcc/MCC/... ODER Multiclass) -> Klassen-Labels wie bisher.
# (is_threshold_independent_metric() stammt aus db_logging.R.)
prob_metric <- is_threshold_independent_metric(baseline_measure_ids[1])

if (prob_metric && !is.null(predictions$prob) && ncol(predictions$prob) == 2) {
  classes <- colnames(predictions$prob)
  pos <- if (!is.null(positive_class)) as.character(positive_class) else classes[length(classes)]
  if (!pos %in% classes) {
    stop("positive_class '", pos, "' ist keine der Klassen (", paste(classes, collapse = ", "), ").")
  }
  if (is.null(positive_class)) {
    warning("positive_class ist NULL - nutze '", pos, "' als positive Klasse. ",
            "Fuer eine prob-basierte Submission positive_class in 000_config.R setzen.")
  }
  submission <- data.table(test_ids, predictions$prob[, pos])
  setnames(submission, c(id_col, target_col))
  fwrite(submission, submission_path)
  cat("=== Submission erzeugt (prob-Metrik ", baseline_measure_ids[1],
      ": P(", target_col, "=", pos, ")) ===\n", sep = "")
  cat("Zeilen:", nrow(submission), "  mean(pred):",
      round(mean(submission[[target_col]]), 4), "\n")
} else {
  if (prob_metric && !is.null(predictions$prob)) {
    warning("Prob-basierte Zielmetrik bei >2 Klassen: das Submission-Format ist ",
            "wettbewerbsspezifisch (i.d.R. eine Spalte je Klasse). Es werden ",
            "vorerst Labels ausgegeben - ggf. projektspezifisch anpassen.")
  }
  submission <- data.table(test_ids, as.character(predictions$response))
  setnames(submission, c(id_col, target_col))
  fwrite(submission, submission_path)
  cat("=== Submission erzeugt (Labels) ===\n")
  cat("Zeilen:", nrow(submission), "\nKlassenverteilung:\n")
  print(table(submission[[target_col]]))
}
cat("\nGespeichert:", submission_path, "\n")
