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

## P2.2 - Status (2026-08-27)

**Ziel laut ChatGPTs korrigiertem Plan**: NICHT sofort einen gemeinsamen
Package-Core bauen - zuerst per Vergleichstabelle
(`Component | Classification | Regression | identical | candidate`)
ehrlich pruefen, welche von 9 genannten Komponenten (Experiment Logging,
DB Schema, Runtime Helpers, Resampling, Generalization Gap, Provenienz,
Config Validation, Evidence Registry, Artifact Management) tatsaechlich
identisch sind. Nur extrahieren, wenn reale Doppelpflege ein Problem
darstellt.

**Umgesetzt**: neue, reine Analyse-Datei `SHARED_CORE_ANALYSIS.md` -
**kein Code geaendert**, keine Extraktion durchgefuehrt. Methodik: jede
der 9 Komponenten wurde tatsaechlich gegen die entsprechende Datei in
`MLR3_Regression` diff't (nicht aus Erinnerung/Doku geschaetzt) -
Funktionsnamen verglichen, bei kleinen Diffs der komplette
Funktionskoerper Zeile fuer Zeile.

**Kernbefund**: nur 4 von 9 Komponenten existieren ueberhaupt in BEIDEN
Repos (Experiment Logging, DB Schema, Runtime Helpers, Resampling) - nur
dort ist "identisch vs. dupliziert" ueberhaupt eine sinnvolle Frage. Bei
diesen 4 ist der KERN tatsaechlich weitgehend identisch bis
byte-identisch (`set_group_role()` in `group_resampling.R` ist
byte-identisch, `run_timed_benchmark()` in `005_benchmark_runtime.R`
unterscheidet sich nur um 6 Zeilen, die 11 Kern-Tabellen in `db_schema.sql`
sind strukturell deckungsgleich, alle 18 gemeinsamen `db_logging.R`-
Funktionsnamen sind identisch). Die restlichen 5 Komponenten
(Generalization Gap, Provenienz, Config Validation, Evidence Registry,
Artifact Management) existieren bislang NUR in `MLR3_Classifikation`
(diese Woche als P0/P1/P2.1 entstanden) - dort gibt es nichts zu
deduplizieren, das ist stattdessen eine spaetere Backport-Frage, keine
Extraktions-Frage. Diese Unterscheidung stand nicht explizit im Plan und
wurde als methodischer Hinweis in der Analyse ergaenzt.

**Konkreter Beleg fuer echtes Doppelpflege-Risiko gefunden**: laut
eigenem Kopfkommentar in `MLR3_Regression/merge_project_experiments.R`
war diese Datei bis 2026-08-08 eine "unangepasste Kopie der
Klassifikations-Version" - `target_db_path` zeigte faelschlich auf die
KLASSIFIKATIONS-DB statt auf die eigene. Genau das Szenario, vor dem eine
Shared-Core-Extraktion schuetzen wuerde, und genau das im Plan geforderte
Kriterium ("nur wenn reale Doppelpflege ein Problem darstellt").
`db_logging.R`/`db_schema.sql` haben strukturell dasselbe Risikoprofil.

**Empfehlung (dokumentiert, NICHT umgesetzt)**: 3 Kandidaten fuer eine
spaetere, bewusste Extraktion, priorisiert nach Risiko/Aufwand -
`db_schema.sql`-Kern (risikoaermste, reine Struktur), `db_logging.R`-
Kernfunktionen (groesster potenzieller Schaden, aber aufwendigster
Umbau), `group_resampling.R`/`run_timed_benchmark()` (kleinster erster
Schritt). Keine dieser Extraktionen wurde in dieser Session begonnen -
der Plan verlangt ausdruecklich, erst bei einer KONKRETEN
Doppelpflege-Situation zu extrahieren, nicht prophylaktisch.

## P2.3 - Status (2026-08-27)

**Ziel laut ChatGPTs korrigiertem Plan**: mindestens einen belastbaren
Referenzpfad fuer Environment-Reproduzierbarkeit dokumentieren (Beispiel
im Plan: Ubuntu / R-Version X / `renv::restore()` / Unit Tests /
synthetic smoke fixture). "Keine erzwungene vollstaendige
Windows-`renv`-Migration."

**Umgesetzt**: neue, reine Doku-Datei `ENVIRONMENT.md` - **kein Code
geaendert, keine CI-Konfiguration geaendert.** Der geforderte Referenzpfad
existiert bereits vollstaendig als `.github/workflows/ci-smoke-test.yml`
(`unit-tests` + `smoke-test`-Jobs) - diese Session hat ihn nur explizit
als solchen benannt, mit einem konkreten Nachweis (CI-Lauf `33044016901`,
beide Jobs `success`, R 4.6.1 auf `ubuntu-24.04`) belegt und begruendet,
warum er trotz Abweichungen vom Plan-Beispiel gleichwertig ist:
- `r-version: release` statt einer festen Versionsnummer - bewusste
  Abwaegung (Synchronitaet mit aktuellen CRAN-Binaries vs. strikte
  Bit-fuer-Bit-Reproduzierbarkeit), fuer ein AutoML-TEMPLATE (kein
  zeitlich eingefrorenes Produktionsartefakt) der sinnvollere Kompromiss.
- `DESCRIPTION`+`r-lib/actions/setup-r-dependencies`(`pak`) statt
  `renv::restore()` - funktional aequivalent (deklarative Installation aus
  einem versionierten Manifest), `renv::restore()` war im Plan nur
  Beispiel, keine Vorgabe.

**Bewusst ausgelassen**: keine Windows-`renv`-Migration fuer die lokale
Entwicklungsumgebung (Rscript.exe unter `C:\Users\HP\Programme\R\...`) -
exakt wie vom Plan verlangt. Der Windows-Arbeitsplatz bleibt bewusst
ausserhalb dieses Referenzpfads.

**Damit ist P2 aus ChatGPTs korrigiertem Plan vollstaendig abgeschlossen**
(P2.1 `db_housekeeping_check()`, P2.2 Shared-Core-Analyse, P2.3
Environment-Referenzpfad-Dokumentation). Nur P3 (Versionierung/Releases,
Publikationsbenchmark, hypothesengetriebene Modellpruefung) bleibt aus dem
gesamten Plan unangetastet - nur nach expliziter Nutzeranfrage
weiterzuverfolgen.

## P3 - Status (2026-08-27)

**Ziel laut ChatGPTs korrigiertem Plan**: P3 hat 3 Checklisten-Punkte
("Versionierung/Releases vorbereiten", "Publikationsbenchmark
standardisieren", "neue Modellfamilien nur noch hypothesengetrieben
pruefen"), aber nur der DRITTE Punkt ist im Plan-Dokument mit einer
konkreten Checkliste ausgefuehrt (Hypothese, Datensatztyp, Baseline,
Primaermetrik, Diversitaetsmetrik, Laufzeitbudget, Abbruchkriterium,
Backport-Kriterium). Die ersten beiden bleiben im Plan-Dokument OHNE
Detailausfuehrung.

**Scope-Entscheidung**: per Rueckfrage an den Nutzer (unbeantwortet)
mit der empfohlenen Option fortgefahren - NUR den klar spezifizierten
dritten Punkt umgesetzt. "Versionierung/Releases vorbereiten" und
"Publikationsbenchmark standardisieren" bleiben UNANGETASTET, bis der
Nutzer sie konkretisiert (der Plan selbst liefert dafuer keine
verwertbare Spezifikation - ein Umsetzungsversuch ohne Konkretisierung
haette geraten statt spezifiziert).

**Umgesetzt**: neue, reine Doku-Datei `MODEL_HYPOTHESIS_CRITERIA.md` -
kodifiziert eine Regel, die dieses Projekt bereits informell befolgt hat
(kein neues Verhalten, nur explizit aufgeschrieben). 8 Pflichtpunkte vor
jedem neuen Modellkandidaten-Test (Hypothese/Datensatztyp/Baseline/
Primaermetrik/Diversitaetsmetrik+Schwelle/Laufzeitbudget inkl.
Smoke-Test-Vorabverifikation/Abbruchkriterium/Backport-Kriterium via
Verweis auf `adr/003-backport-after-confirmation.md`). Mit einer
Beispieltabelle retroactiv gegen 4 bereits gelaufene Tests dieser Woche
(TabPFN, TabM, Hyperband - alle negativ; Multi-Layer Stacking - positiv,
ADR-003-Schwelle erreicht) gefuellt, um zu zeigen, wie ausgefuellte
Kriterien aussehen, statt nur abstrakt zu bleiben.

**Damit ist aus ChatGPTs korrigiertem Plan alles umgesetzt, was das
Dokument selbst konkret spezifiziert hat** - P0 (vollstaendig), P1.1
(Prototyp), P1.2 (Schritt 1 von 3), P1.3, P2.1-P2.3, sowie der
spezifizierte Teil von P3. Offen bleiben ausschliesslich die zwei nicht
naeher spezifizierten P3-Punkte (Versionierung/Releases,
Publikationsbenchmark) sowie P1.2s Schritte 2/3 (historisches Nachtragen,
automatische Generierung) - alle vier bewusst nicht angefasst, bis der
Nutzer sie konkret anfordert.

## Git-Tags pro Backlog-Meilenstein (2026-08-27, "Versionierung/Releases")

Konkretisierung des Nutzers fuer den bislang unspezifizierten P3-Punkt
"Versionierung/Releases vorbereiten": **ein annotierter Git-Tag pro
erledigtem Backlog-Meilenstein**, gesetzt auf den Commit, der den
jeweiligen Meilenstein abschliesst (nicht auf spaetere Folge-Commits wie
Statusanker-Updates). Kein semantisches Versionsschema (`v1.2.3`) - dieses
Template hat keine Versionsnummer im klassischen Sinn (kein installierbares
Paket, siehe `DESCRIPTION`-Kopfkommentar), sondern fortlaufende
Meilensteine. Tag-Namensschema: `backlog-<punkt>` (z.B. `backlog-p1.2`),
bei P3-Teilpunkten ohne Nummer ein sprechendes Suffix (z.B.
`backlog-p3-hypothesis-criteria`).

**Zweck**: ein `git checkout <tag>` bringt den exakten Stand direkt nach
Abschluss eines Meilensteins zurueck - nuetzlich, um z.B. "wie sah das
Repo aus, bevor P1.2 dazukam" zu beantworten, ohne Commit-Hashes aus
`BACKLOG.md`-Prosa heraussuchen zu muessen.

**Rueckwirkend gesetzt** fuer alle in dieser Session abgeschlossenen
Meilensteine (Tag -> Commit):

| Tag | Commit | Meilenstein |
|---|---|---|
| `backlog-p0` | `9914c44` | P0 komplett (P0.1 Testabdeckung, P0.2 Helper-Haertung, P0.3 `validate_config()`) |
| `backlog-p1.1` | `af154a0` | P1.1-Prototyp (Full-Workflow Outer Evaluation) |
| `backlog-p1.2` | `c51c45d` | P1.2 Schritt 1 (Evidence Registry) |
| `backlog-p1.3` | `b37fbc8` | P1.3 (Experiment-/Daten-Provenienz) |
| `backlog-p2.1` | `0bdc776` | P2.1 (`db_housekeeping_check()`) |
| `backlog-p2.2` | `04f810f` | P2.2 (Shared-Core-Analyse) |
| `backlog-p2.3` | `fb0c244` | P2.3 (Environment-Referenzpfad-Doku) |
| `backlog-p3-hypothesis-criteria` | `96051c2` | P3, spezifizierter Teil (Modell-Hypothesen-Kriterien) |

**Ab jetzt laufend**: nach jedem zukuenftigen abgeschlossenen
Backlog-Meilenstein wird direkt nach dem finalen Commit (vor dem naechsten
Punkt) ein neuer annotierter Tag gesetzt und gepusht - Teil des
`backlog-item-workflow`-Skills, nicht ein separat anzustossender Schritt.

## P1.2 Schritt 2 - Status (2026-08-27): historisches Nachtragen

**Nutzeranfrage**: "wir sollten die Historie nachtragen d.h. migrieren"
- konkretisiert den bislang vertagten Schritt 2 aus ChatGPTs 3-Schritte-
Vorgehen fuer die Evidence Registry ("wichtige historische Befunde
nachziehen").

**Umgesetzt**: neues, einmaliges Migrations-Skript
`migrate_systematic_evaluation_to_evidence.R` (Repo-Wurzel, kein Teil der
nummerierten Pipeline, analog zu `merge_project_experiments.R`) - liest
die grosse Projekt-x-Modul-Tabelle aus `SYSTEMATIC_EVALUATION.md` (Stand
"alle Zellen aufgeloest", 2026-08-15) und loggt jede Zelle mit einem
echten Legenden-Symbol (✓/✓✓/~/✗) als eigene `evidence`-Zeile via
`db_log_evidence()`.

**Scope-Entscheidung (bewusst getroffen, nicht nachgefragt)**: `—`-Zellen
(strukturelle Nicht-Anwendbarkeit - das Modul existiert schlicht nicht im
jeweiligen Projektordner) wurden NICHT migriert - das waeren >140
inhaltsleere Zeilen gewesen, kein Befund im Sinn von "wichtige historische
Befunde". Numerische Werte (AUC, BAcc, Prozentsaetze, z-Werte) wurden
NICHT automatisiert aus dem Fliesstext in
`evid_baseline_value`/`evid_result_value`/`evid_delta` geparst - bei
uneinheitlicher Prosa (unterschiedliche Metriken, mal ein, mal zwei Werte
pro Zelle) waere das fehleranfaellig gewesen und haette stillschweigend
falsche Zahlen erzeugt. Stattdessen bleibt der urspruengliche Zellentext
(leicht gekuerzt um reine Klammer-Boilerplate) vollstaendig als `notes`
erhalten - durchsuchbar, aber nicht falsch-praezise.

**Rollen-/Status-Zuordnung** (fest je Spalte/Symbol): Leak-Audit (015),
Adversarial Validation (115), Split-Size-Sensitivity (022),
Learning-Curve (023), Seed-Stabilitaet (092), Generalisierungsluecke
(136) -> `trust_gate`; Ensemble Selection (148/149), Threshold-Tuning
(130) -> `score_lever`; Multi-Label-Workflow (021) -> `workflow_automation`.
✓ -> `confirmed`, ✓✓ -> `core_finding`, ~ -> `neutral`, ✗ -> `negative`.

**Ergebnis**: 56 Zeilen migriert (manuell aus der Tabelle abgezaehlt und
programmatisch bestaetigt - Uebereinstimmung), Verteilung: 47
`confirmed`, 6 `core_finding` (u.a. der CreditScoringChallenge-Leak, der
geoai-Adversarial-Validation-Fund, `health_condition`s Ensemble-Selection-
UND Threshold-Tuning-Kernbefunde, `s6e8`s Live-Kaggle-Bestaetigung, der
wdbc-plateau-test-Plateau-Fund), 2 `negative` (s6e5/s5e12s abgelehnte
Ensemble-Alternativen), 1 `neutral` (s5e12s strukturell uebersprungenes
Threshold-Tuning). `evidence_source` einheitlich auf
"SYSTEMATIC_EVALUATION.md (historischer Backfill, P1.2 Schritt 2,
2026-08-27)" gesetzt, damit die Migration in der Registry selbst als
eigene, unterscheidbare Charge erkennbar bleibt.

**`SYSTEMATIC_EVALUATION.md` selbst bleibt unveraendert** - dieses
Skript kopiert Befunde IN die Registry, ersetzt die Markdown-Tabelle
nicht (das waere Schritt 3, automatische Generierung, weiterhin nicht
umgesetzt).

## Naechste Bewertung 2026-08-28 (extern, neue Roadmap Phase A-E)

Neues externes Bewertungsdokument vom Nutzer eingebracht:
`AutoML_Aktuelle_Bewertung_und_Naechste_Schritte_fuer_Claude_2026-08-28.md`
(`~/Downloads`, nicht Teil dieses Repos - dieser Abschnitt haelt die
relevanten Punkte dauerhaft im Repo fest). Gesamtnote 9.6/10 als
persoenliches ML-System, 9.3/10 Workshop-/Software-Paper-Reife, 8.1/10
staerkeres Research-Paper (fehlt: keine neue Methode, sondern eine breite
Full-Workflow Outer Evaluation).

**3 groesste Hebel** (Prioritaet laut Dokument):
1. **Full-Workflow Outer Evaluation verbreitern** (P0 wissenschaftlich) -
   P1.1-Prototyp (1 Datensatz, 3 Outer Folds) auf 5-8 bewusst diverse
   Datensaetze uebertragen (binaer ausgeglichen/unausgeglichen,
   multiclass, klein/gross, Drift, Group-/Time-Struktur). Fester
   Metrik-Satz je Datensatz (Primaermetrik, Outer-Score Mittel/SD/
   schlechtester Fold, Baselines, Laufzeit, gewaehltes Modell,
   Trust-Findings, manuelle Entscheidungen).
2. **DB-Domain-Grenzen + Provenienz schliessen** (P0 technisch) - vor dem
   naechsten zentralen Merge klaeren, welche Projekt-DB zu Classification
   vs. Regression gehoert (deckt sich mit dem P2.2-Nebenbefund); zusaetzlich
   `capture_run_provenance()` standardmaessig in neue echte Runs einbinden
   (NICHT rueckwirkend historische Runs nachbessern).
3. **Evidence Registry zur Source of Truth machen** (P1) - P1.2 Schritt 3:
   `SYSTEMATIC_EVALUATION.md` aus der Registry generieren statt manuell
   pflegen.

**Vorgeschlagene Reihenfolge (Phasen A-E)**: A) Dokumentation korrigieren +
DB-Domain-Trennung (guenstig, zuerst); B) Provenienz operationalisieren;
C) wissenschaftlicher Hauptblock (5-8-Datensatz-Outer-Evaluation); D)
Evidence-Registry-Generator (P1.2 Schritt 3); E) Publikationsvorbereitung
(Benchmark-Protokoll einfrieren, Ablationsstudien).

**Nutzerentscheidung (2026-08-28)**: Start mit **Phase A**.

### Phase A - Status (2026-08-28)

1. ~~README-Testbeschreibung aktualisieren~~ **ERLEDIGT** - `README.md`
   erwaehnte bislang nur den CI-Smoke-Test, nicht die inzwischen
   umfangreiche `testthat`-Suite (15+ Testdateien). Ergaenzt.
2. ~~AGENTS-Publikationsstatus korrigieren~~ **ERLEDIGT** - `AGENTS.md`
   sagte faelschlich, es fehle "eine breite systematische Evaluation"
   (die MODULWEISE Evaluation ist laengst abgeschlossen, siehe
   `SYSTEMATIC_EVALUATION.md`). Korrigiert: fehlt ist stattdessen eine
   BREITE Full-Workflow Outer Evaluation (Hebel 1 oben).
3. ~~Classification-/Regression-DB-Discovery sauber trennen~~
   **ERLEDIGT** - neue Funktionen `detect_problem_type(db_path)` und
   `discover_source_db_paths_by_type(..., expected_type)` in
   `db_housekeeping.R`. Aufgabentyp wird aus den BEREITS geloggten
   Metrik-Praefixen (`classif.*` vs. `regr.*` in `metric_result`)
   abgeleitet - rein lesend, kein neues Feld noetig, funktioniert
   rueckwirkend fuer alle historischen Projekt-DBs.
   **Akzeptanzkriterium erfuellt**: `merge_project_experiments.R` nutzt
   jetzt `discover_source_db_paths_by_type(..., expected_type =
   "classification")` statt der ungefilterten Variante - ein
   Classification-Merge kann kein als Regression erkanntes Projekt mehr
   aufnehmen.
   **Bug beim ersten Testlauf gefunden+gefixt**: eine anfaengliche
   "unknown -> ausschliessen"-Regel haette mehrere ECHTE Multi-Label-
   Classification-Projekte (`openml-yeast-multilabel` u.a.) dauerhaft aus
   jedem Merge geworfen, weil deren `metric_result`-Tabelle nur einen
   fachfremden `weather_balloon_check.R`-Sanity-Wert enthaelt, keine
   `classif.*`-Zeile. Korrigiert: ausgeschlossen wird NUR bei einem
   POSITIVEN Nachweis des JEWEILS ANDEREN Typs; "unknown"/"mixed" werden
   inkludiert, aber ueber ein `needs_review`-Attribut fuer manuelle
   Pruefung markiert (falsch-negativer Ausschluss eines echten Projekts
   waere schlimmer als ein zu vorsichtiger Einschluss).
   **Live-Ergebnis gegen die echten Projekt-DBs** (rein lesend): von 27
   gefundenen Quell-DBs wurden 23 als `classification` behalten, 4 korrekt
   als `regression` ausgeschlossen (`openml-diamonds-regression`,
   `openml-house-prices-regression`, `playground-series-s5e9`, `tweet` -
   deckt sich mit dem P2.2-Nebenbefund), `WineQualityDataset` als
   `unknown`/`needs_review` markiert (nicht automatisch entschieden).
   6 neue Testfaelle in `test-db_housekeeping.R` (u.a. eine direkte
   Nachbildung des gefundenen Multi-Label-Bugs als Regressionstest).
4. ~~DB-Housekeeping-Check erneut laufen lassen~~ **ERLEDIGT** - unveraendert
   ggue. dem P2.1-Stand (12 nie gemergte Projekte, 10 neue Runs bei
   `openml-credit-g`, 3 unvollstaendige Runs, 129 Runs ohne Git Commit, 9
   Backups/153.6 MB) - erwartungsgemaess, da noch kein Merge stattfand.

### Phase B - Status (2026-08-28): Provenienz operationalisieren

5. ~~`capture_run_provenance()` in neue normale Runs integrieren~~
   **ERLEDIGT** - statt aller ~30 aufrufenden Skripte einzeln anzupassen
   (Big-Bang-Refactoring, vom Bewertungsdokument selbst als NICHT
   priorisiert markiert, siehe Abschnitt 10 dort), wurde EIN zentraler
   Aufrufpunkt geaendert: `db_create_run()` (db_logging.R) - von JEDEM
   Skript bereits verwendet - loggt jetzt standardmaessig
   (`log_baseline_provenance = TRUE`, neuer Parameter, Default `TRUE`)
   die immer verfuegbaren Provenienz-Felder (R-Version,
   Paketversionen) automatisch via `capture_run_provenance()` +
   `db_log_run_config()`. Trainings-/Testdaten-Hashes, Config-Hash,
   Resampling-Hash und Feature-Set bleiben bewusst OPT-IN (muessen vom
   aufrufenden Skript explizit nachgereicht werden, da sie zum Zeitpunkt
   von `db_create_run()` - meist der erste DB-Aufruf eines Skripts - noch
   nicht bekannt sind). `provenance.R` wird bei Bedarf lazily
   nachgesourced (`source(file.path(project_dir, "provenance.R"))`), ein
   Fehlschlag (z.B. fehlendes `digest`-Paket oder fehlende Datei, siehe
   naechster Punkt) fuehrt zu einer WARNUNG, nicht zum Abbruch des
   aufrufenden Skripts.
   **Verifiziert**: die CI-Smoke-Test-Fixture (`ci_smoke_test/`) hat
   BEWUSST kein eigenes `provenance.R` (nicht Teil der kopierten
   Kernskripte-Liste) - lokal simuliert (Kopie von `db_logging.R`/
   `db_schema.sql` in den Fixture-Ordner, `db_create_run()` dort
   aufgerufen): degradiert sauber zu einer Warnung, `run_config` bleibt
   leer, KEIN Absturz. Das war der wichtigste Verifikationsschritt vor
   dem Push, um einen CI-Smoke-Test-Ausfall durch diese Aenderung
   auszuschliessen.
6. ~~Tests dafuer ergaenzen~~ **ERLEDIGT** - 2 neue Faelle in
   `test-db_logging.R` (Default-Verhalten loggt `provenance.r_version`/
   `provenance.packages`; `log_baseline_provenance = FALSE` schaltet es
   ab). EIN bestehender Test musste angepasst werden (`db_log_run_config()
   loggt jeden Eintrag als eigene Zeile` erwartete einen EXAKTEN
   `run_config`-Zeilensatz - explizit `log_baseline_provenance = FALSE`
   gesetzt, um Vermischung mit den neuen automatischen Provenienz-Zeilen
   zu vermeiden). Volle Suite weiterhin gruen (15 Testdateien, jetzt mit
   2 zusaetzlichen Faellen).
7. CI gruen verifizieren - siehe Commit/Push-Protokoll unten.

**Bewusst NICHT umgesetzt** (ausserhalb des Hebel-2B-Scopes, siehe
`provenance.R`s Kopfkommentar): rueckwirkendes Nachbessern historischer
Runs mit Provenienz - explizit vom Bewertungsdokument ausgeschlossen
("Nicht rueckwirkend historische Runs 'nachbessern'").

### Phase C - Status (2026-08-28): Outer Evaluation auf 7 Datensaetze/Kategorien

**Sprachliche Praezisierung (2026-08-29, siehe
[`EVALUATION_LEVELS.md`](EVALUATION_LEVELS.md))**: alles unten
Beschriebene ist **Level 1 (Component Workflow)** - gewichtetes Training
+ ggf. Multiplier-Korrektur. "Full-Workflow"/"der Workflow generalisiert"
in den urspruenglichen Formulierungen unten meinte immer schon genau
das, war aber sprachlich unpraezise (klang nach dem kompletten AutoML-
Entscheidungsprozess). Nicht Teil dieser Evaluation: Leak-Audit, Feature
Engineering, vollstaendige Modellwahl, Ranger-/LightGBM-Tuning, Ensemble
Selection - all das laeuft im echten Projekt-Workflow, aber NICHT
innerhalb der Outer-CV-Schleife selbst. Level 2/3 sind eigene, noch
offene Roadmap-Punkte.

**Punkte 8+9 (Datensaetze definieren + Auswahl begruenden)**: statt neuer
Datensaetze werden bewusst BEREITS ERKUNDETE Projekte aus diesem Templates
eigener Historie wiederverwendet (kein neues Setup-Risiko, Balance/Groesse/
Shift-Eigenschaften bereits bekannt). 7 Kategorien (A-G laut Bewertungsdok.)
-> 7 Projekte, `health_condition` wird als bereits vorhandener P1.1-
Prototyp WIEDERVERWENDET (kein Rerun):

| Kategorie | Projekt | Begruendung |
|---|---|---|
| A. binaer, ausgeglichen* | `openml-credit-g` | binaer, BAcc-primaer, moderat unausgeglichen (~70/30) |
| B. binaer, unausgeglichen | `CreditScoringChallenge` | ~1.8% positive Klasse, extrem unausgeglichen |
| C. multiclass | `health_condition` | **wiederverwendet aus P1.1**, kein Rerun |
| D. kleiner Datensatz | `wdbc-plateau-test` | klassisch klein, sauber trennbar |
| E. groesserer Datensatz | `PumpItUp` | ~59k Zeilen, 3 Klassen |
| F. Covariate Shift | `geoai-aquaculture-pond-identification-challenge` | bereits bestaetigter extremer Shift (AUC 0.99998) |
| G. Group-/Time-Struktur | `openml-eeg-eye-state-timeseries` | Time-Block-Struktur, Group-CV-Effekt bereits gezeigt |

\* Kein Projekt in der Historie ist ein textbuchmaessig EXAKT 50/50
balanciertes binaeres Problem - `openml-credit-g` (70/30) ist die
naechstliegende verfuegbare Naeherung; real-world-Datensaetze sind selten
exakt balanciert, die Kategorien sollen Diversitaet abbilden, keine
akademische Reinheit.

**Nutzerentscheidung zur Ausfuehrung**: alle 6 neuen Laeufe nacheinander im
Hintergrund, laufende Rueckmeldung statt Einzelbestaetigung je Datensatz.

**Notwendige Generalisierung VOR der Ausfuehrung** (waehrend der Vorbereitung
entdeckt, nicht Teil des urspruenglichen P1.1-Scripts): der P1.1-Prototyp
war fest auf `health_condition` (BAcc-primaer, `class_multiplier_tuning.R`
vorhanden) zugeschnitten. Eine Pruefung der 6 Zielprojekte zeigte zwei
strukturelle Unterschiede, die eine 1:1-Kopie unehrlich gemacht haetten:
- `predictingsmartphoneAddiction_s6e8` (urspruenglich fuer Kategorie A
  vorgesehen) und `geoai-aquaculture...` sind AUC-/F-beta-primaer
  (schwellenwertunabhaengig) - bei diesen Projekten fehlt
  `class_multiplier_tuning.R` im Projektordner UEBERHAUPT, weil
  Multiplier-Tuning fuer eine Rangfolgen-Metrik methodisch nicht greift
  (bereits so in `SYSTEMATIC_EVALUATION.md` dokumentiert: "Threshold-
  Tuning strukturell uebersprungen"). Ein hartkodierter BAcc-Score
  (wie im P1.1-Original) haette bei diesen Projekten die FALSCHE Metrik
  optimiert/verglichen.
- `CreditScoringChallenge` und `PumpItUp` haben ebenfalls KEIN
  `class_multiplier_tuning.R` im Ordner, obwohl BAcc-primaer - der reale
  Workflow dieser Projekte nutzt klassengewichtetes Training OHNE
  Multiplier-Schritt.

**Deshalb**: neue, generalisierte Skript-Fassung (`outer_workflow_evaluation.R`,
je Zielprojekt kopiert, Datei-Kern identisch) mit 3 statt 4 Vergleichs-
Armen:
1. `ranger_default`, 2. `lightgbm_default` (unveraendert ggue. P1.1), 3.
`workflow_ranger` - klassengewichtetes Training (`class_weight_power` aus
dem jeweiligen `000_config.R`), ERGAENZT um Multiplier-Tuning NUR wenn
BEIDE Bedingungen gelten: `class_multiplier_tuning.R` existiert im
Projektordner UND die Primaermetrik ist schwellenwertABHAENGIG
(`is_threshold_independent_metric()`, db_logging.R). Scoring generisch
ueber `msr(tuning_measure_id)$score()` statt hartkodiertem
`mlr3measures::bacc()` - funktioniert korrekt fuer jede Primaermetrik.

**Der `lightgbm_tuned`-Arm aus P1.1 ist HIER BEWUSST WEGGELASSEN** - er
zeigte im P1.1-Prototyp keinen Vorteil ggue. Default-LightGBM (konsistent
mit der bereits dokumentierten Hyperband-Erfahrung dieses Templates) und
war mit Abstand der teuerste Arm (~5 Min./Fold). Eine bereits negativ
beantwortete Frage 6x zu wiederholen haette Rechenzeit gekostet, ohne
neue Information zu liefern - das spart bei 6 Datensaetzen mehrere
Stunden Laufzeit.

**Punkte 10-12 (Ausfuehrung, Baselines/Laufzeiten erfassen, in Evidence
Registry loggen)**: alle 6 Laeufe abgeschlossen (Skripte + Ergebnisse
liegen in `ML_Learning/<projekt>/outer_workflow_evaluation.R`, jeweils
eigener lokaler Commit dort - `ML_Learning` ist ein rein lokales Repo
ohne Remote). Zwei Skript-Anpassungen waehrend der Ausfuehrung noetig
(aeltere Projekte ohne die spaeteren Konventionen): `CreditScoringChallenge`/
`PumpItUp` nutzen einen fest kodierten Task-Pfad statt
`task_train_small_path`, `geoai-aquaculture...`/`PumpItUp` hatten kein
`class_weight_power` gesetzt - beides per Fallback im jeweiligen
Skript nachgereicht (Default `1.5`, Template-Konvention), keine
Aenderung an den Projekten selbst. Alle 7 Ergebnisse in die zentrale
Evidence Registry geloggt (`db_log_evidence()`, Projekt-DB von
`health_condition`, `evidence_source = "outer_workflow_evaluation.R
(Phase C, generalisierte Fassung)"`).

**Gesamtergebnis (7 Datensaetze/Kategorien, `workflow_ranger` vs. beste
Baseline)**:

| Kategorie | Projekt | Metrik | Baseline (beste) | workflow_ranger | Delta |
|---|---|---|---|---|---|
| C multiclass | `health_condition` (P1.1) | BAcc | 0.8745 | **0.9480** | **+8.5** |
| A binaer, moderat unausgeglichen | `openml-credit-g` | BAcc | 0.6603 | **0.7092** | **+4.9** |
| D klein | `wdbc-plateau-test` | BAcc | 0.9677 | **0.9727** | **+0.5** |
| G Group/Time | `openml-eeg-eye-state-timeseries` | BAcc | 0.9339 | 0.9323 | -0.2 |
| F Covariate Shift | `geoai-aquaculture...` | AUC | 0.9971 | 0.9957 | -0.1 |
| E groesser | `PumpItUp` | Accuracy | 0.8111 | 0.7428 | **-6.8** |
| B binaer, extrem unausgeglichen | `CreditScoringChallenge` | F-beta | 0.3953 | **0.1088** | **-28.7** |

**Wichtigster uebergreifender Befund (als eigener `cross-project`-Evidence-
Eintrag geloggt, `core_finding`)**: der klassengewichtete `workflow_ranger`-
Arm **gewinnt oder haelt mindestens mit** bei allen 4 BAcc-primaeren
Aufgaben (klar vorn bei 3, minimal hinter LightGBM aber vor Default-
Ranger bei der 4.). Er **faellt drastisch ab** bei den beiden
Accuracy-/F-beta-primaeren Aufgaben, die KEINEN begleitenden Multiplier-/
Schwellenwert-Korrekturschritt hatten (`class_multiplier_tuning.R` fehlt
in beiden Projektordnern). Bei der AUC-primaeren Aufgabe (schwellenwert-
unabhaengig, Multiplier-Tuning entfaellt strukturell) liegt er nahe an
Default-Ranger, leicht hinter LightGBM.

**Erklaerung**: BAcc belohnt Pro-Klasse-Balance - genau das Ziel von
`add_balanced_class_weights()`. Accuracy/F-beta belohnen dagegen
Mehrheits-/Positiv-Klassen-Performance - das GEGENTEIL. Ohne einen
Korrekturschritt (Multiplier-/Threshold-Tuning), der das wieder
ausgleicht, uebersteuert die Gewichtung bei diesen Metriken. Bei
`health_condition` (mit Multiplier-Tuning) und `openml-credit-g` (auch
mit Multiplier-Tuning) UND `wdbc-plateau-test` (OHNE Multiplier-Tuning,
aber BAcc-primaer) hilft reine Gewichtung bereits/zusaetzlich; bei
`CreditScoringChallenge`/`PumpItUp` (Accuracy/F-beta-primaer, OHNE
Multiplier-Tuning) schadet sie deutlich.

**Wichtige Einschraenkung fuer die Trust-/Publikations-Story** (siehe
Bewertungsdokument Abschnitt 15): "der Workflow generalisiert" gilt NICHT
pauschal - er generalisiert MIT einer zur Zielmetrik passenden
Korrekturkette (Gewichtung + Multiplier/Threshold), NICHT mit
Gewichtung allein. Das ist kein Rueckschritt gegenueber dem P1.1-
Befund, sondern eine noetige Praezisierung: P1.1 testete nur EIN
Projekt, bei dem zufaellig beide Zutaten (BAcc + Multiplier-Tuning)
vorhanden waren - die Breite von Phase C deckt jetzt eine echte
Grenzbedingung auf, die mit nur einem Datensatz unsichtbar geblieben
waere. Das ist genau der Wert einer breiteren Outer Evaluation, den das
Bewertungsdokument als Hebel 1 einfordert.

**Naechster moeglicher Schritt (nicht Teil dieser Phase)**: pruefen, ob
das Nachruesten eines Multiplier-/Threshold-Korrekturschritts bei
`CreditScoringChallenge`/`PumpItUp` den Abfall behebt - das waere ein
eigener, gezielter Test (P3-Hypothesenkriterien anwenden:
Hypothese/Baseline/Metrik/Abbruchkriterium vorab definieren), nicht
automatisch Teil von Phase C.

**Nachpruefung durchgefuehrt (2026-08-28, auf Nutzeranfrage "machen wir
die Nachprüfung")**: neues `multiplier_correction_check.R` in beiden
Projekten (`ML_Learning`, lokale Commits) - 4. Arm
`workflow_ranger_multiplier`, identische Outer-Folds/Seed wie Phase C,
Multiplier-Korrektur diesmal gegen die ECHTE Primaermetrik optimiert
(F-beta/Accuracy statt BAcc, `class_multiplier_tuning.R` aus
`MLR3_Classifikation` in beide Projekte kopiert, da dort urspruenglich
nicht vorhanden). Nach dem P3-Hypothesenschema definiert (Hypothese/
Baseline/Metrik/Abbruchkriterium vorab, siehe
`ML_Learning/<projekt>/multiplier_correction_check.R`-Kopfkommentar).

**Ergebnis - unterschiedlich starke Erholung**:

| Projekt | ohne Multiplier | mit Multiplier | Baselines | Erholung |
|---|---|---|---|---|
| `CreditScoringChallenge` (F-beta, ~1.8% positiv) | 0.1088 | **0.2832** | 0.3628 / 0.3953 | Teilweise (+0.174, fast verdreifacht, aber weiterhin klar unter beiden Baselines) |
| `PumpItUp` (Accuracy, ~7% Minderheit) | 0.7428 | **0.8047** | 0.8111 / 0.8039 | Fast vollstaendig (+0.062, praktisch gleichauf mit lightgbm_default) |

**Interpretation**: die Multiplier-Korrektur hilft in BEIDEN Faellen
deutlich - bestaetigt den Mechanismus (die Multiplikatoren fuer die
Minderheitsklasse(n) sinken auf 0.06-0.17, nehmen die urspruengliche
Uebergewichtung fast vollstaendig zurueck). Der GRAD der Erholung haengt
aber sichtbar von der Extremitaet der Klassenschieflage ab - bei
`PumpItUp` (~7% Minderheit) nahezu vollstaendige Korrektur, bei
`CreditScoringChallenge` (~1.8%, deutlich extremer) nur teilweise. Das
ist eine WEITERE Praezisierung, keine Umkehr des Phase-C-Kernbefunds:
"der Workflow generalisiert MIT einer zur Zielmetrik passenden
Korrekturkette" stimmt nach wie vor - die Korrekturkette funktioniert,
ihre Wirksamkeit ist aber selbst wieder von der Datensatz-Charakteristik
abhaengig (Grad der Klassenschieflage), nicht binaer "behoben/nicht
behoben". Beide Befunde in die Evidence Registry geloggt.

### Phase D - Status (2026-08-28): Evidence Registry als Quelle fuer die Ergebnistabelle

**Ziel laut Bewertungsdokument (Punkte 13-15)**: `SYSTEMATIC_EVALUATION.md`
aus der Evidence Registry generieren, manuelle Doppelpflege beenden,
Publikations-Tabellen aus der Registry erzeugen (P1.2 Schritt 3, bislang
bewusst vertagt).

**Umgesetzt**: neue Datei `generate_systematic_evaluation.R` mit
`build_systematic_evaluation_pivot(con)` (Projekt x Modul, breites
Format, mehrere Eintraege je Zelle werden mit "; " zusammengefasst statt
einander zu ueberschreiben), `render_systematic_evaluation_markdown(con)`
(Markdown-Tabelle, bekannte 9 Original-Module zuerst, alles Weitere
alphabetisch danach) und `generate_systematic_evaluation_file(con,
out_path)`. Ausgabe: neue Datei
[`SYSTEMATIC_EVALUATION_GENERATED.md`](SYSTEMATIC_EVALUATION_GENERATED.md).

**Scope-Entscheidung (additiv, NICHT die bestehende Datei ersetzt)**: die
generierte Tabelle ERSETZT `SYSTEMATIC_EVALUATION.md` NICHT - die
handgepflegte Datei enthaelt redaktionelles Material (Fussnoten,
Korrekturvermerke wie die IQR-Nenner-Korrektur, einen ganzen
Diskussionsabschnitt "Was diese erste Fassung zeigt"), das eine reine
DB-Pivot-Tabelle strukturell nicht abbilden kann. Ein einmaliges
Ueberschreiben in diesem Schritt haette dieses Material unwiederbringlich
verloren. Stattdessen: ein Hinweis am Kopf von `SYSTEMATIC_EVALUATION.md`
verweist auf die generierte Version. "Manuelle Doppelpflege beenden" ist
damit als LANGFRISTIGES Ziel dokumentiert, nicht in diesem Schritt
erzwungen - konsistent mit dem bereits bei P1.2 Schritt 1 etablierten
Muster ("nicht sofort alles migrieren").

**Konkreter, ueberpruefbarer Beleg, dass der Generator funktioniert**:
gegen die ECHTE `health_condition`-Registry ausgefuehrt - die erzeugte
Tabelle reproduziert alle bislang manuell gepflegten Zellen korrekt UND
zeigt bereits Inhalte, die `SYSTEMATIC_EVALUATION.md` noch nicht kennt
(die neue Spalte `outer_workflow_evaluation` aus Phase C, inkl. des
Cross-Projekt-Meta-Befunds) - ein direkter, praktischer Beleg fuer den
Wert der Registry ggue. der rein manuellen Pflege.

**Testabdeckung**: neue `tests/testthat/test-generate_systematic_evaluation.R`,
6 Faelle (leere Registry, korrekte Pivotierung + Legenden-Symbol-Mapping,
Zusammenfassen mehrerer Eintraege pro Zelle statt Ueberschreiben,
Spaltenreihenfolge bekannt-zuerst, Hinweistext bei leerer Registry,
Datei-Schreiben). Volle Suite weiterhin gruen (jetzt 16 Testdateien).

**Bewusst NICHT umgesetzt**: das tatsaechliche Zusammenfuehren beider
Dokumente (redaktionelles Material aus `SYSTEMATIC_EVALUATION.md`
manuell als `evid_notes`/Fussnoten in die Registry uebertragen, danach
die generierte Version zur einzigen Quelle machen) - das ist der
naechste Schritt auf dem Weg zu "Doppelpflege beenden", aber ein
eigener, bewusst zu planender Arbeitsschritt, kein Nebeneffekt dieser
Aufgabe.

### Phase E - Status (2026-08-28): Publikationsvorbereitung

**Ziel laut Bewertungsdokument (Punkte 16-18)**: Benchmark-Protokoll
einfrieren, Ablationsstudien DEFINIEREN (nicht durchfuehren), Paper-Story
aus den Ergebnissen ableiten.

**Umgesetzt**:
1. ~~Benchmark-Protokoll einfrieren~~ **ERLEDIGT** - neue Datei
   `BENCHMARK_PROTOCOL.md`, "Version 1": fixiert exakt, was Phase C
   gemacht hat (3 Outer Folds, 3 Vergleichs-Arme, generisches
   `msr()`-Scoring, die bedingte Multiplier-Tuning-Regel, erlaubte
   Abweichungen fuer aeltere Projekte) als verbindliche Referenz fuer
   jeden weiteren Datensatz. Jede zusaetzliche Abweichung braucht eine
   explizite Version 2 statt stiller Drift.
2. ~~Ablationsstudien definieren~~ **ERLEDIGT** - neue Datei
   `ABLATION_STUDIES_PLAN.md`, 4 Ablationen (A1 Gewichtung+Multiplier,
   A2 Leak-Audit, A3 Drift-/Stabilitaets-Checks, A4 Ensemble Selection),
   jeweils nach dem `MODEL_HYPOTHESIS_CRITERIA.md`-Schema
   (Hypothese/Datensatztyp/Baseline/Metrik/Budget/Abbruchkriterium) PLUS
   einer Rollen-Zuordnung (Score/Trust/Fehlervermeidung, wie vom
   Bewertungsdokument gefordert). **Wichtiger Befund beim Definieren**:
   2 von 4 Ablationen (A1, A4) sind durch bereits vorhandene Ergebnisse
   DE FACTO BEREITS BEANTWORTET (Phase C bzw. bestehende Ensemble-
   Selection-Historie) - keine neuen Laeufe noetig, nur Zusammenstellung.
   Die anderen beiden (A2, A3) sind ueberwiegend dokumentarische
   Nacharbeit. **Keine der 4 Ablationen wurde ausgefuehrt/zusammengestellt**
   - nur definiert, wie vom Plan verlangt.
3. ~~Paper-Story aus Ergebnissen ableiten~~ **ERLEDIGT** - `AGENTS.md`s
   bestehender "Mittelfristiges Ziel"-Abschnitt um eine "Aktualisierte
   Paper-Story nach Phase C" ergaenzt: die urspruengliche "der Workflow
   generalisiert"-Behauptung wird zur praeziseren, staerkeren Aussage
   "generalisiert MIT einer zur Zielmetrik passenden Korrekturkette,
   nicht mit Gewichtung allein" - explizit als STAERKERE, nicht
   schwaechere Story eingeordnet (eine Grenzbedingung mit Erklaerung ist
   fuer ein Forschungs-Paper wertvoller als eine unqualifizierte
   "funktioniert immer"-Behauptung).

**Damit ist die komplette Roadmap des 2026-08-28-Bewertungsdokuments
(Phasen A-E) abgeschlossen.** Verbleibt: die tatsaechliche AUSFUEHRUNG der
4 definierten Ablationen (ueberwiegend Dokumentations-Zusammenstellung,
kein grosses Rechenbudget mehr noetig) und die in Phase-C-Status
vorgeschlagene gezielte Nachpruefung (Multiplier-Korrektur bei
`CreditScoringChallenge`/`PumpItUp` nachruesten) - beides bewusst NICHT
automatisch angestossen, nur dokumentiert als naechstmoegliche Schritte.

## Ablation A2 (Leak-Audit) - Status (2026-08-28)

Auf Nutzeranfrage ausgefuehrt: die in `ABLATION_STUDIES_PLAN.md`
definierte Ablation A2 (Full Workflow vs. ohne Leak-Audit) ist
abgeschlossen - siehe [`ABLATION_A2_LEAK_AUDIT.md`](ABLATION_A2_LEAK_AUDIT.md)
fuer die volle Auswertung. Wie geplant ueberwiegend Dokumentations-
Zusammenstellung bereits vorhandener Befunde (kein neues Modelltraining -
der Leak-Audit ist kein Score-Hebel). 4 Kategorien mit konkreten Zahlen:
echter Treffer (`CreditScoringChallenge`, F1 0.88->0.41, extern via
Zindi-Leaderboard 0.4191 bestaetigt), 7x korrekt still bei sauberen
Daten, 1x Graubereich-Fund korrekt NICHT als Leak entfernt
(`openml-steel-plates-fault`), und - bewusst ehrlich mitdokumentiert
statt nur die Erfolgsfaelle zu zeigen - 1 bekannter blinder Fleck
(`Lending Club`, BAcc 0.998->0.53 honest, extremer diffuser Leak, Guard
still) mit einem Gegenbeispiel, das zeigt, wo die Guard-Verbesserung
(Korrelations-Cluster-Zerlegung) noch greift (`synth-redundant-leak-test`,
moderatere Redundanz). Abbruchkriterium mehrfach uebererfuellt.

## Ablation A3 (Drift-/Stabilitaets-Checks) - Status (2026-08-28)

Auf Nutzeranfrage ausgefuehrt: die in `ABLATION_STUDIES_PLAN.md`
definierte Ablation A3 (Full Workflow vs. ohne Adversarial Validation/
Split-Size-Sensitivity/Learning-Curve/Seed-Stabilitaet/Generalisierungs-
luecke) ist abgeschlossen - siehe
[`ABLATION_A3_DRIFT_STABILITY_CHECKS.md`](ABLATION_A3_DRIFT_STABILITY_CHECKS.md).
Wie geplant Dokumentations-Zusammenstellung, kein neues Modelltraining.
Kernbefunde: `geoai-aquaculture` (extremer Covariate Shift, aenderte die
Methodenwahl weg von Reweighting hin zu Invarianz), `openml-credit-g`
(eine urspruenglich FALSCHE eigene Learning-Curve-Messung wurde spaeter
selbst korrigiert - zeigt, dass das Template auch eigene Kalibrierungs-
fehler findet, nicht nur externe Probleme), eine kontrollierte
Generalisierungsluecke-Validierung ("Winner's Curse", z=-3.12 korrekt
erkannt), sowie durchgaengige "korrekt still"-Bestaetigungen ohne falsche
Alarme. Damit sind alle 4 in `ABLATION_STUDIES_PLAN.md` definierten
Ablationen (A1-A4) bearbeitet - A1/A4 waren bereits durch bestehende
Ergebnisse beantwortet, A2/A3 wurden jetzt als eigene Dokumente
ausgearbeitet.

## Zentraler Merge durchgefuehrt (2026-08-29)

Auf Nutzeranfrage ("mach weiter mit dem Merge") den seit P2.1
ueberfaelligen `merge_project_experiments.R`-Lauf nachgeholt - jetzt mit
DB-Domain-Trennung (Phase A) sicherer moeglich. Dabei **2 echte Bugs
gefunden und behoben**:

**Bug 1 (Regression aus P1.2, schwerwiegend)**: die `evidence`-Tabelle
(P1.2, 2026-08-27) existiert in den meisten lokalen Projekt-DBs NICHT
(deren `db_schema.sql` wurde seither nicht neu ausgefuehrt). Da der
Merge-Loop alle Tabellen einer Quelle in EINER Transaktion verarbeitet,
liess der fehlgeschlagene `evidence`-Merge die GESAMTE Transaktion
zurueckrollen - **inklusive der bereits erfolgreich eingefuegten Zeilen
aller anderen Tabellen**. Beim ersten Lauf zeigten deshalb 22 von 23
Quellen "+0 Zeilen" ueberall, obwohl darunter echte neue Daten waren.
**Fix**: `merge_project_experiments.R` prueft jetzt vor jedem
Tabellen-Merge, ob die Tabelle in der QUELLE ueberhaupt existiert
(`sqlite_master`-Abfrage auf `src`), und ueberspringt sie sonst mit einer
Meldung statt die Transaktion abzubrechen.

**Bug 2 (vorbestehendes Datenproblem, nicht durch diese Session
verursacht)**: `openml-credit-g`s lokale `project`-Zeile hatte eine
ANDERE `proj_id` als die bereits in der Ziel-DB gemergte Zeile (gleicher
`proj_name`, UNIQUE-Constraint-Verletzung) - vermutlich wurde die lokale
DB zwischenzeitlich neu aufgebaut und bekam dabei eine frische UUID.
**Fix (in der LOKALEN `openml-credit-g`-DB, nicht im Template-Code)**:
`project.proj_id` und `workflow.wf_proj_id` per gezieltem `UPDATE` auf
die bereits etablierte Ziel-ID umgeschrieben (Backup der lokalen DB
vorher angelegt, FK-Integritaet nach dem Update verifiziert - keine
verwaisten Referenzen).

**Ergebnis nach beiden Fixes**: alle 23 gefundenen Classification-Quell-
DBs erfolgreich verarbeitet (22 bereits vollstaendig aktuell bestaetigt,
`openml-credit-g` mit den erwarteten 10 neuen Runs gemergt: +8 workflow,
+10 run, +33 run_config, +90 model_config, +11 resampling, +318
hyperparam, +193 metric_result). Erneuter `db_housekeeping_check()`
bestaetigt: "Keine neuen Runs - alle lokal auffindbaren Runs sind
bereits gemergt." Backup der Ziel-DB wie immer automatisch vor dem
Schreiben angelegt.

**Bewusst NICHT geaendert**: die 4 als `regression` erkannten Projekte
bleiben ausgeschlossen (Phase A), die 4 als `unknown` markierten
(`WineQualityDataset`, die 3 Multi-Label-Projekte) wurden inkludiert,
aber nicht weiter untersucht - wie in Phase A dokumentiert, absichtlich
konservativ (Einschluss statt Ausschluss bei Unsicherheit).

## Backup-Aufraeumen (2026-08-29)

Auf Nutzeranfrage die in P2.1/Phase-A-E mehrfach als offen vermerkten
`_artifacts`-Backup-Dateien geloescht - vom Nutzer SELBST ausgefuehrt
(dauerhaftes Datei-Loeschen bleibt aus Sicherheitsgruenden dem Nutzer
vorbehalten, nicht automatisiert durch Claude). Vorher: 12 Dateien, 213
MB (aeltester Backup vom 2026-07-15, mehrere aus den heutigen
Merge-Versuchen). Danach: 1 Datei (der finale, erfolgreiche
Merge-Backup vom 2026-08-29, 19.8 MB) - per erneutem
`db_housekeeping_check()` verifiziert ("BACKUPS: 1 Datei(en)", keine
">3 Backups"-Warnung mehr). Damit ist auch dieser letzte, wiederholt
dokumentierte offene Punkt erledigt.

## Naechste Bewertung 2026-08-29 (extern, neue Roadmap P0-P3)

Neues externes Bewertungsdokument vom Nutzer eingebracht:
`AutoML_Bewertung_und_Verbesserungsvorschlaege_2026-08-29.md`
(`~/Downloads`, dieser Abschnitt haelt die relevanten Punkte dauerhaft im
Repo fest). Gesamtnote 9.7/10. **Wichtigster neuer Kritikpunkt**: die
bisherige "Full-Workflow Outer Evaluation" (Phase C) ist NICHT der
komplette AutoML-Entscheidungsprozess, sondern nur ein Baustein davon
(gewichtetes Training + Korrektur) - Modellwahl/Tuning/Ensemble Selection
laufen nicht innerhalb der Outer-CV-Schleife. Vorschlag: 3 Evaluations-
Ebenen definieren (Level 1 Component Workflow, Level 2 Model-Selection
Workflow, Level 3 Full Trust-centered AutoML Decision Process). **Zweiter
Kritikpunkt**: die 7 Phase-C-Datensaetze stammen aus bereits bekannten
Projekten - Risiko von Benchmark Selection Bias fuer ein staerkeres
Research-Paper (Vorschlag: vorab festgelegtes externes Benchmark-Set).
**Dritter Kritikpunkt**: die bisherigen Baselines (Default Ranger/
LightGBM) sind fuer ein Research-Paper zu schwach (Vorschlag: Tuned
Ranger/LightGBM, Best Single Tuned Model ergaenzen).

**Neue Roadmap**: P0 (Begriffe/Ebenen trennen, Doku anpassen - guenstig),
P1 (externes Benchmark-Set + faire Baselines - moderater Aufwand), P2
(Level-2-Outer-Evaluation prototypisieren + Evidence Registry
finalisieren - teuer), P3 (`finalize_run_provenance()`, Paper-
Rohentwurf).

**Nutzerentscheidung (2026-08-29)**: Start mit **P0**.

### P0 - Status (2026-08-29)

1. ~~Begriffe `workflow_ranger`/`model-selection workflow`/`full AutoML
   process` klar trennen~~ **ERLEDIGT** - neue Datei
   [`EVALUATION_LEVELS.md`](EVALUATION_LEVELS.md) definiert die 3 Ebenen
   praezise und legt fest: alles bisher Gemessene (P1.1, Phase C,
   Multiplier-Nachpruefung) ist Level 1, ueber Level 2/3 liegt keine
   Evidenz vor.
2. ~~aktuelle Dokumentation entsprechend anpassen~~ **ERLEDIGT** -
   `BENCHMARK_PROTOCOL.md` (Kopf-Hinweis "Level 1"), `AGENTS.md`
   (Paper-Story-Zitat um die Level-1-Einschraenkung ergaenzt, explizit
   "ueber Level 2/3 liegt keine Evidenz vor" statt es zu verschweigen),
   `BACKLOG.md` (dieser Abschnitt + Praezisierung am Kopf des
   Phase-C-Status).
3. ~~Claims im Paper-/AGENTS-Kontext auf die tatsaechlich evaluierte
   Ebene begrenzen~~ **ERLEDIGT** - siehe Punkt 2, `AGENTS.md`s
   Paper-Story-Zitat wurde umformuliert, nicht nur ergaenzt (kein
   unqualifiziertes "der Workflow generalisiert" mehr im Fliesstext).

**Bewusst NICHT geaendert**: `ABLATION_STUDIES_PLAN.md`/die 2
ausgearbeiteten Ablations-Dokumente (A2/A3) - die behandeln einzelne
Diagnose-Module (Leak-Audit, Drift-/Stabilitaets-Checks), nicht die
"Workflow generalisiert"-Aussage, die Level-Frage betrifft sie nicht
direkt (siehe `EVALUATION_LEVELS.md`s eigene Begruendung dafuer).

### P1 - Status (2026-08-29): externer Benchmark (Auswahl)

**Nutzerentscheidung**: "mach weiter mit P1".

~~Einschlusskriterien definieren~~/~~Dataset-Liste vorab einfrieren~~/
~~keine Auswahl anhand bereits bekannter Modellperformance~~ **ERLEDIGT**
- siehe [`EXTERNAL_BENCHMARK_SET.md`](EXTERNAL_BENCHMARK_SET.md). Quelle:
[OpenML-CC18](https://www.openml.org/search?type=study&study_type=task&id=99)
(72 extern kuratierte Klassifikations-Datensaetze, per OpenML-API
abgerufen). Kriterien (500-20.000 Instanzen, <=100 Features, 2-10
Klassen, nicht bereits in diesem Template verwendet) VOR jeder Auswahl
festgelegt -> 43 zulaessige Kandidaten -> per `set.seed(20260829)`
deterministisch 3 binaere + 3 multiclass gezogen, OHNE jemals eine
Performance-Kennzahl einzusehen. **Eingefroren**: `cmc`, `optdigits`,
`sick`, `analcatdata_authorship`, `blood-transfusion-service-center`,
`ilpd`.

**Bewusste Einschraenkung dokumentiert**: die Phase-C-Kategorien F
(Covariate Shift)/G (Group-/Time-Struktur) lassen sich mit einer
generischen i.i.d.-Suite nicht reproduzieren, ohne selbst wieder eine
Auswahl-Entscheidung zu treffen - das externe Set deckt bewusst nur
binaer/multiclass/Groessen-Diversitaet ab.

**Noch NICHT ausgefuehrt** (separater naechster Schritt, nicht
automatisch angestossen): die eigentlichen Task-Vorbereitungen +
Outer-Evaluation-Laeufe fuer die 6 Datensaetze, sowie der zweite
P1-Teil ("faire Baselines": Tuned Ranger/LightGBM, Best Single Tuned
Model) - beides zusammen ein neuer, nicht-trivialer Rechenaufwand
(6 neue Datensaetze x mehrere Vergleichs-Arme, davon 2 neue TUNED-Arme).

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
