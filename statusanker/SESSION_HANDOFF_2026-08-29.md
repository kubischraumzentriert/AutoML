# Session Handoff (Stand 2026-08-29) - Statusanker

Vorheriger Anker: `statusanker/SESSION_HANDOFF_2026-08-28.md` (2.
Aktualisierung, deckte die komplette Phase-A-E-Roadmap des
2026-08-28-Bewertungsdokuments plus zwei Folgeschritte ab - Multiplier-
Nachpruefung, Ablationen A2+A3). Dieser Anker deckt alles ab, was SEIT
diesem Handoff passiert ist: der ueberfaellige zentrale Merge (inkl. 2
gefundener/gefixter Bugs), Backup-Aufraeumen, und die komplette
Bearbeitung von P0+P1+P2 aus einem NEUEN, dritten externen
Bewertungsdokument (2026-08-29). **3. Aktualisierung dieses Ankers:**
ergaenzt P2 (Level-2-Outer-Evaluation-Prototyp, vollstaendig auf allen 6
externen Datensaetzen ausgerollt).

## Repo-Zustand am Ende dieser Session

- `MLR3_Classifikation` @ `8bd8afc` "P2: Level-2-Prototyp auf alle 6
  externen Datensaetze ausgerollt" - gepusht, CI Smoke Test lief zuletzt
  fuer `7710cef` gruen (Lauf `33254940511`); Lauf fuer `8bd8afc` steht
  zum Zeitpunkt dieses Handoffs noch aus/wird ueberwacht.
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
  (nur die letzte, aktuelle blieb).
- **8 neue annotierte Git-Tags**: `backlog-central-merge-completed`,
  `backlog-2026-08-29-p0-evaluation-levels`,
  `backlog-p1-external-benchmark-frozen`,
  `backlog-p1-external-benchmark-executed`,
  `backlog-p1-fair-baselines-complete`, `backlog-p2-level2-prototype`,
  `backlog-p2-level2-full-rollout` (7 explizit benannte - insgesamt
  jetzt 24+ Tags im Repo).

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

## Offene Punkte fuer die naechste Session

**Aus der 2026-08-29-Bewertung/Roadmap bleibt nur noch P2 (2. Haelfte)
und P3 offen:**
- **P2, 2. Haelfte**: Evidence Registry finalisieren (redaktionelle
  Altinhalte aus `SYSTEMATIC_EVALUATION.md` strukturieren, langfristig
  manuelle Ergebnistabelle abschaffen). Der Level-2-Prototyp-Teil von P2
  ist bereits vollstaendig abgeschlossen (siehe Punkt 8 oben).
- **P3**: `finalize_run_provenance()` (alle verfuegbaren Hashes am Ende
  eines Runs automatisch ergaenzen, siehe die 2026-08-29-Bewertung
  Abschnitt 11), erster Paper-Rohentwurf.
- Optional, nicht dringend: pruefen, ob ein groesseres Tuning-Budget fuer
  Level 2 (aktuell 10 Evals/Arm) das gemischte Ergebnis veraendert -
  bislang nicht getestet.

**Keine dringenden Blocker.** Alles, was das 2026-08-29-Bewertungs-
dokument konkret als P0/P1/P2 (Level-2-Teil) spezifiziert hat, ist
umgesetzt.

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

Kein zwingender Einstiegspunkt. Falls der Nutzer nichts Konkretes
mitbringt: entweder P2s 2. Haelfte (Evidence-Registry-/
`SYSTEMATIC_EVALUATION.md`-Finalisierung) oder P3
(`finalize_run_provenance()`, guenstig) der neuen Roadmap angehen, oder
die tatsaechliche Publikations-Ausarbeitung anstossen (alle Bausteine -
Phase C, externes Benchmark-Set, faire Baselines, Level-2-Prototyp
(gemischtes/negatives Ergebnis), beide Ablationen, das eingefrorene
Protokoll - liegen jetzt bereit).
