# MLR3 Classification AutoML Prototype

Dieses Unterprojekt entwickelt eine wiederverwendbare AutoML-Struktur fuer Kaggle-Klassifikationsaufgaben mit `mlr3`.

Der aktuelle Datensatz stammt aus `playground-series-s6e7` und beschreibt Gesundheits- und Lifestyle-Merkmale. Zielvariable ist `health_condition` mit drei Klassen: `at-risk`, `unhealthy`, `fit`.

> **Einstieg / Kontext erfassen**: vor dem Deep-Dive in einzelne Skripte oder
> Phasen-Text zuerst [`WorkflowDescription.md`](WorkflowDescription.md) ansehen
> - dort steht ein Mermaid-Diagramm mit dem kompletten Ablauf inkl. aller
> Entscheidungspunkte (Metrik-Typ, Adversarial-Shift, Feature-Auswahl,
> Tuning-Verwerfung, Rescue-Rate-Falle, Neural-Gate). Gilt auch fuer eine
> KI-Session, die hier den Kontext erfassen soll: das Diagramm ist der
> guenstigste Einstiegspunkt, kompakter als 12 Phasen-Abschnitte oder
> Skript-Code einzeln zu lesen. Fuer automatisierte Agenten (Codex, Claude
> Code, etc.) siehe zusaetzlich [`AGENTS.md`](AGENTS.md) - u.a. die Pflicht,
> das Diagramm bei Aenderungen an der Ablauflogik mitzuziehen.

## Zielbild

Die Projektstruktur trennt bewusst mehrere Ebenen:

- `mlr3pipelines` beschreibt die Modell-Pipeline: Imputation, Faktorbehandlung, Encoding, Skalierung und Learner.
- Die nummerierten Skripte beschreiben den Workflow: Datenueberblick, Task-Erzeugung, Baselines, Feature Engineering, Kandidatenmodelle.
- `targets` (`_targets.R`) orchestriert den *finalen* Workflow (Task-Erzeugung bis Submission, siehe eigener Abschnitt), ersetzt aber nicht die `mlr3`-Pipelines und nicht die explorativen Einzel-Skripte zur Modellauswahl.
- Datenquellenspezifisches Feature Engineering bleibt austauschbar und liegt separat.

## Skriptstruktur

| Skript | Rolle |
|---|---|
| `000_config.R` | Zentrale Pfade, Zielspalte, Seed, Subset-Quote, Metriken, Modellbudgets |
| `005_benchmark_runtime.R` | Hilfsfunktion fuer Modellbenchmarking mit Laufzeitmessung |
| `006_tuning_diagnostics.R` | `diagnose_mbo_search()` - prueft nach `tnr("mbo")`-Laeufen auf echte sequenzielle Verfeinerung vs. reines Initialdesign, Plateau-Indikator |
| `008_curve_diagnostics.R` | Helferfunktionen fuer ROC-/PR-Kurven aus in `experiments.db` geloggten Vorhersagen (Schwellenwert-Sweep, AUC per Trapezregel); funktioniert bei >=3 Klassen als One-vs-Rest (siehe Notiz unten) |
| `010_eda.R` | Datenueberblick auf 10%-Subset mit `skimr` |
| `015_target_leak_audit.R` | Prueft eine zu gute Baseline auf Target-Leakage: Feature-Importance-Konzentration, Determinismus-Check (`P(Ziel\|Feature=Wert)`), optionale Within-Stratum-Zieltrennung, Ehrlich-vs-aufgeblasen-Zerlegung (mit/ohne Verdaechtige) - bewusst auf vollen Daten, kein Subset |
| `020_task.R` | Erzeugt den Rohfeature-`TaskClassif` |
| `025_feature_engineering.R` | Erzeugt je Feature-Familie (`features/*.R`) einen eigenen Task, den kombinierten Feature-Task (alle Familien) und den ausgewaehlten Feature-Task (Aktivitaet+Cardio+Schlaf) |
| `030_baseline.R` | Autarke Baseline mit LDA, Multinom und Ranger |
| `035_feature_baseline.R` | Dieselben Baseline-Modelle auf engineered Features |
| `036_feature_family_benchmark.R` | Vergleicht Roh-Task, jede Feature-Familie einzeln und den kombinierten Feature-Task (Holdout) |
| `037_selected_features_cv.R` | Bestaetigt die Familien-Auswahl per 5-facher Cross-Validation: LDA auf Rohfeatures, Multinom/Ranger auf Roh- vs. ausgewaehltem Feature-Set |
| `038_surrogate_guided_features.R` | Nutzt ein 5er-`rpart`-Ensemble als schnellen Interaktions-Scout, erzeugt daraus generische Produkt-/Ratio-/Differenzfeatures und prueft sie fuer Multinom/Liblinear auf einem getrennten Evaluation-Split |
| `040_preprocessing.R` | Wiederverwendbare `mlr3pipelines`-Bausteine |
| `050_pipeline_benchmark.R` | Benchmark der allgemeinen Preprocessing-Pipeline |
| `060_regularized_linear.R` | Regularisierte lineare Modelle mit `cv.glmnet` |
| `070_final_models.R` | Trainiert je Learner aus `model_feature_sets` das passende Feature-Set (inkl. Klassengewichtung aus `model_class_weight_power`) und speichert das finale Modell |
| `080_boosting_benchmark.R` | Vergleicht LightGBM gegen die Ranger-Referenz (Rohfeatures, native Faktoren, kein One-Hot, CV) |
| `081_xgboost_benchmark.R` | XGBoost separat (braucht One-Hot aus `040`), Vergleich gegen die `080`-Referenz |
| `090_ranger_tuning.R` | Random-Search-Tuning fuer Ranger (mtry.ratio, min.node.size, sample.fraction), Finalvergleich per CV |
| `095_tabpfn_benchmark.R` | Explorativer TabPFN-Vergleich auf einem CPU-vertraeglichen Mini-Subset (eigenes `tabpfn_subset_size`) |
| `100_lightgbm_tuning.R` | Bayesian-Optimization-Tuning fuer LightGBM (`mlr3mbo`), Finalvergleich per CV |
| `105_lightgbm_class_weights.R` | Vergleicht balancierte Klassengewichte (`power`-Stufen 0 bis 1) fuer LightGBM per CV, inkl. Konfusionsmatrizen |
| `110_lightgbm_feature_family_benchmark.R` | Wiederholt den Feature-Family-Vergleich (wie `036`) fuer LightGBM mit der aktuellen `class_weight_power`-Gewichtung |
| `115_adversarial_validation.R` | Prueft per Adversarial Validation, ob Train und Test unterscheidbar sind (AUC + Feature Importance); zusaetzlich ESS/n der OOF-Propensity-Gewichte (Reweighting-Machbarkeit) und optionale Stufen (`adversarial_staged_exclude`), die verdaechtige Feature-Gruppen ausschliessen, um die Shift-treibende Gruppe zu isolieren |
| `120_lightgbm_empty_string_preprocessing.R` | Vergleicht `""` behalten vs. `"" -> NA -> Imputation` fuer LightGBM (aktuelle `class_weight_power`-Gewichtung), per CV |
| `125_catboost_benchmark.R` | Vergleicht CatBoost gegen LightGBM (beide mit aktueller `class_weight_power`-Gewichtung, Rohfeatures, CV) |
| `130_threshold_tuning.R` | Sucht post-hoc Klassengewichte auf den Wahrscheinlichkeiten (`argmax(prob * weight)`, `class_multiplier_tuning.R`: Grid-Startpunkt + geschlossene `1/prior`-Korrektur + kontinuierliche Nelder-Mead-Verfeinerung) auf einem Tune-Split, vergleicht mit `class_weight_power` |
| `135_lightgbm_class_weight_power_extended.R` | Setzt die `power`-Kurve aus `105` ueber 1 hinaus fort, findet das innere BAcc-Maximum |
| `140_ensemble_candidates_weighted.R` | Vergleicht LightGBM, Ranger und XGBoost mit derselben `power=1.5`-Gewichtung (CV) |
| `142_ranger_tuning_weighted.R` | Wiederholt `090` auf dem `power=1.5`-gewichteten Task (Random Search), Finalvergleich per CV |
| `145_ensemble_ranger_lightgbm.R` | Gleichgewichtetes Wahrscheinlichkeits-Ensemble (`gunion()` + `po("classifavg")`) aus Ranger und LightGBM |
| `146_threshold_tuning_ranger.R` | Wiederholt `130` fuer Ranger statt LightGBM (Probability-Forest-Wahrscheinlichkeiten statt Log-Loss-optimierter Wahrscheinlichkeiten) |
| `147_error_analysis_ranger_models.R` | Trainiert Ranger/LightGBM/LDA auf dem Holdout-Split EINMAL, speichert Modelle+Vorhersagen als Artefakt (`error_analysis_models_path`), loggt vollstaendig (alle Eval-Zeilen) nach `experiments.db` - Basis fuer `160`/`161` und die folgenden Skripte |
| `147_error_analysis_ranger_confidence.R` | Laedt das Modelle-Artefakt (kein erneutes Training): Konfidenz-/Rescue-Rate-Analyse, "alle Modelle einig falsch"-Faelle, speichert Zeilen-Indizes als Artefakt (`error_analysis_indices_path`) |
| `147_error_analysis_ranger_isolation_forest.R` | Laedt Modelle+Indizes-Artefakte: Isolation-Forest-Ausreissercheck auf den "einig falsch"-Faellen |
| `147_error_analysis_ranger_kernelshap.R` | Laedt Modelle+Indizes-Artefakte: KernelSHAP-Fehleranalyse (welche Features treiben Ranger in die falsche Klasse?) |
| `147_error_analysis_ranger_tabpfn.R` | Laedt Modelle+Indizes-Artefakte: TabPFN-Vergleich auf den "interessanten" Zeilen (CPU-Kontextlimit) |
| `150_train_full_model.R` | Trainiert `submission_model_name` (aktuell Ranger, Rohfeatures, `power=1.5`) auf dem vollen Trainingsdatensatz. Jede Modell-Datei ist an eine `run_id` gebunden (kein fixer Dateiname, siehe `final_model_full_path()`) und wird als `model_artifact_path`-Hyperparameter in `experiments.db` geloggt |
| `155_predict_submission.R` | Findet den Pfad des zuletzt trainierten Modells ueber `db_get_latest_model_artifact_path()`, wendet es auf `test.csv` an und schreibt `submission.csv` im Format von `sample_submission.csv`. Metrik-abhaengig: bei schwellenwert-unabhaengiger Zielmetrik (AUC/LogLoss) + binaerer Aufgabe wird `P(positive_class)` geschrieben, sonst Klassen-Labels |
| `160_plot_roc_curve.R` | ROC-Kurve(n) je Algorithmus aus den in `experiments.db` geloggten Vorhersagen, als PNG gespeichert, AUC-Cross-Check gegen `metric_result` |
| `161_plot_pr_curve.R` | Precision-Recall-Kurve(n) je Algorithmus, analog zu `160` |

## `targets`-Pipeline (`_targets.R`)

> **Ausfuehrliche Anleitung**: siehe [`TARGETS.md`](TARGETS.md) - Grundkonzepte, Befehlsuebersicht, ein durchgerechnetes Beispiel und eine Checkliste fuer die Uebertragung auf einen neuen Wettbewerb.
> Fuer eine ausfuehrlichere, Schritt-fuer-Schritt-Fassung dieser Checkliste
> (Beispielbefehle, erwartete Ausgaben, Entscheidungsregeln je Phase - auch
> ohne KI-Unterstuetzung nachvollziehbar) siehe [`WorkflowDescription.md`](WorkflowDescription.md).
> Fuer Probability-Challenges mit LogLoss/Brier-Anteil siehe ausserdem
> [`REFERENZ_PROBABILITY_CALIBRATION.md`](REFERENZ_PROBABILITY_CALIBRATION.md):
> OOF-Kalibrierung, Platt-Scaling und die Fairness-Regel "lokal validieren,
> einmal bestaetigen, dann keine Mikrovarianten ans Leaderboard schicken".
> Fuer neuronale Tabellenmodelle (FT-Transformer) als Ensemble-Diversitaet siehe
> [`NEURAL_DEPLOY.md`](NEURAL_DEPLOY.md): R-only-Policy, wann sich ein neuronales
> Modell lohnt, und der Python-GPU-Export-Workflow fuer Kaggle.

Die nummerierten Skripte `020`/`025`/`070`/`150`/`155` bilden zusammen den *finalen* Workflow: Rohtask erzeugen, Feature-Familien bauen, Modelle auf dem 10%-Subset trainieren, das finale Modell auf dem vollen Datensatz trainieren, Submission schreiben. Bisher musste man dafuer die richtige Reihenfolge kennen und jedes Skript manuell erneut anstossen, wenn sich z.B. `class_weight_power` in `000_config.R` aenderte (jedes Skript prueft nur "existiert die Datei schon", nicht "ist sie noch aktuell").

`_targets.R` bildet genau diesen Workflow als expliziten, cachenden Abhaengigkeitsgraphen ab (`targets`-Paket):

- `train_raw`/`train_full` laden `train.csv` (getrennt fuer Subset- bzw. volles Training).
- `task_family` ist ein **dynamisch verzweigtes** Ziel (`pattern = map(feature_family_name)`) - baut automatisch einen Task pro Eintrag in `feature_families`, ohne den Code pro Familie zu wiederholen.
- `task_raw`/`task_combined`/`task_selected` entsprechen den Roh-/Kombinierten/Ausgewaehlten Tasks aus `025`.
- `final_model_subset` verzweigt ebenso ueber `model_name` (alle Eintraege aus `model_feature_sets`) und entspricht `070`.
- `task_full`/`task_full_weighted`/`final_model_full` entsprechen `150`, `submission` entspricht `155`.

**Nutzung**:
```r
targets::tar_make()          # Pipeline ausfuehren (baut nur veraltete/fehlende Ziele neu)
targets::tar_visnetwork()    # Abhaengigkeitsgraphen interaktiv anzeigen
targets::tar_manifest()      # Zielliste ohne Ausfuehrung pruefen
targets::tar_read(final_model_full)  # Ein bestimmtes Ziel aus dem Cache laden
```

Aendert sich z.B. `class_weight_power` in `000_config.R`, erkennt `tar_make()` beim naechsten Aufruf automatisch, dass `task_full_weighted` und alles Nachgelagerte (`final_model_full`, `submission`) veraltet sind, und baut nur diese neu - `task_family`/`task_combined` (die nicht von `class_weight_power` abhaengen) bleiben unveraendert im Cache.

**Bewusst nicht in `targets` uebernommen**: die explorativen Einzel-Skripte `030`-`145`. Die dienten der Modellauswahl (welches Modell, welche Gewichtung, welche Feature-Familie) und sind eher Analysewerkzeuge fuer eine einmalige Entscheidungsfindung als Teil einer wiederholbaren Produktions-Pipeline - sie bleiben als eigenstaendige Skripte und als Vorlage fuer die *Methodik* (wie man Klassengewichte testet, wie man Adversarial Validation aufsetzt, etc.), wenn ein neuer Klassifikationsaufgaben-Workflow dieselben Fragen erneut beantworten muss.

**Fuer einen neuen Klassifikationsaufgaben-Workflow** (siehe auch "Modularitaet" oben) reduziert `targets` den Umstellungsaufwand: man aendert `000_config.R` (Metrik, Spalten, `model_feature_sets`/`model_class_weight_power`) und `features/*.R`, ruft `tar_make()` auf - der Abhaengigkeitsgraph selbst (welches Ziel von welchem abhaengt) bleibt strukturell gleich, muss also nicht neu durchdacht werden.

## Experiment-Tracking (SQLite)

> **Ausfuehrliche Anleitung**: siehe [`EXPERIMENTS_DB.md`](EXPERIMENTS_DB.md) - Schema im Detail, ER-Diagramm, Namenskonvention, Logging-Code-Walkthrough und eine Query-Sammlung.

Alle explorativen Skripte (`030`-`145`) schreiben ihre Ergebnisse zusaetzlich zu den bisherigen CSV-Exporten in eine normalisierte SQLite-Datenbank (`_artifacts/experiments.db`, Pfad in `experiments_db_path`, `000_config.R`). Ziel: mehr Daten festhalten als das, was auf der Konsole ausgegeben wird (Pro-Fold-Werte statt nur Mittelwert, alle Hyperparameter, Preprocessing- und Feature-Set-Wahl als eigene Spalten), damit sich zukuenftige Optimierungsentscheidungen direkt per SQL statt per README-Gedaechtnis treffen lassen - auch fuer Claude in einer neuen Session.

Kernidee des Schemas (`db_schema.sql`): `project` → `workflow` → `run` (ein Skriptdurchlauf mit Seed/Git-Commit) → `model_config` (Algorithmus, Feature-Set, Preprocessing, Klassengewicht) → `hyperparam` + `metric_result` (aggregiert **und** pro CV-Fold). Vier Views (`v_model_results`, `v_fold_detail`, `v_run_summary`, `v_best_per_algorithm`) decken die haeufigsten Abfragen ab, z.B.:

```sql
-- Bestes Modell je Algorithmus, ueber alle Skripte/Runs hinweg
SELECT * FROM v_best_per_algorithm ORDER BY bacc DESC;
```

Die Datenbank ist rein additiv und projektunabhaengig aufgebaut (kein Bezug zu `health_condition` oder den drei Klassen im Schema) - fuer einen neuen Kaggle-Wettbewerb reicht ein neuer `project_name` in `000_config.R`, Schema und `db_logging.R` bleiben unveraendert. `_targets.R` schreibt aktuell **nicht** in die Datenbank (Details siehe `EXPERIMENTS_DB.md`, Abschnitt "Bekannte Einschraenkung").

In der Praxis bekommt jedes uebertragene Projekt zunaechst seine eigene lokale `experiments.db`. Nach Projektabschluss konsolidiert `merge_project_experiments.R` die aggregierten Tabellen (nicht die Zeilenebene, siehe `EXPERIMENTS_DB.md`) in diese zentrale Template-DB - Stand jetzt enthaelt sie `health_condition`, `s6e5` (Pit-Stop), `s6e6` (Stellar Class) und `s5e12` (Diabetes), abfragbar ueber `proj_name`.

## Bewertungsmetriken

Wir verwenden aktuell:

- Balanced Accuracy (`classif.bacc`)
- Matthews Correlation Coefficient (`classif.mcc`)

Accuracy wurde bewusst nicht als Hauptmetrik gewaehlt, weil die Zielvariable unausgewogen ist. Im 10%-Subset liegt `at-risk` bei ca. 86%.

## Target-Leakage-Audit

`015_target_leak_audit.R` prueft, BEVOR man in Baselines/Feature Engineering investiert, ob eine (spaetere) zu gute Baseline auf einen Leak statt auf echtes Signal zurueckgeht. Anlass: `CreditScoringChallenge` (African Credit Scoring, ~1.8% positive Klasse) - eine naive Baseline erreichte dort F1 0.88, getrieben durch einen Ex-post-Leak (`interest_ratio`, ein Feature, das erst nach der Kreditvergabe bekannt ist). Nach Bereinigung sank der ehrliche Wert auf F1 ~0.41, extern am Leaderboard fast exakt bestaetigt (0.4191). **Wichtig**: CV<->Leaderboard-Uebereinstimmung faengt einen Leak NICHT - das Artefakt steckt meist auch in den Testdaten, ein Leak taeuscht also konsistent hohe CV- UND LB-Werte vor.

Vier automatisierte Schritte (bewusst auf **vollen** Daten, kein Subset - Determinismus-/Stratum-Befunde brauchen Volumen, sonst droht dieselbe Screening-Falle wie bei exact-value Target-Encoding):

1. **Feature-Importance-Konzentration**: ein LightGBM-Fit, traegt ein einzelnes Feature `> leak_audit_importance_share_threshold` (Default 50%) der Gain-Importance?
2. **Determinismus**: fuer Spalten mit ueberschaubarer Kardinalitaet, `P(Ziel=Klasse | Feature=Wert)` - liegt ein Wert bei (nahezu) 100% Reinheit mit ausreichend grosser Gruppe (`leak_audit_determinism_min_n`)?
3. **Within-Stratum-Zieltrennung** (optional, `leak_audit_stratify_cols`): trennt ein verdaechtiges numerisches Feature die Zielklassen sogar INNERHALB einer eigentlich neutralen Kategorie? Braucht projektspezifisches Wissen, welche Spalte "neutral" sein sollte - ohne Konfiguration uebersprungen.
4. **Ehrlich-vs-aufgeblasen-Zerlegung**: gepaarter Holdout-Split, Zielmetrik (`baseline_measure_ids`) mit vs. ohne die Verdaechtigen aus Schritt 1+2.

**Schritt 5 (Verfuegbarkeit zur Entscheidungszeit)** ist bewusst NICHT automatisiert - das Skript listet die Verdaechtigen und die Leitfragen (ex-ante vs. ex-post bekannt? nur definitorisch mit dem Ziel gekoppelt?), das Urteil bleibt fachlich.

**Ergebnis am Template-eigenen Projekt** (`health_condition`, volle 690088 Zeilen):

| Feature | Gain-Share |
|---|---:|
| stress_level | 42.9% |
| sleep_duration | 34.8% |
| physical_activity_level | 16.1% |
| bmi | 2.0% |
| (9 weitere) | < 1% je |

Kein einzelnes Feature ueberschreitet die 50%-Schwelle, keine Wert-Gruppe zeigt exakten Determinismus (`n>=30`) - Audit unauffaellig, Zerlegung (Schritt 4) entsprechend uebersprungen. Bemerkenswert bleibt, dass `stress_level` und `sleep_duration` zusammen bereits ~78% der Gain-Importance tragen - kein Leak-Befund, aber ein Hinweis, dass die meisten anderen Features fuer LightGBM kaum Zusatzsignal liefern (deckt sich mit dem Feature-Family-Benchmark oben).

**Cross-Projekt-Bestaetigung (2026-08-05, PumpItUp + geoai-aquaculture, 2. und 3. Bestaetigungsprojekt):** Der Guard wurde auf zwei reale (nicht-synthetische), externe Projekte aus unterschiedlichen Domaenen angewandt - beide korrekt unauffaellig:

| Projekt | Plattform | Zeilen | Top-Feature (Gain-Share) | Befund |
|---|---|---:|---|---|
| PumpItUp (Wasserpumpen, 3 Klassen/Accuracy) | DrivenData | 59400 | `ward` 28.5% | kein Leak |
| geoai-aquaculture (Fernerkundung, binaer/AUC+Fbeta) | Zindi | 1822 | `re3_08` 27.5% | kein Leak |

Diese zweite/dritte Bestaetigung deckte zwei generische Luecken auf, die am Template-eigenen (rein synthetischen) Projekt nie sichtbar wurden und jetzt behoben sind:

- **Datumsspalten** (`Date`/`IDate`/`POSIXct`, z.B. aus `fread()`) liess `as_task_classif()` bisher abstuerzen ("Must be a subset of..."). Jetzt werden sie numerisch konvertiert (Tage/Sekunden seit Epoch) statt fallengelassen - ein Datum kann selbst leak-relevant sein (z.B. "erfasst am" nach dem Ausgang), PumpItUps `date_recorded` bestaetigt das (2.5e-3 Gain-Share, unauffaellig aber mitgeprueft).
- **Rein kontinuierliche Feature-Saetze** (z.B. geoais 144 Spektralindizes ohne jede Spalte `<= leak_audit_cardinality_max`) liessen Schritt 2 abstuerzen (`rbindlist(list())` erzeugt eine spaltenlose Tabelle). Jetzt expliziter Kurzschluss mit Hinweistext statt Absturz.
- Ausserdem generalisiert: `enable_class_stratification()` (aus `000_config.R`) ist keine harte Abhaengigkeit mehr - das Skript setzt die Stratum-Rolle jetzt direkt, laeuft also auch in aelteren Projekt-Kopien ohne diesen Helfer (PumpItUp/geoai hatten ihn nicht).

## Baseline-Ergebnisse

Die Roh-Baseline laesst leere Strings in kategorialen Features als eigene Faktorstufe bestehen.

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| LDA | 0.8425 | 0.7801 | 3.88 s |
| Multinom | 0.8484 | 0.8094 | 12.14 s |
| Ranger | 0.8657 | 0.8632 | 34.35 s |

Ranger ist aktuell der beste Baseline-Referenzpunkt im Verhaeltnis aus Metrik und Laufzeit.

## Preprocessing-Erkenntnis: Leere Strings

In einigen kategorialen Spalten treten leere Strings `""` auf. Zwei Strategien wurden beobachtet:

| Strategie | Bedeutung | Beobachtung |
|---|---|---|
| `""` als eigene Kategorie behalten | Modell darf Missing-artige Werte als Signal lernen | In der Roh-Baseline staerker |
| `"" -> NA -> Imputation` | Klassische Missing-Value-Behandlung in `mlr3pipelines` | Etwas schwaechere Scores |

Interpretation: Die leeren Strings koennen selbst Signal tragen. Fuer AutoML sollten beide Strategien als Preprocessing-Kandidaten behandelbar bleiben.

## Pipeline-Benchmark

Die allgemeine Pipeline aus `040_preprocessing.R` macht:

```text
empty_factor_to_na -> imputemedian -> imputemode -> fixfactors
```

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| LDA | 0.8394 | 0.7737 | ca. 4-5 s |
| Multinom | 0.8218 | 0.7897 | ca. 13 s |
| Ranger | 0.8558 | 0.8599 | ca. 49 s |

Diese Pipeline ist konzeptionell sauberer, aber nicht automatisch besser. Besonders die Behandlung von `""` als `NA` kostet hier vermutlich Signal.

## Feature Engineering

Die Feature-Funktionen liegen nach Familie getrennt in `features/*.R` (je eine Funktion `add_<familie>_features()`), damit jede Familie unabhaengig einen eigenen Task erzeugen und benchmarken kann:

- BMI (`features/bmi.R`): `bmi_category`
- Schlaf (`features/sleep.R`): `sleep_deficit_7h`, `sleep_excess_9h`, `sleep_distance_from_8h`
- Aktivitaet (`features/activity.R`): `steps_per_exercise_min`, `calories_per_step`, `calories_per_exercise_min`, `steps_per_sleep_hour`, `exercise_per_sleep_hour`
- Hydration (`features/hydration.R`): `water_per_1000_calories`, `water_per_exercise_min`
- Cardio (`features/cardio.R`): `heart_rate_per_bmi`, `cardio_strain_proxy`, `calories_per_bmi`
- Interaktionen (`features/interactions.R`): `stress_sleep_quality`, `activity_smoking_alcohol`, `diet_activity`

`025_feature_engineering.R` speichert sowohl je einen Task pro Familie (`task_train_small_features_<familie>.rds`) als auch den kombinierten Task mit allen Familien (`task_train_small_features.rds`, weiterhin von `035`/`050`/`060` verwendet). Feature Engineering erhoeht den kombinierten Task von 13 auf 30 Features.

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| LDA + Features | 0.8045 | 0.7131 | ca. 11 s |
| Multinom + Features | 0.8424 | 0.7939 | ca. 42 s |
| Ranger + Features | 0.8729 | 0.8638 | ca. 78 s |

Erkenntnis: LDA verschlechtert sich deutlich und meldet Kollinearitaet. Ranger profitiert leicht. Die engineered Features sind daher kein Standardpfad, sondern eine experimentelle Feature-Familie.

### Optionales Modul: leak-sicheres Target-Encoding (`features/target_encoding.R`)

Fuer hochkardinale kategoriale Spalten, die sonst gedroppt oder grob per `collapsefactors` zusammengefasst werden muessten (z.B. `Driver` mit 887 Leveln in `playground-series-s6e5`, `native.country` mit 41 in `openml-adult-income`), bietet `features/target_encoding.R` ein **optionales** leak-sicheres Target-(Impact-)Encoding auf Basis von `mlr3pipelines::po("encodeimpact")`:

- **`build_target_encoding_po(affect_cols, smoothing)`** - der reine Encoding-PipeOp (mit `impute_zero = TRUE` fuer Robustheit gegen im Trainings-Fold ungesehene Level).
- **`build_target_encoded_pipeline(base_learner, affect_cols, smoothing)`** - kompletter GraphLearner: Imputation -> Target-Encoding -> Learner.

**Leak-sicher** auf CV-Fold-Ebene (der PipeOp fittet die Impact-Tabelle nur auf den Trainingszeilen jedes Folds), **multiclass-faehig** (k numerische Spalten je Faktor, eine je Klasse - weit sparsamer als One-Hot bei hoher Kardinalitaet).

**Kein Default - Entscheidungsregel** (A/B an `openml-adult-income`, `036_target_encoding_benchmark.R`, 5-fache CV, jeweils vs. natuerliche Baseline):

| Fall | Empfehlung |
|---|---|
| Lineare Modelle (LDA/Multinom/glmnet) bei hoher Kardinalitaet (One-Hot unpraktikabel) MIT Signal | **Target-Encoding** - der klare Gewinnfall: macht das Modell ueberhaupt erst anwendbar und erreicht starke Werte (siehe Amazon-Beleg unten) |
| Lineare Modelle, moderate Kardinalitaet | **Target-Encoding** - besser bei LogLoss/AUC und ~2x schneller als One-Hot |
| Baummodelle mit nativem Kategorien-Handling (LightGBM/Ranger), echte Kategorien mit stabiler Laufzeit | **native Faktoren zuerst testen** - schlaegt Target-Encoding selbst bei extremer Kardinalitaet (Amazon: LightGBM nativ 0.869 vs. bestes TE 0.847); TE bringt nichts und ist deutlich langsamer |
| Hochkardinale ID-Codes, besonders numerisch codierte Geo-/Objekt-IDs | **Frequency-Encoding als schnellen A/B-Kandidaten testen** - zielwertfrei, leakage-arm und oft viel guenstiger als native riesige Faktoren |
| Hohe Kardinalitaet OHNE Signal | **Spalte weglassen** - Target-Encoding kann kein Signal erzeugen (siehe Warnung unten) |
| XGBoost, moderate Kardinalitaet | One-Hot gewinnt knapp bei Genauigkeit, Target-Encoding ist aber deutlich schneller |

**Frequency-Encoding als Zwischenweg vor Target-Encoding.** `drivendata_richter` bestaetigte einen praktischen Sonderfall: `geo_level_2_id`/`geo_level_3_id` waren eigentlich kategoriale IDs, aber als Faktoren machten sie Ranger bereits auf 10% der Daten unhandlich. Als numerische Codes plus Frequency-Features stieg die 5-fache CV deutlich (Ranger Accuracy 0.7021 -> 0.7154, LightGBM 0.7015 -> 0.7097). Das Leaderboard bestaetigte die Richtung: LightGBM `geo_frequency` 0.7336, Ranger `geo_frequency` 0.7495 (Rang 437), jeweils ohne Target-Encoding. Lektion: Bei hochkardinalen ID-Spalten nicht sofort auf Target-Encoding springen; zuerst eine zielwertfreie Frequency-Variante gegen die native/numerische Baseline testen.

**Wichtige Einschraenkung - Target-Encoding erzeugt kein Signal, es macht vorhandenes nur nutzbar.** Ob TE hilft, haengt davon ab, ob die Spalte ueberhaupt Signal traegt, NICHT nur von der Kardinalitaet. Demonstriert an `playground-series-s6e5`s `Driver` (887 Level, `037_target_encoding_driver.R`): Driver wurde urspruenglich gedroppt, TE macht ihn mechanisch nutzbar (LDA nutzt 2 TE-Spalten statt eines unmoeglichen 887-fach-One-Hot, laeuft sauber/leak-sicher), aber es HILFT nicht - AUC faellt leicht (LDA 0.8425 gedroppt -> 0.8410 TE; LightGBM 0.9403 -> 0.9372 TE; LightGBM mit Driver NATIV sogar 0.9229). Driver traegt schlicht kaum Signal fuer `PitNextLap` - kein Encoding kann das aendern. Das validiert zugleich die urspruengliche "Driver weglassen"-Entscheidung. Faustregel: bei einer hochkardinalen Spalte vor dem TE-Aufwand kurz pruefen, ob sie ueberhaupt diskriminiert (z.B. via Adversarial-/Feature-Importance oder einem schnellen native-LightGBM-Test).

**Zweite wichtige Einschraenkung - `smoothing` ist ein kritischer, modell- UND kardinalitaetsabhaengiger Parameter, kein Set-and-Forget.** Demonstriert am kanonischen Target-Encoding-Datensatz `openml-amazon-access` (9 all-hochkardinale Kategorien, RESOURCE 7518 / MGR_ID 4243 Level, One-Hot ~15.600 Spalten - voellig unpraktikabel, `036`/`037`): der TE-AUC schwankt allein durch die Glaettung massiv (LightGBM+TE Holdout: `smoothing=1` -> 0.847, aber `smoothing=20` -> 0.779; glmnet+TE: `smoothing=0.1` -> **0.854**, `smoothing=20` -> 0.715). Das Optimum ist modellabhaengig (glmnet ~0.1, LightGBM ~1) - **einen Wert unbesehen zu uebernehmen ist riskant, die Glaettung gehoert gesweept**. Die Kernbotschaften dieses Datensatzes:
- **TE-Gewinnfall bestaetigt (linear + extreme Kardinalitaet)**: glmnet erreicht mit guter Glaettung 0.854 AUC - praktisch gleichauf mit dem besten Baummodell - auf Daten, wo ein lineares Modell ohne TE gar nicht laufen koennte (One-Hot unmoeglich). Das ist der eigentliche Zahltag.
- **GBM-natives Handling schlaegt TE**: LightGBM nativ (0.869) uebertrifft selbst optimal geglaettetes TE (0.847) UND ist ~5x schneller (35s vs. ~190s). Fuer Modelle mit nativem Kategorien-Handling lohnt TE also selbst bei extremer Kardinalitaet nicht - der "Amazon = TE-Klassiker"-Ruf bezieht sich auf aufwaendigere, getunte Multi-Encoding-Ansaetze, nicht auf ein einzelnes generisches Impact-Encoding.

Robustheits-Nebenbefund: Target-Encoding mit `impute_zero=TRUE` war im A/B das einzige Encoding, das unter CV ohne zusaetzliche Absicherung durchlief - One-Hot (via `fixfactors`) und `collapsefactors` stuerzten an einem seltenen, per CV nur im Validierungs-Fold auftretenden Level ab. Details siehe `openml-adult-income/TEMPLATE_FRICTION.md` #3.

### Optionales Modul: Exact-value Target-Encoding fuer NUMERISCHE Spalten

Ergaenzt `features/target_encoding.R` um `build_exact_value_te_graph()` /
`build_exact_value_te_pipeline()`. Bei **synthetischen** Datensaetzen (v.a.
Kaggle Playground) resampelt der Generator oft aus endlichem Support, sodass
sich auch numerische Werte stark wiederholen und wie eine hochkardinale
Kategorie wirken. Der Helfer behandelt die uebergebenen Spalten als solche
(numerisch-als-Faktor + `encodeimpact`) und fuegt ihre Impact-Kodierung als
**zusaetzliche** Features hinzu (Originale bleiben erhalten). Leak-sicher pro
CV-Fold, generisch fuer binaer und multiclass.

**Herkunft und Bestaetigung (2 unabhaengige Projekte)**: Kaggle-s6e7-4th-place-
Loesung (XGBoost OOF 0.9489 -> 0.9496), zweite Bestaetigung an
`playground-series-s6e8` (Smartphone Addiction, binaer/AUC): CV +0.0044 AUC,
**Leaderboard 0.96353 -> 0.96731 (+0.0038)** — der CV-Gewinn trug fast exakt
aufs Leaderboard durch.

**VORBEDINGUNG vor Aktivierung**: pruefen, dass die Werte tatsaechlich stark
wiederholen (z.B. `uniq_frac` je Spalte klein, jeder Wert mit vielen
Beobachtungen) — sonst ist jeder Wert quasi-eindeutig und das Encoding erzeugt
reines Overfitting statt Signal.

**Screening-Falle (live bestaetigt, `s6e8`)**: Per-Wert-Statistiken brauchen
Volumen. Dieselbe Pipeline gab auf einem 30k-Zeilen-Screen **-0.0027 AUC**
(Vorzeichen negativ), auf 138k **+0.0025 AUC** (positiv) — nur die Datenmenge
entschied ueber Nutzen/Schaden. **Regel: hochkardinale/statistik-basierte
Features NIEMALS auf einem Zeilen-Subset screenen** — zum Verbilligen Folds
oder Epochen reduzieren, nicht Zeilen. Das gilt fuer Target-/Frequency-
Encoding und alles, was auf hochkardinalen Zaehlungen beruht.

### Optionales Modul: Entitaets-Zeit-Historie (`features/entity_history.R`)

Fuer **Panel-/Forecasting-Daten** (dieselbe Entitaet — z.B. Kunde, Ort — mit
mehreren Zeilen ueber Zeit) bietet `features/entity_history.R` einen generischen,
zeit-respektierenden Historie-Helper `add_entity_history()`. Er aggregiert je
Entitaet nur VERGANGENE Ereignisse (strikt vor der Zeit der aktuellen Zeile); die
Target-Historie zaehlt nur vergangene GELABELTE Ereignisse (Test-Prioren haben
`target = NA`). Dadurch **leak-frei by construction** und exakt die Test-Situation
gespiegelt.

Erzeugt: `n_prior`, `time_since_last`, je Wert `prior_<v>_last/_mean/_mean_w{k}`,
`ratio_<v>_to_prior`; bei Target zusaetzlich `prior_target_rate(_w{k})`,
`prior_target_ever`, `time_since_last_positive`.

**Kein Default — nur fuer Panel-/Forecasting-Daten**, nicht fuer i.i.d.-Tabellen.
Rueckgefuehrt aus zwei unabhaengigen Faellen (geoai-drought Regression
"legal-history"; african-credit-scoring Kunden-Default-Historie, wo
`prior_default_rate` das dominante leak-freie Signal war und das Threshold-Tuning
die Klassengewichtung subsumierte).

**Anwendbarkeit zuerst pruefen** — dass die Daten wirklich Panel sind (Entitaets-
Duplikate mit Zeit-/Ziel-Variation). Manche Datensaetze sehen panel-faehig aus
(Entitaets-ID + Datum), sind aber querschnittlich (jede Entitaet einmal), dann ist
der Helper wirkungslos (Beleg: `drivendata-pump-it-up`, per Duplikat-Check verworfen).

### Optionales Modul: ordinale Ziele + Quadratic Weighted Kappa (`ordinal_qwk.R`)

Fuer **ordinale Ziele** (geordnete Klassen, z.B. Ratings) mit einer nicht-
zerlegbaren, ordnungssensitiven Metrik (**QWK**) - ein Fall, den Multiclass falsch
behandelt (ignoriert die Ordnung). `ordinal_qwk.R` bietet:
- **`qwk(truth, response)`** - Quadratic Weighted Kappa (quadratische Gewichte).
- **`optimize_ordinal_thresholds(pred, truth, levels)`** / `apply_ordinal_thresholds()`
  - der bewaehrte Ansatz: das Ziel als **Regression** vorhersagen und die
  kontinuierliche Ausgabe **QWK-optimal in ordinale Klassen runden** (Schnittpunkte
  per Nelder-Mead auf -QWK gesucht).

**Kernlektion (playground-s3e5 wine-quality):** bei nicht-zerlegbaren Metriken auf
die ECHTE Metrik optimieren, nicht auf einen bequemen Proxy - QWK-naiv-gerundetes
Tuning, MSE-basierte `cv_glmnet`-lambda-Wahl und MSE-Stacking fuehrten alle in die
Irre. Regression+QWK-Runden schlug Multiclass (0.526 vs 0.469); SVR war auf den
kleinen, dichten, numerischen Daten der staerkste Learner. Optionaler Baustein,
vom Standard-Workflow nicht gesourct (rueckwirkungsfrei).

## Feature-Family-Benchmark

`036_feature_family_benchmark.R` vergleicht den Roh-Task, jede Feature-Familie einzeln und den kombinierten Feature-Task mit denselben drei Baseline-Modellen:

| Task | LDA BAcc | LDA MCC | Multinom BAcc | Multinom MCC | Ranger BAcc | Ranger MCC |
|---|---:|---:|---:|---:|---:|---:|
| Roh | 0.8425 | 0.7801 | 0.8484 | 0.8094 | 0.8657 | 0.8632 |
| + BMI | 0.8394 | 0.7918 | 0.8473 | 0.8138 | 0.8643 | 0.8647 |
| + Schlaf | 0.8398 | 0.7636 | 0.8660 | 0.8177 | 0.8685 | 0.8609 |
| + Aktivitaet | 0.8475 | 0.7782 | 0.8592 | 0.8181 | 0.8714 | 0.8673 |
| + Hydration | 0.8357 | 0.7760 | 0.8423 | 0.8017 | 0.8547 | 0.8528 |
| + Cardio | 0.8380 | 0.7854 | 0.8468 | 0.8113 | 0.8711 | 0.8698 |
| + Interaktionen | 0.7885 | 0.6493 | 0.8431 | 0.8020 | 0.8722 | 0.8654 |
| Kombiniert (alle Familien) | 0.7951 | 0.7076 | 0.8270 | 0.7944 | 0.8670 | 0.8608 |

Erkenntnis: Fuer Ranger bringt fast jede Familie einzeln einen kleinen Vorteil gegenueber der Roh-Baseline (v.a. Aktivitaet und Cardio), die Kombination aller Familien ist aber nicht besser als die staerksten Einzel-Familien. Bei LDA schadet vor allem die Interaktionen-Familie deutlich (Kollinearitaet durch die `str_c`-Kategorien), waehrend Multinom von Schlaf und Aktivitaet einzeln staerker profitiert als vom kombinierten Feature-Set. Das bestaetigt, dass "alle Features kombinieren" kein Freifahrtschein ist — einzelne Familien lohnt es sich, separat gegen Kandidatenmodelle zu testen.

**Vorsicht bei der Interpretation:** Die obige Tabelle basiert auf einem einzelnen Holdout-Split (`validation_ratio = 0.80`). Unterschiede von unter ca. 1 Prozentpunkt zwischen aehnlich guten Familien sind Rauschen dieses einen Splits, kein belastbarer Beweis. Siehe naechster Abschnitt.

## Cross-Validation: Ausgewaehltes Feature-Set

Um die Holdout-Ergebnisse gegenzupruefen, vergleicht `037_selected_features_cv.R` mit 5-facher Cross-Validation (`cv_folds` in `000_config.R`):

- LDA auf Rohfeatures (LDA reagiert empfindlich auf Kollinearitaet, bleibt daher bewusst ohne engineered Features).
- Multinom und Ranger auf Rohfeatures **und** auf einem ausgewaehlten Feature-Set aus den drei staerksten Familien (Aktivitaet + Cardio + Schlaf).

| Task | Modell | BAcc | MCC | Laufzeit |
|---|---|---:|---:|---:|
| Rohfeatures | LDA | 0.8389 | 0.7798 | 10.4 s |
| Rohfeatures | Multinom | 0.8462 | 0.8084 | 49.6 s |
| Rohfeatures | Ranger | 0.8610 | 0.8601 | 161.8 s |
| Aktivitaet+Cardio+Schlaf | Multinom | 0.8653 | 0.8253 | 81.2 s |
| Aktivitaet+Cardio+Schlaf | Ranger | 0.8569 | 0.8596 | 279.3 s |

Erkenntnis: Unter CV bestaetigt sich der Multinom-Vorteil aus dem Holdout-Vergleich (BAcc +1.9, MCC +1.7 Prozentpunkte gegenueber Rohfeatures) — Schlaf und Aktivitaet liefern hier ein echtes, robustes Signal. Fuer Ranger dreht sich das Bild dagegen um: Die Kombination liegt unter CV leicht **unter** der Roh-Baseline (BAcc -0.4 Punkte, MCC praktisch gleich). Der im Holdout beobachtete Ranger-Vorteil einzelner Familien war also groesstenteils Rauschen eines einzelnen guenstigen Splits, kein robuster Effekt. Empfehlung: LDA und Ranger auf Rohfeatures belassen, nur Multinom auf dem Aktivitaet+Cardio+Schlaf-Set trainieren.

## Surrogate-guided Feature Engineering

Neben den fachlich motivierten `domain_features` gibt es jetzt einen separaten experimentellen Pfad fuer `surrogate_guided_features` (`038_surrogate_guided_features.R`):

- Ein kleines `rpart`-Ensemble (`surrogate_guided_rpart_runs = 5`) wird auf einem Discovery-Split des 10%-Tasks trainiert und dient nur als Interaktions-Scout, nicht als finale Modellentscheidung.
- Aus den `rpart`-Baeumen werden Feature-Paare gezaehlt, die wiederholt auf demselben Entscheidungsweg gemeinsam auftreten (`rpart_path_cooccurrence`).
- Fuer numerisch-numerische Paare entstehen generische Kandidatenfeatures: Produkt, beide Ratios und Absolutdifferenz.
- Multinom und `classif.liblinear` pruefen diese Features danach auf einem getrennten Evaluation-Split per CV gegen Rohfeatures. Dadurch wird vermieden, dass dieselben Zeilen sowohl fuer Discovery als auch fuer eine zu optimistische Bewertung verwendet werden.

Wichtig: Das ist bewusst kein Ersatz fuer medizinisch/physikalisch motivierte Features. `domain_features` und `surrogate_guided_features` bleiben getrennt, weil sie unterschiedliche Evidenz liefern: Domain-Features sind plausibilitaetsgetrieben, surrogate-guided Features sind modellgetrieben und muessen strenger gegen Overfitting/Leakage validiert werden.

Aktueller schneller Lauf (`038`, rpart-Ensemble mit 5 Laeufen, Discovery 60%, Evaluation max. 12000 Zeilen, 3-fache CV) fand 3 stabile numerisch-numerische Interaktionspaare:

| Rang | Feature A | Feature B | Pair Count |
|---:|---|---|---:|
| 1 | bmi | sleep_duration | 6 |
| 2 | exercise_duration | sleep_duration | 3 |
| 3 | sleep_duration | step_count | 4 |

Surrogat-Benchmark auf dem getrennten Evaluation-Split:

| Task | Modell | BAcc | MCC | Laufzeit |
|---|---|---:|---:|---:|
| Raw Eval | Multinom | 0.8377 | 0.7909 | 9.00 s |
| Raw Eval | Liblinear | 0.6789 | 0.6830 | 9.42 s |
| Surrogate-guided Eval | Multinom | 0.8632 | 0.8177 | 16.83 s |
| Surrogate-guided Eval | Liblinear | 0.7153 | 0.7265 | 13.74 s |

Erkenntnis: Der rpart-Ensemble-Scout ist sehr schnell (die 5 Baeume lagen zusammen unter einer Sekunde Scout-Zeit) und erzeugt nur wenige, gut lesbare Kandidaten. Anders als der vorherige LightGBM/glmnet-Screen verbessert diese Variante Multinom deutlich (BAcc +2.55 Punkte, MCC +2.68 Punkte gegenueber Raw Eval). Liblinear bleibt insgesamt schwach, profitiert aber ebenfalls. Das macht `surrogate_guided` zu einem ernsthaften Kandidaten fuer lineare Surrogatmodelle; vor einer finalen Uebernahme braucht es aber noch eine robustere CV gegen das bisherige `selected`-Feature-Set und gegen den vollen Multinom-Workflow.

## Regularisierte lineare Modelle

`glmnet` wird als ernsthafter Modellkandidat betrachtet, nicht als reine Baseline. Es verwendet:

- Ridge: `alpha = 0`
- Elastic Net: `alpha = 0.5`
- Lasso: `alpha = 1`
- `cv.glmnet` mit `nfolds = 3`, `nlambda = 30`
- `s = "lambda.1se"` als konservative Lambda-Wahl

| Task | Modell | BAcc | MCC | Laufzeit |
|---|---|---:|---:|---:|
| Rohfeatures | Ridge | 0.7417 | 0.7420 | ca. 33 s |
| Rohfeatures | Elastic Net | 0.8109 | 0.7924 | ca. 27 s |
| Rohfeatures | Lasso | 0.8205 | 0.7985 | ca. 18 s |
| Engineered Features | Ridge | 0.8102 | 0.7935 | ca. 41 s |
| Engineered Features | Elastic Net | 0.8592 | 0.8209 | ca. 132 s |
| Engineered Features | Lasso | 0.8586 | 0.8238 | ca. 286 s |

Erkenntnis: Feature Engineering hilft `glmnet` deutlich, besonders Elastic Net und Lasso. Trotzdem bleibt Ranger aktuell staerker und schneller genug.

## Boosting-Benchmark

`080_boosting_benchmark.R` vergleicht LightGBM gegen die Ranger-Referenz, beide auf Rohfeatures per 5-facher CV und mit nativer Faktor-Behandlung (kein One-Hot noetig). XGBoost ist in `081_xgboost_benchmark.R` ausgelagert, weil es als einziges eine one-hot-encodierte Pipeline aus `040_preprocessing.R` braucht (wie bei `glmnet`) - so laesst sich der guenstige Ranger/LightGBM-Vergleich ohne diese Preprocessing-Abhaengigkeit laufen. Alle mit `num.trees`/`nrounds`/`num_iterations = 200`, sonst Standardparameter:

| Modell | BAcc | MCC | Laufzeit (5-fache CV) |
|---|---:|---:|---:|
| Ranger | 0.8614 | 0.8611 | 162.7 s |
| LightGBM | **0.8779** | 0.8607 | **63.6 s** |
| XGBoost | 0.8586 | 0.8523 | 370.2 s |

Erkenntnis: LightGBM schlaegt Ranger bereits mit Standardparametern deutlich bei BAcc (+1.6 Punkte), bei praktisch gleichem MCC, und ist dabei 2.5x schneller. XGBoost liegt dagegen leicht unter Ranger und ist am langsamsten. LightGBM ist damit der neue staerkste Kandidat.

## Ranger-Tuning

`090_ranger_tuning.R` tunt `mtry.ratio`, `min.node.size` und `sample.fraction` per Random Search (20 Evaluationen, Holdout, `num.trees = 100` fuer die Suche), danach Finalvergleich von Default- vs. getuntem Ranger mit `num.trees = 200` per 5-facher CV:

| Modell | mtry.ratio | min.node.size | sample.fraction | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|---:|---:|---:|
| Ranger default | 0.333 | 1 | 1.0 | 0.8620 | 0.8607 | 188.0 s |
| Ranger getunt | 0.928 | 20 | 0.708 | 0.8760 | 0.8572 | 371.6 s |

Erkenntnis: Tuning hebt BAcc um 1.4 Punkte, kostet aber leicht MCC (-0.4 Punkte, da die Suche nur nach BAcc optimiert hat) und verdoppelt die Laufzeit (plus ca. 9 Minuten Suchphase). Wichtiger: **Der getunte Ranger bleibt hinter LightGBM mit Standardparametern zurueck** (BAcc 0.876 vs. 0.878, MCC 0.857 vs. 0.861, Laufzeit 372s vs. 64s). Tuning-Aufwand lohnt sich hier eher bei LightGBM als bei Ranger.

## LightGBM-Tuning

`100_lightgbm_tuning.R` tunt `learning_rate`, `num_leaves`, `min_data_in_leaf`, `feature_fraction` und `bagging_fraction` per **Bayesian Optimization** (`mlr3mbo`, Standard-Surrogat: Gaussian Process via `DiceKriging`, Akquisitionsoptimierung via `rgenoud`) statt Random Search wie bei Ranger — LightGBM hat mehr interagierende Hyperparameter, und bei guenstigen Einzel-Evaluationen lohnt sich ein Surrogatmodell. 25 Evaluationen, Holdout, `num_iterations = 100` fuer die Suche, danach Finalvergleich von Default- vs. getuntem LightGBM mit `num_iterations = 200` per 5-facher CV:

| Modell | learning_rate | num_leaves | min_data_in_leaf | feature_fraction | bagging_fraction | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| LightGBM default | 0.1 (Standard) | 31 (Standard) | 20 (Standard) | 1.0 (Standard) | 1.0 (Standard) | 0.8755 | 0.8584 | 62.1 s |
| LightGBM getunt | 0.081 | 70 | 92 | 0.930 | 0.600 | 0.8754 | 0.8574 | 106.1 s |

Erkenntnis: **Tuning bringt hier keinen Vorteil** — Default und getunte Konfiguration liegen innerhalb der CV-Rauschgrenze, die getunte Variante ist sogar minimal schlechter und deutlich langsamer. LightGBMs Standardparameter sind fuer diesen Datensatz bereits nah am Optimum. Empfehlung: LightGBM mit Standardparametern verwenden, den Tuning-Aufwand sparen.

## TabPFN (explorativ)

`095_tabpfn_benchmark.R` prueft, wie sich TabPFN (`mlr3extralearners::lrn("classif.tabpfn")`) schlaegt. TabPFN ist ein vortrainiertes Foundation-Modell, das nur als Python-Paket existiert (`reticulate`-Anbindung, benoetigt einmaligen Lizenz-Login bei Prior Labs) und auf CPU standardmaessig auf **1000 Trainingszeilen** begrenzt ist. Deshalb ein eigenes Mini-Subset (`tabpfn_subset_size = 1200`, sonst waere die Grenze beim Standard-`validation_ratio = 0.80` ueberschritten), Ranger/LightGBM als Referenz auf demselben Mini-Subset (Holdout, keine CV):

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| Ranger | 0.6667 | 0.7005 | 2.0 s |
| LightGBM | 0.5833 | 0.6060 | 8.3 s |
| TabPFN | **0.7867** | **0.7552** | 151.8 s |

Erkenntnis: Bei sehr wenig Trainingsdaten (~960 Zeilen) schlaegt TabPFN beide Baum-Modelle deutlich — genau sein Spezialgebiet als few-shot-taugliches Foundation-Modell. Nicht direkt vergleichbar mit den anderen Tabellen in diesem README (58x kleineres Subset), aber ein interessantes Signal fuer Datenregime, in denen kaum Trainingsdaten verfuegbar sind. Fuer den aktuellen Datensatz (69008 Zeilen im 10%-Subset) ist LightGBM/Ranger auf CPU praktikabler; TabPFN bliebe nur mit GPU oder der gehosteten `tabpfn-client`-API auf der vollen Datenmenge nutzbar.

## Klassengewichtung

Die Zielvariable ist stark unausgeglichen (`at-risk` ca. 86%, `unhealthy` ca. 8%, `fit` ca. 6%). `105_lightgbm_class_weights.R` testet balancierte Klassengewichte fuer LightGBM ueber `add_balanced_class_weights()` (`000_config.R`): `weight_i = (n_gesamt / (n_klassen * n_klasse_i))^power`. `power = 0` entspricht ungewichtet, `power = 1` voller Balance. Fuenf Stufen per 5-facher CV auf Rohfeatures:

| power | BAcc | MCC | Laufzeit |
|---:|---:|---:|---:|
| 0.00 (ungewichtet) | 0.8779 | 0.8607 | 75.4 s |
| 0.25 | 0.8945 | 0.8558 | 79.0 s |
| 0.50 | 0.9154 | 0.8489 | 98.8 s |
| 0.75 | 0.9278 | 0.8333 | 70.7 s |
| 1.00 (volle Balance) | **0.9358** | 0.8231 | 68.9 s |

Das ist ein glatter, monotoner Trade-off ohne Sweet Spot: BAcc steigt mit `power` stetig, MCC faellt stetig. Konfusionsmatrix-Vergleich (Holdout) zwischen `power=0` und `power=1` erklaert den Mechanismus: Klassengewichtung hebt den Recall der Minderheitsklassen deutlich an (`fit` 82.9% -> 92.7%, `unhealthy` 78.9% -> 92.4%), kostet dafuer Precision derselben Klassen (`fit` 92.2% -> 78.0%, `unhealthy` 94.7% -> 76.8%) — mehr `at-risk`-Faelle werden faelschlich als `fit`/`unhealthy` einsortiert. BAcc (reiner Recall-Durchschnitt) sieht nur den Gewinn, MCC bestraft die zusaetzlichen Falsch-Positiven.

**Entscheidung: `power = 1`** (`class_weight_power` in `000_config.R`). Ausschlaggebend: Kaggle bewertet diesen Wettbewerb ausschliesslich per BAcc, MCC fliesst nicht in die Bewertung ein — volle Balance ist damit fuer das konkrete Ziel (Kaggle-Score) die richtige Wahl, auch wenn das MCC als internes Qualitaetsmass sinkt. `model_class_weight_power` (`000_config.R`) legt fest, welche Modelle gewichtet werden (aktuell nur `lightgbm`); `070_final_models.R` wendet das automatisch ueber `add_balanced_class_weights()` an, bevor der Learner trainiert wird.

## LightGBM Feature-Family-Benchmark

`110_lightgbm_feature_family_benchmark.R` wiederholt den Feature-Family-Vergleich aus `036` fuer LightGBM, mit der aktuellen `power=1.5`-Klassengewichtung auf allen Tasks (sonst waere der Vergleich inkonsistent zur tatsaechlichen Endkonfiguration). 5-fache CV:

| Feature-Set | BAcc | MCC |
|---|---:|---:|
| Roh | 0.9438 | 0.8016 |
| + BMI | 0.9434 | 0.8010 |
| + Schlaf | **0.9443** | 0.8043 |
| + Aktivitaet | 0.9438 | 0.8071 |
| + Hydration | 0.9432 | 0.8043 |
| + Cardio | 0.9426 | 0.8052 |
| + Interaktionen | 0.9422 | 0.8045 |
| Ausgewaehlt (Aktivitaet+Cardio+Schlaf) | 0.9419 | 0.8076 |
| Kombiniert (alle Familien) | 0.9408 | **0.8105** |

Erkenntnis: Alle Werte liegen innerhalb von ca. 0.35 Prozentpunkten Streuung — das ist Rauschniveau, kein robuster Effekt, dasselbe Muster wie bei Ranger/Multinom/LDA in `036`/`037`. "Kombiniert" ist bei BAcc weiterhin die schwaechste Variante (hat hier aber das beste MCC) — kein Feature-Set ist auf beiden Metriken klar ueberlegen. LightGBM bleibt daher bei Rohfeatures; Feature Engineering bringt fuer dieses Modell keinen verlaesslichen Zusatznutzen. (Zahlen aktualisiert auf `power=1.5`, dem seit "Klassengewichtung ueber power=1 hinaus" gueltigen Stand — die fruehere Tabelle stammte noch von `power=1`.)

## Adversarial Validation

`115_adversarial_validation.R` prueft, ob ein Klassifikator Trainings- von Testzeilen (volle `train.csv`/`test.csv`, nicht das 10%-Subset) unterscheiden kann — AUC nahe 0.5 heisst Train/Test sind aehnlich verteilt und CV-Ergebnisse sollten sich aufs Leaderboard uebertragen, AUC deutlich hoeher bedeutet Distribution Shift. LightGBM (statt eines linearen Modells wie LDA) wurde bewusst gewaehlt, weil es auch nichtlineare Verteilungsunterschiede/Interaktionen erkennen kann, die ein linearer Klassifikator uebersehen wuerde:

- **AUC (3-fache CV): 0.654** — ein spuerbarer, reproduzierbarer, aber moderater Shift (kein extremer Wert wie bei Leakage, der naeher an 0.9+ laege).
- Feature Importance des Adversarial-Klassifikators: `water_intake` (29.8%), `calorie_expenditure` (25.7%), `smoking_alcohol` (15.1%), `bmi` (13.8%) erklaeren zusammen ca. 84% der Unterscheidbarkeit.
- Ein direkter Vergleich von Mittelwert, Streuung, Min/Max, NA-Anteil (numerisch) bzw. Kategorienanteilen (`smoking_alcohol`) zwischen Train und Test zeigt fuer alle vier Merkmale **praktisch identische** Verteilungen (Abweichungen im Rauschbereich).

Erkenntnis: Der Shift ist real und reproduzierbar (bei ~985k Zeilen kein Zufallsrauschen), aber nicht als einfacher Mittelwert-/Range-Shift sichtbar — das deutet eher auf ein subtiles Artefakt der (vermutlich synthetischen) Datengenerierung von `playground-series-s6e7` hin als auf einen inhaltlichen Bedeutungsunterschied der Merkmale zwischen Train und Test. Da es keinen klassischen Verteilungsunterschied gibt, an dem man z.B. per Sample-Weighting ansetzen koennte, wird dieser Befund als geprueftes, akzeptables Risiko eingestuft — der bestehende CV-basierte Workflow wird unveraendert fortgesetzt.

## LightGBM: Leere Strings

`120_lightgbm_empty_string_preprocessing.R` wiederholt den Vergleich aus der Baseline (`030` vs. `050`) fuer LightGBM: `""` als eigene Faktorstufe behalten (aktueller Ansatz) vs. `"" -> NA -> Imputation` ueber `empty_factor_to_na` (`040_preprocessing.R`), beide mit `power=1.5`-Gewichtung (aktueller Stand), 5-fache CV:

| Variante | BAcc | MCC |
|---|---:|---:|
| `""` behalten | **0.9438** | **0.8016** |
| `"" -> NA -> Imputation` | 0.9034 | 0.6921 |

Erkenntnis: Der Unterschied ist fuer LightGBM sogar noch groesser als bei den urspruenglichen Baseline-Modellen (ca. 4 BAcc-Punkte, aber gut **11 MCC-Punkte**) — `""` traegt echtes Signal, das durch Imputation verloren geht, und der Verlust trifft MCC unverhaeltnismaessig staerker als BAcc (die Imputation verschlechtert offenbar gezielt die Trennung der Minderheitsklassen). Bestaetigt die bestehende Konfiguration (keine `empty_factor_to_na`-Behandlung im finalen Modell). (Zahlen aktualisiert auf `power=1.5`; die fruehere Tabelle stammte noch von `power=1`, die Kernaussage war und ist aber unveraendert.)

## Schwellenwert-Tuning

Idee: Statt (oder zusaetzlich zu) Klassengewichten beim Training koennte man die vorhergesagten Wahrscheinlichkeiten nachtraeglich mit klassenspezifischen Gewichten multiplizieren (`argmax(prob * weight)`) und dieses Gewicht auf einem separaten Tune-Split direkt auf BAcc optimieren. `130_threshold_tuning.R` testet das mit einem stratifizierten 3-Wege-Split (60% Train / 20% Tune / 20% Eval).

**Update (Playground-s6e7/s6e8-Cross-Projekt, `class_multiplier_tuning.R`)**: Das urspruengliche Suchgitter (`threshold_tuning_weight_grid = seq(0.5, 6, by = 0.5)`) wurde um zwei Bausteine ergaenzt: eine **geschlossene `1/prior`-Korrektur** (`argmax(prob / Klassen-Prior)`, die Bayes-optimale Regel fuer Balanced Accuracy bei gut kalibrierten Wahrscheinlichkeiten — tuning-frei) als zusaetzlicher Startpunkt, und eine **kontinuierliche Nelder-Mead-Verfeinerung** ab dem besten Startpunkt (Grid- ODER Prior-Optimum). Kontinuierlich ist damit per Konstruktion nie schlechter als Grid/Prior:

| Variante | BAcc (argmax) | BAcc (`1/prior`) | BAcc (Grid) | BAcc (kontinuierlich) | Gefundene Gewichte (kontinuierlich) |
|---|---:|---:|---:|---:|---|
| LightGBM ungewichtet trainiert | 0.8735 | 0.9385 | 0.9291 | 0.9415 | at-risk=1.0, fit=19.67, unhealthy=47.91 |
| LightGBM `power=1.5` trainiert (aktueller Stand) | 0.9351 | 0.9346 | 0.9428 | 0.9428 | at-risk=1.0, fit=4.09, unhealthy=3.30 |

**Wichtiger methodischer Befund**: Beim ungewichtet trainierten Modell laeuft das reine Grid an seine Obergrenze (BAcc-optimale Minderheitsfaktoren liegen bei 19.7/47.9, weit ueber der Grid-Decke 6) — `1/prior` liegt dort naeher am Optimum als das Grid (0.9385 vs. 0.9291) und ist zusaetzlich tuning-frei. Beim bereits mit `power=1.5` trainierten Modell dreht sich das Bild: `1/prior` ist dort **schlechter** als das Grid (0.9346 vs. 0.9428) — Trainings-Klassengewichtung und `1/prior`-Korrektur loesen dasselbe Problem und ueberkorrigieren gemeinsam. **Regel: `1/prior` nur auf ungewichtete Modelle anwenden, nicht zusaetzlich zu einer bereits gewichteten Trainingsphase stacken.** Der kontinuierliche Optimizer ist gegen beide Faelle robust (findet beim gewichteten Modell die kleinen Restfaktoren 4.09/3.30, beim ungewichteten die grossen 19.67/47.91) und bleibt die sicherste Standardwahl.

**Entscheidung**: Threshold-Tuning wird nicht zusaetzlich zur Trainings-Klassengewichtung eingesetzt — das Stacken beider Mechanismen erschliesst keinen neuen Freiheitsgrad, nur denselben BAcc/MCC-Trade-off ueber einen anderen Mechanismus. `class_weight_power` bleibt der primaere Regler; `130` dient als Absicherung/Verfeinerung obendrauf, nicht als Ersatz.

## Schwellenwert-Tuning fuer Ranger

Ranger liefert Wahrscheinlichkeiten ueber ein *Probability Forest*: Jeder Baum speichert je Blatt die Klassenanteile der dort gelandeten Trainingsbeobachtungen, die Vorhersage ist der Durchschnitt dieser Anteile ueber alle Baeume — anders als LightGBMs Log-Loss-optimierte Wahrscheinlichkeiten. `146_threshold_tuning_ranger.R` wiederholt `130` deshalb mit Ranger, um zu pruefen, ob post-hoc-Gewichtung bei dieser anderen Art Wahrscheinlichkeit aehnlich stark greift:

| Variante | BAcc (argmax) | MCC (argmax) | BAcc (Gewicht getunt) | MCC (Gewicht getunt) | Gefundene Gewichte |
|---|---:|---:|---:|---:|---|
| Ranger ungewichtet trainiert | 0.8552 | 0.8624 | 0.9260 | 0.7729 | fit=6.0, unhealthy=6.0 |
| Ranger `power=1.5` trainiert (final) | 0.9398 | 0.7672 | 0.9398 | 0.7672 | fit=1.0, unhealthy=1.0 |

**Wichtiger Unterschied zu LightGBM**: Beim ungewichteten Ranger zeigt sich dasselbe Randgitter-Muster wie bei LightGBM (Gewichte laufen auf 6.0/6.0, kein inneres Optimum). Beim bereits mit `power=1.5` trainierten Ranger findet die Suche dagegen **keine besseren Gewichte als 1.0/1.0/1.0** — argmax(prob) ohne jede Nachbearbeitung ist hier bereits optimal, BAcc/MCC bleiben exakt gleich. Bei LightGBM (siehe oben) brachte dieselbe Suche selbst beim gewichteten Modell noch eine kleine Verschiebung (fit=4.0, unhealthy=3.5). Ranger scheint die Trainings-Klassengewichtung vollstaendiger in seine Wahrscheinlichkeiten zu uebernehmen, sodass kein Rest-Bias im argmax uebrig bleibt, den man post-hoc noch herausdruecken koennte.

**Entscheidung**: Bestaetigt die bestehende Konfiguration - fuer Ranger gibt es keinen Grund, zusaetzlich zur Trainings-Klassengewichtung ein Post-hoc-Threshold-Tuning einzusetzen; der Effekt waere schlicht null.

## CatBoost

`125_catboost_benchmark.R` vergleicht CatBoost (Standardparameter, `iterations = 200`, aktuelle `power=1.5`-Gewichtung) gegen LightGBM. Anders als beim CatBoost-vs-LightGBM-Kategorien-Argument (siehe Modell-Erkenntnisse) geht es hier um CatBoosts *Ordered Boosting* (reduziert Prediction-Shift/Overfitting unabhaengig von Kategorien) - deshalb doch noch getestet:

| Modell | BAcc | MCC | Laufzeit (5-fache CV) |
|---|---:|---:|---:|
| LightGBM | 0.9438 | **0.8016** | 67.8 s |
| CatBoost | **0.9445** | 0.7653 | 772.1 s (~11x langsamer) |

Erkenntnis: CatBoost gewinnt bei BAcc nur noch hauchduenn (+0.07 Punkte statt der urspruenglich unter `power=1` beobachteten +0.78 Punkte), verliert aber weiterhin klar bei MCC (-3.6 Punkte), bei fast 11x hoeherer Laufzeit — dasselbe Trade-off-Muster wie bei `class_weight_power`, nur ueber einen Modellwechsel statt einen Regler erreicht. Der naechste Abschnitt zeigt, wie diese Beobachtung (damals noch unter `power=1`) zur Wahl von `power=1.5` fuer LightGBM gefuehrt hat, das CatBoost seitdem auf beiden Metriken schlaegt (siehe "Ranger und XGBoost mit Klassengewichtung").

## Klassengewichtung ueber power=1 hinaus

`135_lightgbm_class_weight_power_extended.R` setzt die Kurve aus `105` (dort nur bis `power=1`, monoton steigend) fort:

| power | BAcc | MCC | Laufzeit |
|---:|---:|---:|---:|
| 1.00 | 0.9357 | 0.8225 | 78.7 s |
| 1.25 | 0.9409 | 0.8116 | 78.5 s |
| 1.50 | 0.9445 | 0.8025 | 77.1 s |
| 1.75 (Peak) | 0.9449 | 0.7945 | 79.3 s |
| 2.00 | 0.9446 | 0.7848 | 70.9 s |
| 2.50 | 0.9417 | 0.7593 | 70.9 s |
| 3.00 | 0.9349 | 0.7304 | 70.4 s |

Anders als im Bereich 0-1 ist diese Kurve **nicht monoton** — sie hat ein inneres Maximum um `power ≈ 1.75` und faellt danach wieder (extreme Gewichte ueberkorrigieren, sodass selbst der Recall-Durchschnitt leidet).

**Entscheidung: `power = 1.5`** (nicht der exakte Peak bei 1.75): BAcc 0.9445 liegt nur 0.0004 unter dem Peak (Rauschniveau), MCC ist bei 1.5 aber spuerbar besser (0.8025 vs. 0.7945). Wichtiger: **`power=1.5` erreicht BAcc und MCC von CatBoost gleichzeitig** (0.9445/0.8025 vs. CatBoosts 0.9435/0.8022) bei gut 10x kuerzerer Laufzeit (77s vs. 806s) — kein Modellwechsel noetig, derselbe Effekt guenstiger ueber den bestehenden Regler erreichbar.

## Ranger und XGBoost mit Klassengewichtung (Ensemble-Kandidaten)

Alle bisherigen Klassengewichts-Experimente liefen nur mit LightGBM. `140_ensemble_candidates_weighted.R` testet Ranger und XGBoost mit derselben `power=1.5`-Gewichtung, um einen fairen Vergleich fuer eine moegliche Ensemble-Entscheidung zu haben (die bisherigen Ranger-/XGBoost-Zahlen aus `080`/`090` waren ungewichtet):

| Modell | BAcc | MCC | Laufzeit (5-fache CV) |
|---|---:|---:|---:|
| LightGBM | 0.9438 | 0.8016 | 79.6 s |
| **Ranger** | **0.9456** | **0.8144** | 135.3 s |
| XGBoost | 0.8912 | 0.7739 | 438.2 s |

**Ueberraschung**: Ranger mit Klassengewichtung schlaegt sowohl LightGBM als auch CatBoost auf beiden Metriken (CatBoost: 0.9435/0.8022) — bei weniger als einem Sechstel von CatBoosts Laufzeit. Ungewichtet war das komplett unsichtbar; der ungewichtete Ranger-Vergleich aus `080`/`090` haette diese Staerke nie gezeigt. XGBoost bleibt dagegen selbst gewichtet deutlich zurueck und ist mit Abstand am langsamsten — kein sinnvoller Ensemble-Kandidat.

**Entscheidung**: Ranger (Rohfeatures, `num.trees=200`, `power=1.5`) loest LightGBM als finales Modell ab (`model_feature_sets`/`model_class_weight_power`/`070_final_models.R`/`150_train_full_model.R`, gesteuert ueber `submission_model_name`).

**Erste Kaggle-Einreichung mit Ranger**: BAcc **0.9482** (vs. 0.94751 mit dem vorherigen LightGBM-Stand) - wieder nah an der CV-Schaetzung (0.9456), bestaetigt erneut die CV-Methodik.

## Ranger + LightGBM Ensemble (verworfen)

`145_ensemble_ranger_lightgbm.R` testet ein gleichgewichtetes Wahrscheinlichkeits-Ensemble (`gunion()` + `po("classifavg")`, beide Zweige `power=1.5`-gewichtet) gegen die Einzelmodelle:

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| Ranger | 0.9456 | **0.8144** | 136.1 s |
| LightGBM | 0.9438 | 0.8016 | 77.0 s |
| Ensemble (50/50) | 0.9459 | 0.8049 | 208.0 s |

Erkenntnis: Der BAcc-Gewinn gegenueber Ranger allein (+0.0003) ist Rauschen, MCC faellt dagegen spuerbar (LightGBMs schwaecherer MCC zieht den Durchschnitt runter), bei fast doppelter Laufzeit. **Entscheidung: kein Ensemble** - Ranger pur bleibt das finale Modell. Anders als bei LDA/Multinom (grosser Staerkeunterschied) liegt es hier daran, dass beide Modelle zu aehnlich in dieselbe Richtung ziehen, um echten Diversitaetsgewinn zu erzeugen.

## Fehleranalyse Ranger: Konfidenz, Modellvergleich, Isolation Forest, SHAP

`147_error_analysis_ranger.R` untersucht Rangers falsch klassifizierte Zeilen auf einem eigenen Holdout-Split (`power=1.5`, `predict_type="prob"` fuer alle Vergleichsmodelle): Wie sicher war Ranger, als es falsch lag, haetten andere Modelle (LightGBM, LDA, TabPFN) bei denselben Zeilen richtig entschieden, sind die hartnaeckigsten Fehler Feature-Ausreisser, und welche Features treiben Ranger ueberproportional in die falsche Klasse?

**Konfidenz und LightGBM-Vergleich** (beide `power=1.5`-gewichtet, fairer Vergleich):

| Ranger-Konfidenz bei Fehlern | n Fehler | LightGBM-Rescue-Rate | Ø Ranger-Konfidenz |
|---|---:|---:|---:|
| selbstsicher falsch (>=0.5) | 719 | 7.8% | 0.754 |
| unsicher (<0.5) | 22 | 36.4% | 0.452 |

Von 13802 Eval-Zeilen waren 741 falsch (5.4%). LightGBM "rettet" insgesamt nur 8.6% von Rangers Fehlern (waere selbst richtig gelegen); umgekehrt rettet Ranger 14.5% von LightGBMs 792 Fehlern. Bei unsicheren Faellen ist LightGBMs Rescue-Rate deutlich hoeher (36.4% vs. 7.8%) - die Vermutung "LightGBM entscheidet bei unsicheren Faellen oefter richtig" bestaetigt sich damit qualitativ. Diese Faelle sind aber selten: Nur 22 von 741 Fehlern (3%) waren ueberhaupt "unsicher" - die grosse Mehrheit von Rangers Fehlern ist selbstsicher falsch (Ø-Konfidenz 0.75), und dort hilft LightGBM kaum, weil beide Modelle sich meist gemeinsam irren (row-genauer Vergleich zeigt uebereinstimmende Fehlklassifikationen).

**Wichtige methodische Falle: LDA und TabPFN "retten" scheinbar viel mehr, aber nicht echt.** LDA (kann keine Gewichte, `use_weights="ignore"`) und TabPFN (kleiner klassenstratifizierter 999-Zeilen-Kontext, ebenfalls ungewichtet) zeigen auf den ersten Blick beeindruckende Rescue-Raten von **77.7%** bzw. **80.7%** ueber alle 741 Fehler. Aufschluesselung nach der tatsaechlichen Klasse zeigt aber: Das ist fast vollstaendig Mehrheitsklassen-Bias, kein echtes Signal.

| Wahre Klasse | n (von 741 Fehlern) | LDA-Rescue | LightGBM-Rescue |
|---|---:|---:|---:|
| at-risk | 645 | 88.5% | 7.8% |
| unhealthy + fit | 96 | **5.2%** | 14.6% |

645 der 741 Ranger-Fehler haben `truth=at-risk` - genau die Faelle, wo die Klassengewichtung Ranger bewusst von der Mehrheitsklasse wegdrueckt und dabei manchmal uebers Ziel hinausschiesst. LDA/TabPFN sind ungewichtet und tippen daher meist auf "at-risk", was hier zufaellig oft stimmt. Bei den 96 Faellen, wo die Wahrheit tatsaechlich eine Minderheitsklasse ist (die eigentliche Zielgruppe der Gewichtung), rettet LDA nur 5.2% - **schlechter als das korrekt gewichtete LightGBM (14.6%)**. Dasselbe Muster bestaetigt sich fuer TabPFN auf den 138 "alle drei selbstsicher falsch"-Zeilen unten (siehe dort). Lektion (erneut): Modellvergleiche ohne dieselbe Gewichtungsbehandlung sind nicht belastbar, auch nicht als "Rescue-Rate"-Nebenrechnung.

**Zweite methodische Falle: Rescue-Rate ist NICHT dasselbe wie Vertrauenswuerdigkeit bei Uneinigkeit.** Auch nach Kontrolle des Mehrheitsklassen-Bias oben verleitet eine hohe Rescue-Rate leicht zu der Idee, bei Uneinigkeit zwischen zwei Modellen automatisch dem "retteten" Modell zu glauben (z.B. "bei Uneinigkeit LDA statt LightGBM nehmen"). Das ist eine Denkfalle bei bedingten Wahrscheinlichkeiten: Rescue-Rate misst **P(Modell B richtig | Modell A falsch)** - fuer eine Korrekturregel relevant ist aber **P(Modell B richtig | Modelle A und B uneinig)**, eine andere Groesse. In einem Testfall (LightGBM vs. LDA, `playground-series-s6e6`, Klassengewichtung `power=1.25`) zeigte LDA eine Rescue-Rate von 38% auf LightGBMs Fehler - bei tatsaechlicher Uneinigkeit zwischen beiden Modellen (10% aller Zeilen) hatte aber **LightGBM in 77.3% der Faelle recht, LDA nur in 18.1%**. Eine "bei Uneinigkeit LDA glauben"-Regel haette 683 aktuell richtige Vorhersagen zerstoert (BAcc 0.9534 -> 0.8535). Grund: Das insgesamt viel staerkere Modell hat auch bei den meisten Uneinigkeitsfaellen noch recht, selbst wenn das schwaechere Modell einen ueberdurchschnittlichen Anteil von dessen SPEZIFISCHEN Fehlern trifft. **Vor jeder Ensemble-/Korrekturentscheidung aus einer Fehleranalyse heraus**: Uneinigkeits-bedingte Genauigkeit beider Modelle direkt vergleichen (nicht nur die Rescue-Rate), sonst droht eine Regel, die im Mittel mehr schadet als nuetzt.

**Isolierte "alle drei Modelle selbstsicher falsch"-Faelle**: 138 von 741 Ranger-Fehlern sind auch fuer LightGBM UND LDA falsch (bei Ranger-Konfidenz >= 0.5); 136 davon sagen sogar dieselbe falsche Klasse voraus - ein starkes, konsistentes Verwirrungsmuster ueber drei strukturell verschiedene Modellfamilien (Baum-Ensemble, Boosting, linear). Sind das Feature-Raum-Ausreisser? **Isolation Forest** (Paket `isotree`, 500 Baeume) sagt nein:

| Gruppe | n | Anomalie-Score (Median) | Anomalie-Score (Mean) |
|---|---:|---:|---:|
| Alle drei selbstsicher falsch | 138 | 0.4585 | 0.466 |
| Baseline: alle drei richtig | 690 | 0.4626 | 0.4676 |

Praktisch identisch (Wilcoxon-Test p=0.30, nicht signifikant) - diese Zeilen sehen im Feature-Raum vollkommen unauffaellig aus. Das spricht gegen "ungewoehnliche Merkmalskombination, auf der Modelle schlecht extrapolieren" und eher fuer inhaerente Grenzfaelle/Label-Mehrdeutigkeit (passend zum synthetischen Datensatz und dem in `115` gefundenen Generierungs-Artefakt) - kein Befund, den man ueber Trainingsdaten-Bereinigung leicht beheben koennte.

**TabPFN auf den 138 Faellen** (999-Zeilen-Kontext, siehe `095` fuer das CPU-Limit): 21.7% Rescue-Rate insgesamt, aber wieder Mehrheitsklassen-Bias bei genauerem Hinsehen:

| Wahre Klasse | n | TabPFN-Rescue |
|---|---:|---:|
| at-risk | 62 | 46.8% |
| fit | 36 | **0%** |
| unhealthy | 40 | **2.5%** |

29 der 30 "Rettungen" kommen aus der at-risk-Klasse, nur 1 aus unhealthy, keine einzige aus fit - TabPFN bringt hier keinen robusten Zusatznutzen auf den Klassen, die tatsaechlich zaehlen, trotz komplett anderer Methodik (in-context-Lernen statt Baum-Splits/lineare Grenzen).

**KernelSHAP** (Paket `kernelshap`) auf je 100 zufaellig gezogenen falsch- und richtig-klassifizierten Zeilen, um zu pruefen, welche Features ueberproportional an Fehlern beteiligt sind (`mean(|SHAP|)` fuer die jeweils vorhergesagte Klasse, Verhaeltnis falsch/richtig):

| Feature | Error-Ratio |
|---|---:|
| smoking_alcohol | **2.98** |
| sleep_quality | **2.82** |
| diet_type | 1.90 |
| step_count | 1.70 |
| bmi | 1.63 |
| exercise_duration | 1.57 |
| sleep_duration | 1.45 |
| stress_level | 1.19 |
| heart_rate | 1.15 |
| physical_activity_level | 1.14 |
| gender | 1.12 |
| calorie_expenditure | 1.07 |
| water_intake | 0.85 |

**Verbindung zur Adversarial Validation (`115`)**: Dort waren `water_intake`, `calorie_expenditure`, `smoking_alcohol`, `bmi` die vier staerksten Treiber des Train/Test-Shifts. Hier zeigt sich, dass `smoking_alcohol` und `bmi` auch ueberproportional an Rangers Fehlern beteiligt sind (Ratio 2.98 bzw. 1.63) - der Shift scheint bei diesen beiden Merkmalen tatsaechlich mit Fehlklassifikationen zusammenzuhaengen. `water_intake` dagegen, der staerkste Shift-Treiber in `115`, hat eine Error-Ratio **unter 1** - traegt zum Shift bei, aber nicht ueberproportional zu Fehlern, vermutlich weil es insgesamt der schwaechste Praediktor im Modell ist (niedrigster absoluter SHAP-Beitrag aller Features).

**Gesamterkenntnis**: Kein einzelner Hebel springt heraus, der eine gezielte Korrektur rechtfertigen wuerde. Weder ein anderes Modell (LightGBM/LDA/TabPFN) noch eine Feature-Raum-Anomalie erklaeren Rangers hartnaeckigste Fehler robust - die Isolation-Forest- und klassenweisen Rescue-Analysen deuten eher auf inhaerent schwierige/mehrdeutige Faelle hin als auf ein behebbares Modell- oder Datenproblem. `smoking_alcohol`/`sleep_quality`/`diet_type` waeren die ersten Kandidaten, falls man dennoch gezielt an Feature-Qualitaet/-Kodierung arbeiten wollte.

**Cross-Projekt-Update (2026-07-16, `openml-adult-income`, 4. Bestaetigungsprojekt)**: Die "strukturelle Fehlergrenze" (mehrere Modellfamilien einig, selbstsicher, oft dieselbe falsche Klasse) trat dort ebenfalls auf (41.6% der Ranger-Fehler, alle mit derselben falschen Klasse) - **erste Bestaetigung auf einem echten (nicht-synthetischen) Datensatz**, war bis dahin nur an synthetischen Kaggle-Playground-Daten beobachtet (Sorge: koennte ein Generierungs-Artefakt sein, siehe Klammer oben). Die Isolation-Forest-Richtung war dort allerdings UMGEKEHRT (hartnaeckige Faelle waren *weniger* anomal als die Baseline, nicht mehr) - die Interpretation "inhaerente Grenzfaelle/Label-Mehrdeutigkeit statt Ausreisser" bleibt gleich, aber die Isolation-Forest-Richtung selbst ist offenbar nicht verlaesslich in eine Richtung vorherzusagen und sollte pro Projekt neu interpretiert, nicht als feste Erwartung angenommen werden.

## One-vs-Rest-Kurven an echten Multiclass-Daten bestaetigt

Die OvR-Logik in `008_curve_diagnostics.R`/`160`/`161` (`truth == positive` fasst bei >=3 Klassen alle anderen Klassen als "negativ" zusammen) war bislang nur an binaeren (`openml-adult-income`) und synthetischen 3-Klassen-Daten (dieses Projekt) ausgeuebt. **Bestaetigt (2026-07-17) am 5. Projekt `openml-satimage-multiclass`** (OpenML-ID 182, 6 echte Klassen, 36 numerische Features): fuer JEDE der 6 Klassen stimmt die aus `compute_classif_curves()` abgeleitete OvR-ROC-AUC (Trapezregel, `curve_auc()`) mit einer unabhaengig berechneten OvR-AUC (`mlr3measures::auc` auf binarisiertem `truth`) und dem geloggten Referenzwert bis auf **1.11e-16** ueberein (reines Fliesskomma-Rauschen). Makro-Durchschnitt OvR-ROC-AUC 0.9859 (Ranger). Reine Validierung der bestehenden generischen Funktionalitaet, keine Codeaenderung noetig. Hinweis am Rande: `mlr3measures::auc()` verlangt einen strikt binaeren Faktor - fuer eine per-Klasse-OvR-AUC muss `truth` erst binarisiert werden (`factor(ifelse(truth == cls, cls, "rest"), levels = c(cls, "rest"))`); `compute_classif_curves()` macht das intern selbst.

**Neu in der Datenbank**: `147` ist das erste Skript, das Einzelvorhersagen zeilenweise loggt (Tabellen `prediction`/`prediction_prob`, siehe `EXPERIMENTS_DB.md`) - aber bewusst nur fuer die "interessanten" Zeilen (falsch klassifiziert oder Konfidenz < `error_analysis_uncertainty_threshold`), nicht fuer den kompletten Eval-Split, um die Tabelle klein zu halten (757 von 13802 Zeilen, je Modell - inzwischen 4 Modelle: Ranger, LightGBM, LDA, TabPFN).

**Laufzeit-Hinweis**: Dieses Skript ist rechnerisch teuer - KernelSHAP (Sampling-basierte Permutations-SHAP) und TabPFNs CPU-Inferenz brauchen zusammen deutlich ueber eine Stunde, obwohl beide Kosten aus fruaheren Skripten (`095`) bereits bekannt waren. Vor einer Wiederholung/Erweiterung lohnt es sich, den Nutzen explizit gegen die Laufzeit abzuwaegen, statt mehrere teure Analyseschritte routinemaessig zu stapeln.

## Ranger-Tuning unter Klassengewichtung (verworfen)

`090_ranger_tuning.R` tunte Ranger **ohne** Klassengewichtung. `142_ranger_tuning_weighted.R` wiederholt das Tuning auf dem `power=1.5`-gewichteten Task, da die Zielfunktionslandschaft mit Gewichtung eine andere ist:

| Modell | mtry.ratio | min.node.size | sample.fraction | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|---:|---:|---:|
| Default (gewichtet) | 0.333 | 1 | 1.0 | 0.9458 | **0.8148** | 114.3 s |
| Getunt (gewichtet) | 0.377 | 20 | 0.685 | **0.9473** | 0.7920 | 112.3 s |

Erkenntnis: Anders als bei LightGBM (`100`) findet das Tuning hier einen kleinen echten BAcc-Gewinn (+0.0015), aber wieder zum Preis eines spuerbaren MCC-Verlusts (-0.023). Der Gewinn liegt in der Groessenordnung der CV-Rauschgrenze, die wir in anderen Experimenten beobachtet haben. **Entscheidung: Standard-Hyperparameter behalten** - konsistent mit der Wahl `power=1.5` statt des BAcc-Peaks bei `power=1.75`: ein unsicherer, kleiner BAcc-Gewinn rechtfertigt nicht den sichereren, groesseren MCC-Verlust.

## Modell-Erkenntnisse

- Ranger war zunaechst die wichtigste Vergleichsbaseline, wurde von LightGBM abgeloest (Boosting-Benchmark) - und hat dann mit Klassengewichtung LightGBM (und CatBoost) wieder ueberholt (siehe oben). Lektion: Modellvergleiche ohne dieselbe Gewichtungs-/Preprocessing-Behandlung sind nicht belastbar, selbst wenn sie zuvor "eindeutig" aussahen.
- Cross-Projekt-Bestaetigung (`drivendata_richter`, 2026-07-17): LightGBM darf kein automatischer Submission-Default sein. Ohne Target-Encoding, aber mit `geo_frequency`, war Ranger lokal besser (CV Accuracy 0.7154 vs. 0.7097) und auf dem Leaderboard klar besser (0.7495/Rang 437 vs. 0.7336/Rang 1414). Finale Modellwahl daher immer aus CV je Feature-Set ableiten, nicht aus "LightGBM ist meistens gut".
- Lineare Modelle profitieren nicht automatisch von vielen abgeleiteten Features.
- LDA reagiert empfindlich auf Kollinearitaet.
- Unregularisierte multinomiale Regression ist schnell, aber nicht stark genug.
- `glmnet + engineered Features` ist methodisch interessant, aber deutlich teurer.
- `s = "lambda.1se"` ist konservativ; `lambda.min` kann spaeter fuer Kaggle-Performance getestet werden.
- SHAP ist noch zu frueh als fester Schritt. Es wird spaeter fuer stabile Baum-/Boosting-Kandidaten interessant.
- Holdout-Vergleiche zwischen aehnlich guten Feature-Varianten sind mit Vorsicht zu geniessen: Der per Cross-Validation bestaetigte Ranger-Befund dreht die Holdout-Erkenntnis (einzelne Familien helfen Ranger) sogar um. Vor einer Modell-/Feature-Entscheidung immer per CV gegenpruefen.
- LightGBM schlaegt mit Standardparametern sowohl Ranger default als auch getunten Ranger — Boosting-Kandidaten vor Hyperparameter-Tuning einzelner Modelle pruefen, nicht danach.
- TabPFN ist bei sehr kleinen Trainingsmengen (< ca. 1000 Zeilen auf CPU) konkurrenzfaehig, fuer den vollen 10%-Subset auf CPU aber nicht praktikabel (Kontextlaengen-Limit).
- CatBoosts Kernvorteil bei Kategorien (Ordered-Target-Statistics) greift hier nicht (nur 3-4 Auspraegungen je Spalte), aber CatBoosts *Ordered Boosting* ist ein unabhaengiger, kategorien-unabhaengiger Vorteil - deshalb doch getestet (siehe CatBoost-Abschnitt): gewinnt bei BAcc, verliert bei MCC, bei fast 10x hoeherer Laufzeit. LightGBM mit hoeherem `class_weight_power` erreicht denselben Punkt guenstiger.
- Auch LightGBM-Tuning per Bayesian Optimization bringt keinen messbaren Vorteil gegenueber den Standardparametern — bei bereits starken Default-Implementierungen (LightGBM, glmnet mit `lambda.1se`) ist der Ertrag von Hyperparameter-Tuning innerhalb eines vertretbaren Budgets gering.
- Klassengewichtung ist ein echter BAcc/MCC-Trade-off, kein Gratis-Gewinn: Welche Seite richtig ist, haengt davon ab, welche Metrik tatsaechlich zaehlt (hier: Kaggle-Bewertung per BAcc) — nicht vom Bauchgefuehl.
- Feature Engineering hilft auch LightGBM nicht robust (siehe Feature-Family-Benchmark) — dasselbe Muster wie bei Ranger/Multinom/LDA bestaetigt sich modelluebergreifend.
- Adversarial Validation zeigt einen moderaten, aber nicht per Mittelwert/Streuung erklaerbaren Train/Test-Unterschied (AUC 0.654) — vermutlich ein Generierungs-Artefakt des synthetischen Datensatzes, kein inhaltlicher Shift. Vor einer Sample-Weighting-Massnahme lohnt es sich, zu pruefen, ob ueberhaupt ein klassischer (Mittelwert-/Range-)Shift vorliegt, den man korrigieren koennte.
- Post-hoc Threshold-Tuning auf Wahrscheinlichkeiten ist kein unabhaengiger Hebel zusaetzlich zur Trainings-Klassengewichtung — beide optimieren denselben BAcc/MCC-Trade-off, nur an unterschiedlichen Stellen der Pipeline. Ein Suchgitter, das am Rand landet (statt an einem inneren Optimum), ist ein Warnsignal fuer eine unbeschraenkte Zielfunktion, nicht ein Zeichen fuer "mehr suchen".

## Modellauswahl pro Learner (Stand nach CV-Check)

- **LDA**: Rohfeatures, keine engineered Features (kollinearitaetsempfindlich, kein CV-bestaetigter Nutzen).
- **Multinom**: Aktivitaet+Cardio+Schlaf-Feature-Set (`task_train_small_features_selected.rds`) — CV-bestaetigter Vorteil gegenueber Rohfeatures.
- **Ranger (finales Modell, `submission_model_name`)**: Rohfeatures, Standardparameter (`num.trees = 200`, sonst Default), balancierte Klassengewichte mit `power = 1.5` — schlaegt gewichtetes LightGBM und CatBoost auf BAcc und MCC gleichzeitig, bei einem Sechstel von CatBoosts Laufzeit (siehe Ensemble-Kandidaten-Abschnitt). Bereits in `model_feature_sets`/`model_class_weight_power`/`070_final_models.R`/`150_train_full_model.R` uebernommen.
- **LightGBM**: weiterhin ein sehr starker Kandidat (Rohfeatures, `power = 1.5`, eigenes Hyperparameter-Tuning brachte keinen Zusatznutzen), aber knapp hinter Ranger — bleibt als moeglicher Ensemble-Partner interessant (siehe Ensemble-Kandidaten-Abschnitt).

Diese Zuordnung ist in `model_feature_sets` und `model_class_weight_power` (`000_config.R`) fest verdrahtet und wird von `070_final_models.R` automatisch angewendet: das Skript laedt je Learner ueber `resolve_task_path()` das passende Feature-Set-Task, wendet ueber `add_balanced_class_weights()` ggf. Klassengewichte an und trainiert/speichert das finale Modell (`_artifacts/final_model_<modell>.rds`).

**Modularitaet fuer einen anderen Klassifikationsaufgaben-Workflow:** `resolve_task_path()` kennt nur die generischen Bezeichner `"raw"`, `"features"`, `"selected"` sowie beliebige Eintraege aus `feature_families` - er ist nicht an dieses Dataset gebunden, ebenso wenig `add_balanced_class_weights()` (arbeitet generisch ueber `task$target_names`). Um das Setup auf eine andere Aufgabe zu uebertragen, muessen nur folgende Teile ausgetauscht werden:

1. `features/*.R` durch neue, aufgabenspezifische `add_<familie>_features()`-Funktionen ersetzen.
2. `feature_families`/`selected_families` in `000_config.R` an die neuen Familien anpassen.
3. `model_feature_sets` neu befuellen (welcher Learner nutzt welches Feature-Set).
4. `model_class_weight_power` neu befuellen (welcher Learner bekommt Klassengewichte, welche `power`-Staerke) - je nachdem, welche Metrik fuer die neue Aufgabe zaehlt.
5. `base_learner_constructors` um neue Modellnamen ergaenzen, falls noetig, und `submission_model_name` auf das gewuenschte finale Modell setzen.

`005_benchmark_runtime.R`, `040_preprocessing.R`, `025_feature_engineering.R`, `070_final_models.R`, `150_train_full_model.R` und `155_predict_submission.R` bleiben dabei unveraendert, da sie ausschliesslich ueber diese Konfigurationswerte arbeiten. Wichtig: Feature Engineering ist weiterhin aufgabenspezifisch und kein Default. `apply_feature_set()` sorgt nur dafuer, dass ein bewusst gewaehltes Feature-Set identisch auf Full-Train und `test.csv` angewendet wird; fuer dieses Projekt bleibt Ranger aufgrund der CV-/Kaggle-Ergebnisse explizit auf Rohfeatures. `038_surrogate_guided_features.R` ist davon getrennt: es kann generisch neue Kandidatenfeatures vorschlagen, ersetzt aber nicht die fachliche Auswahl und nicht die CV-Bestaetigung.

**Empfehlung fuer zukuenftige Projekte**: Wo immer moeglich `predict_type = "prob"` setzen, auch wenn zunaechst nur die Klassenvorhersage gebraucht wird. Grund: `final_model_ranger.rds` (`070_final_models.R`) wurde ohne `predict_type = "prob"` trainiert und lieferte deshalb nur harte Klassenlabels - fuer die Fehleranalyse (`147_error_analysis_ranger.R`, siehe unten) musste Ranger deswegen auf einem eigenen Split neu trainiert werden, nur um an Wahrscheinlichkeiten zu kommen. Wahrscheinlichkeiten kosten beim Training praktisch nichts extra, ermoeglichen aber im Nachhinein Schwellenwert-Tuning (`130`/`146`), Ensembles (`145`) und SHAP-/Fehleranalysen (`147`), ohne neu trainieren zu muessen.

## Finales Training & Submission

`150_train_full_model.R` trainiert `submission_model_name` (aktuell `ranger`: Rohfeatures, Standardparameter, `class_weight_power = 1.5`) auf dem **vollen** Trainingsdatensatz (`train.csv`, 690088 Zeilen statt des 10%-Subsets) und speichert Modell + Feature-Set + Faktorstufen der Merkmale gemeinsam (`_artifacts/final_model_<modell>_full.rds`) - Letzteres, damit `155_predict_submission.R` `test.csv` exakt mit demselben Feature-Set und denselben Kategorie-Stufen verarbeitet, unabhaengig davon, ob im Test-Set zufaellig alle Stufen vorkommen. `150`/`155` laden `features/*.R` per Glob statt hartcodierter Dateinamen (zwei unabhaengige Uebertragungen - s6e5, s5e12 - scheiterten sonst an fehlenden Feature-Familien-Dateien in einem neuen Projekt). `155` erzeugt daraus `submission.csv` im Format von `sample_submission.csv` (Spalten `id`, `health_condition`) - **metrik-abhaengig**: bei binaerer Aufgabe mit schwellenwert-unabhaengiger Zielmetrik (AUC/LogLoss) wird stattdessen `P(positive_class)` geschrieben (`150` setzt dafuer `predict_type="prob"`, falls der Learner es unterstuetzt), sonst wie bisher Klassen-Labels.

Vorhergesagte Klassenverteilung auf `test.csv` (295753 Zeilen, Ranger): `at-risk` 81.8%, `unhealthy` 10.9%, `fit` 7.25% (Rohverteilung im Training war ca. 86/8/6%) - naeher an der Rohverteilung als LightGBMs Vorhersage, passend zu Rangers besserer Precision/MCC in der CV.

**Erste Kaggle-Einreichung** (LightGBM, `power=1.5`, vor der Ranger-Umstellung): BAcc **0.94751**, Platz 618/1104 - sehr nah an der lokalen CV-Schaetzung (0.9445), was die CV-Methodik nachtraeglich bestaetigt (kein Overfitting an das 10%-Subset, der Adversarial-Validation-Shift hat sich als unschaedlich erwiesen).

Kein erneutes Hyperparameter-Tuning auf dem vollen Datensatz: `100_lightgbm_tuning.R` zeigte auf dem Subset keinen Vorteil gegenueber Standardparametern, und eine erneute Suche haette auf der 10x groesseren Datenmenge grob geschaetzt 1.5-2.5 Stunden gekostet, ohne dass ein anderes Ergebnis zu erwarten war.

## Naechste Schritte

1. ~~Ranger als feste Referenzbaseline behalten~~ - Ranger ist (wieder) das finale Modell, diesmal mit Klassengewichtung, finales Training auf vollem Datensatz abgeschlossen (siehe oben).
2. ~~Feature Engineering in kleinere Feature-Familien aufteilen~~ - erledigt in `features/*.R`, `025`, `036` und `037`, fuer LightGBM in `110` bestaetigt (kein Zusatznutzen).
3. ~~Preprocessing-Strategien explizit fuer LightGBM vergleichen~~ - erledigt in `120`: `""` behalten bleibt klar besser (bestaetigt bestehende Konfiguration).
4. ~~Boosting-Kandidaten pruefen: XGBoost, LightGBM, CatBoost~~ - LightGBM erledigt in `080`, XGBoost in `081`, CatBoost in `125`, alle drei nochmal gewichtet in `140` (Ranger gewinnt).
5. ~~LightGBM tunen~~ - erledigt in `100` (Bayesian Optimization via `mlr3mbo`), kein Zusatznutzen gegenueber Standardparametern.
6. ~~Klassengewichtung pruefen~~ - erledigt in `105`/`135`, `power = 1.5` uebernommen; in `140` bestaetigt, dass Ranger davon noch staerker profitiert als LightGBM.
7. ~~Adversarial Validation durchfuehren~~ - erledigt in `115`. Moderater, aber nicht per Mittelwert/Streuung erklaerbarer Shift (AUC 0.654) - als geprueftes Risiko akzeptiert, kein Handlungsbedarf.
8. ~~Post-hoc Threshold-Tuning pruefen~~ - erledigt in `130`, kein unabhaengiger Hebel gegenueber `class_weight_power`.
9. ~~Ganz am Schluss: kompletten Trainingsdatensatz statt 10%-Subset verwenden~~ - erledigt in `150`/`155`, `submission.csv` erzeugt. Kaggle-Einreichungen: LightGBM-Stand BAcc 0.94751 (Platz 618/1104), Ranger-Stand BAcc 0.9482 - beide nah an der jeweiligen CV-Schaetzung.
10. ~~Ensemble aus LightGBM + Ranger~~ - erledigt in `145`: kein Zusatznutzen, BAcc-Gewinn ist Rauschen, MCC leidet. Ranger pur bleibt final. XGBoost bewusst ausgeschlossen (schwaecher und ~10x langsamer, siehe `140`).
11. ~~Ranger-Tuning unter Klassengewichtung pruefen~~ - erledigt in `142`: kleiner, unsicherer BAcc-Gewinn (+0.0015) zum Preis eines spuerbaren MCC-Verlusts (-0.023) - nicht uebernommen, Standard-Hyperparameter bleiben.
12. Pseudo-Labeling als moeglicher weiterer Hebel besprochen (mehr Trainingsdaten, passt Modell an Testverteilung an) - Risiko: kann die muehsam hergestellte Klassenbalance wieder unterlaufen, falls Konfidenz-Schwellen nicht pro Klasse gesetzt werden. Noch nicht umgesetzt.
13. Optional, falls noch gewuenscht: SHAP/Interpretierbarkeit fuer das finale Modell einsetzen.
14. ~~`targets` zur Orchestrierung der Skripte einfuehren~~ - erledigt (`_targets.R`), deckt den finalen Workflow ab (Task-Erzeugung bis Submission), siehe eigener Abschnitt oben.
