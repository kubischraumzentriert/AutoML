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
