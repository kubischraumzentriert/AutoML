# Session Handoff (Stand 2026-08-29) - Statusanker

Vorheriger Anker: `statusanker/SESSION_HANDOFF_2026-08-28.md` (2.
Aktualisierung, deckte die komplette Phase-A-E-Roadmap des
2026-08-28-Bewertungsdokuments plus zwei Folgeschritte ab - Multiplier-
Nachpruefung, Ablationen A2+A3). Dieser Anker deckt alles ab, was SEIT
diesem Handoff passiert ist: der ueberfaellige zentrale Merge (inkl. 2
gefundener/gefixter Bugs), Backup-Aufraeumen, und die komplette
Bearbeitung von P0-P3 aus einem NEUEN, dritten externen
Bewertungsdokument (2026-08-29). Die GESAMTE P0-P3-Roadmap des dritten
Bewertungsdokuments ist vollstaendig abgearbeitet. **9. Aktualisierung
dieses Ankers:** JOSS-Repo-Checkliste vollstaendig geprueft und
geschlossen - LICENSE (MIT), CONTRIBUTING.md + Issue-Templates,
`joss/paper.md` auf 6 JOSS-Pflichtabschnitte erweitert, und eine
GitHub Action fuer eine automatische Vorschau-PDF eingerichtet und
tatsaechlich verifiziert (echtes 4-Seiten-PDF heruntergeladen und
geprueft, nicht nur "Workflow gruen" vertraut). Von der urspruenglichen
JOSS-Vorbereitungsliste ist jetzt NUR NOCH die tatsaechliche Einreichung
selbst offen. **10. Aktualisierung (jetzt 2026-08-30, Datum seit dieser
Aktualisierung uebergelaufen, Session laeuft nahtlos weiter - dieser
Anker bleibt bewusst unter dem 29.08.-Dateinamen, da es eine
zusammenhaengende Fortsetzung ist):** JOSS-Einreichung nach 2 echten,
gegen JOSS' eigene Docs verifizierten Risiken (Alters-Gate,
Scope-Fit-Frage) bewusst PAUSIERT statt aufgegeben, Wiedervorlage
~November 2026; ausserdem ein kleiner Abstecher in das separate
Logseq-Lernkarten-Repo `C:\Users\HP\Documents\ML01` (5 neue ESS-Karten +
Nutzer-Sammelcommit). **11. Aktualisierung:** der komplette
"Research Aspect"-Weg (3 Schritte: formaler Signifikanztest,
Tuning-Budget-Test, Metafeature-Analyse) fuer P2s Level-2-Befund
durchgefuehrt und abgeschlossen, plus AutoML-Conf als parallele
Alternativ-Venue zu JOSS notiert (2026 nicht mehr erreichbar, 2027
ABCD-Track vermerkt). **12. Aktualisierung:** ein VIERTES externes
Bewertungsdokument eingebracht (2026-08-30), dessen P0
(Dokumentationskonsistenz-Pass) vollstaendig abgearbeitet - 3 konkrete
Drift-Funde (`EVALUATION_LEVELS.md`, `EXTERNAL_BENCHMARK_SET.md`,
`joss/paper.md`s "package"-Wortwahl) + der Evidence-Registry-Claim
korrigiert. **13. Aktualisierung:** P1 aus demselben Dokument -
`JOSS_TECHNIQUE_WATCH.md` angelegt (alle 7 Kandidaten strukturiert
dokumentiert, jeder DOI/Autor/Jahr einzeln gegen JOSS verifiziert).

## Repo-Zustand am Ende dieser Session

- `MLR3_Classifikation` @ `d6f05a1` "P1 (2026-08-30-Bewertung):
  JOSS_TECHNIQUE_WATCH.md anlegen" - gepusht. `.md`-only, CI Smoke Test
  (Haupt-Workflow) triggert dafuer nicht - letzter tatsaechlicher
  CI-Smoke-Test-Lauf weiterhin gruen fuer `d29ea0d` (Lauf
  `33300592379`). Der `Draft JOSS PDF`-Workflow lief fuer den
  vorherigen Commit (`3509661`, da `joss/paper.md` geaendert wurde)
  erfolgreich (Lauf `33307346419`).
- **Separates Repo** `C:\Users\HP\Documents\ML01` (Logseq-Lernkarten-
  Graph, GitHub `kubischraumzentriert/LogSeq`): neue Seite `Effective
  Sample Size (ESS).md` (5 Karten) + Verlinkung in `Data Leakage.md`/
  `contents.md` (Commit `efd5b1a`), danach ein Sammelcommit auf
  Nutzerwunsch fuer manuelle Umlaut-Korrekturen + SRS-Reviews + Backups
  (Commit `10ef610`) - beide gepusht. Lokale Git-Identity dieses Repos
  war unkonfiguriert, per `--local` auf die bereits etablierte
  Konvention "Codex <codex@local>" gesetzt (nicht global geaendert).
- `ML_Learning` (rein lokal, kein Remote): 12 neue Projektordner
  (`openml-cc18-cmc`, `-optdigits`, `-sick`,
  `-analcatdata-authorship`, `-blood-transfusion`, `-ilpd` - je mit
  `020_task.R` via `mlr3oml` + Protokoll-v1-, v2- UND v3-Skripten, v3 in
  ALLEN 6 Projektordnern), mehrere lokale Commits, zuletzt `9127bb4`.
- `openml-credit-g` (lokale ML_Learning-DB) hatte ihre `proj_id`
  angeglichen (siehe Merge-Fix unten) - Backup vor der Aenderung
  angelegt.
- Zentrale `experiments.db` (`health_condition`-Projekt) vollstaendig
  gemergt (23 Classification-Quell-DBs), 4 Backup-Dateien geloescht
  (nur die letzte, aktuelle blieb); alle P1/P2-Evidence-Eintraege dieser
  Session (20 neue Zeilen) liegen direkt in dieser zentralen DB (der
  Logging-Helfer verbindet sich zentral, nicht projekt-lokal).
- **10 neue annotierte Git-Tags**: `backlog-central-merge-completed`,
  `backlog-2026-08-29-p0-evaluation-levels`,
  `backlog-p1-external-benchmark-frozen`,
  `backlog-p1-external-benchmark-executed`,
  `backlog-p1-fair-baselines-complete`, `backlog-p2-level2-prototype`,
  `backlog-p2-level2-full-rollout`, `backlog-p2-complete`,
  `backlog-2026-08-29-roadmap-complete` (9 explizit benannte - insgesamt
  jetzt 26+ Tags im Repo). Der letzte Tag markiert den Abschluss der
  GESAMTEN P0-P3-Roadmap. Fuer P3s 1. Teil (`finalize_run_provenance()`)
  wurde bewusst KEIN eigener Zwischentag gesetzt (kleiner, additiver
  Schritt ohne eigenen "Meilenstein"-Charakter).
- **Neue Datei `PAPER_DRAFT.md`**: erster vollstaendiger Rohentwurf eines
  Workshop-/Experience-/Software-Papers ("A Reproducible, Trust-Centered
  AutoML Workflow for Tabular Classification in R/mlr3"), auf Englisch,
  explizit als DRAFT markiert. Per `SendUserFile` an den Nutzer
  ausgeliefert. Dient inzwischen als "extended technical report" (siehe
  unten).
- **Ordner `joss/`**: die tatsaechliche Ziel-Venue-Einreichung, jetzt
  vollstaendig. `paper.md` (1342 Woerter, alle 6 JOSS-Pflichtabschnitte:
  Summary/Statement of Need/State of the Field/**Software Design**/
  **Research Impact Statement**/**AI Usage Disclosure**/Acknowledgements/
  References). Autor **Andre Endress** (Independent Researcher, keine
  ORCID) - vom Nutzer per `AskUserQuestion` bestaetigt, nicht geraten.
  Nur die Acknowledgements-Sektion bleibt bewusst ein offener `TODO`.
  `paper.bib` (6 BibTeX-Eintraege), `README.md` (Rollenteilung, jetzt
  mit vollstaendiger 7-Punkte-JOSS-Checkliste, alle Punkte erledigt bis
  auf die eigentliche Einreichung). Neue Root-Dateien `LICENSE` (MIT)
  und `CONTRIBUTING.md` + `.github/ISSUE_TEMPLATE/` (Bug-Report/
  Feature-Request), neuer Workflow `.github/workflows/draft-pdf.yml`
  (automatische Vorschau-PDF, verifiziert erfolgreich gelaufen). Per
  `SendUserFile` ausgeliefert (Draft-Texte + das erste erzeugte PDF).

## Was in dieser Session passiert ist

**1. Zentraler Merge nachgeholt** (Nutzeranfrage "mach weiter mit dem
Merge") - **2 echte Bugs gefunden und behoben**:
- **Regression aus P1.2**: die `evidence`-Tabelle existiert in den
  meisten lokalen Projekt-DBs nicht (deren `db_schema.sql` seither nicht
  neu ausgefuehrt) - liess die GESAMTE Merge-Transaktion pro Quelle
  zurueckrollen, auch bereits erfolgreiche Tabellen. Fix: Tabellen-
  Existenz in der Quelle vorab pruefen, fehlende Tabellen ueberspringen
  statt die Transaktion abzubrechen.
- **Vorbestehendes Datenproblem**: `openml-credit-g`s lokale `proj_id`
  wich von der bereits gemergten Ziel-ID ab (UNIQUE-Constraint-
  Verletzung) - lokal per gezieltem `UPDATE` angeglichen (mit Backup +
  FK-Integritaets-Verifikation).
- Ergebnis: alle 23 Classification-Quellen erfolgreich verarbeitet,
  `openml-credit-g` holte 10 ausstehende Runs nach.

**2. Backup-Aufraeumen** (Nutzeranfrage) - Claude identifiziert/schlaegt
vor, der NUTZER fuehrt das dauerhafte Loeschen selbst aus (Sicherheits-
grundsatz: kein automatisiertes Hard-Delete durch Claude). 12 Dateien/213
MB -> 1 Datei/19.8 MB.

**3. Neues, drittes externes Bewertungsdokument eingebracht**
(`AutoML_Bewertung_und_Verbesserungsvorschlaege_2026-08-29.md`,
`~/Downloads`, Inhalt in `BACKLOG.md` dauerhaft festgehalten). Gesamtnote
9.7/10. **Wichtigster neuer Kritikpunkt**: die bisherige "Full-Workflow
Outer Evaluation" (Phase C vom Vortag) ist NICHT der komplette AutoML-
Prozess, sondern nur EIN Baustein (gewichtetes Training + Korrektur) -
Modellwahl/Tuning/Ensemble laufen nicht innerhalb der Outer-CV-Schleife.
Vorschlag: 3 Evaluations-Ebenen (Level 1/2/3). **Zweiter Kritikpunkt**:
Benchmark Selection Bias (die 7 Phase-C-Datensaetze waren bereits
bekannt). **Dritter Kritikpunkt**: Default-Baselines zu schwach fuer ein
Research-Paper. Neue Roadmap P0-P3, Nutzerentscheidung: "P0 zuerst".

**4. P0 (Begriffe/Ebenen trennen) - ERLEDIGT.** Neue Datei
`EVALUATION_LEVELS.md` definiert Level 1 (Component Workflow - bislang
GESAMTE bisherige Outer-Evaluation, inkl. Phase C), Level 2
(Model-Selection Workflow, noch offen), Level 3 (voller Trust-Prozess,
noch offen). `BENCHMARK_PROTOCOL.md`/`AGENTS.md`/`BACKLOG.md` entsprechend
praezisiert - jede bisherige Aussage explizit auf Level 1 begrenzt, mit
dem klaren Hinweis, dass fuer Level 2/3 KEINE Evidenz vorliegt (weder
positiv noch negativ).

**5. P1, Teil "externer Benchmark" (Auswahl) - ERLEDIGT.** Nutzeranfrage
"mach weiter mit P1". Quelle: OpenML-CC18 (72 extern kuratierte
Klassifikations-Datensaetze, per OpenML-API abgerufen). Einschlusskriterien
(500-20.000 Instanzen, <=100 Features, 2-10 Klassen, nicht bereits in
diesem Template verwendet) VOR jeder Auswahl festgelegt -> 43 zulaessige
Kandidaten -> per `set.seed(20260829)` deterministisch 3 binaere + 3
multiclass gezogen, OHNE jemals eine Performance-Kennzahl einzusehen.
Eingefroren (`EXTERNAL_BENCHMARK_SET.md`): `cmc`, `optdigits`, `sick`,
`analcatdata_authorship`, `blood-transfusion-service-center`, `ilpd`.

**6. P1, Teil "Task-Vorbereitung + Level-1-Outer-Evaluation" - ERLEDIGT**
(Nutzeranfrage "erst nur die Task-Vorbereitung und Outer-Evaluation").
Alle 6 Datensaetze via `mlr3oml` (direkter OpenML-API-Zugriff) geladen,
12 neue `ML_Learning`-Projektordner. **Ergebnis bestaetigt den Phase-C-
Kernbefund erstmals auf voellig unbekannten Daten**: `workflow_ranger`
gewinnt deutlich bei 4/6 (`ilpd` +6.7, `sick` +4.6, `blood-transfusion`
+3.9, `cmc` +1.6 BAcc-Punkte), fast neutral bei den restlichen 2 - kein
einziger Ausreisser nach unten. **Echter Bug gefunden+gefixt**:
`openml-cc18-optdigits` (10 Klassen) liess `tune_class_multipliers()`
mit "cannot allocate vector of size 38.4 Gb" abstuerzen (Grid-Search
waechst exponentiell mit der Klassenzahl, 12^9 Kombinationen bei 10
Klassen) - gefixt mit einer Kombinatorik-Obergrenze (200.000), oberhalb
derer der Grid-Schritt uebersprungen wird und Prior-Korrektur +
Nelder-Mead allein den Startpunkt liefern.

**7. P1, Teil "faire getunte Baselines" (Protokoll v2) - ERLEDIGT**
(Nutzeranfrage "mach weiter mit den fairen Baselines"). Neue Arme
`tuned_ranger`/`tuned_lightgbm` (`AutoTuner`, 15 Random-Search-/MBO-Evals,
Inner-Holdout INNERHALB des Outer-Train) + `best_single_tuned_model`
(Auswahl nach innerem Tuning-Score, kein zusaetzliches Training). **Bug
gefunden+gefixt**: dieselbe `mlr3measures::tnr()`/`mlr3tuning::tnr()`-
Namenskollision aus P1.1 trat erneut auf (diesmal im Ranger-Tuning-Arm,
beim Uebertragen des Fixes vom LightGBM-Arm schlicht vergessen).

**Wichtigstes Gesamtergebnis der Session (praeziseste Version der
Kernaussage bislang)**: gegen faire getunte Baselines VERSCHWINDET
`workflow_ranger`s Vorteil bei 3 von 6 Datensaetzen (knapp, <1 BAcc-
Punkt: `cmc` -0.9, `analcatdata_authorship` -0.6, `optdigits` -0.3 -
alle groesser/besser balanciert) - bleibt aber bei den kleineren,
staerker unausgeglichenen Datensaetzen klar und deutlich bestehen
(`ilpd` +11.9, `sick` +4.0, `blood-transfusion` +0.8 BAcc-Punkte).
Aktualisierte Kernaussage: **die Gewichtungs-/Multiplier-Korrekturkette
bringt einen echten Mehrwert UEBER reines Hyperparameter-Tuning hinaus
dort, wo Klassenimbalance das dominante Problem ist - bei bereits gut
balancierten/groesseren Aufgaben leistet reines Tuning gleichwertig oder
mehr.** Beantwortet den "Default-Baselines zu schwach"-Kritikpunkt der
Bewertung direkt mit Zahlen statt einer Vermutung. `AGENTS.md`s
Paper-Story entsprechend aktualisiert.

**8. P2, Teil "Level-2-Outer-Evaluation-Prototyp" (Protokoll v3) -
ERLEDIGT** (Nutzeranfrage "mach weiter mit P2", per `AskUserQuestion`
zunaechst auf "1-2 Datensaetze" begrenzt, danach "Level-2-Prototyp auf
die restlichen 4 Datensaetze ausrollen"). Neues Skript
`outer_workflow_evaluation_v3_level2.R`: pro Outer-Fold zusaetzlicher
Inner-Train/Inner-Tune-Split (0.75/0.25), `auto_tuner()` fuer Ranger
(Random-Search) und LightGBM (MBO, je 10 Evals) + Mini-Ensemble, alle
klassenmultiplier-korrigiert, Gewinner nach Inner-Tune-Score final auf
vollem Outer-Train refittet, einmal auf Outer-Test bewertet.

**Ergebnis auf allen 6 externen Datensaetzen: GEMISCHT, kein
verlaesslicher Vorteil.** 3 Siege (`sick` +0.1, `blood-transfusion`
+3.0, `optdigits` +0.2 BAcc-Punkte ggue. dem bisher besten Wert), 3
Niederlagen (`ilpd` -3.7, `cmc` -2.6, `analcatdata-authorship` -1.9).
**Wichtig**: eine erste Arbeitshypothese nach nur 2 Datensaetzen (Level
2 hilft bei grossen/balancierten, schadet bei kleinen/unausgeglichenen
Daten) wurde nach dem vollstaendigen Rollout explizit ALS WIDERLEGT
dokumentiert - `blood-transfusion` (klein, unausgeglichen) gewinnt
deutlich, `ilpd` (dieselben Eigenschaften) verliert. Weder Groesse noch
Klassenimbalance erklaeren das Muster sauber. Ehrlicher Gesamtbefund:
mehr Prozess-Komplexitaet ist NICHT automatisch besser - bei diesem
Tuning-Budget (10 Evals/Arm) kein systematischer Mehrwert gegenueber
Level 1/den fairen v2-Baselines, bei 5-30x hoeheren Rechenkosten. Alle 6
Ergebnisse in die Evidence Registry geloggt.

**9. P2, 2. Haelfte "Evidence Registry finalisieren" - ERLEDIGT**
(Nutzeranfrage "mach weiter mit P2 zweite Haelfte"). `SYSTEMATIC_
EVALUATION_GENERATED.md` neu erzeugt (enthielt vorher nur den Stand vom
28.08., vor P1/P2 - alle 20 P1/P2-Evidence-Eintraege liegen direkt in
der zentralen `experiments.db`). **Entscheidung explizit dokumentiert**:
die 770-Zeilen-Handdatei `SYSTEMATIC_EVALUATION.md` wird NICHT
abgeschafft - ihre redaktionelle Dichte (Spaltenaufloesungs-Historie,
Korrekturvermerke, Fussnoten) liesse sich nicht verlustfrei in
Registry-Freitextfelder migrieren. Stattdessen: klare Arbeitsteilung
formalisiert - die manuelle Tabelle bleibt massgeblich fuer die 9
urspruenglichen Trust-Module, waehrend `outer_workflow_evaluation`
(Phase C/P1/P2) nur noch ueber die generierte Datei gepflegt wird.

**10. P3, 1. Teil "`finalize_run_provenance()`" - ERLEDIGT**
(Nutzeranfrage "mach weiter mit P3"). Neue Funktion in `provenance.R`,
die am ENDE eines Runs die Provenienzfelder nachtraegt, die bei
`db_create_run()` (Skriptanfang) meist noch nicht bekannt sind (Daten-/
Resampling-/Feature-Set-/Modellartefakt-Hashes) - ohne die dort bereits
geloggte R-Version/Paketliste zu duplizieren. Zentraler Aufrufpunkt:
`db_finish_run()` (bereits die EINE Stelle, die alle ~30 Skripte im Repo
nutzen) um optionale, NULL-default Parameter erweitert - rueckwaerts-
kompatibel fuer alle bestehenden Aufrufstellen. Als Referenz-
implementierung an `030_baseline.R` (Teil der CI-Smoke-Test-Kette)
demonstriert (`feature_set`/`resampling` mitgegeben), lokal gegen die
CI-Fixture verifiziert (degradiert korrekt zu Warnung bei fehlendem
`provenance.R`, wie designed). 12 neue Tests, Gesamtsuite 322/322 gruen.
**Bewusst nicht** auf alle ~30 Skripte ausgerollt - `030_baseline.R`
dient als Muster fuer kuenftige Skripte, kein Big-Bang-Refactoring.

**11. P3, 2. Teil "erster Paper-Rohentwurf" - ERLEDIGT** (Nutzeranfrage
"mach weiter mit dem Paper-Rohentwurf"). Neue Datei `PAPER_DRAFT.md` -
erster vollstaendiger Durchgang, EXPLIZIT als DRAFT markiert, auf
Englisch (Standard fuer die anvisierten Venues), obwohl das Repo selbst
deutsch dokumentiert ist. Struktur: Abstract, Introduction, System
Description, Related Work (**bewusst nur Platzhalter** - keine echte
Literaturrecherche gemacht, das steht explizit im Dokument), die 3
Evaluations-Ebenen, Level-1-Ergebnis (Phase C + externes Benchmark-Set +
faire Baselines), Level-2-Prototyp als offen kommuniziertes NEGATIVES
Ergebnis, zwei Trust-Layer-Ablationen (inkl. dem dokumentierten
Leak-Audit-blinden-Fleck, nicht nur den Erfolgsfaellen), Limitations
(inkl. der wichtigsten Klarstellung: der Titel-Anspruch "trust-centered"
gilt informell fuer Level 3/die gelebte Praxis, waehrend die
QUANTITATIVEN Befunde nur Level 1/2 abdecken), Conclusion, sowie ein
"How to use this draft"-Abschnitt mit den noch offenen menschlichen
Entscheidungen (Ziel-Venue, echte Literaturrecherche, Autorenliste,
Abbildungen/Tabellen). Jede Zahl darin stammt direkt aus bereits
gepruesften Repo-Dokumenten - keine neue Recherche, kein neuer Lauf,
reine Synthese. Per `SendUserFile` an den Nutzer ausgeliefert. Getaggt:
`backlog-2026-08-29-roadmap-complete`.

**12. `PAPER_DRAFT.md` Section 3 (Related Work) - Literaturrecherche
ERLEDIGT** (Nutzeranfrage "literaturrecherche fuer Section 3
anfangen"). 14 per Websuche lokalisierte und inhaltlich geprueft Quellen
(keine Erinnerungs-Zitate), 6 thematische Bloecke: AutoML-Systeme
(Auto-sklearn/Feurer 2015, AutoGluon-Tabular/Erickson 2020, das
AutoML-Buch/Hutter-Kotthoff-Vanschoren 2019), Benchmark-Methodik
(OpenML-CC18/Bischl 2021, "An Open Source AutoML Benchmark"/Gijsbers
2019 - direkt relevant fuer die eigene `BENCHMARK_PROTOCOL.md`-Disziplin),
Daten-Leakage/Dataset-Shift (Kaufman/Rosset/Perlich 2011,
Quinonero-Candela et al. 2009 - direkt relevant fuer Section 7.1/7.2),
Reproduzierbarkeit/Testing (Pineau et al. 2021, Gundersen/Kjensmo 2018,
Breck et al. "ML Test Score" 2017, Zhang/Harman/Ma/Liu 2020),
Klassen-Imbalance (He/Garcia 2009), sowie die verwendete Software selbst
(mlr3/Lang 2019, Caruana et al. 2004 Ensemble Selection). Jede Quelle
explizit zu einer konkreten eigenen Aussage in Bezug gesetzt statt nur
aufgelistet - inkl. einer bewusst benannten Spannung (AutoGluons
Multi-Layer-Stacking-Ergebnis vs. der eigene Level-2-Negativbefund).
**Bewusste Ehrlichkeitsentscheidung**: Adversarial Validation bekommt
KEINE akademische Zitation (Kaggle-/Praktiker-Technik, kein erfundenes
Zitat). Neuer `References`-Abschnitt mit allen 14 Quellen + URLs.
Bewusst NICHT erledigt (im Draft selbst benannt): Zitate noch nicht auf
BibTeX normalisiert, Abdeckung bewusst eng auf das Paper-Thema begrenzt.

**13. Ziel-Venue festgelegt: JOSS - ERLEDIGT** (Nutzeranfrage
"ziel-venue festlegen", per `AskUserQuestion` beantwortet mit "JOSS").
Wichtige Konsequenz, per Websuche verifiziert: JOSS reviewt die
SOFTWARE, kein vollstaendiges empirisches Paper - die Einreichung ist
ein kurzes `paper.md` (750-1750 Woerter: Summary, Statement of Need,
Comparison to existing software, Acknowledgements) + YAML-Header +
separate `paper.bib`. Neuer Ordner `joss/` (`paper.md` mit 787 Woertern,
`paper.bib` mit 6 BibTeX-Eintraegen als Teilmenge der 14 `PAPER_DRAFT.md`-
Quellen, `README.md` mit Rollenteilung + offenen Vorbereitungsschritten).
`PAPER_DRAFT.md` ist damit umdeklariert (nicht geloescht) zum "extended
technical report", auf den `paper.md` fuer die volle Level-1/2-Auswertung
verweist. Autoren-/Affiliation-/ORCID-Platzhalter zunaechst bewusst als
`TODO` belassen - keine Entscheidung, die geraten werden darf.

**14. `joss/paper.md` Autoren/Affiliation - ERLEDIGT** (Nutzeranfrage
"autoren und affiliation in joss/paper.md ausfuellen"). Per
`AskUserQuestion` abgesichert statt geraten: Name "Andre Endress" (aus
dem oeffentlichen GitHub-Profil `kubischraumzentriert` vorgeschlagen,
vom Nutzer bestaetigt), Affiliation "Independent Researcher" (kein
Institut im Profil hinterlegt), keine ORCID (Feld aus dem YAML-Header
entfernt statt als leerer Platzhalter stehen zu bleiben). Nur die
Acknowledgements-Sektion bleibt bewusst ein offener `TODO` -
Autoren-Frage war nicht danach gefragt, nichts hineingeraten.
`joss/README.md`s Vorbereitungsliste aktualisiert (Punkt 1 jetzt
"DONE").

**15. JOSS-Repo-Checkliste vollstaendig geprueft und geschlossen -
ERLEDIGT** (Nutzeranfrage "JOSS-Repo-Checkliste pruefen", dann "welche
Lizenz empfiehlst Du", dann "ja, MIT eintragen", dann "ja,
Contribution-Guidelines ergaenzen", dann "JOSS Vorschau tooling was ist
das?", dann "ja, GitHub Action einrichten"). Mehrteilige Kette:
- **Struktureller Fund** (per Doppel-Websuche gegen JOSS' aktuelle Docs
  verifiziert, nicht angenommen): `paper.md` braucht 6 statt 4
  Pflichtabschnitte - Software Design/Research Impact Statement/AI
  Usage Disclosure ergaenzt. AI Usage Disclosure legt transparent offen,
  dass ein erheblicher Teil von Code/Doku/Paper in Claude-Sessions
  entstand, unter durchgehender menschlicher Steuerung. Neue Wortzahl:
  1342.
- **Lizenz**: Repo hatte KEINE (`"license": null` via GitHub-API
  bestaetigt) - erste `AskUserQuestion` dazu wurde weggeklickt, auf
  explizite Nachfrage MIT empfohlen (Standard fuer JOSS/R-Pakete, kein
  Copyleft-Zwang) und vom Nutzer bestaetigt. Neue Datei `LICENSE`
  (Repo-Root, MIT, Copyright (c) 2026 Andre Endress) - GitHub erkennt
  sie inzwischen korrekt (API-Check nach Push bestaetigt).
- **Community-Guidelines**: neue `CONTRIBUTING.md` (beschreibt die
  TATSAECHLICHE Praxis - Einzelbetreuer, GitHub Issues als einziger
  Kanal, die >=2-Projekt-Backport-Regel aus `adr/003` als zentraler
  Vorbehalt bei neuen Modul-PRs, Dokumentations-PRs ausgenommen) +
  `.github/ISSUE_TEMPLATE/bug_report.md`/`feature_request.md`.
- **Vorschau-Tooling erklaert und eingerichtet**: neuer Workflow
  `.github/workflows/draft-pdf.yml` (via `openjournals/
  openjournals-draft-action`/`inara`, dasselbe Tool wie JOSS selbst) -
  baut bei jeder Aenderung an `joss/paper.md`/`paper.bib` eine
  unverbindliche Vorschau-PDF als Actions-Artifact. **Tatsaechlich
  verifiziert, nicht nur "Workflow gruen" vertraut**: Artifact
  heruntergeladen, echtes valides 4-Seiten-PDF bestaetigt (`file`-Check
  + PDF-Header), per `SendUserFile` ausgeliefert.

**Ergebnis: alle 7 JOSS-Repo-Checkliste-Kriterien erfuellt, alle 6
Pflichtabschnitte in `paper.md` vorhanden.** Von der urspruenglichen
Vorbereitungsliste (`joss/README.md`) ist NUR NOCH die tatsaechliche
Einreichung selbst offen - eine bewusste, eigene Entscheidung des
Nutzers, nicht ungefragt angestossen.

**16. JOSS-Einreichung bewusst PAUSIERT (nicht aufgegeben) - 2 echte
Risiken gefunden** (Nutzerfrage "JOSS einreichen, wie geht das?", dann
Nutzer-Links zu `joss.readthedocs.io/submitting.html#scope-and-significance`
und dem JOSS-Blog `2026/01/preparing-joss-for-a-generative-ai-future`,
beide unabhaengig per WebFetch verifiziert statt aus dem Gedaechtnis
angenommen):
1. **Hart, aktuell blockierend**: JOSS verlangt >=6 Monate oeffentliche
   Repo-Historie. Erster Commit dieses Repos 2026-07-07 (per `git log
   --reverse` bestaetigt) -> einreichungsfaehig fruehestens ~2027-01-07.
2. **Weich, loest sich NICHT durch Zeitablauf**: JOSS' "Scope and
   Significance"-Kriterium definiert "research software" eng
   (wissenschaftliche Domain-Modellierung, Forschungsinstrumente,
   Wissensextraktion aus Grossdatensaetzen) und schliesst "pre-trained
   machine learning models and notebooks" explizit aus - ein
   Wettbewerbs-Methodik-Template ist kein offensichtlicher Fit.

Nutzerentscheidung: Publikationsziel bleibt JOSS, Wiedervorlage
~November 2026. Auf Nachfrage "was meinst Du dazu"/"koennten wir einen
research aspect hinbekommen" empfohlener Weg: P2s bislang UNERKLAERTES
gemischtes Level-2-Ergebnis (3/3 Siege/Niederlagen, keine saubere
Groessen-/Imbalance-Erklaerung) tatsaechlich erklaeren - z.B. via
systematischer Tuning-Budget-Variation und/oder Metafeature-basierter
Vorhersage (Kandidaten: `n_inner_tune`, Minderheitsklassen-Zeilenzahl,
Inner-Score-Streuung ueber die Outer-Folds). Festgehalten in
`BACKLOG.md` UND im persistenten Gedaechtnis
(`project_joss_publication_timeline.md`), damit eine kuenftige Session
das nicht neu herleiten muss.

**17. Abstecher: 5 neue ESS-Lernkarten im separaten Logseq-Repo**
(Nutzeranfrage, ausgeloest durch Rueckfragen im Gespraech "was meinst
Du mit effektiver Stichprobengroesse"/"was war nochmal ESS" - dabei kam
heraus, dass der Begriff im JOSS-Kontext locker/uneindeutig verwendet
wurde, prazisiert als: Zeilenzahl fuer die INNERE Modellwahl im
Level-2-Prototyp, NICHT dieselbe ESS wie beim Covariate-Shift-
Reweighting). Neue Seite `Effective Sample Size (ESS).md` in
`C:\Users\HP\Documents\ML01`: Definition, Formel, Interpretation bei
niedriger ESS, Bruecke zu Adversarial Validation, Umgang bei
kollabierter ESS - VORHER geprueft, dass keine Redundanz zu den 4
bestehenden Adversarial-Validation-Karten in `Data Leakage.md`
entsteht. Danach auf Nutzerwunsch ("im Grund alles committen") ein
Sammelcommit fuer bereits vorhandene lokale Aenderungen (manuelle
Umlaut-Korrekturen, SRS-Reviews, Backups).

**18. Alternative Ziel-Venue notiert: AutoML-Conf** (Nutzerhinweis
"Wir sollten auch AutoML-Conf-Workshop nicht vergessen"). Per Websuche
geprueft: AutoML-Conf 2026 nicht mehr erreichbar (Hauptdeadline
2026-05-14 verstrichen, selbst Late-Breaking-Abstracts schliessen
2026-08-31). **AutoML-Conf 2027 ist die reale Option** - CFP im Auge
behalten, der ABCD-Track ("Applications, Benchmarks, Challenges,
Datasets") passt inhaltlich vermutlich SOGAR BESSER als JOSS zu diesem
Projekt (kein Scope-Fit-Risiko wie bei JOSS). Kein Konflikt mit dem
JOSS-Zeitplan - beide Optionen parallel verfolgbar. Auch im
persistenten Gedaechtnis ergaenzt.

**19. Der komplette "Research Aspect"-Weg fuer P2s Level-2-Befund -
3 Schritte, alle abgeschlossen** (Nutzeranfragen "mach weiter mit dem
Research Aspect" -> "ja, mach weiter mit dem Tuning-Budget-Test" ->
"ok mach weiter mit dem nächsten Kandidat"):

1. **Formaler Signifikanztest statt "3/3"-Zaehlung**: JOSS-Papersuche
   fand Autorank (Herbold 2020, JOSS) - implementiert Demsar (2006)s
   Standardmethodik fuer Mehrfach-Datensatz-Vergleiche. Bewusst NICHT
   als Python-Tool uebernommen (R-only-Policy), sondern nativ in R
   angewendet (`p2_level2_significance_test.R`). Ergebnis: gepaarter
   Wilcoxon-Test, V=8, p=0.6875 - bei n=6 statistisch nicht von einem
   Nulleffekt unterscheidbar.
2. **Tuning-Budget-Hypothese getestet und AUSGESCHLOSSEN**: alle 6
   Datensaetze mit 3x Budget (30 statt 10 Evals/Arm, ueber neue
   `LEVEL2_TUNING_EVALS`-Env-Var) neu gelaufen. Gepaarter Wilcoxon-Test
   30- vs. 10-Evals direkt: V=11, p=1.0 - der denkbar nullste Befund.
   `ilpd`/`optdigits` flippen sogar in ENTGEGENGESETZTE Richtungen
   (ilpd Niederlage->Sieg, optdigits Sieg->Niederlage).
3. **5 Metafeatures getestet - ebenfalls KEINE Erklaerung gefunden**
   (`p2_level2_metafeature_analysis.R`): Datensatzgroesse, Klassen-
   imbalance, Minderheitsklassen-Zeilenzahl im Inner-Tune, Score-
   Instabilitaet, Deckennaehe - alle |Spearman-rho| <= 0.37, alle
   p >= 0.49 bei n=6. Klassenverteilungen aus den gespeicherten
   `task_train_small.rds` gelesen, nicht geschaetzt.

**Ehrliche Gesamtschlussfolgerung, in `PAPER_DRAFT.md` Section 6
eingearbeitet**: nach Ausschluss von Groesse/Imbalance (informell),
Tuning-Budget (formal) UND 5 weiteren Metafeatures bleibt P2s
gemischtes Level-2-Muster OHNE einfache univariate Erklaerung - entweder
Interaktion hoeherer Ordnung oder irreduzibles Datensatz-Rauschen, mit
n=6 nicht unterscheidbar. Alle Ergebnisse in die Evidence Registry
geloggt. Beide neuen Skripte + alle 6 Projekt-Kopien in beiden Repos
(MLR3_Classifikation, ML_Learning) committed und gepusht, CI durchgehend
gruen verifiziert (nicht nur angenommen).

**20. VIERTES externes Bewertungsdokument (2026-08-30) - P0 abgearbeitet**
(Nutzer legte `AutoML_Bewertung_Naechste_Schritte_JOSS_Technique_Watch_
2026-08-30.md` vor, per `AskUserQuestion` "P0 zuerst" gewaehlt).
Kernaussage des Dokuments: Projekt technisch weitgehend ausgereift
(9.5-9.9 je Kategorie), Engpass jetzt Dokumentationskonsistenz/externe
Evidenzbreite/Publikationsstrategie statt Software-Funktionalitaet.
Neue Roadmap: P0 Dokumentationskonsistenz, P1 `JOSS_TECHNIQUE_WATCH.md`
+ optionale Research-Benchmark-Erweiterung (n=6->10-15), P2 erster
JOSS-inspirierter Forschungsprototyp (VeridicalFlow/PCS-Decision-
Stability oder astartes/schwierige Splits als Top-Kandidaten), P3
externe Adoption.

**P0 vollstaendig erledigt**: `EVALUATION_LEVELS.md`s Roadmap-Abschnitt
(sagte noch "P1/P2/P3 offen") und `EXTERNAL_BENCHMARK_SET.md` (sagte
noch "Noch NICHT ausgefuehrt", Kopf + Schlussabschnitt) auf den
tatsaechlichen Stand korrigiert. `joss/paper.md`s "package"-Wortwahl
(10 Stellen) durch "template" ersetzt (mlr3-Paket-Referenzen und der
"kein R-Paket"-Kontrast bewusst unveraendert). Evidence-Registry-Claim
in `joss/paper.md` UND `PAPER_DRAFT.md` praezisiert (tatsaechliche
Arbeitsteilung manuell/generiert statt pauschaler Aussage).
`BENCHMARK_PROTOCOL.md`/`AGENTS.md`/`BACKLOG.md` selbst geprueft, keine
weitere Drift gefunden (BACKLOG.md ist ein chronologisches Journal,
historische Eintraege sind fuer ihren Zeitstempel korrekt). Draft-PDF-
Workflow nach der Aenderung erneut erfolgreich verifiziert (Lauf
`33307346419`).

**21. P1 aus dem vierten Bewertungsdokument: `JOSS_TECHNIQUE_WATCH.md`
angelegt** (Nutzeranfrage "ja, JOSS_TECHNIQUE_WATCH.md anlegen"). Alle
7 Kandidaten (VeridicalFlow, astartes, Autorank, PyExperimenter,
ReciPies, ImageMLResearch, mlr3extralearners) strukturiert dokumentiert
(Titel/Autoren/DOI/Problem/Uebertragbarkeit/eigenes Problem vorhanden?/
Hypothese/Nutzen/Komplexitaetskosten/Prototype/Backport-Status), plus
ein Erinnerungs-Eintrag fuer mlr3 selbst. **Alle 7 DOIs/Autoren/Jahre
vor der Uebernahme einzeln gegen `joss.theoj.org` verifiziert statt
blind aus dem Bewertungsdokument kopiert** - stimmten exakt.
**Bemerkenswerter Zwischenfund**: Autorank ist kein reiner Watch-Punkt
mehr - die Demsar-(2006)-Wilcoxon-Methodik laeuft bereits produktiv in
`p2_level2_significance_test.R` (Research-Aspect-Schritt 1). ADR-003-
Backport-Regel ("NO BACKPORT bis Evidenz vorhanden") explizit
verankert. Noch KEINE Implementierung/Prototyp begonnen. `README.md`
um Verweis ergaenzt.

## Offene Punkte fuer die naechste Session

**Die GESAMTE P0-P3-Roadmap des DRITTEN Bewertungsdokuments
(2026-08-29) ist vollstaendig abgearbeitet, ebenso P0 des VIERTEN
Bewertungsdokuments (2026-08-30, Dokumentationskonsistenz).** Die
JOSS-Einreichung selbst ist bewusst pausiert.

**Aus dem VIERTEN Bewertungsdokument noch offen (P1 Rest + P2-P3, auf
explizite Nutzeranweisung)**:
- **P1, Rest**: `JOSS_TECHNIQUE_WATCH.md` selbst ist ERLEDIGT (siehe
  Punkt 21 oben). Nur noch offen: optional Research-Benchmark von n=6
  auf n=10-15 CC18-Datensaetze erweitern (deutlich teurer, nur falls
  der Research-/AutoML-Conf-Pfad weiterverfolgt wird - VORHER
  einfrieren, nicht nach Sicht der Zahlen).
- **P2**: erster JOSS-inspirierter Forschungsprototyp - Top-Kandidaten
  laut Bewertung: VeridicalFlow/PCS-Decision-Stability-Report oder
  astartes/schwierige-Splits-Stresstest. Nur Prototyp, kein Backport
  ohne Evidenz (ADR-003 bleibt massgeblich).
- **P3**: externe Adoption vorbereiten (Start-here-Anleitung, erstes
  Release, externe Nutzerfeedbacks als Evidenz behandeln).
- **Ausdrueckliche Warnung aus dem Bewertungsdokument**: KEIN Feature
  Creep - jede JOSS-Idee braucht erst eine eigene Hypothese/ein
  bestehendes Problem im Template, bevor prototypisiert wird. Default:
  "NO BACKPORT bis Evidenz vorhanden".

**Weiterhin offen, unabhaengig vom vierten Bewertungsdokument**:
- **Wiedervorlage ~November 2026**: JOSS-Status pruefen (bleibt bis
  ~2027-01-07 ohnehin nicht einreichbar) UND AutoML-Conf-2027-CFP im
  Auge behalten - siehe `project_joss_publication_timeline.md` im
  persistenten Gedaechtnis.
- Optional: die Acknowledgements-Sektion in `joss/paper.md` ausfuellen,
  falls gewuenscht (bleibt sonst als expliziter `TODO` stehen).
- Optional: `finalize_run_provenance()` auf weitere aktive Skripte
  ausrollen (`030_baseline.R` ist bislang die einzige
  Referenzimplementierung).

**Keine dringenden Blocker.**

## Wichtige Konventionen (Ergaenzungen seit dem 28.08.-Anker)

- **NEU**: bei einem GEFUNDENEN, PERMANENTEN Loeschvorgang (z.B.
  Backup-Dateien aufraeumen) NICHT selbst ausfuehren - identifizieren/
  vorschlagen, der Nutzer fuehrt das Loeschen selbst aus (Sicherheits-
  grundsatz, in dieser Session zum ersten Mal explizit angewendet).
- **NEU**: bei einem Merge-Skript, das mehrere Tabellen in EINER
  Transaktion pro Quelle verarbeitet - IMMER pruefen, ob eine neue
  Tabelle (hier: `evidence`) in ALLEN Quellen existiert, bevor sie zur
  Merge-Liste hinzugefuegt wird. Eine fehlende Tabelle in nur EINER
  Quelle kann sonst die GESAMTE Transaktion (inkl. anderer, laengst
  erfolgreicher Tabellen) zum Zurueckrollen bringen - ein Fehler, der
  erst beim tatsaechlichen Lauf sichtbar wird, nicht beim Code-Review.
- **NEU**: die `mlr3measures::tnr()`/`mlr3tuning::tnr()`-Namenskollision
  ist ein WIEDERKEHRENDES Risiko (diese Session: 2. Mal aufgetreten,
  nachdem sie in P1.1 bereits einmal gefunden wurde) - beim Kopieren
  eines Skript-Ausschnitts mit einem qualifizierten `mlr3tuning::tnr(...)`-
  Aufruf IMMER pruefen, ob JEDER `tnr()`-Aufruf im neuen Kontext
  qualifiziert ist, nicht nur der zuerst geschriebene.
- **NEU**: bei einer Grid-Search ueber Klassen-Multiplikatoren (oder
  aehnlichen kombinatorischen Suchen) IMMER eine Obergrenze fuer die
  Kombinationszahl einbauen, BEVOR ein neues Projekt mit unbekannter
  Klassenzahl getestet wird - exponentielles Wachstum mit der
  Dimensionszahl ist bei diesem Muster (`expand.grid()` ueber alle
  Klassen minus Referenz) fast garantiert, sobald die Klassenzahl
  zweistellig wird.
- **NEU**: eine "der Workflow ist besser als Default-Hyperparameter"-
  Behauptung ist ANFAELLIG fuer den Einwand "das war erwartbar" - eine
  faire Bewertung braucht getunte Baselines, sonst bleibt der Befund
  fuer ein Research-Paper angreifbar (diese Session direkt bestaetigt:
  bei 3/6 Datensaetzen verschwand der Vorteil tatsaechlich).
- **NEU**: eine Arbeitshypothese, die nach NUR 2 Datensaetzen aufgestellt
  wird (Level-2-Prototyp: "Groesse/Balance erklaeren das Ergebnis"),
  IMMER als vorlaeufig kennzeichnen und explizit am vollstaendigen
  Rollout nachpruefen, statt sie stillschweigend zu uebernehmen - hier
  hielt sie nicht (`blood-transfusion` widersprach ihr direkt). Ein
  widerlegter Zwischenbefund ist genauso dokumentationswuerdig wie ein
  bestaetigter.
- Vollstaendiger Kontext: `BACKLOG.md` (jetzt mit P0-P3-, Phase-A-E- UND
  der kompletten 2026-08-29-P0/P1/P2-Historie), `EVALUATION_LEVELS.md`,
  `EXTERNAL_BENCHMARK_SET.md`, `BENCHMARK_PROTOCOL.md` (jetzt v3),
  `outer_workflow_evaluation_v2_fair_baselines.R`,
  `outer_workflow_evaluation_v3_level2.R`, sowie weiterhin
  `TARGETS.md`/`AGENTS.md`/das persistente Gedaechtnis.

## Empfohlener erster Schritt der naechsten Session

Kein zwingender Einstiegspunkt, ABER ein wichtiger Kontext-Hinweis: die
JOSS-Einreichung selbst ist bewusst PAUSIERT bis ~2027-01-07 (6-Monats-
Repo-Alter-Gate) UND wegen eines offenen Scope-Fit-Risikos - siehe
Punkt 16/`project_joss_publication_timeline.md`. NICHT einfach "jetzt
einreichen" vorschlagen, falls der Nutzer das Thema ohne weiteren
Kontext wieder aufbringt - AutoML-Conf-2027 (Punkt 18) als Alternative
im Kopf behalten. Der 3-Schritte-Research-Aspect-Weg (Punkt 19) ist fuer
diese Sitzung ABGESCHLOSSEN. **Ein VIERTES Bewertungsdokument
(2026-08-30, Punkte 20-21) liegt vor - P0 (Dokumentationskonsistenz)
UND P1 (`JOSS_TECHNIQUE_WATCH.md`) sind bereits erledigt. Naechster
naheliegendster Schritt: P2 (erster JOSS-inspirierter Prototyp -
VeridicalFlow/PCS-Decision-Stability oder astartes/schwierige-Splits
als Top-Kandidaten laut Bewertungsdokument, siehe
`JOSS_TECHNIQUE_WATCH.md`) oder P3 (externe Adoption vorbereiten),
falls der Nutzer nichts Konkretes mitbringt.** Ausdrueckliche Warnung
aus diesem Dokument im Kopf behalten: kein Feature Creep, jede
JOSS-Idee braucht erst eine Hypothese/ein bestehendes Problem im
Template, Default "NO BACKPORT bis Evidenz vorhanden" (ADR-003 bleibt
massgeblich). Kleinere Alternativen: die optionale Acknowledgements-
Sektion in `joss/paper.md` ausfuellen, `finalize_run_provenance()` auf
weitere Skripte ausrollen, oder die optionale Research-Benchmark-
Erweiterung (n=6->10-15, nur falls der Research-Pfad weiterverfolgt
wird).
