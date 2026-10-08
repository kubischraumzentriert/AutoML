# tests/

**Echte Korrektheitstests** (bekannter Erwartungswert) für einzelne
Funktionen aus `modules/` - der Gegenpart zu `ci_smoke_test/` (das prüft
nur "läuft es fehlerfrei durch", nicht "ist das Ergebnis korrekt"). Beide
laufen als getrennte Jobs in `.github/workflows/ci-smoke-test.yml`
(`unit-tests` bzw. `smoke-test`).

## Warum kein `testthat::test_check()`?

Dieses Repo ist **kein installierbares R-Paket** (siehe `DESCRIPTION`s
Kopfkommentar, ADR-007) - `test_check()` setzt genau das voraus und
funktioniert hier nicht. Stattdessen `test_dir()` (`testthat.R`), und
jede Testdatei sourced ihr Zielmodul direkt über
`testthat::test_path("..", "..", "modules", "<datei>.R")` relativ zu
sich selbst.

## Lokal ausführen

Vom Repo-Root:

```bash
Rscript tests/testthat.R
```

## Struktur

- `testthat.R` - Runner, ruft `test_dir("tests/testthat")` auf.
- `testthat/test-<modul>.R` - je eine Testdatei pro `modules/<modul>.R`
  (siehe `modules/README.md` für die Zuordnung Datei → Zweck). Name
  entspricht 1:1 dem getesteten Modul.
- `testthat/_snaps/` - von `testthat` automatisch verwaltete Snapshot-Tests
  (nicht von Hand editieren, siehe `testthat`-Doku zu `expect_snapshot()`).

Neue Module bekommen beim Anlegen i.d.R. direkt eine eigene Testdatei
(siehe `BACKLOG.md` P0.1 für die historische Aufarbeitung aller
damals ungetesteten Bausteine) - eine fehlende Testdatei für ein
bestehendes Modul ist meist eine echte Lücke, kein bewusstes Auslassen.

## S6E10 P0-Regressionen (2026-10-08)

- `test-target_leak_audit_helpers.R`: Importance-Namensmapping fuer
  LightGBM; No-op, Reihenfolge/Werte, Leerzeichen, Kollisionen,
  unbekannte/fehlende Namen und echte LightGBM-Integration.
- `test-baseline_provenance.R`: fuehrt den echten Abschluss-Aufruf aus
  030 auf einem kleinen Benchmark und temporaerer SQLite-DB aus.
  Prueft den gespeicherten Fold-Hash sowie unveraenderte Scores/Predictions.

Falls R unter Windows beim Start `Setting LC_CTYPE=C.UTF-8 failed` meldet,
koennen Unicode-Symboltests mit Kodierungsdifferenzen scheitern. Fuer diese
Umgebung in R eine verfuegbare UTF-8-Locale setzen, dann den Runner starten:

```r
Sys.setlocale("LC_CTYPE", "English_United States.utf8")
source("tests/testthat.R")
```

Die Rueckgabe von setlocale muss nichtleer sein. Keine globale erzwungene
Windows-Locale im plattformuebergreifenden Test-Runner. Fachliche Tests
oder Erwartungswerte werden fuer dieses Umgebungsproblem nicht veraendert.

## Task- und Lernkurven-Regressionen (2026-10-08)

- `test-classification_task_settings.R`: binaere Overrides, NULL,
  Multiclass-No-op, bestehende Stratum-Rollen, echte 023-CSV/RDS-Ladezweige
  und additive positive_class-Metadaten im 150-Modellbundle.
- `test-learning_curve_preprocessing.R`: echte 023-Pipeline im festen
  Train/Test-Split, Trainingsmedian/-modus trotz extremer Testdaten,
  identische Ranger-Vorhersagen bei vollstaendigen Daten und endliche
  LogLoss-Lernkurven bei binaeren/Multiclass-Tasks mit Fehlwerten.

Die Tests isolieren kleine Fixtures; kein neues Training der lokalen
Kaggle-Submission und kein Schreibzugriff auf deren Experimentdatenbank.

## Submission-Vertrag (2026-10-08)

- `test-submission_contract.R`: richtige Probability-Klasse, IDs/Spalten,
  Sample-Reihenfolge, Wertebereich, fuehrende Nullen, legale konstante
  Wahrscheinlichkeiten, Faktoren, Parameter und CSV-Fehlerpfade.
- `test-submission_export.R`: echter 155-Aufruf in isolierten Rscript-
  Prozessen mit kleinen trainierten rpart-Modellen/SQLite; binaere
  Probabilities und Multiclass-Labels. Fremdprojekt und unvollstaendiger
  Modelllauf werden nicht ausgewaehlt. --validate-only lehnt falsche
  Probability-Spalte/stale Parameter ab und laesst die Datei unveraendert.
  Der echte targets-Submission-Ausdruck erzeugt dieselben Dateibytes.
- `tests/fixtures/submission_config.R`: minimale Konfiguration dieser
  temporaeren Prozesse, kein neuer produktiver Default.

CI-Konsistenztest prueft apply_positive_class in Smoke- und Root-Config.
Nachgeholter isolierter 023-Smoke-Lauf und Runtime-Pruefung eines leeren
optionalen targets-Dateiziels bestanden. Keine komplette Heavy-CI erneut
gestartet; die Gesamtsuite umfasste hier 37 Testdateien.

## Kandidaten und Score-Historie (2026-10-08)

Die Bruecke wird in test-submission_export.R zusaetzlich
mit echten 157-/158-Aufrufen fuer binaere und Multiclass-Ensembles geprueft:
Gewichte/Klassen/Modell-SHA, unveraenderte Einzelmodell-CSV und richtiger
Trainingsworkflow im Score-Manifest. Der echte targets-Graph nutzt die
Produktionsausdruecke fuer final_model_artifacts/submission in einer kleinen
Fixture: erster Export, cachegleicher zweiter Lauf, Artefakt-Wiederaufbau,
DB-Rollback/Datei-Cleanup bei injiziertem Fehler und Score-Pinning.
targets-Test nur bei installiertem optionalem Paket; isolierte R-Prozesse.
Bruecken-Abschluss: alle 38 Testdateien ohne Fehler, Produktionsgraph mit
20 Targets geparst (_artifacts/bridge_full_suite_utf8.log). No-op gegen
vorhandenes health_condition-Ensemble: 256 Zeilen, bit-identische
Probabilitaeten, unveraenderter Modell-SHA (bridge_template_noop.log).

`test-submission_registry.R` prueft CLI-Grenzen und widerspruechliche
EAV-Referenzen. db_logging-Regressionsfall: bekannte Scores nur bei
gleicher Dateiidentitaet erhalten, bei neuen Bytes kein Score-Uebertrag;
Competition-Konflikt darf bestehenden Wert nicht aendern.

Erweiterter echter Rscript-/SQLite-Test in test-submission_export.R:
altes validiertes Modell nach spaeterem Training korrekt gepinnt,
Private-Update ohne Public-/Competition-Flag erhaelt beides, fruehere
Events unveraendert. Identische Bytes aus zwei Modellen sind mehrdeutig,
explizite Modell-ID hilft; falsche Algorithmen, CLI-Typos, manipulierte
CSV/Modelle und Competition-Konflikte hinterlassen keine Ghost-Events.
Die Summary bleibt eine Zeile, die Historie drei unabhaengige Events.

Volle Suite: 38 Testdateien, UTF-8, ohne Fehler. Legacy-S6E10-Kandidat
auf temporaerer DB-Kopie rein lesend aufgeloest, Originalhashes und
Public Score 0.95785 unveraendert. Kein echter Score registriert/Upload.

`test-lightgbm_seed_thread.R` prueft Grid-/Pairing-Vertrag und unvollstaendige
Seed-Paare. Der echte Screeninglauf 093 wurde separat ausgefuehrt und in der
Projekt-DB mit sechs Modellkonfigurationen protokolliert; Ergebnis ohne
Seed-/Thread-Scoreeffekt.
