suppressPackageStartupMessages({
  library(mlr3)
  library(mlr3pipelines)
})

# Leak-sicheres Target-(Impact-)Encoding fuer kategoriale Spalten, generisch
# und template-portabel. Setzt auf mlr3pipelines::po("encodeimpact") auf:
#
# - LEAK-SICHERHEIT: encodeimpact ist ein PipeOpTaskPreproc. Als Teil eines
#   GraphLearners, der via resample()/benchmark() mit CV ausgewertet wird,
#   wird die Impact-Tabelle in $train() NUR auf den Trainingszeilen des
#   jeweiligen Folds gebildet und in $predict() angewendet - die Kodierung
#   sieht also nie die Ziel-Werte des Validierungs-Folds. Leak-sicher auf
#   CV-Fold-Ebene (die entscheidende Ebene fuer eine ehrliche CV-Schaetzung).
#   Verbleibende In-Fold-Optimismus (der eigene Ziel-Wert einer Zeile fliesst
#   in den Impact ihres Levels ein) ist zweitrangig und wird durch die
#   Glaettung (smoothing) gedaempft - der puristische "nested inner-CV"-Ansatz
#   der Kaggle-Gewinner-Writeups reduziert das noch weiter, ist aber deutlich
#   aufwaendiger; fuer eine wiederverwendbare Template-Faehigkeit ist die
#   Fold-Ebene der richtige, robuste Kompromiss.
#
# - MULTICLASS: pro kategoriale Spalte entstehen k numerische Spalten (eine je
#   Zielklasse, k = Anzahl Klassen). Fuer hochkardinale Spalten ist das weit
#   sparsamer als One-Hot (41-Level native.country -> 2 Spalten bei 2 Klassen
#   statt 41), was besonders Modellen hilft, die numerische Eingaben brauchen
#   (XGBoost, glmnet) und sonst an der One-Hot-Dimensionalitaet leiden.
#
# affect_cols: Spaltennamen, die kodiert werden sollen. NULL = alle Faktor-/
#   ordered-Spalten. Gezielt setzen, wenn nur die hochkardinalen Spalten
#   kodiert werden sollen (niedrigkardinale koennen Baummodelle nativ nutzen).
# smoothing: Glaettung Richtung globalem Ziel-Mittel (hoeher = staerker fuer
#   seltene Level, robuster gegen Ueberanpassung an Raritaeten).
# impute_zero = TRUE ist wichtig fuer Robustheit: Level, die im Trainings-Fold
# NICHT vorkamen (z.B. ein seltenes Level, das durch die CV-Aufteilung nur im
# Validierungs-Fold landet - bei adult etwa occupation="Armed-Forces", 1x im
# Subset), bekommen sonst NA statt eines Impacts, was NA-intolerante Learner
# (LDA/Multinom) beim Predict abstuerzen laesst. Mit impute_zero = TRUE
# erhalten unbekannte Level neutralen Impact 0 (= globaler Durchschnitt auf der
# Log-Impact-Skala) - das korrekte Verhalten fuer einen generischen Encoder.
build_target_encoding_po <- function(affect_cols = NULL, smoothing = 1e-4, id = "encode_target") {
  selector <- if (is.null(affect_cols)) {
    selector_type(c("factor", "ordered"))
  } else {
    selector_name(affect_cols)
  }
  po("encodeimpact", id = id, affect_columns = selector, smoothing = smoothing, impute_zero = TRUE)
}

# Baut einen kompletten Klassifikations-GraphLearner mit Target-Encoding statt
# One-Hot/collapsefactors: Imputation (numerisch median, Faktor mode) ->
# Target-Encoding -> base_learner. Leerstring-Faktorlevel werden vorher zu NA
# (siehe empty_factor_to_na), damit sie als fehlend imputiert statt als eigenes
# Level kodiert werden. Spiegelt build_classif_pipeline() aus 040_preprocessing.R,
# nur mit Target-Encoding als Encoding-Schritt.
build_target_encoded_pipeline <- function(base_learner, affect_cols = NULL, smoothing = 1e-4) {
  empty_factor_to_na <- function(x) {
    if (!is.factor(x) && !is.ordered(x)) return(x)
    y <- as.character(x); y[y == ""] <- NA_character_; factor(y)
  }
  graph <-
    po("colapply", id = "empty_factor_to_na", applicator = empty_factor_to_na,
       affect_columns = selector_type(c("factor", "ordered"))) %>>%
    po("imputemedian", id = "impute_numeric_median") %>>%
    po("imputemode", id = "impute_factor_mode") %>>%
    build_target_encoding_po(affect_cols = affect_cols, smoothing = smoothing) %>>%
    base_learner
  as_learner(graph)
}
