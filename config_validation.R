# =====================================================================
# config_validation.R -- validate_config(): fruehe, verstaendliche Fehler
# statt spaeter kryptischer Abstuerze tief in einem numerierten Skript.
# =====================================================================
# P0.3 (ChatGPTs korrigierter Plan): "000_config.R modularisieren, ohne die
# flache Architektur zu verlassen". BEWUSST KEINE physische Aufteilung von
# `000_config.R` selbst - dieses Template wird per Kopieren-und-Anpassen
# wiederverwendet (siehe TARGETS.md-Checkliste "Uebertragung auf einen
# neuen Kaggle-Wettbewerb"), eine Aufteilung in mehrere Dateien wuerde genau
# dieses Muster erschweren. Stattdessen: eine neue, rein additive Datei mit
# EINER Funktion, die die BESTEHENDEN `000_config.R`-Werte auf Konsistenz
# prueft. Kein bestehendes Skript ruft sie automatisch auf - ein neues
# Projekt (oder eine bestehende Session) ruft sie manuell nach dem Anpassen
# von `000_config.R` auf: `source("config_validation.R"); validate_config()`.
#
# Deckt aus ChatGPTs P0.3-Checkliste die Punkte ab, die auf tatsaechlich
# existierende Config-Variablen dieses Templates abbilden. "Group-CV ohne
# Group-Spalte"/"Time-CV ohne Zeitinformation" sind hier NICHT als feste
# Config-Variable vorgesehen (das ist Panel-/Forecasting-spezifisch, siehe
# das analoge Backlog-Kapitel im Regressions-Template) - bewusst
# ausgelassen statt eine nicht-existente Konvention zu erfinden.
# "Schwellenwertunabhaengige Metrik + Threshold-Tuning" deckt bereits
# `warn_if_threshold_step_low_value()` (db_logging.R) ab - hier nicht
# dupliziert.

#' Prueft die zentralen `000_config.R`-Werte auf innere Konsistenz.
#'
#' @param env Environment, aus dem die Config-Variablen gelesen werden
#'   (Default: die Umgebung des Aufrufers - nach `source("000_config.R")`
#'   im Skript/in der Konsole ist das ueblicherweise `.GlobalEnv`).
#' @return `invisible(TRUE)` bei Erfolg. Wirft einen EINZIGEN `stop()` mit
#'   allen gefundenen Fehlern (nicht nur dem ersten), falls es welche gibt -
#'   spart wiederholtes Aufrufen+Fixen+Aufrufen. Gibt zusaetzlich `warning()`
#'   fuer nicht-fatale Hinweise aus.
validate_config <- function(env = parent.frame()) {
  get_or <- function(name, default = NULL) {
    if (exists(name, envir = env, inherits = FALSE)) get(name, envir = env) else default
  }

  errors <- character(0)
  warn <- function(msg) errors <<- c(errors, msg)
  soft_warnings <- character(0)

  # --- target_col --------------------------------------------------------
  target_col <- get_or("target_col")
  if (is.null(target_col) || !is.character(target_col) || length(target_col) != 1 || !nzchar(target_col)) {
    warn("target_col fehlt oder ist kein einzelner nicht-leerer String.")
  }

  # --- id_col: NULL ODER Zeichenvektor (kann laut 020_task.R auch ein
  # Vektor > 1 sein, siehe openml-eeg-eye-state-timeseries) -------------
  id_col <- get_or("id_col")
  if (!is.null(id_col) && (!is.character(id_col) || length(id_col) == 0 || any(!nzchar(id_col)))) {
    warn("id_col muss NULL oder ein Zeichenvektor nicht-leerer Spaltennamen sein.")
  }

  # --- baseline_measure_ids: nicht leer, jede ID ein bekanntes mlr3-Mass -
  baseline_measure_ids <- get_or("baseline_measure_ids")
  if (is.null(baseline_measure_ids) || length(baseline_measure_ids) == 0) {
    warn("baseline_measure_ids fehlt oder ist leer.")
  } else if (requireNamespace("mlr3", quietly = TRUE)) {
    unknown <- Filter(function(m) inherits(tryCatch(mlr3::msr(m), error = function(e) e), "error"), baseline_measure_ids)
    if (length(unknown) > 0) {
      warn(sprintf("baseline_measure_ids enthaelt unbekannte mlr3-Mass-IDs: %s", paste(unknown, collapse = ", ")))
    }
  }

  # --- positive_class: NULL ODER einzelner String -------------------------
  positive_class <- get_or("positive_class")
  if (!is.null(positive_class) && (!is.character(positive_class) || length(positive_class) != 1)) {
    warn("positive_class muss NULL oder ein einzelner String sein.")
  }
  threshold_independent_measures <- c(
    "classif.auc", "classif.logloss", "classif.prauc",
    "classif.mauc_au1p", "classif.mauc_au1u", "classif.mauc_aunp", "classif.mauc_aunu"
  )
  if (is.null(positive_class) && !is.null(baseline_measure_ids) && length(baseline_measure_ids) > 0 &&
      baseline_measure_ids[1] %in% threshold_independent_measures) {
    soft_warnings <- c(soft_warnings, sprintf(
      "positive_class ist NULL, aber baseline_measure_ids[1]='%s' ist schwellenwertunabhaengig - falls die Aufgabe BINAER ist, sollte positive_class gesetzt sein (siehe 020_task.R/155_predict_submission.R).",
      baseline_measure_ids[1]
    ))
  }

  # --- Multi-Label-Konfiguration: Ratios muessen Platz fuer Eval lassen --
  label_cols <- get_or("label_cols", character(0))
  if (length(label_cols) > 0) {
    train_ratio <- get_or("multilabel_train_ratio")
    tune_ratio <- get_or("multilabel_tune_ratio")
    if (is.null(train_ratio) || is.null(tune_ratio)) {
      warn("label_cols ist gesetzt, aber multilabel_train_ratio/multilabel_tune_ratio fehlen.")
    } else if (train_ratio <= 0 || train_ratio >= 1 || tune_ratio <= 0 || tune_ratio >= 1) {
      warn("multilabel_train_ratio/multilabel_tune_ratio muessen jeweils in (0, 1) liegen.")
    } else if (train_ratio + tune_ratio >= 1) {
      warn(sprintf(
        "multilabel_train_ratio (%.2f) + multilabel_tune_ratio (%.2f) >= 1 - kein Platz fuer die Eval-Menge.",
        train_ratio, tune_ratio
      ))
    }
    if (target_col %in% label_cols) {
      warn("target_col taucht auch in label_cols auf - bei Multi-Label sollte target_col NICHT als eigenes Label wiederholt werden.")
    }
  }

  # --- Split-/Budget-Anteile in sinnvollen Bereichen ----------------------
  check_ratio01 <- function(name, allow_one = FALSE) {
    v <- get_or(name)
    if (is.null(v)) return(invisible())
    ok <- if (allow_one) (v > 0 && v <= 1) else (v > 0 && v < 1)
    if (!ok) warn(sprintf("%s = %s liegt ausserhalb des erwarteten Bereichs (0, %s].", name, v, if (allow_one) "1" else "1)"))
  }
  check_ratio01("validation_ratio")
  check_ratio01("subset_fraction", allow_one = TRUE)

  cv_folds <- get_or("cv_folds")
  if (!is.null(cv_folds) && (!is.numeric(cv_folds) || cv_folds < 2 || cv_folds != round(cv_folds))) {
    warn(sprintf("cv_folds = %s ist keine ganze Zahl >= 2.", cv_folds))
  }

  class_weight_power <- get_or("class_weight_power")
  if (!is.null(class_weight_power) && (!is.numeric(class_weight_power) || class_weight_power < 0)) {
    warn(sprintf("class_weight_power = %s muss numerisch und >= 0 sein.", class_weight_power))
  }

  # --- Modellnamen-Konsistenz: model_feature_sets/model_class_weight_power/
  # submission_model_override muessen auf tatsaechliche base_learner_
  # constructors-Eintraege verweisen - faengt Tippfehler beim Uebertragen
  # auf ein neues Projekt (z.B. "lgihtgbm" statt "lightgbm"). ------------
  base_learner_constructors <- get_or("base_learner_constructors")
  known_models <- if (!is.null(base_learner_constructors)) names(base_learner_constructors) else NULL
  if (!is.null(known_models)) {
    check_model_names <- function(names_to_check, source_label) {
      unknown <- setdiff(names_to_check, known_models)
      if (length(unknown) > 0) {
        warn(sprintf(
          "%s referenziert Modell(e), die nicht in base_learner_constructors stehen: %s (bekannt: %s)",
          source_label, paste(unknown, collapse = ", "), paste(known_models, collapse = ", ")
        ))
      }
    }
    model_feature_sets <- get_or("model_feature_sets")
    if (!is.null(model_feature_sets)) check_model_names(names(model_feature_sets), "model_feature_sets")
    model_class_weight_power <- get_or("model_class_weight_power")
    if (!is.null(model_class_weight_power)) check_model_names(names(model_class_weight_power), "model_class_weight_power")
    submission_model_override <- get_or("submission_model_override")
    if (!is.null(submission_model_override)) check_model_names(submission_model_override, "submission_model_override")
  }

  # --- Directional-Expectation-Specs: Pflichtfelder je Typ ---------------
  specs <- get_or("directional_expectation_specs", list())
  for (i in seq_along(specs)) {
    s <- specs[[i]]
    required <- c("feature", "type", "direction", "favorable_class")
    missing_fields <- setdiff(required, names(s))
    if (length(missing_fields) > 0) {
      warn(sprintf("directional_expectation_specs[[%d]] fehlen Felder: %s", i, paste(missing_fields, collapse = ", ")))
      next
    }
    if (!s$type %in% c("numeric", "ordinal")) {
      warn(sprintf("directional_expectation_specs[[%d]]: type muss 'numeric' oder 'ordinal' sein, nicht '%s'.", i, s$type))
    } else if (s$type == "numeric" && is.null(s$delta)) {
      warn(sprintf("directional_expectation_specs[[%d]]: type='numeric' braucht ein 'delta'-Feld.", i))
    } else if (s$type == "ordinal" && is.null(s$level_order)) {
      warn(sprintf("directional_expectation_specs[[%d]]: type='ordinal' braucht ein 'level_order'-Feld.", i))
    }
    if (!is.null(s$direction) && !s$direction %in% c("increasing", "decreasing")) {
      warn(sprintf("directional_expectation_specs[[%d]]: direction muss 'increasing' oder 'decreasing' sein, nicht '%s'.", i, s$direction))
    }
  }

  # --- Ergebnis ------------------------------------------------------------
  for (w in soft_warnings) warning(w, call. = FALSE)
  if (length(errors) > 0) {
    stop("validate_config() fand ", length(errors), " Problem(e):\n- ", paste(errors, collapse = "\n- "), call. = FALSE)
  }
  invisible(TRUE)
}
