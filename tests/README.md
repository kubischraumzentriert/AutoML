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
