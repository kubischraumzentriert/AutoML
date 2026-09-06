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
**14. Aktualisierung:** P2 - erster JOSS-inspirierter Prototyp
(Decision-Stability, VeridicalFlow/PCS) gebaut, synthetisch getestet,
auf `ilpd`+`blood-transfusion` angewendet (2 Datensaetze), dann auf
alle 6 externen Datensaetze ausgerollt. **15. Aktualisierung:** 3 neue
ADRs (007-009) angelegt. **16. Aktualisierung:** Decision Stability auf
alle 3 Outer-Folds erweitert ("Weg A", 18 statt 6 Messungen) - der
urspruengliche suggestive n=6/Fold-1-Korrelationsbefund haelt der
Erweiterung NICHT stand (rho -0.28 -> -0.086), ehrlich als widerlegt
dokumentiert. **17. Aktualisierung (jetzt 2026-08-31, neuer Tag, Session
laeuft nahtlos weiter):** 2. JOSS-inspirierter Prototyp - Hard-Split-
Stresstest (astartes-inspiriert) gebaut, synthetisch getestet, auf 2
reale Projekte angewendet - deutlich klareres, ueberzeugenderes Signal
als der 1. Prototyp (optdigits massiv auffaellig, z=-157.67).
**18. Aktualisierung:** auf Nutzerfrage hin Rollout auf alle 6
CC18-Datensaetze (4/6 auffaellig, deutlich haeufiger als der n=2-Befund
vermuten liess), dann Backport ins Template
(`137_hard_split_stress_test.R`, ADR-003-Schwelle klar erfuellt, 7/7
Bestaetigungen inkl. Template-eigenem Projekt gepruft), CI-Smoke-Test-
Fixture entsprechend ergaenzt. Anschliessend eine echte Ursachendiagnose
fuer den optdigits-Befund: der harte Cluster-Split ist dort (und bei
`analcatdata-authorship`) fast ein VERDECKTER CLASS-HOLDOUT (Test-Cluster
zu 95%/80% aus 1-3 Klassen), waehrend `sick`/`cmc` echtes
Extrapolationsrisiko unabhaengig von der Zielklasse zeigen - ein echter,
zuvor unbekannter Interpretationsvorbehalt. Auf Nutzerwunsch direkt ins
Modul zurueckgefuehrt: neue `class_proportion_shift()`-Funktion +
`class_holdout_suspected`-Flag (Schwellenwert 20 Prozentpunkte, grob an
den 4 diagnostizierten Faellen kalibriert), 4 neue Tests, Regressions-
bestaetigung am Template-Projekt (4.9pp - echtes Risiko, kein Artefakt).
**19. Aktualisierung:** P3 (externe Adoption) aus dem vierten
Bewertungsdokument bearbeitet - README um einen "Los geht's"-Abschnitt
ergaenzt (Umgebung einrichten, Testsuite, ein Skript ausprobieren,
kompletten Workflow nachvollziehen, auf eigenes Projekt uebertragen; die
zugrundeliegende Checkliste existierte bereits in `TARGETS.md`/
`WorkflowDescription.md`, war vom README aus aber nicht auffindbar).
Beispielprojekt (`health_condition`, bereits im Repo enthalten) explizit
als solches benannt. Nach Nutzerbestaetigung (bewusst vorher gefragt,
da oeffentlich sichtbar) ersten GitHub Release `v0.1.0` veroeffentlicht.
Externe-Feedback-Punkte (4/5) ehrlich als "strukturell vorbereitet, aber
mangels echter externer Nutzung inhaltlich nicht umsetzbar" dokumentiert,
nicht simuliert. **Damit ist die GESAMTE P0-P3-Roadmap des vierten
Bewertungsdokuments (2026-08-30) vollstaendig abgearbeitet.**
**20. Aktualisierung (jetzt 2026-09-01, neuer Tag, Session laeuft
nahtlos weiter):** "Weg B" - das externe Benchmark-Set fuer die
Decision-Stability-Forschungsfrage von n=6 auf n=10 CC18-Datensaetze
erweitert (Nutzeranweisung "mach weiter mit der Weg-B-Erweiterung", vorab
per AskUserQuestion auf +4 statt +9 neue Datensaetze geeinigt). 4 neue
Datensaetze deterministisch gezogen und VOR jeder Ergebnisberechnung
eingefroren (`PhishingWebsites`, `qsar-biodeg`, `mfeat-karhunen`,
`eucalyptus`, neuer Seed `20260831`, siehe `EXTERNAL_BENCHMARK_SET.md`).
Projektordner angelegt, Level-2-Prototyp + Decision-Stability (je 3
Outer-Folds) fuer alle 4 durchgefuehrt.

Dabei ein echter Fund: der bereits am 2026-08-29 bei `optdigits`
gefundene und im Template gefixte OOM-Crash-Bug
(`class_multiplier_tuning.R`, kombinatorische Grid-Explosion bei 10
Klassen) war NIE in die 5 anderen bestehenden lokalen Projekt-Kopien
(`cmc`/`sick`/`analcatdata-authorship`/`blood-transfusion`/`ilpd`)
nachgezogen worden - beim Kopieren von `cmc` als Vorlage fuer die neuen
Weg-B-Projekte reproduziert (`mfeat-karhunen`, 10 Klassen, crashte mit
"cannot allocate vector of size 38.4 Gb"). Fix aus dem Template in alle
9 betroffenen Ordner synchronisiert - Lehre: ein zentraler Bugfix
wirkt NICHT automatisch in bereits bestehenden lokalen Kopien (keine
Symlinks).

**Zentrales Ergebnis**: Level-2-Deltas der 4 neuen Datensaetze klein und
gemischt (2 leicht positiv, 2 leicht negativ, alle <0.4 BAcc-Punkte),
konsistent mit dem bisherigen Muster. Die Korrelationsanalyse ueber alle
10 Datensaetze x 3 Folds (30 statt 18 Messungen) **bestaetigt den
n=6-Nullbefund erneut**: rho=-0.134, p=0.712 (weiterhin nicht
signifikant) - der urspruengliche suggestive Fold-1-only-Befund
(rho=-0.28, n=6) bleibt damit ueber ZWEI unabhaengige
Erweiterungsschritte hinweg (Weg A: mehr Folds; Weg B: mehr Datensaetze)
widerlegt, jetzt gut abgesichert. Kein Backport (ADR-003 weiterhin nicht
erfuellt).
**21. Aktualisierung:** auf Nutzeranweisung "n=10 auf n=15 erweitern" -
die obere Grenze der urspruenglichen Vormerkung. 5 weitere Datensaetze
deterministisch gezogen und eingefroren (`ozone-level-8hr`,
`dresses-sales`, `jm1`, `MiceProtein`, `mfeat-morphological`, neuer Seed
`20260901`). Level-2 + Decision-Stability (je 3 Outer-Folds) fuer alle 5
durchgefuehrt - diesmal die Kopiervorlage direkt aus dem (bereits
gepatchten) zentralen Template statt aus einer lokalen Projekt-Kopie
genommen, um den Drift-Fehler aus Punkt 20 nicht zu wiederholen.

**Zentrales Ergebnis**: die Level-2-Deltas dieser 5 Datensaetze sind
DEUTLICH groesser als bei den ersten 10 (bisher max. |3.7| BAcc-Punkte) -
`ozone-level-8hr` +20.11, `jm1` +9.04 (beide stark unbalancierte
Aufgaben, wo Tuning+Klassengewichtung viel bringt), `dresses-sales`
-5.34 (kleinster Datensatz im Set, n=500, Overfitting-auf-Inner-Split-
Muster), `MiceProtein` +0.56, `mfeat-morphological` +0.05. Trotz dieser
groesseren Einzeldeltas bestaetigt die finale Korrelationsanalyse ueber
alle 15 Datensaetze x 3 Folds (45 Messungen) den Nullbefund ein DRITTES
Mal: rho=-0.147, p=0.601 - ein sehr konsistenter Trend ueber n=6
(rho=-0.086) -> n=10 (rho=-0.134) -> n=15 (rho=-0.147). Bemerkenswerter
Einzelfall: `ozone-level-8hr` kombiniert die hoechste Stabilitaet des
gesamten Sets MIT dem groessten Level-2-Vorteil - genau in die erwartete
Richtung, aendert aber die Gesamtkorrelation nicht signifikant. Kein
Backport (ADR-003). **Aus Kosten-Nutzen-Sicht ein natuerlicher
Abschlusspunkt fuer diese Forschungsfrage - ein weiterer Ausbau (n=15->20+)
wuerde nach dieser dritten Bestaetigung voraussichtlich keine neue
Erkenntnis mehr liefern.**
**22. Aktualisierung:** P3s letzte 2 Checklistenpunkte (externe
Nutzerfeedbacks/Issues als Evidenz) tatsaechlich GEPRUEFT statt nur
angenommen - `gh api repos/.../AutoML`: 0 Stars, 0 Forks, 0 Watchers, 0
Issues, 0 PRs seit dem `v0.1.0`-Release. Nutzerentscheidung per
AskUserQuestion: "Abwarten" (keine aktive Sichtbarkeits-Massnahme). Diese
2 Punkte bleiben strukturell vorbereitet, inhaltlich aber erst mit
echter externer Nutzung fuellbar - **damit ist P3 in dem Sinne
abgeschlossen, wie es mit dem aktuellen Repo-Stand abschliessbar ist.**

Auf Nutzerfrage "hast du was gelernt, das wir in Skill uebernehmen
koennen?": neue Skill-Datei
[`.claude/skills/extend-benchmark-set/SKILL.md`](.claude/skills/extend-benchmark-set/SKILL.md)
angelegt - fasst den zweifach identisch durchgefuehrten Weg-B-Ablauf
(Auswahl einfrieren mit neuem Seed, Projektordner IMMER aus dem
zentralen Template kopieren statt aus lokalen Kopien, Level-2
sequenziell, Decision-Stability, Korrelationsanalyse, Evidence-Logging,
Doku/Commits) als wiederholbare Prozedur zusammen, inkl. der 3
technischen Stolpersteine dieser Session (Bash-`$`-Escaping bei
Windows-Pfaden, `powershell -Command`-Bruecke bei `$_`-Referenzen,
verfruehte Background-Completion-Meldung bei doppeltem `&`).
**23. Aktualisierung:** auf Nutzeranweisung "mach weiter mit den
restlichen Bewertungspunkten" gepruefte, ob aus dem vierten
Bewertungsdokument noch etwas offen war jenseits von P0-P3 - gefunden:
Abschnitt 12 "Drei groesste Hebel", davon Hebel 1 (Benchmark erweitern)
und Hebel 2 (externe Nutzung) bereits erledigt/geprueft, aber **Hebel 3
("Story einfrieren, Paper-Claim-Hygiene") war noch offen**: weder
`PAPER_DRAFT.md` noch `joss/paper.md` erwaehnten die Decision-Stability-
oder Hard-Split-Stresstest-Befunde ueberhaupt. Per AskUserQuestion Umfang
geklaert - Nutzerentscheidung: "nur Text/Doku aktualisieren" (keine
Wiederholung der Metafeature-Analyse bei n=15).

`PAPER_DRAFT.md` erweitert: Abstract um beide Befunde ergaenzt, 2 neue
Unterabschnitte 7.3 (Decision Stability, inkl. der expliziten Fold-1-
Widerlegung ueber n=6/10/15) und 7.4 (Hard-Split-Stresstest, inkl. der
Class-Holdout-Entdeckung), Referenzen fuer Duncan et al. 2022
(VeridicalFlow, korrigierter Zitierschluessel - urspruenglich
faelschlich "Yu2020" statt korrekt "Duncan2022") und Burns et al. 2023
(astartes) ergaenzt. `joss/paper.md` um einen kurzen Absatz im "Software
design"-Abschnitt ergaenzt (weiterhin 1565/1750 Woerter, im Limit). Der
automatische Draft-PDF-CI-Workflow lief danach erfolgreich durch (Lauf
`33548539731`) - baut auch mit den Ergaenzungen fehlerfrei.

**Damit sind jetzt ALLE 3 Hebel aus dem vierten Bewertungsdokument
abgeschlossen, zusaetzlich zur bereits vollstaendigen P0-P3-Roadmap.**
**24. Aktualisierung:** ein kleiner Abstecher ausserhalb der bisherigen
Bewertungsdokumente - der Nutzer berichtete vom Abschluss des
`predictingsmartphoneAddiction_s6e8`-Wettbewerbs (Platz 1162, Top 33%)
und teilte 2 Kaggle-Write-ups (1st Place "Distributed Intelligence"/
Multi-Agent-Ansatz ohne nachvollziehbare technische Details; 7th Place
"Way Too Many Models, One Simple Stack" mit vielen konkreten,
verifizierbaren Techniken - u.a. bestaetigt dessen "nie denselben Fold
fuer Gewichtsuche UND Bewertung nutzen"-Prinzip exakt unsere eigene
`nested_cv_class_multiplier_tuning.R`-Methodik).

Aus dem 7th-Place-Write-up griff der Nutzer einen konkreten Punkt auf:
negative Stacking-Gewichte ("negative residual correctors") verbesserten
dort das Ensemble messbar. Nutzeranweisung: "das ist ein Kandidat fuer
mich - kannst du mal bei JOSS dann schauen?" - JOSS-Suche ergab einen
direkt passenden, verifizierten Beleg: `stacks`-R-Paket (Couch & Kuhn
2022, [10.21105/joss.04471](https://doi.org/10.21105/joss.04471)) hat
ein dokumentiertes `non_negative`-Argument in `blend_predictions()`
(Default `TRUE`, bei `FALSE` explizit negative Gewichte erlaubt) - in
der tatsaechlichen Funktionsdoku nachgeprueft, nicht nur aus dem
Paper-Abstract angenommen. Als **Kandidat #8** in
`JOSS_TECHNIQUE_WATCH.md` dokumentiert (Prioritaet mittel, Ursprung
explizit als "nicht aus dem urspruenglichen Bewertungsdokument"
gekennzeichnet - stattdessen aus einem Kaggle-Write-up plus eigener
JOSS-Recherche). Noch kein Prototyp, kein Backport - wartet auf ein
Projekt mit ausreichend grossem/redundantem Kandidatenpool.

## Repo-Zustand am Ende dieser Session

- `MLR3_Classifikation` @ `db3a1f5` "BACKLOG: Ensemble-Pilot
  abgeschlossen - 10 Projekte, kein systematischer Nutzen" - gepusht,
  docs-only. Zwischenstaende (alle docs-only): `e7089cb` (cmc +
  ozone-level-8hr), `d6c3395` (analcatdata-authorship + mice-protein),
  `63d03b2` (Ensemble-Faustregel-Korrektur), `7b3aab7` (Reshuffling +
  Ensemble-Pilot, erste 2 Projekte), `2a96684` (Reshuffling-Ergebnis:
  kein Unterschied), `d57a069` (Reshuffling-Prototyp gestartet),
  `3b613f9` "BACKLOG: Ranger-LB-Score geloggt +
  Fund: Ranger-Tuning nie bei voller Datenmenge". Zwischenstand: `48b3b20` "BACKLOG: s6e9 zweite/dritte Submission
  dokumentiert" - gepusht, docs-only. Zwischenstand: `939eebf` "BACKLOG:
  s6e9 TabPFN-Fehleranalyse dokumentiert - Fehleranalyse-Vertiefung
  vollstaendig" - gepusht, docs-only. Weiterer Zwischenstand: `ac507d9`
  "TabPFN-Fehleranalyse:
  Abfragezeilen-Kappung fuer grosse Eval-Splits" - CI gruen (neue Config
  `error_analysis_tabpfn_query_sample_size`, Testsuite 359/359).
  Zwischenstand: `46feebd` "BACKLOG: s6e9
  rausch-arme-Features-Entfernung dokumentiert" - gepusht, docs-only.
  Weitere Zwischenstaende (alle docs-only, kein CI-Trigger): `8221f4e`
  "Segmentmetriken - Hauptfund", `6fade18` "confidence/isolation_forest
  + LDA-Nachtest", `3abf6d0`/Statusanker, `98f08bf` "JOSS-Kandidat #8
  (negative Stacking-Gewichte): erster Prototyp-Test, Nullbefund".
  Zwischenstand: `7d66506` "BACKLOG: s6e9 ROC/PR-Kurven +
  AUC-Blend-Nullbefund dokumentiert" (docs-only). Zwischenstand:
  `0106c12`/Statusanker. Zwischenstand: `8cd15e3` "BACKLOG:
  s6e9-Trust-Gate-Diagnostik (136+137) dokumentiert" - gepusht, docs-only.
  Weitere Zwischenstaende (alle
  gepusht, CI gruen wo `.R`-Dateien betroffen): `0ffb24d` "Erweiterung:
  generalization_gap.R unterstuetzt jetzt AUC/LogLoss" (359/359 Tests,
  136 ist Teil der CI-Fixture), `a181416` (BACKLOG Ensemble-Ergebnis,
  docs-only), `a413836` "Bugfix: CatBoost-Kandidat in
  148_ensemble_candidate_pool.R lehnte integer-Spalten ab" (CI gruen),
  `3f15247` "BACKLOG: CatBoost-vs-LightGBM-Ergebnis fuer s6e9
  dokumentiert" (docs-only), `ae88221` "Bugfix: CatBoost lehnt
  integer-Spalten ab" - CI gruen (Lauf `33670597158`, 2m24s).
  Zwischenstand: `8b70733` "Neue Skill:
  declutter-flat-scripts" - gepusht (docs-only, kein CI-Trigger; Push
  brauchte 2 Versuche wegen eines kurzen Netzwerkfehlers). Zwischenstand:
  `5696b6d` "R-Skripte
  aufgeraeumt: 31 abgeschlossene Einmal-Skripte nach analysis/" - CI
  gruen (unit-tests 1m46s, smoke-test 6m20s, beide Jobs). Zwischenstand:
  `0acb6d6` (Statusanker), `6ba6af7` "Dokumente in
  docs/{reference,ablations,research} umstrukturiert" - CI gruen
  (unit-tests + smoke-test, beide Jobs). Weitere Zwischenstaende auf dem
  Weg dorthin (alle gepusht, alle CI-relevant gruen wo `.R`-Dateien
  betroffen waren): `2bc10d5` (Kaggle-Score-Bestaetigung s6e9, docs-only),
  `a69c98d` (BACKLOG: vollstaendiger `predict_type`-Sweep, docs-only),
  `3ff0c54` (Bugfix: `predict_type` in 9 weiteren Skripten, Lauf
  `33618031823` gruen), `894d9c5` (BACKLOG: Klassengewichtung +
  finales Modell, docs-only), `cf2f48f` (BACKLOG: Feature-Engineering-
  Nullbefund, docs-only), `9aca6b9` (BACKLOG: beide Bugs dokumentiert,
  docs-only), `688594e` (Bugfix: `predict_type` in
  `base_learner_constructors` + 6 Skripten, Lauf `33598897623` gruen),
  `45bfd9a` (Bugfix: `positive_class` in `finalize_task()`), `6ef9427`
  (BACKLOG: xgboost/renv-Drift-Fund), `fdfd70e` (Doku-Umstrukturierung
  zunaechst zurueckgestellt), `dc5790f` (Statusanker), `7e25b7a`
  "JOSS_TECHNIQUE_WATCH: neuer Kandidat #8 - negative Stacking-Gewichte
  (stacks-Paket, Couch/Kuhn 2022)". Zwischenstand: `7cb59e0`
  "Paper-Claim-Hygiene (Hebel 3)" (loeste den Draft-JOSS-PDF-Workflow
  aus, Lauf `33548539731`, gruen). Letzter CI-Smoke-Test-relevanter
  Commit weiterhin `eaa0000` (gruen, Lauf `33406093180`). Tag + [GitHub
  Release `v0.1.0`](https://github.com/kubischraumzentriert/AutoML/releases/tag/v0.1.0)
  weiterhin aktuell.
- Zwischenstaende: `87ad05b` "Neue Skill: extend-benchmark-set",
  `1749b21` "P3: uebrige 2 Checklistenpunkte geprueft", `cc4cf3e`
  "n=10->15 abgeschlossen" (alle ebenfalls gepusht).
- `ML_Learning` @ `e8f9a12` "n=10->15: 5 neue Projekte (ozone-level-8hr,
  dresses-sales, jm1, mice-protein, mfeat-morphological) fuer die
  Decision-Stability-Forschungsfrage" - lokal, kein Remote.
- Zwischenstand: `2074f37` "Weg B abgeschlossen: n=6->10" (ebenfalls
  gepusht, docs/Analyse-only).
- Zwischenstaende auf dem Weg dorthin (alle gepusht, alle CI gruen):
  `928cf5f` (Backport `137_hard_split_stress_test.R`, Lauf
  `33361859447`), `9bd9562` (CI-Fixture um 137 ergaenzt, Lauf
  `33362023282`), `859b1d0`/`b09c8a6` (Doku: Fixture-Ergaenzung +
  optdigits-Ursachendiagnose, docs-only, kein CI-Trigger).
- Fruehere Zwischenstaende dieses Ankers (jetzt ueberholt): Commit
  `8d02499` "P2: Decision-Stability-Prototyp
  (VeridicalFlow/PCS-inspiriert)" - gepusht. CI Smoke Test-Lauf fuer
  diesen Commit stand zum Zeitpunkt der urspruenglichen Zwischen-
  aktualisierung noch
  aus (neue `.R`-Dateien, Trigger sollte greifen) - letzter bekannter
  gruener Lauf `33300592379` (Commit `d29ea0d`). `testthat` lokal
  340/340 gruen vor dem Commit verifiziert.
- **Separates Repo** `C:\Users\HP\Documents\ML01` (Logseq-Lernkarten-
  Graph, GitHub `kubischraumzentriert/LogSeq`): neue Seite `Effective
  Sample Size (ESS).md` (5 Karten) + Verlinkung in `Data Leakage.md`/
  `contents.md` (Commit `efd5b1a`), danach ein Sammelcommit auf
  Nutzerwunsch fuer manuelle Umlaut-Korrekturen + SRS-Reviews + Backups
  (Commit `10ef610`) - beide gepusht. Lokale Git-Identity dieses Repos
  war unkonfiguriert, per `--local` auf die bereits etablierte
  Konvention "Codex <codex@local>" gesetzt (nicht global geaendert).
- `ML_Learning`: der Reshuffling-/Ensemble-Pilot (Punkte 39-40) beruehrt
  10 zusaetzliche kleine CC18-Projektordner (`openml-cc18-ilpd`,
  `-blood-transfusion`, `-qsar-biodeg`, `-eucalyptus`,
  `-analcatdata-authorship`, `-mice-protein`, `-cmc`,
  `-ozone-level-8hr`, `-mfeat-morphological`, `-mfeat-karhunen`, plus
  `-dresses-sales`/`-sick` als gescheiterte, nicht ausgewertete
  Kandidaten) - jeweils um `005_benchmark_runtime.R`/`090`/`147`/`148`/
  `149`/`167`/`ensemble_selection.R`/`db_logging.R`/`db_schema.sql`/
  `provenance.R` sowie Config-Ergaenzungen erweitert, mehrere Commits
  (alle lokal, kein Remote). `PredictingElectricVehiclePurchases-s6e9`
  selbst zuletzt unveraendert bei `60cff38` "zweite (lightgbm_10) +
  dritte (Ranger getunt) Submission erzeugt" - Kaggle-LB-Score der
  Ranger-Submission (0.93829) und der `090_ranger_tuning.R`-Neu-Lauf
  sind NUR in `experiments.db` (gitignored), kein weiterer Commit dort
  noetig. Zwischenstand: `0000b78` "TabPFN-Fehleranalyse -
  Fehleranalyse-Vertiefung vollstaendig abgeschlossen". Zwischenstand:
  `389a880` "neues
  164_low_signal_feature_removal.R - Rausch-Feature-Test". Weiterer Zwischenstand:
  `ad08609` "segment_metric_cols befuellt - Hauptfund der
  Fehleranalyse-Vertiefung". Zwischenstand: `96eaaff` "147
  Fehleranalyse (confidence/isolation_forest) + 163 LDA-Erweiterung".
  Zwischenstand: `a9aa844` "JOSS-Kandidat #8 Prototyp -
  negative Stacking-Gewichte, Nullbefund". Zwischenstand: `8153a6c`
  "ROC/PR-Kurven (160/161) + neues 162_auc_blend_ranger_lightgbm.R".
  Zwischenstand: `d262f6a` "136 (AUC-Erweiterung
  synchronisiert) + 137 Trust-Gate-Diagnostik". Weitere Zwischenstaende:
  `f05068d` "Ensemble Selection (148/149) - CatBoost-integer-Fix +
  Ergebnis", `25f59bf` "CatBoost-vs-LightGBM-Vergleich (integer-Spalten-
  Fix + Ergebnis)", `7747dad` "finales Modell + Submission (getunte
  Hyperparameter, Kaggle-Score 0.94142 geloggt)". Weitere
  Zwischenstaende:
  `840044e` (Feature Engineering verworfen - Nullbefund), `b8be70d`
  (Feature Engineering + `predict_type`-Sync), `edc6759`
  (`subset_fraction=1.0` + Lernkurve), `c03748a` (initiales Setup).
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

**22. P2: erster JOSS-inspirierter Prototyp - Decision-Stability
(VeridicalFlow/PCS)** (Nutzeranfrage "mach weiter mit P2", per
`AskUserQuestion` "VeridicalFlow / Decision-Stability-Report" gewaehlt
statt astartes). Pipeline aus `JOSS_TECHNIQUE_WATCH.md` befolgt:
Problem -> Hypothese -> Komplexitaetskosten -> kleiner Prototyp ->
synthetischer Test -> 1-2 reale Projekte.

Neues generisches Modul `decision_stability.R`
(`decision_stability_report()`) - wiederholt eine beliebige kategoriale
Entscheidungsfunktion unter variierenden Seeds, meldet Verteilung/
Mehrheitsentscheidung/Stabilitaetsanteil, flaggt bei Mehrheit
<70%. Klare Abgrenzung zu `seed_stability.R` (dort: kontinuierliche
Score-Streuung; hier: ob eine KATEGORIALE Entscheidung selbst kippt).
Synthetischer Test ZUERST: `test-decision_stability.R`, 7 Faelle mit
kontrolliertem Verhalten - Gesamtsuite 340/340 gruen (+18 neue).
Angewendet ueber `decision_stability_level2_prototype.R` (neues
Root-Template) auf die Level-2-Arm-Wahl (ranger/lightgbm/ensemble) bei
FIXEM Outer-Train (Outer-Fold 1, identisch zum eingefrorenen Protokoll
v3), nur der Inner-Split-Seed variiert 10x.

**Ergebnis `ilpd` (Fold 1)**: `ranger` gewinnt bei 7/10 Wiederholungen
(70%) - knapp nicht geflaggt.

**23. `blood-transfusion`-Ergebnis + Rollout auf alle 6 Datensaetze
(Fold 1 only)**: `blood-transfusion` gewinnt nur 6/10 (60%) -
GEFLAGGT, waehrend es im urspruenglichen Level-2-Rollout den
DEUTLICH BESSEREN Score hatte (+3.0 Punkte) und `ilpd` (stabiler,
70%) den SCHLECHTEREN (-3.7 Punkte) - gegen die naive Erwartung
laufend. Rollout auf alle 6 externen Datensaetze (Fold 1):
`sick`=60%, `cmc`=50%, `analcatdata-authorship`=70%, `optdigits`=60%.
Formaler Test: Spearman rho=-0.28 (p=0.59, n=6, NICHT signifikant,
aber konsistente Richtung: 4 geflaggte Datensaetze im Mittel +0.175,
2 nicht geflaggte im Mittel -2.8).

**24. n-Erhoehungs-Diskussion**: Nutzerfrage "sollten wir n erhoehen
... auf 8?" - geklaert, dass "n" die Anzahl Projekte meint (nicht die
10 Wiederholungen). Zwei Wege vorgeschlagen: "Weg A" (mehr Outer-Folds
der bestehenden 6 Datensaetze, guenstig, kein Benchmark-Bias-Risiko)
vs. "Weg B" (echte neue OpenML-Datensaetze, teurer, eigene
Auswahlmethodik noetig). Nutzerentscheidung: "erst Weg A".

**25. 3 neue ADRs angelegt** (Nutzerfrage "gibt es Kandidaten fuer
weitere ADRs?", dann "ja, alle 3 anlegen"):
- `adr/007-flat-scripts-not-r-package.md` (flaches Skript-Template
  statt R-Paket)
- `adr/008-frozen-versioned-benchmark-protocols.md` (Benchmark-
  Protokolle eingefroren/versioniert, nie in-place veraendert)
- `adr/009-evidence-registry-dual-source-split.md` (Evidence Registry
  vs. `SYSTEMATIC_EVALUATION.md` dauerhaft getrennte Quellen)

Ein 4. Kandidat (`PAPER_DRAFT.md` vs. `joss/paper.md`) genannt, aber
als schwaecher eingeordnet und NICHT angelegt.

**26. "Weg A" durchgefuehrt: Decision Stability auf alle 3 Outer-Folds
erweitert (18 statt 6 Messungen)** -
`decision_stability_level2_prototype.R` um `DECISION_STABILITY_OUTER_
FOLD`-Env-Var erweitert (Default 1, rueckwaertskompatibel), Fold 2+3
aller 6 Datensaetze zusaetzlich gelaufen.

**Zentraler, ehrlicher Befund - widerlegt den vorherigen
Zwischenbefund**: gemittelt ueber alle 3 Folds sinkt die Korrelation
von rho=-0.28 (Fold 1 only) auf **rho=-0.086, p=0.92** - praktisch
verschwunden. Der urspruengliche n=6/Fold-1-Befund war ein Artefakt der
kleinen Stichprobe. Bonus-Befund: Instabilitaet (<70%) ist mit 11/18
(61%) eher die Norm als die Ausnahme bei diesem Tuning-Budget.
Innerhalb-Datensatz-Konsistenz meist hoch (5/6 Datensaetze Spannweite
<=0.2 ueber 3 Folds, Ausnahme `sick` mit 0.4).

Alle Ergebnisse (18 Einzelmessungen + Korrelationsvergleich) in die
Evidence Registry geloggt. Weiterhin **kein Backport** (ADR-003) - das
generische `decision_stability.R`-Modul bleibt, die konkrete Level-2-
Anwendung liefert keine actionable Handlungsempfehlung. "Weg B" (neue
externe Datensaetze via OpenML) bleibt eine separate, groessere Option
fuer spaeter.

**27. Neuer Tag (2026-08-31), astartes als 2. JOSS-inspirierter
Prototyp** (Nutzeranweisung "astartes als zweiten Prototyp angehen") -
`hard_split_stress_test.R` (neu): `cluster_based_hard_split()`
(k-means auf numerischen Features, kleinstes Cluster = Test-Set, ein
strukturell schwieriger Extrapolations-Split statt eines zufaelligen
Interpolations-Splits) + `random_split_score_distribution()`
(Referenzbereich aus zufaelligen Holdouts gleicher Testgroesse) +
`hard_split_stress_test()` (z-Score-Report, |z|<-2 auffaellig, exakt
dasselbe Muster wie `generalization_gap.R`). Bewusst NICHT die
Python-astartes-Implementierung uebernommen, nur die Grundidee nativ in
R.

Synthetischer Test (`test-hard_split_stress_test.R`, 2-Cluster-Task mit
"flip"- vs. "no-flip"-Regel) fand einen Designfehler in der ersten
Fassung: eine CLUSTER-RELATIVE Regel liess selbst den Kontrollfall
(no-flip) faelschlich durchfallen (z=-74.3), weil absolute
Baum-Schwellenwerte cluster-relative Regeln nicht uebertragen koennen -
behoben durch ein cluster-UNABHAENGIGES Feature `x3~N(0,1)`. Danach
12/12 Tests gruen (Flip-Fall korrekt geflaggt, No-Flip-Fall korrekt
nicht geflaggt).

Angewendet auf `ilpd` und `optdigits` (ungetunter, klassengewichteter
Ranger, reiner Diagnose-Check, kein Tuning): `ilpd` z=0.18
(unauffaellig), `optdigits` z=**-157.67** (massiv auffaellig - Score
auf hartem Split 0.6918 vs. Referenzmittel 0.9811, SD=0.0018). Die
Ursache (welche Ziffernklassen/Schreibstile das Test-Cluster
dominieren) wurde bewusst NICHT weiter diagnostiziert - offener
Folgepunkt. ADR-003-Backport-Frage bleibt ebenfalls offen: das Modul
verhaelt sich korrekt (still bei ilpd, schlaegt bei optdigits an), aber
noch kein expliziter Backport als nummeriertes Pipeline-Skript ohne
weitere Nutzeranweisung/weiteren Rollout.

Commits: `MLR3_Classifikation` @ `1a02cc8`, CI Smoke Test gruen (Lauf
`33359779042`); `ML_Learning` @ `fae9029` (lokal, kein Remote, Module +
Prototyp-Skript in `openml-cc18-ilpd`/`openml-cc18-optdigits`).

## Offene Punkte fuer die naechste Session

**Die GESAMTE P0-P3-Roadmap des DRITTEN Bewertungsdokuments
(2026-08-29) ist vollstaendig abgearbeitet, ebenso P0 des VIERTEN
Bewertungsdokuments (2026-08-30, Dokumentationskonsistenz).** Die
JOSS-Einreichung selbst ist bewusst pausiert.

**P2 (Decision-Stability-Prototyp, VeridicalFlow/PCS) ist jetzt
VOLLSTAENDIG ABGESCHLOSSEN** - Modul + synthetische Tests + Rollout auf
alle 6 Datensaetze x alle 3 Outer-Folds (18 Messungen) + formale
Nachanalyse (siehe Punkte 22-26 oben). Kein Backport (ADR-003) - das
generische Modul bleibt, die konkrete Anwendung liefert keine
actionable Handlungsempfehlung.

**Die GESAMTE P0-P3-Roadmap des VIERTEN Bewertungsdokuments (2026-08-30)
ist jetzt ebenfalls vollstaendig abgearbeitet** (P0 Dokumentationskonsistenz,
P1 `JOSS_TECHNIQUE_WATCH.md`, P2 beide JOSS-inspirierten Prototypen, P3
externe Adoption - siehe Punkt 19 oben):
- **P1, Rest - VOLLSTAENDIG ABGESCHLOSSEN** (Punkte 20-21 oben): "Weg B"
  in 2 Tranchen (n=6->10->15 CC18-Datensaetze) durchgefuehrt. Korrelations-
  analyse bestaetigt den n=6-Nullbefund DREIFACH (rho=-0.086 -> -0.134 ->
  -0.147, durchgehend nicht signifikant) - keine Aenderung der
  Schlussfolgerung ueber 3 unabhaengige Stichprobengroessen hinweg. Ein
  weiterer Ausbau (n=15->20+) ist aus Kosten-Nutzen-Sicht nicht mehr
  sinnvoll (kein zwingender Grund mehr, das Ergebnis ist bereits
  dreifach stabil).
- **P2, beide JOSS-inspirierten Prototypen VOLLSTAENDIG ABGESCHLOSSEN UND
  BACKPORTED**: VeridicalFlow/Decision-Stability (kein Backport, ADR-003
  - liefert keine actionable Handlungsempfehlung) UND astartes/
  Hard-Split-Stresstest (Punkt 18 oben) - Modul + synthetische Tests +
  Rollout auf alle 6 CC18-Datensaetze (4/6 auffaellig) + Backport als
  `137_hard_split_stress_test.R` (ADR-003 erfuellt, 7/7 Bestaetigungen)
  + CI-Fixture-Ergaenzung + eine echte Ursachendiagnose (optdigits/
  analcatdata-authorship: verdeckter Class-Holdout; sick/cmc: echtes
  Extrapolationsrisiko) + direkte Modul-Erweiterung um
  `class_proportion_shift()`/`class_holdout_suspected` als Reaktion
  darauf. Kein offener Rest mehr bei diesem Thema, ausser der Nutzer
  will explizit tiefer einsteigen (z.B. Schwellenwert 20pp synthetisch
  nachschaerfen statt nur grob kalibriert, oder k>2 testen).
- **P3, VOLLSTAENDIG ABGESCHLOSSEN** (Punkte 19+22 oben):
  README-"Los geht's"-Abschnitt, Beispielprojekt explizit benannt,
  GitHub Release `v0.1.0` veroeffentlicht. Punkte 4/5 (externe
  Nutzerfeedbacks/Issues als Evidenz) TATSAECHLICH GEPRUEFT (0 Stars/
  Forks/Issues/PRs) - Nutzerentscheidung "Abwarten", kein Handlungsbedarf
  von unserer Seite, nur reagieren, falls Issues eintreffen.
- **Ausdrueckliche Warnung aus dem Bewertungsdokument**: KEIN Feature
  Creep - jede JOSS-Idee braucht erst eine eigene Hypothese/ein
  bestehendes Problem im Template, bevor prototypisiert wird. Default:
  "NO BACKPORT bis Evidenz vorhanden".
- **Abschnitt 12 "Drei groesste Hebel" - ALLE 3 ABGESCHLOSSEN**
  (Punkt 23 oben): Hebel 1 (Benchmark n=6->15) und Hebel 2 (externe
  Nutzung geprueft) waren bereits erledigt; Hebel 3 (Paper-Claim-
  Hygiene) war der letzte offene Punkt aus diesem Bewertungsdokument -
  `PAPER_DRAFT.md`/`joss/paper.md` erwaehnten die Decision-Stability-/
  Hard-Split-Stresstest-Befunde bisher gar nicht, jetzt ergaenzt
  (Text/Doku-only, Nutzerentscheidung - keine Wiederholung der
  Metafeature-Analyse bei n=15).

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
- **NEU (Punkt 24)**: JOSS_TECHNIQUE_WATCH-Kandidat #8 (negative
  Stacking-Gewichte, `stacks`-Paket) - noch kein Prototyp, wartet auf
  ein Projekt mit ausreichend grossem/redundantem Ensemble-
  Kandidatenpool, um die Hypothese sinnvoll zu testen. Nicht von selbst
  aus anfangen - erst wenn ein passendes Projekt vorliegt oder der
  Nutzer explizit danach fragt (Feature-Creep-Warnung bleibt gueltig).
- **NEU (Punkt 25)**: der getunte-Hyperparameter-Final-Modell-Fix in
  `PredictingElectricVehiclePurchases-s6e9/150_train_full_model.R` ist
  bislang lokal, n=1 - noch NICHT zentral in `150_train_full_model.R`/
  `070_final_models.R` des Templates verallgemeinert. Braucht laut
  ADR-003 eine zweite unabhaengige Projektbestaetigung vor einem
  Backport, kein eigenmaechtiger Vorstoss.
- **Erledigt (Punkt 26)**: die seit dem 2026-09-01-Anker zurueckgestellte
  Dokumenten-Umstrukturierung ist jetzt durchgefuehrt (siehe Punkt 26
  oben) - kein offener Punkt mehr.
- **Erledigt (Punkt 28)**: R-Skript-Aufraeumung (`analysis/`-Ordner)
  ebenfalls durchgefuehrt und verifiziert - kein offener Punkt mehr.
- **Erledigt (Punkt 29)**: neue Skill `declutter-flat-scripts` fasst
  das Aufraeum-Verfahren fuer eine kuenftige Wiederholung zusammen.

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
- **NEU (Punkt 25-29)**: `PredictingElectricVehiclePurchases-s6e9`
  (Setup bis Submission, s. `ML_Learning`-Commits oben), die 2 zentralen
  Bugfixes (`positive_class`, `predict_type`), der xgboost/renv-
  Umgebungsfund, die Doku-Umstrukturierung (`docs/reference`,
  `docs/ablations`, `docs/research`), die R-Skript-Umstrukturierung
  (`analysis/`), und die neue Skill `declutter-flat-scripts`.

## Empfohlener erster Schritt der naechsten Session

Kein zwingender Einstiegspunkt, ABER ein wichtiger Kontext-Hinweis: die
JOSS-Einreichung selbst ist bewusst PAUSIERT bis ~2027-01-07 (6-Monats-
Repo-Alter-Gate) UND wegen eines offenen Scope-Fit-Risikos - siehe
Punkt 16/`project_joss_publication_timeline.md`. NICHT einfach "jetzt
einreichen" vorschlagen, falls der Nutzer das Thema ohne weiteren
Kontext wieder aufbringt - AutoML-Conf-2027 (Punkt 18) als Alternative
im Kopf behalten. Der 3-Schritte-Research-Aspect-Weg (Punkt 19) ist fuer
diese Sitzung ABGESCHLOSSEN. Ein VIERTES Bewertungsdokument
(2026-08-30, Punkte 20-21) liegt vor - P0 (Dokumentationskonsistenz)
UND P1 (`JOSS_TECHNIQUE_WATCH.md`) sind bereits erledigt.

**Beide P2-Prototypen (Decision-Stability/VeridicalFlow UND
Hard-Split-Stresstest/astartes) sind jetzt VOLLSTAENDIG abgeschlossen UND
- soweit sinnvoll - backported** (Punkt 18 oben). Decision-Stability
widerlegte ehrlich den eigenen Zwischenbefund (rho -0.28 -> -0.086 ueber
3 Folds, kein Backport). Der Hard-Split-Stresstest fand einen echten,
unerwartet dramatischen Treffer bei `optdigits` (z=-157.67), wurde auf
alle 6 CC18-Datensaetze ausgerollt (4/6 auffaellig), als
`137_hard_split_stress_test.R` ins Template zurueckgefuehrt (ADR-003
erfuellt, 7/7 Bestaetigungen), UND die anschliessende Ursachendiagnose
zeigte einen echten Interpretationsvorbehalt (optdigits/analcatdata-
authorship: verdeckter Class-Holdout statt reiner Extrapolation;
sick/cmc: echtes Extrapolationsrisiko) - direkt als
`class_proportion_shift()`/`class_holdout_suspected`-Erweiterung ins
Modul zurueckgefuehrt. **Kein offener Rest mehr bei diesem Thema.**

**P3 (externe Adoption) ist ebenfalls VOLLSTAENDIG abgeschlossen**
(Punkt 19 oben): README-"Los geht's"-Abschnitt ergaenzt, das im Repo
bereits enthaltene Beispielprojekt (`health_condition`) explizit
benannt, GitHub Release [`v0.1.0`](https://github.com/kubischraumzentriert/AutoML/releases/tag/v0.1.0)
veroeffentlicht (Nutzer VORHER bewusst gefragt, da oeffentlich sichtbar).
Die letzten beiden Checklistenpunkte (externe Nutzerfeedbacks/Issues als
Evidenz) sind strukturell vorbereitet, aber naturgemaess erst mit
tatsaechlicher externer Nutzung inhaltlich fuellbar - keine Simulation,
kein weiterer Handlungsbedarf von unserer Seite.

**Damit ist die GESAMTE P0-P3-Roadmap sowohl des dritten (2026-08-29)
als auch des vierten (2026-08-30) externen Bewertungsdokuments
vollstaendig abgearbeitet - kein zwingender naechster Schritt mehr aus
irgendeinem der bisherigen Bewertungsdokumente offen.**

**"Weg B" (n=6->10->15 CC18-Datensaetze fuer die Decision-Stability-
Forschungsfrage) ist jetzt VOLLSTAENDIG abgeschlossen, in 2 Tranchen**
(Punkte 20-21 oben): 9 neue Datensaetze eingefroren, Level-2 +
Decision-Stability durchgefuehrt, Korrelationsanalyse bestaetigt den
n=6-Nullbefund DREIFACH (rho=-0.086 -> -0.134 -> -0.147, durchgehend
nicht signifikant) - der urspruengliche suggestive Fold-1-only-Befund
bleibt ueber DREI unabhaengige Erweiterungsschritte hinweg widerlegt,
so solide abgesichert wie fuer dieses Template praktisch erreichbar.
**Kein weiterer Ausbau mehr sinnvoll (n=15->20+ wuerde voraussichtlich
keine neue Erkenntnis liefern).** Dabei ein echter Nebenfund (Punkt 20):
der `optdigits`-OOM-Crash-Fix in `class_multiplier_tuning.R` war in 5
von 6 bestehenden Projekt-Kopien nie nachgezogen worden - jetzt
ueberall synchronisiert (Lehre: zentrale Bugfixes NICHT automatisch in
bestehenden lokalen Kopien wirksam - bei der 2. Tranche deshalb direkt
aus dem zentralen Template statt einer lokalen Kopie kopiert). Ein
weiterer Nebenfund (Punkt 21): 2 der 5 neuen Datensaetze
(`ozone-level-8hr`, `jm1`) zeigen deutlich groessere Level-2-Vorteile
als alle bisherigen 10 (+20.1/+9.0 BAcc-Punkte) - plausibel durch
starke Klassenunbalance erklaerbar, aendert aber nichts an der
Kernaussage (kein Stabilitaets-Erfolgs-Zusammenhang).

**P3s letzte 2 Checklistenpunkte SIND JETZT GEPRUEFT** (Punkt 22 oben,
Nutzerfrage "mach weiter mit P3s uebrigen Punkten"): `gh api` bestaetigt
0 Stars/Forks/Watchers/Issues/PRs seit `v0.1.0` - Nutzerentscheidung
"Abwarten" statt aktiver Sichtbarkeits-Massnahme. **Damit ist P3
vollstaendig, in dem Sinne, wie es mit dem aktuellen Repo-Stand
abschliessbar ist.**

**Neue Skill angelegt** (Punkt 22, Nutzerfrage "hast du was gelernt,
das wir in Skill uebernehmen koennen?"):
[`.claude/skills/extend-benchmark-set/SKILL.md`](.claude/skills/extend-benchmark-set/SKILL.md)
fasst den zweifach durchgefuehrten Weg-B-Ablauf als wiederholbare
Prozedur zusammen (Auswahl+Freeze, Projektordner IMMER aus dem
zentralen Template, Level-2 sequenziell, Decision-Stability,
Korrelationsanalyse, Evidence-Logging, Doku) inkl. 3 technischer
Stolpersteine dieser Session. Bei einer aehnlichen kuenftigen
Benchmark-Erweiterung zuerst dort nachschauen, statt den Ablauf neu
herzuleiten.

**Alle 3 "groessten Hebel" aus Abschnitt 12 des vierten
Bewertungsdokuments sind jetzt ebenfalls abgeschlossen** (Punkt 23
oben): Hebel 1 (Benchmark n=6->15), Hebel 2 (externe Nutzung geprueft -
0 Aktivitaet, "Abwarten"), Hebel 3 (Paper-Claim-Hygiene - Decision-
Stability-/Hard-Split-Stresstest-Befunde in `PAPER_DRAFT.md`/
`joss/paper.md` ergaenzt, die vorher komplett fehlten). Draft-JOSS-PDF-
CI-Workflow danach erfolgreich (Lauf `33548539731`).

**Damit sind jetzt WIRKLICH ALLE bisher bekannten Punkte aus allen 4
externen Bewertungsdokumenten dieser Session (2026-08-27/28/29/30)
vollstaendig abgearbeitet** - P0-P3-Roadmaps, die optionale Research-
Benchmark-Erweiterung, die letzten P3-Punkte, UND jetzt auch die "3
groessten Hebel" aus dem vierten Dokument. Naheliegendste naechste
Schritte, falls der Nutzer nichts Konkretes mitbringt: die optionale
Acknowledgements-Sektion in `joss/paper.md`, der Hard-Split-Stresstest-
Schwellenwert (20pp, bislang nur grob kalibriert) bei Gelegenheit
nachschaerfen, oder schlicht abwarten, ob ein FUENFTES externes
Bewertungsdokument kommt (bisheriges Muster dieser Session: nach jedem
abgeschlossenen Roadmap-Zyklus kam bisher ein neues). Ausdrueckliche
Warnung aus dem vierten Bewertungsdokument im Kopf behalten: kein
Feature Creep, jede JOSS-Idee braucht erst eine Hypothese/ein
bestehendes Problem im Template, Default "NO BACKPORT bis Evidenz
vorhanden" (ADR-003 bleibt massgeblich, jetzt auch fuer ADRs 007-009
relevant). Wiedervorlage JOSS/AutoML-Conf-2027 bleibt ~November 2026 im
Blick (Punkt 10/`project_joss_publication_timeline.md`).

**Nachtrag (Punkt 24), ausserhalb aller bisherigen Bewertungsdokumente**:
der `predictingsmartphoneAddiction_s6e8`-Wettbewerb ist beendet (Platz
1162, Top 33%) - der Nutzer teilte 2 Kaggle-Write-ups, aus dem 7th-
Place-Write-up griff er die Idee "negative Stacking-Gewichte" auf. JOSS-
Recherche ergab einen verifizierten Beleg (`stacks`-Paket, Couch/Kuhn
2022), jetzt als **Kandidat #8** in `JOSS_TECHNIQUE_WATCH.md`
dokumentiert (Prioritaet mittel). Noch kein Prototyp/Backport - NICHT
von selbst damit anfangen, wartet auf ein Projekt mit ausreichend
grossem/redundantem Ensemble-Kandidatenpool oder eine explizite
Nutzeranweisung.

**25. Aktualisierung (2026-09-02, neuer Tag, Session laeuft nahtlos
weiter)**: neues Kaggle-Projekt `PredictingElectricVehiclePurchases-s6e9`
(`ML_Learning`, lokal, kein Remote) komplett aufgesetzt und bis zur
Submission durchlaufen - Adversarial Validation (kein Distribution
Shift), LightGBM-Baseline, Ranger-/LightGBM-Tuning, Lernkurve
(subset_fraction 0.10->1.0, "noch steigend" bei 0.10), Feature-
Engineering-Nullbefund (3 neue Feature-Familien gebaut, dann per
Cross-Projekt-Abfrage der zentralen `experiments.db` widerlegt -
LightGBM reagiert nicht auf abgeleitete Features, Familien behalten,
aber nicht aktiviert), Klassengewichtungs-Nullbefund (AUC kaum
beeinflusst, LogLoss verschlechtert), finales Modell mit getunten statt
Default-Hyperparametern (lokale Sonderloesung in `150_train_full_model.R`,
n=1, noch nicht zentral verallgemeinert). Kaggle-Score **0.94142**
bestaetigt die interne CV-Schaetzung (0.9416) fast exakt (Differenz
0.0002, keine CV-LB-Luecke) - in `submission_result` geloggt.

Dabei **2 echte, zentrale Template-Bugs gefunden und gefixt** (nicht
s6e9-spezifisch): (a) `finalize_task()` in `025_feature_engineering.R`
setzte `positive_class` nicht (im Gegensatz zu `020_task.R`) - fuer
binaere Probleme mit `features`/`selected`-Featuresets relevant. (b)
`predict_type="prob"` fehlte systematisch in `base_learner_constructors`
UND in insgesamt 15 weiteren Skripten - ohne diesen fehlte
probabilistischen Messwerten (AUC/LogLoss) stillschweigend die
Grundlage, sie lieferten `NaN` statt eines Fehlers. Fund erfolgte in
ZWEI Durchgaengen (erster Fund: 6 Skripte; ein gezielter Grep-Sweep nach
der Nutzerfrage "koennen wir was ins Template uebernehmen?" deckte 9
weitere auf) - als Lehre dokumentiert: bei dieser Bug-Klasse sofort
repoweit greppen statt einzelne Fundstellen zu fixen. Ausserdem ein
Umgebungs-Fund: lokal installiertes `xgboost` (1.7.11.1) war unabhaengig
von `renv.lock` (korrekt 3.2.1.1 gepinnt) gedriftet, weil `renv` fuer
dieses Repo gar nicht aktiviert ist - `renv.lock` musste NICHT
angefasst werden, nur die lokale Installation aktualisiert.

**26. Aktualisierung**: die seit `2026-09-01` zurueckgestellte
Dokumenten-Umstrukturierung (36 Root-`.md`-Dateien, 65 querverweisende
Dateien) auf explizite Nutzerbestaetigung ("Ja, genau so umsetzen")
durchgefuehrt - 25 Dateien per `git mv` nach `docs/reference/` (11),
`docs/ablations/` (3), `docs/research/` (11) verschoben, Root auf 11
`.md`-Dateien reduziert. Alle Querverweise (41 betroffene Dateien) per
R-Skript automatisiert neu berechnet statt manuell nachgezogen;
historische Punkt-in-Zeit-Logs (`statusanker/`, `_artifacts/`) und reine
Namensnennungen (`adr/`, `joss/README.md`) bewusst nicht angefasst.
Testsuite 356/356 gruen, CI (Commit `6ba6af7`) beide Jobs gruen.

**27. Aktualisierung**: `s6e9` ist mit der Submission (Score 0.94142,
s. Punkt 25) fachlich abgeschlossen; die Doku-Umstrukturierung
(Punkt 26) ist verifiziert und gepusht. Der Nutzer teilte beilaeufig
einen weiteren s6e9-Kaggle-Link (`s6e9-1st-blood`, Public Score 0.94538,
GPU-Notebook) - Code/Methodik ohne Kaggle-Login nicht einsehbar, daher
keine Handlungsempfehlung daraus abgeleitet.

**28. Aktualisierung**: Nutzerbeobachtung "es gibt sehr viele R-Dateien -
viele scheinen nicht Bestandteil des Workflows zu sein" (114 `.R`-Dateien
im Root). Per Querverweis-Scan kategorisiert: Kern-Workflow (nummeriert
+ direkt gesourcete Support-Module, ADR-007) und ADR-008-eingefrorene
Benchmark-Protokolle (`outer_workflow_evaluation*.R`) bewusst
unangetastet gelassen; 31 abgeschlossene Einmal-Skripte (Evidence-
Logger, Portfolio-Warmstart-Validierungen, Literatur-Vergleiche,
P2-Forschungsskripte) auf Nutzerbestaetigung ("nur Kategorie C
verschieben") per `git mv` nach `analysis/` (neu, mit erklaerendem
README) verschoben - Root auf 83 `.R`-Dateien reduziert. Querverweise in
11 Dateien automatisiert korrigiert. Testsuite 356/356 gruen, ein
verschobenes Skript probeweise direkt ausgefuehrt (laeuft korrekt), CI
(Commit `5696b6d`) beide Jobs gruen.

**29. Aktualisierung**: auf Nutzerfrage "haben wir was gelernt, das wir
als Skill ablegen koennten?" - neue Skill-Datei
[`.claude/skills/declutter-flat-scripts/SKILL.md`](.claude/skills/declutter-flat-scripts/SKILL.md)
angelegt (Nutzerbestaetigung "Ja, Skill-Datei anlegen"). Fasst das in
Punkt 26+28 zweimal identisch angewendete Aufraeum-Verfahren zusammen
(Querverweis-Scan, ADR-007/008-Schutzzonen, git mv + automatisiertes
Link-Rewrite-Skript, die `source()`/Arbeitsverzeichnis-Erkenntnis -
`source("datei.R")` loest relativ zum Arbeitsverzeichnis auf, nicht zum
Skript-Pfad, solange die Konvention "immer vom Repo-Root ausfuehren"
gilt, ist Verschieben von Skripten technisch risikolos). Commit `8b70733`
(docs-only, kein CI-Trigger; Push brauchte 2 Versuche wegen eines
kurzen Netzwerkfehlers, 2. Versuch erfolgreich).

**Stand jetzt: kein offener Blocker.** Root-Verzeichnis ist jetzt fuer
Docs UND Skripte deutlich uebersichtlicher (36->11 `.md`-Dateien im
Root, 114->83 `.R`-Dateien im Root); das Aufraeum-Verfahren selbst ist
jetzt als Skill wiederverwendbar dokumentiert, falls erneuter Clutter
entsteht.

**30. Aktualisierung ("mach weiter mit s6e9", per AskUserQuestion auf
"CatBoost-Benchmark" praezisiert)**: `125_catboost_benchmark.R` fuer
`PredictingElectricVehiclePurchases-s6e9` ausgefuehrt (5-fache CV, volle
668.665 Zeilen). Dabei ein echter, allgemeiner Bug gefunden: CatBoost
(mlr3) lehnt `integer`-Spalten grundsaetzlich ab (`Fehler: ... has the
following unsupported feature types: integer`) - hier `Age`,
`Charging_Stations_Near_Home/Work`, `Number_of_Cars_Owned`. Fix:
`po("colapply", applicator = as.numeric, affect_columns =
selector_type("integer"))` vor `classif.catboost` eingefuegt - No-Op fuer
Datensaetze ohne `integer`-Spalten (daher im Template-eigenen Projekt nie
zuvor sichtbar geworden). Auf Nutzernachfrage "sollte die Konvertierung
ins Template ueberspielt werden?" sofort auch zentral in
`125_catboost_benchmark.R` uebernommen (kein ADR-003-Bestaetigungs-Gate
noetig - reiner Robustheits-Fix wie zuvor `predict_type`/`positive_class`,
kein zu evaluierendes Technique-Backport). Testsuite 356/356 gruen, CI
gruen (Commit `ae88221`).

**Eigentliches Vergleichsergebnis** (nach dem Fix): LightGBM AUC
0.9413/LogLoss 0.4299 in 124s vs. CatBoost AUC 0.9406/LogLoss 0.4286
(leicht besser) in 1405s (~11.3x langsamer) - LightGBM bleibt beim
Haupt-Metrik AUC leicht vorn UND deutlich schneller, bestaetigt die
bestehende Submission-Modellwahl, kein Wechselgrund. In `BACKLOG.md`
(Commit `3f15247`) sowie im s6e9-Projekt selbst (lokal, `ML_Learning`,
kein Remote, Commit `25f59bf`) dokumentiert.

**31. Aktualisierung ("Ensemble Selection zuerst, dann Trust-Gate-
Diagnostik")**: `147_error_analysis_ranger_models.R` (schnell) ->
`148_ensemble_candidate_pool.R` (24-Modelle-Pool: 8 Ranger/8 LightGBM/8
CatBoost) -> `149_ensemble_selection.R` fuer s6e9 durchgefuehrt. Dabei
EIN WEITERER CatBoost-`integer`-Bug gefunden (diesmal in `148`s eigener
`make_learner()`, nicht in `125` - der urspruengliche Fund deckte nur
`125_catboost_benchmark.R` ab) - als `GraphLearner` geloest
(`colapply`->`classif.catboost`), `weights`-Eigenschaft bleibt
nachweislich erhalten. Zentral UND lokal gefixt, Testsuite 356/356,
CI gruen (Commit `a413836`). **Ensemble-Ergebnis**: Greedy Ensemble
BAcc 0.8769 vs. bestes Einzelmodell (Ranger, nicht LightGBM!) 0.8748 vs.
gleichgewichteter Blend 0.8746 - kleiner Gewinn, ABER Metrik-Mismatch
(diese Pipeline bewertet BAcc, die Submission-Wahl basiert auf AUC) -
kein direkter Beleg fuer "Ensemble schlaegt LightGBM bei AUC". Reine
Diagnose, kein `156_train_full_ensemble.R`-Lauf angestossen. Commit
`a181416` (zentral), `f05068d` (s6e9 lokal).

**Nebenfund (Umgebung)**: der Rechner ging waehrend des 148-Laufs
mehrfach in Standby (Windows-Ereignisprotokoll bestaetigt: "System
Idle", "Application API", "Hibernate from Sleep - Fixed Timeout"),
verlangsamte den 1. Versuch massiv (41267s Timer-Anzeige bei real
deutlich weniger Rechenzeit). Nutzer hat den AC-Ruhemodus-Timeout
selbst auf 5h angehoben - der Rest lief durch.

**32. Aktualisierung (Trust-Gate-Diagnostik)**: `136_generalization_gap.R`
war fuer s6e9 urspruenglich NICHT lauffaehig (dokumentierte
Einschraenkung: `bootstrap_score_distribution()` nutzte nur
klassenbasierte Metriken via `pred$response`, s6e9s Hauptmetrik ist aber
`classif.auc`, probabilistisch). Per AskUserQuestion gefragt: "ueber-
springen" vs. "Template erweitern" - Nutzer waehlte **Erweiterung**.
`bootstrap_score_distribution()` erkennt jetzt anhand der Formalnamen
von `measure_fn`, ob eine `prob`-Matrix (+ optional `positive`-Klasse)
noetig ist (mlr3measures-Konvention). Dabei EIN WEITERER,
eigenstaendiger predict_type-Bug gefunden:
`build_tuned_learner_from_instance()` in `136` selbst setzte
`predict_type` nicht (dynamisches `lrn(learner_id)` mit String-Variable
- vom urspruenglichen Sweep uebersehen, da nicht grep-bar wie ein
direkter `lrn("classif.X", ...)`-Aufruf). Beides gefixt, 2 neue Tests
(AUC-Pfad + Fehlermeldung), Testsuite 359/359, CI gruen (Commit
`0ffb24d` - `136_generalization_gap.R` ist Teil der CI-Smoke-Test-
Fixture, der Fix wurde also direkt scharf getestet).

**137 (Hard-Split-Stresstest)**: harter k-means-Cluster-Split (k=2,
Test-Cluster n=239.086, 35.8%) vs. Referenzbereich (10 zufaellige
Splits). Score hart=0.9369 vs. Referenz=0.9380±0.0004 -> **z=-2.42,
AUFFAELLIG**. Klassenverschiebung nur max. 1.0pp - KEIN Class-Holdout-
Verdacht, spricht fuer echtes Extrapolationsrisiko. Wichtige Einordnung:
absoluter Effekt ist klein (0.0011 AUC-Punkte) - die Referenz-SD ist bei
diesem Datensatz sehr eng, daher faellt schon eine kleine Differenz
statistisch auf. Kein dramatischer Befund wie optdigits (z=-157.67),
sondern ein mildes, plausibles Signal (neue Kundensegmente/Fahrzeugtyp-
Cluster koennten schwaecher generalisieren als der CV-Score suggeriert).
Kein Score-Hebel, reine Diagnose - kein Grund, die Submission
zurueckzuziehen. Commit `8cd15e3` (zentral), `d262f6a` (s6e9 lokal).
**Damit sind beide Nutzeranweisungen fuer s6e9 dieser Session
abgeschlossen.**

**33. Aktualisierung (Nutzeranfrage: Festplattenplatz)**: `ML_Learning`
hatte nur noch ~10GB frei. Systematische Kandidatensuche (3 Risikostufen:
sicher/re-downloadbar, redundante Modell-Checkpoints, schwerer
neubeschaffbar). Nutzer lehnte reines Loeschen der Roh-CSVs ab
("dann koennen wir keine Verbesserungen mehr machen") und schlug
Zippen statt Loeschen vor. PowerShell `Compress-Archive` (kein Install
noetig, 7-Zip war nicht installiert) erreichte ~70% Kompression,
identisch zu gzip getestet. **21 Roh-CSV-Dateien** (abgeschlossene/
inaktive Projekte, NICHT das aktive s6e9) gezippt, JEDES Zip einzeln
verifiziert (Eintragsanzahl=1, Eintragsgroesse=Original-Groesse) VOR
UND NOCHMAL UNMITTELBAR VOR dem Loeschen der Originale (Sicherheitsnetz).
1005MB -> 302MB, **703MB freigegeben** nach Nutzerbestaetigung "Ja,
loesche die Originale". Freier Speicher jetzt 10.44GB. Offene, nicht
umgesetzte Kandidaten: `FinancialStressPredictionChallenge`s 5 fast
identische Modell-Checkpoints (~745MB, braucht erst Pruefung welche
Datei zur echten Submission gehoert), `niftis/extracted/` (633MB,
Vorsicht - Rohdaten fuer DAT_Parkinsons, ggf. nicht trivial neu
beschaffbar), s6e9s eigene `train.csv`/`test.csv` (61MB, aktives
Projekt, bewusst nicht angefasst).

**34. Aktualisierung (Nutzeranfrage: FinancialStressPredictionChallenge-
Checkpoints pruefen)**: `README.md` des Projekts dokumentiert die
komplette Leaderboard-Historie mit Scores - eindeutig identifiziert:
`final_model_lightgbm_features_iter175_ens7_l2_5.rds` (247.6MB, spaetester
Zeitstempel) ist das Modell hinter dem tatsaechlich besten/finalen
Submission-Kandidaten (Public LB 0.697156, mit OOF-Platt-Kalibrierung
obendrauf). 6 weitere, durch spaetere LB-bestaetigte Submissions
ueberholte Checkpoints identifiziert und - nach Nutzerbestaetigung "Ja,
loesche die 6 Dateien" - geloescht (~566MB). Freier Speicher jetzt
11.75GB (von 10.44GB). Offene Kandidaten: `predictingsmartphoneAddiction_
s6e8`/`playground-series-s5e12` (kleinere Mengen aehnlicher redundanter
Checkpoints, ~90MB/~40MB), `niftis/extracted/` (633MB, weiterhin
Vorsicht-Flag).

**35. Aktualisierung ("machen wir weiter mit
PredictingElectricVehiclePurchases-s6e9")**: Nutzerwunsch "ROC-/PR-Kurven
zuerst, dann Fehleranalyse-Vertiefung" - 160/161 ausgefuehrt (guenstig,
nutzt bereits geloggte 147-Vorhersagen). LightGBM fuehrt bei beiden
(ROC-AUC 0.9424, PR-AUC/Average-Precision 0.7579) - bestaetigt die
Modellwahl visuell. Beide PNGs per SendUserFile ausgeliefert.

Mitten in der Arbeit fragte der Nutzer "haben wir noch Ideen, wie wir
den Score erhoehen koennten?" - daraufhin 2 KONKRETE, noch nicht
versuchte Ideen vorgeschlagen und auf Nutzeranweisung ("AUC-Blend
zuerst, dann Stacking mit negativen Gewichten") beide getestet, BEIDE
NULLBEFUND:

- **Neues Skript `162_auc_blend_ranger_lightgbm.R`**: AUC-optimierter
  Ranger/LightGBM-Wahrscheinlichkeits-Blend (Motivation: 148/149 war
  BAcc-optimiert, Submission-Metrik ist aber AUC). Gewicht-Suche
  konvergiert gegen w_lightgbm=0.95, aber auf der unabhaengigen
  Bestaetigungsmenge liegt dieser "optimierte" Blend (0.94243) MARGINAL
  UNTER reinem LightGBM (0.94245) - Ranger bringt keinen Mehrwert.
- **Neues Skript `163_stacking_negative_weights.R`**: erster echter Test
  von JOSS_TECHNIQUE_WATCH.md Kandidat #8 (negative Stacking-Gewichte,
  `stacks`-Paket/Couch & Kuhn 2022) - s6e9s 24-Modelle-Pool aus
  `148_ensemble_candidate_pool.R` erfuellt genau die im Kandidaten
  genannte Voraussetzung. `glmnet::cv.glmnet(lower.limits=0 vs. -Inf)`
  als Mechanik-Nachbau von `stacks::blend_predictions()`. Ergebnis:
  Meta-Learner waehlte 0 von 24 negative Koeffizienten - beide Varianten
  identisch (AUC 0.9416), UND das beste Einzelmodell im Pool (AUC
  0.9427) schlug SOGAR beide Stacking-Varianten. `JOSS_TECHNIQUE_WATCH.md`
  entsprechend aktualisiert (Prioritaet mittel -> niedrig nach diesem
  negativen n=1-Befund).

**Damit sind jetzt VIER von VIER Score-Hebel-Versuchen dieser Session
fuer s6e9 Nullbefunde** (Feature Engineering, Klassengewichtung,
AUC-Blend, negatives Stacking) - starkes Indiz, dass das Signal bei
diesem synthetischen Playground-Datensatz mit einem gut getunten
LightGBM bereits weitgehend ausgeschoepft ist. Commits: `98f08bf`
(zentral: JOSS_TECHNIQUE_WATCH.md + BACKLOG.md), `a9aa844`/`8153a6c`
(s6e9 lokal).

Nutzer entschied "das machen wir morgen" fuer die urspruenglich geplante
**Fehleranalyse-Vertiefung** (`147_error_analysis_ranger_confidence.R`/
`_isolation_forest.R`/`_kernelshap.R`/`_segments.R` - `_tabpfn.R` separat
zu bewerten) - EXPLIZIT VERSCHOBEN, nicht vergessen, naechster
konkreter Einstiegspunkt fuer s6e9.

**36. Aktualisierung (neuer Tag, "nun die Fehleranalyse")**: die auf
"morgen" verschobene Fehleranalyse-Vertiefung durchgefuehrt -
`147_error_analysis_ranger_confidence.R`/`_isolation_forest.R`/
`_kernelshap.R`/`_segments.R` (`_sanity_checks.R` war nie Teil des
Plans, `_tabpfn.R` bleibt offen).

- **confidence**: LDA rettet 62.2% von Rangers Fehlern, LightGBM nur
  4.5% - hoehere Fehler-Diversitaet trotz niedrigerer Einzel-AUC (LDA
  0.9353 vs. LightGBM 0.9413). Mitten in der Arbeit fragte der Nutzer
  "Greedy am besten fuer LDA im Ensemble?" - klargestellt, dass Greedy
  (149) BAcc-optimiert ist, nicht AUC (unsere Metrik), daher stattdessen
  `163_stacking_negative_weights.R` um LDA als 25. Kandidaten erweitert
  (aus dem 147-Artefakt, exakt derselbe Eval-Split wie der 148-Pool).
  **Erneuter Nullbefund**: weiterhin 0 negative Koeffizienten, bestes
  Einzelmodell (LightGBM, AUC 0.9427) schlaegt beide Stacking-Varianten
  (0.9417) - Fehler-Diversitaet uebersetzt sich hier nicht in AUC-Gewinn.
- **isolation_forest**: die 6.180 "alle drei falsch"-Faelle sind KEINE
  Feature-Raum-Ausreisser (Anomalie-Score sogar leicht niedriger als
  Baseline, p=1.3e-132) - genuin mehrdeutige Grenzfaelle, kein
  Datenqualitaetsproblem.
- **kernelshap**: Fehler haeufen sich ueberproportional bei den
  Features mit der GERINGSTEN Gesamtwichtigkeit (`City_Type` etc.,
  error_ratio 1.57-1.94x), waehrend die dominanten Treiber
  (`Subsidy_Available`, `Environmental_Concern_Level`) bei Fehlern fast
  neutral bleiben.
- **segments** (`segment_metric_cols` war leer, mit 5 kategorialen
  Spalten befuellt): **DER HAUPTFUND der gesamten Fehleranalyse.** Ohne
  verfuegbare Subsidy (`Subsidy_Available = "No"`, **37% der
  Eval-Zeilen!**) landen ALLE DREI Modellfamilien (LDA/LightGBM/Ranger)
  unabhaengig voneinander bei BAcc~0.50 - praktisch Zufallsniveau.
  Konvergentes Signal fuer echte irreduzible Unsicherheit in diesem
  Datenbereich (kein Modell-Bug), erklaert rueckblickend, warum ALLE
  Score-Hebel-Versuche dieser Session (Feature Engineering,
  Klassengewichtung, AUC-Blend, Stacking mit/ohne LDA) ins Leere liefen.

Anschliessende Nutzerfrage: "waere es sinnvoll, Features ohne Signal zu
entfernen, um Rauschen zu unterdruecken, oder fallen die im Baum eh
weg?" - `037_selected_features_cv.R` als ungeeignet erkannt (domaenenfremde,
bei s6e9 leere "selected"-Familie, kein LightGBM) - stattdessen neues,
gezieltes `164_low_signal_feature_removal.R`: LightGBM-CV ohne die 5
SHAP-schwaechsten Features. **Ergebnis**: AUC minimal schlechter
(0.9410 -> 0.9403, -0.0007), aber LogLoss besser (0.2343 -> 0.2299) und
Training 23% schneller (113s -> 87s). Bestaetigt die Nutzerintuition
weitgehend - LightGBM filtert Rauschen schon weitgehend selbst, kein
AUC-Gewinn durch manuelles Entfernen, aber ein vertretbarer
Zeit/Kalibrierungs-Tausch fuer andere Prioritaeten.

Commits: `46feebd`/`389a880` (Rausch-Feature-Test), `8221f4e`/`ad08609`
(Segmentmetriken-Hauptfund), `6fade18`/`96eaaff` (confidence/isolation_
forest + LDA-Nachtest) - alle zentral gepusht, s6e9 lokal (kein Remote).

**37. Aktualisierung ("TabPFN-Fehleranalyse probieren")**: letzter der
5 Fehleranalyse-Bausteine. **Kosten-Fund vorab**: `interesting_idx`
hatte 32.528 Zeilen - bei TabPFN-CPU-Inferenz mutmasslich mehrere
Stunden. Per AskUserQuestion 3 Optionen vorgelegt (Stichprobe
reduzieren/vollstaendig im Hintergrund/abbrechen) - Nutzer waehlte
"auf Stichprobe reduzieren". Neue Config `error_analysis_tabpfn_
query_sample_size` (Default 2000, No-op fuer kleinere Projekte) ZENTRAL
eingefuehrt (nicht nur lokal) - kappt `interesting_idx`
klassenstratifiziert per Zufall, `147_error_analysis_ranger_tabpfn.R`
entsprechend angepasst (na.rm=TRUE in den Rescue-Rate-Berechnungen).
Testsuite 359/359, CI gruen (Commit `ac507d9`).

**Ergebnis**: TabPFN rettet 61.3% von Rangers Fehlern (Stichprobe,
vergleichbar mit LDA 62.2%, deutlich mehr als LightGBM 4.5%) - erneut
das Muster "methodisch grundverschiedener Ansatz rettet mehr". Aber bei
den 6.180 "alle drei selbstsicher falsch"-Faellen nur 7.1% -
**unabhaengige Bestaetigung des Segmentmetriken-Hauptfunds** (Punkt 36):
selbst ein leistungsfaehiges Foundation-Model kommt bei den wirklich
harten Faellen kaum weiter, kein methodenspezifisches Problem, sondern
echte irreduzible Unsicherheit. Commits: `939eebf` (zentral), `0000b78`
(s6e9 lokal).

**Damit ist die Fehleranalyse-Vertiefung fuer s6e9 jetzt WIRKLICH
VOLLSTAENDIG abgeschlossen** (alle 5 Bausteine: confidence,
isolation_forest, kernelshap, segments, tabpfn - keine offene Option
mehr aus dem urspruenglichen Plan).

**38. Aktualisierung ("wir sollten eine zweite Submission erzeugen,
aehnlich gut wie die erste")**: Kaggle erlaubt 2 finale Submissions.
Kandidat `lightgbm_10` aus dem 148-Pool (wiederholt bestes Einzelmodell
in 163, Bestaetigungs-AUC 0.9427 - mit dem Vorbehalt, dass das nur eine
Holdout-Auswertung war) auf vollen Daten trainiert
(`165_train_predict_lightgbm10.R`) -> `submission_lightgbm10.csv`.
**Diversitaets-Check ergab: PRAKTISCH EIN NAHE-DUPLIKAT** der ersten
Submission (Korrelation 0.9983) - kaum Hedge-Wert. Auf Nutzerwunsch
("Ranger auch erzeugen") zusaetzlich `166_train_predict_ranger.R` ->
`submission_ranger.csv` (getunte Ranger-Konfiguration, strukturell
andere Modellfamilie) - Korrelation nur 0.9898, ~2.5x diverser.
**Empfehlung**: `submission.csv` + `submission_ranger.csv` fuer die 2
finalen Einreichungen (nicht die lightgbm_10-Variante). Commits:
`48b3b20` (zentral, docs-only), `60cff38` (s6e9 lokal, Skripte - die
Submission-CSVs selbst sind gitignored).

Nebenfrage des Nutzers: "die Submission hat sehr viele Nachkommastellen -
sind die sinnvoll?" - erklaert: statistisch nicht (R-Standard-Float-
Serialisierung, nicht echte Modellpraezision), aber irrelevant fuer AUC
(rangfolgebasiert) und deckungsgleich mit dem Format von Kaggles eigener
`sample_submission.csv` - kein Handlungsbedarf.

Nutzer teilte den Public-LB-Score der Ranger-Submission: **0.93829** -
in `experiments.db` geloggt (mconf_id `adf1f8d8-...`). Dabei ein echter
Fund: `090_ranger_tuning.R` lief SEIT DER UMSTELLUNG AUF DIE VOLLE
DATENMENGE (`edc6759`, 2026-09-01) NIE ERNEUT - die Ranger-Submission
nutzt Hyperparameter aus dem urspruenglichen 10%-Subset-Tuning
(anders als beim LightGBM, das explizit bei voller Groesse neu getunt
wurde, mit messbarer Verbesserung). Per AskUserQuestion 2 Optionen
vorgelegt (nur dokumentieren vs. neu tunen) - Nutzer waehlte **neu
tunen bei voller Datenmenge** (Empfehlung). `090_ranger_tuning.R`
laeuft im Hintergrund (~60-100 Min. Kostenschaetzung, 20 Suchevaluationen
+ 5-facher CV-Finalvergleich auf 668.665 Zeilen) - **Ergebnis noch
NICHT bekannt bei diesem Statusanker-Update, folgt als Nachtrag**.
Commit `3b613f9` (zentral, docs-only).

**Stand jetzt: EIN LAUFENDER HINTERGRUNDPROZESS** (`090_ranger_tuning.R`
bei voller Datenmenge) - Ergebnis bei Sessionende noch offen. Root-
Verzeichnis ist weiterhin fuer Docs UND Skripte deutlich uebersichtlicher
(36->11 `.md`-Dateien im Root, 114->83 `.R`-Dateien im Root); das
Aufraeum-Verfahren selbst ist als Skill wiederverwendbar dokumentiert.
Die komplette Fehleranalyse-Vertiefung fuer s6e9 ist abgeschlossen. 2
Submission-Optionen (LightGBM + Ranger) liegen bereit, eine davon
(Ranger) bereits mit LB-Score 0.93829 bestaetigt.

**39. Aktualisierung (Ergebnis des `090`-Neu-Tunings + Nutzerfrage zu
AutoML-Seminars, 2026-09-04/05)**: Ranger getunt bei voller Datenmenge
AUC 0.9388 vs. Default 0.9383 - bestaetigt, dass die Tuning-Luecke real
war, Gewinn aber klein. Nutzer fragte nach interessanten Inhalten von
youtube.com/@automlseminars4622/automl-seminars.github.io/talks -
Recherche fand ein direkt relevantes, begutachtetes Paper: [Reshuffling
Resampling Splits Can Improve Generalization of Hyperparameter
Optimization](https://arxiv.org/abs/2405.15393) (Nagler/Schneider/
Bischl/Feurer, NeurIPS 2024) - Kernbefund: ein je Tuning-Konfiguration
NEU gezogener Split generalisiert besser als ein fixer, wiederverwendeter
Split (v.a. bei Holdout, genau unser Suchphasen-Setup), ohne
Mehraufwand. Neues Prototyp-Skript `167_ranger_tuning_reshuffled.R`
(manuelle Zufallssuche, da mlr3tuning keinen "reshuffle je Evaluation"-
Modus hat) - Nutzer bestaetigte trotz stark nach oben korrigierter
Kostenschaetzung (Stunden statt Minuten) "trotzdem probieren". **Ergebnis:
kein messbarer Unterschied** (CV-AUC 0.938750 reshuffled vs. 0.938788
fixer Split) - plausibel durch den bei 668k Zeilen bereits sehr
stabilen Split erklaerbar (Paper-eigene Randbedingung). Commits:
`d57a069`/`2a96684` (zentral).

**40. Aktualisierung (Nutzerfrage "sollten wir die beiden Methoden bei
anderen Projekten probieren", Ensemble-Pilot ueber 2 Tage)**: Idee, die
Reshuffling- UND Ensemble-Diversitaets-Methode auf kleinen OpenML-
Datensaetzen zu testen (theoretisch aussagekraeftiger als bei s6e9s
668k Zeilen) - bei Erfolg Kandidat fuer einen Template-Backport
(ADR-003-Schwelle: >=2 unabhaengige Bestaetigungen). Setup-Infrastruktur
fuer kleine CC18-Projekte etabliert (fehlende Config-Variablen/
Helferfunktionen ergaenzt, `005_benchmark_runtime.R`/`090`/`147`/`148`/
`149`/`167`/`ensemble_selection.R`/`db_logging.R`/`db_schema.sql`/
`provenance.R` aus dem zentralen Template kopiert).

- **Reshuffling** (2 kleine Projekte: `ilpd`, `blood-transfusion`):
  BEIDE negativ (0.5906->0.5875; 0.6340->0.6290). Zusammen mit dem
  s6e9-Nullbefund jetzt **3/3 ohne Vorteil** - Technik nicht weiter
  verfolgt, kein Backport.
- **Ensemble-Pool**: erste 2 Projekte (ilpd +0.71pp, blood-transfusion
  +1.76pp) legten voreilig eine "kleine Datensaetze -> Ensemble hilft"-
  Faustregel nahe, in `REFERENZ_ENSEMBLE_SELECTION.md` dokumentiert
  (Commit `7b3aab7`). Nutzer bat NOCHMAL um Vorsicht ("2 weitere
  Projekte probieren") - `qsar-biodeg` (-0.72pp, `dresses-sales` scheiterte
  an LDA-Kollinearitaet und wurde ersetzt) und `eucalyptus` (-2.77pp,
  grosse Selektions-/Bestaetigungs-Luecke = Ueberanpassung bei nur 147
  Eval-Zeilen) KIPPTEN DAS BILD auf 2/4 positiv, 2/4 negativ - **Faustregel
  explizit zurueckgenommen und korrigiert** (Commit `63d03b2`, wichtige
  Lehre: n=2 reicht nie fuer eine Faustregel).
  
  Nutzer liess NOCHMAL 2 (`analcatdata-authorship`, `mice-protein` -
  beide Deckeneffekt BAcc=1.0, uninformativ) UND NOCHMAL 2 (`cmc` -2.02pp,
  `ozone-level-8hr` +0.84pp) und ABSCHLIESSEND NOCHMAL 2 (`sick` scheiterte
  an einer fast komplett fehlenden Spalte und wurde durch
  `mfeat-morphological` ersetzt, `mfeat-karhunen` - beide EXAKT
  IDENTISCH Einzelmodell=Ensemble) testen. **ENDGUELTIGES BILD (10
  Projekte)**: 3 positiv, 3 negativ, 4 kein Unterschied - Rauschen um
  Null, KEIN systematischer Ensemble-Nutzen. Pilot bewusst
  abgeschlossen (10 Projekte als ausreichend belastbar erachtet).
  **Endgueltige Konsequenz: KEIN Backport in den Standard-Workflow.**
  Commits: `d6c3395`, `e7089cb`, `db3a1f5` (zentral, alle docs-only).

**Methodische Randbeobachtung**: die Caruana-Greedy-Selection verhielt
sich in allen 4 "kein Unterschied"-Faellen korrekt (waehlte
Ensemblegroesse 1, statt unnoetig aufzublaehen) - spricht fuer die
Robustheit des Algorithmus selbst, auch wenn die Datensatzgroessen-
Frage negativ beantwortet wurde.

**Stand jetzt: kein offener Blocker, kein laufender Hintergrundprozess.**
s6e9 ist inhaltlich vollstaendig abgeschlossen (Submission + Ensemble-
Check + Trust-Gate-Diagnostik + Fehleranalyse + 2 zusaetzliche
Submissions, eine davon LB-bestaetigt). Reshuffling UND Ensemble-Pool-
Backport sind beide abschliessend NEGATIV beantwortet (je mit robuster
Mehrfach-Projekt-Evidenz) - keine weitere Untersuchung dieser beiden
Ideen geplant, ausser der Nutzer bringt neue Evidenz/einen neuen Ansatz.

**Empfohlener erster Schritt, Stand jetzt**: kein zwingender
Einstiegspunkt, kein offener Blocker (s6e9-Fehleranalyse inkl. TabPFN
ist bereits vollstaendig abgeschlossen, siehe Punkt 37). Naheliegende
Option, falls der Nutzer nichts Neues mitbringt: ein neues Kaggle-/
OpenML-Projekt, oder Aufraeumen der 10 Ensemble-Pilot-Projekt-Setups
in `ML_Learning` (temporaere Skript-Kopien, kein Loeschbedarf, aber
falls der Nutzer aufraeumen will).
