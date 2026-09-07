# Skript-Index: nicht-nummerierte Root-Skripte ohne bisherige Einzeldokumentation

Ergaenzt die knappe "Skript | Rolle"-Tabelle in `README_DETAILS.md`
(Abschnitt "Skriptstruktur") um die 15 Root-Skripte, die dort bislang
GAR NICHT auftauchten - gefunden bei einer Nutzeranfrage ("mir scheint
das nicht klar zu sein"), die zurecht Unuebersichtlichkeit im
Root-Verzeichnis bemaengelte. Scope bewusst auf diese 15 begrenzt
(Nutzerentscheidung, 2026-09-07) - die bereits in `README_DETAILS.md`
dokumentierten nummerierten Skripte und `analysis/*.R`-Dateien bleiben
bei ihrer knappen Ein-Zeilen-Rolle.

**Warum diese Skripte im Root bleiben (nicht in `analysis/` verschoben)**:
ADR-007 (flache Struktur) - die meisten hier sind Bibliotheksmodule, die
von nummerierten Pipeline-Skripten per `source("datei.R")`
(arbeitsverzeichnis-relativ) eingebunden werden; ein Verschieben wuerde
das ohne Anpassung jedes einzelnen aufrufenden Skripts brechen. Die 4
`outer_workflow_evaluation*.R`-Dateien sind zusaetzlich per ADR-008
eingefroren (siehe eigener Abschnitt unten).

Jeder Eintrag: **Beschreibung** (was das Skript/Modul macht) -
**Aufrufkontext** (wann/von wem es genutzt wird) - **Ergebnis/Nutzen**
(was es bisher gebracht hat, mit Verweis auf `BACKLOG.md` fuer Details)
- **Literaturreferenz** (falls zutreffend).

## Uebersicht

| Skript | Kurzbeschreibung |
|---|---|
| [`config_validation.R`](../../config_validation.R) | Prueft `000_config.R` auf innere Konsistenz (Tippfehler, unpassende Bereiche) |
| [`db_housekeeping.R`](../../db_housekeeping.R) | Rein lesende Diagnose der zentralen `experiments.db` vor einem Merge |
| [`decision_stability.R`](../../decision_stability.R) | Generischer Baustein: wie stabil ist eine kategoriale Entscheidung unter variierenden Seeds |
| [`decision_stability_level2_prototype.R`](../../decision_stability_level2_prototype.R) | Wendet `decision_stability.R` konkret auf die Level-2-Modellwahl an |
| [`ensemble_selection.R`](../../ensemble_selection.R) | Caruana-Greedy-Ensemble-Selection als eigenstaendige Funktion |
| [`evidence_registry.R`](../../evidence_registry.R) | Maschinenlesbare Befund-Registry (Ergaenzung zu BACKLOG.md/Statusankern) |
| [`generate_systematic_evaluation.R`](../../generate_systematic_evaluation.R) | Erzeugt eine Projekt-x-Modul-Ergebnistabelle aus der Evidence Registry |
| [`group_resampling.R`](../../group_resampling.R) | Group-aware Resampling fuer wiederholte Entitaeten (Patienten/Nutzer/Geraete) |
| [`hard_split_stress_test.R`](../../hard_split_stress_test.R) | Extrapolations-Stresstest per k-means-Cluster-Split |
| [`outer_workflow_evaluation.R`](../../outer_workflow_evaluation.R) | Eingefrorenes Benchmark-Protokoll, Ursprung (P1.1-Prototyp, nur health_condition) |
| [`outer_workflow_evaluation_template.R`](../../outer_workflow_evaluation_template.R) | Eingefrorenes Benchmark-Protokoll v1 (generalisiert fuer beliebige Projekte) |
| [`outer_workflow_evaluation_v2_fair_baselines.R`](../../outer_workflow_evaluation_v2_fair_baselines.R) | Eingefrorenes Benchmark-Protokoll v2 (+ getunte Baseline-Arme) |
| [`outer_workflow_evaluation_v3_level2.R`](../../outer_workflow_evaluation_v3_level2.R) | Eingefrorenes Benchmark-Protokoll v3 (echtes Level-2: Modellwahl+Tuning innerhalb jedes Outer-Splits) |
| [`provenance.R`](../../provenance.R) | SHA256-/Config-Hashes: was hat sich zwischen zwei Runs geaendert |
| [`target_leak_audit_helpers.R`](../../target_leak_audit_helpers.R) | Testbare Kernberechnungen aus `015_target_leak_audit.R` extrahiert |

## config_validation.R

**Beschreibung**: `validate_config()` prueft die zentralen
`000_config.R`-Werte auf innere Konsistenz - `target_col`/`id_col`/
`baseline_measure_ids`/`positive_class`/Multi-Label-Ratios/Split-
Anteile/`cv_folds`/`class_weight_power`/Modellnamen-Konsistenz
(`model_feature_sets` etc. muessen auf echte `base_learner_
constructors`-Eintraege verweisen)/`directional_expectation_specs`.
Sammelt ALLE Fehler in einem einzigen `stop()`, statt einzeln
nacheinander abzustuerzen.

**Aufrufkontext**: Manuell, NICHT automatisch von einem nummerierten
Skript aufgerufen - nach dem Anpassen von `000_config.R` fuer ein neues
Projekt: `source("config_validation.R"); validate_config()`.

**Ergebnis/Nutzen**: Faengt Tippfehler (z.B. "lgihtgbm" statt
"lightgbm" beim Uebertragen auf ein neues Projekt) und typische
Config-Fehler frueh ab, statt kryptischer Abstuerze tief in einem
nummerierten Skript.

**Literaturreferenz**: -

## db_housekeeping.R

**Beschreibung**: `db_housekeeping_check()` - REIN LESENDE Diagnose der
zentralen gemergten `experiments.db` gegen alle lokal auffindbaren
Projekt-DBs: fehlende Projekte (nie gemergt), neue ungemergte Runs,
moegliche Duplikate, unvollstaendige Runs (`run_finished_at IS NULL`),
Runs ohne Git-Commit, Backup-Uebersicht. `discover_source_db_paths()`
und `detect_problem_type()` (Aufgabentyp-Erkennung classification/
regression/mixed/unknown aus den geloggten Metrik-Praefixen
`classif.`/`regr.`) sind hierher aus `merge_project_experiments.R`
verschoben (nicht dupliziert) - Letzteres sourced diese Datei jetzt.

**Aufrufkontext**: Manuell, typischerweise VOR einem
`merge_project_experiments.R`-Lauf, um zu pruefen, ob ueberhaupt ein
Merge noetig ist und ob die Quell-DBs sauber sind.

**Ergebnis/Nutzen**: Verhindert, dass ein Classification-Merge
versehentlich ein Regression-Projekt aufnimmt (oder umgekehrt) - reine
lesende Abfrage, aendert nie eine DB.

**Literaturreferenz**: -

## decision_stability.R

**Beschreibung**: `decision_stability_report()` - generischer Baustein:
wiederholt eine BELIEBIGE kategoriale Entscheidungsfunktion
(`function(seed) -> Entscheidung`) unter variierenden Seeds und meldet,
wie stabil die Mehrheitsentscheidung ist (Default-Schwelle 70%
Uebereinstimmung, sonst "AUFFAELLIG/fragil"). Beantwortet NICHT "wie
schwankt der Score" (das macht `seed_stability.R`), sondern "haette
eine leicht andere, ebenso plausible Ausgangslage dieselbe
KATEGORIALE Entscheidung ergeben".

**Aufrufkontext**: Von `decision_stability_level2_prototype.R`
aufgerufen (konkrete Anwendung: Level-2-Modellwahl); als generischer
Baustein fuer jede kuenftige kategoriale Workflow-Entscheidung
wiederverwendbar (Modellwahl, Ensemble-Mitgliedschaft,
Feature-Auswahl-Cutoff, ...).

**Ergebnis/Nutzen**: Angewendet auf bis zu 15 externe CC18-Datensaetze
(n=6->10->15, siehe `BACKLOG.md`) - durchgehend NULLBEFUND (Spearman
rho -0.086 bis -0.147 zwischen Stabilitaet und Level-2-Erfolg, nicht
signifikant ueber 3 unabhaengige Erweiterungsschritte). Kein Backport
als eigenstaendiges nummeriertes Pipeline-Skript (ADR-003) - das Modul
selbst bleibt als generischer, bereits getesteter Baustein im Template.

**Literaturreferenz**: VeridicalFlow/PCS-Rahmenwerk (Predictability,
Computability, Stability), Duncan et al. 2022, JOSS
[10.21105/joss.03895](https://doi.org/10.21105/joss.03895).

## decision_stability_level2_prototype.R

**Beschreibung**: Wendet `decision_stability_report()` auf die
konkreteste, bereits instrumentierte kategoriale Entscheidung des
Templates an: welcher Kandidat (Ranger/LightGBM/Ensemble) beim
Level-2-Protokoll (`outer_workflow_evaluation_v3_level2.R`) fuer einen
gegebenen Outer-Fold gewinnt. Outer-Train bleibt FIX (identisch zum
eingefrorenen Protokoll v3), nur der Inner-Split-Seed variiert je
Wiederholung.

**Aufrufkontext**: Manuell, Outer-Fold per Umgebungsvariable
`DECISION_STABILITY_OUTER_FOLD` steuerbar (Default 1) - fuer die
n=6->10->15-Erweiterung wurde derselbe Fold ueber alle Datensaetze
hinweg verwendet, fuer "Weg A" (mehr Folds statt mehr Datensaetze)
Fold 2/3 zusaetzlich.

**Ergebnis/Nutzen**: Siehe `decision_stability.R` - Teil des
durchgehenden Nullbefunds ueber alle 15 Datensaetze.

**Literaturreferenz**: siehe `decision_stability.R`.

## ensemble_selection.R

**Beschreibung**: `greedy_ensemble_selection()` - Caruana-Greedy-
Ensemble-Selection als eigenstaendige, testbare Funktion (extrahiert
aus `149_ensemble_selection.R`, 2026-08-19, Anlass: externes Review
bemaengelte fehlende Testbarkeit). Waehlt iterativ MIT Zuruecklegen den
Kandidaten, dessen Hinzunahme zum laufenden Wahrscheinlichkeits-Mittel
die Zielmetrik am staerksten erhoeht. Unterstuetzt sowohl Multiclass-
BAcc (Default, ueber `class_names`) als auch eine eigene `metric_fn`
(z.B. binaeres AUC).

**Aufrufkontext**: Von `149_ensemble_selection.R` und
projektlokalen Varianten (z.B. `163_stacking_negative_weights.R` in
`PredictingElectricVehiclePurchases-s6e9`) aufgerufen - IMMER mit
getrennter Selektions-/Bestaetigungsmenge (Aufgabe des Aufrufers).

**Ergebnis/Nutzen**: An mehreren Datensaetzen als Mechanismus
bestaetigt (siehe `REFERENZ_ENSEMBLE_SELECTION.md`). Im 2026-09-05/06-
Pilot ueber 10 kleine OpenML-Datensaetze ABER **kein systematischer
Vorteil** gegenueber dem besten Einzelmodell gefunden (3 positiv/3
negativ/4 kein Unterschied - Rauschen um Null) - eine anfaengliche
"kleine Datensaetze -> Ensemble hilft"-Faustregel wurde nach
Erweiterung explizit zurueckgenommen. Bei `PredictingElectricVehicle
Purchases-s6e9` (668k Zeilen) ebenfalls kein Gewinn. Bleibt ein
optionales, PROJEKTWEISE zu verifizierendes Diagnoseskript, keine
automatische Empfehlung mehr.

**Literaturreferenz**: Caruana et al. 2004 (wie in Auto-sklearn
verwendet).

## evidence_registry.R

**Beschreibung**: `db_log_evidence()` - maschinenlesbare Ergaenzung zu
`TARGETS.md`/`BACKLOG.md`/Statusankern: loggt einen strukturierten
Befund (Rolle `score_lever`/`trust_gate`/`workflow_automation`/
`documentation`, Status `confirmed`/`core_finding`/`neutral`/
`negative`/`not_applicable`/`open`) in die `evidence`-Tabelle
(`db_schema.sql`). Bewusst UNABHAENGIG vom project/workflow/run-
Beziehungsgeflecht in `db_logging.R` - ein Befund bezieht sich oft auf
eine ganze Roadmap-Frage ueber mehrere Projekte/Laeufe hinweg, nicht
auf einen einzelnen mlr3-Lauf.

**Aufrufkontext**: Von vielen Analyse-/Evidenz-Skripten aufgerufen,
u.a. den projektlokalen `log_*_evidence.R`-Einmalskripten.

**Ergebnis/Nutzen**: Schritt 1 eines 3-Schritte-Plans ("nur neue
Befunde strukturiert loggen" -> "wichtige historische Befunde
nachziehen" -> "`SYSTEMATIC_EVALUATION.md` automatisch erzeugen", siehe
`generate_systematic_evaluation.R` fuer Schritt 3). Nur Schritt 1
umgesetzt, Schritt 2 bewusst nicht (waere ein eigener, deutlich
groesserer Arbeitsschritt).

**Literaturreferenz**: -

## generate_systematic_evaluation.R

**Beschreibung**: Erzeugt `docs/research/SYSTEMATIC_EVALUATION_
GENERATED.md` (Projekt-x-Modul-Pivot-Tabelle mit Symbolen ✓/✓✓/~/✗/—/?)
AUS der Evidence Registry, statt sie manuell zu pflegen. Ueberschreibt
BEWUSST NICHT die handgepflegte `docs/research/SYSTEMATIC_EVALUATION.md`
- die hat redaktionellen Mehrwert (Fussnoten, Korrekturvermerke,
Diskussionsabschnitte), den eine reine DB-Pivot-Tabelle nicht
reproduzieren kann.

**Aufrufkontext**: Manuell, on-demand.

**Ergebnis/Nutzen**: Demonstriert, dass die Registry die Tabelle
reproduzieren KANN (das eigentliche Akzeptanzkriterium); die generierte
Tabelle ist bereits AKTUELLER als die manuelle Datei (deckt z.B. das
Modul `outer_workflow_evaluation` aus Phase C ab, das die manuelle
Datei zum Erstellungszeitpunkt noch nicht kannte) - konkreter Beleg
fuer den Wert der Registry.

**Literaturreferenz**: -

## group_resampling.R

**Beschreibung**: `set_group_role()`/`diagnose_group_cv()`/
`test_group_significance()`/`scan_group_candidates()` - generischer
Baustein fuer Group-aware Resampling (dieselbe Entitaet in mehreren
Zeilen, Ziel: Generalisierung auf NEUE Entitaeten - neue Patienten/
Nutzer/Geraete/Molekuele). Zufaellige CV memoriert die Entitaet und
UEBERSCHAETZT massiv. `test_group_significance()` erkennt automatisch,
ob der Zielwert numerisch (eta²-Permutationstest) oder kategorial
(Cramer's V, Chi-Quadrat-basiert) ist.

**Aufrufkontext**: Bei Verdacht auf wiederholte Entitaeten im
Datensatz (Panel-/Longitudinal-Daten) - Diagnose vor der eigentlichen
Modellierung.

**Ergebnis/Nutzen**: Backportiert aus MLR3_Regression (dort laenger
etabliert), an 2 unabhaengigen Klassifikationsprojekten bestaetigt
(ADR-003 erfuellt): `openml-eeg-eye-state-timeseries` (Random-CV BAcc
0.930 vs. Block-CV BAcc 0.717) und `uci-parkinsons-voice-groupcv`
(Random-CV BAcc 0.804 vs. Group-CV BAcc 0.568) - beide Male eine
massive Ueberschaetzung durch normale CV.

**Literaturreferenz**: siehe `docs/reference/REFERENZ_GROUP_AWARE_CV.md`
fuer die volle Herleitung/Zahlen.

## hard_split_stress_test.R

**Beschreibung**: `cluster_based_hard_split()`/
`hard_split_stress_test()` - Extrapolations-Stresstest: k-means-
Clusterung auf den numerischen Features, das KLEINSTE Cluster wird als
Test-Set gehalten, der Rest ist Training. Vergleich des resultierenden
Scores gegen einen Referenzbereich aus zufaelligen Holdout-Splits
GLEICHER Testgroesse (z-Score-Muster wie `generalization_gap.R`, |z| >
2 = auffaellig). Erweitert um `class_proportion_shift()` -
unterscheidet echtes Extrapolationsrisiko von einem verdeckten
Class-Holdout (Test-Cluster besteht fast nur aus 1-2 im Training kaum
vorkommenden Klassen).

**Aufrufkontext**: Von `137_hard_split_stress_test.R` aufgerufen - Teil
der nummerierten Pipeline (Backport vollzogen, ADR-003 erfuellt).

**Ergebnis/Nutzen**: An 7 Datensaetzen bestaetigt (4/6 CC18-Datensaetze
klar auffaellig, u.a. `optdigits` mit z=-157.67 - extremer Ausreisser,
spaeter als verdeckter Class-Holdout diagnostiziert). Bei
`PredictingElectricVehiclePurchases-s6e9` (2026-09-03) angewendet:
z=-2.42 (AUFFAELLIG), aber kleiner absoluter Effekt (0.0011 AUC-Punkte)
- mildes, aber echtes Extrapolationsrisiko bei strukturell neuen
Kundensegmenten.

**Literaturreferenz**: astartes, Burns et al. 2023, JOSS
[10.21105/joss.05996](https://doi.org/10.21105/joss.05996).

## outer_workflow_evaluation*.R (4 Dateien - ADR-008-eingefroren)

**WICHTIG**: diese 4 Dateien duerfen NIE inhaltlich veraendert werden
(ADR-008) - bereits berichtete Deltas (z.B. "+4.9 BAcc-Punkte gegenueber
Default" fuer `openml-credit-g`) haengen an ihnen als feste Zahlen. Eine
Verbesserung/Erweiterung bekommt IMMER eine neue Version (neue Datei),
nie ein Edit der bestehenden.

**Beschreibung**: alle 4 beantworten dieselbe Grundfrage - wie gut
generalisiert der TATSAECHLICH gelebte Workflow (nicht nur ein
Einzelmodell) auf echte Outer-Test-Folds, die nie von einer inneren
Entscheidung (Tuning, Multiplier-Suche, Modellwahl) beruehrt wurden -
mit wachsendem Protokoll-Umfang:

- **`outer_workflow_evaluation.R`** (Ursprung, P1.1-Prototyp): NUR
  `health_condition` (Template-eigenes Projekt), 3 Outer-Folds, 4 Arme
  (`ranger_default`/`lightgbm_default`/`lightgbm_tuned`/
  `workflow_ranger`).
- **`outer_workflow_evaluation_template.R`** (Protokoll v1):
  generalisiert fuer beliebige Projekte - Scoring ueber beliebige
  Primaermetrik statt hartkodiertem BAcc, `lightgbm_tuned`-Arm
  weggelassen (zeigte im Original keinen Vorteil, teuerster Arm).
- **`outer_workflow_evaluation_v2_fair_baselines.R`** (Protokoll v2):
  +2 GETUNTE Baseline-Arme (`tuned_ranger`/`tuned_lightgbm`, AutoTuner
  auf Inner-Holdout(0.75) im Outer-Train) + `best_single_tuned_model`
  (Auswahl nach INNEREM Validierungswert, nie nach Outer-Test).
- **`outer_workflow_evaluation_v3_level2.R`** (Protokoll v3): echtes
  Level 2 - Modellwahl UND Hyperparameter-Tuning laufen INNERHALB jedes
  Outer-Train-Splits (Inner-Split 75/25, Ranger+LightGBM+Mini-Ensemble
  als Kandidaten, Gewinner nach innerem Score, Multiplier-Korrektur je
  Kandidat).

**Aufrufkontext**: Manuell, je Projekt fuer die Benchmark-Protokoll-
Historie (typischerweise beim Aufbau eines neuen externen
Vergleichsdatensatzes, siehe `extend-benchmark-set`-Skill).

**Ergebnis/Nutzen**: Belegte, mehrfach zitierte Deltas (z.B. "+4.9
BAcc-Punkte gegenueber Default" fuer `openml-credit-g`) - siehe
`docs/research/BENCHMARK_PROTOCOL.md`/`BACKLOG.md` fuer die vollstaendigen
Zahlen je Protokoll-Version und Datensatz.

**Literaturreferenz**: -

## provenance.R

**Beschreibung**: `sha256_file()`/`hash_value()`/
`capture_run_provenance()`/`finalize_run_provenance()` - Experiment-/
Daten-Provenienz: SHA256-Hash der Trainings-/Testdaten, Config-Hash
(gehasht statt Klartext geloggt - kann sensible lokale Pfade
enthalten), Resampling-Hash, R-Version/Paketreferenz. Baut auf der
BESTEHENDEN `run_config`-EAV-Tabelle auf (`db_logging.R`) statt eines
neuen Schemas. Git-Commit ist bereits separat ueber `run_git_commit`
abgedeckt, hier nicht dupliziert.

**Aufrufkontext**: Opt-in je Skript (`log_baseline_provenance = TRUE`-
Parameter in `db_logging.R`'s Logging-Helfern) - bislang nur
`030_baseline.R` als Referenzimplementierung, Ausrollen auf weitere
Skripte ist ein offener, optionaler Punkt.

**Ergebnis/Nutzen**: Beantwortet "was hat sich zwischen zwei Runs
geaendert?" (Daten/Config/Environment), ohne sensible Pfade im Klartext
zu speichern - jeder Parameter ist optional, `NULL` heisst "hier nicht
anwendbar", kein Fehler.

**Literaturreferenz**: -

## target_leak_audit_helpers.R

**Beschreibung**: `compute_determinism()` und 2 weitere, eigenstaendig
testbare Kernberechnungen (kumulative Schwelle, Cluster-Erkennung) -
aus `015_target_leak_audit.R` extrahiert (P0-Testabdeckung, KEINE
Verhaltensaenderung). `compute_determinism()` misst P(Ziel=Wert |
Feature=Wert) fuer eine niedrig-kardinale Spalte - eine sehr hohe
"purity" (Feature bestimmt das Ziel fast deterministisch) ist ein
Leak-Verdachtsmoment.

**Aufrufkontext**: Von `015_target_leak_audit.R` aufgerufen.

**Ergebnis/Nutzen**: Regressionsgetestet mit synthetischem Ground Truth
(bekannte Positiv-/Negativ-Faelle); real bestaetigt an mehreren
Projekten (road-accident-risk, bike-sharing, lending-club - Letzteres
mit dem bekannten Befund BAcc 0.998 -> 0.53 nach Entfernen des
Leak-Features, siehe `project_target_leak_audit`-Notiz im persoenlichen
Gedaechtnis). Der volle Mechanismus (warum Determinismus/kumulative
Schwelle/Cluster-Erkennung einen Leak anzeigen) ist in `README.md`
("Target-Leakage-Audit") beschrieben - hier nur die drei testbaren
Kernberechnungen.

**Literaturreferenz**: -
