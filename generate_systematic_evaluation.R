# =====================================================================
# generate_systematic_evaluation.R -- P1.2 Schritt 3 / Phase D (siehe
# BACKLOG.md "Naechste Bewertung 2026-08-28"): eine Projekt-x-Modul-
# Ergebnistabelle AUS der Evidence Registry erzeugen, statt sie manuell
# zu pflegen ("Publikations-Tabellen aus Registry erzeugen").
# =====================================================================
# Scope-Entscheidung (additiv, siehe unten): dieses Skript erzeugt eine
# NEUE Datei (`SYSTEMATIC_EVALUATION_GENERATED.md`), es ueberschreibt
# NICHT die bestehende, handgepflegte `SYSTEMATIC_EVALUATION.md`. Grund:
# `SYSTEMATIC_EVALUATION.md` enthaelt redaktionellen Mehrwert, den eine
# reine DB-Pivot-Tabelle nicht reproduzieren kann - Fussnoten,
# Korrekturvermerke (z.B. die IQR-Nenner-Korrektur vom 2026-08-15/17),
# einen "Was diese erste Fassung zeigt"-Diskussionsabschnitt. Der Plan
# selbst sagt "manuelle Doppelpflege beenden" - das ist das erklaerte
# LANGFRISTIGE Ziel, aber ein einmaliges Ueberschreiben des
# redaktionellen Materials in diesem Schritt haette es unwiederbringlich
# verloren. Diese Datei demonstriert stattdessen, dass die Registry die
# Tabelle reproduzieren KANN (das eigentliche Akzeptanzkriterium von
# Schritt 3), und bleibt der Weg fuer eine kuenftige Session, die beiden
# Dokumente bewusst zusammenzufuehren, sobald der redaktionelle Text
# manuell in die Registry uebertragen wurde (z.B. als `evid_notes`).
#
# Deckt ausserdem NEUE Inhalte ab, die `SYSTEMATIC_EVALUATION.md` selbst
# noch nicht kennt (z.B. das Modul `outer_workflow_evaluation` aus
# Phase C) - die generierte Tabelle ist bereits AKTUELLER als die
# manuelle Datei, ein konkreter Beleg fuer den Wert der Registry.

suppressPackageStartupMessages(library(data.table))

STATUS_SYMBOL <- c(
  confirmed = "✓", core_finding = "✓✓", neutral = "~",
  negative = "✗", not_applicable = "—", open = "?"
)

#' Baut eine Projekt-x-Modul-Pivot-Tabelle (data.table, breites Format)
#' aus der `evidence`-Tabelle. Mehrere Eintraege fuer dieselbe
#' (Projekt, Modul)-Kombination werden mit "; " zusammengefasst (nicht
#' ueberschrieben) - Verlustfreiheit vor Kompaktheit.
build_systematic_evaluation_pivot <- function(con) {
  dt <- evidence_registry_summary(con)
  if (nrow(dt) == 0) return(data.table())
  dt <- dt[!is.na(evid_module) & nzchar(evid_module)]
  dt[, cell := paste0(
    STATUS_SYMBOL[evid_status],
    ifelse(is.na(evid_notes) | !nzchar(evid_notes), "", paste0(" (", evid_notes, ")"))
  )]
  dt[, cell := vapply(cell, function(x) if (is.na(x)) "?" else x, character(1))]
  dcast(
    dt, evid_project ~ evid_module, value.var = "cell",
    fun.aggregate = function(x) paste(x, collapse = "; ")
  )
}

# Bevorzugte Spaltenreihenfolge - die 9 Original-Module aus
# `SYSTEMATIC_EVALUATION.md` zuerst (fuer Vergleichbarkeit), alles
# Weitere (z.B. neue Module wie `outer_workflow_evaluation`) alphabetisch
# dahinter.
KNOWN_MODULE_ORDER <- c(
  "015_target_leak_audit", "115_adversarial_validation", "022_split_size_sensitivity",
  "023_learning_curve", "092_seed_stability", "136_generalization_gap",
  "148_149_ensemble_selection", "130_threshold_tuning", "021_multilabel_workflow"
)

#' Rendert die Pivot-Tabelle als Markdown-Tabelle (String, eine Zeile pro
#' Zeilenumbruch) - inkl. Kopfzeile mit Erzeugungszeitpunkt/Quelle.
render_systematic_evaluation_markdown <- function(con) {
  pivot <- build_systematic_evaluation_pivot(con)
  if (nrow(pivot) == 0) {
    return("# Systematische Evaluation (AUS DER EVIDENCE REGISTRY ERZEUGT)\n\nKeine Eintraege in der Evidence Registry gefunden.\n")
  }
  data_cols <- setdiff(names(pivot), "evid_project")
  ordered_cols <- c(intersect(KNOWN_MODULE_ORDER, data_cols), sort(setdiff(data_cols, KNOWN_MODULE_ORDER)))
  setcolorder(pivot, c("evid_project", ordered_cols))
  setorder(pivot, evid_project)

  header <- paste0(
    "# Systematische Evaluation (AUS DER EVIDENCE REGISTRY ERZEUGT)\n\n",
    "Automatisch erzeugt aus der `evidence`-Tabelle via ",
    "`generate_systematic_evaluation.R` (P1.2 Schritt 3 / Phase D, siehe ",
    "BACKLOG.md \"Naechste Bewertung 2026-08-28\") am ", format(Sys.time(), "%Y-%m-%d %H:%M"), ".\n\n",
    "**Dies ersetzt NICHT** `SYSTEMATIC_EVALUATION.md` (dort steht ",
    "redaktionelles Material - Fussnoten, Korrekturvermerke, Diskussion -, ",
    "das diese generierte Tabelle nicht enthaelt). Diese Datei zeigt, dass ",
    "die Evidence Registry die Kerntabelle reproduzieren kann, und ist ",
    "bereits AKTUELLER als die manuelle Datei (z.B. `outer_workflow_evaluation` ",
    "aus Phase C fehlt dort noch).\n\n",
    "**Legende**: ✓ confirmed · ✓✓ core_finding · ~ neutral · ",
    "✗ negative · — not_applicable · ? open/unbekannter Status\n\n"
  )

  col_header <- paste0("| Projekt | ", paste(ordered_cols, collapse = " | "), " |")
  col_sep <- paste0("|---|", paste(rep("---", length(ordered_cols)), collapse = "|"), "|")
  rows <- vapply(seq_len(nrow(pivot)), function(i) {
    vals <- vapply(ordered_cols, function(col) {
      v <- pivot[[col]][i]
      if (is.na(v) || !nzchar(v)) STATUS_SYMBOL[["not_applicable"]] else v
    }, character(1))
    paste0("| `", pivot$evid_project[i], "` | ", paste(vals, collapse = " | "), " |")
  }, character(1))

  paste0(header, col_header, "\n", col_sep, "\n", paste(rows, collapse = "\n"), "\n")
}

#' Schreibt das generierte Markdown nach `out_path` (Default:
#' `SYSTEMATIC_EVALUATION_GENERATED.md` im `project_dir`).
generate_systematic_evaluation_file <- function(con, out_path = file.path(project_dir, "SYSTEMATIC_EVALUATION_GENERATED.md")) {
  writeLines(render_systematic_evaluation_markdown(con), out_path)
  invisible(out_path)
}
