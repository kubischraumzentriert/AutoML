# Session Handoff (Stand 2026-08-28, 2. Aktualisierung) - Statusanker

Vorheriger Anker: `statusanker/SESSION_HANDOFF_2026-08-26.md` (3.
Aktualisierung, deckte den BACKLOG.md-Refactor-Plan-Start bis P1.1-
Prototyp ab). Dieselbe Sitzung lief ueber den Tag weiter - dieser Anker
(2. Aktualisierung) deckt ZUSAETZLICH zur 1. Fassung (Abschnitte 1-8
unten: P1.2-P1.3, komplettes P2, spezifizierter P3-Teil, Git-Tag-
Konvention, `backlog-item-workflow`-Skill) einen KOMPLETT NEUEN Strang
ab: der Nutzer brachte ein neues externes Bewertungsdokument
(`AutoML_Aktuelle_Bewertung_und_Naechste_Schritte_fuer_Claude_2026-08-28.md`,
`~/Downloads`) mit einer 5-Phasen-Roadmap (A-E) ein - alle 5 Phasen
wurden abgearbeitet, plus zwei vom Nutzer explizit angeforderte
Folgeschritte (Multiplier-Korrektur-Nachpruefung, Ablationen A2+A3).

## Repo-Zustand am Ende dieser Session

- `MLR3_Classifikation` @ `e9af720` "Ablation A3: drift/stability checks
  vs. full workflow, write-up from existing evidence" - gepusht. Die
  letzten reinen Code-Pushes (Phase A/B/C/D) hatten je einen gruenen
  CI-Lauf (zuletzt `33180497695` fuer Phase D); alles danach (Phase E,
  Multiplier-Nachpruefung, Ablation A2/A3) war reine Markdown-
  Dokumentation ohne Code-Aenderung - kein neuer CI-Lauf ausgeloest
  (Workflow-Trigger nur bei `**.R`/`DESCRIPTION`/`.Rprofile`).
- `ML_Learning` (rein lokal, kein Remote): mehrere neue lokale Commits -
  6x `outer_workflow_evaluation.R` (Phase C, je ein Datensatz), 2x
  `multiplier_correction_check.R` + `class_multiplier_tuning.R`-Kopien
  (`CreditScoringChallenge`, `PumpItUp`, Nachpruefung).
- `MLR3_Regression`: weiterhin unangetastet.
- **12 neue annotierte Git-Tags** seit der 1. Fassung dieses Anchors
  (Namensschema `backlog-<punkt>`, siehe `BACKLOG.md` fuer die volle
  Liste): `backlog-phaseA-docs-and-db-domain-split`,
  `backlog-phaseB-provenance-operationalized`,
  `backlog-phaseC-outer-evaluation-7-datasets`,
  `backlog-phaseD-evidence-registry-generator`,
  `backlog-phaseE-publication-prep`,
  `backlog-multiplier-correction-followup`,
  `backlog-ablation-a2-leak-audit`, `backlog-ablation-a3-drift-stability`
  (8 explizit benannte + einige aus der 1. Fassung nachtraeglich
  gezaehlt - insgesamt jetzt 17 Tags im Repo).
- Zentrale `experiments.db` (`health_condition`-Projekt-DB) waechst
  weiter: Phase-C-Ergebnisse (7 Datensaetze + 1 Cross-Projekt-Meta-Fund)
  und die 2 Multiplier-Nachpruefungs-Funde kamen als neue `evidence`-
  Zeilen dazu. Der zentrale MERGE (`merge_project_experiments.R`) ist
  weiterhin NICHT durchgefuehrt (siehe "Offene Punkte").

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

## Was NACH der 1. Fassung dieses Anchors passiert ist: die neue Bewertung 2026-08-28 (Phase A-E)

**9. Neues externes Bewertungsdokument eingebracht** (kein
`AskUserQuestion`-Vorlauf noetig - Nutzer nannte nur den Downloads-Pfad,
Inhalt wurde gelesen und in `BACKLOG.md` unter "Naechste Bewertung
2026-08-28" dauerhaft festgehalten, da die Quelldatei selbst nicht Teil
des Repos ist). Gesamtnote 9.6/10 als persoenliches System, 9.3/10
Workshop-/Software-Paper-Reife, 8.1/10 staerkeres Forschungspaper (fehlt:
keine neue Methode, sondern eine breite Full-Workflow Outer Evaluation).
3 Hebel, 5 Phasen (A-E). Nutzerentscheidung: "Phase A zuerst", danach
jede weitere Phase per "mach weiter mit Phase X" einzeln freigegeben -
alle 5 Phasen inzwischen abgeschlossen.

**10. Phase A (Doku-Korrektur + DB-Domain-Trennung)**: `README.md`
erwaehnt jetzt auch die `testthat`-Suite (vorher nur der Smoke-Test);
`AGENTS.md`s veralteter Satz "breite systematische Evaluation fehlt"
korrigiert (die MODULWEISE Evaluation ist laengst fertig, es fehlt eine
BREITE Full-Workflow Outer Evaluation). Neue `detect_problem_type()`/
`discover_source_db_paths_by_type()` in `db_housekeeping.R` - erkennt
den Aufgabentyp (classification/regression) aus bereits geloggten
Metrik-Praefixen (`classif.*`/`regr.*`), keine neue Config noetig,
funktioniert rueckwirkend. `merge_project_experiments.R` filtert jetzt
darauf. **Bug beim ersten Testlauf gefunden+gefixt**: eine anfaengliche
"unknown -> ausschliessen"-Regel haette echte Multi-Label-Projekte
dauerhaft aus jedem Merge geworfen (nur ein fachfremder Sanity-Wert in
`metric_result`, kein `classif.*`) - korrigiert: nur bei POSITIVEM
Gegentyp-Nachweis ausschliessen, "unknown" wird inkludiert + markiert.

**11. Phase B (Provenienz operationalisieren)**: `db_create_run()`
(db_logging.R) loggt jetzt standardmaessig Basis-Provenienz (R-Version/
Paketversionen) fuer JEDEN neuen Run - EIN zentraler Aenderungspunkt
statt ~30 Skripte einzeln anzufassen (`log_baseline_provenance = TRUE`
als neuer Default-Parameter). Vor dem Push lokal simuliert, dass die
CI-Smoke-Test-Fixture (kein eigenes `provenance.R`) sauber zu einer
Warnung statt eines Absturzes degradiert - das war der entscheidende
Check.

**12. Phase C (Full-Workflow Outer Evaluation auf 7 Datensaetzen) - der
teuerste und wichtigste Schritt.** `health_condition` (P1.1) wiederverwendet
als Kategorie C (multiclass), 6 NEUE Laeufe auf bereits erkundeten
`ML_Learning`-Projekten (kein neues Setup-Risiko): `openml-credit-g` (A,
binaer moderat unausgeglichen), `CreditScoringChallenge` (B, binaer
EXTREM unausgeglichen ~1.8%), `wdbc-plateau-test` (D, klein), `PumpItUp`
(E, groesser, ~59k Zeilen), `geoai-aquaculture...` (F, Covariate Shift),
`openml-eeg-eye-state-timeseries` (G, Group-/Time-Struktur). Neues
generalisiertes `outer_workflow_evaluation_template.R` (generisches
`msr()`-Scoring statt hartkodiertem BAcc, `lightgbm_tuned`-Arm
weggelassen - war in P1.1 bereits negativ). **Zwei aeltere Projekte
brauchten Fallbacks** (fest kodierter Task-Pfad statt
`task_train_small_path`, fehlendes `class_weight_power`) - im jeweiligen
Skript nachgereicht, Projekte selbst unveraendert.

**Kernbefund (wichtigster Fund der gesamten Session)**: der
klassengewichtete `workflow_ranger`-Arm gewinnt/haelt mindestens mit bei
ALLEN 4 BAcc-primaeren Aufgaben (health_condition +8.5, openml-credit-g
+4.9, wdbc-plateau-test +0.5 Punkte; eeg-eye-state minimal dahinter, aber
vor Default-Ranger) - faellt aber DRASTISCH ab bei den 2 Accuracy-/
F-beta-primaeren Aufgaben OHNE begleitenden Multiplier-Korrekturschritt
(PumpItUp -6.8, CreditScoringChallenge -28.7 Punkte). Erklaerung: BAcc
belohnt Pro-Klasse-Balance (das Ziel der Gewichtung), Accuracy/F-beta
belohnen Mehrheits-/Positiv-Klassen-Performance (das Gegenteil). Die
urspruengliche P1.1-Aussage "der Workflow generalisiert" wird dadurch
PRAEZISIERT (staerkere, nicht schwaechere Story): er generalisiert MIT
einer zur Zielmetrik passenden Korrekturkette, nicht mit Gewichtung
allein - eine Grenzbedingung, die mit nur 1 Datensatz unsichtbar
geblieben waere.

**13. Phase D (Evidence Registry -> generierte Ergebnistabelle, P1.2
Schritt 3)**: neue `generate_systematic_evaluation.R` erzeugt
`SYSTEMATIC_EVALUATION_GENERATED.md` AUS der `evidence`-Tabelle -
reproduziert die bestehende Tabelle korrekt UND zeigt bereits neue
Inhalte (Phase-C-Spalte), die die manuelle Datei noch nicht kennt.
**Bewusst additiv**: ersetzt `SYSTEMATIC_EVALUATION.md` NICHT (dessen
redaktionelles Material - Fussnoten, Korrekturvermerke, Diskussion -
waere sonst unwiederbringlich verloren gegangen) - nur ein Verweis am
Kopf der manuellen Datei ergaenzt.

**14. Phase E (Publikationsvorbereitung)**: `BENCHMARK_PROTOCOL.md`
friert Phase C als "Version 1" ein (verbindlich fuer jeden weiteren
Datensatz). `ABLATION_STUDIES_PLAN.md` definiert 4 Ablationen (A1
Gewichtung+Multiplier, A2 Leak-Audit, A3 Drift-/Stabilitaets-Checks, A4
Ensemble Selection) nach dem `MODEL_HYPOTHESIS_CRITERIA.md`-Schema - dabei
erkannt: A1 und A4 sind durch bestehende Ergebnisse bereits de facto
beantwortet. `AGENTS.md`s Paper-Story aktualisiert (die Phase-C-
Praezisierung explizit als STAERKERE Story eingeordnet).

**15. Nachpruefung auf explizite Nutzeranfrage ("machen wir die
Nachprüfung"): hilft ein Multiplier-Korrekturschritt bei den 2 negativen
Phase-C-Faellen?** Neuer 4. Arm, Multiplier-Tuning gegen die ECHTE
Primaermetrik (F-beta/Accuracy statt BAcc) optimiert. **Ergebnis:
unterschiedlich starke Erholung** - `PumpItUp` (~7% Minderheit) fast
vollstaendig (0.7428 -> 0.8047, nahe an beiden Baselines), `CreditScoring
Challenge` (~1.8%, extremer) nur teilweise (0.1088 -> 0.2832, weiterhin
klar unter beiden Baselines). Praezisiert den Kernbefund weiter: die
Korrekturkette FUNKTIONIERT, ihre Wirksamkeit haengt aber selbst vom Grad
der Klassenschieflage ab.

**16. Ablationen A2+A3 auf explizite Nutzeranfrage ausgefuehrt**
(ueberwiegend Dokumentations-Zusammenstellung bereits vorhandener
Befunde, wie im Plan vorgesehen, kein neues Modelltraining):
- **A2 (`ABLATION_A2_LEAK_AUDIT.md`)**: 1 echter Volltreffer
  (`CreditScoringChallenge`, F1 0.88->0.41, extern via Zindi-Leaderboard
  0.4191 bestaetigt), 7x korrekt still, 1x Graubereich korrekt NICHT
  entfernt, UND - ehrlich mitdokumentiert statt nur Erfolgsfaelle
  gezeigt - 1 bekannter blinder Fleck (`Lending Club`, BAcc 0.998->0.53
  honest, Standard-Guard komplett still bei einem extrem diffusen Leak
  ueber 10 Features) mit Gegenbeispiel (`synth-redundant-leak-test`,
  moderatere Redundanz, Guard-Verbesserung greift korrekt).
- **A3 (`ABLATION_A3_DRIFT_STABILITY_CHECKS.md`)**: staerkster Fund -
  `openml-credit-g`s Learning-Curve-Modul hatte urspruenglich eine EIGENE
  falsche Messung (faelschlich "PLATEAU" durch einen Ausreisser bei
  n=20), spaeter selbst via IQR-Fix korrigiert - zeigt, das Template
  findet nicht nur externe Probleme, sondern auch eigene
  Kalibrierungsfehler. Dazu `geoai-aquaculture`s Covariate-Shift-Fund
  (aenderte die Methodenwahl) und eine kontrollierte "Winner's Curse"-
  Validierung des Generalisierungsluecke-Mechanismus (z=-3.12 korrekt
  erkannt vs. z=+2.30 korrekt nicht).

**Damit sind alle 4 in `ABLATION_STUDIES_PLAN.md` definierten Ablationen
bearbeitet, und die komplette Phase-A-E-Roadmap ist abgeschlossen.**

## Offene Punkte fuer die naechste Session

**Aus der 2026-08-28-Bewertung/Roadmap ist NICHTS mehr offen** - Phase
A-E komplett, beide Follow-ups (Multiplier-Nachpruefung, Ablationen
A2/A3) auf Nutzeranfrage erledigt.

**Was uebrig bleibt, ist bewusst NICHT automatisch angestossen**:
- Die tatsaechliche Zusammenfuehrung von `SYSTEMATIC_EVALUATION.md` und
  `SYSTEMATIC_EVALUATION_GENERATED.md` (redaktionelles Material manuell
  in die Registry uebertragen, dann die generierte Version zur alleinigen
  Quelle machen) - "Doppelpflege beenden" bleibt LANGFRISTIGES Ziel,
  bewusst nicht in Phase D erzwungen.
- Ein echter Merge (`merge_project_experiments.R`) ist weiterhin
  ueberfaellig (Stand P2.1: 12 nie gemergte lokale Projekte, seither noch
  mehr neue Runs durch Phase C dazugekommen). Die DB-Domain-Trennung aus
  Phase A macht einen sicheren Merge nur fuer echte Classification-
  Projekte jetzt moeglich - vor dem naechsten Merge trotzdem kurz
  gegenpruefen (`db_housekeeping_check()` erneut laufen lassen).
- 9+ Backup-Dateien (153.6+ MB) unter `_artifacts/` - manuelles
  Aufraeumen erwaegen.
- Eigentliche Publikations-Ausarbeitung (Paper-Text schreiben, aus den
  jetzt vollstaendigen Ablationen/Phase-C-Ergebnissen) - alle Bausteine
  liegen bereit, aber das Schreiben selbst ist nicht angestossen.

**Keine dringenden Blocker.**

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
- **NEU (Phase A)**: den Aufgabentyp eines fremden Projekts (Classification
  vs. Regression) aus bereits geloggten Metrik-Praefixen ableiten
  (`classif.*`/`regr.*`) statt ein neues Config-Feld zu verlangen -
  funktioniert rueckwirkend fuer historische Projekte. Bei einer
  Ja/Nein-Klassifikationsregel IMMER pruefen, ob "unbekannt" wirklich
  wie der Negativfall behandelt werden darf (hier fast ein Bug: echte
  Projekte waeren verloren gegangen) - lieber "unbekannt -> inkludieren +
  markieren" als "unbekannt -> ausschliessen", wenn ein falsch-negativer
  Ausschluss teurer ist als ein zu vorsichtiger Einschluss.
- **NEU (Phase B)**: eine "fuer neue Runs automatisch"-Anforderung nicht
  durch Aenderung aller Aufrufer loesen, sondern durch Aenderung EINES
  gemeinsamen, bereits von allen genutzten Einstiegspunkts
  (`db_create_run()`) - mit einem Default-Parameter, der sich abschalten
  laesst, und einem `tryCatch`, der bei fehlenden Voraussetzungen (hier:
  `provenance.R` fehlt in der CI-Fixture) zu einer Warnung statt einem
  Absturz degradiert. VOR dem Push explizit gegen die CI-Fixture
  simulieren, nicht nur lokal im vollen Projektkontext testen.
- **NEU (Phase C, wichtigster methodischer Punkt)**: eine "der Workflow
  generalisiert"-Aussage aus EINEM Datensatz ist fragil - eine Ausweitung
  auf mehrere, bewusst diverse Datensaetze/Kategorien deckt
  Grenzbedingungen auf, die sonst unsichtbar blieben (hier: Score-Metrik-
  Typ entscheidet, ob Klassengewichtung hilft oder schadet). Das ist der
  eigentliche Wert einer breiten Outer Evaluation, nicht nur "mehr
  Datenpunkte".
- **NEU (Phase D)**: bei "generiere X aus einer strukturierten Quelle,
  X existiert bereits manuell gepflegt" NICHT die manuelle Datei
  ueberschreiben, wenn sie redaktionellen Mehrwert hat, den die Quelle
  nicht abbildet (hier: Fussnoten/Diskussion) - additiv (neue Datei +
  Verweis) statt destruktiv vorgehen, "Doppelpflege beenden" bleibt
  langfristiges statt sofortiges Ziel.
- **NEU (Ablationen A2/A3)**: bei einer Trust-/Fehlervermeidungs-
  Ablation (kein Score-Effekt erwartet) NICHT nur Erfolgsfaelle zeigen -
  ein dokumentierter blinder Fleck (Lending Club) macht die Story
  glaubwuerdiger, nicht schwaecher.
- Vollstaendiger Kontext: `BACKLOG.md` (jetzt mit P0-P3- UND Phase-A-E-
  Status-Abschnitten sowie der Git-Tag-Konvention),
  `SHARED_CORE_ANALYSIS.md`, `ENVIRONMENT.md`,
  `MODEL_HYPOTHESIS_CRITERIA.md`, `BENCHMARK_PROTOCOL.md`,
  `ABLATION_STUDIES_PLAN.md` + die 2 ausgearbeiteten Ablations-Dokumente
  (`ABLATION_A2_LEAK_AUDIT.md`, `ABLATION_A3_DRIFT_STABILITY_CHECKS.md`),
  `SYSTEMATIC_EVALUATION_GENERATED.md`, sowie weiterhin
  `TARGETS.md`/`NEURAL_DEPLOY.md`/das persistente Gedaechtnis.

## Empfohlener erster Schritt der naechsten Session

Kein zwingender Einstiegspunkt - sowohl ChatGPTs urspruenglicher Plan als
auch die 2026-08-28-Bewertungs-Roadmap sind komplett abgearbeitet. Falls
der Nutzer nichts Konkretes mitbringt: entweder die tatsaechliche
Publikations-Ausarbeitung anstossen (alle Bausteine - Phase C, beide
Ablationen, das eingefrorene Protokoll - liegen bereit), oder den
ueberfaelligen `merge_project_experiments.R`-Lauf nachholen (jetzt mit
DB-Domain-Trennung sicherer moeglich), oder eine neue Literatur-/
Ideenrunde anstossen (das Muster vom 24.08.).
