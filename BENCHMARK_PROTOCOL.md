# Benchmark-Protokoll (eingefroren, Stand 2026-08-28, v2 seit 2026-08-29)

## Version 2 (2026-08-29): faire getunte Baselines

P1 aus der 2026-08-29-Bewertung ("Baselines fuer Research-Paper noch zu
schwach"). Referenzimplementierung:
[`outer_workflow_evaluation_v2_fair_baselines.R`](outer_workflow_evaluation_v2_fair_baselines.R).
Ergaenzt v1 um 3 Arme, v1 selbst bleibt UNVERAENDERT gueltig fuer die
bereits damit ausgewerteten 13 Datensaetze (7 Phase C + 6 externes Set):

- **`tuned_ranger`** - `AutoTuner` (Random-Search, `search_space` wie
  `090_ranger_tuning.R`), Inner-Resampling = Holdout(0.75) INNERHALB des
  Outer-Train.
- **`tuned_lightgbm`** - `AutoTuner` (MBO, `search_space` wie
  `100_lightgbm_tuning.R`), gleiches Inner-Resampling.
- **`best_single_tuned_model`** - kein eigenes Training: waehlt je
  Outer-Fold zwischen `tuned_ranger`/`tuned_lightgbm` anhand des INNEREN
  Tuning-Validierungswerts (nicht Outer-Test) und uebernimmt dessen
  bereits berechneten Outer-Test-Score.

**Compute-Budget (dokumentiert)**: `tuned_baseline_evals = 15` je Arm
(Random-Search bzw. MBO) - bewusst kleiner als das volle Template-Default
fuer `100_lightgbm_tuning.R` (25 MBO-Evals), da dieser Arm 3x pro
Datensatz (Outer Folds) statt einmalig laeuft. `ranger_default`/
`lightgbm_default`/`workflow_ranger` unveraendert aus v1.

**Ergebnis (alle 6 externen Datensaetze, siehe `BACKLOG.md`/P1-Status
fuer die volle Tabelle)**: gegen faire getunte Baselines verschwindet
`workflow_ranger`s Vorteil bei 3 von 6 Datensaetzen (knapp, <1 BAcc-
Punkt) - bleibt aber bei den kleineren/staerker unausgeglichenen
Datensaetzen (ilpd, sick, blood-transfusion) klar bestehen. Wichtige
Praezisierung ggue. v1 (dort gewann/hielt `workflow_ranger` bei allen 6).

**Praezisierung (2026-08-29, siehe [`EVALUATION_LEVELS.md`](EVALUATION_LEVELS.md))**:
dieses Protokoll deckt ausschliesslich **Level 1 (Component Workflow)**
ab - gewichtetes Training + ggf. Multiplier-/Threshold-Korrektur, NICHT
den vollstaendigen AutoML-Entscheidungsprozess (Modellwahl, Tuning,
Ensemble Selection etc. laufen NICHT innerhalb der Outer-CV-Schleife
selbst). Fruehere Formulierungen wie "Full-Workflow Outer Evaluation"
meinten immer schon genau das, sind aber sprachlich unpraezise - siehe
`EVALUATION_LEVELS.md` fuer die vollstaendige Einordnung und Level 2/3.

Phase E, Punkt 16 aus dem 2026-08-28-Bewertungsdokument: "Benchmark-
Protokoll einfrieren". Dieses Dokument fixiert EXAKT, was Phase C
(`BACKLOG.md`, "Naechste Bewertung 2026-08-28"/Phase C) als Level-1-
Outer Evaluation gemacht hat, als **Version 1** dieses Protokolls -
verbindlich fuer jeden weiteren Datensatz, der dazukommt, sofern nicht
explizit als Abweichung dokumentiert.

Zweck: Vergleichbarkeit ueber Datensaetze/Sessions hinweg. Ohne ein
eingefrorenes Protokoll wuerde jede neue Session leicht abweichende Arme,
Fold-Zahlen oder Metrik-Handhabung waehlen - die Ergebnisse waeren dann
nicht mehr sauber nebeneinander stellbar (genau das Risiko, das ein
"Benchmark-Protokoll" verhindern soll).

## Protokoll v1

**Referenzimplementierung**: `outer_workflow_evaluation_template.R`
(Repo-Wurzel) - wird unveraendert in den Ordner des Zieldatensatzes
kopiert (`ML_Learning/<projekt>/outer_workflow_evaluation.R`), dort nur
so weit angepasst, wie die Projektkonventionen es erfordern (siehe
"Erlaubte Abweichungen" unten).

**Outer-CV**: `rsmp("cv", folds = 3)`, stratifiziert
(`enable_class_stratification()`), instanziiert auf der gesamten
`task_train_small`. Jeder Outer-Test-Fold wird GENAU EINMAL angefasst -
fuer die finale Bewertung bereits fertig trainierter Modelle. Keine
Inner-Entscheidung (Hyperparameter-Suche, Multiplier-Tuning) sieht
jemals Outer-Test-Zeilen (siehe P1.1-Status, `BACKLOG.md`).

**3 Vergleichs-Arme** (nicht mehr, nicht weniger - der `lightgbm_tuned`-
Arm aus dem P1.1-Prototyp ist bewusst NICHT Teil von v1, siehe
Begruendung im Phase-C-Status):

1. `ranger_default` - `classif.ranger`, Default-Hyperparameter,
   `imputemedian`+`imputemode`-Vorverarbeitung.
2. `lightgbm_default` - `classif.lightgbm`,
   `num_iterations = lightgbm_tuning_final_iterations` (falls im Projekt
   gesetzt, sonst 200), sonst Default-Hyperparameter, gleiche
   Vorverarbeitung.
3. `workflow_ranger` - der reale, dokumentierte Projekt-Workflow:
   klassengewichtetes Training (`add_balanced_class_weights()`,
   `class_weight_power` aus `000_config.R`, Default `1.5` falls nicht
   gesetzt) auf dem VOLLEN Outer-Train. Multiplier-Tuning
   (`class_multiplier_tuning.R`) wird NUR ergaenzt, wenn BEIDE
   Bedingungen gelten: die Datei existiert im Projektordner UND die
   Primaermetrik ist schwellenwertABHAENGIG
   (`!is_threshold_independent_metric(tuning_measure_id)`). In diesem
   Fall: Inner-Train/Tune-Split (75/25) NUR des Outer-Train, Multiplier
   auf dem Inner-Tune-Split gesucht, finales Modell auf dem VOLLEN
   Outer-Train trainiert.

**Metrik**: `baseline_measure_ids[1]` des jeweiligen Projekts (die
tatsaechliche Primaermetrik, NICHT pauschal BAcc) - Scoring generisch
ueber `mlr3::Prediction$score(msr(tuning_measure_id))`.

**Erfasste Kennzahlen je Arm** (siehe `outer_workflow_evaluation_results.csv`/
`_summary.csv` im jeweiligen `_artifacts/`-Ordner): Score je Outer-Fold,
Laufzeit je Outer-Fold, daraus aggregiert Mittelwert, Standardabweichung,
schlechtester Fold (richtungsabhaengig - Minimum bei "hoeher=besser"-
Metriken, Maximum bei Fehlermetriken wie LogLoss).

**Logging**: jedes Ergebnis wird als eigene Zeile in die zentrale
Evidence Registry geloggt (`db_log_evidence()`, `role = "trust_gate"`,
`module = "outer_workflow_evaluation"`, `evidence_source =
"outer_workflow_evaluation.R (Phase C, generalisierte Fassung)"` oder
Nachfolgeversion, `dataset_type` = die Kategorie A-G o.ae.).

## Erlaubte Abweichungen (dokumentationspflichtig, nicht protokollbrechend)

Diese Anpassungen sind bereits in Phase C aufgetreten und gelten als
Teil des Protokolls, WENN das Zielprojekt aeltere Konventionen nutzt:

- Task-Pfad: falls kein `task_train_small_path`/`020_task.R` existiert,
  ein projektspezifischer, fest kodierter Pfad (z.B. `task_credit.rds`) -
  im Skript-Kommentar zu dokumentieren.
- `class_weight_power`: falls im Projekt nicht gesetzt, Default `1.5`
  (Template-Konvention) uebernehmen.
- `enable_class_stratification()`/`add_balanced_class_weights()`: falls
  im Projekt nicht vorhanden, die identischen Implementierungen aus
  `MLR3_Classifikation/000_config.R` als Fallback nachreichen.

Jede WEITERE Abweichung (z.B. ein 4. Vergleichsarm, eine andere
Fold-Zahl, ein anderer Split-Anteil) macht ein Ergebnis NICHT direkt mit
den bestehenden 7 Phase-C-Datensaetzen vergleichbar - so etwas erfordert
eine explizite Protokoll-Version 2 (dieses Dokument aktualisieren, alte
Version nicht stillschweigend ueberschreiben) statt einer stillen
Abweichung.

## Bereits mit Protokoll v1 ausgewertete Datensaetze

Siehe `BACKLOG.md`/Phase-C-Status fuer die volle Ergebnistabelle:
`health_condition` (P1.1-Prototyp, methodisch identisch zu v1 bis auf
den zusaetzlichen, hier entfernten `lightgbm_tuned`-Arm),
`openml-credit-g`, `CreditScoringChallenge`, `wdbc-plateau-test`,
`PumpItUp`, `geoai-aquaculture-pond-identification-challenge`,
`openml-eeg-eye-state-timeseries`.
