rm(list = ls())
source("000_config.R")
source("db_logging.R")
source("evidence_registry.R")

con <- db_connect()

results <- list(
  list(project = "openml-cc18-sick", metric = "classif.bacc", hard = 0.5000, ref_mean = 0.9060, z = -19.72, status = "confirmed"),
  list(project = "openml-cc18-cmc", metric = "classif.bacc", hard = 0.3845, ref_mean = 0.5171, z = -18.94, status = "confirmed"),
  list(project = "openml-cc18-analcatdata-authorship", metric = "classif.bacc", hard = 0.7158, ref_mean = 0.9864, z = -57.78, status = "confirmed"),
  list(project = "openml-cc18-blood-transfusion", metric = "classif.bacc", hard = 0.7176, ref_mean = 0.6247, z = 2.46, status = "neutral")
)

for (r in results) {
  db_log_evidence(
    con,
    project = r$project,
    module = "hard_split_stress_test.R",
    role = "trust_gate",
    status = r$status,
    metric = r$metric,
    baseline_value = r$ref_mean,
    result_value = r$hard,
    delta = r$hard - r$ref_mean,
    backport_status = "open",
    evidence_source = "hard_split_stress_test_prototype.R (P2, astartes-inspiriert, Rollout auf restliche 4 CC18-Datensaetze)",
    notes = sprintf("z=%.2f gegenueber Referenzbereich aus 10 zufaelligen Holdouts gleicher Testgroesse; k=2 k-means-Cluster-Split, ungetunter klassengewichteter Ranger.", r$z)
  )
}

cat("Rollout-Log abgeschlossen: sick z=-19.72, cmc z=-18.94, analcatdata-authorship z=-57.78, blood-transfusion z=2.46\n")
cat("Zusammen mit ilpd (z=0.18) und optdigits (z=-157.67): 4/6 Datensaetze deutlich auffaellig (|z|>2), 2/6 unauffaellig.\n")

DBI::dbDisconnect(con)
