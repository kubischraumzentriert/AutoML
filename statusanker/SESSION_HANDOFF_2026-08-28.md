# Session Handoff (Stand 2026-08-28) - Statusanker

Vorheriger Anker: `statusanker/SESSION_HANDOFF_2026-08-26.md` (3.
Aktualisierung, deckte den BACKLOG.md-Refactor-Plan-Start bis P1.1-
Prototyp ab). Dieser Anker deckt alles ab, was SEIT dem 26.08.-Handoff
passiert ist: P1.2-P1.3 (Rest von P1), das komplette P2 (P2.1-P2.3), der
spezifizierte Teil von P3, eine neue Git-Tag-Konvention fuer
"Versionierung/Releases", und - als letzter Schritt, auf explizite
Nutzeranfrage - die Migration der Historie aus `SYSTEMATIC_EVALUATION.md`
in die neue Evidence Registry.

## Repo-Zustand am Ende dieser Session

- `MLR3_Classifikation` @ `6f9eeef` "P1.2 step 2: migrate historical
  findings from SYSTEMATIC_EVALUATION.md into the evidence registry" -
  gepusht, CI Smoke Test gruen (Lauf `33167619522`).
- `MLR3_Regression`/`ML_Learning`: in dieser Session nicht angefasst
  (unveraendert seit dem 26.08.-Handoff).
- **8 neue annotierte Git-Tags** gesetzt und gepusht (siehe Abschnitt
  "Git-Tag-Konvention" unten): `backlog-p0`, `backlog-p1.1`,
  `backlog-p1.2`, `backlog-p1.3`, `backlog-p2.1`, `backlog-p2.2`,
  `backlog-p2.3`, `backlog-p3-hypothesis-criteria`,
  `backlog-p1.2-step2` (9 insgesamt).
- Zentrale `experiments.db` wurde NICHT ueber `merge_project_experiments.R`
  aktualisiert (der P2.1-Check zeigte offene Merges - siehe "Offene
  Punkte" unten) - aber die PROJEKTEIGENE `health_condition`-DB waechst:
  2 P1.1/P1.2-Demo-Eintraege + 56 neu migrierte historische Eintraege in
  der `evidence`-Tabelle.

## Was in dieser Session passiert ist (Fortsetzung nach dem 26.08.-Anker)

**1. P1.2 (Evidence Registry) wurde vollstaendig - inkl. Schritt 2 -
umgesetzt**, ueber zwei getrennte Nutzeranfragen hinweg:

- **Schritt 1** (bereits im 26.08.-Anker dokumentiert, hier nur als
  Kontext): `evidence`-Tabelle + `evidence_registry.R` -
  `db_log_evidence()`/`evidence_registry_summary()`.
- **Schritt 2, HEUTE auf explizite Anfrage** ("wir sollten die Historie
  nachtragen d.h. migrieren"): neues `migrate_systematic_evaluation_to_
  evidence.R` (einmaliges Migrationsskript) liest die grosse Projekt x
  Modul-Tabelle aus `SYSTEMATIC_EVALUATION.md` und loggt jede Zelle mit
  echtem Legenden-Symbol (✓/✓✓/~/✗) als eigene `evidence`-Zeile.
  **Bewusste Scope-Entscheidungen** (nicht extra nachgefragt, weil
  eindeutig aus dem Plan-Wortlaut ableitbar): `—`-Zellen (strukturelle
  Nicht-Anwendbarkeit) NICHT migriert (waeren >140 inhaltsleere Zeilen
  gewesen); Zahlen (AUC/BAcc/Prozentsaetze/z-Werte) NICHT automatisiert
  aus der Prosa geparst (fehleranfaellig bei uneinheitlichem Format),
  stattdessen der komplette Originaltext als `notes` erhalten.
  **Ergebnis**: 56 Zeilen migriert (47 confirmed, 6 core_finding, 2
  negative, 1 neutral), manuell abgezaehlt UND programmatisch bestaetigt.
  `SYSTEMATIC_EVALUATION.md` selbst blieb unveraendert - Schritt 3
  (automatische Generierung DARAUS) ist weiterhin NICHT umgesetzt.

**2. P1.3 (Experiment-/Daten-Provenienz)**: neue `provenance.R` mit
`capture_run_provenance()` - baut bewusst AUF der bestehenden
`run_config`-EAV-Tabelle auf (keine neue Tabelle noetig). Deckt
SHA256-Hashes fuer Trainings-/Testdaten/Modellartefakte, einen
GEHASHTEN (nicht Klartext-)Config-Hash, einen Resampling-Hash ueber die
TATSAECHLICHEN Fold-Zuweisungen (nicht das R6-Objekt), Feature-Set-Label-
oder-Hash, R-Version und Paketversionen ab. **Dabei einen echten Bug
gefunden+gefixt**: `as.list()` auf einem Environment hat keine
garantierte Reihenfolge, wodurch `digest()` fuer inhaltlich identische
Configs unterschiedliche Hashes lieferte, je nachdem ob als Environment
oder Liste uebergeben - gefixt durch Sortierung nach Namen vor dem
Hashen. `digest` zu `DESCRIPTION` UND zur `unit-tests`-CI-Job-
`extra-packages`-Zeile hinzugefuegt. **Kein Live-Demo** in der echten DB
(anders als P1.2) - Provenienz muss ZUM ZEITPUNKT eines echten Laufs
erfasst werden, ein rueckwirkendes Anhaengen an einen historischen Run
haette falsche Provenienz vorgetaeuscht.

**3. P2.1 (DB-Housekeeping)**: neue `db_housekeeping.R` mit
`db_housekeeping_check()` - REIN LESEND (DB-Verbindungen mit `flags =
RSQLite::SQLITE_RO` geoeffnet, nicht nur per Konvention). Zeigt letzte
Merge-Zeit, fehlende Projekte, neue lokale Runs, moegliche
`metric_result`-Duplikate, unvollstaendige Runs, Runs ohne Git Commit,
Backup-Anzahl/-Groesse. `discover_source_db_paths()` + Pfad-Konstanten
aus `merge_project_experiments.R` HIERHER verschoben (nicht dupliziert),
letzteres sourced jetzt diese Datei. **Live gegen die echte DB
verifiziert** (rein lesend): 12 nie gemergte lokale Projekte, 10 neue
Runs bei `openml-credit-g`, 3 unvollstaendige Runs, 129 Runs ohne Git
Commit, 9 Backup-Dateien (153.6 MB) - **kein Merge durchgefuehrt**, nur
dokumentiert (Abbruchkriterium des Plans: "Diagnose darf keine DB
veraendern"). **Nebenbefund, nicht behoben**: mehrere der "fehlenden
Projekte" sind erkennbare REGRESSIONS-Projekte, die das (unveraenderte)
Discovery-Verhalten beim naechsten Merge faelschlich in die
KLASSIFIKATIONS-Ziel-DB einsortieren wuerde - dokumentiert, nicht
entschieden.

**4. P2.2 (Shared-Core-Analyse)**: neue, reine Analyse-Datei
`SHARED_CORE_ANALYSIS.md` - KEIN Code geaendert, nichts extrahiert.
Vergleichstabelle fuer alle 9 vom Plan genannten Komponenten. **Kernbefund**:
nur 4 von 9 existieren ueberhaupt in beiden Repos (Experiment Logging, DB
Schema, Runtime Helpers, Resampling) - deren Kern ist tatsaechlich
weitgehend identisch (`set_group_role()` sogar byte-identisch,
`run_timed_benchmark()` nur 6 Diff-Zeilen). Die restlichen 5
(Generalization Gap, Provenienz, Config Validation, Evidence Registry,
Artifact Management) existieren NUR in Classification (diese Session) -
das ist eine Backport-, keine Extraktions-Frage. **Konkreter Beleg fuer
Doppelpflege-Risiko**: `MLR3_Regression/merge_project_experiments.R` war
laut eigenem Kopfkommentar bis 2026-08-08 eine unangepasste Kopie mit
falschem `target_db_path`. Empfehlung dokumentiert (3 Kandidaten nach
Risiko/Aufwand), NICHTS umgesetzt.

**5. P2.3 (Environment-Referenzpfad)**: neue, reine Doku-Datei
`ENVIRONMENT.md` - dokumentiert den BEREITS BESTEHENDEN, funktionierenden
CI-Pfad (`ci-smoke-test.yml`: Ubuntu 24.04, R `release` [zuletzt 4.6.1],
`DESCRIPTION`+`pak` statt `renv::restore()`, Unit Tests, synthetische
Smoke-Fixture) als den geforderten Referenzpfad, mit konkretem Nachweis
(CI-Lauf-ID). Kein Code/keine CI geaendert. Keine Windows-`renv`-
Migration - wie vom Plan explizit ausgeschlossen.

**6. P3, spezifizierter Teil (Modell-Hypothesen-Kriterien)**: von den 3
P3-Checklistenpunkten war nur "neue Modelle nur hypothesengetrieben
pruefen" im Plan-Dokument konkret ausgefuehrt. Per `AskUserQuestion`
(unbeantwortet) mit der empfohlenen Option fortgefahren: NUR diesen einen
Punkt umgesetzt. Neue `MODEL_HYPOTHESIS_CRITERIA.md` - 8 Pflichtpunkte
vor jedem neuen Modellkandidaten (Hypothese/Datensatztyp/Baseline/
Primaermetrik/Diversitaetsmetrik+Schwelle/Laufzeitbudget/
Abbruchkriterium/Backport-Kriterium via Verweis auf ADR-003), mit einer
retroactiven Beispieltabelle (TabPFN/TabM/Hyperband negativ, Multi-Layer-
Stacking positiv). Kodifiziert eine bereits gelebte Praxis, kein neues
Verhalten.

**7. Neue Konvention: Git-Tags pro Backlog-Meilenstein ("Versionierung/
Releases", vom Nutzer konkretisiert).** Die zwei im Plan unspezifizierten
P3-Punkte wurden per Rueckfrage geklaert - Nutzer konkretisierte
"Versionierung/Releases" als **einen annotierten Git-Tag pro erledigtem
Backlog-Meilenstein**, Namensschema `backlog-<punkt>`, gesetzt auf den
Commit, der den Meilenstein abschliesst. Kein semantisches
Versionsschema (kein installierbares Paket). Konvention in `BACKLOG.md`
dokumentiert, 8 Tags rueckwirkend fuer alle in dieser Session
abgeschlossenen Meilensteine gesetzt+gepusht, ein 9. Tag
(`backlog-p1.2-step2`) fuer die Historie-Migration direkt danach. **Gilt
ab jetzt als fester Bestandteil des Ablaufs** (Teil des
`backlog-item-workflow`-Skills, siehe unten) - nach jedem kuenftigen
abgeschlossenen Meilenstein direkt taggen.

**8. Neuer Skill erstellt: `backlog-item-workflow`.** Auf Nutzerfrage
("ist es sinnvoll Skills abzuleiten") einen Skill-Entwurf per
`skill-creator` erstellt, informell per Text-Feedback iteriert (keine
formalen Evals), dann paketiert und vom Nutzer erfolgreich als
Konto-Skill gespeichert ("konnte den Skill hochladen"). Kodifiziert genau
den mechanischen Ablauf, der in dieser Session fuer jeden Backlog-Punkt
wiederholt wurde: Punkt lokalisieren -> Scope-/Architektur-Konflikt
pruefen (EXPLIZIT als Ermessensschritt markiert, NICHT automatisiert -
bei Konflikt Rueckfrage statt Standardentscheidung) -> additiv umsetzen
-> Tests ergaenzen (inkl. der `project_dir`/`globalenv()`-Falle) -> volle
Suite gruen -> `BACKLOG.md`-Status-Abschnitt -> commit/push (mit
Fetch-Check zuerst) -> CI verifizieren -> knappe Rueckmeldung. Der Skill
selbst wurde diese Session bereits mehrfach implizit "gelebt" (P1.3 bis
P1.2-Schritt-2 folgten exakt diesem Muster), auch ohne dass er bei jedem
einzelnen Schritt explizit aufgerufen wurde.

## Offene Punkte fuer die naechste Session

**Aus ChatGPTs korrigiertem Plan bleibt nur noch:**
- **P1.2 Schritt 3** (automatische Generierung von
  `SYSTEMATIC_EVALUATION.md` AUS der Evidence Registry) - bewusst
  vertagt, der Plan selbst verlangt "nicht sofort alles migrieren".
- **P3 "Publikationsbenchmark standardisieren"** - weiterhin
  UNSPEZIFIZIERT, der Nutzer wurde einmal per `AskUserQuestion` gefragt,
  hat noch nicht geantwortet. Beim naechsten Andocken ggf. erneut
  ansprechen oder auf Initiative des Nutzers warten.

**Ausserhalb des Plans, aus P2.1s Diagnose entstanden (nicht bearbeitet,
nur dokumentiert)**:
- Ein echter Merge (`merge_project_experiments.R`) ist ueberfaellig - 12
  lokale Projekte nie gemergt, 10 neue Runs bei `openml-credit-g`. Vor
  dem naechsten Merge pruefen, ob die "fehlenden" Regressions-Projekte
  wirklich in die Klassifikations-DB gehoeren (siehe P2.2-Nebenbefund).
- 9 Backup-Dateien (153.6 MB) unter `_artifacts/` - manuelles Aufraeumen
  erwaegen (kein automatisches Loeschen implementiert).

**Keine dringenden Blocker.** Alles, was das Plan-Dokument konkret
spezifiziert hat, ist umgesetzt.

## Wichtige Konventionen (Ergaenzungen seit dem 26.08.-Anker)

- **NEU**: nach jedem abgeschlossenen Backlog-Meilenstein einen
  annotierten Git-Tag `backlog-<punkt>` auf den abschliessenden Commit
  setzen und pushen (siehe Abschnitt 7 oben, `BACKLOG.md` fuer die volle
  Konvention).
- **NEU**: der Skill `backlog-item-workflow` (Konto-Skill, nicht
  repo-lokal) kodifiziert den Standardablauf fuer "mach weiter mit
  \<Punkt>" - bei Unsicherheit ueber den naechsten Schritt dort
  nachschlagen statt neu zu erfinden.
- Bei einem mehrstufigen externen Plan mit teils unspezifizierten
  Punkten (wie P3s "Versionierung"/"Publikationsbenchmark"): NICHT
  raten - per `AskUserQuestion` fragen, bei ausbleibender Antwort mit der
  empfohlenen/konservativsten Option fortfahren und den Rest explizit
  offen lassen (diese Session zweimal so gehandhabt).
- Bei einer Massen-Migration von Freitext-Prosa in strukturierte Felder
  (P1.2 Schritt 2): NICHT automatisiert Zahlen aus uneinheitlicher Prosa
  parsen (fehleranfaellig, erzeugt stillschweigend falsche Werte) -
  Originaltext als Notiz erhalten, nur die eindeutig klassifizierbaren
  Metadaten (Status ueber ein festes Symbol-Mapping) strukturieren.
- Ein rein lesender Diagnose-Helfer (P2.1) sollte read-only auf
  DB-EBENE erzwungen werden (`flags = RSQLite::SQLITE_RO`), nicht nur per
  Konvention "wir rufen halt kein `dbExecute()` auf".
- Vollstaendiger Kontext: `BACKLOG.md` (jetzt mit P0-P3-Status-Abschnitten
  UND der Git-Tag-Konvention), `SHARED_CORE_ANALYSIS.md`,
  `ENVIRONMENT.md`, `MODEL_HYPOTHESIS_CRITERIA.md` (alle neu diese
  Session), sowie weiterhin `TARGETS.md`/`NEURAL_DEPLOY.md`/das
  persistente Gedaechtnis.

## Empfohlener erster Schritt der naechsten Session

Kein zwingender Einstiegspunkt. Falls der Nutzer nichts Konkretes
mitbringt: entweder "Publikationsbenchmark standardisieren"
konkretisieren (die letzte offene P3-Frage), oder eine neue
Literatur-/Ideenrunde anstossen (das Muster vom 24.08.), oder den
ueberfaelligen `merge_project_experiments.R`-Lauf nachholen (nach Klaerung
der Regressions-Projekt-Frage aus P2.2).
