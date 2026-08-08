# Hinweise fuer AI-Coding-Agenten (Codex, Claude Code, etc.)

Diese Datei ist der erste Anlaufpunkt fuer automatisierte Agenten, die in
diesem Repo arbeiten - analog zu `WorkflowDescription.md` fuer Menschen.

## Workflow-Diagramm aktuell halten

`WorkflowDescription.md` enthaelt ein Mermaid-Flowchart mit dem kompletten
Ablauf (`010`-`155`) inkl. aller Entscheidungspunkte. Aendert ein Commit
eine dieser Entscheidungen - ein neues Skript zwischen bestehenden Phasen,
eine neue oder veraenderte Verzweigung (z.B. neue Metrik-Bedingung, neue
Guard-Stufe wie `015`), eine umbenannte/verschobene Phase - MUSS das
Diagramm in `WorkflowDescription.md` im selben Commit nachgezogen werden,
nicht nur der Skript-Code. Eine reine Parameter- oder Bugfix-Aenderung
ohne neue Verzweigung braucht keine Diagramm-Aenderung.

Vor dem Commit pruefen: veraendert der Commit die *Reihenfolge* der
Skripte, eine *Entscheidungsregel* (z.B. Phase 9/10 Schwellenwert-Logik),
oder fuegt er eine neue Guard-/Gate-Stufe hinzu (wie `015` oder das
Neural-Gate aus `NEURAL_DEPLOY.md`)? Falls ja: `WorkflowDescription.md`
aktualisieren, sonst reicht der Code allein.

## Architekturentscheidungen (ADRs)

`adr/` enthaelt kurze, nummerierte Architekturentscheidungen (z.B. warum
Projekt-DBs lokal bleiben statt einer geteilten Live-DB, die R-only/Python-
GPU-Export-Policy, die ≥2-Projekt-Backport-Regel). Vor einer Aenderung, die
eine dieser Entscheidungen beruehrt, erst das passende ADR lesen statt neu
zu diskutieren/zu raten. Das Verzeichnis existiert **dupliziert** im
Schwester-Repo `AutoML_Regression` - bei einer Aenderung an einer Entscheidung
das ADR in BEIDEN Repos pruefen/aktualisieren, siehe `adr/README.md`.

## Git-Arbeitsweise

- Vor groesseren Aenderungen `git status` pruefen. Dieses Repo wird
  gelegentlich von einer parallelen Session/einem parallelen Prozess
  bearbeitet (z.B. laufende Tuning-Skripte, die selbst committen) - keine
  fremden, unbekannten Aenderungen zuruecksetzen oder ueberschreiben.
- Beim Staging gezielt nur die tatsaechlich selbst geaenderten Dateien
  hinzufuegen, kein blindes `git add -A`/`git add .`.
- Standardarbeitsweise: zuerst lokal aendern, die Aenderung kurz
  zusammenfassen (was und warum), dann **committen nur nach ausdruecklicher
  Rueckfrage oder Freigabe** durch den Nutzer.
- **Pushen ist ein separater, erneut zu bestaetigender Schritt** - nie im
  selben Zug wie der Commit, auch nicht nach einer bereits erteilten
  Commit-Freigabe.
- Inhaltlich zusammenhaengende Aenderungen gemeinsam committen, nicht
  kuenstlich aufsplitten.

## Ressourcenschonende Arbeitsweise

- Bei einem klar abgegrenzten Thema gezielt die passende Datei lesen
  (Skript, Phasenabschnitt in `WorkflowDescription.md`, `TARGETS.md`-
  Eintrag), nicht routinemaessig das ganze Repo laden.
- `git status`, `git diff --stat` und gefilterte Ausgaben bevorzugen statt
  vollstaendiger Logs/Diffs.
- Grosse Dateien (`README.md`, `TARGETS.md`, `EXPERIMENTS_DB.md`) gezielt
  ueber Ueberschriften/Suche lesen, nicht routinemaessig vollstaendig.
- Vor mehrminuetigen R-Laeufen (CV-Vergleiche, `tnr("mbo")`-Tuning,
  KernelSHAP, TabPFN) die Laufzeit grob abschaetzen (`estimate_cv_runtime()`
  aus `db_logging.R`, dokumentierte Zeiten im README) und bei gestapelten
  teuren Schritten (z.B. KernelSHAP+TabPFN kombiniert in der `147`-Kette,
  siehe `WorkflowDescription.md` Phase 11) **vor** dem Start explizit sagen,
  wie lange es dauert und ob der Scope reduziert werden soll - nicht erst,
  wenn der Nutzer nachfragt, wieso es so lange dauert.
- Nie mehrzeiligen R-Code direkt per `-e` an ein Terminal uebergeben
  (Segfault-/Fehlinterpretations-Risiko unter Windows/Git-Bash) - immer
  zuerst in eine `.R`-Datei schreiben, dann `Rscript.exe datei.R` ausfuehren.
- Rechenintensive Skripte im Hintergrund starten und Fortschritt per
  Log-Datei pruefen, nicht die Konsole blockieren.

## Aufwandskennzahl fuer Antworten

Ab Beginn einer neuen Session soll der Agent den geschaetzten relativen
Aufwand jeder inhaltlichen Antwort auf einer Skala von 1 bis 10 bewerten.
Kein exaktes Token-, Zeit- oder Kostenmass, sondern ein relativer
Arbeitsindikator.

Referenz:

```text
AGENTS.md + WorkflowDescription.md lesen und den Repo-Kontext arbeitsfaehig
aufnehmen = 3/10
```

Orientierung:

- `1-2/10`: direkte Antwort aus vorhandenem Kontext, keine neue Datei lesen.
- `3/10`: vollstaendiger Session-Einstieg (`AGENTS.md` + `WorkflowDescription.md`).
- `4-5/10`: zusaetzlich gezielt README-/TARGETS.md-Abschnitt oder ein bis
  zwei Skripte lesen, `experiments.db`-Abfrage.
- `6-7/10`: mehrere Skripte/Phasen abgleichen, ein CV-/Benchmark-Lauf im
  Vordergrund (Minutenbereich), Doku mehrerer Phasen anpassen.
- `8-9/10`: neues Skript, neue Feature-Familie oder neuer Guard
  implementiert; laengerer Tuning-/CV-Lauf im Hintergrund gestartet.
- `10/10`: grosser Durchstich ueber mehrere Phasen (z.B. neue Datenquelle
  komplett durch Phase 0-12 gefahren), oder eine sehr lange gestapelte
  Analyse (KernelSHAP+TabPFN kombiniert, teils >1h).

Am Ende jeder inhaltlichen Antwort angeben:

- Aufwand dieser Antwort mit kurzer Begruendung,
- kumulierte Summe und Durchschnitt (seit Sessionbeginn),
- Anfragen,
- eindeutig gelesene Dateien,
- eindeutig geaenderte Dateien,
- bearbeitete Themen.

Eine Datei wird pro Session nur einmal gezaehlt. Kleine Rueckfragen
innerhalb desselben Arbeitsblocks erzeugen kein neues Thema.

Ein Sessionwechsel sollte nach einem belastbaren Commit-/Push-Stand
geprueft werden, wenn viele Themen parallel offen sind, viele Dateien
geladen wurden, oder der kumulierte Aufwand grob im Bereich `40-50`
(aufsummierte 10er-Skala) liegt - ein grober, nicht dogmatischer
Richtwert, keine einzelne Kennzahl loest den Wechsel automatisch aus.

## Pflege dieser Datei

`AGENTS.md` nach groesseren Arbeiten pruefen und aktualisieren, wenn sich
aendert:

- die Ablauflogik/Entscheidungspunkte (siehe oben, Diagramm-Pflicht),
- die Git- oder Ressourcenschonende Arbeitsweise,
- die Aufwandskennzahl-Referenzwerte, falls sich der typische
  Session-Einstieg deutlich aendert,
- eine Architekturentscheidung - dann das zugehoerige ADR aktualisieren,
  nicht nur `AGENTS.md`/den Code.

Pruffrage am Ende groesserer Arbeiten:

```text
Muss AGENTS.md, WorkflowDescription.md oder ein ADR angepasst werden, damit
eine neue Agentensession korrekt und ressourcenschonend einsteigen kann?
```

## Siehe auch

- `WorkflowDescription.md` - der Workflow selbst, inkl. Diagramm.
- `README.md` - Skriptuebersicht und inhaltliche Ergebnisse.
- `TARGETS.md` - `targets`-Pipeline und Uebertragungs-Checkliste.
- `adr/` - Architekturentscheidungen (siehe oben).
