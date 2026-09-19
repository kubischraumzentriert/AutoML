# protocols/

Versionierte **Outer-Evaluation-Benchmark-Protokolle** (ADR-008): prüfen,
wie gut der tatsächlich gelebte Projekt-Workflow (klassengewichtetes
Ranger-/LightGBM-Training + Multiplier-/Hyperparameter-Tuning) auf
Outer-Test-Folds generalisiert, die NIE von einer Inner-Entscheidung
(Hyperparameter-Suche, Multiplier-Suche) berührt werden - beantwortet also
nicht nur "wie gut ist der Score", sondern "ist der Score selbst
vertrauenswürdig, oder Leckage-artig optimistisch".

## Warum ein eigenes Verzeichnis, kein `modules/`?

**ADR-008 (`adr/008-frozen-versioned-benchmark-protocols.md`): diese
Dateien werden nach Abschluss eingefroren und NIE in-place verändert.**
Eine Methodikänderung (neuer Vergleichsarm, andere Fold-Zahl, andere
Leckage-Garantie) erzeugt eine neue `_vN`-Datei statt die bestehende zu
editieren - sonst wären ältere, bereits berichtete Ergebnisse (BACKLOG.md,
Statusanker, `docs/research/`) rückwirkend nicht mehr nachvollziehbar
reproduzierbar. `modules/` dagegen enthält lebende, bei Bedarf
weiterentwickelte Bausteine - der Gegensatz zu "eingefroren" ist der Grund
für die Trennung.

| Datei | Protokoll-Version | Vergleichsarme |
|---|---|---|
| `outer_workflow_evaluation.R` | P1.1-Prototyp (2026-08-26), nur `health_condition` | `ranger_default`, `lightgbm_default`, `lightgbm_tuned`, `workflow_ranger` |
| `outer_workflow_evaluation_template.R` | v1, generalisiert für beliebige Projekte | wie oben |
| `outer_workflow_evaluation_v2_fair_baselines.R` | v2, "faire Baselines" | v1 + 2 zusätzliche GETUNTE Baseline-Arme |
| `outer_workflow_evaluation_v3_level2.R` | v3, Level-2-Evaluation (siehe `docs/research/EVALUATION_LEVELS.md`) | v2 + Modellwahl selbst als Teil der Inner-Entscheidung |
| `outer_workflow_helpers.R` | **kein Protokoll, sondern Plumbing** | gemeinsame Bausteine (Fallback-Shims, `make_imputed_learner()`, Standard-Arme, `direction_max`-Summary), aus den 4 obigen Dateien extrahiert - diese Datei selbst ist NICHT eingefroren, da reine technische Wiederverwendung ohne methodische Aussage |

Ergebnisse und Interpretation je Version stehen in `BACKLOG.md`
(P1.1-Abschnitt) und den Statusanker-Dateien, nicht hier - dieses
Verzeichnis enthält nur den ausführbaren Code der jeweiligen Version.
`162_benchmark_statistics_report.R` (Root) nutzt die CSV-Ergebnisse
mehrerer Protokoll-v2-Läufe für eine Mehrfach-Datensatz-Statistik.
