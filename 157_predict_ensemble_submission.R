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

# Analog zu 155_predict_submission.R, aber fuer das Greedy-Ensemble aus
# 156_train_full_ensemble.R: mittelt die Wahrscheinlichkeiten mehrerer
# Mitglieder GEWICHTET (Gewicht = wie oft der Kandidat in 149 ausgewaehlt
# wurde) statt eines einzelnen Learners. Schreibt NACH submission_ensemble_
# path, NICHT nach submission_path - ueberschreibt die bestehende
# Einzelmodell-Submission nicht.
db_con <- db_connect()
model_path <- db_get_latest_model_artifact_path(db_con, "ensemble", workflow_name = "156_train_full_ensemble.R")
DBI::dbDisconnect(db_con)

if (is.na(model_path) || !file.exists(model_path)) {
  source(file.path(project_dir, "156_train_full_ensemble.R"))
  db_con <- db_connect()
  model_path <- db_get_latest_model_artifact_path(db_con, "ensemble", workflow_name = "156_train_full_ensemble.R")
  DBI::dbDisconnect(db_con)
}

model_bundle <- readRDS(model_path)
members <- model_bundle$members
feature_levels <- model_bundle$feature_levels
class_names <- model_bundle$class_names

test <- fread(test_path)
test_ids <- test[[id_col]]
test[, (id_col) := NULL]
for (col in names(feature_levels)) {
  test[[col]] <- factor(test[[col]], levels = feature_levels[[col]])
}

cat(sprintf("=== Ensemble-Vorhersage: %d Mitglieder ===\n", length(members)))
total_weight <- sum(vapply(members, `[[`, integer(1), "weight"))
prob_sum <- NULL
response_via_argmax <- NULL
for (member in members) {
  pred <- member$learner$predict_newdata(test)
  cat(sprintf("  %s (Gewicht %d/%d)\n", member$label, member$weight, total_weight))
  weighted_prob <- pred$prob[, class_names, drop = FALSE] * member$weight
  prob_sum <- if (is.null(prob_sum)) weighted_prob else prob_sum + weighted_prob
}
prob_avg <- prob_sum / total_weight
response_via_argmax <- factor(class_names[max.col(prob_avg, ties.method = "first")], levels = class_names)

# Submission-Format haengt an der ZIELMETRIK, identische Logik wie
# 155_predict_submission.R.
prob_metric <- is_threshold_independent_metric(baseline_measure_ids[1])

if (prob_metric && ncol(prob_avg) == 2) {
  pos <- if (!is.null(positive_class)) as.character(positive_class) else class_names[length(class_names)]
  if (!pos %in% class_names) {
    stop("positive_class '", pos, "' ist keine der Klassen (", paste(class_names, collapse = ", "), ").")
  }
  submission <- data.table(test_ids, prob_avg[, pos])
  setnames(submission, c(id_col, target_col))
  fwrite(submission, submission_ensemble_path)
  cat("\n=== Ensemble-Submission erzeugt (prob-Metrik ", baseline_measure_ids[1],
      ": P(", target_col, "=", pos, ")) ===\n", sep = "")
  cat("Zeilen:", nrow(submission), "  mean(pred):", round(mean(submission[[target_col]]), 4), "\n")
} else {
  submission <- data.table(test_ids, as.character(response_via_argmax))
  setnames(submission, c(id_col, target_col))
  fwrite(submission, submission_ensemble_path)
  cat("\n=== Ensemble-Submission erzeugt (Labels) ===\n")
  cat("Zeilen:", nrow(submission), "\nKlassenverteilung:\n")
  print(table(submission[[target_col]]))
}
cat("\nGespeichert:", submission_ensemble_path, "\n")
cat("(bestehende submission.csv/Einzelmodell unveraendert)\n")
