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

# --- Exact-value Target-Encoding fuer (typisch NUMERISCHE) Spalten -----------
# Bei synthetischen Daten mit endlichem Support wiederholen sich auch numerische
# Werte stark (jeder Wert mehrfach) -> der exakte Wert wirkt wie eine
# hochkardinale Kategorie. Diese Helfer behandeln die uebergebenen Spalten als
# solche und fuegen ihre leck-sichere Impact-Kodierung als ZUSAETZLICHE Features
# hinzu (Originale bleiben erhalten, damit Baeume den rohen Wert UND die
# Kodierung nutzen). Herkunft: Kaggle-s6e7-4th-place (dort +0.0007 XGBoost),
# bestaetigt auf s6e8 (CV +0.0044 AUC, LB +0.0038). Zweite unabhaengige
# Bestaetigung -> aus dem TARGETS.md-Backlog in den Workflow uebernommen.
#
# VORBEDINGUNG (unbedingt pruefen!): nur sinnvoll, wenn die Werte tatsaechlich
# stark wiederholen (uniq_frac klein, z.B. < 0.01, jeder Wert mit vielen
# Beobachtungen). Bei quasi-stetigen, kaum wiederholten Werten waere jeder Wert
# quasi-eindeutig -> reines Overfitting. Und: NICHT auf einem Zeilen-Subset
# screenen (Per-Wert-Statistiken brauchen Volumen; das Vorzeichen kann sonst
# kippen - Folds/Epochen reduzieren, nicht Zeilen).
#
# LECK-SICHERHEIT: encodeimpact als Teil eines GraphLearners wird pro CV-Fold
# nur auf Trainingszeilen gefittet und in $predict() angewandt (wie
# build_target_encoding_po). NA/Leerstring werden ein eigenes Level
# (Missingness-as-Signal). Generisch fuer binaer UND multiclass (je Klasse eine
# Impact-Spalte <col>.<klasse>, kollidiert nicht mit den Originalnamen).
# Laufzeit-Hinweis: encodeimpact auf sehr hochkardinalen (numerisch-als-Faktor)
# Spalten ist spuerbar teurer als auf niedrigkardinalen Faktoren.
build_exact_value_te_graph <- function(cols, smoothing = 1e-2, id_prefix = "evte") {
  to_factor_na_level <- function(x) {
    z <- as.character(x); z[is.na(z) | z == ""] <- "__NA__"; factor(z)
  }
  te_branch <-
    po("select", id = paste0(id_prefix, "_select"), selector = selector_name(cols)) %>>%
    po("colapply", id = paste0(id_prefix, "_as_factor"), applicator = to_factor_na_level) %>>%
    po("encodeimpact", id = paste0(id_prefix, "_impact"), smoothing = smoothing, impute_zero = TRUE)
  po("copy", outnum = 2, id = paste0(id_prefix, "_copy")) %>>%
    gunion(list(
      po("nop", id = paste0(id_prefix, "_keep")),
      te_branch
    )) %>>%
    po("featureunion", id = paste0(id_prefix, "_union"))
}

# Kompletter GraphLearner: exact-value TE (Originale + Impact-Features) ->
# Leerstring->NA -> Imputation -> base_learner. Spiegelt
# build_target_encoded_pipeline(), nur mit Exact-value-TE statt regulaerem
# Kategorie-TE. `exact_value_cols`: Spalten mit stark wiederholten Werten.
build_exact_value_te_pipeline <- function(base_learner, exact_value_cols, smoothing = 1e-2) {
  empty_factor_to_na <- function(x) {
    if (!is.factor(x) && !is.ordered(x)) return(x)
    y <- as.character(x); y[y == ""] <- NA_character_; factor(y)
  }
  graph <-
    build_exact_value_te_graph(exact_value_cols, smoothing = smoothing) %>>%
    po("colapply", id = "empty_factor_to_na", applicator = empty_factor_to_na,
       affect_columns = selector_type(c("factor", "ordered"))) %>>%
    po("imputemedian", id = "impute_numeric_median") %>>%
    po("imputemode", id = "impute_factor_mode") %>>%
    base_learner
  as_learner(graph)
}
