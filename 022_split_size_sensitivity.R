# =====================================================================
# 022_split_size_sensitivity.R -- Split-Size-Sensitivity-Analyse (siehe
# split_size_sensitivity.R und TARGETS.md fuer Herkunft/Verifikation).
# =====================================================================
# Prueft, ob der gewaehlte validation_ratio selbst stabil ist - bewusst
# FRUEH in der Pipeline (nach 020_task.R, vor Feature Engineering/Modell-
# training), da das Ergebnis die spaetere Interpretation aller Holdout-
# Bewertungen einordnet: bei einer hohen CV waere eine einzelne
# validation_ratio-Bewertung wenig verlaesslich, unabhaengig davon, welches
# Modell/Feature-Set als naechstes getestet wird.
rm(list = ls())
suppressPackageStartupMessages({ library(data.table); library(mlr3) })

source("000_config.R")
source(file.path(project_dir, "split_size_sensitivity.R"))
set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}
task <- readRDS(task_train_small_path)

if (task$nrow > split_sensitivity_max_n) {
  cat(sprintf(
    "022_split_size_sensitivity.R uebersprungen: %d Zeilen > split_sensitivity_max_n (%d) - ",
    task$nrow, split_sensitivity_max_n
  ))
  cat("bei dieser Groessenordnung war der Effekt in 2 realen Bestaetigungen unauffaellig, ")
  cat("siehe TARGETS.md.\n")
  quit(save = "no", status = 0)
}

# classif.rpart statt eines Projekt-Learners: der Mechanismus (Streuung
# durch Testset-Groesse) ist weitgehend lernverfahren-unabhaengig, ein
# schneller Baum-Lerner reicht fuer die Diagnose (siehe Kommentar zu
# split_sensitivity_max_n in 000_config.R). predict_type="prob": siehe
# 030_baseline.R/BACKLOG.md (2026-09-01) fuer die Begruendung - noetig
# fuer eine AUC-/LogLoss-bewertete Uebertragung.
learner <- lrn("classif.rpart", predict_type = "prob")
measure <- msr(baseline_measure_ids[1])

sens <- split_ratio_sensitivity(
  task, learner, measure, split_sensitivity_ratios,
  repeats = split_sensitivity_repeats, seed = seed
)
report_split_ratio_sensitivity(
  sens, chosen_ratio = validation_ratio,
  out_path = split_sensitivity_results_path,
  cv_warn_relative = split_sensitivity_cv_warn_relative
)
