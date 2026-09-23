# modules/ - Übersicht

Nicht-nummerierte R-Dateien, die von den nummerierten Kernskripten (`000`-`170`
im Repo-Root) per `source(file.path(project_dir, "modules", "X.R"))`
eingebunden werden, statt selbst Teil der laufenden Pipeline zu sein (siehe
ADR-007: flaches Skript-Template, kein R-Paket). Entstanden aus der
Root-Aufräumung "Schnitt 1-3" (2026-09-17) - vorher lagen diese Dateien flach
im Root.

Jede Datei trägt ihren eigenen ausführlichen Kopfkommentar (Herkunft,
Mechanismus, ggf. Backport-/ADR-003-Historie) - diese Übersicht ersetzt den
nicht, sondern hilft nur beim schnellen Einordnen: **was tut die Datei, und
wer ruft sie auf**.

## Trust-Layer / Diagnose

Prüfen Annahmen über Daten, Modell oder Evaluation, bevor man einem Ergebnis
vertraut. Kein Teil der eigentlichen Trainings-Pipeline.

| Datei | Zweck | Genutzt von |
|---|---|---|
| `target_leak_audit_helpers.R` | Testbare Kernfunktionen des Leakage-Audits (Determinismus-Check, kumulative Top-k-Schwelle, Cluster-Erkennung) | `015_target_leak_audit.R` |
| `univariate_drift.R` | Statistische Train-vs-Test-Drift-Tests je Spalte (Ergänzung zur Adversarial Validation) | `115_adversarial_validation.R`, `rolling_drift_diagnosis.R`, `missingness_mechanism_audit.R` |
| `rolling_drift_diagnosis.R` | Concept-Drift über MEHRERE Zeitperioden statt nur Train-vs-Test | eigenständig (Projekt-Skripte) |
| `missingness_mechanism_audit.R` | Ist Fehlen in einem Feature informativ (MCAR/MAR/MNAR-artig), statt naiv zu imputieren? | eigenständig |
| `composition_reweighting.R` | Label-freie Diagnose, ob eine CV↔Test-/LB-Lücke ein reiner Kompositionseffekt ist | eigenständig |
| `feature_importance_stability.R` | Ist die Gain-Importance-Rangfolge über Folds/Seeds stabil, oder Rauschen eines Einzellaufs? | `016_feature_importance_stability.R` |
| `seed_stability.R` | Score-Streuung bei fixem Split allein durch Lerner-Seed/Hyperparameter-Jitter | `092_seed_stability.R` |
| `split_size_sensitivity.R` | Ist der gewählte Train/Test-Split-Anteil selbst stabil? | `022_split_size_sensitivity.R` |
| `learning_curve.R` | Würden mehr Trainingsdaten den Score noch spürbar verbessern? | `023_learning_curve.R` |
| `generalization_gap.R` | Formale Quantifizierung der CV-/Train- vs. Holdout-Score-Lücke | `136_generalization_gap.R` |
| `decision_stability.R` | Ist die finale KLASSENENTSCHEIDUNG (nicht nur der Score) über Seeds stabil? | `decision_stability_level2_prototype.R` |
| `decision_stability_level2_prototype.R` | Wendet `decision_stability.R` auf ein konkretes Projekt an | - |
| `hard_split_stress_test.R` | Stresstest gegen EXTRAPOLATION (harte, geclusterte Splits statt zufälliger) | `137_hard_split_stress_test.R` |
| `sanity_checks.R` | Perturbations-/Invarianz-/Directional-Expectation-Checks (Huyen 2022) | `147_error_analysis_ranger_sanity_checks.R` |
| `probability_calibration.R` | Sind `predict_type="prob"`-Wahrscheinlichkeiten selbst kalibriert? | `017_probability_calibration.R` |
| `subgroup_fairness_disparity.R` | Performt das Modell über sensible Untergruppen hinweg systematisch unterschiedlich? | `018_subgroup_fairness_disparity.R` |
| `bootstrap_metric_ci.R` | Bootstrap-Konfidenzintervall für EINE final berichtete Metrik auf festen Vorhersagen | `159_bootstrap_metric_ci.R` |
| `benchmark_statistics_report.R` | Friedman/Nemenyi (Demsar 2006) - ist Methode A über MEHRERE Datensätze hinweg systematisch besser? | `162_benchmark_statistics_report.R` |

## Modell-/Workflow-Bausteine

Werden aktiv in den Trainings-/Tuning-Ablauf eingebunden, nicht nur zur
nachträglichen Diagnose.

| Datei | Zweck | Genutzt von |
|---|---|---|
| `class_multiplier_tuning.R` | Metrik-optimale Klassen-Multiplikatoren fürs Threshold-Tuning bei Multiklassen-BAcc | `130_threshold_tuning.R`, alle `protocols/outer_workflow_evaluation*.R` |
| `ensemble_selection.R` | Caruana-Greedy-Ensemble-Selection als eigenständige, testbare Funktion | `149_ensemble_selection.R`, `analysis/multilayer_stack_test.R` |
| `group_resampling.R` | Group-aware Resampling für Aufgaben mit wiederholten Entitäten (Generalisierung auf NEUE Gruppen) | projektspezifisch (kein Default-Skript, opt-in) |
| `multilabel.R` | Multi-Label-Klassifikation (Binary Relevance + Metriken/Threshold-Tuning) | `021_multilabel_workflow.R` |
| `ordinal_qwk.R` | Ordinale Ziele als Regression + QWK-optimales Runden | projektspezifisch (kein Default-Skript, opt-in) |
| `config_validation.R` | `validate_config()` - frühe, verständliche Fehler bei falsch angepasster `000_config.R` | manuell nach Config-Anpassung |

## DB/Infra

| Datei | Zweck | Genutzt von |
|---|---|---|
| `db_housekeeping.R` | Rein lesende Diagnose der zentralen, gemergten Experiment-DB (Merge nötig? Duplikate? unvollständige Runs?) | `merge_project_experiments.R` |
| `merge_project_experiments.R` | Konsolidiert projekteigene `experiments.db`-Dateien mehrerer lokaler Projekte in eine zentrale DB | manuell aufgerufen |
| `generate_systematic_evaluation.R` | Erzeugt eine Projekt-x-Modul-Ergebnistabelle aus der Evidence Registry | manuell aufgerufen |
| `reproduce_publication_benchmark.R` | Eigenständige Reproduktion des berichteten 6-Datensatz-Benchmarks ohne `ML_Learning`-Abhängigkeit | manuell aufgerufen (Reproduzierbarkeitsnachweis) |

## Domain-Adapter (optional, kein Default)

Externe/optionale Datenquellen - bewusst nicht Teil der Kernpipeline, siehe
jeweiligen Kopfkommentar für Scope-Einschränkungen.

| Datei | Zweck | Genutzt von |
|---|---|---|
| `agridatasets_adapter.R` | Adapter für das optionale `agridatasets`-Paket (erzwingt explizite Join-Schlüssel) | `analysis/agridatasets_pilot.R` |
| `dwd_weather_adapter.R` | Adapter für lokal eingefrorene DWD-Wetterdaten (rückblickender as-of-Join) | projektspezifisch (`ML_Learning`) |
| `enrichment_trust_gate.R` | Zweidimensionales Stabilitäts-Gate (Seed x Split-Ratio) vor jeder "Anreicherung hilft/schadet"-Aussage; domänenneutral, aktuell nur von den DWD-Piloten genutzt | wiederverwendbar (bisher genutzt: `ML_Learning`) |

## Siehe auch

- `protocols/` - die ADR-008-eingefrorenen `outer_workflow_evaluation*.R`-Protokolle, die mehrere der obigen Bausteine (v.a. `class_multiplier_tuning.R`) verwenden.
- `WorkflowDescription.md` - Gesamtübersicht des nummerierten Kern-Workflows im Root.
- `TARGETS.md` - Hintergrund zu Testabdeckung/CI-Trennung, die diese Module absichert.
