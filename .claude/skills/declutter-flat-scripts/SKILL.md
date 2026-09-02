---
name: declutter-flat-scripts
description: Raeumt ein zunehmend unuebersichtliches Root-Verzeichnis dieses Templates auf - Dokumente ODER R-Skripte - ohne den kopierbaren Kern-Workflow (ADR-007) oder eingefrorene Benchmark-Protokolle (ADR-008) zu beschaedigen. Nutzen, wenn der Nutzer sagt "das Repo wird unuebersichtlich"/"aufraeumen"/"viele Dateien scheinen nicht Teil des Workflows zu sein" (oder aehnlich).
---

# Flaches Repo aufraeumen (Docs oder Skripte)

Wiederholbares Verfahren, zweimal identisch angewendet (2026-09-02:
36 Root-`.md`-Dateien -> `docs/{reference,ablations,research}/`, danach
114 Root-`.R`-Dateien -> 31 davon nach `analysis/`, siehe BACKLOG.md fuer
beide vollstaendigen Durchlaeufe als Referenz). Gilt fuer Markdown UND
R-Skripte gleichermassen - derselbe Ablauf, andere Dateiendung.

## Wann anwenden

Der Nutzer beobachtet Unuebersichtlichkeit im Repo-Root (viele Dateien,
unklar was noch gebraucht wird) - typischerweise nach mehreren Sessions
mit vielen neuen Ad-hoc-Skripten/Dokumenten. NICHT von selbst anfangen -
das Repo waechst absichtlich schnell (viele einmalige Ablationen/Evidenz-
Sammlungen sind gewollter Teil der Arbeitsweise), eine Aufraeum-Aktion
braucht immer einen expliziten Anlass vom Nutzer.

## Ablauf

### 0. Geschuetzte Zonen zuerst pruefen (`adr/`)

Bevor irgendetwas kategorisiert wird, `adr/007-flat-scripts-not-r-package.md`
und `adr/008-frozen-versioned-benchmark-protocols.md` lesen (koennte um
weitere ADRs ergaenzt worden sein - `adr/`-Ordner vollstaendig auflisten):

- **ADR-007**: der kopierbare Kern-Workflow (nummerierte Skripte
  `000`-`170` + davon direkt `source()`te Support-Module wie
  `db_logging.R`, `evidence_registry.R`, `sanity_checks.R`) bleibt
  IMMER flach im Root - das Template lebt vom "ein Skript kopieren und
  direkt anpassen"-Workflow.
- **ADR-008**: `outer_workflow_evaluation.R`/`_template.R`/
  `_v2_fair_baselines.R`/`_v3_level2.R` (oder kuenftige weitere
  Protokoll-Versionen) bleiben unveraendert UND an ihrem Ort - bereits
  berichtete Zahlen haengen an diesen exakten Dateien.
- Module mit eigenen `testthat`-Tests, die exakte Root-Pfade voraussetzen
  (`test_path("..", "..", "datei.R")`), NICHT verschieben, ohne die
  Tests mitzuziehen - i.d.R. sind das ohnehin Kern-Workflow-Module.

### 1. Querverweis-Scan statt Vermutung

Fuer jede Kandidaten-Datei zaehlen, wie oft ihr Dateiname anderswo im
Repo auftaucht (`grep -rl -F "<dateiname>" --include="*.md" --include="*.R" .`,
den eigenen Treffer abziehen). Niedrige Trefferzahl (0-5) UND kein
nummeriertes Skript sourced sie UND kein `testthat`-Test setzt einen
festen Pfad voraus = echter Aufraeum-Kandidat. Ergebnis IMMER dem Nutzer
als Tabelle/Kategorien vorlegen (siehe Schritt 2) statt direkt zu
loeschen/verschieben - Fehlkategorisierung ist teurer als eine Rueckfrage.

### 2. Kategorisieren und per AskUserQuestion bestaetigen lassen

Typische Kategorien (Namen an den konkreten Fall anpassen):
- Kern-Workflow / eingefrorene Protokolle -> bleibt (Schritt 0).
- Neuer Zielordner A (z.B. `docs/reference/`, `docs/research/`,
  `analysis/`) fuer die restlichen Kandidaten.
- Bewusst NICHT angefasste historische Punkt-in-Zeit-Logs
  (`statusanker/*.md`, `_artifacts/*`) - reine Namensnennungen darin
  sind keine kaputten Referenzen, nicht nachziehen.

**Umfang immer per AskUserQuestion abstimmen** (z.B. "nur verschieben"
vs. "zusaetzlich auf toten Code pruefen und Loeschung vorschlagen") -
nicht von selbst tiefer gehen als angefragt. Ich loesche nie
selbststaendig permanent, nur `git mv`/Vorschlaege.

### 3. Verschieben per `git mv`, dann Querverweise per Skript nachziehen

`git mv <datei> <zielordner>/<datei>` fuer jede bestaetigte Datei.
Danach ein kleines R-Skript (siehe `analysis/README.md` diesem Repos
Historie bzw. BACKLOG.md 2026-09-02 fuer ein Vorlagen-Skript) schreiben,
das fuer jede verschobene Datei ihre Erwaehnungen in allen `.md`/`.R`-
Dateien automatisch findet und den Pfad korrigiert - NICHT manuell 40+
Dateien durchgehen.

- **Bei Markdown-Links** (anklickbare `[text](pfad)`): relativer Pfad
  haengt vom Ordner der VERWEISENDEN Datei ab - root->docs/X:
  `docs/X/datei.md`; docs/X->docs/Y: `../Y/datei.md`; docs/X->root:
  `../../datei.md`.
- **Bei R-Skript-Namen in Prosa/Codebeispielen** (z.B. `Rscript
  datei.R`, `` `datei.R` ``): einfacher, da meist alle in EINEN
  Zielordner wandern - Praefix `zielordner/` voranstellen, ausser die
  Erwaehnung steht bereits in einer Datei, die selbst im Zielordner
  liegt (dann bleibt der Name bewusst bare/unpraefixiert).
- **Wichtige technische Erkenntnis**: `source("datei.R")` in R loest
  relativ zum AKTUELLEN ARBEITSVERZEICHNIS auf, nicht zum Pfad der
  ausfuehrenden Datei. Solange die Konvention "Skripte werden immer mit
  dem Repo-Root als Arbeitsverzeichnis gestartet" gilt (etablierte
  Konvention in diesem Repo), aendert das Verschieben eines Skripts in
  einen Unterordner NICHTS an seinen eigenen bare `source("000_config.R")`/
  `source("db_logging.R")`-Aufrufen - keine Pfad-Anpassung im
  verschobenen Skript selbst noetig. `file.path(project_dir, "x.R")`-
  Aufrufe (project_dir = absoluter Pfad aus `000_config.R`) sind ohnehin
  ortsunabhaengig.

### 4. Verifikation, IMMER vor dem Commit

- Volle `testthat`-Suite lokal gruen (`Rscript tests/testthat.R` oder
  `testthat::test_dir("tests/testthat")`), Soll: bisherige Anzahl PASS,
  0 FAIL.
- Stichprobe: mindestens 1 verschobene Datei direkt aus ihrem neuen Pfad
  ausfuehren (`Rscript <neuer_ordner>/<datei>.R`) und pruefen, dass sie
  weiterhin fehlerfrei laeuft (bestaetigt die CWD-Annahme aus Schritt 3
  empirisch, nicht nur theoretisch).
- Stichprobe: 1-2 umgeschriebene Links in einer zentralen Datei (z.B.
  `README.md`) von Hand nachvollziehen.
- Push, dann CI (`ci-smoke-test.yml`) abwarten (Monitor mit
  Abschluss-Filter, nicht manuell pollen) - beide Jobs (`unit-tests`,
  `smoke-test`) muessen gruen sein, bevor die Aktion als abgeschlossen
  gilt.

### 5. Dokumentation

- `BACKLOG.md`: neuer Abschnitt mit Anlass, Kategorisierung (inkl.
  Datei-Anzahlen je Kategorie), was NICHT angefasst wurde und warum,
  Verifikationsergebnis.
- Kurzer erklaerender `README.md` im neuen Zielordner (Zweck,
  Ausfuehrkonvention) - hilft der naechsten Session, sofort zu verstehen
  wofuer der Ordner da ist, ohne BACKLOG.md durchsuchen zu muessen.
- Statusanker nur auf explizite Nutzeranweisung "Statusanker
  aktualisieren und committen" aktualisieren, nicht automatisch.

## Bekannte Stolpersteine

- Multiline-R-Code per `-e` ueber die Bash-Tool-Bruecke segfault-t auf
  Windows/Git-Bash - Rewrite-Skript immer als `.R`-Datei schreiben
  (Write-Tool), dann `Rscript.exe datei.R` ausfuehren, niemals inline.
- Beim `git add -A` vor dem Commit koennen unabsichtlich unabhaengige,
  bereits vorhandene ungetrackte Dateien mit eingecheckt werden (z.B.
  vergessene Evidence-Logger aus einer frueheren Session) - `git status
  --short` VOR dem Commit durchsehen, nicht blind `git add -A &&
  git commit` hintereinander.
- Ein Zaehlfehler in einer fruehen Kategorisierung (z.B. Sammel-Bullets
  wie "PORTFOLIO_WARMSTART_PREREG_*.md (3)" als 1 statt 3 gezaehlt) faellt
  oft erst beim tatsaechlichen `ls`/`git mv` auf - kein Problem, einfach
  in der BACKLOG.md-Dokumentation richtigstellen, nicht die urspruengliche
  Vorab-Notiz nachtraeglich unbemerkt "korrigieren".
