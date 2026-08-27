# Backlog: Classification-Template

Dieses Dokument übersetzt die aktuelle Bewertung des Classification-Templates in einen konkreten Arbeitsplan für Codex.

## Hinweis zur Struktur-Prämisse (wichtig vor der Umsetzung von P1-P3)

Dieses Repo ist **bewusst kein R-Paket** (siehe `TARGETS.md`: `DESCRIPTION`
existiert nur als CI-Dependency-Manifest, keine installierbare Paketstruktur).
Die in P1/P3 genannten Pfade (`R/000_config.R`, `R/classification/`,
`NAMESPACE`, `vignettes/`) passen nicht zur tatsächlichen, absichtlichen
Flach-Struktur (nummerierte Skripte im Root, siehe `WorkflowDescription.md`).
Ein Umzug nach `R/` würde `source()`-Aufrufe in einem Dutzend+ abhängiger
Projekte brechen (`ML_Learning/*`, `MLR3_Regression`), die diese Dateien über
ihren aktuellen flachen Pfad einbinden. Die inhaltlichen Ziele von P1
("fachliche Logik in kleine, testbare Funktionen lösen") werden hier bereits
im etablierten Muster erreicht - eigenständige Helper-Dateien im Root
(`ensemble_selection.R`, `group_resampling.R`, `sanity_checks.R`, jetzt auch
`target_leak_audit_helpers.R`) statt eines Pfad-Umzugs. **P0 wird unten
umgesetzt, P1-P3 folgen bei Bedarf in derselben angepassten Form.**

## P0 - Status (2026-08-26)

- **Testabdeckungs-Audit**: 4 der 5 genannten Kernbausteine hatten bereits
  `testthat`-Tests (Class-Multiplier/Threshold-Tuning, Ensemble Selection,
  Generalization Gap, Group Resampling). Einzige Lücke: **Leakage-Schutz**
  (`015_target_leak_audit.R`) hatte keinen Unit-Test.
- **CI-Trennung Unit-/Smoke-Test**: existierte bereits (`unit-tests`- und
  `smoke-test`-Jobs in `.github/workflows/ci-smoke-test.yml`, seit 2026-08-19).
- **Lücke geschlossen**: die drei eigenständig testbaren Kernberechnungen aus
  `015_target_leak_audit.R` (Determinismus-Check, kumulative Top-k-Schwelle,
  Cluster-Erkennung) wurden - ohne Verhaltensänderung - in eine neue Datei
  `target_leak_audit_helpers.R` extrahiert (analog `group_resampling.R`).
  `015_target_leak_audit.R` ruft sie jetzt auf, statt sie inline zu
  definieren. Regressionsgetestet: byte-identisches Ergebnis gegen die
  CI-Fixture UND das Template-eigene Projekt (health_condition: stress_level
  42.9%/sleep_duration 34.8%, exakt wie zuvor dokumentiert).
- **Neue Tests**: `tests/testthat/test-target_leak_audit_helpers.R`, 12 Faelle
  mit bekanntem Ground Truth - u.a. die bereits dokumentierten realen
  Positiv-/Negativ-Kontrollen als synthetische Regressionstests nachgebaut
  (bike-sharing-Leak-PAAR, road-accident-risk-Spezifitätskontrolle,
  lending-club-redundanter-Cluster). Volle Suite (`Rscript tests/testthat.R`):
  alle 4 bestehenden + die neue Datei gruen.
- CI-Workflow um `target_leak_audit_helpers.R` in der Fixture-Kopierliste
  ergänzt (sonst würde `015` in der CI-Fixture ab jetzt fehlschlagen).
- **CI bestätigt grün** (Run `32993648579`, beide Jobs `unit-tests` +
  `smoke-test` erfolgreich, commit `8d06e30`).
- **`univariate_drift.R` getestet** (2. Punkt aus ChatGPTs korrigierter
  P0.1-Liste): war bereits eine saubere, eigenständige Funktionsdatei
  (`run_univariate_drift_tests()`/`report_univariate_drift()`), keine
  Extraktion nötig. Neue `tests/testthat/test-univariate_drift.R`, 9 Fälle
  mit bekanntem Ground Truth (echter numerischer/kategorialer Drift, echte
  Spezifitätskontrolle bei identischer Verteilung, degenerierte Randfälle
  ohne Absturz - konstante Spalte, Einzel-Auspägung -, BH-Korrektur-
  Monotonie, Spaltennamen-Mismatch, Speichern/Rückgabe-Konsistenz). Volle
  Suite weiterhin komplett grün.
- **CI bestätigt grün** (Run `32994042694`, commit `42f31b5`).
- **`seed_stability.R` getestet** (3. Punkt aus P0.1): drei Funktionen -
  `report_stability()` ist reine Statistik (analog `cohens_d()`/
  `compare_score_distributions()` in `generalization_gap.R`), `seed_
  stability()`/`hyperparam_jitter_stability()` brauchen echtes mlr3-Training
  (messen Modell-eigene Streuung, kein Umweg möglich). Neue
  `tests/testthat/test-seed_stability.R`, 9 Fälle: `report_stability()`
  vollständig ground-truth-getestet (flaggt/flaggt nicht korrekt je nach
  Verhältnis zur CV-Referenzstreuung, `NA` statt Division-durch-0 bei
  konstanter Referenz, `NA` rutscht NICHT als "auffällig" durch, custom
  Schwellenwert, CSV-Append-Verhalten). `seed_stability()` an einem winzigen
  synthetischen Task mit 2 echten mlr3-Lernern verifiziert: `classif.rpart`
  (seed-unempfindlich) -> SD=0 (Spezifität), `classif.ranger` (seed-
  empfindlich, 5 Bäume) -> SD>0 (Positivkontrolle).
  `hyperparam_jitter_stability()`: Plumbing (Parameter-Ziehung, Score je Zug)
  + Determinismus bei fixem Seed verifiziert. Volle Suite weiterhin grün.
- **CI bestätigt grün** (Run `32994649311`, commit `bfa6d27`).
- **`db_logging.R` getestet** (4. Punkt aus P0.1): das SQLite-Experiment-
  Tracking-Backend - bislang der einzige Baustein mit echten DB-
  Schreib-/Lesezugriffen statt reiner Statistik/ML-Logik. Neue
  `tests/testthat/test-db_logging.R`, 15 Fälle gegen eine frische temporäre
  Datei-DB je Test (`db_connect()` auf `tempfile()`, echtes Schema aus
  `db_schema.sql`): Schema-Anlage + Idempotenz von `db_connect()`,
  `db_get_or_create_project()`/`_workflow()` geben beim 2. Aufruf dieselbe ID
  zurück statt zu duplizieren (inkl. Unterscheidung gleichnamiger Workflows
  unterschiedlichen Typs), `db_create_run()`/`db_finish_run()` setzen
  `run_finished_at` korrekt, `db_log_run_config()`/`db_create_model_config()`
  (inkl. Hyperparameter-Zeilen) inserten korrekt verknüpft,
  `db_log_predictions()` vergibt `pred_seq` fortlaufend UND kollisionsfrei
  über mehrere Aufrufe hinweg und entrollt die Wahrscheinlichkeitsmatrix
  korrekt in die EAV-Tabelle `prediction_prob`, `db_log_submission_result()`s
  Upsert-Verhalten (2. Aufruf mit gleichem Platform/Status/Metric
  aktualisiert statt zu duplizieren), `db_get_latest_model_artifact_path()`/
  `_model_config_id()` finden korrekt den ZULETZT trainierten Lauf (Zeit-
  stempel explizit auseinandergezogen, da `datetime('now')` nur Sekunden-
  auflösung hat) und geben `NA` zurück, wenn nichts geloggt ist.
  **Technischer Fund**: `db_connect()` löst `project_dir` über seine
  Definitionsumgebung auf (`source()` ohne `local=TRUE` definiert in
  `.GlobalEnv`) - ein testthat-sandboxed lokales `project_dir <-` im
  Testfile ist dafür unsichtbar; behoben mit
  `assign("project_dir", ..., envir = globalenv())` vor dem Sourcen.
  Volle Suite weiterhin grün (jetzt 6 Testdateien).
- **`split_size_sensitivity.R` getestet** (5. Punkt aus P0.1, auf Nutzerwunsch
  vorgezogen vor `learning_curve.R`): zwei Funktionen -
  `report_split_ratio_sensitivity()` ist reine Logik (operiert auf einer
  bereits berechneten `sens`-Tabelle), `split_ratio_sensitivity()` braucht
  echtes mlr3-Training (`rsmp("subsampling")`, misst Streuung durch
  UNTERSCHIEDLICHE Splits desselben Anteils). Neue
  `tests/testthat/test-split_size_sensitivity.R`, 7 Fälle: `report_split_
  ratio_sensitivity()` flaggt/flaggt nicht korrekt je nach Faktor zum
  Minimum-CV (per `capture.output()` an der tatsächlichen Konsolenmeldung
  geprüft, nicht nur am Rückgabewert), Hinweis bei nicht getestetem
  `chosen_ratio`, Speichern. `split_ratio_sensitivity()` an einem winzigen
  synthetischen Task verifiziert: korrekte `n_train`/`n_test` je ratio,
  `cv`-Spalte stimmt mit `sd/|mean|` überein, Determinismus bei fixem Seed.
  mlr3-INFO-Logging fürs Testfile auf "warn" gedrosselt (sauberer
  Testoutput). Volle Suite weiterhin grün (jetzt 7 Testdateien).
- **`learning_curve.R` getestet** (6. Punkt aus P0.1): das bisher am
  dichtesten mit dokumentierter Bugfix-Historie versehene Modul (IQR- statt
  Range-Fix wegen eines Ausreissers bei `openml-credit-g`,
  `min_rows_per_fold`-Filter wegen `wdbc-plateau-test`). Beide Fixes wurden
  als kalibrierte synthetische Regressionstests nachgebaut (nicht nur
  behauptet): PLATEAU-Erkennung bei reinem Rauschen, NOCH-STEIGEND trotz
  eines extremen Ausreissers bei winzigem `n` (**mit Gegenprobe im Test
  selbst**: `gain/volle_Spannweite` liegt unter der 10%-Schwelle - waere
  also faelschlich PLATEAU gewesen -, `gain/IQR` bleibt klar darueber,
  exakt die im Kopfkommentar beschriebene Bug-Signatur), sowie PLATEAU nach
  Ausschluss eines unzuverlaessigen Frueh-Punkts (`min_rows_per_fold`).
  Alle Test-Kurven wurden vorab per Skript kalibriert (nicht aus der Luft
  gegriffen) - eine erste Version mit plausibel wirkenden, aber nicht
  nachgerechneten Werten schlug bei 3 von 7 Fällen fehl, weil eine "typisch
  aussehende" Lernkurvenform nicht automatisch der beabsichtigten
  Klassifikation entspricht (die Regression laeuft ueber ALLE Punkte in
  log(n)-Raum, ein einzelner frueher Anstieg kann den Gesamttrend staerker
  dominieren als intuitiv erwartet). Neue
  `tests/testthat/test-learning_curve.R`, 7 Fälle. `learning_curve()`
  selbst (braucht echtes mlr3-Training) an einem winzigen synthetischen
  Task verifiziert: `n` waechst mit `fraction`, Determinismus bei fixem
  Seed. Volle Suite weiterhin grün (jetzt 8 Testdateien).
  **Offen aus P0.1**: `multilabel.R`, Probability-/Calibration-Helper,
  Config-Validierung (letztere existiert noch nicht, siehe P0.3).
- **`multilabel.R` getestet** (7. Punkt aus P0.1): Binary-Relevance-
  Multi-Label-Klassifikation. Fünf reine Metrik-/Schwellenwert-Funktionen
  (`hamming_loss()`, `subset_accuracy()`, `f1_binary()` inkl. `tp=0 -> 0`
  statt `NaN`, `macro_f1()`/`micro_f1()` - Ground Truth so konstruiert,
  dass sich Makro und Mikro nachweislich UNTERSCHEIDEN bei unbalancierten
  Labelhäufigkeiten, genau die im Kopfkommentar behauptete Eigenschaft -,
  `accuracy_at_threshold()`, `tune_threshold_accuracy()`) vollständig von
  Hand nachgerechnet. `binary_relevance_pool()`/`classifier_chain_pool()`
  (brauchen echtes mlr3-Training) an einem winzigen synthetischen
  2-Label-Task verifiziert - insbesondere die **NA-Maskierung** (2026-08-21-
  Fund aus `tox21-multilabel`, bislang ungetestet): NA-Zeilen fehlen im
  Ergebnis für das betroffene Label vollständig (nicht nur beim Training),
  ein NA-freies zweites Label bleibt unverändert vollständig (No-op-
  Verhalten wie bei yeast/scene/birds), außerdem eigene Learner-Objekte je
  Label und Reproduzierbarkeit bei fixem Seed. Neue
  `tests/testthat/test-multilabel.R`, 10 Fälle. Volle Suite weiterhin grün
  (jetzt 9 Testdateien). **Damit ist P0.1 aus ChatGPTs Liste bis auf die
  Probability-/Calibration-Helper vollständig abgearbeitet.**
- **Probability-/Calibration-Helper getestet (8., letzter Punkt aus
  P0.1) - Fund: es existiert KEIN eigenständiges Modul dafür.**
  `REFERENZ_PROBABILITY_CALIBRATION.md` ist explizit als reine Referenz
  ohne Code-Änderung markiert ("Dies ist eine Referenz, keine
  Template-Code-Änderung"). Der einzige tatsächliche Template-Code zu
  diesem Thema liegt bereits in `db_logging.R` (`calibration_sensitive_
  measures`, `is_threshold_independent_metric()` - beide schon getestet)
  - übersehen wurde dabei `warn_if_threshold_step_low_value()`, die
  Konsolenwarnung, die zwischen "kalibrierungssensitiv" (LogLoss +
  Gewichtungsschritt), "schwellenwertunabhängig, wenig Effekt" (AUC) und
  "schwellenwertabhängig, relevant" (BAcc) unterscheidet. 3 neue Fälle in
  `tests/testthat/test-db_logging.R` (ergänzt, keine neue Datei) decken
  alle 3 Zweige ab. Volle Suite weiterhin grün (weiterhin 9 Testdateien,
  `db_logging` jetzt mit mehr Fällen). **P0.1 ist damit vollständig
  abgeschlossen** - kein weiterer Punkt aus ChatGPTs Liste offen.

## P0.2 - Status (2026-08-26)

Audit ergab: von den 9 in P0.1 mit Tests versehenen Root-Helper-Dateien
hatten **nur 2 Funktionen** (beide in `db_logging.R`) eine stille
Abhängigkeit von einer globalen Variable statt eines expliziten Arguments
(`db_connect()` -> `project_dir`, `warn_if_threshold_step_low_value()` ->
`baseline_measure_ids`) - alle anderen Helper-Dateien waren bereits
sauber (reine Funktionen mit expliziten Parametern). Zusätzlich hatten
7 `stopifnot()`-Aufrufe (in `group_resampling.R`, `univariate_drift.R`,
`generalization_gap.R`, `ensemble_selection.R`) keine Fehlermeldung -
im Fehlerfall nur R-Standardtext wie `"length(gcol) == 1 is not TRUE"`.

**Umgesetzt, beides 100% rückwärtskompatibel** (keine Pfad-/Signatur-
Brüche für bestehende Aufrufer, siehe P0.2-Akzeptanzkriterium):

1. `db_connect(db_path, project_dir = get("project_dir", envir =
   globalenv()))` - Default erhält das bisherige Verhalten für JEDEN
   bestehenden Aufrufer 1:1, macht die Abhängigkeit aber sichtbar und
   explizit übergebbar (kein `assign(..., envir = globalenv())`-Workaround
   in Tests mehr nötig).
2. `warn_if_threshold_step_low_value(..., primary_metric =
   baseline_measure_ids[1])` - dieselbe Idee.
3. Alle 7 `stopifnot()`-Aufrufe bekamen eine benannte, verständliche
   Fehlermeldung (`stopifnot("Meldung" = Bedingung)` - reine
   Meldungsergänzung, keine Logikänderung).

**Regressionsgetestet**: volle `testthat`-Suite weiterhin grün (7 neue
Testfälle für die gehärteten Signaturen/Meldungen ergänzt, u.a. ein Test,
der `project_dir` in `globalenv()` bewusst auf einen NICHT existierenden
Pfad setzt und beweist, dass das explizite Argument trotzdem greift), UND
`015_target_leak_audit.R` End-to-End gegen `health_condition` erneut
gelaufen - byte-identisches Ergebnis zu vorher (stress_level 42.9%,
sleep_duration 34.8%).

**Bewusst NICHT angefasst**: die repo-weite Konvention, dass Skripte
`seed`/`validation_ratio`/`cv_folds`/etc. aus `000_config.R` als globale
Variablen lesen - das ist die etablierte, funktionierende Architektur
dieses Templates (jedes numerierte Skript liest seine Config so), keine
versehentliche stille Abhängigkeit wie die zwei oben gefundenen Fälle.
Eine Umstellung DIESES Musters wäre P0.3-/Architektur-Territorium
(`validate_config()`), nicht P0.2s "Helper haerten".

## P0.3 - Status (2026-08-26)

**Struktur-Konflikt wie schon bei P1 gefunden und mit dem Nutzer geklärt**:
ChatGPTs Vorschlag, `000_config.R` physisch in `config_defaults.R`/
`config_validation.R`/`config_derived.R` aufzuteilen, würde das
etablierte Wiederverwendungsmuster dieses Templates brechen - ein neues
Projekt entsteht durch **Kopieren einer einzelnen Datei** (`000_config.R`)
und Anpassen der Werte (siehe `TARGETS.md`-Checkliste "Übertragung auf
einen neuen Kaggle-Wettbewerb"). Eine Aufteilung würde daraus "mehrere
Dateien kopieren und synchron halten" machen. **Nutzerentscheidung**: nur
`validate_config()` als neue, rein additive Datei umsetzen, `000_config.R`
selbst bleibt strukturell unverändert.

**Umgesetzt**: `config_validation.R`, eine einzelne Funktion
`validate_config(env = parent.frame())`, die die BESTEHENDEN
`000_config.R`-Werte auf Konsistenz prüft - kein bestehendes Skript ruft
sie automatisch auf (rein additiv, kein Verhalten geändert), ein
Nutzer/eine Session ruft sie manuell nach dem Anpassen der Config auf.

Deckt aus ChatGPTs Checkliste ab, was auf tatsächlich existierende
Config-Variablen dieses Templates abbildet:
- `target_col` vorhanden und nicht-leer.
- `id_col` `NULL` oder gültiger Zeichenvektor.
- `baseline_measure_ids` nicht leer, jede ID ein bekanntes mlr3-Maß
  (fängt Tippfehler wie `classif.baccc`).
- `positive_class`-Konsistenz: warnt (nicht fatal), wenn `NULL` bei einer
  schwellenwertunabhängigen Metrik (AUC/LogLoss) - könnte binär sein.
- Multi-Label-Konsistenz: `multilabel_train_ratio`/`_tune_ratio` müssen
  Platz für die Eval-Menge lassen, `target_col` darf nicht in `label_cols`
  auftauchen.
- Split-/Budget-Anteile (`validation_ratio`, `subset_fraction`, `cv_folds`,
  `class_weight_power`) in sinnvollen Bereichen.
- **Tippfehler-Schutz**: `model_feature_sets`/`model_class_weight_power`/
  `submission_model_override` müssen auf tatsächliche Einträge in
  `base_learner_constructors` verweisen (der konkrete Anlass:
  "lgihtgbm" statt "lightgbm" bei der Übertragung auf ein neues Projekt).
- `directional_expectation_specs`: Pflichtfelder je Typ (`delta` bei
  `numeric`, `level_order` bei `ordinal`), gültige `direction`.

**Bewusst ausgelassen** (aus ChatGPTs Liste, aber ohne Entsprechung in
diesem Template): "Group-CV ohne Group-Spalte"/"Time-CV ohne
Zeitinformation" - dieses Template hat keine feste `group_col`/`date_col`-
Konvention in `000_config.R` (das ist Panel-/Forecasting-spezifisch,
siehe das analoge, bereits umgesetzte Kapitel im Regressions-Template).
Eine Erfindung einer nicht existierenden Konvention hätte hier keinen
Wert gehabt. "Schwellenwertunabhängige Metrik + Threshold-Tuning" deckt
bereits `warn_if_threshold_step_low_value()` (P0.2) ab, nicht dupliziert.

**Verifiziert**: Sammelt ALLE gefundenen Probleme in einer einzigen
Fehlermeldung (nicht nur das erste), damit man nicht wiederholt
aufrufen/fixen muss. 6 handgebaute kaputte Configs lösten alle die
richtige Meldung aus (Positivkontrolle), die echte `000_config.R` von
`health_condition` läuft fehlerfrei durch (Spezifitätskontrolle,
regressionsgetestet). Neue `tests/testthat/test-config_validation.R`,
16 Fälle (29 Erwartungen) - inkl. eines End-to-End-Tests gegen die echte
Config. Volle Suite weiterhin grün (jetzt 11 Testdateien).

**Damit ist P0 aus ChatGPTs Plan vollständig abgeschlossen** (P0.1
Testabdeckung, P0.2 Helper-Härtung, P0.3 `validate_config()`) - jeweils
an die tatsächliche, absichtliche Architektur dieses Templates angepasst
statt der wörtlichen Vorlage zu folgen, wo diese mit der Realität des
Repos kollidierte.

## P1.1 - Status (2026-08-26)

**Nutzerentscheidung zum Scope**: "Prototyp zuerst: nur `health_condition`,
3 Outer Folds" - statt der von ChatGPTs korrigiertem Plan verlangten
>= 2 Datensätze bewusst auf 1 Projekt reduziert. P1.2 (Evidence Registry)
und P1.3 (Experiment-/Daten-Provenienz) aus demselben Plan sind NICHT
angefasst - nur explizit angeforderte Punkte werden umgesetzt.

**Umgesetzt**: `outer_workflow_evaluation.R` (neu, Repo-Wurzel, analog zu
`multilayer_stack_test.R`/`hyperband_budget_test.R` - ein Evaluations-
Skript, kein Teil der nummerierten Produktions-Pipeline). Frage: wie gut
generalisiert der TATSÄCHLICH gelebte Projekt-Workflow (klassengewichteter
Ranger via `add_balanced_class_weights()` + BAcc-optimales Multiplier-
Tuning via `class_multiplier_tuning.R`) auf Outer-Test-Folds, die NIE von
einer Inner-Entscheidung (Hyperparameter-Suche, Multiplier-Suche) berührt
werden?

4 Vergleichs-Arme je Outer-Fold (3 stratifizierte Folds via
`rsmp("cv", folds = 3)`):
1. `ranger_default` - ungewichteter Ranger, Default-Hyperparameter.
2. `lightgbm_default` - ungewichtetes LightGBM, Default-Hyperparameter.
3. `lightgbm_tuned` - kleines MBO-Suchbudget (8 Evaluationen, reduziert
   gegenüber `100_lightgbm_tuning.R`s 25, da dieser Arm 3x statt 1x läuft)
   auf einem Inner-Train/Tune-Split des Outer-Train; finales Modell mit
   gefundenen Hyperparametern auf dem VOLLEN Outer-Train.
4. `workflow_ranger` - der echte Projekt-Workflow: Multiplier werden auf
   einem Inner-Tune-Split gesucht, das finale (gewichtete) Modell wird auf
   dem VOLLEN Outer-Train trainiert.

Leckage-Garantie (Kernkriterium von P1.1): jeder Outer-Test-Fold wird
GENAU EINMAL angefasst - für die finale Vorhersage bereits fertig
entschiedener Modelle/Hyperparameter/Multiplikatoren. Keine Inner-
Entscheidung sieht jemals Outer-Test-Zeilen.

**Ergebnis** (Mittel über 3 Outer Folds, BAcc):

| Arm | mean BAcc | SD | worst fold | mean Laufzeit |
|---|---|---|---|---|
| `workflow_ranger` | **0.9480** | 0.0051 | 0.9427 | 72s |
| `lightgbm_default` | 0.8745 | 0.0085 | 0.8646 | 10s |
| `lightgbm_tuned` | 0.8707 | 0.0065 | 0.8638 | 266s |
| `ranger_default` | 0.8633 | 0.0091 | 0.8532 | 58s |

Der echte Projekt-Workflow generalisiert klar und konsistent besser als
alle 3 Baselines (+7.3 bis +8.5 BAcc-Punkte, in JEDEM der 3 Outer Folds
vorne, niedrige Streuung) - auf Daten, die während Multiplier-Tuning nie
gesehen wurden. Das leicht getunte LightGBM (Arm 3) bringt hier trotz
~4.5 Minuten Laufzeit keinen Vorteil gegenüber Default-LightGBM - im
Rahmen des reduzierten 8-Evaluationen-Budgets konsistent mit der bereits
dokumentierten Hyperband-/Successive-Halving-Erfahrung dieses Projekts
(LightGBM-Tuning-Gewinn hier klein/rauschbehaftet).

**Aufgetretener Bug (gefunden und gefixt)**: Namenskollision zwischen
`mlr3tuning::tnr()` (Tuner-Konstruktor) und `mlr3measures::tnr()` (True
Negative Rate) - da `library(mlr3measures)` NACH `library(mlr3tuning)`
geladen wird, maskiert Letzteres die Tuner-Funktion. `tnr("mbo")` rief
dadurch `mlr3measures::tnr("mbo", ...)` auf und scheiterte an
`assert_binary()`, weil `"mbo"` als `truth`-Argument interpretiert wurde.
Fix: expliziter `mlr3tuning::tnr("mbo")`-Aufruf statt des unqualifizierten
Namens - robust unabhängig von der Ladereihenfolge.

**Kein dediziertes `testthat`-Testfile**: analog zu
`multilayer_stack_test.R`/`hyperband_budget_test.R` (Evaluations-Skripte,
keine wiederverwendbaren Bausteine) - die eingesetzten Bausteine
(`add_balanced_class_weights()`, `class_multiplier_tuning.R`) sind bereits
andernorts testabgedeckt.

**Limitationen** (bewusst, siehe Scope-Entscheidung): nur 1 Projekt/
Datensatz (health_condition), nur 3 Outer Folds, reduziertes LightGBM-
Tuning-Budget für Arm 3. Vor einer Verallgemeinerung dieses Befunds auf
andere Projekte wäre eine Wiederholung auf einem 2. Datensatz nötig
(P1.1 mit vollem Scope) - aktuell nicht angefordert.

## P1.2 - Status (2026-08-27)

**Ziel laut ChatGPTs korrigiertem Plan**: Experimentwissen verteilt sich
aktuell auf `TARGETS.md`, `README_DETAILS.md`, `SYSTEMATIC_EVALUATION.md`,
Projekt-READMEs, Statusanker, Commits und die Experiment-DB - eine
maschinenlesbare "Evidence Registry" als zusaetzliche, strukturierte
Quelle fuer neue Befunde. Der Plan selbst schreibt ein 3-Schritte-Vorgehen
vor: "1. nur neue Befunde strukturiert loggen, 2. wichtige historische
Befunde nachziehen, 3. SYSTEMATIC_EVALUATION.md automatisch erzeugen.
**Nicht sofort alles migrieren.**"

**Scope dieses Prototyps**: NUR Schritt 1. Schritt 2 (rueckwirkendes
Nachtragen von `SYSTEMATIC_EVALUATION.md`s ~20 Projekten x 9 Modulen in
die Registry) und Schritt 3 (automatische Generierung dieser Datei aus der
Registry) sind NICHT umgesetzt - beides waere angesichts der Detailtiefe
von `SYSTEMATIC_EVALUATION.md` (Fussnoten, Korrekturvermerke, Methodik-
Hinweise je Zelle) ein eigener, erheblich groesserer Arbeitsschritt, den
ChatGPTs eigener Plan ausdruecklich vertagt.

**Umgesetzt**:
- Neue Tabelle `evidence` in `db_schema.sql` (additiv, `CREATE TABLE IF
  NOT EXISTS`, wie der Rest des Schemas). Bewusst OHNE Fremdschluessel auf
  `project`/`workflow`/`run`/`model_config` - ein Befund bezieht sich oft
  auf eine ganze Roadmap-Frage ueber mehrere Projekte/Laeufe hinweg (z.B.
  "TabM getestet, negativ") statt auf einen einzelnen mlr3-Lauf.
  `evid_project` ist deshalb reiner Text, keine FK. Felder wie im Plan
  vorgeschlagen: `evid_role` (`score_lever`/`trust_gate`/
  `workflow_automation`/`documentation`), `evid_status`
  (`confirmed`/`core_finding`/`neutral`/`negative`/`not_applicable`/`open`),
  Metrik/Baseline/Ergebnis/Delta/Laufzeit, Backport-Status, Quelle,
  Git-Commit, Notizen.
- Neue Datei `evidence_registry.R`: `db_log_evidence(con, project, module,
  role, status, ...)` (validiert role/status, verstaendliche
  Fehlermeldungen bei Tippfehlern) und `evidence_registry_summary(con)`
  (liest die komplette Tabelle als `data.table`, neueste zuerst).
- `merge_project_experiments.R`: `evidence` zur `merge_tables`-Liste
  hinzugefuegt (keine FK-Abhaengigkeit, daher gefahrlos anfuegbar) - neue
  Befunde aus einzelnen Projekt-DBs fliessen damit wie die anderen
  Tabellen in die zentrale, gemergte DB (ADR-001: lokale Projekt-DBs,
  keine geteilte Live-DB - der Merge bleibt ein expliziter, manueller
  Schritt).
- Testabdeckung: neue `tests/testthat/test-evidence_registry.R`, 5 Faelle
  (Positivkontrolle mit allen Feldern, Minimalaufruf mit optionalen
  NA-Feldern, 3 Fehlerfaelle fuer ungueltiges `role`/`status`/leeres
  `project`, Sortierreihenfolge von `evidence_registry_summary()`). Volle
  Suite weiterhin gruen (jetzt 12 Testdateien).
- **Live demonstriert**: 2 erste echte Eintraege in die tatsaechliche
  `health_condition`-`experiments.db` geloggt (nicht nur in einer
  Test-DB) - der P1.1-Kernbefund (`trust_gate`, `core_finding`, BAcc
  0.8633 -> 0.9480, delta +0.0847) und ein Selbstverweis auf die
  Umsetzung von P1.2 selbst (`workflow_automation`, `confirmed`).

**Bewusst ausgelassen**: keine neue SQL-View fuer die `evidence`-Tabelle
(die Tabelle ist bereits flach/direkt abfragbar, eine View haette hier
keinen echten Mehrwert gehabt, anders als bei den Join-lastigen
Tabellen weiter oben im Schema). Keine automatische Aufrufstelle in einem
bestehenden nummerierten Skript - wie bei `validate_config()` (P0.3) ein
manuell aufzurufendes Werkzeug, kein Teil der Pipeline.

**Naechster moeglicher Schritt (nicht angefordert)**: Schritt 2 (historische
Befunde aus `SYSTEMATIC_EVALUATION.md` in die Registry nachtragen) waere
die logische Fortsetzung, sollte aber als eigener, bewusst geplanter
Arbeitsschritt behandelt werden statt beilaeufig mit P1.2 vermischt zu
werden.

## P1.3 - Status (2026-08-27)

**Ziel laut ChatGPTs korrigiertem Plan**: "Was hat sich zwischen zwei
Runs geändert?" - wenn praktikabel loggen: SHA256 Trainings-/Testdaten,
Git Commit, R-Version, Config-Hash, Resampling-Hash, Feature-Set-
Bezeichnung/-Hash, Modellartefakt-Checksumme, Environment-/Paketreferenz.

**Umgesetzt**: neue Datei `provenance.R` mit `sha256_file(path)`,
`hash_value(x)` (generischer SHA256-Hash beliebiger R-Objekte ueber deren
Serialisierung) und `capture_run_provenance(...)`, die eine benannte
Liste (Praefix `provenance.*`) baut, direkt uebergebbar an die
BESTEHENDE `db_log_run_config()` (db_logging.R) - **keine neue Tabelle**,
da Provenienzwerte konzeptionell zusaetzliche Konfigurationswerte EINES
Runs sind und die vorhandene `run_config`-EAV-Tabelle das bereits
verlustfrei abbildet. Git Commit ist bereits ueber `run_git_commit`
(`get_git_commit()`) abgedeckt, hier bewusst nicht dupliziert.

"Wenn praktikabel" woertlich umgesetzt: jeder Parameter ist optional
(`NULL` = "hier nicht anwendbar", kein Fehler) - `train_data_path`/
`test_data_path`/`model_artifact_path` (SHA256 der Datei),
`config_env` (Environment ODER Liste, wird GEHASHT statt im Klartext
geloggt - kann sensible lokale Pfade enthalten, der Hash beantwortet
trotzdem "hat sich die Config geaendert?"), `resampling` (ein
instanziiertes mlr3-`Resampling`-Objekt wird ueber seine TATSAECHLICHEN
Fold-Zuweisungen gehasht, nicht ueber das R6-Objekt selbst - dessen
interne Env-Referenzen waeren nicht reproduzierbar hashbar),
`feature_set` (einzelner String -> Klartext-Label, Spaltennamen-Vektor
-> Hash), `packages` (installierte Versionen im `name=version`-Format,
Default deckt `mlr3`/`mlr3learners`/`mlr3extralearners`/
`mlr3pipelines`/`ranger`/`lightgbm` ab). `R.version.string` immer
enthalten.

**Testabdeckung**: neue `tests/testthat/test-provenance.R`, 8 Faelle
(Datei-Hash deterministisch/aendert sich bei Inhaltsaenderung,
Objekt-Hash, leerer Minimalaufruf, Trainings-/Test-Hashes, Config-Hash
UNABHAENGIG von Environment- vs. Listen-Eingabeform - dabei einen echten
Bug gefunden und gefixt: `as.list()` auf einem Environment hat KEINE
garantierte Reihenfolge, was `digest()` unterschiedliche Hashes fuer
inhaltlich identische Configs liefern liess, je nachdem ob als
Environment oder Liste uebergeben - Fix: Sortierung nach Namen vor dem
Hashen -, Feature-Set Klartext-vs.-Hash-Verzweigung, Resampling-Hash
haengt von der tatsaechlichen Fold-Zuweisung ab (zwei unabhaengig
instanziierte CV-Resamplings hashen unterschiedlich), Paketversions-
Format, End-to-End-Integrationstest gegen eine echte Test-DB via
`db_log_run_config()`). Volle Suite weiterhin gruen (jetzt 14
Testdateien). CI: `digest` zu `DESCRIPTION`s Imports UND zur
`unit-tests`-Job-`extra-packages`-Zeile hinzugefuegt.

**Bewusst kein Live-Demo in der echten `experiments.db`** (anders als
bei P1.2): Provenienzwerte muessen ZUM ZEITPUNKT eines echten Laufs
erfasst werden, nicht rueckwirkend an einen bereits abgeschlossenen
historischen Run angehaengt werden - das wuerde falsche Provenienz
vortaeuschen (z.B. einen "heutigen" Config-Hash an einen Lauf von vor
Wochen haengen). Echte Nutzung beginnt beim naechsten Aufruf von
`db_create_run()` in einem numerierten Skript, der `capture_run_provenance()`
tatsaechlich einbindet - das ist NICHT Teil dieses Prototyps (kein
bestehendes nummeriertes Skript wurde geaendert, analog zu
`validate_config()`/P0.3: ein manuell einzubindendes Werkzeug).

**Damit sind P1.1 (Prototyp), P1.2 (Schritt 1) und P1.3 aus ChatGPTs
korrigiertem Plan umgesetzt.** Nicht angefasst bleiben P2 (DB-Housekeeping-
Automatisierung, Classification-/Regression-Shared-Core-Analyse,
Environment-Reproduzierbarkeit) und P3 (Versionierung/Releases,
Publikationsbenchmark, hypothesengetriebene Modellpruefung) - nur nach
expliziter Nutzeranfrage weiterzuverfolgen.

## P2.1 - Status (2026-08-27)

**Ziel laut ChatGPTs korrigiertem Plan**: ein lokaler, rein lesender
Diagnose-Helfer `db_housekeeping_check()` fuer die zentrale, gemergte
Experiment-DB - zeigt letzte Merge-Zeit, Projekt-DBs mit Aenderungen,
fehlende Projekte, neue Runs, moegliche Duplikate, unvollstaendige Runs,
Runs ohne Git Commit, optional Backup-Anzahl/Speicherverbrauch. "Die
Diagnose darf keine DB veraendern. Ein tatsaechlicher Merge bleibt bewusst
explizit."

**Umgesetzt**: neue Datei `db_housekeeping.R` mit `db_housekeeping_check(
target = target_db_path, sources = NULL)`. Deckt alle im Plan genannten
Punkte ab: letzte Aenderung der Ziel-DB (Datei-mtime als Proxy fuer
"letzter Merge"), fehlende Projekte (lokal vorhanden, nie gemergt), neue
Runs (Projekt bereits gemergt, aber lokale `run_id`s, die die Ziel-DB noch
nicht kennt), moegliche Duplikate (mehrere `metric_result`-Zeilen fuer
dieselbe Model-Config/Metrik/Fold-Kombination - im Schema nicht per
Constraint verhindert), unvollstaendige Runs (`run_finished_at IS NULL`),
Runs ohne Git Commit, Backup-Anzahl/-Groesse. Gibt zusaetzlich zur
Konsolenausgabe eine Liste von `data.table`s zurueck (programmatisch
weiterverarbeitbar).

**Rein lesend GARANTIERT, nicht nur per Konvention**: beide
DB-Verbindungen (Ziel- und Quell-DBs) werden mit `flags = RSQLite::SQLITE_RO`
geoeffnet - ein versehentlicher Schreibversuch wuerde auf DB-Ebene
fehlschlagen, nicht nur "wir haben halt kein `dbExecute()` aufgerufen".

**`discover_source_db_paths()` + Pfad-Konstanten aus
`merge_project_experiments.R` HIERHER verschoben, nicht dupliziert** -
Diagnose und tatsaechlicher Merge muessen dieselben Projekte finden, sonst
drifted eine Kopie unbemerkt von der anderen auseinander (Analogie zu
`target_leak_audit_helpers.R`, P0.1). `merge_project_experiments.R`
sourced jetzt `db_housekeeping.R` statt die Logik selbst zu definieren -
Verhalten regressionsgetestet unveraendert (Syntax-Check + identisches
Discovery-Verhalten in `test-db_housekeeping.R`).

**Live gegen die echte zentrale DB verifiziert** (rein lesend, keine
Aenderung): fand 12 lokale Projekte, die noch nie gemergt wurden (u.a.
mehrere Regressions-Projekte - siehe Hinweis unten), 10 neue lokale Runs
bei `openml-credit-g`, 3 unvollstaendige Runs (abgebrochene Skripte), 129
Runs ohne Git Commit (aeltere Laeufe von vor der Commit-Protokollierung),
0 Duplikate, 9 Backup-Dateien mit 153.6 MB Gesamtgroesse (Hinweis auf
manuelles Aufraeumen ab >3 Backups). **Kein Merge wurde durchgefuehrt** -
das bleibt bewusst der explizite, separate Aufruf von
`merge_project_experiments.R`.

**Testabdeckung**: neue `tests/testthat/test-db_housekeeping.R`, 13
Faelle gegen frische, ueber `db_connect()`/`db_schema.sql` aufgebaute
Test-DBs (Discovery-Logik, jeder der 5 Befund-Typen einzeln, "saubere DB
meldet nichts", Fehlermeldung bei fehlender Ziel-DB, Read-Only-Garantie,
sowie ein dabei gefundener Randfall-Bug: `sub("\\.db$", ...)` auf einem
Zielpfad OHNE `.db`-Endung war ein No-op, wodurch `Sys.glob()` die
Ziel-DB-Datei selbst faelschlich als eigenes Backup gezaehlt haette -
in der Produktion nie sichtbar, da `experiments.db` immer auf `.db`
endet, aber ein echter Bug, der durch den Test mit einer `.sqlite`-Endung
sichtbar wurde - gefixt: Backup-Suche nur bei tatsaechlicher `.db`-Endung).
Volle Suite weiterhin gruen (jetzt 15 Testdateien).

**Nebenbefund, NICHT behoben (ausserhalb des Scopes von P2.1)**: unter den
12 "fehlenden Projekten" sind mehrere erkennbare REGRESSIONS-Projekte
(z.B. `WineQualityDataset`, `openml-diamonds-regression`,
`openml-house-prices-regression`, `playground-series-s5e9`) - das
bestehende, unveraendert uebernommene Discovery-Verhalten von
`merge_project_experiments.R` durchsucht `R_Workspace`/`ML_Learning`
projekt-typ-unabhaengig und wuerde diese beim naechsten Merge in die
KLASSIFIKATIONS-Ziel-DB einsortieren. Ob das gewollt ist (eine Datenbank
fuer alle mlr3-Projekte) oder ein latenter Bug (Regression sollte in
`MLR3_Regression`s eigene Ziel-DB gemergt werden), war nicht Teil dieser
Aufgabe und wird hier nur dokumentiert, nicht entschieden.

## Zielbild

Das Template soll nicht nur starke ML-Ergebnisse liefern, sondern als wiederverwendbare, überprüfbare und wartbare Basis für neue Classification-Projekte dienen.

Priorität hat dabei:

1. Korrektheit vor Komfort
2. Testbarkeit vor weiterer Komplexität
3. Reproduzierbarkeit vor zusätzlichen Features
4. Kleine, saubere Commits statt eines großen Refactors

## Arbeitsreihenfolge

Die Punkte werden strikt in dieser Reihenfolge abgearbeitet. Jeder Punkt soll erst abgeschlossen werden, bevor der nächste begonnen wird.

1. P0: Stabilisieren und absichern
2. P1: Kernlogik aus dem Template lösen und testbar machen
3. P2: Evaluation, Vergleichbarkeit und Nachvollziehbarkeit verbessern
4. P3: Aufräumen, dokumentieren, polieren

## Commit-Strategie

Es sollen mehrere kleine Commits entstehen, keine große Sammeländerung.

Empfohlene Reihenfolge:

1. `docs: add next steps for classification template`
2. `test: add deterministic core checks`
3. `refactor: extract classification helpers`
4. `test: extend outer-cv and leakage coverage`
5. `docs: clarify workflow and acceptance criteria`
6. `chore: cleanup template structure`

Regeln:

- Pro Commit nur ein klarer Themenblock.
- Erst Tests oder Dokumentation, dann Refactor.
- Keine fachliche Logik mit kosmetischen Änderungen mischen.
- Nach jedem Commit einmal die relevanten Tests ausführen.

## P0 - Stabilisieren und absichern

### Ziel

Die wichtigsten Template-Bausteine sollen deterministisch, fachlich geprüft und CI-sicher sein.

### Betroffene Dateien und Module

- `tests/testthat/`
- `tests/testthat.R`
- `DESCRIPTION`
- `.github/workflows/`
- `R/000_config.R`
- `R/`
- `_targets.R`

### Umsetzungsschritte

1. Eine klare Trennung zwischen Smoke-Tests und fachlichen Unit-Tests herstellen.
2. Für die zentralen Classification-Bausteine deterministische Tests anlegen:
   - Class-Multiplier / Threshold-Tuning
   - Ensemble Selection
   - Generalization Gap
   - Group Resampling
   - Leakage-Schutz
3. Alle Tests mit festen Seeds und kleinen synthetischen Datensätzen absichern.
4. CI so aufsetzen, dass Unit-Tests und Smoke-Test getrennt laufen.
5. Falls noch nicht vorhanden, minimale Fixture-Helfer für synthetische Daten ergänzen.

### Akzeptanzkriterien

- Alle Kernmechanismen haben mindestens einen fachlich aussagekräftigen Test.
- Tests laufen reproduzierbar und ohne manuelle Eingriffe.
- CI meldet getrennt, ob ein fachlicher Test oder nur ein Pipeline-Smoke-Test fehlschlägt.
- Kein Test hängt von externen Daten oder Zufallsergebnissen ohne Seed ab.

### Testanforderungen

- Neue Tests müssen klein, schnell und deterministisch sein.
- Jeder Test muss einen fachlichen Sollzustand prüfen, nicht nur "läuft durch".
- Für jeden neu angelegten Helper mindestens ein positiver Test und, wenn sinnvoll, ein Negativtest.

### Ergebnis von P0

Das Template ist abgesichert genug, um Refactors ohne stille Regressionen weiterzuführen.

## P1 - Kernlogik testbar machen

### Ziel

Die fachliche Logik soll aus dem schwer wartbaren Template-Kern in klar benannte, wiederverwendbare Funktionen wandern.

### Betroffene Dateien und Module

- `R/000_config.R`
- weitere `R/*.R`-Dateien, die aktuell mehrere Aufgaben mischen
- `R/classification/` falls das Repo so strukturiert wird
- `_targets.R`
- `tests/testthat/`

### Umsetzungsschritte

1. Die zentrale Konfigurations- und Methodenlogik in kleine Funktionen zerlegen.
2. Insbesondere diese Verantwortlichkeiten trennen:
   - Pfade und Projektkonfiguration
   - Modell- und Hyperparameter-Spezifikation
   - Threshold-Logik
   - Ensemble-Auswahl
   - Resampling-Strategie
   - Reporting / Diagnose
3. Jede Funktion so schneiden, dass sie einzeln testbar ist.
4. `_targets.R` nur als Orchestrierung nutzen, nicht als Ablage fachlicher Logik.
5. Lange Skripte in klar benannte Module überführen, ohne die bestehende Pipeline sofort komplett umzubauen.

### Akzeptanzkriterien

- Keine Datei erfüllt mehr mehrere Hauptrollen gleichzeitig.
- Die Logik ist in kleine, fachlich benannte Funktionen zerlegt.
- Jede neue Funktion hat einen direkten Test oder wird von einem bestehenden Test zuverlässig abgedeckt.
- Die Pipeline läuft nach dem Refactor identisch oder besser.

### Testanforderungen

- Nach jedem Extraktionsschritt alle betroffenen Unit-Tests ausführen.
- Für neue Helferfunktionen explizit Randfälle testen.
- Wo möglich, Snapshot-artige Prüfungen vermeiden und lieber konkrete fachliche Assertions verwenden.

### Ergebnis von P1

Das Template ist so strukturiert, dass weitere Verbesserungen nicht mehr in einem großen Monolithen landen.

## P2 - Evaluation und Nachvollziehbarkeit verbessern

### Ziel

Nicht nur Modelle, sondern der gesamte Auswahlprozess soll messbar und erklärbar werden.

### Betroffene Dateien und Module

- `tests/testthat/`
- `R/`
- `reports/` oder bestehende Ergebnis-Dokumentation
- `README.md`
- `vignettes/` falls vorhanden

### Umsetzungsschritte

1. Outer-/Nested-CV als Standardmaßstab für die Template-Bewertung nutzen.
2. Den vollständigen AutoML-Prozess auswerten:
   - Feature-Auswahl
   - Modellwahl
   - Tuning
   - Thresholds
   - Ensemble-Entscheidung
3. Einen klaren Vergleich zwischen Einzelkomponenten und Gesamtprozess anlegen.
4. Negative Befunde bewusst dokumentieren, statt sie zu entfernen.
5. Ein kurzes Ergebnisdokument oder eine kompakte Auswertung ergänzen, die den Entscheidungsweg erklärt.

### Akzeptanzkriterien

- Es gibt eine nachvollziehbare Bewertung des kompletten Templates auf ungesehenen Outer-Folds.
- Die Auswertung zeigt, welche Teile des Prozesses beitragen und welche kaum Mehrwert liefern.
- Dokumentation und Ergebnisse stimmen mit der realen Pipeline überein.

### Testanforderungen

- Evaluationscode muss auf kleinen Datenmengen reproduzierbar laufen.
- Jede neue Metrik braucht eine klare Definition und mindestens einen Konsistenztest.
- Kein stiller Methodikwechsel ohne dokumentierte Begründung.

### Ergebnis von P2

Die Qualität des Templates ist nicht nur gefühlt, sondern messbar beschrieben.

## P3 - Aufräumen, dokumentieren, polieren

### Ziel

Das Template soll für andere verständlich und angenehm nutzbar werden.

### Betroffene Dateien und Module

- `README.md`
- `docs/` oder bestehende Dokumentation
- `NAMESPACE` falls vorhanden
- `DESCRIPTION`
- `examples/` falls vorhanden

### Umsetzungsschritte

1. Die wichtigste Bedienlogik in der README klar erklären.
2. Die Trennung von Smoke-Test, Unit-Test und Evaluation sichtbar machen.
3. Kurz beschreiben, wie neue Projekte aus dem Template starten.
4. Unklare Namen, doppelte Inhalte und veraltete Hinweise entfernen.
5. Wenn sinnvoll, kleine Beispielpfade oder Minimalbeispiele ergänzen.

### Akzeptanzkriterien

- Neue Nutzer erkennen in wenigen Minuten, wie das Template gedacht ist.
- Die README beschreibt den realen Workflow, nicht den historischen Stand.
- Es gibt keine offensichtlichen Redundanzen oder veralteten Hinweise mehr.

### Testanforderungen

- Nach Dokumentationsänderungen mindestens den Haupt-Smoke-Test und die wichtigsten Unit-Tests laufen lassen.

### Ergebnis von P3

Das Template ist fachlich stark, technisch ordentlich und für andere nachvollziehbar.

## Konkrete Arbeitsregeln für Codex

1. Immer zuerst die betroffenen Dateien lesen, bevor Änderungen gemacht werden.
2. Nur eine Prioritätsstufe gleichzeitig anfassen.
3. Änderungen immer mit Tests absichern.
4. Nach jedem abgeschlossenen Teilpunkt einen eigenen Commit erstellen.
5. Wenn ein Test fehlschlägt, Ursache zuerst verstehen und nicht "drüberarbeiten".
6. Keine unmotivierten Umbauten an der Pipeline.
7. Wenn eine Datei aktuell mehrere Rollen hat, zuerst die Logik extrahieren, erst danach umbenennen.

## Empfohlene erste Ausführungsreihenfolge

1. `R/000_config.R` und die wichtigsten `R/*.R`-Dateien lesen
2. `tests/testthat/` und vorhandene CI-Definitionen lesen
3. P0-Tests ergänzen oder präzisieren
4. P0-Commits einzeln einchecken
5. Danach erst die Extraktion in P1 starten

## Kurzfassung

Wenn Codex nur eine Sache zuerst tun soll, dann diese:

1. Die fachlich wichtigsten Classification-Bausteine mit deterministischen Tests absichern.
2. Danach die Kernlogik aus dem Template-Monolithen in testbare Funktionen herauslösen.
3. Erst dann Evaluation und Dokumentation auf den finalen Stand bringen.
