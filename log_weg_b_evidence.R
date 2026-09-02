rm(list = ls())
source("000_config.R")
source("db_logging.R")
source("evidence_registry.R")

con <- db_connect()

level2_results <- list(
  list(project = "openml-cc18-phishing-websites", level2 = 0.9679682, best_baseline = 0.9686621),
  list(project = "openml-cc18-qsar-biodeg", level2 = 0.8517163, best_baseline = 0.8489591),
  list(project = "openml-cc18-mfeat-karhunen", level2 = 0.9554802, best_baseline = 0.9575079),
  list(project = "openml-cc18-eucalyptus", level2 = 0.6311444, best_baseline = 0.6276678)
)
for (r in level2_results) {
  db_log_evidence(
    con, project = r$project, module = "outer_workflow_evaluation_v3_level2.R",
    role = "score_lever", status = "neutral",
    metric = "classif.bacc", baseline_value = r$best_baseline, result_value = r$level2,
    delta = r$level2 - r$best_baseline,
    evidence_source = "P1 Weg-B-Erweiterung (n=6->10 CC18-Datensaetze), 2026-08-31",
    notes = "Level-2-Workflow (Modellwahl+Tuning im Outer-Fold) vs. bester ungetunter Baseline-Arm, gemittelt ueber 3 Outer-Folds - kein konsistenter Vorteil, konsistent mit dem n=6-Befund."
  )
}

stability_results <- list(
  list(project = "openml-cc18-phishing-websites", fold = 1, majority = "ensemble", stability = 0.70, flagged = FALSE),
  list(project = "openml-cc18-phishing-websites", fold = 2, majority = "ensemble", stability = 0.60, flagged = TRUE),
  list(project = "openml-cc18-phishing-websites", fold = 3, majority = "lightgbm", stability = 0.60, flagged = TRUE),
  list(project = "openml-cc18-qsar-biodeg", fold = 1, majority = "ranger", stability = 0.50, flagged = TRUE),
  list(project = "openml-cc18-qsar-biodeg", fold = 2, majority = "ensemble", stability = 0.50, flagged = TRUE),
  list(project = "openml-cc18-qsar-biodeg", fold = 3, majority = "ranger", stability = 0.50, flagged = TRUE),
  list(project = "openml-cc18-mfeat-karhunen", fold = 1, majority = "lightgbm", stability = 0.50, flagged = TRUE),
  list(project = "openml-cc18-mfeat-karhunen", fold = 2, majority = "lightgbm", stability = 0.40, flagged = TRUE),
  list(project = "openml-cc18-mfeat-karhunen", fold = 3, majority = "ensemble", stability = 0.40, flagged = TRUE),
  list(project = "openml-cc18-eucalyptus", fold = 1, majority = "ensemble", stability = 0.50, flagged = TRUE),
  list(project = "openml-cc18-eucalyptus", fold = 2, majority = "ranger", stability = 0.60, flagged = TRUE),
  list(project = "openml-cc18-eucalyptus", fold = 3, majority = "ensemble", stability = 0.60, flagged = TRUE)
)
for (r in stability_results) {
  db_log_evidence(
    con, project = r$project, module = "decision_stability_level2_prototype.R",
    role = "trust_gate", status = if (r$flagged) "confirmed" else "neutral",
    result_value = r$stability, backport_status = "open",
    evidence_source = "P1 Weg-B-Erweiterung (n=6->10 CC18-Datensaetze), 2026-08-31",
    notes = sprintf("Outer-Fold %d: Mehrheitsentscheidung=%s (%.0f%% der 10 Wiederholungen)%s",
                     r$fold, r$majority, r$stability * 100, if (r$flagged) " - AUFFAELLIG (<70%)" else "")
  )
}

db_log_evidence(
  con, project = "MLR3_Classifikation (uebergreifend)", module = "decision_stability_level2_analysis_weg_b.R",
  role = "trust_gate", status = "negative",
  result_value = -0.134,
  evidence_source = "P1 Weg-B-Erweiterung, Spearman-Korrelation ueber n=10 Datensaetze x 3 Folds (30 Messungen)",
  notes = "rho=-0.134, p=0.712 (n=10) - bestaetigt den n=6-Befund (rho=-0.086, p=0.919), KEIN Zusammenhang zwischen Level-2-Arm-Wahl-Stabilitaet und Level-2-vs-Baseline-Delta. Widerlegt endgueltig den urspruenglichen Fold-1-only-Befund (rho=-0.28, n=6)."
)

cat("Weg-B-Evidenz geloggt: 4 Level-2-Ergebnisse, 12 Decision-Stability-Ergebnisse, 1 uebergreifende Korrelationsanalyse.\n")
DBI::dbDisconnect(con)
