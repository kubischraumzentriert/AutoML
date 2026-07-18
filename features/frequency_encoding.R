suppressPackageStartupMessages({
  library(mlr3)
  library(mlr3pipelines)
  library(paradox)
  library(data.table)
})

# Leak-armes Frequency-(Count-)Encoding fuer hochkardinale kategoriale Spalten,
# generisch und template-portabel. Geschwistermodul zu features/target_encoding.R.
#
# WANN: fuer numerisch/kategorial codierte Hoch-Kardinalitaets-IDs (Geo-/Objekt-
#   IDs), wo native Faktoren Baummodelle laufzeit-technisch unhandlich machen und
#   One-Hot unpraktikabel ist. Frequency-Encoding ist ZIELWERTFREI - es ersetzt
#   jedes Level durch seine Haeufigkeit im Trainingssatz. Damit ist es KEIN
#   Ersatz fuer Target-Encoding (das nutzt Signal aus dem Ziel), sondern ein
#   schneller, guenstiger A/B-Kandidat, der oft schon reicht (Beleg:
#   drivendata_richter geo_level_2/3_id - siehe README Encoding-Entscheidungs-
#   tabelle). Regel: bei hochkardinalen ID-Spalten ZUERST diese zielwertfreie
#   Variante gegen die native/numerische Baseline testen, bevor man den TE-
#   Aufwand faehrt.
#
# - LEAK-ARMUT: als PipeOpTaskPreprocSimple lernt der Encoder seinen Zustand
#   (Level-Zaehlungen) in $train() NUR auf den Trainingszeilen des jeweiligen
#   Folds und wendet ihn in $predict() an. Innerhalb eines GraphLearners unter
#   resample()/benchmark() sind die Frequenzen also pro Fold sauber. Da gar
#   keine Zielwerte einfliessen, ist das Leakage-Risiko ohnehin viel kleiner als
#   bei Target-Encoding (kein In-Fold-Optimismus ueber das Label); die
#   verbleibende Sorge waere nur, Frequenzen auf dem Gesamtdatensatz statt pro
#   Fold zu bilden - und genau das vermeidet die PipeOp-Integration.
#
# - UNBEKANNTE LEVEL: Level, die im Trainings-Fold nicht vorkamen (durch die
#   CV-Aufteilung nur im Validierungs-Fold), bekommen Frequenz 0 (und log1p(0)=0).
#   Kein NA - NA-intolerante Learner (LDA/Multinom) stuerzen also beim Predict
#   nicht ab (analog zu impute_zero im Target-Encoding-Modul).
#
# ERZEUGTE SPALTEN je Eingabespalte <x>:
#   <x>_freq        rohe Trainings-Haeufigkeit (Count) des Levels
#   <x>_freq_log1p  log1p(Count) - nichtlineare Stauchung, hilft linearen Modellen
#   <x>_share       (optional) Count/n; ist eine konstante Reskalierung von _freq
#                   (nur 1/n) und daher fuer die meisten Modelle redundant -
#                   default AUS, nur bei Bedarf einschalten.
# Das Original wird per Default ERSETZT (keep_original = FALSE): der hochkardinale
# Faktor verschwindet, downstream sehen numerische Features - genau das, was
# glmnet/LDA/XGBoost brauchen und was One-Hot/native-Riesenfaktoren vermeidet.
PipeOpEncodeFrequency <- R6::R6Class(
  "PipeOpEncodeFrequency",
  inherit = mlr3pipelines::PipeOpTaskPreprocSimple,
  public = list(
    initialize = function(id = "encode_frequency", param_vals = list()) {
      param_set <- paradox::ps(
        add_log       = paradox::p_lgl(tags = c("train", "predict")),
        add_share     = paradox::p_lgl(tags = c("train", "predict")),
        keep_original = paradox::p_lgl(tags = c("train", "predict"))
      )
      param_set$values <- list(add_log = TRUE, add_share = FALSE, keep_original = FALSE)
      super$initialize(
        id = id, param_set = param_set, param_vals = param_vals,
        feature_types = c("factor", "ordered", "character")
      )
    }
  ),
  private = list(
    .get_state_dt = function(dt, levels, target) {
      counts <- lapply(dt, function(col) {
        tt <- table(as.character(col), useNA = "no")
        stats::setNames(as.integer(unname(tt)), names(tt))
      })
      list(counts = counts, n = nrow(dt))
    },
    .transform_dt = function(dt, levels) {
      pv <- self$param_set$values
      out <- list()
      for (nm in names(dt)) {
        lookup <- self$state$counts[[nm]]
        freq <- unname(lookup[as.character(dt[[nm]])])
        freq[is.na(freq)] <- 0L
        out[[paste0(nm, "_freq")]] <- as.integer(freq)
        if (isTRUE(pv$add_log))   out[[paste0(nm, "_freq_log1p")]] <- log1p(freq)
        if (isTRUE(pv$add_share)) out[[paste0(nm, "_share")]] <- freq / self$state$n
      }
      new_dt <- data.table::as.data.table(out)
      if (isTRUE(pv$keep_original)) new_dt <- cbind(dt, new_dt)
      new_dt
    }
  )
)

# affect_cols: Spaltennamen, die kodiert werden sollen. NULL = alle Faktor-/
#   ordered-/character-Spalten. In der Praxis gezielt auf die hochkardinalen
#   ID-Spalten setzen (niedrigkardinale koennen Baummodelle nativ nutzen).
# add_log/add_share/keep_original: siehe Spalten-Doku oben.
build_frequency_encoding_po <- function(affect_cols = NULL, add_log = TRUE,
                                        add_share = FALSE, keep_original = FALSE,
                                        id = "encode_frequency") {
  po <- PipeOpEncodeFrequency$new(id = id, param_vals = list(
    add_log = add_log, add_share = add_share, keep_original = keep_original
  ))
  if (!is.null(affect_cols)) {
    po$param_set$values$affect_columns <- selector_name(affect_cols)
  }
  po
}

# Baut einen kompletten Klassifikations-GraphLearner mit Frequency-Encoding:
# Imputation (numerisch median, Faktor mode) -> Frequency-Encoding -> base_learner.
# Leerstring-Faktorlevel werden vorher zu NA, damit sie als fehlend imputiert
# statt als eigenes Level gezaehlt werden. Spiegelt build_target_encoded_pipeline()
# aus features/target_encoding.R, nur mit Frequency- statt Target-Encoding.
build_frequency_encoded_pipeline <- function(base_learner, affect_cols = NULL,
                                             add_log = TRUE, add_share = FALSE,
                                             keep_original = FALSE) {
  empty_factor_to_na <- function(x) {
    if (!is.factor(x) && !is.ordered(x)) return(x)
    y <- as.character(x); y[y == ""] <- NA_character_; factor(y)
  }
  graph <-
    po("colapply", id = "empty_factor_to_na", applicator = empty_factor_to_na,
       affect_columns = selector_type(c("factor", "ordered"))) %>>%
    po("imputemedian", id = "impute_numeric_median") %>>%
    po("imputemode", id = "impute_factor_mode") %>>%
    build_frequency_encoding_po(affect_cols = affect_cols, add_log = add_log,
                                add_share = add_share, keep_original = keep_original) %>>%
    base_learner
  as_learner(graph)
}
