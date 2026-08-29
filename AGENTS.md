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
- Grosse Dateien (`README_DETAILS.md`, `TARGETS.md`, `EXPERIMENTS_DB.md`) gezielt
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

## Mittelfristiges Ziel: publikationsfaehiger AutoML-Workflow

Dieses Repo soll nicht nur als Kaggle-/OpenML-Arbeitsordner wachsen, sondern
als Kandidat fuer eine spaetere Publikation betrachtet werden. Der derzeit
plausibelste Beitrag ist **kein neuer AutoML-Algorithmus**, sondern ein
reproduzierbarer, diagnoseorientierter Human-in-the-loop-AutoML-Workflow fuer
tabellarische Klassifikation mit `mlr3`, `targets`, Experiment-Logging und
Trust-Gates.

Arbeitshypothese fuer kuenftige Sessions:

- Paper-Narrativ: "A reproducible trust-centered AutoML workflow for tabular
  classification in R/mlr3".
- Staerkster Kern: die Trust-/Diagnose-Schicht aus Target-Leak-Audit,
  Adversarial Validation, univariaten Drift-Tests, Segmentmetriken und
  Modell-Sanity-Checks (Perturbation/Invarianz/Directional Expectation).
- Zweiter Kern: die disziplinierte Template-Evolution nach ADR-003
  (Backport erst nach >=2-Projekt-Bestaetigung oder No-op-Beleg), um
  Template-Overfitting zu vermeiden.
- Wahrscheinlich passender Publikationstyp: Workshop-/Experience-Paper,
  Software-Paper oder angewandtes AutoML-Workflow-Paper - hierfuer liegt
  der Reifegrad bereits vor (breite modulweise systematische Evaluation
  abgeschlossen, siehe Punkt 3 unten, plus Evidence Registry, Provenienz,
  Tests/CI).

**Aktualisierte Paper-Story nach Phase C (2026-08-28, siehe
`BACKLOG.md`/Phase C, `BENCHMARK_PROTOCOL.md`,
`ABLATION_STUDIES_PLAN.md`), sprachlich praezisiert (2026-08-29, siehe
[`EVALUATION_LEVELS.md`](EVALUATION_LEVELS.md))**: die bisherige Outer
Evaluation ist nicht mehr nur ein 1-Datensatz-Prototyp, sondern lief auf
7 bewusst diversen Datensaetzen/Kategorien (binaer ausgeglichen/
unausgeglichen, multiclass, klein/gross, Covariate Shift, Group-/Time-
Struktur) nach einem eingefrorenen Protokoll (`BENCHMARK_PROTOCOL.md`,
Version 1). **Wichtige Praezisierung**: gemessen wurde bislang
ausschliesslich **Level 1 (Component Workflow)** - gewichtetes Training +
ggf. Multiplier-Korrektur - NICHT der vollstaendige AutoML-
Entscheidungsprozess (Modellwahl/Tuning/Ensemble Selection liefen nicht
innerhalb der Outer-CV-Schleife). Die Kernaussage der Story bleibt
dieselbe Erkenntnis, aber mit der korrekten sprachlichen Reichweite:

> Der Level-1-Component-Workflow (gewichtetes Training + ggf.
> Multiplier-Korrektur) generalisiert nicht pauschal - er generalisiert
> MIT einer zur Zielmetrik passenden Korrekturkette (Klassengewichtung +
> Multiplier-/Schwellenwert-Tuning), NICHT mit Klassengewichtung allein.
> Bei allen 4 BAcc-primaeren Aufgaben gewinnt oder haelt dieser Baustein
> mindestens mit den Baselines mit; bei den 2 Accuracy-/F-beta-primaeren
> Aufgaben OHNE begleitenden Korrekturschritt faellt er DEUTLICH ab (bis
> zu -28.7 Punkte F-beta). **Ueber Level 2 (Modellwahl+Tuning innerhalb
> Outer-Train) und Level 3 (kompletter Trust-Prozess innerhalb
> Outer-Train) liegt bislang KEINE Evidenz vor - weder positiv noch
> negativ, schlicht noch nicht getestet.**

Das ist die staerkere, ehrlichere Version der urspruenglichen "der
Workflow generalisiert"-Behauptung - eine Grenzbedingung, die mit nur
einem Datensatz unsichtbar geblieben waere, und genau der Beleg, den ein
Forschungs-Paper braucht (nicht nur "es funktioniert", sondern "es
funktioniert UNTER WELCHEN BEDINGUNGEN, und warum nicht sonst"). Fuer
ein staerkeres Forschungs-Paper fehlen laut der 2026-08-29-Bewertung vor
allem: (1) ein VORAB festgelegtes externes Benchmark-Set (Risiko von
Benchmark Selection Bias bei den bisherigen, bereits bekannten
Projekten), (2) staerkere/budgetgleiche Baselines (Tuned Ranger/
LightGBM, Best Single Tuned Model - bisher nur Default-Baselines), (3)
ggf. eine echte Level-2-Outer-Evaluation.

Naechste Schritte, die bei neuen Arbeiten mitgedacht werden sollen:

1. ~~Systematische Evaluation vorbereiten: 8-15 diverse OpenML/Kaggle/
   DrivenData-Datensaetze mit demselben Workflow durchlaufen lassen.~~
   **ERLEDIGT.** Ueber die Session-Historie hinweg an ~20+ Projekten
   passiert (siehe `ML_Learning/README.md` fuer die vollstaendige Liste).
2. ~~Fuer jeden Datensatz dieselben Artefakte sammeln: Baseline, Tuning,
   ggf. Ensemble, Laufzeit, manuelle Eingriffe, Drift-/Leak-/Segment-/
   Sanity-Befunde.~~ **ERLEDIGT**, in `SYSTEMATIC_EVALUATION.md`
   konsolidiert.
3. ~~Eine Ergebnistabelle pflegen: Welche Workflow-Komponente wurde auf
   welchem Projekt bestaetigt, war neutral, oder wurde verworfen?~~
   **ERLEDIGT.** `SYSTEMATIC_EVALUATION.md` ist fertig (eigener
   Status-Header: "alle Zellen aufgeloest, keine `?` mehr offen") -
   dieser Punkt hier war bis 2026-08-21 faelschlich noch als "aktueller
   Arbeitsschwerpunkt/noch nicht begonnen" markiert, obwohl die Tabelle
   laengst abgeschlossen war. Pflege der Tabelle bei neuen Befunden
   bleibt laufende Aufgabe, aber der Erstaufbau ist fertig.
4. ~~Greedy Ensemble Selection als groessten offenen Backport-Kandidaten
   priorisieren~~ **ERLEDIGT**: `148_ensemble_candidate_pool.R`/
   `149_ensemble_selection.R` (+ `156`/`157` fuer den Full-Train-Export)
   sind seit dem Backport Teil des nummerierten Workflows, verifiziert
   gegen `health_condition` und live an `s6e6`/`s6e8` bestaetigt
   (`s6e8`: als echte Kaggle-Submission deployed). Als eigenstaendige,
   testbare Funktion + erste `testthat`-Unit-Tests weiter gehaertet
   (2026-08-19, `ensemble_selection.R`).
   **Weitere Backports seit diesem Punkt (2026-08-21)**: Leak-Audit
   Schritt 1b (Korrelations-Cluster-Zerlegung, `015_target_leak_audit.R`
   - findet redundante, ueber viele Features verteilte Leak-Gruppen ohne
   Einzelverdacht, mit dokumentierter Grenze am Lending-Club-Extremfall);
   Multi-Label Per-Label-NA-Maskierung (`multilabel.R`/
   `021_multilabel_workflow.R` - erstmals echte fehlende Labels
   unterstuetzt, aus `tox21-multilabel` generalisiert). **Naechster
   offener Backport-Kandidat**: aktuell keiner in `TARGETS.md`
   dokumentiert (die gesuchte 2. Bestaetigung fuer das kumulative
   Leak-PAAR-Muster selbst bleibt offen, aber das ist eine Suche nach
   einem Datensatz, kein Code-Kandidat).
5. Negative Ergebnisse explizit behalten, insbesondere den Meta-Learning-
   Warmstart-Befund: kleine Referenzpools bringen hier bisher praktisch
   keinen messbaren Vorteil. Weitere Beispiele seit 2026-08-21: AER
   Credit Card/Give Me Some Credit (kein Leak-Paar-Muster reproduziert),
   SVM als "immer mitnehmen"-Kandidat bei Chemie-Fingerprints (gemischtes
   Ergebnis, Laufzeit macht es ohne Tuning unpraktikabel).
6. Bei jeder neuen Methode pruefen, ob sie Score-Hebel, Trust-Gate,
   Workflow-Automatisierung oder reine Dokumentation ist. Diese Rolle spaeter
   fuer eine Publikation klar trennen.

Prueffrage beim Einstieg in eine neue Session:

```text
Traegt die geplante Arbeit zum Publikationsziel bei, und falls ja: erzeugt sie
eine auswertbare Evidenzzeile (Datensatz, Methode, Metrik, Laufzeit, Befund,
Backport-Status)?
```

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
- `README.md` - kurzer Ueberblick (Zielgruppe: extern/erster Eindruck).
- `README_DETAILS.md` - vollstaendige Skriptuebersicht und inhaltliche Ergebnisse.
- `TARGETS.md` - `targets`-Pipeline und Uebertragungs-Checkliste.
- `adr/` - Architekturentscheidungen (siehe oben).
