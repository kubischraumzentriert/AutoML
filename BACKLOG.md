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
  `docs/reference/REFERENZ_PROBABILITY_CALIBRATION.md` ist explizit als reine Referenz
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
`analysis/multilayer_stack_test.R`/`analysis/hyperband_budget_test.R` - ein Evaluations-
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
`analysis/multilayer_stack_test.R`/`analysis/hyperband_budget_test.R` (Evaluations-Skripte,
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
aktuell auf `TARGETS.md`, `README_DETAILS.md`, `docs/research/SYSTEMATIC_EVALUATION.md`,
Projekt-READMEs, Statusanker, Commits und die Experiment-DB - eine
maschinenlesbare "Evidence Registry" als zusaetzliche, strukturierte
Quelle fuer neue Befunde. Der Plan selbst schreibt ein 3-Schritte-Vorgehen
vor: "1. nur neue Befunde strukturiert loggen, 2. wichtige historische
Befunde nachziehen, 3. docs/research/SYSTEMATIC_EVALUATION.md automatisch erzeugen.
**Nicht sofort alles migrieren.**"

**Scope dieses Prototyps**: NUR Schritt 1. Schritt 2 (rueckwirkendes
Nachtragen von `docs/research/SYSTEMATIC_EVALUATION.md`s ~20 Projekten x 9 Modulen in
die Registry) und Schritt 3 (automatische Generierung dieser Datei aus der
Registry) sind NICHT umgesetzt - beides waere angesichts der Detailtiefe
von `docs/research/SYSTEMATIC_EVALUATION.md` (Fussnoten, Korrekturvermerke, Methodik-
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
Befunde aus `docs/research/SYSTEMATIC_EVALUATION.md` in die Registry nachtragen) waere
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

**Umgesetzt**: neue, reine Doku-Datei `docs/research/MODEL_HYPOTHESIS_CRITERIA.md` -
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
`analysis/migrate_systematic_evaluation_to_evidence.R` (Repo-Wurzel, kein Teil der
nummerierten Pipeline, analog zu `merge_project_experiments.R`) - liest
die grosse Projekt-x-Modul-Tabelle aus `docs/research/SYSTEMATIC_EVALUATION.md` (Stand
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
"docs/research/SYSTEMATIC_EVALUATION.md (historischer Backfill, P1.2 Schritt 2,
2026-08-27)" gesetzt, damit die Migration in der Registry selbst als
eigene, unterscheidbare Charge erkennbar bleibt.

**`docs/research/SYSTEMATIC_EVALUATION.md` selbst bleibt unveraendert** - dieses
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
   `docs/research/SYSTEMATIC_EVALUATION.md` aus der Registry generieren statt manuell
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
   `docs/research/SYSTEMATIC_EVALUATION.md`). Korrigiert: fehlt ist stattdessen eine
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
[`docs/research/EVALUATION_LEVELS.md`](docs/research/EVALUATION_LEVELS.md))**: alles unten
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
  (bereits so in `docs/research/SYSTEMATIC_EVALUATION.md` dokumentiert: "Threshold-
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

**Ziel laut Bewertungsdokument (Punkte 13-15)**: `docs/research/SYSTEMATIC_EVALUATION.md`
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
[`docs/research/SYSTEMATIC_EVALUATION_GENERATED.md`](docs/research/SYSTEMATIC_EVALUATION_GENERATED.md).

**Scope-Entscheidung (additiv, NICHT die bestehende Datei ersetzt)**: die
generierte Tabelle ERSETZT `docs/research/SYSTEMATIC_EVALUATION.md` NICHT - die
handgepflegte Datei enthaelt redaktionelles Material (Fussnoten,
Korrekturvermerke wie die IQR-Nenner-Korrektur, einen ganzen
Diskussionsabschnitt "Was diese erste Fassung zeigt"), das eine reine
DB-Pivot-Tabelle strukturell nicht abbilden kann. Ein einmaliges
Ueberschreiben in diesem Schritt haette dieses Material unwiederbringlich
verloren. Stattdessen: ein Hinweis am Kopf von `docs/research/SYSTEMATIC_EVALUATION.md`
verweist auf die generierte Version. "Manuelle Doppelpflege beenden" ist
damit als LANGFRISTIGES Ziel dokumentiert, nicht in diesem Schritt
erzwungen - konsistent mit dem bereits bei P1.2 Schritt 1 etablierten
Muster ("nicht sofort alles migrieren").

**Konkreter, ueberpruefbarer Beleg, dass der Generator funktioniert**:
gegen die ECHTE `health_condition`-Registry ausgefuehrt - die erzeugte
Tabelle reproduziert alle bislang manuell gepflegten Zellen korrekt UND
zeigt bereits Inhalte, die `docs/research/SYSTEMATIC_EVALUATION.md` noch nicht kennt
(die neue Spalte `outer_workflow_evaluation` aus Phase C, inkl. des
Cross-Projekt-Meta-Befunds) - ein direkter, praktischer Beleg fuer den
Wert der Registry ggue. der rein manuellen Pflege.

**Testabdeckung**: neue `tests/testthat/test-generate_systematic_evaluation.R`,
6 Faelle (leere Registry, korrekte Pivotierung + Legenden-Symbol-Mapping,
Zusammenfassen mehrerer Eintraege pro Zelle statt Ueberschreiben,
Spaltenreihenfolge bekannt-zuerst, Hinweistext bei leerer Registry,
Datei-Schreiben). Volle Suite weiterhin gruen (jetzt 16 Testdateien).

**Bewusst NICHT umgesetzt**: das tatsaechliche Zusammenfuehren beider
Dokumente (redaktionelles Material aus `docs/research/SYSTEMATIC_EVALUATION.md`
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
   `docs/research/BENCHMARK_PROTOCOL.md`, "Version 1": fixiert exakt, was Phase C
   gemacht hat (3 Outer Folds, 3 Vergleichs-Arme, generisches
   `msr()`-Scoring, die bedingte Multiplier-Tuning-Regel, erlaubte
   Abweichungen fuer aeltere Projekte) als verbindliche Referenz fuer
   jeden weiteren Datensatz. Jede zusaetzliche Abweichung braucht eine
   explizite Version 2 statt stiller Drift.
2. ~~Ablationsstudien definieren~~ **ERLEDIGT** - neue Datei
   `docs/ablations/ABLATION_STUDIES_PLAN.md`, 4 Ablationen (A1 Gewichtung+Multiplier,
   A2 Leak-Audit, A3 Drift-/Stabilitaets-Checks, A4 Ensemble Selection),
   jeweils nach dem `docs/research/MODEL_HYPOTHESIS_CRITERIA.md`-Schema
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

Auf Nutzeranfrage ausgefuehrt: die in `docs/ablations/ABLATION_STUDIES_PLAN.md`
definierte Ablation A2 (Full Workflow vs. ohne Leak-Audit) ist
abgeschlossen - siehe [`docs/ablations/ABLATION_A2_LEAK_AUDIT.md`](docs/ablations/ABLATION_A2_LEAK_AUDIT.md)
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

Auf Nutzeranfrage ausgefuehrt: die in `docs/ablations/ABLATION_STUDIES_PLAN.md`
definierte Ablation A3 (Full Workflow vs. ohne Adversarial Validation/
Split-Size-Sensitivity/Learning-Curve/Seed-Stabilitaet/Generalisierungs-
luecke) ist abgeschlossen - siehe
[`docs/ablations/ABLATION_A3_DRIFT_STABILITY_CHECKS.md`](docs/ablations/ABLATION_A3_DRIFT_STABILITY_CHECKS.md).
Wie geplant Dokumentations-Zusammenstellung, kein neues Modelltraining.
Kernbefunde: `geoai-aquaculture` (extremer Covariate Shift, aenderte die
Methodenwahl weg von Reweighting hin zu Invarianz), `openml-credit-g`
(eine urspruenglich FALSCHE eigene Learning-Curve-Messung wurde spaeter
selbst korrigiert - zeigt, dass das Template auch eigene Kalibrierungs-
fehler findet, nicht nur externe Probleme), eine kontrollierte
Generalisierungsluecke-Validierung ("Winner's Curse", z=-3.12 korrekt
erkannt), sowie durchgaengige "korrekt still"-Bestaetigungen ohne falsche
Alarme. Damit sind alle 4 in `docs/ablations/ABLATION_STUDIES_PLAN.md` definierten
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
   [`docs/research/EVALUATION_LEVELS.md`](docs/research/EVALUATION_LEVELS.md) definiert die 3 Ebenen
   praezise und legt fest: alles bisher Gemessene (P1.1, Phase C,
   Multiplier-Nachpruefung) ist Level 1, ueber Level 2/3 liegt keine
   Evidenz vor.
2. ~~aktuelle Dokumentation entsprechend anpassen~~ **ERLEDIGT** -
   `docs/research/BENCHMARK_PROTOCOL.md` (Kopf-Hinweis "Level 1"), `AGENTS.md`
   (Paper-Story-Zitat um die Level-1-Einschraenkung ergaenzt, explizit
   "ueber Level 2/3 liegt keine Evidenz vor" statt es zu verschweigen),
   `BACKLOG.md` (dieser Abschnitt + Praezisierung am Kopf des
   Phase-C-Status).
3. ~~Claims im Paper-/AGENTS-Kontext auf die tatsaechlich evaluierte
   Ebene begrenzen~~ **ERLEDIGT** - siehe Punkt 2, `AGENTS.md`s
   Paper-Story-Zitat wurde umformuliert, nicht nur ergaenzt (kein
   unqualifiziertes "der Workflow generalisiert" mehr im Fliesstext).

**Bewusst NICHT geaendert**: `docs/ablations/ABLATION_STUDIES_PLAN.md`/die 2
ausgearbeiteten Ablations-Dokumente (A2/A3) - die behandeln einzelne
Diagnose-Module (Leak-Audit, Drift-/Stabilitaets-Checks), nicht die
"Workflow generalisiert"-Aussage, die Level-Frage betrifft sie nicht
direkt (siehe `docs/research/EVALUATION_LEVELS.md`s eigene Begruendung dafuer).

### P1 - Status (2026-08-29): externer Benchmark (Auswahl)

**Nutzerentscheidung**: "mach weiter mit P1".

~~Einschlusskriterien definieren~~/~~Dataset-Liste vorab einfrieren~~/
~~keine Auswahl anhand bereits bekannter Modellperformance~~ **ERLEDIGT**
- siehe [`docs/research/EXTERNAL_BENCHMARK_SET.md`](docs/research/EXTERNAL_BENCHMARK_SET.md). Quelle:
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
automatisch angestossen): der zweite P1-Teil ("faire Baselines": Tuned
Ranger/LightGBM, Best Single Tuned Model).

### P1 - Status (2026-08-29, Fortsetzung): Task-Vorbereitung + Level-1-Outer-Evaluation ausgefuehrt

**Nutzerentscheidung**: "erst nur die Task-Vorbereitung und Outer-
Evaluation" (ohne die faire-Baselines-Erweiterung).

Fuer alle 6 eingefrorenen Datensaetze: Projekt-Setup via `mlr3oml`
(direkter OpenML-API-Zugriff, kein manuelles Herunterladen), Kopien von
`db_logging.R`/`db_schema.sql`/`class_multiplier_tuning.R`/
`outer_workflow_evaluation_template.R` aus dem Template, uniforme
Primaermetrik `classif.bacc`/`classif.mcc` (Template-Standardkonvention).
Alle 6 Projekte in `ML_Learning` angelegt und lokal committet (kein
Remote). Level-1-Protokoll (`docs/research/BENCHMARK_PROTOCOL.md`) unveraendert
angewendet.

**Ergebnis (alle 6, `workflow_ranger` vs. beste Baseline, BAcc)**:

| Datensatz | Instanzen | Klassen | Baseline (beste) | workflow_ranger | Delta |
|---|---|---|---|---|---|
| `sick` | 3772 | 2 | 0.9250 | **0.9714** | **+4.6** |
| `ilpd` | 583 | 2 | 0.6170 | **0.6840** | **+6.7** |
| `blood-transfusion` | 748 | 2 | 0.6190 | **0.6576** | **+3.9** |
| `cmc` | 1473 | 3 | 0.5214 | **0.5374** | **+1.6** |
| `analcatdata_authorship` | 841 | 4 | 0.9852 | **0.9876** | +0.2 |
| `optdigits` | 5620 | 10 | 0.9818 | 0.9810 | -0.1 |

**Bestaetigt das Phase-C-Muster erneut, auf voellig unbekannten
Datensaetzen**: bei allen 6 (BAcc-primaer, alle mit Multiplier-Tuning)
gewinnt `workflow_ranger` deutlich oder haelt praktisch mit - kein
einziger Ausreisser nach unten. Am staerksten bei kleineren, staerker
unausgeglichenen binaeren Aufgaben (`ilpd`, `sick`, `blood-transfusion`),
am schwaechsten (knapp neutral) bei `optdigits` - einem grossen, gut
balancierten 10-Klassen-Datensatz, wo wenig Klassenimbalance zum
Korrigieren vorliegt. Das ist die ERSTE Bestaetigung des Kernbefunds auf
Datensaetzen, die zu keinem Zeitpunkt vor der Auswahl bekannt waren -
entkraeftet das Benchmark-Selection-Bias-Risiko aus der 2026-08-29-
Bewertung fuer den BAcc-primaeren Fall.

**Echter Bug gefunden und behoben**: `openml-cc18-optdigits` (10
Klassen) liess `tune_class_multipliers()` (`class_multiplier_tuning.R`)
mit "cannot allocate vector of size 38.4 Gb" abstuerzen - der
Grid-Search-Schritt (`expand.grid()` ueber alle Nicht-Referenz-Klassen)
waechst exponentiell mit der Klassenzahl (12^9 Kombinationen bei 10
Klassen). **Fix**: eine Kombinatorik-Obergrenze (200.000 Kombinationen -
deckt bis zu 5 Klassen vollstaendig ab, alle bisherigen Projekte
betroffen hoechstens `PumpItUp`/`openml-steel-plates-fault` mit 3/7
Klassen, beide weit darunter) - oberhalb wird der volle Grid-Durchlauf
uebersprungen, Prior-Korrektur + Nelder-Mead (bereits vorhandene
Schritte 1b/2) uebernehmen dann allein die Rolle des robusten
Startpunkts. 2 neue Testfaelle (Reproduktion des Crashs synthetisch mit
10 Klassen, Regressionsschutz dass das Grid bei wenigen Klassen weiterhin
voll genutzt wird). Nach dem Fix lief `openml-cc18-optdigits`
fehlerfrei durch.

**Alle 7 Ergebnisse (6 Datensaetze + der Bug-Fund selbst) in die
Evidence Registry geloggt.**

### P1 - Status (2026-08-29, Abschluss): faire getunte Baselines (Protokoll v2)

**Nutzerentscheidung**: "mach weiter mit den fairen Baselines".

~~tuned Ranger~~/~~tuned LightGBM~~/~~ggf. Best Single Tuned Model~~/
~~Compute-Budget dokumentieren~~/~~Workflow gegen diese Baselines
vergleichen~~ **ERLEDIGT** - siehe `docs/research/BENCHMARK_PROTOCOL.md` Version 2 und
[`outer_workflow_evaluation_v2_fair_baselines.R`](outer_workflow_evaluation_v2_fair_baselines.R).
3 neue Arme (`tuned_ranger`, `tuned_lightgbm`, `best_single_tuned_model`,
je 15 Random-Search-/MBO-Evals, Inner-Holdout(0.75) INNERHALB des
Outer-Train), angewendet auf alle 6 externen P1-Datensaetze.

**Aufgetretener Bug (gefunden und gefixt)**: dieselbe `mlr3measures::tnr()`/
`mlr3tuning::tnr()`-Namenskollision aus P1.1 trat erneut auf (diesmal in
`run_tuned_ranger()`s `tnr("random_search")`-Aufruf, den `run_tuned_
lightgbm()`s bereits qualifizierten Aufruf hatte ich beim ersten Entwurf
schlicht vergessen zu spiegeln) - sofort beim Testlauf auf `ilpd`
aufgefallen, mit `mlr3tuning::tnr(...)` gefixt.

**Vollstaendiges Ergebnis (alle 6 Datensaetze, `workflow_ranger` vs.
bester Baseline)**:

| Datensatz | v1 (nur Default) | v2 (+ getunte Baselines) | Bester v2-Konkurrent | Delta zu diesem |
|---|---|---|---|---|
| `ilpd` | **+6.7** (workflow gewinnt) | **+11.9** (workflow gewinnt) | tuned_lightgbm/best_single 0.596 | **+11.9** |
| `sick` | **+4.6** (workflow gewinnt) | **+4.0** (workflow gewinnt) | lightgbm_default 0.923 | **+4.0** |
| `blood-transfusion` | **+3.9** (workflow gewinnt) | **+0.8** (workflow gewinnt, knapp) | tuned_ranger 0.622 | **+0.8** |
| `cmc` | **+1.6** (workflow gewinnt) | **-0.9** (workflow verliert knapp) | tuned_ranger 0.529 | **-0.9** |
| `analcatdata_authorship` | +0.2 (fast neutral) | -0.6 (workflow verliert knapp) | tuned_lightgbm 0.992 | **-0.6** |
| `optdigits` | -0.1 (fast neutral) | -0.3 (workflow verliert knapp) | tuned_lightgbm/best_single 0.984 | **-0.3** |

**Wichtigste Praezisierung der gesamten P1/Phase-C-Story**: gegen faire
getunte Baselines VERSCHWINDET `workflow_ranger`s Vorteil bei 3 von 6
Datensaetzen (knapp, jeweils <1 BAcc-Punkt) - bleibt aber bei den
kleineren, staerker unausgeglichenen Datensaetzen (`ilpd`, `sick`,
`blood-transfusion`) klar und deutlich bestehen. Erklaerungsmuster: die
Gewichtungs-/Multiplier-Korrekturkette bringt einen echten Mehrwert UEBER
reines Hyperparameter-Tuning hinaus dort, wo Klassenimbalance das
eigentliche Problem ist - bei groesseren, bereits gut balancierten
Aufgaben (`cmc`, `analcatdata_authorship`, `optdigits`) leistet reines
Tuning bereits dasselbe oder mehr, ohne die zusaetzliche Komplexitaet.

**Das ist die ehrlichste, praeziseste Version der gesamten Kernaussage
bislang** - keine Umkehr der vorherigen Befunde, sondern eine weitere,
noetige Praezisierung: "Level-1-Workflow generalisiert MIT einer zur
Zielmetrik passenden Korrekturkette UND bringt einen Mehrwert ueber
reines Tuning hinaus, WENN Klassenimbalance das dominante Problem ist -
bei balancierten/grossen Aufgaben leistet reines Tuning gleichwertig
oder mehr." Genau das noetigt, was die 2026-08-29-Bewertung unter Punkt 9
("faire Baselines fehlen") einforderte, und beantwortet es jetzt mit
echten Zahlen statt einer Vermutung.

Alle 6 v2-Ergebnisse + ein Cross-Projekt-Meta-Befund in die Evidence
Registry geloggt.

### P2 - Status (2026-08-29): Level-2-Prototyp (Modellwahl+Tuning+Ensemble im Outer-Fold)

**Nutzerentscheidung**: "mach weiter mit P2", dann per `AskUserQuestion`
"Nur 1-2 Datensaetze zuerst (Empfehlung)" fuer den Umfang.

Neues Konzept-Dokument [`docs/research/EVALUATION_LEVELS.md`](docs/research/EVALUATION_LEVELS.md)
praezisiert: Level 1 = Component Workflow (Gewichtung + optionale
Multiplier-Korrektur - das ist ALLES, was bisher unter "Outer Evaluation"
lief, inkl. Phase C und P1/v1/v2). Level 2 = Model-Selection Workflow
(Tuning + Modellwahl + optionales Ensemble, alles INNERHALB jedes
Outer-Train-Splits). Level 3 = volle Trust-zentrierte AutoML-Entscheidungskette
(Leak-Audit/Drift als aktive Inloop-Entscheidungen) - noch nicht geplant.

Neues Skript [`outer_workflow_evaluation_v3_level2.R`](outer_workflow_evaluation_v3_level2.R)
(Protokoll v3): pro Outer-Fold wird der Outer-Train nochmal in
Inner-Train/Inner-Tune gesplittet (0.75/0.25), darauf `auto_tuner()` fuer
Ranger (Random-Search) und LightGBM (MBO), je 10 Evals, plus ein
Mini-Ensemble (Mittel der Wahrscheinlichkeiten) - alle drei Kandidaten
klassenmultiplier-korrigiert und anhand des Inner-Tune-Scores verglichen.
Der Gewinner wird mit den besten Hyperparametern final auf dem GESAMTEN
Outer-Train refittet und genau einmal auf dem Outer-Test bewertet (kein
Data Leakage: Outer-Test bleibt bis zum Schluss ungesehen).

**Update (2026-08-29, Rollout auf alle 6 Datensaetze)**: nach den ersten
2 Datensaetzen (`ilpd`, `optdigits`) wurde eine Arbeitshypothese notiert
("Level 2 hilft bei grossen/balancierten, schadet bei kleinen/
unausgeglichenen Datensaetzen"). Nach Rollout auf die verbleibenden 4
Datensaetze **haelt diese Hypothese NICHT** - `blood-transfusion` (klein,
n=498, unausgeglichen) gewinnt deutlich mit Level 2, waehrend `cmc`
(n=981) und `analcatdata-authorship` (n=559, nahe an der Saettigungsgrenze)
verlieren. Das ist ein wichtiges Ergebnis der Nachpruefung selbst: die
anfaengliche 2-Datensatz-Hypothese war zu einfach.

**Vollstaendiges Ergebnis (alle 6 Datensaetze)**:

| Datensatz | v1 `workflow_ranger` | bisher bester Wert (v1/v2) | v3 `level2_workflow` | Level 2 gewinnt/verliert |
|---|---|---|---|---|
| `ilpd` (n=388) | 0.6840 | 0.6840 (v1) | 0.6473 | **verliert** (-3.7) |
| `sick` (n=2514) | 0.9714 | 0.9714 (v1) | 0.9723 | **gewinnt knapp** (+0.1) |
| `blood-transfusion` (n=498) | 0.6576 | 0.6576 (v1) | 0.6878 | **gewinnt deutlich** (+3.0) |
| `cmc` (n=981) | 0.5374 | 0.5374 (v1) | 0.5113 | **verliert** (-2.6) |
| `analcatdata-authorship` (n=559) | 0.9876 | 0.9921 (v2, tuned_lightgbm) | 0.9731 | **verliert** (-1.9) |
| `optdigits` (n=3743) | 0.9810 | 0.9840 (v2, tuned_lightgbm) | 0.9859 | **gewinnt** (+0.2) |

3 von 6 Siege, 3 von 6 Niederlagen, mittlerer Delta ggue. dem bisher
besten Wert ueber alle 6 Datensaetze ≈ **-0.7 BAcc-Punkte** (leicht
negativ im Mittel, hohe Streuung). **Weder Datensatzgroesse noch
Klassenimbalance erklaeren das Muster sauber**: `blood-transfusion`
(klein, unausgeglichen) gewinnt, `ilpd` (klein, unausgeglichen) verliert;
`sick`/`optdigits` (gross) gewinnen, `cmc` (mittelgross) verliert. Ein
moeglicher Sonderfall: `analcatdata-authorship` ist bereits nahe an der
Saettigungsgrenze (Inner-Tune-Scores = 1.0000 in 2 von 3 Outer-Folds fuer
ALLE drei Level-2-Kandidaten) - dort waehlt die Modellwahl effektiv
zufaellig zwischen gleichwertigen Kandidaten, was die zusaetzliche
Komplexitaet in einen reinen Kostenfaktor ohne Nutzen verwandelt.

**Ehrliche, unaufgeloeste Kernaussage**: der Level-2-Prozess
(Modellwahl+Tuning+Ensemble innerhalb des Outer-Train-Splits) bringt
KEINEN verlaesslichen, systematischen Mehrwert gegenueber dem einfacheren
Level-1-Workflow oder den fairen getunten v2-Baselines - das Ergebnis ist
datensatzabhaengig und (bislang) nicht durch eine einfache
Datensatz-Eigenschaft (Groesse, Imbalance) vorhersagbar. Das ist selbst
ein wertvoller, negativer Befund fuer die Paper-Story: mehr
Prozess-Komplexitaet ist NICHT automatisch besser, und die zusaetzlichen
Rechenkosten (Level 2 laeuft 5-30x langsamer als v1/v2, siehe
`mean_runtime_sec` in den Ergebnis-CSVs) sind bei diesem Prototyp-Budget
(10 Tuning-Evals/Arm) nicht durchgehend gerechtfertigt.

Alle 6 Ergebnisse in die Evidence Registry geloggt (Rolle `score_lever`,
Status `core_finding`).

**Offen**: P2s zweite Haelfte ("Evidence Registry finalisieren" /
`docs/research/SYSTEMATIC_EVALUATION.md`-Struktur) - auf explizite Nutzeranweisung. Ein
groesseres Tuning-Budget fuer Level 2 (aktuell nur 10 Evals/Arm) koennte
das Bild veraendern, ist aber nicht getestet.

### P2 - Status (2026-08-29, 2. Haelfte): Evidence Registry finalisieren

**Nutzeranfrage**: "mach weiter mit P2 zweite Haelfte".

**Schritt 1 (Regenerieren)**: die 20 P1/P2-Evidence-Eintraege dieser
Session (externes Benchmark-Set, faire Baselines, Level-2-Rollout - alle
direkt in die zentrale `experiments.db` geloggt, nicht in
Projekt-lokale DBs, siehe `evidence_registry_summary()`-Check) waren noch
nicht in [`docs/research/SYSTEMATIC_EVALUATION_GENERATED.md`](docs/research/SYSTEMATIC_EVALUATION_GENERATED.md)
enthalten (zuletzt generiert 2026-08-28, vor P1/P2). `generate_
systematic_evaluation_file()` erneut ausgefuehrt - die Datei enthaelt
jetzt alle 6 externen CC18-Projekte mit ihren `outer_workflow_evaluation`-
Zellen (v1/v2/v3 zusammengefasst, da dieselbe Modul-Spalte).

**Schritt 2 (Entscheidung "manuelle Tabelle abschaffen?")**: geprueft,
ob `docs/research/SYSTEMATIC_EVALUATION.md` (770 Zeilen, handgepflegte 9-Modul-Tabelle
+ dichte redaktionelle Diskussion je Spalte, Korrekturvermerke,
Fussnoten) durch die generierte Version ersetzt werden kann.
**Entscheidung: NEIN, nicht jetzt** - die redaktionelle Dichte des
manuellen Dokuments (z.B. die vollstaendige Herleitung jeder
Spaltenaufloesung vom 2026-08-15, mit Fallzahlen/Ausschlussgruenden) ist
so hoch, dass eine verlustfreie Migration in `evid_notes`-Freitextfelder
entweder unpraktikabel waere (viel zu lange Zellen fuer eine Pivot-
Tabelle) oder den redaktionellen Mehrwert kappen wuerde - das widerspraeche
der Session-Konvention "additive/verlustfreie Aenderungen vor
destruktiven Umbauten". Stattdessen: **klare Arbeitsteilung
formalisiert** (siehe aktualisierter Hinweis-Absatz oben in
`docs/research/SYSTEMATIC_EVALUATION.md`) - die manuelle Tabelle bleibt massgeblich fuer
die urspruenglichen 9 Trust-/Diagnose-Module, waehrend ALLES rund um
`outer_workflow_evaluation` (Phase C, P1, P2) nur noch ueber die
generierte Datei gepflegt wird und dort NICHT mehr manuell nachgezogen
werden muss. Das ist der pragmatische Mittelweg zwischen "sofort
abschaffen" (haette redaktionelles Material vernichtet) und "weiter
doppelt pflegen" (unnoetiger Mehraufwand fuer die neuen, schnell
wachsenden Outer-Evaluation-Ergebnisse).

**Ergebnis**: kein Code-Aenderungsbedarf (die Infrastruktur aus Phase D/
P1.2 Schritt 3 war bereits vollstaendig und funktioniert wie gedacht) -
nur eine Regenerierung + eine explizite, dokumentierte
Arbeitsteilungs-Entscheidung. Damit ist P2 (beide Haelften) vollstaendig
abgeschlossen.

### P3 - Status (2026-08-29): `finalize_run_provenance()`

**Nutzeranfrage**: "mach weiter mit P3". Bezug: die 2026-08-29-Bewertung,
Abschnitt 11 ("Provenienz - naechster kleiner Schritt") - Basis-
Provenienz (R-Version/Paketversionen) wird bereits automatisch bei
`db_create_run()` geloggt, aber Trainings-/Testdaten-, Resampling-,
Feature-Set- und Modellartefakt-Hashes sind zu diesem fruehen Zeitpunkt
im Skript meist noch nicht bekannt. Vorschlag: eine Funktion, die am ENDE
eines Runs alle bis dahin verfuegbar gewordenen Felder nachtraegt.

**Umgesetzt**: `finalize_run_provenance(con, run_id, ...)` (neu in
`provenance.R`) - ruft `capture_run_provenance()` erneut auf, aber MIT
`packages = character(0)` und entfernt `provenance.r_version`/`.packages`
explizit aus dem Ergebnis, damit diese beiden Basisfelder (die bereits
aus `db_create_run()` in `run_config` stehen) nicht ein zweites Mal
geloggt werden (reines Rauschen in der EAV-Tabelle). Wie bei der
Basis-Provenienz: ein Fehler beim Erfassen darf den Skriptlauf nicht zum
Absturz bringen (`tryCatch` + Warnung).

**Zentraler Aufrufpunkt statt Big-Bang-Refactoring**: `db_finish_run()`
(bereits die EINE Stelle, die alle ~30 Skripte im Repo aufrufen) um
optionale, NULL-default Parameter (`train_data_path`, `test_data_path`,
`config_env`, `resampling`, `feature_set`, `model_artifact_path`)
erweitert - ruft bei Bedarf `finalize_run_provenance()` intern auf.
**Rueckwaertskompatibel**: alle ~30 bestehenden `db_finish_run(con,
run_id)`-Aufrufstellen ohne Zusatzargumente verhalten sich exakt wie
zuvor (kein zusaetzliches Logging, per Test abgesichert).

**Demonstriert an einem echten, aktiven Skript** statt nur isoliert per
Unit-Test: `030_baseline.R` (Teil der CI-Smoke-Test-Kette) gibt am
`db_finish_run()`-Aufruf jetzt `feature_set`/`resampling` mit - beide
Objekte sind an dieser Stelle (Skriptende) bereits fertig instanziiert,
anders als noch bei `db_create_run()` am Skriptanfang. Lokal gegen die
CI-Fixture verifiziert: laeuft fehlerfrei durch (Exit 0), degradiert bei
fehlendem `provenance.R` (wie in der CI-Fixture bewusst nicht kopiert,
siehe Kommentar in `db_create_run()`) korrekt zu einer Warnung statt
eines Fehlers - identisches Verhalten wie die bereits bestehende
Basis-Provenienz.

**Tests**: 12 neue `testthat`-Faelle (4 in `test-provenance.R`/
`test-db_logging.R` zusammen) decken ab: leeres `finalize_run_provenance()`
loggt nichts + liefert `FALSE`; mit Argumenten loggt es die erwarteten
Felder OHNE `r_version`/`packages` zu duplizieren; `db_finish_run()` ohne
Zusatzargumente bleibt exakt wie zuvor (Regressionsschutz fuer die ~30
bestehenden Aufrufstellen). testthat-Gesamtsuite: 322 PASS, 0 FAIL (vorher
310).

**Bewusst NICHT umgesetzt** (ausserhalb des "naechster KLEINER Schritt"-
Rahmens aus der Bewertung): Rollout auf alle ~30 Skripte mit
`db_finish_run()`-Aufruf, oder eine automatische Bestimmung der
Feature-Set-/Resampling-Objekte ohne explizite Skript-Angabe. `030_
baseline.R` dient als Referenzimplementierung fuer kuenftige Skripte, die
denselben Mehrwert wollen.

**Offen (P3, 2. Teil)**: erster Paper-Rohentwurf - auf explizite
Nutzeranweisung, deutlich groesserer, eigenstaendiger Arbeitsschritt.

### P3 - Status (2026-08-29, 2. Teil): erster Paper-Rohentwurf

**Nutzeranfrage**: "mach weiter mit dem Paper-Rohentwurf".

Neue Datei [`docs/research/PAPER_DRAFT.md`](docs/research/PAPER_DRAFT.md) - erster vollstaendiger
Durchgang, EXPLIZIT als DRAFT markiert. Auf Englisch geschrieben (Standard
fuer die anvisierten Venues), obwohl das Repo selbst auf Deutsch
dokumentiert ist - eine bewusste, im Dokument selbst begruendete
Entscheidung, kein Widerspruch zur sonstigen Repo-Sprache.

**Struktur**: Abstract, Introduction, System Description (Architektur,
Trust-Layer, ADR-003-Governance, CI/Tests), Related Work (**bewusst nur
Platzhalter** - eine echte Literaturrecherche wurde NICHT gemacht, das
Dokument sagt das explizit statt es zu verschleiern), die 3
Evaluations-Ebenen (Section 4, direkt aus `docs/research/EVALUATION_LEVELS.md`), Level-1-
Ergebnis (Section 5, Phase C + externes Benchmark-Set + faire Baselines -
die praezise, metrik-bedingte Kernaussage), Level-2-Prototyp als
ausdruecklich NEGATIVES Ergebnis (Section 6), zwei Trust-Layer-Ablationen
mit sowohl Erfolgsfaellen ALS AUCH dem dokumentierten Leak-Audit-blinden-
Fleck (Section 7), Limitations (Section 8, inkl. der wichtigsten
Klarstellung: der Titel-Anspruch "trust-centered" bezieht sich informell
auf Level 3/die gelebte Praxis, waehrend die QUANTITATIVEN Befunde nur
Level 1/2 abdecken - explizit als das Wichtigste benannt, das dieses Paper
NICHT verwischen darf), Conclusion.

**Jede konkrete Zahl im Entwurf stammt direkt aus bereits bestehenden,
gepruesften Repo-Dokumenten** (`BACKLOG.md`, `AGENTS.md`,
`docs/research/EVALUATION_LEVELS.md`, `docs/research/BENCHMARK_PROTOCOL.md`,
`docs/research/EXTERNAL_BENCHMARK_SET.md`, beide Ablationsdokumente) - keine neue
Recherche, kein neuer Code-Lauf, reine Syntheseleistung. Ein
"How to use this draft"-Abschnitt am Ende benennt explizit, was noch
menschliche Entscheidungen braucht (Ziel-Venue, echte Literaturrecherche,
Autorenliste/Anonymisierung, Abbildungen/Tabellen) statt diese Fragen
stillschweigend selbst zu beantworten.

**Kein Code geaendert** - reine Dokumentation, kein `testthat`-Lauf
zwingend erforderlich, aus Vorsicht trotzdem verifiziert (weiterhin
322/322 gruen).

Damit ist die GESAMTE P0-P3-Roadmap des dritten Bewertungsdokuments
(2026-08-29) abgearbeitet.

### docs/research/PAPER_DRAFT.md - Literaturrecherche fuer Section 3 (2026-08-29)

**Nutzeranfrage**: "literaturrecherche fuer Section 3 anfangen" - einer
der beiden im Draft selbst als offen benannten Punkte (der andere:
Ziel-Venue festlegen).

Section 3 ("Related Work") war zuvor ein reiner Platzhalter. Jetzt: 14
per Websuche lokalisierte und inhaltlich geprueft Quellen (keine
Erinnerungs-Zitate), gegliedert in 6 thematische Abschnitte -
AutoML-Systeme (Auto-sklearn/Feurer 2015, AutoGluon-Tabular/Erickson
2020, das AutoML-Buch/Hutter/Kotthoff/Vanschoren 2019), Benchmark-
Methodik (OpenML-CC18/Bischl 2021, "An Open Source AutoML Benchmark"/
Gijsbers 2019 - direkt relevant fuer die eigene `docs/research/BENCHMARK_PROTOCOL.md`-
Disziplin), Daten-Leakage/Dataset-Shift (Kaufman/Rosset/Perlich 2011,
Quinonero-Candela et al. 2009 - direkt relevant fuer Section 7.1/7.2),
Reproduzierbarkeit/Testing (Pineau et al. 2021, Gundersen/Kjensmo 2018,
Breck et al. 2017 "ML Test Score", Zhang/Harman/Ma/Liu 2020), Klassen-
Imbalance (He/Garcia 2009), sowie die bereits verwendete Software selbst
(mlr3/Lang 2019, Caruana et al. 2004 Ensemble Selection).

Jede Quelle wird explizit zu einer konkreten eigenen Aussage in Bezug
gesetzt (nicht nur aufgelistet) - z.B. AutoGluons Multi-Layer-Stacking-
Ergebnis wird bewusst als IN SPANNUNG zum eigenen Level-2-Negativbefund
stehend benannt, statt die Spannung zu verschweigen. **Eine bewusste
Ehrlichkeitsentscheidung**: Adversarial Validation selbst bekommt KEINE
akademische Zitation - die Technik ist in ihrer heute verbreiteten Form
am ehesten als Kaggle-/Praktiker-Technik dokumentiert, nicht als
Ergebnis eines einzelnen peer-reviewten Ursprungspapers; ein erfundenes
Zitat waere schlechter als die ehrliche Luecke. Ein `References`-
Abschnitt mit allen 14 Quellen (inkl. URLs) wurde ergaenzt.

**Bewusst nicht erledigt** (im Draft selbst so benannt): Zitate sind
NICHT auf ein Referenzmanager-/BibTeX-Format normalisiert; die Abdeckung
ist bewusst eng auf das begrenzt, was dieses Paper tatsaechlich beruehrt,
keine erschoepfende AutoML-Uebersicht. "How to use this draft" im
Dokument entsprechend aktualisiert (Punkt 2 war "Section 3 ist ein
Platzhalter", jetzt der aktuelle Stand + die offene Adversarial-
Validation-Zitations-Entscheidung).

Kein Code geaendert - reine Dokumentation, `testthat` trotzdem
vorsichtshalber verifiziert (weiterhin 322/322 gruen).

### docs/research/PAPER_DRAFT.md - Ziel-Venue festgelegt: JOSS (2026-08-29)

**Nutzeranfrage**: "ziel-venue festlegen", per `AskUserQuestion`
beantwortet mit "JOSS (Software-Paper, Empfehlung)" (Alternativen waren
AutoML-Conf Workshop/Applications-Track, "nur als Preprint haerten",
oder eine frei benannte andere Venue).

**Wichtige Konsequenz, per Websuche verifiziert**: JOSS reviewt die
SOFTWARE, kein vollstaendiges empirisches Paper - die Einreichung ist
ein kurzes `paper.md` (750-1750 Woerter: Summary, Statement of Need,
Comparison to existing software, Acknowledgements) mit YAML-Header
(Titel/Autoren/Affiliations/Tags) und einer separaten `paper.bib`.
`docs/research/PAPER_DRAFT.md` (der bisherige 9-Abschnitte-Volltext) ist damit NICHT
mehr die Einreichung selbst, sondern dient als der "extended technical
report", auf den `paper.md` fuer die volle Level-1/2-Auswertung
verweist - explizit als solcher umdeklariert, keine Loeschung.

Neuer Ordner `joss/`:
- [`joss/paper.md`](joss/paper.md) - die eigentliche Einreichung (787
  Woerter, innerhalb des 750-1750-Limits), mit Autoren-/Affiliation-/
  ORCID-Platzhaltern (bewusst NICHT erfunden, explizit als `TODO`
  markiert)
- [`joss/paper.bib`](joss/paper.bib) - 6 BibTeX-Eintraege (Teilmenge der
  14 Quellen aus `docs/research/PAPER_DRAFT.md`s Section 3 - JOSS-Papers zitieren
  sparsam, sind keine Literaturuebersicht)
- [`joss/README.md`](joss/README.md) - dokumentiert die Rollenteilung
  und listet explizit, was VOR einer echten Einreichung noch fehlt
  (Autoren/Affiliation ausfuellen, JOSS-Repo-Checkliste pruefen -
  Lizenzdatei/Contributing-Guidelines noch nicht gegen JOSS-Kriterien
  verifiziert -, lokal kompilieren, tatsaechlich einreichen)

`docs/research/PAPER_DRAFT.md`s Kopf-Status und "How to use this draft" Punkt 1
entsprechend aktualisiert (Ziel-Venue jetzt "DECIDED", nicht mehr offen).

**Bewusst nicht erledigt**: keiner der in `joss/README.md` gelisteten
Vorbereitungsschritte wurde ausgefuehrt - dies ist ein erster Entwurf
der Einreichungs-TEXTE, keine fertige Einreichung.

Kein Code geaendert - reine Dokumentation, `testthat` trotzdem
vorsichtshalber verifiziert (weiterhin 322/322 gruen).

**Nachtrag (2026-08-29): Autoren/Affiliation ausgefuellt.**
Nutzeranfrage "autoren und affiliation in joss/paper.md ausfuellen" -
per `AskUserQuestion` bestaetigt: Name "Andre Endress" (aus dem
oeffentlichen GitHub-Profil `kubischraumzentriert` uebernommen, vom
Nutzer bestaetigt statt automatisch verwendet), Affiliation
"Independent Researcher" (kein Institut/Firma im Profil hinterlegt),
keine ORCID (Feld aus dem YAML-Header entfernt statt als leerer
Platzhalter stehen zu bleiben). `joss/README.md`s Vorbereitungsliste
entsprechend aktualisiert (Punkt 1 jetzt "DONE"). Die
Acknowledgements-Sektion bleibt bewusst ein offener `TODO` - nichts
wurde hineingeraten.

### docs/research/PAPER_DRAFT.md/joss/ - JOSS-Repo-Checkliste geprueft + Lizenz ergaenzt (2026-08-29)

**Nutzeranfrage**: "JOSS-Repo-Checkliste pruefen", dann "welche Lizenz
empfiehlst Du", dann "ja, MIT eintragen".

**Wichtiger struktureller Fund, per Doppel-Websuche gegen JOSS' aktuelle
Docs verifiziert (nicht aus dem Gedaechtnis angenommen)**: `paper.md`
braucht inzwischen 6 statt 4 Pflichtabschnitte - zusaetzlich zu Summary/
Statement of Need/State of the Field/Acknowledgements/References
zwingend auch **Software Design**, **Research Impact Statement** und
**AI Usage Disclosure**. `joss/paper.md` entsprechend erweitert:
- Software Design: die 4 zentralen Architektur-Trade-offs erklaert
  (flaches Skript-Template statt R-Paket, lokale Projekt-DB statt
  geteilter Live-DB, R-only-Policy mit Python nur als Export, die
  >=2-Projekt-Backport-Regel)
- Research Impact Statement: EHRLICH und KONKRET statt aspirational
  (JOSS verlangt explizit "compelling and specific, not aspirational") -
  3 extern nachpruefbare Ergebnisse (CreditScoringChallenge-Leak extern
  fast exakt bestaetigt, Ensemble-Selection-Leaderboard-Verbesserung bei
  einer laufenden Kaggle-Competition, BAcc 0.9482 auf health_condition),
  plus das externe OpenML-CC18-Benchmark-Ergebnis - UND explizit
  ehrlich benannt, dass das Template bislang NICHT von anderen Teams
  uebernommen wurde (keine Uebertreibung).
- AI Usage Disclosure: transparent offengelegt, dass ein erheblicher
  Teil von Code/Doku/diesem Paper in Sessions mit Claude (Anthropic)
  entstand, unter durchgehender menschlicher Steuerung/Pruefung, mit
  Verweis auf die eigene Verifikationsdisziplin (Tests/CI/>=2-Projekt-
  Regel) und die Co-Authored-By-Vermerke in der Commit-Historie.

Neue Wortzahl: 1342 (weiterhin innerhalb 750-1750).

**Repo-Checkliste gegen die restlichen JOSS-Kriterien** (Source-Repo,
Lizenz, Community-Guidelines, Installation, Beispielnutzung, API-Doku,
Tests): 5 von 7 bereits erfuellt. **Lizenz fehlte** (`"license": null`
via GitHub-API bestaetigt) - dafuer wurde der Nutzer per
`AskUserQuestion` gefragt (Optionen: MIT/Apache-2.0/GPL-3.0/andere),
die Frage zunaechst weggeklickt ("nicht fortfahren"). Auf explizite
Nachfrage "welche Lizenz empfiehlst Du" MIT empfohlen (Standard fuer
JOSS/R-Pakete, passt zum "kopier's dir"-Zweck des Templates, kein
Copyleft-Zwang wie GPL). Nutzer bestaetigte MIT explizit ("ja, MIT
eintragen").

**Neue Datei [`LICENSE`](LICENSE)** (Repo-Root): MIT, Copyright (c) 2026
Andre Endress. `joss/README.md`s Checkliste entsprechend aktualisiert
(Tabelle mit allen 7 Kriterien, Lizenz jetzt "DONE").

**Verbleibende Luecke, unveraendert offen**: Community-/Contribution-
Guidelines (`CONTRIBUTING.md`/Issue-Templates fehlen weiterhin) - noch
nicht adressiert, auf explizite Nutzeranweisung.

Kein Code geaendert - reine Dokumentation, `testthat` trotzdem
vorsichtshalber verifiziert (weiterhin 322/322 gruen).

**Nachtrag (2026-08-29): Contribution-Guidelines ergaenzt.**
Nutzeranfrage "ja, Contribution-Guidelines ergaenzen" - letzte offene
Luecke der JOSS-Repo-Checkliste geschlossen. Neue Dateien:
- [`CONTRIBUTING.md`](CONTRIBUTING.md) (Repo-Root, Englisch, passend zum
  `joss/`-Ordner): beschreibt EHRLICH die tatsaechliche Praxis statt
  eines generischen Prozesses - Bug-Reports/Support ausschliesslich via
  GitHub Issues (keine garantierte Reaktionszeit, Einzelbetreuer),
  UND der zentrale, template-eigene Vorbehalt bei neuen Modulen: ein PR
  mit einer echten Neuerung wird erst nach Bestaetigung an >=2
  unabhaengigen Projekten (oder Null-Ergebnis-Beleg) in den geteilten
  Template-Teil gemergt - Verweis auf `adr/003-backport-after-
  confirmation.md`. Dokumentations-PRs sind davon ausdruecklich
  ausgenommen.
- `.github/ISSUE_TEMPLATE/bug_report.md` und `feature_request.md` -
  Letzteres verweist explizit auf dieselbe >=2-Projekt-Regel, damit
  niemand einen sofortigen Merge erwartet.
- `README.md` um einen Verweis auf `CONTRIBUTING.md` ergaenzt.

`joss/README.md`s Checkliste aktualisiert: **alle 7 JOSS-Kriterien jetzt
erfuellt.** Verbleibend fuer eine tatsaechliche Einreichung nur noch:
lokal kompilieren (JOSS-Vorschau-Tooling) und die eigentliche
Einreichung selbst - beides bewusst nicht Teil dieser Sitzung.

Kein Code geaendert - reine Dokumentation, `testthat` trotzdem
vorsichtshalber verifiziert (weiterhin 322/322 gruen).

**Nachtrag (2026-08-29): JOSS-Vorschau-GitHub-Action eingerichtet.**
Nutzerfrage "JOSS Vorschau tooling was ist das?" beantwortet (Whedon-
Web-Vorschau, GitHub Action, lokal via Docker/`inara` - alle 3 nutzen
dasselbe Tool wie JOSS selbst fuer den echten Review), danach
Nutzeranfrage "ja, GitHub Action einrichten". Neue Datei
[`.github/workflows/draft-pdf.yml`](.github/workflows/draft-pdf.yml):
baut bei jeder Aenderung an `joss/paper.md`/`joss/paper.bib`
(Path-Filter, analog zum bestehenden CI-Smoke-Test-Workflow) via
`openjournals/openjournals-draft-action` eine unverbindliche Vorschau-
PDF und laedt sie als Actions-Artifact hoch - reine Formatierungs-/
Zitations-Pruefung, KEINE Einreichung. `joss/README.md`/`BACKLOG.md`
entsprechend ergaenzt.

### JOSS-Einreichung pausiert (2026-08-30): 2 echte Risiken gefunden, Wiedervorlage ~Nov 2026

**Nutzerfrage** "JOSS einreichen, wie geht das?" fuehrte zur Entdeckung
eines harten Blockers, dann auf explizite Nutzer-Links zwei weiteren,
unabhaengig verifizierten Funden (nicht aus dem Gedaechtnis, sondern
gegen `joss.readthedocs.io/submitting.html` und den JOSS-Blog-Post
`2026/01/preparing-joss-for-a-generative-ai-future` geprueft):

1. **Hart, objektiv, aktuell blockierend**: JOSS verlangt >=6 Monate
   oeffentliche Repo-Historie mit aktiver Entwicklung vor Einreichung
   (explizit in beiden Quellen). Erster Commit dieses Repos: 2026-07-07
   (per `git log --reverse` bestaetigt, 256 Commits seither) -
   einreichungsfaehig fruehestens ~2027-01-07.
2. **Weich, inhaltlich, loest sich NICHT einfach durch Zeitablauf**:
   JOSS' "Scope and Significance"-Kriterium definiert "research
   software" eng (komplexe Modellierungsprobleme in einem
   wissenschaftlichen Kontext, Forschungsinstrumente, Wissens-
   extraktion aus grossen Datensaetzen, mathematische Bibliotheken) und
   schliesst explizit "pre-trained machine learning models and
   notebooks" aus. Ein Wettbewerbs-Methodik-Template (Kaggle/Zindi/
   OpenML) ist seinem Wesen nach eher ein Engineering-Practice-Werkzeug
   als ein Werkzeug fuer wissenschaftliche Domain-Modellierung - echtes
   Scope-Fit-Risiko, unabhaengig vom Alters-Gate.

**Nutzerentscheidung**: Publikationsziel bleibt JOSS, Einreichung
bewusst PAUSIERT (nicht aufgegeben), Wiedervorlage in ~2-3 Monaten
(~November 2026 - noch VOR dem 6-Monats-Gate, aber sinnvoll fuer eine
Zwischenbilanz zum "Research Aspect").

**Vorschlag fuer einen echten "Research Aspect" bis dahin** (meine
Einschaetzung auf explizite Nachfrage): der vielversprechendste Hebel
ist, P2s bislang UNERKLAERTES gemischtes Level-2-Ergebnis (3 Siege/3
Niederlagen ueber die 6 externen CC18-Datensaetze, keine saubere
Groessen-/Imbalance-Erklaerung gefunden) tatsaechlich zu erklaeren -
z.B. durch systematische Variation des Tuning-Budgets (aktuell nur 10
Evals/Arm) und/oder Pruefung, ob Datensatz-Metafeatures (effektive
Stichprobengroesse fuer die innere Modellwahl, Naehe zu einer
Saettigungsgrenze, Score-Varianz je Fold) vorhersagen, wann Level 2
hilft vs. schadet. Eine bestaetigte Erklaerungshypothese waere ein
echter methodischer Beitrag (naeher an tatsaechlicher AutoML-Forschung
als ein Engineering-Protokoll) - staerkt das Paper unabhaengig davon,
ob am Ende JOSS oder eine andere Venue (z.B. AutoML-Conf) das Ziel
bleibt.

Auch im persistenten Gedaechtnis festgehalten (Datei
`project_joss_publication_timeline.md`), damit eine kuenftige Session
das nicht neu herleiten muss.

### Research Aspect, 1. Schritt (2026-08-30): formaler Signifikanztest fuer P2 statt informeller "3/3"-Zaehlung

**Nutzeranfrage**: "mach weiter mit dem Research Aspect, auf der Seite
joss.theoj.org gibt es vielleicht interessante papers ... was meinst
Du?" - JOSS-Papersuche nach AutoML-/Benchmark-/Ranking-relevanten
Arbeiten durchgefuehrt (Browser, `joss.theoj.org/papers/search`).

**Fund**: **Autorank** (Herbold 2020, JOSS,
`10.21105/joss.02173`) implementiert die Standardmethodik von
**Demsar (2006)**, *"Statistical Comparisons of Classifiers over
Multiple Data Sets"* (JMLR) - Wilcoxon-Signed-Rank bei 2 Verfahren,
Friedman+Nemenyi bei mehr, fuer Mehrfach-Datensatz-Vergleiche. Genau die
Methodik, die unserem bisherigen "3 Siege/3 Niederlagen, Delta ≈ -0.7"-
Befund aus P2 fehlte. Autorank selbst ist Python - **bewusst NICHT
uebernommen** (R-only-Policy), stattdessen dieselbe Methodik nativ in R
angewendet (`stats::wilcox.test`, Basis-R, kein neues Paket noetig).

**Neues Skript** [`analysis/p2_level2_significance_test.R`](analysis/p2_level2_significance_test.R)
(Repo-Root): gepaarter, exakter Wilcoxon-Signed-Rank-Test ueber die 6
Datensaetze (EIN aggregierter Wert pro Datensatz, nicht pro Outer-Fold -
Folds sind nicht unabhaengig, das wuerde die Stichprobe kuenstlich
aufblaehen). **Ergebnis: V = 8, p = 0.6875** - bei n = 6 statistisch
NICHT von einem Nulleffekt unterscheidbar. Demsar selbst empfiehlt fuer
den Wilcoxon-Test ~8-10 Datensaetze fuer ausreichende Power - eine
echte Stichprobengroessen-Einschraenkung, kein Kunstfehler.

**In `docs/research/PAPER_DRAFT.md` eingearbeitet**:
- Section 6 (Level-2-Negativbefund): der formale Test ergaenzt (nicht
  ersetzt) die informelle 3/3-Zaehlung, mit der expliziten Begruendung,
  warum das wichtig ist ("a small, cherry-pickable set of deltas can
  look more like a 'pattern' ... than the data actually support").
- Section 8 (Limitations): der bisherige "No formal significance
  testing"-Punkt praezisiert - gilt jetzt nur noch fuer die UEBRIGEN
  Vergleiche (Sections 5/7), nicht mehr fuer den Level-1-vs-2-Vergleich.
- Section 3 (Related Work): Demsar (2006)/Autorank als eigener
  Methodik-Absatz ergaenzt.
- References: beide Quellen ergaenzt.

**Einordnung fuer den Research-Aspect insgesamt**: das ist ein erster,
GUENSTIGER Schritt (reine Nachanalyse bestehender Zahlen, kein neuer
Lauf) - macht die Ehrlichkeit des Negativbefunds praeziser/belastbarer,
ERKLAERT aber noch NICHT, warum das Muster existiert (das bleibt der
naechste, teurere Schritt: Tuning-Budget-Variation und/oder
Metafeature-Analyse, siehe oben).

### Alternative Ziel-Venue notiert: AutoML-Conf (2026-08-30)

**Nutzerhinweis**: "Wir sollten auch AutoML-Conf-Workshop nicht
vergessen - eventuell koennen wir dort ein paper einreichen".

Per Websuche geprueft (`2026.automl.cc/dates/`): **AutoML-Conf 2026
ist fuer diesen Zyklus nicht mehr erreichbar** - Haupt-/ABCD-Track-
Deadline war 2026-05-14, selbst Late-Breaking-Abstracts schliessen
2026-08-31, Workshop-Proposals schlossen bereits 2026-06-30.

**AutoML-Conf 2027 ist die reale Option** - CFP dafuer im Auge behalten
(vermutlich aehnlicher Rhythmus wie 2026, Hauptdeadline ~April/Mai
2027). Der **ABCD-Track** ("Applications, Benchmarks, Challenges,
Datasets") passt inhaltlich vermutlich SOGAR BESSER als JOSS zu diesem
Projekt - Benchmark-Protokoll, Evaluations-Ebenen-Framework, ehrliche
Negativbefunde sind genau das, was ABCD sucht, waehrend JOSS' enge
"research software"-Scope-Definition (siehe oben, "JOSS-Einreichung
pausiert") ein Wettbewerbs-Methodik-Template nicht sauber abdeckt.
Kein Konflikt mit dem JOSS-Zeitplan (~2027-01-07 einreichungsfaehig) -
beide Optionen koennen parallel verfolgt werden.

Auch im persistenten Gedaechtnis ergaenzt
(`project_joss_publication_timeline.md`).

### Research Aspect, 2. Schritt (2026-08-30): Tuning-Budget-Hypothese getestet und AUSGESCHLOSSEN

**Nutzeranfrage**: "ja, mach weiter mit dem Tuning-Budget-Test".

`outer_workflow_evaluation_v3_level2.R` um `LEVEL2_TUNING_EVALS`
(Umgebungsvariable, Default weiterhin 10) ergaenzt, dann alle 6
externen Datensaetze mit **30 Evals/Arm** (3x Budget) neu gelaufen
(root-Template + alle 6 `ML_Learning`-Projektkopien synchronisiert).

**Ergebnisse (30 Evals) im Vergleich zu 10 Evals**:

| Datensatz | Level2 @10 | Level2 @30 | Delta | bisher bester Wert | @30 gewinnt/verliert |
|---|---|---|---|---|---|
| `ilpd` | 0.6473 | **0.6919** | +4.5 | 0.6840 | **Sieg** (vorher Niederlage!) |
| `optdigits` | 0.9859 | 0.9818 | -0.4 | 0.9840 | Niederlage (vorher Sieg!) |
| `sick` | 0.9723 | 0.9712 | -0.1 | 0.9714 | ~neutral |
| `cmc` | 0.5113 | 0.5122 | +0.1 | 0.5374 | Niederlage (unveraendert) |
| `analcatdata-authorship` | 0.9731 | 0.9818 | +0.9 | 0.9921 | Niederlage (unveraendert, kleiner) |
| `blood-transfusion` | 0.6878 | 0.6720 | -1.6 | 0.6576 | Sieg (unveraendert, kleiner) |

**Formaler Test (in `analysis/p2_level2_significance_test.R` erweitert, 3
Fragen)**: gepaarter Wilcoxon-Signed-Rank-Test 30-Evals- vs. 10-Evals-
Level2 direkt gegeneinander - **V = 11, p = 1.0**. Das ist der denkbar
nullste Befund: KEIN nachweisbarer systematischer Effekt der
Budget-Verdreifachung. `ilpd` und `optdigits` flippen sogar in
GEGENSAETZLICHE Richtungen (ilpd wird deutlich besser, optdigits leicht
schlechter). Die Aggregat-Signifikanz gegen den bisher besten Wert
bleibt bei 30 Evals identisch nicht-signifikant (V=8, p=0.6875 -
exakt derselbe Wert wie bei 10 Evals).

**Einordnung**: die Tuning-Budget-Hypothese fuer P2s gemischtes Muster
ist damit sauber AUSGESCHLOSSEN, nicht nur ungetestet - ein negativer,
aber werthaltiger Befund (grenzt den Erklaerungsraum ein statt ihn offen
zu lassen). Mehr Budget aendert, WELCHE Datensaetze gewinnen, nicht OB
Level 2 im Aggregat gewinnt. Alle 7 neuen Ergebnisse (6 Datensaetze +
der aggregierte Vergleichstest) in die Evidence Registry geloggt.

**In `docs/research/PAPER_DRAFT.md` eingearbeitet**: neuer Absatz in Section 6 (nach
dem urspruenglichen Signifikanztest), Limitations-Punkt zum Tuning-
Budget aktualisiert (war "untested", ist jetzt "getestet, kein Effekt
bei 3x - groessere Budgets als 30 bleiben ungetestet").

**Verbleibender Kandidat fuer den Research Aspect**: die Metafeature-
basierte Erklaerung (Inner-Tune-Zeilenzahl, Score-Streuung, Naehe zur
Saettigungsgrenze) - reine Nachanalyse bereits vorhandener Zahlen, kein
neuer Lauf noetig. Noch nicht durchgefuehrt.

Kein neuer Code-Test noetig (Skriptaenderung war additiv/rueckwaerts-
kompatibel, bereits im vorherigen Commit mit 322/322 gruen verifiziert).

### Research Aspect, 3. Schritt (2026-08-30): Metafeature-Analyse - ebenfalls KEINE Erklaerung gefunden

**Nutzeranfrage**: "ok mach weiter mit dem nächsten Kandidat".

Reine Nachanalyse bereits vorhandener Zahlen (kein neuer Modell-Lauf).
Klassenverteilungen direkt aus den gespeicherten `task_train_small.rds`-
Objekten gelesen (nicht geschaetzt): ilpd 28.6% Minderheitsklasse, sick
6.1%, blood-transfusion 23.8%, cmc 22.6% (3-Klassen), analcatdata-
authorship 6.5% (4-Klassen), optdigits 9.9% (10-Klassen, fast perfekt
balanciert).

**Neues Skript** [`analysis/p2_level2_metafeature_analysis.R`](analysis/p2_level2_metafeature_analysis.R):
5 Kandidaten-Metafeatures gegen das Level2@10-vs-bester-Wert-Delta
getestet (Spearman-Korrelation, n=6): Datensatzgroesse, Klassen-
imbalance, Minderheitsklassen-Zeilenzahl im Inner-Tune-Split (25% von
outer_train - die tatsaechliche Stichprobe fuer die innere Modellwahl),
Score-Streuung des Level2-Arms ueber die Outer-Folds (Instabilitaets-
Proxy), und "Deckennaehe" (bisher bester Wert als Saettigungs-Proxy,
motiviert durch die beobachtete Sättigung bei `analcatdata-authorship`).

**Ergebnis: KEINE der 5 Metafeatures zeigt eine nennenswerte
Korrelation** - alle |Spearman-rho| <= 0.37, alle p >= 0.49 bei n=6.

**Gesamteinordnung des Research Aspect (alle 3 Schritte)**: nach
Ausschluss von Datensatzgroesse/Klassenimbalance (Schritt 1, informell
beim Rollout), Tuning-Budget (Schritt 2, formal per Wilcoxon-Test
ausgeschlossen) UND 5 weiteren Metafeatures (Schritt 3) bleibt P2s
gemischtes Level-2-Muster OHNE einfache univariate Erklaerung. Zwei
plausible Deutungen, mit n=6 nicht unterscheidbar: entweder eine
Interaktion hoeherer Ordnung zwischen mehreren Faktoren, oder das Muster
ist naeher an irreduzierbarem Datensatz-Rauschen als an einem
systematischen Effekt. Eine Unterscheidung wuerde ein deutlich groesseres
externes Benchmark-Set erfordern als die hier verwendeten 6 Datensaetze -
bewusst als offene Grenze benannt statt eine schwache Korrelation
ueberzuinterpretieren.

**In `docs/research/PAPER_DRAFT.md` eingearbeitet**: neuer Absatz am Ende von
Section 6, der diese ehrliche Schlussfolgerung explizit zieht statt den
Versuch zu verschweigen.

Ergebnis in die Evidence Registry geloggt (Rolle `score_lever`, Status
`negative`).

**Damit ist der Research-Aspect-Weg (3 Schritte: formaler
Signifikanztest, Tuning-Budget-Test, Metafeature-Analyse) fuer diese
Sitzung abgeschlossen** - alle 3 Schritte liefern zusammen ein deutlich
praeziseres, ehrlicheres Bild von P2s Level-2-Befund als die
urspruengliche "3 Siege/3 Niederlagen"-Formulierung, auch wenn keiner
der Schritte eine positive Erklaerung liefert. Das ist selbst der Kern
der Paper-Story: eine grundliche, ehrliche Suche nach einer Erklaerung,
die mehrere plausible Kandidaten sauber ausschliesst, ist wertvoller als
eine ungeprüfte Vermutung.

## Naechste Bewertung 2026-08-30 (extern, Dokumentationskonsistenz + JOSS-Technique-Watch)

Neues externes Bewertungsdokument vom Nutzer eingebracht:
`AutoML_Bewertung_Naechste_Schritte_JOSS_Technique_Watch_2026-08-30.md`
(`~/Downloads`). Gesamtnote im 9.5-9.9-Bereich je nach Kategorie -
**Kernaussage**: das Projekt ist technisch weitgehend ausgereift, der
Engpass liegt nicht mehr in Software-/ML-Funktionalitaet, sondern in
"wissenschaftlicher Evidenzbreite, externer Nutzung,
Dokumentationskonsistenz und der Schaerfung der Publikationsstrategie".

**Wichtigster konkreter Kritikpunkt**: Dokumentationsdrift - mehrere
zentrale Dokumente hinken der tatsaechlichen Software-Entwicklung
hinterher (konkrete Beispiele: `docs/research/EVALUATION_LEVELS.md`s Roadmap-Abschnitt
sagte noch "P1/P2/P3 offen", `docs/research/EXTERNAL_BENCHMARK_SET.md` sagte noch
"Noch NICHT ausgefuehrt" - beides laengst ueberholt). Weitere Punkte:
JOSS-Draft-Sprachgebrauch ("package" vs. "template/software"
uneinheitlich), Evidence-Registry-Claim zu pauschal formuliert
(verschweigt die Arbeitsteilung manuell/generiert).

**Vorgeschlagene neue Roadmap**: P0 Dokumentationskonsistenz (guenstig),
P1 `docs/research/JOSS_TECHNIQUE_WATCH.md` + optionale Research-Benchmark-Erweiterung
auf 10-15 Datensaetze (teurer), P2 erster JOSS-inspirierter
Forschungsprototyp (VeridicalFlow/PCS-Decision-Stability oder
astartes/schwierige Splits), P3 externe Adoption vorbereiten.

**Nutzerentscheidung**: Start mit **P0**.

### P0 - Status (2026-08-30): Dokumentationskonsistenz-Pass

Alle 3 konkret benannten Faelle behoben:

1. **`docs/research/EVALUATION_LEVELS.md`**: Roadmap-Abschnitt ("Bezug zur neuen
   Roadmap") von "P1/P2/P3 Noch offen" auf den tatsaechlichen Stand
   korrigiert (alle 3 erledigt, mit Verweisen auf die jeweiligen
   Ergebnisdokumente).
2. **`docs/research/EXTERNAL_BENCHMARK_SET.md`**: "Noch NICHT ausgefuehrt"-Hinweis am
   Kopf und der "Naechster Schritt (nicht Teil dieses Dokuments)"-
   Abschnitt am Ende beide auf "AUSGEFUEHRT" mit Verweisen auf die
   tatsaechlichen Ergebnisse (`BACKLOG.md`, `docs/research/EVALUATION_LEVELS.md`,
   `docs/research/PAPER_DRAFT.md`) aktualisiert.
3. **`joss/paper.md`**: durchgehend "this package"/"the package"/
   "package's" durch "this template"/"the template"/"template's"
   ersetzt (10 Stellen) - `mlr3`-Paket-Referenzen und der explizite
   "nicht ein installierbares R-Paket"-Kontrast in Section "Software
   Design" bewusst unveraendert gelassen, da dort "package" der
   korrekte technische Begriff ist. Wortzahl bleibt bei 1382 innerhalb
   des 750-1750-Limits.
4. **Evidence-Registry-Claim praezisiert**: sowohl in `joss/paper.md`s
   Summary als auch in `docs/research/PAPER_DRAFT.md` Abschnitt 2.4 wurde die
   pauschale Aussage ("jeder Claim ist per Evidence-Registry-Eintrag
   belegt") durch die tatsaechliche Arbeitsteilung ersetzt - die 9
   urspruenglichen Trust-Module bleiben in der handgepflegten
   `docs/research/SYSTEMATIC_EVALUATION.md` verankert, NUR die neueren Outer-
   Evaluation-Befunde (Phase C/P1/P2) laufen ausschliesslich ueber die
   generierte Evidence-Registry-Tabelle - mit explizitem Verweis auf
   die Arbeitsteilungs-Entscheidung in `BACKLOG.md`/P2-Status
   (2. Haelfte).

**Weitere geprueft, kein Fund**: `docs/research/BENCHMARK_PROTOCOL.md`,
`BACKLOG.md` selbst (chronologisches Journal - historische "noch nicht
ausgefuehrt"-Eintraege sind fuer ihren Zeitstempel korrekt und werden
von spaeteren Eintraegen ueberholt, keine Korrektur noetig), `AGENTS.md`
(ein aehnlicher Treffer war bereits eine selbst-korrigierende
historische Anmerkung, keine Drift).

Kein Code geaendert - reine Dokumentation, `testthat` trotzdem
vorsichtshalber verifiziert.

**Offen**: P1 (`docs/research/JOSS_TECHNIQUE_WATCH.md` anlegen, optionale Research-
Benchmark-Erweiterung), P2 (erster JOSS-inspirierter Prototyp), P3
(externe Adoption) - auf explizite Nutzeranweisung.

### P1 - Status (2026-08-30): docs/research/JOSS_TECHNIQUE_WATCH.md angelegt

**Nutzeranfrage**: "ja, docs/research/JOSS_TECHNIQUE_WATCH.md anlegen".

Neue Datei [`docs/research/JOSS_TECHNIQUE_WATCH.md`](docs/research/JOSS_TECHNIQUE_WATCH.md): alle
7 im Bewertungsdokument genannten Kandidaten (VeridicalFlow, astartes,
Autorank, PyExperimenter, ReciPies, ImageMLResearch, mlr3extralearners)
strukturiert dokumentiert (Titel/Autoren/DOI/Problem/Uebertragbarkeit/
"haben wir dieses Problem"/Hypothese/Nutzen/Komplexitaetskosten/
Prototype/Backport-Status), plus ein Erinnerungs-Eintrag fuer mlr3
selbst (vor neuer Eigeninfrastruktur regelmaessig gegenpruefen).

**Vor dem Uebernehmen verifiziert, nicht blind aus dem
Bewertungsdokument kopiert**: alle 7 DOIs/Autoren/Jahre einzeln direkt
gegen `joss.theoj.org/papers/<DOI>` geprueft (Browser) - alle 7 stimmten
exakt.

**Wichtiger Zwischenfund beim Schreiben**: Autorank ist kein reiner
Watch-Punkt mehr, sondern **teilweise bereits umgesetzt** - die
Demsar-(2006)-Wilcoxon-Methodik laeuft bereits produktiv in
`analysis/p2_level2_significance_test.R` (Research-Aspect-Schritt 1, siehe
oben). Offen bleibt nur eine generische, wiederverwendbare
`benchmark_statistics_report()`-Funktion fuer kuenftige Mehrfach-
Datensatz-Vergleiche.

Prioritaeten aus dem Bewertungsdokument uebernommen: VeridicalFlow +
astartes = hoch, Autorank = hoch sobald n groesser, PyExperimenter/
ReciPies/mlr3-Check = mittel, ImageMLResearch = niedrig-mittel,
mlr3extralearners = niedrig. Die verbindliche ADR-003-Backport-Regel
("NO BACKPORT bis Evidenz vorhanden") explizit im Dokument verankert.

`README.md` um einen Verweis auf `docs/research/JOSS_TECHNIQUE_WATCH.md` ergaenzt.
Noch KEINE Implementierung/Prototyp begonnen - reine Recherche-
Dokumentation, wie vom Bewertungsdokument fuer P1 gefordert.

Kein Code geaendert - reine Dokumentation, `testthat` trotzdem
vorsichtshalber verifiziert.

**Offen**: optionale Research-Benchmark-Erweiterung (Rest von P1), P2
(erster JOSS-inspirierter Prototyp - VeridicalFlow oder astartes als
Top-Kandidaten), P3 (externe Adoption) - auf explizite Nutzeranweisung.

### P2 - Status (2026-08-30): Decision-Stability-Prototyp (VeridicalFlow/PCS-inspiriert)

**Nutzeranfrage**: "mach weiter mit P2", per `AskUserQuestion`
"VeridicalFlow / Decision-Stability-Report" gewaehlt (Alternativen:
astartes/schwierige Splits, oder beide erst grob skizzieren).

Pipeline aus `docs/research/JOSS_TECHNIQUE_WATCH.md` befolgt: Problem identifiziert ->
Hypothese -> Komplexitaetskosten -> kleiner Prototyp -> synthetischer
Test -> 1-2 reale Projekte.

**Neues, generisches Modul** [`decision_stability.R`](decision_stability.R):
`decision_stability_report(decision_fn, n_repeats, seed_start, label,
flag_threshold)` - wiederholt eine beliebige kategoriale Entscheidungs-
funktion unter variierenden Seeds, meldet Verteilung/Mehrheitsentscheidung/
Stabilitaetsanteil, flaggt "AUFFAELLIG" wenn die Mehrheit unter
`flag_threshold` (Default 0.7) liegt. Bewusst NICHT an Level 2 oder ein
bestimmtes Skript gekoppelt - wiederverwendbar fuer jede kuenftige
kategoriale Workflow-Entscheidung. **Klare Abgrenzung zu
`seed_stability.R`**: jenes misst kontinuierliche SCORE-Streuung bei
fixen Daten, dieses Modul misst, ob eine KATEGORIALE Entscheidung
(welches Modell gewinnt) unter denselben Variationen kippt - eine
Entscheidung kann bei fast identischem Score trotzdem instabil sein.

**Synthetischer Test zuerst**:
[`tests/testthat/test-decision_stability.R`](tests/testthat/test-decision_stability.R),
7 Faelle mit bekanntem/kontrolliertem Stabilitaetsverhalten (immer
stabil, deterministisch alternierend, 3-Optionen-Haeufigkeitstabelle,
benutzerdefinierter Schwellenwert, Reproduzierbarkeit bei intern
geseedeter `decision_fn`, Fehlerfall `n_repeats<2`). Gesamtsuite jetzt
340/340 gruen (vorher 322, +18 neue Einzel-Assertions).

**Angewendet auf 1. reales Projekt**: `openml-cc18-ilpd`, Outer-Fold 1
(Outer-Train FIX wie im eingefrorenen Protokoll v3, NUR der Inner-
Split-Seed variiert 10x) - via neues
[`decision_stability_level2_prototype.R`](decision_stability_level2_prototype.R)
(root-Template, wiederverwendet die Modellwahl-Logik aus `outer_
workflow_evaluation_v3_level2.R`, aber nur den inneren Teil - kein
finales Refit/Outer-Test-Scoring, das waere fuer die Stabilitaetsfrage
unnoetig).

**Ergebnis ilpd**: `ranger` gewinnt bei 7/10 Wiederholungen (70%) -
knapp NICHT geflaggt (Schwelle ist "<70%"), aber auch keine
ueberwaeltigende Stabilitaet.

**Ergebnis blood-transfusion (2. reales Projekt, identischer Aufbau)**:
`ranger` gewinnt nur bei 6/10 Wiederholungen (60%) - **GEFLAGGT
AUFFAELLIG** (unter der 70%-Schwelle). Verteilung: ranger=6,
ensemble=2, lightgbm=2.

**Bemerkenswerter, gegen die naive Erwartung laufender Befund**: im
urspruenglichen Level-2-Rollout (P2, siehe oben) hatte `blood-
transfusion` den DEUTLICH BESSEREN Outer-Score (level2_workflow +3.0
BAcc-Punkte gegenueber dem bisher besten Wert - der klarste Level-2-
Sieg ueberhaupt), waehrend `ilpd` den SCHLECHTEREN hatte (-3.7 Punkte,
die klarste Level-2-Niederlage). Die Decision-Stability-Messung zeigt
jetzt das GENAUE GEGENTEIL der naiven Erwartung "instabile Entscheidung
-> schlechteres Ergebnis": `blood-transfusion`s instabilere
Arm-Wahl (60%) gehoert zum besseren Endergebnis, `ilpd`s stabilere
Arm-Wahl (70%) zum schlechteren. Bei n=2 ist das KEIN belastbarer
statistischer Schluss (dieselbe Vorsicht wie beim gesamten Research-
Aspect-Weg oben: kleine Stichprobe, keine Ueberinterpretation), aber
ein bemerkenswerter erster Befund, der zeigt: **Decision Stability (in
diesem gemessenen Sinn) ist offenbar NICHT einfach ein Proxy fuer
"gutes Endergebnis"** - eine instabile Modellwahl kann trotzdem (oder
gerade deswegen, z.B. weil das Mini-Ensemble als robusterer Kompromiss
oefter mitspielt) zu einem guten Outer-Test-Ergebnis fuehren. Das
relativiert einen impliziten Teil der VeridicalFlow-Uebertragungs-
Hypothese ("Stabilitaet = zusaetzliche Trust-Information") - Stabilitaet
ist ein EIGENSTAENDIGES Signal (verdient als solches Beachtung), aber
kein verlaesslicher Vorhersager fuer Ergebnisqualitaet, zumindest nicht
in diesen 2 Faellen.

Beide Ergebnisse in die Evidence Registry geloggt (Rolle `score_lever`,
`ilpd` Status `confirmed`, `blood-transfusion` Status `core_finding`
wegen des gegenlaeufigen Befunds).

**Einordnung nach ADR-003**: 2 unabhaengige Projekte sind die formale
Mindestbestaetigungsschwelle - ABER hier gibt es (noch) keinen
einheitlichen POSITIVEN Befund zum Bestaetigen, sondern zwei
unterschiedliche Stabilitaetswerte mit einem gegenlaeufigen Bezug zum
Endergebnis. **Kein Backport** in dieser Form - das Modul
(`decision_stability.R`) selbst ist generisch und nuetzlich genug, um
im Template zu bleiben (bereits per Test abgesichert), aber die
KONKRETE Anwendung auf die Level-2-Arm-Wahl liefert noch keine klare,
actionable Handlungsempfehlung ("wenn instabil, dann X tun"). Weitere
Datenpunkte (mehr Projekte/Outer-Folds) waeren noetig, bevor eine
Schlussfolgerung wie "instabile Entscheidungen sollten anders behandelt
werden" gerechtfertigt waere.

**Status P2 (VeridicalFlow-Prototyp)**: ABGESCHLOSSEN im Rahmen des
vereinbarten Umfangs (kleiner Prototyp + synthetischer Test + 2 reale
Projekte). Ergebnis: ein funktionierendes, getestetes, wiederverwendbares
Modul PLUS ein ehrlicher, gegen die eigene Ausgangshypothese laufender
Befund - genau die Art Ergebnis, die dieses Projekt bewusst offen
dokumentiert statt zu verschweigen.

### 3 neue ADRs angelegt (2026-08-30)

**Nutzerfrage**: "gibt es eigentlich Kandidaten fuer weitere ADRs?",
dann "ja, alle 3 als ADRs anlegen". Gegen die beiden Kriterien aus
`adr/README.md` gepruefte Kandidaten (echte Alternative + Risiko einer
versehentlichen Umkehrung durch einen kuenftigen Agenten) - alle 3
angelegt:

- [`adr/007-flat-scripts-not-r-package.md`](adr/007-flat-scripts-not-r-package.md):
  flaches Skript-Template statt eines installierbaren R-Pakets (bereits
  in `joss/paper.md`s Software-Design-Abschnitt begruendet, hier als
  ADR fixiert).
- [`adr/008-frozen-versioned-benchmark-protocols.md`](adr/008-frozen-versioned-benchmark-protocols.md):
  Benchmark-Protokolle (v1/v2/v3) werden eingefroren und versioniert,
  nie in-place veraendert - formalisiert die bereits gelebte Praxis
  (neue Protokollversion = neue Datei, nie die alte editieren).
- [`adr/009-evidence-registry-dual-source-split.md`](adr/009-evidence-registry-dual-source-split.md):
  Evidence Registry und `docs/research/SYSTEMATIC_EVALUATION.md` bleiben dauerhaft
  getrennte Quellen mit fester Arbeitsteilung (formalisiert die
  P2-2.-Haelfte-Entscheidung vom 2026-08-29).

Ein 4. Kandidat (`docs/research/PAPER_DRAFT.md` vs. `joss/paper.md` als getrennte
Dokumente) wurde als schwaecher/schmaler im Scope eingeordnet und
NICHT angelegt, auf Nachfrage aber genannt.

`adr/README.md`s Index-Tabelle aktualisiert (jetzt 9 ADRs).

### P2 - Decision-Stability-Prototyp auf alle 6 externen Datensaetze ausgerollt (2026-08-30)

**Nutzeranfrage**: nach Rueckfrage zur Stichprobengroesse ("sollten wir
n erhoehen ... auf 8?") wurde geklaert, dass "n" die Anzahl getesteter
PROJEKTE meint (nicht die 10 Wiederholungen/Projekt) - Empfehlung: auf
alle 6 bereits eingefrorenen externen Datensaetze gehen statt auf 8 mit
2 methodisch fragwuerdigen Zusatzprojekten (Benchmark-Selection-Bias-
Risiko). Nutzerentscheidung: "mach mit allen 6 weiter".

**Volles Ergebnis (Outer-Fold 1, identischer Aufbau wie bei ilpd/
blood-transfusion)**:

| Datensatz | Stabilitaet | Geflaggt? | Level-2-Delta (vs. bisher bester Wert) |
|---|---|---|---|
| `ilpd` | 70% | nein | -3.7 |
| `blood-transfusion` | 60% | ja | +3.0 |
| `sick` | 60% | ja | +0.1 |
| `cmc` | 50% | ja | -2.6 |
| `analcatdata-authorship` | 70% | nein | -1.9 |
| `optdigits` | 60% | ja | +0.2 |

**Formale Nachanalyse** (neues Skript
[`analysis/decision_stability_level2_analysis.R`](analysis/decision_stability_level2_analysis.R)):
Spearman-Korrelation Stabilitaet vs. Level-2-Delta: **rho = -0.28, p =
0.59** (n=6, NICHT signifikant - wie beim gesamten Research-Aspect-Weg
erwartungsgemaess bei dieser Stichprobengroesse). Wilcoxon-Rangsummen-
test geflaggt vs. nicht geflaggt: W=7, p=0.27 (ebenfalls nicht
signifikant).

**ABER eine konsistente Richtung ueber alle 6 Datensaetze**: die 4
GEFLAGGTEN (instabilen) Datensaetze hatten im Mittel einen POSITIVEN
Level-2-Delta (+0.175 BAcc-Punkte), die 2 NICHT geflaggten (stabilen)
Datensaetze hatten im Mittel einen deutlich NEGATIVEN Delta (-2.8
Punkte). Das ist GENAU die Richtung, die schon beim urspruenglichen
n=2-Befund auffiel (`blood-transfusion` instabil+gut, `ilpd`
stabil+schlecht) - sie kippt beim Rollout auf alle 6 NICHT um, sondern
bestaetigt sich richtungsmaessig (wenn auch statistisch nicht
signifikant).

**Ehrliche Einordnung**: dies ist WEDER ein bewiesener Zusammenhang
(p-Werte klar ueber jeder ueblichen Signifikanzschwelle bei n=6) NOCH
ein zufaellig verschwundenes Muster - die Richtung ist bemerkenswert
konsistent (4/4 geflaggte Datensaetze positiv oder neutral, 2/2 nicht
geflaggte negativ), aber die Stichprobe ist zu klein fuer eine
verlaessliche Aussage. Genau die Art von Befund, die eine groessere
Stichprobe (mehr Datensaetze UND/ODER mehr Outer-Folds pro Datensatz)
rechtfertigen wuerde, falls der Research-/AutoML-Conf-Pfad
weiterverfolgt wird.

**Moegliche Erklaerung (Spekulation, nicht getestet)**: eine instabile
Arm-Wahl bedeutet, dass die 3 Kandidaten (ranger/lightgbm/ensemble)
im Inner-Tune-Score nah beieinander liegen - das Mini-Ensemble
"gewinnt" dann oefter oder zumindest ist der gewaehlte Kandidat selten
weit vom besten entfernt, was den Outer-Test-Schaden einer "falschen"
Wahl begrenzt. Bei einer stabilen Wahl (ein klarer Inner-Gewinner)
haengt das Endergebnis dagegen staerker davon ab, ob dieser klare
Gewinner auch auf Outer-Test wirklich der beste ist - und wenn nicht,
faellt der Schaden groesser aus. Diese Erklaerung ist NICHT
verifiziert, nur als plausible Hypothese fuer eine kuenftige,
groessere Untersuchung festgehalten.

Alle 6 Ergebnisse + der aggregierte Korrelationstest in die Evidence
Registry geloggt. `decision_stability.R`/`decision_stability_level2_
prototype.R` bereits in allen 6 `ML_Learning`-Projektordnern
synchronisiert.

**Kein Backport weiterhin** (ADR-003) - die konkrete Anwendung auf
Level 2 liefert immer noch keine actionable Handlungsempfehlung
("wenn instabil, dann X"), auch mit 6 statt 2 Datensaetzen nicht. Das
generische `decision_stability.R`-Modul selbst bleibt im Template
(bereits getestet/nuetzlich unabhaengig von dieser einen Anwendung).

### P2 - "Weg A": Decision Stability auf alle 3 Outer-Folds statt nur Fold 1 erweitert (2026-08-30)

**Nutzeranfrage**: nach der Klaerung "n=Anzahl Projekte" fragte der
Nutzer, ob neue ungesehene Projekte (OpenML) noetig sind. Vorschlag:
"Weg A" (mehr Outer-Folds der bereits eingefrorenen 6 Datensaetze,
keine neuen Datensaetze noetig) vs. "Weg B" (echte neue externe
Datensaetze, teurer, eigene Auswahlmethodik). Nutzerentscheidung:
"erst Weg A".

`decision_stability_level2_prototype.R` um `DECISION_STABILITY_OUTER_
FOLD` (Env-Var, Default 1) ergaenzt - Fold 2 und 3 aller 6 Datensaetze
zusaetzlich gelaufen (18 Einzelmessungen statt 6).

**Volles Ergebnis (Stabilitaet je Datensatz x Fold)**:

| Datensatz | Fold 1 | Fold 2 | Fold 3 | Mittel | Level-2-Delta |
|---|---|---|---|---|---|
| `ilpd` | 70% | 70% | 50% | 63% | -3.7 |
| `blood-transfusion` | 60% | 50% | 60% | 57% | +3.0 |
| `sick` | 60% | 100% | 80% | 80% | +0.1 |
| `cmc` | 50% | 40% | 50% | 47% | -2.6 |
| `analcatdata-authorship` | 70% | 80% | 70% | 73% | -1.9 |
| `optdigits` | 60% | 60% | 60% | 60% | +0.2 |

**Zentraler, ehrlicher Befund - die Erweiterung WIDERLEGT den
vorherigen suggestiven Zwischenbefund**: die Spearman-Korrelation
zwischen Stabilitaet und Level-2-Delta betrug bei NUR Fold 1 (n=6)
rho=-0.28 (p=0.59, nicht signifikant, aber konsistente Richtung ueber
alle 6). Gemittelt ueber ALLE 3 Folds (robusterer Wert): **rho=-0.086,
p=0.92 - die Korrelation ist praktisch verschwunden.** Der urspruengliche
Befund war ein Artefakt der kleinen Stichprobe (nur 1 Fold pro
Datensatz) - genau der Grund, weshalb "mehr Daten sammeln, bevor man
einer schwachen Korrelation vertraut" die richtige Reaktion war, statt
den Fold-1-Befund als bestaetigt zu behandeln.

**Weitere deskriptive Befunde**:
- Instabilitaet (< 70% Mehrheit) ist mit 11 von 18 Messungen (61%) eher
  die NORM als die Ausnahme bei diesem Tuning-Budget (10 Evals/Arm) -
  die Level-2-Arm-Wahl ist insgesamt haeufiger knapp als klar.
- Innerhalb-Datensatz-Konsistenz ist meist hoch (Spannweite ueber die 3
  Folds bei 5 von 6 Datensaetzen nur 0.0-0.2), Ausnahme `sick`
  (Spannweite 0.4 - schwankt zwischen 60% und 100%).

**Aktualisiertes Skript** [`analysis/decision_stability_level2_analysis.R`](analysis/decision_stability_level2_analysis.R)
(erweitert um die 3-Fold-Auswertung, beide Versionen - Fold-1-only zum
Vergleich UND das robustere 3-Fold-Mittel - bewusst nebeneinander
gezeigt statt den Fold-1-Befund stillschweigend zu ersetzen). Alle 18
Einzelergebnisse + der neue Korrelationsvergleich in die Evidence
Registry geloggt.

**Einordnung**: das Decision-Stability-Prototyp-Kapitel schliesst hier
mit einem doppelt ehrlichen Ergebnis ab - (1) Decision Stability selbst
korreliert nicht verlaesslich mit der Ergebnisqualitaet (bestaetigt
jetzt robuster als zuvor), UND (2) ein Nachtrag zu einer eigenen
vorherigen Session-Aussage: der n=6/Fold-1-Befund war zu vorlaeufig, um
ihn ungeprueft stehen zu lassen. Weiterhin **kein Backport** (ADR-003).
Weg B (neue externe Datensaetze) bleibt eine separate, groessere
Option, falls der Research-Pfad weiterverfolgt wird.

### P2 - 2. JOSS-inspirierter Prototyp: Hard-Split-Stresstest (astartes-inspiriert, 2026-08-31)

**Nutzeranfrage**: "ein neuer Tag - astartes als zweiten Prototyp
angehen". Gleiche Pipeline aus `docs/research/JOSS_TECHNIQUE_WATCH.md`: Problem ->
Hypothese -> Komplexitaetskosten -> kleiner Prototyp -> synthetischer
Test -> 1-2 reale Projekte.

**Idee (aus astartes, Burns et al. 2023, JOSS 10.21105/joss.05996)**:
zufaellige Splits pruefen vor allem Interpolation. Ein strukturell
schwieriger, DISTANZBASIERTER Split (Train/Test durch Feature-Raum-
Clusterung statt Zufall getrennt) prueft dagegen Extrapolation - ob ein
Modell auch auf eine strukturell andere Region des Feature-Raums
generalisiert, die es nie gesehen hat.

**Neues Modul** [`hard_split_stress_test.R`](hard_split_stress_test.R):
`cluster_based_hard_split()` (k-means auf numerischen Features,
kleinstes Cluster = Test-Set) + `hard_split_stress_test()` (Score auf
dem harten Split vs. Referenzbereich aus 10 zufaelligen Splits gleicher
Testgroesse, z-Score-Einordnung). Bewusst NICHT die astartes-/Kennard-
Stone-Implementierung uebernommen (Python, Cheminformatik-fokussiert),
sondern dieselbe Grundidee nativ in R mit `kmeans()`. Folgt demselben
Referenzbereich-/z-Score-Muster wie `generalization_gap.R` (|z|>2 =>
auffaellig, aus Konsistenzgruenden derselbe Schwellenwert).

**Synthetischer Test zuerst**:
[`tests/testthat/test-hard_split_stress_test.R`](tests/testthat/test-hard_split_stress_test.R),
konstruierter 2-Cluster-Fall mit einer clusterunabhaengigen
Zielvariable (x3) - im "Flip"-Fall gilt in Cluster B die UMGEKEHRTE
Regel (garantiertes Extrapolationsversagen erwartet+bestaetigt), im
Kontrollfall dieselbe Regel in beiden Clustern (keine Flag erwartet+
bestaetigt). Ein erster Testentwurf hatte einen Denkfehler
(cluster-RELATIVE statt absolute Regel taeuschte auch im Kontrollfall
ein Versagen vor) - beim ersten Testlauf sofort aufgefallen und
korrigiert, bevor irgendein echter Lauf gemacht wurde. Gesamtsuite
352/352 gruen (+12 neue).

**Angewendet auf 2 reale Projekte** (ungetunter, klassengewichteter
Ranger - kein Tuning, reiner Diagnose-Check, daher deutlich guenstiger
als der Decision-Stability-Prototyp):

- **`ilpd`**: Score auf hartem Split 0.5903 vs. Referenzbereich-Mittel
  0.5859 (SD=0.0247) - z=0.18, **unauffaellig**.
- **`optdigits`**: Score auf hartem Split **0.6918** vs.
  Referenzbereich-Mittel **0.9811** (SD=0.0018) - **z=-157.67, MASSIV
  AUFFAELLIG**. Ein Standard-CV-Score (BAcc≈0.98) haette dieses
  Extrapolationsrisiko komplett verdeckt - der harte Cluster-Split
  deckt einen fast 30-Punkte-BAcc-Einbruch auf.

**Einordnung**: anders als beim Decision-Stability-Prototyp (der auf
beiden Datensaetzen ein mehrdeutiges, letztlich nicht belastbares
Signal lieferte) zeigt dieser Check ein GENAU DAS Verhalten, das man
von einem funktionierenden Trust-/Diagnose-Modul erwartet: still bei
`ilpd` (kein echtes Problem), aber ein klares, grosses, gut
interpretierbares Signal bei `optdigits` (ein echtes, durch Standard-
CV verdecktes Risiko). Das ist strukturell aehnlich zu Ablation A2/A3
(Leak-Audit/Drift-Checks: die meisten Datensaetze unauffaellig, aber
mindestens ein klarer echter Fund) - ein Trust-Modul MUSS nicht auf
jedem Datensatz feuern, um wertvoll zu sein.

**Bewusst noch NICHT weiter diagnostiziert**: warum genau `optdigits`
so stark abfaellt (z.B. welche Ziffernklassen/Schreibstile das
Test-Cluster dominieren) - das waere ein natuerlicher, aber separater
Folgeschritt (offen gelassen statt spekulativ zu erklaeren).

**Backport-Frage (ADR-003)**: 2 unabhaengige Projekte getestet, das
Modul verhaelt sich in beiden Faellen nachvollziehbar/korrekt (nicht
"immer positiv", sondern situationsabhaengig richtig). Das erfuellt die
Bestaetigungs-Schwelle im Sinne eines Trust-Moduls (Mechanismus
validiert), ABER: bewusst noch NICHT als nummeriertes Pipeline-Skript
(`0XX_...R`) backported - dafuer waere ein breiterer Rollout (mehr
Datensaetze) und eine bewusste Entscheidung ueber die Platzierung in
der Skript-Reihenfolge sinnvoll, beides noch nicht angefragt. Bleibt
als eigenstaendiges, getestetes Modul im Template verfuegbar.

Beide Ergebnisse in die Evidence Registry geloggt (Rolle `trust_gate` -
dies ist ein Trust-/Diagnose-Check, kein Score-Hebel).

### P2 - Hard-Split-Stresstest: Rollout auf alle 6 CC18-Datensaetze (2026-08-31)

**Nutzerfrage**: "sollten wir vielleicht astartes bei noch weiteren
Datensaetzen versuchen bevor wir backporten?" - bejaht (Empfehlung: da
kein Tuning noetig ist, deutlich guenstiger als der Decision-Stability-
Rollout). Modul + Prototyp-Skript auf die restlichen 4 Datensaetze
(`sick`, `cmc`, `analcatdata-authorship`, `blood-transfusion`) kopiert
und ausgefuehrt.

**Ergebnisse (alle 6 Datensaetze)**:

| Datensatz | Score hart | Referenz-Mittel (SD) | z | Auffaellig? |
|---|---|---|---|---|
| `ilpd` | 0.5903 | 0.5859 (0.0247) | 0.18 | nein |
| `optdigits` | 0.6918 | 0.9811 (0.0018) | -157.67 | **ja, massiv** |
| `sick` | 0.5000 | 0.9060 (0.0206) | -19.72 | **ja** |
| `cmc` | 0.3845 | 0.5171 (0.0070) | -18.94 | **ja** |
| `analcatdata-authorship` | 0.7158 | 0.9864 (0.0047) | -57.78 | **ja** |
| `blood-transfusion` | 0.7176 | 0.6247 (0.0377) | +2.46 | nein (Split sogar leicht *besser*) |

**Ehrliche Einordnung**: 4/6 Datensaetze zeigen ein deutliches, teils
massives Extrapolationsrisiko (|z| von 19 bis 158), das ein normaler
Zufalls-CV-Score komplett verdeckt haette - das ist HAEUFIGER als
zunaechst mit n=2 vermutet (damals 1/2). `blood-transfusion` ist ein
interessanter Gegenfall: der harte Split faellt hier sogar leicht
BESSER aus als der Referenzbereich (z=+2.46) - ein Hinweis, dass
"auffaellig" bei diesem Check klar zweiseitig ist und der Check nicht
einfach "schlechtere Cluster = schlechterer Score" unterstellt.

**Backport-Frage (ADR-003) - jetzt beantwortet**: mit 6/6 Datensaetzen
und einem konsistent nachvollziehbaren, differenzierten Verhalten
(2x unauffaellig inkl. 1x sogar positiv, 4x klar auffaellig ueber eine
grosse Bandbreite an |z|-Werten) ist die Bestaetigungsschwelle jetzt
deutlich UEBER dem ADR-003-Minimum (≥2 Projekte) erfuellt. Empfehlung:
Backport als Trust-Gate-Diagnose-Skript vorbereiten (Platzierung in der
Skript-Reihenfolge und genaues Ausgabeformat noch mit dem Nutzer
abzustimmen) - noch nicht ausgefuehrt, wartet auf explizite
Nutzeranweisung.

**Bewusst weiterhin offen**: die Ursachendiagnose fuer die einzelnen
Faelle (welche Feature-Kombinationen/Ziffernklassen/Cluster-Strukturen
die jeweiligen Extrapolationsprobleme treiben) - bleibt ein separater
Folgeschritt, kein Teil dieses Rollouts.

Alle 4 neuen Ergebnisse in die Evidence Registry geloggt (Rolle
`trust_gate`, `backport_status = "open"`).

### P2 - Hard-Split-Stresstest: Backport ins Template (2026-08-31)

**Nutzeranweisung**: "mach weiter mit dem Backport" (nach dem 6/6-Rollout
oben). Neues nummeriertes Pipeline-Skript
[`137_hard_split_stress_test.R`](137_hard_split_stress_test.R) - direkt
nach `136_generalization_gap.R` platziert (beide teilen dasselbe
Referenzbereich-/z-Score-Muster, unterscheiden sich aber im gemessenen
Rauschkanal: 136 = Interpolations-Optimismus bei zufaelligem Split, 137 =
Extrapolationsrisiko bei strukturell schwierigem Cluster-Split). Bewusst
mit dem UNGETUNTEN `base_learner_constructors$ranger` statt getunter
090/100-Kandidaten (reiner Diagnose-Check, braucht keine Tuning-Instanzen -
deutlich guenstiger als 136).

Neue Config-Sektion in `000_config.R`
(`hard_split_stress_test_k`/`_n_repeats`/`_flag_threshold_z`/
`_results_path`, k=2/n_repeats=10/z<-2 als Defaults, unveraendert
gegenueber dem Prototyp). Eintrag in `analysis/check_project_script_coverage.R`
ergaenzt (`"Hard-Split-Stresstest (137)"`).

**Regressionstest gegen das Template-eigene Projekt** (`health_condition`,
69008 Zeilen, groesster bisher getesteter Datensatz): **ebenfalls
auffaellig, z=-29.33** (Score hart 0.7913 vs. Referenzbereich-Mittel
0.8602, SD=0.0024) - ein 7. Bestaetigungsfall, konsistent mit dem
6/6-CC18-Befund (Extrapolationsrisiko ist eher die Norm als die Ausnahme
bei diesem Check). Volle Testsuite danach 352/352 gruen (keine neuen
Tests noetig - das bestehende `test-hard_split_stress_test.R` deckt das
Modul bereits synthetisch ab, der Backport selbst ist reine
Verkabelung/Config).

**ADR-003-Status**: Backport jetzt VOLLZOGEN (7 unabhaengige
Bestaetigungen: 6 CC18-Datensaetze + das Template-eigene Projekt, 5/7
auffaellig). `hard_split_stress_test.R` bleibt zusaetzlich als
eigenstaendiges Modul verfuegbar (fuer Adhoc-Diagnosen ausserhalb der
nummerierten Pipeline-Reihenfolge).

**Weiterhin bewusst offen**: die Ursachendiagnose fuer die einzelnen
auffaelligen Faelle (welche Feature-Kombinationen/Cluster-Strukturen die
jeweiligen Extrapolationsprobleme treiben) - bleibt ein separater
Folgeschritt.

**CI-Smoke-Test-Fixture ergaenzt** (separater Commit `9bd9562`, direkt im
Anschluss): `hard_split_stress_test.R`/`137_hard_split_stress_test.R` in
die "Kernskripte in die Fixture kopieren"-Liste sowie einen neuen
`137 Hard-Split-Stresstest`-Schritt in `.github/workflows/ci-smoke-test.yml`
aufgenommen (Kernskripte jetzt 015-137), plus reduzierte
`hard_split_stress_test_n_repeats=3` in `ci_smoke_test/000_config.R` (nur
der Code-Pfad zaehlt, analog zu `seed_stability_n_seeds`/`_n_jitter`).
Ohne diesen Schritt waere die neue Datei vom Smoke-Test unbemerkt geblieben
(derselbe Fehlermodus wie beim Merge-Skript-Vorfall dieser Session -
Konventionen, ROUTINE-MAESSIG pruefen statt anzunehmen). Beide CI-Laeufe
gruen: `928cf5f` (Backport selbst, CI-Lauf `33361859447`) und `9bd9562`
(Fixture-Ergaenzung inkl. des neuen 137-Schritts, CI-Lauf `33362023282`).

### P2 - Hard-Split-Stresstest: optdigits-Ursachendiagnose (2026-08-31)

**Nutzeranweisung**: "mach weiter mit der optdigits-Ursachendiagnose".
Denselben k-means-Split (k=2, seed) wie im Prototyp reproduziert
(`hard_split_diagnosis.R`, ML_Learning-Projekt, nicht ins Template
zurueckgefuehrt - reines Ad-hoc-Diagnoseskript) und die Klassenverteilung
je Cluster untersucht.

**Zentraler Befund - der k-means-Split ist bei `optdigits` fast ein
verdeckter Class-Holdout, kein reiner Feature-Raum-Split**: Test-Cluster
(n=1702) besteht zu **95.3%** aus den Ziffern {0, 4, 6} (32.4%+30.2%+
32.7%), waehrend das Train-Cluster diese drei Ziffern fast vollstaendig
ausschliesst (0.1%/1.4%/0.1% statt der erwarteten ~10% je Ziffer). Die
Konfusionsmatrix bestaetigt das direkt: das auf dem Train-Cluster
trainierte Modell erreicht 0% Trefferquote auf Ziffer 0 und 6, 13% auf
Ziffer 4 - fuer alle anderen (im Training normal vertretenen) Ziffern
84.6%-100%. Der dramatische Gesamt-Score-Einbruch ist also ueberwiegend
durch fehlende Trainingsbeispiele fuer 3 von 10 Klassen erklaerbar, nicht
(nur) durch einen "dieselbe Klasse, aber strukturell andere Region"-
Extrapolationsfehler im urspruenglich intendierten astartes-Sinn.

**Vergleich mit den anderen 3 auffaelligen Datensaetzen** (gleicher
Diagnose-Check, Klassenverteilung TRAIN- vs. TEST-Cluster):
- `analcatdata-authorship` (4 Klassen, z=-57.78): **derselbe Effekt**,
  fast so extrem - Test-Cluster 79.7% "London" (Referenz: 35.2%),
  Train-Cluster schliesst "London" fast aus (2.9%). Auch hier
  ueberwiegend ein verdeckter Class-Holdout.
- `sick` (2 Klassen, z=-19.72): Klassenverteilung bleibt nah an der
  Referenz (7.4%->1.9% "sick"-Anteil, moderat) - **KEIN Class-Holdout-
  Artefakt**, hier misst der Check tatsaechlich ein feature-raum-
  basiertes Extrapolationsrisiko unabhaengig von der Zielklasse.
- `cmc` (3 Klassen, z=-18.94): moderate Verschiebung (16.8%->29.9% fuer
  Klasse 2), deutlich schwaecher als bei optdigits/analcatdata-
  authorship - vermutlich eine Mischung aus beidem.
- Beide UNAUFFAELLIGEN Faelle (`ilpd`, `blood-transfusion`) sind binaer
  mit nur moderater Klassenverschiebung.

**Einordnung/Korrektur**: der Mechanismus des Checks funktioniert wie
gebaut (k-means auf Feature-Raum, kleinstes Cluster = Test), ABER bei
Multi-Klassen-Aufgaben mit im Feature-Raum gut trennbaren Klassen (viele
Klassen, hohe Dimensionalitaet wie bei Pixel-/Autorschafts-Features)
kann `cluster_based_hard_split()` UNBEABSICHTIGT in einen
Class-Holdout-Split entarten - ein bereits gut verstandenes, anderes
Risiko (seltene-Klassen-Handling) als das eigentlich intendierte
"gleiche Klasse, andere Feature-Region"-Extrapolationsrisiko. Der
z-Score bleibt technisch korrekt (der Score-Einbruch ist real), aber die
INTERPRETATION "Extrapolationsrisiko" ist bei stark klassen-verschobenen
Splits irrefuehrend/unvollstaendig - `sick` bleibt das sauberste Beispiel
fuer den urspruenglich intendierten Mechanismus.

**Konsequenz fuer das Modul**: dieser Befund ist ein echter, bisher nicht
dokumentierter Interpretationsvorbehalt fuer das bereits zurueckgefuehrte
`137_hard_split_stress_test.R` - noch NICHT als Code-Aenderung umgesetzt
(z.B. ein automatischer Klassenverschiebungs-Diagnosewert im Report), nur
als Befund dokumentiert. Entscheidung ueber eine Modul-Erweiterung offen.

**Nutzerentscheidung (AskUserQuestion)**: "Ja, Klassenverschiebungs-
Diagnose ergaenzen" - Modul erweitert statt nur dokumentiert.

**Erweiterung umgesetzt**: neue Funktion `class_proportion_shift()`
(`hard_split_stress_test.R`) misst die maximale Klassenanteils-
Verschiebung (Prozentpunkte) zwischen Test-Cluster und Referenzverteilung
(`NA` fuer `TaskRegr`). `hard_split_stress_test()` gibt jetzt zusaetzlich
`class_shift_max_pp`/`class_holdout_suspected` zurueck und meldet einen
separaten "CLASS-HOLDOUT-VERDACHT"-Hinweis im Report, unabhaengig vom
z-Score-Flag. Neuer Schwellenwert `hard_split_stress_test_class_shift_
warn_pp` (Default 20, in `000_config.R`/`ci_smoke_test/000_config.R`
ergaenzt, `137_hard_split_stress_test.R` gibt ihn durch) - grob an den 4
bereits diagnostizierten Faellen kalibriert (`sick`/`cmc`: 5.5/13.1pp,
darunter; `optdigits`/`analcatdata-authorship`: 32.6/76.8pp, darueber),
NICHT synthetisch hergeleitet wie der z-Score-Schwellenwert -2 (bewusst
als schwaechere Kalibrierung im Kopfkommentar gekennzeichnet).

4 neue synthetische Tests (`class_proportion_shift()` bei klassen-
korrelierter Clusterung, `NA` bei `TaskRegr`, sowie die Integration in
`hard_split_stress_test()` bei klassen-UNabhaengiger Clusterung - dort
korrekt KEIN Class-Holdout-Verdacht). Gesamtsuite danach 356/356 gruen.

**Regressionstest health_condition (erneut)**: Klassenverschiebung nur
4.9 Prozentpunkte (weit unter dem 20pp-Schwellenwert) - bestaetigt, dass
der z=-29.33-Alarm dort ein ECHTES Extrapolationsrisiko misst, kein
Class-Holdout-Artefakt. Eine schoene Validierung der neuen Diagnose an
einem bereits bekannten Fall.

### P3 - Externe Adoption vorbereiten (2026-08-31)

**Nutzeranweisung**: "mach weiter mit P3" (viertes Bewertungsdokument,
2026-08-30, Abschnitt "P3 - externe Adoption", 5 Checklistenpunkte).

**1. "Start here"-Anleitung geprueft**: existierte NICHT im `README.md` -
das README war reine "warum ist das gut"-Darstellung ohne praktische
Einstiegsanleitung. Eine ausfuehrliche Checkliste
("Uebertragung auf einen neuen Kaggle-Wettbewerb") existierte bereits in
`TARGETS.md`/`WorkflowDescription.md`, war aber vom README aus nicht als
Einstiegspunkt auffindbar/verlinkt. Neuer Abschnitt "Los geht's (Start
Here)" im README ergaenzt: Umgebung einrichten (Verweis
`ENVIRONMENT.md`), Testsuite laufen lassen, ein einzelnes Skript
ausprobieren, kompletten Workflow nachvollziehen, dann auf ein eigenes
Projekt uebertragen (Verweis `TARGETS.md`/`WorkflowDescription.md`).
Beide als Beispiel genannten Skripte (`015_target_leak_audit.R`,
`030_baseline.R`) verifiziert: beide lesen `train.csv` direkt bzw.
bootstrappen `020_task.R` automatisch, sind also tatsaechlich
eigenstaendig lauffaehig wie behauptet.

**2. Extern nachvollziehbares Beispielprojekt**: bereits vorhanden, aber
nicht explizit als solches kommuniziert - dieses Repo selbst enthaelt ein
vollstaendig durchgespieltes, echtes Kaggle-Projekt
(`health_condition`/Playground Series S6E7, `train.csv`/`test.csv`/
`sample_submission.csv` + befuelltes `000_config.R`). Im neuen
README-Abschnitt jetzt explizit als solches benannt statt implizit
vorausgesetzt.

**3. Erste Version/Release**: Nutzerentscheidung (AskUserQuestion) - "Ja,
v0.1.0 Release veroeffentlichen" (bewusst vorher gefragt, da ein
GitHub-Release eine sichtbare, oeffentliche Aktion ist, anders als die
sonst automatisch gesetzten Backlog-Tags). Tag `v0.1.0` + [GitHub
Release](https://github.com/kubischraumzentriert/AutoML/releases/tag/v0.1.0)
veroeffentlicht, Release-Notes fassen Faehigkeiten/bestaetigte Ergebnisse
zusammen und verweisen auf den neuen Start-here-Abschnitt. Bewusst KEIN
R-Paket-Release (ADR-007 bleibt massgeblich) - reine Snapshot-Markierung
fuer externe Adoptierende.

**4./5. Externe Nutzerfeedbacks/Issues als Evidenz**: strukturell bereits
vorbereitet (`CONTRIBUTING.md` beschreibt den Issue-Prozess, ADR-003
gilt fuer externe PRs genauso wie fuer eigene Aenderungen), aber
inhaltlich NICHT umsetzbar ohne tatsaechliche externe Nutzung - es gibt
bislang keine externen Nutzer/Issues. Bewusst nicht simuliert/vorgetaeuscht;
bleibt offen, bis echte externe Ruckmeldungen eintreffen.

Commit `495ede4` (README-Ergaenzung, docs-only, kein CI-Trigger), Tag
`v0.1.0`.

### "Weg B"-Erweiterung: n=6->10 CC18-Datensaetze fuer die Decision-Stability-Forschungsfrage (2026-08-31)

**Nutzeranweisung**: "mach weiter mit der Weg-B-Erweiterung". Vorab per
AskUserQuestion geklaert: +4 neue Datensaetze (n=10 insgesamt statt
n=15), da jeder neue Datensatz denselben teuren Ablauf braucht
(Task-Setup + Level-2-Prototyp mit Tuning ueber 3 Outer-Folds +
Decision-Stability mit 10 Wiederholungen je Fold).

**Auswahl eingefroren VOR jeder Ergebnisberechnung**: siehe
`docs/research/EXTERNAL_BENCHMARK_SET.md`, Abschnitt "Weg B"-Erweiterung, und
[`analysis/select_weg_b_extension.R`](analysis/select_weg_b_extension.R) - repliziert
exakt dieselbe Methodik wie die urspruengliche 6er-Auswahl (deterministisch,
2 binaer + 2 multiclass, NEUER Seed `20260831`, da derselbe Seed auf dem
um 6 Kandidaten reduzierten Pool kein echtes Fortsetzungsergebnis liefern
wuerde). Gezogen: `PhishingWebsites` (DID 4534, binaer), `qsar-biodeg`
(DID 1494, binaer), `mfeat-karhunen` (DID 16, 10 Klassen), `eucalyptus`
(DID 188, 5 Klassen).

**Echter Fund: bekannter OOM-Crash-Bug in 5 von 6 bestehenden lokalen
Projekt-Kopien nicht gepatcht.** Beim Level-2-Lauf fuer `mfeat-karhunen`
(10 Klassen): `Fehler: cannot allocate vector of size 38.4 Gb`, exakt
derselbe Fehlermodus wie der bereits am 2026-08-29 bei `optdigits`
gefundene und im ZENTRALEN Template (`class_multiplier_tuning.R`,
`max_grid_combos`-Obergrenze bei 200000 Kombinationen) gefixte Bug
(`expand.grid()` ueber alle Klassen minus Referenz waechst mit
`grid_laenge^(Klassenzahl-1)` - bei 10 Klassen `12^9 ≈ 5.2 Mrd.` Zeilen).
Der Fix wurde damals NUR ins Template UND in `optdigits`s eigene lokale
Kopie eingespielt - NICHT in die anderen 5 bereits bestehenden
`openml-cc18-*`-Kopien (`cmc`, `sick`, `analcatdata-authorship`,
`blood-transfusion`, `ilpd`), die seitdem unbemerkt mit der
ungepatchten, absturzgefaehrdeten Version liefen (bei diesen 5 bislang
folgenlos, da alle <=4 Klassen haben und die Kombinatorik dort
handhabbar bleibt - reines Glueck, kein Beweis der Korrektheit). Beim
Kopieren von `openml-cc18-cmc`s Dateien als Vorlage fuer die 4 neuen
Weg-B-Projekte wurde der Bug dadurch unbeabsichtigt reproduziert.

**Fix**: die aktuelle, gepatchte Fassung aus dem zentralen Template in
ALLE 9 betroffenen `ML_Learning`-Projektordner synchronisiert (4 neue
Weg-B-Projekte + die 5 bisher ungepatchten Bestandsprojekte). Lehre:
eine zentrale Bugfix-Korrektur ist NICHT automatisch in bereits
bestehenden lokalen Projekt-Kopien wirksam (keine Symlinks, echte
Kopien) - bei einem sicherheits-/stabilitaetsrelevanten Fix im Template
lohnt sich ein bewusster Abgleich gegen ALLE bestehenden lokalen Kopien,
nicht nur gegen die, wo der Bug urspruenglich auftrat.

**Level-2-Prototyp-Ergebnisse** (Protokoll v3, 3 Outer-Folds, Metrik
BAcc):

| Datensatz | `level2_workflow` (Mittel) | bester Baseline-Arm | Delta (BAcc-Punkte) |
|---|---|---|---|
| `PhishingWebsites` | 0.9680 | `lightgbm_default` 0.9687 | -0.07 |
| `qsar-biodeg` | 0.8517 | `lightgbm_default` 0.8490 | +0.28 |
| `mfeat-karhunen` | 0.9555 | `lightgbm_default` 0.9575 | -0.20 |
| `eucalyptus` | 0.6311 | `lightgbm_default` 0.6277 | +0.35 |

Konsistent mit dem bisherigen Muster (siehe P2-Rollout der urspruenglichen
6): kein durchgehender Vorteil des Level-2-Workflows - 2/4 leicht positiv,
2/4 leicht negativ, alle Deltas klein (<0.4 BAcc-Punkte).

**Decision-Stability (alle 3 Folds, alle 4 neuen Datensaetze)**:

| Datensatz | Fold 1 | Fold 2 | Fold 3 |
|---|---|---|---|
| `PhishingWebsites` | ensemble, 70% | ensemble, 60% (geflaggt) | lightgbm, 60% (geflaggt) |
| `qsar-biodeg` | ranger, 50% (geflaggt) | ensemble, 50% (geflaggt) | ranger, 50% (geflaggt) |
| `mfeat-karhunen` | lightgbm, 50% (geflaggt) | lightgbm, 40% (geflaggt) | ensemble, 40% (geflaggt) |
| `eucalyptus` | ensemble, 50% (geflaggt) | ranger, 60% (geflaggt) | ensemble, 60% (geflaggt) |

**Korrelationsanalyse ueber alle 10 Datensaetze x 3 Folds (30 statt 18
Messungen)**: [`analysis/decision_stability_level2_analysis_weg_b.R`](analysis/decision_stability_level2_analysis_weg_b.R)
- Deskriptiv: 22/30 (73%) der Einzelmessungen liegen unter der
  70%-Stabilitaetsschwelle (Median 0.6, Mittel 0.593) - Instabilitaet
  bleibt bei diesem Tuning-Budget eher die Norm als die Ausnahme,
  konsistent mit dem n=6-Befund (damals 11/18, 61%).
- **Spearman (n=10, mittlere Stabilitaet vs. Level-2-Delta): rho=-0.134,
  p=0.712 - WEITERHIN NICHT signifikant.** Bestaetigt den n=6-Befund
  (rho=-0.086, p=0.919 fuer die urspruenglichen 6 allein) - die
  Erweiterung um 4 unabhaengige neue Datensaetze aendert die Schlussfolgerung
  NICHT. Der urspruengliche, suggestive Fold-1-only-Befund (rho=-0.28,
  n=6) bleibt damit ueber zwei unabhaengige Erweiterungsschritte hinweg
  (Weg A: mehr Folds: rho->-0.086; Weg B: mehr Datensaetze: rho->-0.134)
  widerlegt - ein konsistentes, jetzt gut abgesichertes Negativergebnis:
  Level-2-Arm-Wahl-Instabilitaet erklaert NICHT, ob der Level-2-Workflow
  gegenueber der besten Baseline gewinnt oder verliert.

Alle 4 neuen Level-2- und 12 neuen Decision-Stability-Ergebnisse in die
Evidence Registry geloggt (Rolle `score_lever` fuer Level-2, `trust_gate`
fuer Decision-Stability, analog zu den urspruenglichen 6).

**Fazit Weg B**: die "Weg A"-Schlussfolgerung (kein Zusammenhang zwischen
Entscheidungsstabilitaet und Level-2-Erfolg) ist jetzt an einer
unabhaengigen n=4-Erweiterung erneut bestaetigt - kein Hinweis auf ein
Artefakt der urspruenglichen 6 Datensaetze. Kein Backport (ADR-003
weiterhin nicht erfuellt - die konkrete Level-2-Anwendung des generischen
`decision_stability.R`-Moduls liefert weiterhin keine actionable
Handlungsempfehlung, unabhaengig von der Stichprobengroesse).

### "Weg B", 2. Tranche: n=10->15 CC18-Datensaetze (2026-09-01)

**Nutzeranweisung**: "n=10 auf n=15 erweitern" - die obere Grenze der
urspruenglichen Vormerkung ("n=10-15"). Auswahl eingefroren VOR jeder
Ergebnisberechnung: siehe `docs/research/EXTERNAL_BENCHMARK_SET.md`, Abschnitt "Weg
B, 2. Tranche", und [`analysis/select_n15_extension.R`](analysis/select_n15_extension.R)
- identische Methodik wie zuvor, neuer Seed `20260901`, 3 binaer + 2
multiclass aus einem Pool von 33 zulaessigen Datensaetzen (37 minus die
4 bereits verwendeten Weg-B-Datensaetze). Gezogen: `ozone-level-8hr`
(DID 1487), `dresses-sales` (DID 23381), `jm1` (DID 1053),
`MiceProtein` (DID 40966), `mfeat-morphological` (DID 18).

**Level-2-Prototyp-Ergebnisse** (Protokoll v3, 3 Outer-Folds, Metrik
BAcc):

| Datensatz | `level2_workflow` (Mittel) | bester Baseline-Arm | Delta (BAcc-Punkte) |
|---|---|---|---|
| `ozone-level-8hr` | 0.8348 | `lightgbm_default` 0.6337 | **+20.11** |
| `jm1` | 0.6736 | `lightgbm_default` 0.5832 | **+9.04** |
| `dresses-sales` | 0.5279 | `ranger_default` 0.5813 | -5.34 |
| `MiceProtein` | 0.9956 | `lightgbm_default` 0.9899 | +0.56 |
| `mfeat-morphological` | 0.7170 | `ranger_default` 0.7165 | +0.05 |

**Deutlich groessere Effektstaerken als bei den ersten 10 Datensaetzen**
(bisher max. |3.7| BAcc-Punkte) - plausibel erklaerbar: `ozone-level-8hr`
und `jm1` sind bekannte, STARK unbalancierte binaere Aufgaben (seltene
Minderheitsklasse), wo Klassengewichtung+Tuning gegenueber ungetunten
Baselines besonders viel bringt. `dresses-sales` ist der kleinste
Datensatz im gesamten Set (n=500) - dort zeigt sich das Gegenteil: die
Modellwahl anhand des Inner-Tune-Scores generalisiert schlecht auf den
Outer-Test (Ranger gewinnt in allen 3 Folds intern, verliert aber gegen
seine eigene ungetunte Baseline auf dem Outer-Test) - ein plausibles
Overfitting-auf-den-Inner-Split-Muster bei sehr kleinen Stichproben.

**Decision-Stability (alle 3 Folds, alle 5 neuen Datensaetze)**:

| Datensatz | Fold 1 | Fold 2 | Fold 3 |
|---|---|---|---|
| `ozone-level-8hr` | lightgbm, 70% | lightgbm, 60% (geflaggt) | lightgbm, 90% |
| `jm1` | ensemble, 60% (geflaggt) | ensemble, 50% (geflaggt) | ranger, 50% (geflaggt) |
| `dresses-sales` | ranger, 60% (geflaggt) | ranger, 80% | ranger, 50% (geflaggt) |
| `MiceProtein` | lightgbm, 60% (geflaggt) | lightgbm, 70% | lightgbm, 40% (geflaggt) |
| `mfeat-morphological` | ensemble, 50% (geflaggt) | ranger, 60% (geflaggt) | ranger, 70% |

Bemerkenswerter Einzelfall: `ozone-level-8hr` kombiniert die HOECHSTE
Stabilitaet des gesamten Sets (Mittel 73%, 2/3 Folds unauffaellig) MIT
dem groessten Level-2-Vorteil (+20.1 BAcc-Punkte) - genau in die
Richtung, die man bei einem echten Zusammenhang erwarten wuerde. Ein
einzelner Datenpunkt reicht aber nicht, um die Gesamtkorrelation zu
kippen (siehe unten).

**Korrelationsanalyse ueber alle 15 Datensaetze x 3 Folds (45 statt 30
Messungen)**: [`analysis/decision_stability_level2_analysis_n15.R`](analysis/decision_stability_level2_analysis_n15.R)
- Deskriptiv: 32/45 (71%) der Einzelmessungen liegen unter der
  70%-Stabilitaetsschwelle (Median 0.6, Mittel 0.600) - praktisch
  identisch zum n=10-Befund (73%).
- **Spearman (n=15, mittlere Stabilitaet vs. Level-2-Delta): rho=-0.147,
  p=0.601 - WEITERHIN NICHT signifikant.** Sehr konsistenter Trend ueber
  alle 3 Stichprobengroessen: n=6 rho=-0.086 -> n=10 rho=-0.134 -> n=15
  rho=-0.147 - die Korrelation bleibt durchgehend schwach negativ und
  weit von Signifikanz entfernt, auch nach 2 unabhaengigen Erweiterungen
  um insgesamt 9 zusaetzliche Datensaetze. Ein robusteres, besser
  abgesichertes Negativergebnis ist im Rahmen dieses Templates kaum
  erreichbar.

Alle 5 neuen Level-2- und 15 neuen Decision-Stability-Ergebnisse in die
Evidence Registry geloggt.

**Fazit n=15**: die Frage ist jetzt beantwortet, mit einer fuer dieses
Template ungewoehnlich soliden Stichprobenbasis (3 unabhaengige
Erweiterungsschritte, konsistentes Ergebnis). Kein Backport (ADR-003).
Ein weiterer Ausbau (n=15->20+) wuerde nach dieser dritten Bestaetigung
voraussichtlich keine neue Erkenntnis mehr liefern - aus Kosten-Nutzen-
Sicht hier ein natuerlicher Abschlusspunkt fuer diese Forschungsfrage.

### P3 - uebrige 2 Checklistenpunkte geprueft, nichts umsetzbar (2026-09-01)

**Nutzeranweisung**: "mach weiter mit P3s uebrigen Punkten" (die beiden
noch offenen Checklistenpunkte 4/5: externe Nutzerfeedbacks sammeln,
Bugs/Issues aus externer Nutzung als Evidenz behandeln). GitHub-Repo
tatsaechlich geprueft statt nur angenommen: `gh api repos/.../AutoML` ->
**0 Stars, 0 Forks, 0 Watchers, 0 Issues, 0 PRs** seit dem `v0.1.0`-
Release. Bestaetigt die bisherige Dokumentation - es gibt schlicht keine
externe Nutzung, an die diese Punkte anknuepfen koennten.

Per AskUserQuestion 3 Optionen vorgelegt (abwarten / Sichtbarkeit aktiv
erhoehen z.B. via Repo-Topics / Thema wechseln) - Nutzerentscheidung:
**"Abwarten"**. Keine Aenderung vorgenommen, keine Simulation externer
Aktivitaet. Diese beiden Punkte bleiben strukturell vorbereitet
(`CONTRIBUTING.md`, ADR-003 gilt fuer externe PRs) und werden erst mit
echter externer Nutzung inhaltlich relevant - kein weiterer proaktiver
Handlungsbedarf von unserer Seite, nur reagieren, falls tatsaechlich
Issues/PRs eintreffen.

**Damit ist P3 in dem Sinne abgeschlossen, wie es mit dem aktuellen
Stand des Repos abschliessbar ist** - die 3 umsetzbaren Punkte (Start-
here-Anleitung, Beispielprojekt, Release) sind erledigt, die 2 letzten
haengen an einer externen Bedingung ausserhalb unserer Kontrolle.

### Neuer JOSS-Technique-Watch-Kandidat: negative Stacking-Gewichte (2026-09-01)

**Herkunft**: der Nutzer las das 7th-Place-Write-up der
`playground-series-s6e8`-Competition ("Way Too Many Models, One Simple
Stack") - dort verbesserte das Abziehen von 25%/10% eines schwaecheren
Sub-Blends vom Hauptensemble (negative Gewichte) das OOF-Ergebnis
(0.970820 -> 0.970849). Nutzeranweisung: "das ist ein Kandidat fuer
mich - kannst du mal bei JOSS dann schauen?"

JOSS-Suche ergab einen direkt passenden Beleg: `stacks` (Couch & Kuhn
2022, [10.21105/joss.04471](https://doi.org/10.21105/joss.04471)) - ein
begutachtetes R-Stacking-Paket mit einem `non_negative`-Argument in
`blend_predictions()` (Default `TRUE`, bei `FALSE` werden explizit
negative Gewichte erlaubt) - tatsaechlich anhand der Funktionsdoku
verifiziert, nicht nur aus dem Paper-Abstract angenommen. Der Kaggle-
Befund ist damit keine Einzelanekdote, sondern deckt sich mit einer
bewusst eingebauten Option in einem publizierten Paket.

Als Kandidat #8 in `docs/research/JOSS_TECHNIQUE_WATCH.md` dokumentiert (Prioritaet
mittel, Ursprung explizit als "nicht aus dem urspruenglichen
Bewertungsdokument" gekennzeichnet). Uebertragbarer Teil: NICHT das
Paket selbst, sondern die konkrete Idee eines alternativen linearen
Stacking-Modus mit erlaubten negativen Koeffizienten neben der
bestehenden nicht-negativen Caruana-Greedy-Selection
(`ensemble_selection.R`). Noch kein Prototyp, kein Backport - wartet
auf ein Projekt mit ausreichend grossem/redundantem Kandidatenpool, um
die Hypothese sinnvoll zu testen.

### Vorgeschlagen, zurueckgestellt: Dokumenten-Umstrukturierung (2026-09-01)

**Anlass**: Nutzerfrage, ob die Leak-Audit-Methode dokumentiert ist (ja -
`README_DETAILS.md`, Abschnitt "Target-Leakage-Audit", nicht im Haupt-
`README.md` wie ein `000_config.R`-Kommentar leicht ungenau suggeriert),
gefolgt von der Beobachtung, dass das Repo-Root zunehmend unuebersichtlich
wird.

**Bestandsaufnahme**: 36 Markdown-Dateien im Repo-Root, davon verweisen
65 Dateien (R-Skripte + andere .md) per Dateiname aufeinander - eine
echte Verlinkungs-Verwebung, ein Umzug muesste alle relativen Links
mitziehen.

**Vorgeschlagene Kategorisierung** (noch NICHT umgesetzt, Nutzer hat
explizit zurueckgestellt - "machen wir weiter mit Kaggle"):
- `docs/reference/` (8): alle `REFERENZ_*.md`
- `docs/ablations/` (3): alle `ABLATION_*.md`
- `docs/research/` (9): `docs/research/PAPER_DRAFT.md`, `docs/research/EVALUATION_LEVELS.md`,
  `docs/research/EXTERNAL_BENCHMARK_SET.md`, `docs/research/BENCHMARK_PROTOCOL.md`,
  `SYSTEMATIC_EVALUATION*.md` (2), `docs/research/MODEL_HYPOTHESIS_CRITERIA.md`,
  `PORTFOLIO_WARMSTART_PREREG_*.md` (3), `docs/research/JOSS_TECHNIQUE_WATCH.md`
- Bleibt im Root: `README.md`, `README_DETAILS.md`, `TARGETS.md`,
  `AGENTS.md`, `BACKLOG.md`, `CONTRIBUTING.md`, `LICENSE`,
  `ENVIRONMENT.md`, `WorkflowDescription.md`, `EXPERIMENTS_DB.md`,
  `SHARED_CORE_ANALYSIS.md`, `NEURAL_DEPLOY.md` (Einzelstuecke ohne
  eigene Kategorie).

**Status**: zurueckgestellt fuer eine ruhigere Session ohne laufende
Kaggle-Arbeit nebenbei (Nutzerentscheidung). Bei Aufnahme: Kategorisierung
ggf. nochmal mit dem Nutzer abstimmen (wurde nur vorgeschlagen, nicht
final bestaetigt), dann alle Links per Skript statt manuell nachziehen
(65 betroffene Dateien) und danach die volle Testsuite + CI pruefen,
bevor committet wird.

### Umgesetzt: Dokumenten-Umstrukturierung (2026-09-02)

Nutzer hat die oben vorgeschlagene Kategorisierung unveraendert bestaetigt
("Ja, genau so umsetzen"). Umsetzung:

- `docs/reference/` (11, nicht 8 - Zaehlfehler im urspruenglichen Vorschlag):
  alle `REFERENZ_*.md` per `git mv`.
- `docs/ablations/` (3): alle `ABLATION_*.md` per `git mv`.
- `docs/research/` (11, nicht 9 - `PORTFOLIO_WARMSTART_PREREG_*.md` und
  `SYSTEMATIC_EVALUATION*.md` waren im Vorschlag als je 1 Sammel-Bullet
  gezaehlt, nicht als Einzeldateien): `PAPER_DRAFT.md`,
  `EVALUATION_LEVELS.md`, `EXTERNAL_BENCHMARK_SET.md`,
  `BENCHMARK_PROTOCOL.md`, `SYSTEMATIC_EVALUATION.md`,
  `SYSTEMATIC_EVALUATION_GENERATED.md`, `MODEL_HYPOTHESIS_CRITERIA.md`,
  `PORTFOLIO_WARMSTART_PREREG_CREDIT_G.md`,
  `PORTFOLIO_WARMSTART_PREREG_PIMA.md`,
  `PORTFOLIO_WARMSTART_PREREG_PUMPITUP.md`, `JOSS_TECHNIQUE_WATCH.md`.
- Root wie vorgeschlagen: 11 verbleibende `.md`-Dateien (README.md,
  README_DETAILS.md, TARGETS.md, AGENTS.md, BACKLOG.md, CONTRIBUTING.md,
  ENVIRONMENT.md, WorkflowDescription.md, EXPERIMENTS_DB.md,
  SHARED_CORE_ANALYSIS.md, NEURAL_DEPLOY.md) plus `LICENSE`.
  11 + 25 verschoben = 36 - stimmt mit der urspruenglichen Root-Zaehlung
  ueberein.

**Link-Korrektur per Skript statt manuell**: ein R-Skript hat alle
`.md`/`.R`-Dateien im Root sowie in den 3 neuen `docs/`-Unterordnern nach
Vorkommen der 25 verschobenen Dateinamen durchsucht und die relativen
Pfade automatisch neu berechnet (root->docs/X: `docs/X/datei.md`;
docs/X->docs/Y: `../Y/datei.md`; docs/X->root: `../../datei.md`).
41 Dateien geaendert. Stichprobenkontrolle in `README.md` bestaetigt
korrekt aufgeloeste Links.

**Bewusst nicht angefasst**: Datei-Erwaehnungen in `statusanker/*.md`
(historische Session-Logs, Punkt-in-Zeit-Aufzeichnungen - sollen nicht
rueckwirkend veraendert werden), `_artifacts/*.md` (generierte Snapshots)
sowie vereinzelte reine Namensnennungen in `adr/*.md`, `joss/README.md`
und einem Testkommentar - das sind Prosa-Erwaehnungen des Dateinamens,
keine anklickbaren Markdown-Links, also keine kaputten Referenzen.

**Verifikation**: volle Testsuite nach der Umstrukturierung gruen
(356/356, 0 Fails, 4 unveraenderte Warnungen aus dem Split-Size-Test).
CI gruen (Commit `6ba6af7`, beide Jobs).

### Umgesetzt: R-Skripte aufgeraeumt - `analysis/`-Ordner fuer abgeschlossene Einmal-Skripte (2026-09-02)

**Anlass**: Nutzerbeobachtung "es gibt sehr viele R-Dateien - viele
scheinen nicht Bestandteil des Workflows zu sein" (114 `.R`-Dateien im
Root).

**Bestandsaufnahme per Querverweis-Scan**: fuer jede NICHT-nummerierte
`.R`-Datei geprueft, ob ein anderes `.R`/`.md` sie erwaehnt/sourced.
Drei Kategorien:
- **Kern-Workflow** (nummeriert `000`-`170` + davon `source()`te
  Support-Module wie `db_logging.R`, `evidence_registry.R`,
  `sanity_checks.R`, `class_multiplier_tuning.R`, `db_housekeeping.R`,
  `generate_systematic_evaluation.R`, `config_validation.R` - letztere 3
  haben eigene `testthat`-Tests, die exakte Pfade voraussetzen): bleibt
  laut ADR-007 flach im Root - das Template lebt vom
  "Skript kopieren und direkt anpassen"-Workflow ohne Paketstruktur.
- **ADR-008-eingefrorene Benchmark-Protokolle**
  (`outer_workflow_evaluation.R`/`_template.R`/`_v2_fair_baselines.R`/
  `_v3_level2.R`): bleiben unveraendert im Root, bereits berichtete
  Zahlen haengen an diesen exakten Dateien.
- **Abgeschlossene Einmal-Skripte** (0-5 Querverweise, kein nummeriertes
  Skript sourced sie, Ergebnis meist schon als Kommentar im Skript oder
  in `BACKLOG.md`/`TARGETS.md` dokumentiert): 31 Dateien - Evidence-
  Logger (`log_*_evidence.R`), Portfolio-Warmstart-Validierungen
  (`validate_portfolio_warmstart_*.R`), Literatur-Vergleiche
  (`reproduce_literature_f1_*.R`, `compare_literature_vs_own_results.R`,
  `classify_literature_comparability.R`,
  `review_literature_split_candidates.R`,
  `seed_literature_benchmark_results.R`), P2-Forschungsschritte
  (`p2_level2_*.R`, `decision_stability_level2_analysis*.R`,
  `select_*_extension.R`), sowie vereinzelte abgeschlossene
  Diagnose-/Aufbau-Skripte (`check_native_na_blend.R`,
  `hard_split_stress_test_prototype.R`, `hyperband_budget_test.R`,
  `multilayer_stack_test.R`, `suggest_subset_fraction.R`,
  `build_meta_learning_reference_pool.R`,
  `build_portfolio_warmstart_evidence.R`,
  `recommend_portfolio_warmstart.R`, `merge_duckdb_experiment_marts.R`,
  `migrate_systematic_evaluation_to_evidence.R`,
  `check_project_script_coverage.R`).

**Nutzer bestaetigte explizit "nur Kategorie C verschieben"** (nicht
Kern-Workflow/Protokolle anfassen, kein Vorab-Loeschcheck). Umsetzung:
alle 31 per `git mv` nach `analysis/` (neu, mit erklaerendem
`analysis/README.md`), technisch risikoarm, da alle betroffenen
`source("000_config.R")`/`source("db_logging.R")`-Aufrufe relativ zum
ARBEITSVERZEICHNIS aufgeloest werden (Konvention: immer Repo-Root),
nicht relativ zum Skript-Pfad - die Verschiebung selbst aendert daran
nichts. Querverweise (11 betroffene Dateien: `BACKLOG.md`,
`TARGETS.md`, `EXPERIMENTS_DB.md`, `README_DETAILS.md`,
`WorkflowDescription.md`, 5 `docs/`-Dateien, 1 Skill-Datei) per
R-Skript automatisiert mit `analysis/`-Praefix versehen; 2 veraltete
"Root-Skript"-Bezeichnungen in `TARGETS.md` von Hand auf
"Analyse-Skript" korrigiert.

**Verifikation**: volle Testsuite danach gruen (356/356). Ein
verschobenes Skript (`analysis/check_project_script_coverage.R`) direkt
per `Rscript analysis/check_project_script_coverage.R` probeweise
ausgefuehrt - laeuft unveraendert korrekt (schreibt weiterhin nach
`_artifacts/`, relativ zum Arbeitsverzeichnis).

### Umgebungs-Fund: lokal installiertes `xgboost` war von `renv.lock` abgedriftet (2026-09-01)

Beim `081_xgboost_benchmark.R`-Lauf im neuen `PredictingElectricVehiclePurchases-s6e9`-
Projekt: `Fehler: 'xgb.params' ist kein exportiertes Objekt aus
'namespace:xgboost'`. Ursache: die lokal installierte `xgboost`-R-
Paketversion war `1.7.11.1`, obwohl `renv.lock` bereits korrekt
`xgboost 3.2.1.1` pinnt (mlr3extralearners verlangt `>= 3.2.0.1` fuer
seinen XGBoost-Learner) - `renv.lock` war also NICHT das Problem, die
lokale Installation war einfach unabhaengig davon gedriftet. Grund:
`renv` ist fuer dieses Repo gar nicht aktiv (`.Rprofile` aktiviert es
nicht, setzt nur CRAN-Repo-Optionen fuer `pak`/CI) - ein bewusster,
bereits in `ENVIRONMENT.md` dokumentierter Architekturentscheid
(`DESCRIPTION`+`pak` statt `renv::restore()` als operativer Mechanismus),
der hier aber bedeutet: die lokale interaktive R-Bibliothek wird von
NICHTS automatisch mit `renv.lock` synchron gehalten - ein Update-Skript
kann jederzeit eine aeltere Version installieren/liegen lassen, ohne
dass irgendetwas warnt. Fix: `install.packages("xgboost")` (CRAN,
aktuell 3.2.1.1) - danach lief `081_xgboost_benchmark.R` fehlerfrei.
Betrifft die ganze Maschine, nicht nur dieses Projekt - falls derselbe
Fehler in einem anderen Projekt wieder auftaucht, ist die Ursache
bereits bekannt.

### Zwei weitere echte Bugs im Template, gefunden im s6e9-Projekt (2026-09-01)

**Bug 1 - `025_feature_engineering.R` setzte die positive Klasse nicht.**
`finalize_task()` rief `as_task_classif()` ohne `positive = positive_class`
auf - bei `health_condition` (3-Klassen, `positive_class=NULL`) folgenlos,
bei einer binaeren AUC-Aufgabe (s6e9, `positive_class="Yes"`) waehlte mlr3
stattdessen die erste Faktorstufe ("No") als positive Klasse. Der AUC-Wert
selbst bleibt zufaellig unveraendert (symmetrisch bei Tausch der positiven
Klasse), aber `155_predict_submission.R` haette bei Verwendung eines
`features`/`selected`-Feature-Sets P(No) statt P(Yes) ausgegeben - ein
Submission-invertierender Fehler. `020_task.R` hatte die korrekte Logik
bereits (`if (!is.null(positive_class) && nlevels(...)==2) task_args$positive
<- positive_class`), war aber nie nach `025` uebertragen worden. Fix:
`finalize_task()` uebernimmt jetzt dieselbe Logik.

**Bug 2 - `predict_type="prob"` fehlte systemisch in 6 Skripten.**
`036_feature_family_benchmark.R` lief nach dem Fix von Bug 1 komplett durch
(inkl. teurer Ranger-Laeufe bei voller Datensatzgroesse, ~20+ Min), lieferte
aber fuer ALLE Zeilen `NaN` bei `classif.auc`/`classif.logloss` und brach am
Ende mit `NOT NULL constraint failed: metric_result.mres_value` ab - eine
teure Sackgasse. Ursache: `lrn("classif.lda")`/`lrn("classif.multinom")`/
`lrn("classif.ranger")` OHNE `predict_type="prob"` liefern standardmaessig
nur Klassen-Labels, aber `classif.auc`/`classif.logloss` (die
`baseline_measure_ids` dieses Projekts) brauchen Wahrscheinlichkeiten -
still `NaN` statt eines Fehlers. **Genau dieser Fix stand bereits in
`030_baseline.R`**, mit einem Kommentar, der ihn explizit als
"wiederholt aufgetretenen Reibungspunkt bei der Uebertragung auf
playground-series-s6e5/s5e12" beschreibt - war aber nie in die zentrale,
von mehreren Skripten geteilte `base_learner_constructors`-Liste (in
`000_config.R`, genutzt von 070/092/136/137) UND nie in die 5 weiteren
Skripte mit dupliziertem Learner-Code (`035`/`036`/`037`/`038`/`050`)
propagiert worden. Fix: `predict_type <- "prob"` jetzt in
`base_learner_constructors` (alle 4 Konstruktoren) UND in allen 5
betroffenen Skripten ergaenzt (`037`/`038` mit angepasster Reihenfolge -
Setzen VOR dem `make_baseline_learner()`/`build_classif_pipeline()`-Wrap,
da GraphLearner den `predict_type` vom Basis-Learner zum Wrap-Zeitpunkt
uebernimmt). Volle Testsuite danach 356/356 gruen.

**Lehre aus beiden Bugs**: ein Fix, der lokal in EINEM Skript entsteht
(hier: `020`/`030`), wird nicht automatisch auf strukturell aehnliche
Geschwister-Skripte uebertragen - dieselbe Klasse von Problem wie beim
`class_multiplier_tuning.R`-Drift-Fund vom 2026-09-01 (dort: Kopien
zwischen Projekten drifteten auseinander; hier: Skripte INNERHALB des
Templates selbst drifteten auseinander). Ein systematischer Grep ueber
alle numerierten Skripte auf ein bekanntes Fix-Muster (z.B. `predict_type`)
haette diesen zweiten Fund frueher aufgedeckt - eine Massnahme fuer
kuenftige Bugfixes: nach dem Fixen EINES Skripts kurz pruefen, ob
strukturell aehnliche Geschwister-Skripte denselben Fehler tragen, statt
nur den einen konkreten Fehlerfall zu beheben.

**Eigener Fehler dabei, ebenfalls dokumentiert**: beim Zurueckkopieren der
gefixten `000_config.R` aus dem Template ins s6e9-Projekt wurde die
GESAMTE Datei ueberschrieben statt nur der `base_learner_constructors`-
Aenderung uebertragen - das loeschte kurzzeitig alle s6e9-spezifischen
Anpassungen (target_col, positive_class, subset_fraction=1.0,
feature_families etc.). Sofort bemerkt (Datei-Change-Warnung) und aus der
letzten committeten Version + den in diesem Turn vorgenommenen Aenderungen
wiederhergestellt, kein Datenverlust. Lehre: bei einem Rueck-Sync einer
zentralen, aber projektspezifisch ANGEPASSTEN Config-Datei NIE die ganze
Datei kopieren - nur den konkreten Aenderungsblock gezielt uebertragen.

### s6e9 Feature Engineering: Nullbefund, gestuetzt durch die gesamte Projekthistorie (2026-09-01)

**Anlass**: 3 neue Feature-Familien (charging/affordability/interactions)
fuer s6e9 zeigten in `036_feature_family_benchmark.R` (nach dem
`predict_type`-Fix) DURCHGEHEND keinen Vorteil gegenueber Rohfeatures
(LDA/Multinom/Ranger, alle 3 Familien gleich oder leicht schlechter).
Nutzerfrage: "schau mal in unsere experiments.db inwieweit LightGBM auf
abgeleitete Features reagiert" - Abfrage der zentralen `experiments.db`
ueber ALLE Projekte mit LightGBM UND mehr als einem Feature-Set.

**Zentraler Befund - `health_condition` selbst ist der klarste Fall**: 8
verschiedene Feature-Familien (bmi/sleep/activity/hydration/cardio/
interactions/features/selected) wurden dort gegen Rohfeatures getestet -
**Rohfeatures gewinnen bei ALLEN 8** (BAcc 0.9459 roh vs. 0.9408-0.9443
mit Features). Exakt dasselbe Muster wie gerade bei s6e9.

**Weitere Projekte mit echtem Feature-Engineering-vs-Rohfeatures-
Vergleich fuer LightGBM**:
- `zindi-geoai-aquaculture-pond`: "indices"-Features 0.989 AUC vs. raw
  0.994 AUC - raw besser.
- `playground-series-s5e9-beats-per-minute`: "boundary_interactions" RMSE
  26.638 vs. raw 26.628 - praktisch identisch, minimal schlechter.
- `drivendata-richter-earthquake-damage`: "geo_frequency" 0.710 Acc vs.
  raw 0.702 Acc - **einziger Fall mit echtem Nutzen** (+0.008), aber das
  war Frequency-Encoding einer hochkardinalen Geo-ID-Spalte (ein
  struktureller Fix fuer eine sonst fuer Baeume schlecht nutzbare
  Kategorie-Spalte), kein generisches Ratio-/Interaktions-Feature wie bei
  s6e9.

**Schlussfolgerung**: ueber die gesamte Projekthistorie hinweg helfen
handgefertigte Ratio-/Interaktions-Features LightGBM praktisch nie - der
einzige Fall mit echtem Nutzen war ein struktureller Encoding-Fix
(hochkardinale ID), kein Domaenenwissen-Feature. Deckt sich mit der
bekannten Eigenschaft von Baumverfahren, Interaktionen/Nichtlinearitaeten
bereits selbst ueber Splits zu finden - ein Ratio wie
`income/commute_km` liefert typischerweise nichts, was der Baum nicht
schon aus den beiden Einzelspalten ableiten kann.

**Konsequenz fuer s6e9**: Feature-Engineering-Linie (charging/
affordability/interactions) aufgegeben, `feature_families`/
`selected_families` auf `character(0)` zurueckgesetzt, `model_feature_sets`
bleibt bei "raw". Naechster Fokus: Klassengewichtung/Threshold-Tuning
statt weiterer Feature-Ideen.

### s6e9: Klassengewichtung (Nullbefund bei AUC) + finales Modell

**Klassengewichtung**: `105_lightgbm_class_weights.R` (5 Power-Stufen 0-1,
5-fache CV, volle Groesse) - AUC bewegt sich praktisch nicht (0.9410-0.9413,
im Rauschen), waehrend LogLoss mit staerkerer Gewichtung deutlich schlechter
wird (0.234 -> 0.319 von power=0 zu power=1). Erwartbar: AUC ist gegenueber
Klassengewichtung weitgehend invariant, solange sich die Score-Rangfolge
nicht aendert - und Kaggle bewertet diese Competition ausschliesslich per
AUC. Konsequenz: keine Gewichtung (power=0, `model_class_weight_power`
enthaelt keinen lightgbm-Eintrag). Aus demselben Grund macht auch
Threshold-Tuning (130/146) keinen Sinn - schwellenwertunabhaengige Metrik.

**Datengetriebene Modellwahl**: `148_select_submission_model.R` bestaetigt
LightGBM als Sieger (AUC 0.9427 vs. Multinom 0.9403, Ranger 0.9391, LDA
0.9376, XGBoost 0.9322).

**Echter Nebenfund**: `150_train_full_model.R`/`070_final_models.R`
verwenden PROJEKTUEBERGREIFEND nur die ungetunten Konstruktor-Defaults aus
`base_learner_constructors`, selbst wenn eine Tuning-Instanz existiert -
das finale Modell haette sonst NICHT die in `100_lightgbm_tuning.R`
gefundenen Hyperparameter genutzt. Per Nutzerentscheidung (AskUserQuestion)
in `150_train_full_model.R` (nur diese Projekt-Kopie, nicht zentral
geaendert - eine Verhaltensaenderung fuer ALLE Projekte waere eine groessere
Design-Entscheidung fuer sich) ein Block ergaenzt, der bei `model_name ==
"lightgbm"` die Parameter aus `lightgbm_tuning_instance_path` uebernimmt
(Muster aus `build_tuned_learner_from_instance()` in
`generalization_gap.R` uebernommen). Kandidat fuer eine spaetere zentrale
Verallgemeinerung, falls sich das Muster in weiteren Projekten wiederholt
(ADR-003-Bestaetigungsschwelle: noch n=1).

**Finales Modell trainiert und Submission erzeugt**: LightGBM auf allen
668665 Zeilen mit getunten Hyperparametern (learning_rate≈0.066,
num_leaves=158, min_data_in_leaf=63, feature_fraction≈0.57,
bagging_fraction≈0.74). `submission.csv` verifiziert (286571 Zeilen,
Format `id,Will_Buy_EV`, mean(pred)=0.174, nah an der Trainings-
Basisrate 17% - kein entartetes Ergebnis). Noch NICHT bei Kaggle
eingereicht (externe Aktion, bewusst dem Nutzer ueberlassen).

### `predict_type`-Bugfix vervollstaendigt: vollstaendiger Sweep ueber alle Skripte (2026-09-01)

**Anlass**: Nutzerfrage "koennen wir was ins Template uebernehmen?" -
geprueft, ob der s6e9-lokale `predict_type`-Fix in `023_learning_curve.R`
(dort auf LightGBM umgestellt + `predict_type="prob"` ergaenzt) auch
zentral nachgezogen wurde - war er NICHT. Daraufhin ein systematischer
Grep ueber ALLE `.R`-Dateien im Template auf `lrn("classif....)`-Aufrufe
OHNE jegliche `predict_type`-Erwaehnung in derselben Datei (nicht nur die
6 bereits gefixten von gestern) - genau die im gestrigen Eintrag selbst
empfohlene Massnahme ("nach dem Fixen EINES Skripts kurz pruefen, ob
strukturell aehnliche Geschwister-Skripte denselben Fehler tragen").

**Ergebnis: 9 weitere betroffene Skripte gefunden** (`022_split_size_
sensitivity.R`, `023_learning_curve.R`, `092_seed_stability.R`,
`095_tabpfn_benchmark.R`, `110_lightgbm_feature_family_benchmark.R`,
`120_lightgbm_empty_string_preprocessing.R`, `125_catboost_benchmark.R`,
`135_lightgbm_class_weight_power_extended.R`,
`140_ensemble_candidates_weighted.R`, `142_ranger_tuning_weighted.R`) -
insgesamt also 15 von urspruenglich betroffenen Skripten (6 gestern + 9
heute) plus die zentrale `base_learner_constructors`-Liste. `predict_type
= "prob"` in allen ergaenzt (identisches Muster wie beim `030_baseline.R`-
Vorbild). Ein erneuter Sweep danach: **0 verbleibende Treffer** -
vollstaendig.

Volle Testsuite 356/356 gruen, CI Smoke Test gruen (deckt 022/023/092
direkt ab, da Teil der Kernskripte).

**Lehre bestaetigt**: der erste Fund (6 Skripte gestern) war selbst noch
unvollstaendig - ein Grep-basierter Sweep nach dem ERSTEN Fund haette
sofort alle 15 betroffenen Stellen gefunden, statt sie ueber zwei
Sessions verteilt nacheinander zu entdecken. Fuer kuenftige Bugfixes
dieser Art: sofort nach dem ersten Fund `grep -rl <Fix-Suchmuster>` bzw.
das GEGENTEIL (Dateien OHNE das Muster, aber mit dem urspruenglichen
Fehler-ausloesenden Aufruf) ueber das gesamte Repo laufen lassen, statt
sich auf eine Handvoll "offensichtlich aehnlicher" Skripte zu
beschraenken.

### s6e9: Kaggle-Leaderboard-Score bestaetigt die interne CV-Schaetzung (2026-09-02)

**Ergebnis der ersten Submission**: `0.94142` (Kaggle Public Leaderboard,
AUC). Interne CV-Schaetzung des finalen Modells (getuntes LightGBM, volle
Datensatzgroesse, 5-fache CV): `0.9416`. **Differenz nur 0.0002 - keine
CV-LB-Luecke.** Bestaetigt, dass die gesamte Methodik dieses Durchlaufs
(keine Feature-Engineering-Illusion, keine Ueberanpassung durch
Klassengewichtung, saubere getunte Hyperparameter) ehrlich validiert war,
nicht nur lokal ueberzeugend aussah. Ergebnis in `submission_result`
geloggt (`db_log_submission_result()`, `mconf_id
f0c17d04-28db-404f-b525-28cf5ad2dce5`, Plattform "kaggle", Competition
"playground-series-s6e9").

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
