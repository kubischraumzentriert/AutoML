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
