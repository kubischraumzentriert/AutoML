# Skript-Index: nicht-nummerierte Root-Skripte ohne bisherige Einzeldokumentation

Ergaenzt die knappe "Skript | Rolle"-Tabelle in `README_DETAILS.md`
(Abschnitt "Skriptstruktur") um Root-Skripte, die dort bislang GAR NICHT
mit einer EIGENEN Tabellenzeile auftauchten - gefunden bei einer
Nutzeranfrage ("mir scheint das nicht klar zu sein"), die zurecht
Unuebersichtlichkeit im Root-Verzeichnis bemaengelte. Urspruenglicher
Scope: 15 Skripte (Nutzerentscheidung, 2026-09-07), per lockerem
Substring-Grep gefunden. Der Nutzer wies direkt danach auf eine LUECKE
in dieser Pruefung hin (`univariate_drift.R` fehlte, obwohl NICHT
dokumentiert - nur *erwaehnt* in der `115`-Zeile) - eine verschaerfte
Pruefung (Zeilenanfang `| \`datei.R\`` statt beliebiger Fundstelle)
foerderte 11 weitere echte Luecken zutage, siehe unten "Nachtrag
2026-09-07". Die bereits in `README_DETAILS.md` dokumentierten
nummerierten Skripte und `analysis/*.R`-Dateien bleiben bei ihrer
knappen Ein-Zeilen-Rolle.

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
| [`provenance.R`](../../provenance.R) | SHA256-/Config-Hashes und R/renv-JSON-Manifeste: was hat sich zwischen zwei Runs geaendert |
| [`target_leak_audit_helpers.R`](../../target_leak_audit_helpers.R) | Testbare Kernberechnungen aus `015_target_leak_audit.R` extrahiert |
| [`class_multiplier_tuning.R`](../../class_multiplier_tuning.R) | Metrik-optimale Klassen-Multiplikatoren (Grid + `1/prior` + Nelder-Mead), von `130_threshold_tuning.R` genutzt |
| [`db_logging.R`](../../db_logging.R) | Zentrale `experiments.db`-Logging-Helfer (EAV-Schema plus JSON-Manifeste) |
| [`generalization_gap.R`](../../generalization_gap.R) | Formale Generalisierungsluecke (CV- vs. Bootstrap-Verteilung + Baseline-Referenzbereich), von `136_generalization_gap.R` genutzt |
| [`learning_curve.R`](../../learning_curve.R) | Lernkurve (Score vs. Trainingsgroesse, algorithmusabhaengig), von `023_learning_curve.R` genutzt |
| [`merge_project_experiments.R`](../../merge_project_experiments.R) | Konsolidiert lokale Projekt-`experiments.db`-Dateien inkrementell in die zentrale Template-DB |
| [`multilabel.R`](../../multilabel.R) | Multi-Label-Klassifikation (Binary Relevance), von `021_multilabel_workflow.R` genutzt |
| [`ordinal_qwk.R`](../../ordinal_qwk.R) | Ordinale Ziele + Quadratic Weighted Kappa (Regression + QWK-optimales Runden), optionales Modul |
| [`sanity_checks.R`](../../sanity_checks.R) | Drei Modell-Sanity-Checks (Perturbation/Invarianz/Directional Expectation), von `147_error_analysis_ranger_sanity_checks.R` genutzt |
| [`seed_stability.R`](../../seed_stability.R) | Seed-/Hyperparameter-Rausch-Stabilitaet bei fixem Split, von `092_seed_stability.R` genutzt |
| [`split_size_sensitivity.R`](../../split_size_sensitivity.R) | Prueft, ob der gewaehlte Split-Anteil selbst stabil ist, von `022_split_size_sensitivity.R` genutzt |
| [`univariate_drift.R`](../../univariate_drift.R) | Univariate statistische Drift-Tests (KS/Chi², BH-korrigiert), von `115_adversarial_validation.R` genutzt |

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
`capture_run_provenance()`/`finalize_run_provenance()` plus
`capture_reproducibility_manifest()` - Experiment-/Daten-Provenienz:
SHA256-Hash der Trainings-/Testdaten, Config-Hash (gehasht statt
Klartext geloggt - kann sensible lokale Pfade enthalten), Resampling-
Hash, R-Version/Paketreferenz. Die aeltere Provenienz nutzt weiter die
`run_config`-EAV-Tabelle; fuer variable, projektspezifische Metadaten
liefert das Modul zusaetzlich JSON-Manifeste fuer `run_manifest_json`,
`mconf_manifest_json` und `subm_manifest_json`.

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

## Nachtrag 2026-09-07: 11 weitere Skripte

Der urspruengliche Vollstaendigkeits-Check (`grep -q "\`$f\`" README_
DETAILS.md`, lockerer Substring-Match "kommt der Dateiname IRGENDWO im
Text vor") hatte einen systematischen Fehler: er zaehlte ein Skript
bereits als "dokumentiert", wenn es nur BEILAEUFIG innerhalb der
Beschreibung eines anderen Skripts erwaehnt wird (z.B. `univariate_
drift.R` in der `115_adversarial_validation.R`-Zeile), statt eine
EIGENE Tabellenzeile/einen eigenen Abschnitt zu haben. Ein verschaerfter
Check (`grep -q "^| \`$f\`"`, Dateiname muss eine Tabellenzeile
EROEFFNEN) foerderte 11 echte weitere Luecken zutage. (3 weitere
Alarme des verschaerften Checks - `outer_workflow_evaluation_
template.R`/`_v2_fair_baselines.R`/`_v3_level2.R` - sind falsch-positiv:
die 4 Dateien teilen sich bewusst EINE gemeinsame Tabellenzeile/einen
gemeinsamen Abschnitt, siehe oben. `_targets.R` ist ebenfalls
falsch-positiv - hat einen eigenen dedizierten Abschnitt "`targets`-
Pipeline" in `README_DETAILS.md`, keine Tabellenzeile noetig.)

Anders als bei den ersten 15: alle 11 hier sind Bibliotheksmodule, die
bereits von genau EINEM nummerierten Pipeline-Skript per `source()`
eingebunden werden UND deren Rolle bereits (knapp, inline) in dessen
`README_DETAILS.md`-Zeile beschrieben ist - die Luecke ist also eher
"kein eigener Anker/keine eigene Vertiefung" als "komplett unbekannt".

## class_multiplier_tuning.R

**Beschreibung**: `apply_class_multipliers()`/Such-Routine fuer
metrik-optimale Klassen-Multiplikatoren bei schwellenwert-ABHAENGIGEN
Multiklassen-Metriken (v.a. Balanced Accuracy): skaliert vorhergesagte
Klassen-Wahrscheinlichkeiten mit klassenweisen Faktoren vor `argmax`
(`argmax(prob * multiplier)`) - Verallgemeinerung des binaeren
Threshold-Tunings auf K Klassen. Drei Startpunkte kombiniert: GRID
(`seq(0.5, 6, by=0.5)`, robuster Startpunkt), geschlossene `1/prior`-
Korrektur (Bayes-optimale Regel bei kalibrierten Wahrscheinlichkeiten,
tuning-frei) und kontinuierliche Nelder-Mead-Verfeinerung ab dem besten
der beiden (kann per Konstruktion nie schlechter werden als das
Grid-/Prior-Optimum).

**Aufrufkontext**: Von `130_threshold_tuning.R` aufgerufen.

**Ergebnis/Nutzen**: Bestaetigt an s6e7/health_condition (3-Klassen/
BAcc, OOF): raw argmax 0.872 -> Grid 0.936 -> `1/prior` 0.943 ->
kontinuierlich 0.945 (Grid rannte in seine Obergrenze 6/6). Entstand aus
der Beobachtung, dass die urspruenglich in `130` fest verdrahtete
Grid-Suche bei stark unbalancierten Zielen regelmaessig an ihre
Obergrenze stiess.

**Literaturreferenz**: -

## db_logging.R

**Beschreibung**: Zentrale Logging-Helferfunktionen fuer die
`experiments.db` (SQLite, EAV-Schema `project` -> `workflow` -> `run`
-> `model_config` -> `hyperparam`/`metric_result`, siehe
`db_schema.sql`). Unterscheidet schwellenwertunabhaengige Metriken
(AUC, LogLoss - Post-hoc-Threshold-Tuning hat KEINEN Effekt darauf) von
schwellenwertabhaengigen (BAcc, MCC, F1 - profitieren stark davon).
Ergaenzend zu festen Spalten und Key-Value-Tabellen serialisiert
`db_manifest_to_json()` variable R-Listen als valides JSON und migriert
bestehende SQLite-Dateien automatisch um die Manifest-Spalten.

**Aufrufkontext**: Von praktisch allen nummerierten Skripten
gesourct/genutzt, sobald ein Lauf in die zentrale DB geloggt werden
soll (opt-in je Skript).

**Ergebnis/Nutzen**: Rein additiv und projektunabhaengig aufgebaut -
ein neues Kaggle-Projekt braucht nur einen neuen `project_name` in
`000_config.R`, das Schema/`db_logging.R` selbst bleiben unveraendert.
Traeger fuer `merge_project_experiments.R`/`db_housekeeping.R`
(Konsolidierung ueber Projekte hinweg) und `provenance.R` (R-/renv-,
Daten-, Modell- und Submission-Provenienz).

**Literaturreferenz**: -

## generalization_gap.R

**Beschreibung**: Formale Quantifizierung der Generalisierungsluecke
(CV-/Train-Score vs. Score auf unberuehrten Daten): statistischer
Vergleich (Mann-Whitney U, robust bei kleinem n) + Effektgroesse
(Cohen's d) gegen einen Referenzbereich aus mehreren UNGETUNTEN
Baseline-Algorithmen. Getrennt von `target_leak_audit_helpers.R`:
dort Feature-Target-Leakage, hier Train/Test-Grenz-Optimismus
("Winner's-Curse"-Effekt einer Hyperparameter-Suche).

**Aufrufkontext**: Von `136_generalization_gap.R` aufgerufen, nach
`090`/`100` (baut auf deren Tuning-Instanzen als Kandidaten auf).

**Ergebnis/Nutzen**: Formalisiert, was zuvor ad-hoc als "CV<->LB-Luecke
gross/klein?" beurteilt wurde (siehe `REFERENZ_ENSEMBLE_SELECTION.md`,
s6e8-Notizen) - liefert einen statistischen Test statt eines
Bauchgefuehls.

**Literaturreferenz**: Jason Brownlee, "Data Science Diagnostic
Checklist", Abschnitte 5+6 - siehe `docs/reference/
REFERENZ_GENERALIZATION_GAP.md` fuer den vollen Abgleich der Checkliste
gegen den Template-Stand.

## learning_curve.R

**Beschreibung**: Lernkurve - prueft, ob mehr Trainingsdaten den Score
noch spuerbar verbessern wuerden, oder ob die gewaehlte Stichprobe
(`subset_fraction`) bereits ausreicht. ANDERS als `split_size_
sensitivity.R`: das Ergebnis haengt direkt von der KAPAZITAET des
Algorithmus ab (ein Baum plateaut frueh, ein Ensemble/Boosting kann
noch steigen) - laeuft deshalb mit dem tatsaechlich eingesetzten
Algorithmus (Ranger), nicht mit einem billigen Stellvertreter. Je
Trainingsgroesse: Validierungsscore per einmaliger k-facher CV (Trend,
nicht Streuung) + Trainingsscore, gemittelt ueber mehrere Wiederholungen
je Groesse (Rauschunterdrueckung).

**Aufrufkontext**: Von `023_learning_curve.R` aufgerufen, laedt bewusst
den vollen Datensatz (nicht `task_train_small`), gekappt bei
`learning_curve_max_rows`.

**Ergebnis/Nutzen**: Meldet "NOCH STEIGEND" als Warnung (kein
Abbruchgrund), dass Modellvergleiche/Hyperparameter-Entscheidungen
davor mit dem Vorbehalt zu lesen sind, dass sich die Algorithmen-
Rangfolge bei mehr Daten theoretisch noch verschieben koennte.

**Literaturreferenz**: Jason Brownlee, "Data Science Diagnostic
Checklist", Abschnitt 11 ("Learning Curve Tests").

## merge_project_experiments.R

**Beschreibung**: Konsolidiert die projekteigenen `experiments.db`-
Dateien mehrerer abgeschlossener Kaggle-/OpenML-Projekte in die
zentrale Template-Datenbank (Auto-Discovery unter `R_Workspace`/
`ML_Learning`), damit sich projektuebergreifende Muster per SQL
abfragen lassen statt nur in README-/`TEMPLATE_FRICTION.md`-Prosa.
Bewusst NUR die AGGREGIERTEN Tabellen (project/workflow/run/
run_config/model_config/resampling/hyperparam/metric_result) - NICHT
`prediction`/`prediction_prob` (Zeilenebene ist projektspezifisch,
nicht sinnvoll uebergreifend vergleichbar). `discover_source_db_paths()`/
`detect_problem_type()` liegen inzwischen in `db_housekeeping.R` (dort
gesourct, nicht dupliziert).

**Aufrufkontext**: Manuell, on-demand, INKREMENTELL (neue lokale Runs
werden bei jedem Aufruf nachgezogen, nicht nur beim ersten Merge eines
Projekts - siehe `TARGETS.md`, "Merge-Skript-Bug", 2026-08-14).
Typischerweise nach `db_housekeeping_check()` als Vorab-Diagnose.

**Ergebnis/Nutzen**: Ermoeglicht projektuebergreifende SQL-Abfragen
(z.B. "wie oft schlaegt Tuning den Default tatsaechlich", "AUC- vs.
BAcc-Projekte im Vergleich") ueber alle jemals gemergten Projekte
hinweg.

**Literaturreferenz**: -

## multilabel.R

**Beschreibung**: Generische Bausteine fuer Multi-Label-Klassifikation
(mehrere nicht-exklusive Zielspalten, anders als Multiclass) per
Binary Relevance (N unabhaengige Binaerklassifikatoren) - Standardweg,
da weder mlr3 noch CRAN ein natives Multi-Label-Paket haben (geprueft
2026-08-13/14). Schwellenwert je Label auf ROHER Accuracy getunt
(NICHT BAcc - verschlechtert sonst Hamming Loss/Subset Accuracy).

**Aufrufkontext**: Von `021_multilabel_workflow.R` aufgerufen, opt-in
ueber `label_cols` statt `target_col` in `000_config.R` - Default
`label_cols <- character(0)` (rueckwirkungsfrei bei leerem Wert).

**Ergebnis/Nutzen**: Verifiziert an 4 unabhaengigen Standalone-Projekten
(kein Git): `openml-yeast-multilabel` (14 Labels), `openml-scene-
multilabel` (6 Labels, Bild), `openml-birds-multilabel` (19 Labels,
gemischte Feature-Typen), `tox21-multilabel` (12 Labels, echte fehlende
Labels/NA-Maskierung) - Binary Relevance + Accuracy-Threshold 3/3
bestaetigt bester Ansatz.

**Literaturreferenz**: siehe `docs/reference/
REFERENZ_METRIC_TARGET_MISMATCH.md` fuer die vollen Zahlen.

## ordinal_qwk.R

**Beschreibung**: Bausteine fuer ordinale Ziele (geordnete Klassen,
z.B. Ratings) mit der nicht-zerlegbaren, ordnungssensitiven Metrik
Quadratic Weighted Kappa (QWK): `qwk()` (die Metrik selbst, Cohen,
quadratische Gewichte), `optimize_ordinal_thresholds()`/`apply_
ordinal_thresholds()` - das Ziel als REGRESSION vorhersagen und die
kontinuierliche Ausgabe QWK-optimal in ordinale Klassen runden
(Schnittpunkte per Nelder-Mead), statt Multiclass (ignoriert die
Ordnung).

**Aufrufkontext**: Optionales Modul, vom Standard-Workflow NICHT
gesourct (rueckwirkungsfrei) - manuell fuer Projekte mit ordinalem
Ziel + QWK-Metrik.

**Ergebnis/Nutzen**: An playground-s3e5 (wine-quality) bestaetigt:
Regression+QWK-Runden schlug Multiclass (0.526 vs. 0.469). Kernlektion:
bei nicht-zerlegbaren Metriken auf die ECHTE Metrik optimieren, nicht
auf einen Proxy - QWK-naiv-gerundetes Tuning, MSE-basierte Lambda-Wahl
und MSE-Stacking fuehrten alle in die Irre.

**Literaturreferenz**: -

## sanity_checks.R

**Beschreibung**: Drei modell-agnostische Behavioral-Testing-Checks
(Funktionen nehmen `predict_fn`/`predict_prob_fn` als Parameter):
Perturbation (Robustheit gegen kleine realistische Stoerungen),
Invarianz (Modell reagiert NICHT auf kausal bedeutungslose Spalten),
Directional Expectation (Modell bewegt sich bei bekannter monotoner
Domainbeziehung in die erwartete Richtung). Ergaenzen eine reine
Holdout-Metrik, die solche Verhaltensprobleme verstecken kann.

**Aufrufkontext**: Von `147_error_analysis_ranger_sanity_checks.R`
aufgerufen; Konfiguration (welche Spalten, Richtung, `higher_is_
better`) projektspezifisch in `000_config.R`. Aufgabentyp-unabhaengig,
identisch ins Regressions-Template uebernommen (wie `univariate_
drift.R`).

**Ergebnis/Nutzen**: Verifiziert an synthetischer Ground Truth + 2
realen Projekten (`health_condition`, `drivendata-pump-it-up`).

**Literaturreferenz**: Huyen (2022) "Designing Machine Learning
Systems", Kap. 6 "Model Evaluation Methods" - siehe `docs/reference/
REFERENZ_MODEL_SANITY_CHECKS.md` fuer den vollen theoretischen
Hintergrund.

## seed_stability.R

**Beschreibung**: Prueft, wie sehr der Score AUF DENSELBEN Daten
(fixer Train/Test-Split) allein durch den Zufalls-Seed des Lerners
bzw. leichtes Jitter auf den gewaehlten Hyperparametern schwankt -
Referenzpunkt ist die normale CV-Fold-zu-Fold-Streuung. Ergaenzt
`sanity_checks.R` (Streuung durch Feature-Rauschen) und `split_size_
sensitivity.R` (Streuung durch WELCHE Zeilen im Split landen) um einen
dritten Rauschkanal: Streuung durch das MODELL selbst bei fixen Daten.

**Aufrufkontext**: Von `092_seed_stability.R` aufgerufen, nach der
`090`-Tuning-Konfiguration.

**Ergebnis/Nutzen**: Relevant fuer Fragen wie "mehr Baeume vs. mehr
CV-Folds" oder wie sehr man den gefundenen Hyperparametern vertrauen
sollte, wenn die reine Seed-/Jitter-Streuung im Vergleich zur
CV-Fold-Streuung gross ausfaellt.

**Literaturreferenz**: Jason Brownlee, "Data Science Diagnostic
Checklist", Abschnitt 14.

## split_size_sensitivity.R

**Beschreibung**: Prueft, ob der GEWAEHLTE Train/Test-Split-Anteil
(`validation_ratio`) selbst stabil ist, BEVOR man einer einzelnen
Holdout-Bewertung vertraut. Mechanismus: `rsmp("subsampling", repeats,
ratio)` wiederholt den Split R-mal bei festem `ratio` mit `classif.
rpart` als billigem, lernverfahren-unabhaengigem Stellvertreter - die
SD der Scores zeigt, wie sehr "welche Zeilen zufaellig gezogen werden"
das Ergebnis beeinflusst.

**Aufrufkontext**: Von `022_split_size_sensitivity.R` aufgerufen,
uebersprungen bei Datensaetzen ueber `split_sensitivity_max_n`.

**Ergebnis/Nutzen**: `report_split_ratio_sensitivity()` meldet
"AUFFAELLIG" mit drei Reaktionsebenen (von taktisch bis strukturell) -
ergaenzt (nicht ersetzt) `target_leak_audit_helpers.R`/`univariate_
drift.R`: dort Verzerrung/Drift EINES Splits, hier Stabilitaet ueber
viele moegliche Splits desselben Anteils.

**Literaturreferenz**: Jason Brownlee, "Data Science Diagnostic
Checklist", Abschnitt 3.

## univariate_drift.R

**Beschreibung**: Univariate statistische Drift-Tests je Feature -
Kolmogorov-Smirnov (stetig) bzw. Chi-Quadrat (kategorial), mit
Benjamini-Hochberg-Korrektur ueber alle Features (verhindert
Massensignifikanz bei vielen Features/Zeilen). Effektgroesse (KS-D
bzw. Cramer's V) zusaetzlich zum p-Wert, da p-Werte bei grossen
Datensaetzen triviale Abweichungen ueberbetonen. Ergaenzung zur
Adversarial Validation (Domain-Classifier): die AUC sagt nur
"trennbar ja/nein/wie stark insgesamt", die univariaten Tests sagen
WELCHE Features treiben.

**Aufrufkontext**: Von `115_adversarial_validation.R` aufgerufen.

**Ergebnis/Nutzen**: Verifiziert an 2 unabhaengigen OpenML-Datensaetzen
+ 3 Szenarien (echter Zeit-Drift, Zufalls-Kontrolle, konstruierter
Drift) - siehe `TARGETS.md` fuer Zahlen. Aufgabentyp-unabhaengig,
identisch ins Regressions-Template uebernommen.

**Literaturreferenz**: "Introducing MLOps" (Treveil/Dataiku 2020),
Kap. 7.
