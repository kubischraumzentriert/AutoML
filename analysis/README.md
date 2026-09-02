# `analysis/`

Abgeschlossene Diagnose-, Evidenz- und Forschungs-Skripte, die zu einer
bestimmten Fragestellung ein Ergebnis erzeugt haben (meist bereits als
Kommentar im Skript selbst oder in `BACKLOG.md`/`TARGETS.md` dokumentiert).
Sie sind **nicht Teil der nummerierten Produktionspipeline** (`000_config.R`
bis `170_*.R`, siehe `WorkflowDescription.md`) und werden von keinem
nummerierten Skript `source()`t.

Ausfuehren weiterhin mit dem Repo-Root als Arbeitsverzeichnis, z. B.:

```r
Rscript analysis/build_portfolio_warmstart_evidence.R
```

Diese Skripte referenzieren `000_config.R`/`db_logging.R` etc. relativ zum
Arbeitsverzeichnis, nicht relativ zu ihrem eigenen Pfad - ein Aufruf aus
einem anderen Verzeichnis funktioniert daher nicht.

Eingefrorene Benchmark-Protokolle (`outer_workflow_evaluation*.R`, ADR-008)
und der Kern-Workflow (nummerierte Skripte + direkt gesourcete
Support-Module wie `db_logging.R`, `evidence_registry.R`) bleiben bewusst
im Repo-Root - siehe ADR-007 (`adr/007-flat-scripts-not-r-package.md`).
