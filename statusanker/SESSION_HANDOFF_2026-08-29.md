# Session Handoff (Stand 2026-08-29) - Statusanker

Vorheriger Anker: `statusanker/SESSION_HANDOFF_2026-08-28.md` (2.
Aktualisierung, deckte die komplette Phase-A-E-Roadmap des
2026-08-28-Bewertungsdokuments plus zwei Folgeschritte ab - Multiplier-
Nachpruefung, Ablationen A2+A3). Dieser Anker deckt alles ab, was SEIT
diesem Handoff passiert ist: der ueberfaellige zentrale Merge (inkl. 2
gefundener/gefixter Bugs), Backup-Aufraeumen, und die komplette
Bearbeitung von P0+P1 aus einem NEUEN, dritten externen
Bewertungsdokument (2026-08-29).

## Repo-Zustand am Ende dieser Session

- `MLR3_Classifikation` @ `501be7b` "P1 (fair baselines, protocol v2):
  reusable template + full results" - gepusht, CI Smoke Test gruen
  (Lauf `33253383429`).
- `ML_Learning` (rein lokal, kein Remote): 12 neue Projektordner
  (`openml-cc18-cmc`, `-optdigits`, `-sick`,
  `-analcatdata-authorship`, `-blood-transfusion`, `-ilpd` - je mit
  `020_task.R` via `mlr3oml` + Protokoll-v1- UND v2-Skripten), mehrere
  lokale Commits.
- `openml-credit-g` (lokale ML_Learning-DB) hatte ihre `proj_id`
  angeglichen (siehe Merge-Fix unten) - Backup vor der Aenderung
  angelegt.
- Zentrale `experiments.db` (`health_condition`-Projekt) vollstaendig
  gemergt (23 Classification-Quell-DBs), 4 Backup-Dateien geloescht
  (nur die letzte, aktuelle blieb).
- **6 neue annotierte Git-Tags**: `backlog-central-merge-completed`,
  `backlog-2026-08-29-p0-evaluation-levels`,
  `backlog-p1-external-benchmark-frozen`,
  `backlog-p1-external-benchmark-executed`,
  `backlog-p1-fair-baselines-complete` (5 explizit benannte - insgesamt
  jetzt 22+ Tags im Repo).

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

## Offene Punkte fuer die naechste Session

**Aus der 2026-08-29-Bewertung/Roadmap bleibt nur noch P2-P3 offen:**
- **P2**: Level-2-Outer-Evaluation prototypisieren (Modellwahl/Tuning/
  Threshold/Ensemble INNERHALB jedes Outer-Train-Splits statt eines
  festen Arm-Katalogs) + Evidence Registry finalisieren (redaktionelle
  Altinhalte aus `SYSTEMATIC_EVALUATION.md` strukturieren, langfristig
  manuelle Ergebnistabelle abschaffen). Deutlich teurer als P1 - jeder
  Outer-Fold wuerde eine komplette Kopie des Modellwahl-/Tuning-Prozesses
  durchlaufen.
- **P3**: `finalize_run_provenance()` (alle verfuegbaren Hashes am Ende
  eines Runs automatisch ergaenzen, siehe die 2026-08-29-Bewertung
  Abschnitt 11), erster Paper-Rohentwurf.

**Keine dringenden Blocker.** Alles, was das 2026-08-29-Bewertungs-
dokument konkret als P0/P1 spezifiziert hat, ist umgesetzt.

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
- Vollstaendiger Kontext: `BACKLOG.md` (jetzt mit P0-P3-, Phase-A-E- UND
  der kompletten 2026-08-29-P0/P1-Historie), `EVALUATION_LEVELS.md`,
  `EXTERNAL_BENCHMARK_SET.md`, `BENCHMARK_PROTOCOL.md` (jetzt v2),
  `outer_workflow_evaluation_v2_fair_baselines.R`, sowie weiterhin
  `TARGETS.md`/`AGENTS.md`/das persistente Gedaechtnis.

## Empfohlener erster Schritt der naechsten Session

Kein zwingender Einstiegspunkt. Falls der Nutzer nichts Konkretes
mitbringt: entweder P2 (Level-2-Outer-Evaluation, deutlich teurer -
Umfang vorher klaeren) oder P3 (`finalize_run_provenance()`, guenstiger)
der neuen Roadmap angehen, oder die tatsaechliche Publikations-
Ausarbeitung anstossen (alle Bausteine - Phase C, externes Benchmark-Set,
faire Baselines, beide Ablationen, das eingefrorene Protokoll - liegen
jetzt bereit).
