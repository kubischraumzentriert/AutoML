rm(list = ls())
source("000_config.R")
source("db_logging.R")
source("evidence_registry.R")

con <- db_connect()

level2_results <- list(
  list(project = "openml-cc18-ozone-level-8hr", level2 = 0.8347750, best_baseline = 0.6336637),
  list(project = "openml-cc18-dresses-sales", level2 = 0.5279430, best_baseline = 0.5813016),
  list(project = "openml-cc18-jm1", level2 = 0.6736012, best_baseline = 0.5831817),
  list(project = "openml-cc18-mice-protein", level2 = 0.9955556, best_baseline = 0.9899206),
  list(project = "openml-cc18-mfeat-morphological", level2 = 0.7169908, best_baseline = 0.7164782)
)
for (r in level2_results) {
  db_log_evidence(
    con, project = r$project, module = "outer_workflow_evaluation_v3_level2.R",
    role = "score_lever", status = "neutral",
    metric = "classif.bacc", baseline_value = r$best_baseline, result_value = r$level2,
    delta = r$level2 - r$best_baseline,
    evidence_source = "P1 Weg-B-Erweiterung, 2. Tranche (n=10->15 CC18-Datensaetze), 2026-09-01",
    notes = "Level-2-Workflow vs. bester ungetunter Baseline-Arm, gemittelt ueber 3 Outer-Folds."
  )
}

stability_results <- list(
  list(project = "openml-cc18-ozone-level-8hr", fold = 1, majority = "lightgbm", stability = 0.70, flagged = FALSE),
  list(project = "openml-cc18-ozone-level-8hr", fold = 2, majority = "lightgbm", stability = 0.60, flagged = TRUE),
  list(project = "openml-cc18-ozone-level-8hr", fold = 3, majority = "lightgbm", stability = 0.90, flagged = FALSE),
  list(project = "openml-cc18-jm1", fold = 1, majority = "ensemble", stability = 0.60, flagged = TRUE),
  list(project = "openml-cc18-jm1", fold = 2, majority = "ensemble", stability = 0.50, flagged = TRUE),
  list(project = "openml-cc18-jm1", fold = 3, majority = "ranger", stability = 0.50, flagged = TRUE),
  list(project = "openml-cc18-dresses-sales", fold = 1, majority = "ranger", stability = 0.60, flagged = TRUE),
  list(project = "openml-cc18-dresses-sales", fold = 2, majority = "ranger", stability = 0.80, flagged = FALSE),
  list(project = "openml-cc18-dresses-sales", fold = 3, majority = "ranger", stability = 0.50, flagged = TRUE),
  list(project = "openml-cc18-mice-protein", fold = 1, majority = "lightgbm", stability = 0.60, flagged = TRUE),
  list(project = "openml-cc18-mice-protein", fold = 2, majority = "lightgbm", stability = 0.70, flagged = FALSE),
  list(project = "openml-cc18-mice-protein", fold = 3, majority = "lightgbm", stability = 0.40, flagged = TRUE),
  list(project = "openml-cc18-mfeat-morphological", fold = 1, majority = "ensemble", stability = 0.50, flagged = TRUE),
  list(project = "openml-cc18-mfeat-morphological", fold = 2, majority = "ranger", stability = 0.60, flagged = TRUE),
  list(project = "openml-cc18-mfeat-morphological", fold = 3, majority = "ranger", stability = 0.70, flagged = FALSE)
)
for (r in stability_results) {
  db_log_evidence(
    con, project = r$project, module = "decision_stability_level2_prototype.R",
    role = "trust_gate", status = if (r$flagged) "confirmed" else "neutral",
    result_value = r$stability, backport_status = "open",
    evidence_source = "P1 Weg-B-Erweiterung, 2. Tranche (n=10->15 CC18-Datensaetze), 2026-09-01",
    notes = sprintf("Outer-Fold %d: Mehrheitsentscheidung=%s (%.0f%% der 10 Wiederholungen)%s",
                     r$fold, r$majority, r$stability * 100, if (r$flagged) " - AUFFAELLIG (<70%)" else "")
  )
}

db_log_evidence(
  con, project = "MLR3_Classifikation (uebergreifend)", module = "decision_stability_level2_analysis_n15.R",
  role = "trust_gate", status = "negative",
  result_value = -0.147,
  evidence_source = "P1 Weg-B-Erweiterung, 2. Tranche, Spearman-Korrelation ueber n=15 Datensaetze x 3 Folds (45 Messungen)",
  notes = "rho=-0.147, p=0.601 (n=15) - bestaetigt den n=6- (rho=-0.086) und n=10-Befund (rho=-0.134) ein drittes Mal. KEIN Zusammenhang zwischen Level-2-Arm-Wahl-Stabilitaet und Level-2-vs-Baseline-Delta, jetzt ueber 3 unabhaengige Stichprobenerweiterungen hinweg robust bestaetigt."
)

cat("n=15-Evidenz geloggt: 5 Level-2-Ergebnisse, 15 Decision-Stability-Ergebnisse, 1 uebergreifende Korrelationsanalyse.\n")
DBI::dbDisconnect(con)
