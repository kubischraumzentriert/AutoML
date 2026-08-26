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
