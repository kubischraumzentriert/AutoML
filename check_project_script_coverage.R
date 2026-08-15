rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
})

# Automatisiert, was bei der Pflege von SYSTEMATIC_EVALUATION.md bisher
# manuell per `ls`/Bash-Schleife je Spalte geprueft wurde: welches Projekt
# hat welches nummerierte Workflow-Skript tatsaechlich im Ordner? Anlass:
# genau dieser manuelle Weg fuehrte einmal zu einer echten Fehl-Zuordnung
# (s6e5 wurde faelschlich mit s6e6s Ensemble-Selection-Ergebnis markiert,
# siehe TARGETS.md/SYSTEMATIC_EVALUATION.md, Eintrag 2026-08-15) - ein
# wiederholbares Skript macht diesen Check zuverlaessig und schnell erneut
# ausfuehrbar, statt ihn jedes Mal neu von Hand zu tippen.
#
# BEWUSST NUR EXAKTER DATEINAME-ABGLEICH, keine Heuristik/Fuzzy-Matching:
# mehrere reale Projekte haben denselben Mechanismus unter einem ANDEREN,
# aelteren lokalen Dateinamen (z.B. `playground-series-s6e6`s
# `146_ensemble_selection.R` statt des aktuellen `148_ensemble_candidate_
# pool.R`/`149_ensemble_selection.R`; die drei Multi-Label-Projekte nutzen
# `030_binary_relevance_baseline.R`/`031_threshold_tuning.R` statt des
# aktuellen `021_multilabel_workflow.R`). Ein Fuzzy-Match haette genau die
# Sorte Fehlzuordnung riskiert, die dieses Skript eigentlich vermeiden soll -
# FALSE heisst hier also "kein Skript unter dem AKTUELLEN kanonischen Namen
# gefunden", nicht zwingend "Mechanismus nie angewendet". Solche Alias-Faelle
# bleiben bewusste manuelle Dokumentation (siehe SYSTEMATIC_EVALUATION.md).
#
# Quellen werden wie in merge_project_experiments.R automatisch unter den
# bekannten Projekt-Wurzeln gesucht, keine manuell gepflegte Liste.

project_roots <- c(
  "C:/Users/HP/OneDrive/Dokumente/R_Workspace",
  "C:/Users/HP/ML_Learning"
)
exclude_dirs <- c("MLR3_Classifikation", "MLR3_Regression")

# id -> ein oder mehrere kanonische Dateinamen (Projekt gilt als "hat es",
# wenn MINDESTENS EINER davon existiert - z.B. Threshold-Tuning hat je nach
# Projektart 130 ODER 146 ODER nur den Multiplikator-Optimizer).
canonical_scripts <- list(
  "Leak-Audit (015)" = "015_target_leak_audit.R",
  "Adversarial Val. (115)" = "115_adversarial_validation.R",
  "Split-Size-Sens. (022)" = "022_split_size_sensitivity.R",
  "Learning-Curve (023)" = "023_learning_curve.R",
  "Seed-Stabilitaet (092)" = "092_seed_stability.R",
  "Generalisierungsluecke (136)" = "136_generalization_gap.R",
  "Ensemble Selection (148/149)" = c("148_ensemble_candidate_pool.R", "149_ensemble_selection.R"),
  "Threshold-Tuning (130)" = c("130_threshold_tuning.R", "146_threshold_tuning_ranger.R", "class_multiplier_tuning.R"),
  "Multi-Label (021)" = "021_multilabel_workflow.R"
)

discover_project_dirs <- function(roots, exclude) {
  found <- unlist(lapply(roots, function(root) {
    if (!dir.exists(root)) return(character(0))
    list.dirs(root, recursive = FALSE)
  }))
  found <- unique(normalizePath(found, winslash = "/", mustWork = FALSE))
  # Nur echte Template-Projekte: `000_config.R` ist die Konvention, die
  # JEDES Projekt dieser Familie hat (siehe TARGETS.md/AGENTS.md) - filtert
  # Nicht-Projekt-Unterordner (.git, alte Scratch-Verzeichnisse, Datensatz-
  # Ordner ohne Pipeline wie `niftis`/`catboost_info`) zuverlaessig heraus,
  # ohne eine manuell gepflegte Ausschlussliste zu brauchen.
  found <- found[file.exists(file.path(found, "000_config.R"))]
  basenames <- basename(found)
  found[!basenames %in% exclude]
}

project_dirs <- discover_project_dirs(project_roots, exclude_dirs)

has_any_script <- function(project_dir, filenames) {
  any(file.exists(file.path(project_dir, filenames)))
}

coverage <- data.table(project = basename(project_dirs))
for (component in names(canonical_scripts)) {
  coverage[[component]] <- vapply(
    project_dirs, has_any_script, logical(1),
    filenames = canonical_scripts[[component]]
  )
}

setorder(coverage, project)

cat("=== Skript-Abdeckung je Projekt (nur exakter kanonischer Dateiname) ===\n")
cat(nrow(coverage), "Projekte gefunden unter:", paste(project_roots, collapse = ", "), "\n\n")
print(coverage)

cat("\nHinweis: FALSE heisst 'kein kanonischer Dateiname gefunden', nicht\n")
cat("zwingend 'Mechanismus nie angewendet' - siehe Skript-Kopfkommentar fuer\n")
cat("bekannte Alias-Faelle (s6e6, Multi-Label-Trio).\n")

# Laeuft mit dem Template-Root als Arbeitsverzeichnis (gleiche Konvention
# wie merge_project_experiments.R) - relativer Pfad reicht.
dir.create("_artifacts", showWarnings = FALSE, recursive = TRUE)
fwrite(coverage, "_artifacts/project_script_coverage.csv")
cat("\nGespeichert:", normalizePath("_artifacts/project_script_coverage.csv", winslash = "/"), "\n")
