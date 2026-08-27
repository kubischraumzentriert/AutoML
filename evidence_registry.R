# =====================================================================
# evidence_registry.R -- P1.2 (ChatGPTs korrigierter Plan): "Evidence
# Registry" als maschinenlesbare Ergaenzung zu TARGETS.md/README_DETAILS.md/
# SYSTEMATIC_EVALUATION.md/Statusankern.
# =====================================================================
# Scope (siehe BACKLOG.md P1.2-Status): NUR Schritt 1 aus ChatGPTs eigenem
# 3-Schritte-Vorgehen ("1. nur neue Befunde strukturiert loggen, 2. wichtige
# historische Befunde nachziehen, 3. SYSTEMATIC_EVALUATION.md automatisch
# erzeugen. Nicht sofort alles migrieren."). Dieser Prototyp deckt Schritt 1
# ab: eine `evidence`-Tabelle (siehe db_schema.sql) + eine Logging-Funktion.
# Schritt 2 (rueckwirkendes Nachtragen der ~20 Projekte x 9 Module aus
# SYSTEMATIC_EVALUATION.md) und Schritt 3 (automatische Generierung dieser
# Datei aus der Registry) sind bewusst NICHT Teil dieses Prototyps - beides
# waere ein eigener, deutlich groesserer Arbeitsschritt.
#
# Bewusst UNABHAENGIG vom project/workflow/run-Beziehungsgeflecht in
# db_logging.R: ein Befund bezieht sich oft auf eine ganze Roadmap-Frage
# ueber mehrere Projekte/Laeufe hinweg (z.B. "TabM getestet, negativ") statt
# auf einen einzelnen mlr3-Lauf - db_log_evidence() braucht deshalb keinen
# aktiven run_id/mconf_id-Kontext, nur eine offene DB-Verbindung (`con`,
# ueblicherweise via db_connect() aus db_logging.R).

#' Loggt einen einzelnen strukturierten Befund in die `evidence`-Tabelle.
#'
#' @param con Offene DBI-Verbindung (siehe `db_connect()` in db_logging.R).
#' @param project Projektordnername (Freitext, z.B. "health_condition").
#' @param module Name des betroffenen Moduls/Skripts (z.B. "148_ensemble_candidate_pool").
#' @param role Eine von "score_lever", "trust_gate", "workflow_automation", "documentation".
#' @param status Eine von "confirmed", "core_finding", "neutral", "negative", "not_applicable", "open".
#' @return Die neu erzeugte `evid_id` (unsichtbar).
db_log_evidence <- function(con, project, module, role, status,
                             dataset_type = NA_character_, metric = NA_character_,
                             baseline_value = NA_real_, result_value = NA_real_,
                             delta = NA_real_, runtime_seconds = NA_real_,
                             backport_status = NA_character_, evidence_source = NA_character_,
                             git_commit = NA_character_, notes = NA_character_) {
  valid_roles <- c("score_lever", "trust_gate", "workflow_automation", "documentation")
  stopifnot(
    "role muss eine von score_lever/trust_gate/workflow_automation/documentation sein" = role %in% valid_roles
  )
  valid_status <- c("confirmed", "core_finding", "neutral", "negative", "not_applicable", "open")
  stopifnot(
    "status muss eine von confirmed/core_finding/neutral/negative/not_applicable/open sein" = status %in% valid_status
  )
  stopifnot("project darf nicht leer sein" = is.character(project) && nzchar(project))
  stopifnot("module darf nicht leer sein" = is.character(module) && nzchar(module))

  evid_id <- uuid::UUIDgenerate()
  DBI::dbExecute(
    con,
    "INSERT INTO evidence (
       evid_id, evid_project, evid_dataset_type, evid_module, evid_role, evid_metric,
       evid_baseline_value, evid_result_value, evid_delta, evid_runtime_seconds,
       evid_status, evid_backport_status, evid_evidence_source, evid_git_commit, evid_notes
     ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
    params = list(
      evid_id, project, dataset_type, module, role, metric,
      baseline_value, result_value, delta, runtime_seconds,
      status, backport_status, evidence_source, git_commit, notes
    )
  )
  invisible(evid_id)
}

#' Liest die komplette `evidence`-Tabelle als data.table (neueste zuerst).
evidence_registry_summary <- function(con) {
  data.table::as.data.table(DBI::dbGetQuery(con, "SELECT * FROM evidence ORDER BY evid_created_at DESC"))
}
