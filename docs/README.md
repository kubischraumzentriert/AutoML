# docs/

Vertiefende Dokumentation, die zu ausführlich für README/`TARGETS.md`/
`BACKLOG.md` wäre. Drei Unterordner nach Zweck getrennt:

## `reference/`

**Theoretischer Hintergrund und Herleitungen** zu einzelnen `modules/`-
Bausteinen (`REFERENZ_*.md`) - Quellen, Mechanismus, warum eine
Bestätigung an ≥2 Projekten nötig war (ADR-003). Kein Code, reine Prosa.
Plus `SCRIPT_INDEX.md`: Ergänzung zu `README_DETAILS.md`s Skript-Tabelle
um nicht-nummerierte Root-Skripte ohne eigene Dokumentationszeile.

## `research/`

**Roadmaps, Protokoll-Definitionen und Recherche-Ergebnisse**, die über
eine einzelne Modul-Referenz hinausgehen - Benchmark-Protokoll-Design
(`BENCHMARK_PROTOCOL.md`), Evaluationsebenen (`EVALUATION_LEVELS.md`),
externe Vergleichs-/Benchmark-Sets, JOSS-Publikationsvorbereitung
(`PAPER_DRAFT.md`, `JOSS_TECHNIQUE_WATCH.md` - laufend beobachtete externe
Techniken/Pakete als Backlog-Kandidatenquelle), die generierte
Projekt-x-Modul-Ergebnistabelle (`SYSTEMATIC_EVALUATION*.md`), sowie
projektspezifische Piloten (`AGRIDATASETS_PILOT.md`,
`DWD_WEATHER_INTEGRATION.md`, `PORTFOLIO_WARMSTART_PREREG_*.md`).

## `ablations/`

**Ablationsstudien** - systematisch je EINEN Baustein des Workflows
deaktivieren/ersetzen und den Effekt messen (getrennt von den einmaligen
Backport-Bestätigungen in `BACKLOG.md`: eine Ablation fragt "wie viel
bringt dieser eine bereits eingebaute Baustein", nicht "sollte dieser neue
Baustein eingebaut werden"). `ABLATION_STUDIES_PLAN.md` definiert den
Plan bewusst getrennt von seiner Ausführung; `ABLATION_A2_*`/`ABLATION_A3_*`
sind bereits durchgeführte Einzelstudien.

## Siehe auch

- `TARGETS.md`, `BACKLOG.md`, `WorkflowDescription.md` (Repo-Root) - die
  primären, kürzeren Einstiegspunkte für "was ist der Stand" bzw. "wie ist
  der Kern-Workflow aufgebaut". `docs/` vertieft, ersetzt diese nicht.
- `modules/README.md` - Übersicht der Code-Bausteine, zu denen
  `docs/reference/` oft die Herleitung liefert.
