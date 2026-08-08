# Anleitung: `targets`-Pipeline

Diese Datei erklärt, wie unsere `targets`-Pipeline (`_targets.R`) funktioniert,
welche Befehle man im Alltag braucht, und was zu tun ist, wenn dieser Workflow
auf einen neuen Klassifikationsaufgaben-Wettbewerb übertragen werden soll.
Für die inhaltlichen Ergebnisse (welches Modell, welche Klassengewichtung,
welche Features) siehe `README.md` - hier geht es nur um das *Werkzeug*.

## Das Wichtigste zuerst: Was `targets` NICHT macht

`targets` trifft **keine inhaltlichen Entscheidungen**. Es führt exakt den
Code aus, der in `_targets.R` und den referenzierten Konfigurationswerten
(`000_config.R`) steht - nicht mehr und nicht weniger.

Konkret: `submission_model_name <- "ranger"` in `000_config.R` legt fest,
dass `tar_make()` immer Ranger als finales Modell trainiert. Das bleibt so,
**auch wenn ein besseres Modell existieren würde**, das wir nicht eingebaut
haben. Ob Ranger tatsächlich das beste Modell ist, wurde durch die
explorativen Skripte (`080`-`145`) und manuelle Analyse entschieden - nicht
durch `targets`. Wenn sich die Faktenlage ändert (z.B. ein neuer Datensatz,
eine neue Idee), muss ein Mensch (oder eine KI) das erneut untersuchen und
die Config/den Pipeline-Code entsprechend anpassen. `targets` automatisiert
danach nur noch die *Ausführung* dieser Entscheidung - zuverlässig,
nachvollziehbar, ohne unnötige Neuberechnung.

## Grundkonzept

- **Ziel (Target)**: ein benanntes R-Objekt, erzeugt durch ein Code-Snippet
  (`tar_target(name, command)`). Wird nach der Berechnung in `_targets/objects/`
  gecacht.
- **Abhängigkeitsgraph**: `targets` erkennt automatisch per Code-Analyse,
  welches Ziel von welchem abhängt - taucht der Name von Ziel A im Code von
  Ziel B auf, hängt B von A ab. Keine manuelle Verkabelung nötig.
- **Caching/Invalidierung**: `targets` hasht sowohl die Konfigurationswerte
  als auch den Code jedes Ziels (inklusive aufgerufener Funktionen aus
  `000_config.R`/`features/*.R`). Ändert sich einer der beiden, gilt das Ziel
  und alles Nachgelagerte als veraltet und wird bei `tar_make()` neu gebaut -
  alles andere bleibt unverändert im Cache und wird übersprungen.

## Befehlsübersicht

Alles wird aus einer R-Konsole mit Arbeitsverzeichnis im Projektordner
ausgeführt (wo `_targets.R` liegt), z.B.:

```r
setwd("C:/Users/HP/OneDrive/Dokumente/R_Workspace/MLR3_Classifikation")
library(targets)
```

| Befehl | Zweck |
|---|---|
| `tar_make()` | Hauptbefehl: baut alles Veraltete/Fehlende neu, überspringt den Rest |
| `tar_visnetwork()` | Zeigt den Abhängigkeitsgraphen interaktiv (gruen = aktuell, andere Farbe = muss neu laufen) - **vor** `tar_make()` aufrufen, um zu sehen, was passieren wuerde |
| `tar_outdated()` | Listet nur die Namen der veralteten Ziele auf |
| `tar_manifest()` | Zeigt Zielliste + Code, ohne etwas auszuführen (schnelle Strukturpruefung) |
| `tar_read(name)` | Lädt ein Ziel aus dem Cache, um es anzuschauen (z.B. `tar_read(submission)`) |
| `tar_load(name)` | Wie `tar_read()`, legt das Ergebnis aber als Variable `name` in der Session ab |
| `tar_meta(fields = warnings)` | Zeigt Warnungen/Fehler aus dem letzten Lauf |

Aus dem Terminal (ohne R-Konsole zu öffnen) geht es auch direkt:

```bash
Rscript -e "targets::tar_make()"
```

## Unsere Pipeline im Überblick (17 Ziele)

`_targets.R` bildet den *finalen* Workflow ab (entspricht den nummerierten
Skripten `020`/`025`/`070`/`150`/`155`), in vier Phasen:

1. **Rohdaten** (`train_raw_file`, `train_raw`, `test_file`, `train_full_file`,
   `train_full`) - laedt `train.csv`/`test.csv`.
2. **Feature-Familien und 10%-Subset-Tasks** (`feature_family_name` →
   `task_family` als **dynamisch verzweigtes Ziel**, ein Branch pro Eintrag in
   `feature_families`; dazu `task_raw`, `task_combined`, `task_selected`).
3. **Finale Modelle auf dem Subset** (`model_name` → `final_model_subset`,
   ebenfalls dynamisch verzweigt über `model_feature_sets`).
4. **Volles Training & Submission** (`train_full`, `full_feature_levels`,
   `task_full`, `task_full_weighted`, `final_model_full`, `submission`).

Die **dynamische Verzweigung** (`pattern = map(...)`) ist der Grund, warum wir
z.B. für sechs Feature-Familien nicht sechs fast identische `tar_target()`-
Aufrufe schreiben mussten - ein Branch pro Eintrag in `feature_families`
entsteht automatisch. Fügt man in `000_config.R` eine siebte Familie hinzu
(und die passende Funktion in `features/`), erzeugt `tar_make()` beim
nächsten Lauf automatisch einen siebten Branch, ohne dass `_targets.R`
angefasst werden muss.

**Bewusst nicht in dieser Pipeline enthalten**: die explorativen Skripte
`030`-`145` (Baselines, Feature-/Surrogate-guided-Vergleiche, Boosting-
Vergleich, Klassengewicht-Kurven, Ranger-Tuning, Ensemble-Test,
Adversarial Validation, ...). Die dienten der
*einmaligen* Modellauswahl fuer *diesen* Wettbewerb, nicht einem
wiederholbaren Produktions-Workflow. Fuer einen neuen Wettbewerb muesste man
dieselben *Fragen* erneut stellen (siehe Checkliste unten), aber das ist
Analysearbeit, die `targets` nicht automatisiert - nur die Vorlage
(Methodik/Code-Struktur der Skripte) ist wiederverwendbar.

## Praktisches Beispiel: Etwas aendern und neu bauen

Angenommen, du willst `class_weight_power` von 1.5 auf 1.75 testen:

1. Aendere den Wert in `000_config.R`.
2. `targets::tar_visnetwork()` - du siehst: `task_full_weighted`,
   `final_model_full` und `submission` sind jetzt als veraltet markiert
   (haengen von `class_weight_power` ab). `task_family`, `task_combined` etc.
   bleiben unveraendert (aktuell), da sie nicht von diesem Wert abhaengen.
3. `targets::tar_make()` - nur die drei veralteten Ziele werden neu berechnet
   (inkl. dem vollen Ranger-Training, ca. 12 Minuten). Der Rest kommt aus dem
   Cache, ohne neu zu laufen.
4. `submission.csv` (bzw. `targets::tar_read(submission)`) enthaelt das neue
   Ergebnis.

## Checkliste: Uebertragung auf einen neuen Kaggle-Wettbewerb

> **Ausfuehrlichere Fassung**: siehe [`WorkflowDescription.md`](WorkflowDescription.md) - dieselbe
> Checkliste, aber mit Beispielbefehlen, erwarteten Ausgaben und
> Entscheidungsregeln pro Schritt, damit sie auch ohne KI-Unterstuetzung
> nachvollziehbar ist.

1. `train.csv`/`test.csv`/`sample_submission.csv` durch die neuen Dateien ersetzen.
2. `000_config.R`: `id_col`, `target_col`, `baseline_measure_ids` (die Ziel-
   metrik ist wahrscheinlich eine andere als BAcc/MCC! `030_baseline.R`/
   `080_boosting_benchmark.R`/`090_ranger_tuning.R`/`100_lightgbm_tuning.R`/
   `105_lightgbm_class_weights.R` setzen `predict_type = "prob"` bereits
   automatisch und `090`/`100` optimieren bereits `baseline_measure_ids[1]`
   statt hart codiertem `classif.bacc` - bei einer schwellenwertunabhaengigen
   Metrik wie AUC/LogLoss ist daher **kein** manueller Fix mehr noetig, nur
   `130_threshold_tuning.R`/`146_threshold_tuning_ranger.R` bleiben fuer
   diesen Fall i.d.R. ueberspringbar, siehe deren Kopfkommentar),
   `feature_families`/`selected_families`, `model_feature_sets`,
   `model_class_weight_power` neu befuellen. `task_id_prefix` wird automatisch
   aus `target_col` abgeleitet, dort ist **keine** manuelle Anpassung noetig.
   Bei genau 2 Zielklassen (binaere Aufgabe): `error_analysis_uncertainty_threshold`
   bewusst deutlich ueber 0.5 setzen (z.B. 0.7) - bei 2 Klassen ist die
   Konfidenz der vorhergesagten Klasse mathematisch immer >= 0.5, ein
   Schwellenwert von 0.5 waere dort entartet (bleibt praktisch immer leer).
   Aus demselben Grund ist bei binaeren Aufgaben der "Keiner hat recht"-Anteil
   von `check_disagreement_accuracy()` strukturell immer 0% (nur bei >=3
   Klassen aussagekraeftig).
3. `features/*.R` durch neue, domaenenspezifische `add_<familie>_features()`-
   Funktionen ersetzen (oder zunaechst leer lassen, falls noch kein Feature
   Engineering feststeht).
4. Falls ein neues Modell das Submission-Modell werden soll, das noch nicht
   in `base_learner_constructors` (`000_config.R`) steht: dort ergaenzen.
5. `_targets.R` selbst muss dabei in der Regel **nicht** angefasst werden -
   der Graph (welches Ziel von welchem abhaengt) bleibt strukturell gleich,
   er liest nur die neuen Config-Werte.
6. Vor dem finalen `tar_make()`: die Methodik aus `030`-`145` (als Vorlage,
   nicht als Copy-Paste) fuer den neuen Datensatz wiederholen - Feature-
   Familien testen, Modelle vergleichen, Klassengewichtung pruefen,
   Adversarial Validation - und die Ergebnisse in Schritt 2/4 einfliessen
   lassen. Alle diese Skripte loggen automatisch in `_artifacts/experiments.db`
   (siehe README.md, Abschnitt "Experiment-Tracking (SQLite)") - fuer einen
   neuen Wettbewerb reicht ein neuer `project_name` in `000_config.R`, Schema
   und Logging-Code bleiben unveraendert. `030_baseline.R` warnt automatisch
   vor hochkardinalen Faktor-Spalten (`warn_high_cardinality_factors()` in
   `005_benchmark_runtime.R`), die LDA/Multinom zum Absturz bringen koennen -
   bei einer Warnung die Spalte fuer diese Modelle ausschliessen oder sinnvoll
   kodieren (Frequenz-/Zielkodierung). Bei numerisch codierten hochkardinalen
   IDs (z.B. Geo- oder Objekt-IDs) zunaechst eine zielwertfreie
   Frequency-Encoding-Variante gegen die native/numerische Baseline testen:
   `drivendata_richter` verbesserte sich damit deutlich, ohne Target-Encoding
   zu benoetigen.
7. `148_select_submission_model.R` ausfuehren, um datengetrieben (aus
   `experiments.db`) den Algorithmus mit dem besten Wert von
   `baseline_measure_ids[1]` auf dem Roh-Feature-Set vorzuschlagen. Ergebnis
   pruefen (siehe Hinweis unten) und `submission_model_override` in
   `000_config.R` entweder auf diesen Vorschlag oder eine bewusst abweichende
   Entscheidung setzen (auf `NULL` lassen uebernimmt den Vorschlag automatisch
   bei jedem Lauf, ohne dass jemand `000_config.R` anfassen muss - siehe
   Architektur-Hinweis bei `submission_model_override`). **Vorsicht**: die
   automatische Auswahl beruecksichtigt nur eine einzelne Metrik auf
   Rohfeatures - Abwaegungen wie BAcc-vs-MCC-Trade-offs, Feature-Set-Wahl oder
   Klassengewichtung (wie in diesem Projekt fuer Ranger dokumentiert) muss ein
   Mensch weiterhin selbst pruefen, bevor er sich auf den Vorschlag verlaesst.
   Der finale Submission-Kandidat sollte aus dem besten CV-Ergebnis je
   Feature-Set kommen, nicht pauschal aus einem bevorzugten Algorithmus:
   `drivendata_richter` bestaetigte Ranger + Frequency-Encoding deutlich vor
   LightGBM + Frequency-Encoding.

## Feature-Sets im finalen Workflow

`task_full`/`final_model_full`/`submission` nutzen dieselbe Feature-Set-Logik
wie die explorativen Skripte: `apply_feature_set()` wendet `"raw"`,
`"features"`, `"selected"`, `"surrogate_guided"` oder einzelne Eintraege aus `feature_families`
identisch auf den vollen Trainingsdatensatz und auf `test.csv` an. Das heisst
nicht, dass Feature Engineering automatisch besser ist: In diesem Projekt
bleibt Ranger bewusst auf `"raw"`, weil Cross-Validation und Kaggle-Feedback
genau diese Entscheidung bestaetigt haben.

`"surrogate_guided"` ist ein Sonderfall: Die Feature-Spezifikation entsteht
vorher explorativ durch `038_surrogate_guided_features.R` aus Pfaden eines
kleinen `rpart`-Ensembles. `targets` wendet diese Spezifikation nur reproduzierbar an,
falls sie bewusst als Feature-Set fuer ein finales Modell gewaehlt wurde; die
Discovery selbst bleibt ausserhalb des finalen Graphen, um Modellauswahl und
Produktion sauber zu trennen.

## Backlog (bei einer Uebertragung gefunden, noch nicht umgesetzt)

Bei der Uebertragung dieses Templates auf `playground-series-s6e5`
(F1-Boxenstopp-Vorhersage, binaer, AUC-bewertet) sind weitere
Reibungspunkte aufgefallen, die sich noch nicht sicher genug generalisieren
liessen, um sie hier direkt umzusetzen. Details, Herleitung und Status siehe
`TEMPLATE_FRICTION.md` im genannten Projekt:

- ~~**`080_boosting_benchmark.R` bündelt Learner mit unterschiedlichem
  Preprocessing-Bedarf**~~ **ERLEDIGT (2026-07-17)**: aufgeteilt in `080`
  (Ranger + LightGBM, native Faktoren, kein One-Hot) und neu
  `081_xgboost_benchmark.R` (XGBoost, sourct `040_preprocessing.R`). `080`
  sourct `040` nicht mehr - der guenstige Teil laeuft ohne die
  XGBoost-Preprocessing-Abhaengigkeit. README/ANLEITUNG/Config entsprechend
  angepasst, end-to-end gegen das Template-eigene Projekt getestet.
- ~~**SQL-Views (`v_model_results`, `v_run_summary`, `v_best_per_algorithm`)
  zeigen nur `classif.bacc`/`classif.mcc`**~~ **ERLEDIGT (2026-07-17)**: zwei
  generische Langformat-Views ergaenzt (`v_metric_results`,
  `v_best_per_algorithm_metric` - Letzteres richtungsabhaengig sortiert,
  LogLoss niedriger=besser), Pivot-Views um `auc`/`logloss`/`prauc` erweitert,
  alle Views auf `DROP VIEW IF EXISTS` + `CREATE VIEW` umgestellt (sonst
  greifen geaenderte Definitionen in bestehenden DBs nicht). Gegen echte
  AUC/LogLoss-Daten (openml-adult-income) UND die BAcc/MCC-Template-DB
  getestet. Siehe `EXPERIMENTS_DB.md`, Abschnitt "Views".
- **`tnr("mbo")`s Initialdesign kann das Eval-Budget stillschweigend
  aufbrauchen**: Das Initialdesign skaliert mit ~4x Anzahl Suchraum-
  Parameter - wird der Suchraum erweitert, ohne das Budget (`*_tuning_evals`)
  entsprechend zu erhoehen, findet ggf. gar keine echte sequenzielle
  Optimierung mehr statt (pruefbar ueber `unique(instance$archive$data$batch_nr)`
  - genau 1 eindeutiger Wert heisst: nur Initialdesign, keine Verfeinerung).
  Vorschlag: vor jedem Tuning-Lauf mit erweitertem Suchraum Budget >= 4x
  Dimensionen + 10-20 sicherstellen, danach `batch_nr` sowie Spannweite/R²
  der Zielmetrik ueber die Archiv-Punkte pruefen (Plateau-Indikator), um
  eine Empfehlung "Budget erhoehen" vs. "vermutlich Plateau" abzuleiten.
- **Logits-Stacking über bereits benchmarkte Modelle fehlt**: Das Template
  waehlt bisher nur das beste EINZELNE Modell fuer die Submission
  (`148_select_submission_model.R`), kombiniert die bereits vorhandenen
  Benchmark-Modelle (LDA/Multinom/Ranger/LightGBM/XGBoost) aber nirgends zu
  einem Stacking-Ensemble. Anlass: 1st-Place-Writeup zu
  `playground-series-s6e5` zeigt, dass ein simpler Logistic-Regression-Meta-
  Learner auf den Logits mehrerer Basismodelle nahe an ein komplexes
  AutoML-Ensemble herankam - unser getuntes LightGBM liegt dort ~0.013 AUC
  hinter dem Gewinner. Details, Abgrenzung (was bewusst NICHT übernommen
  wurde, z.B. Original-Datensatz-Mischen) und ein konkreter Vorschlag
  (`140_stack_ensemble.R`) siehe `TEMPLATE_FRICTION.md` in
  `playground-series-s6e5`, Eintrag 6. **Update (2026-07-16)**: in
  `playground-series-s6e5` umgesetzt und per CV getestet - Ergebnis negativ/
  neutral (Stack nur +0.00016 AUC vs. bestes Einzelmodell, unter dem
  Rausch-Band, bei ~19x hoeherem Rechenaufwand). Nicht als eigener Schritt
  ins Template zurueckgefuehrt - Aufwand/Nutzen sprach dagegen.
  (Die beiden folgenden Punkte - SQL-Views und `080`-Split - hatten nach
  `openml-adult-income` eine zweite unabhaengige Bestaetigung und wurden
  daraufhin umgesetzt, siehe die durchgestrichenen ERLEDIGT-Eintraege oben.)
- **Kalibrierungssensitive Metriken (LogLoss) reagieren auf Trainings-
  Klassengewichtung anders als reine Rangfolge-Metriken (AUC)** - direkt
  verifiziert in `openml-adult-income` (mittlere vorhergesagte Wahrschein-
  lichkeit driftet mit steigendem `class_weight_power` messbar von der
  wahren Basisrate weg, Mechanismus wie bei "Rare Events Logistic
  Regression"). **Bereits ins Template zurueckgefuehrt (2026-07-16)**:
  `calibration_sensitive_measures`/`is_weighting_step`-Parameter in
  `db_logging.R`s `warn_if_threshold_step_low_value()`, siehe Kommentar dort
  fuer die Herleitung. Regressionsgetestet gegen das Template-eigene Projekt
  (BAcc-Metrik, keine Verhaltensaenderung).
- **Kardinalitaets-Schwelle (`warn_high_cardinality_factors()`, 50 Level)
  reicht nicht aus** - `openml-adult-income` zeigte LDA/Multinom-Abstuerze
  sowohl bei einer 41-Level-Spalte (unter der Schwelle) als auch bei
  niedrig-kardinalen Spalten (7-14 Level) mit einzelnen seltenen, in einer
  Klasse gar nicht vorkommenden Leveln. **Bereits ins Template
  zurueckgefuehrt (2026-07-16)**: neue Funktion `warn_rare_factor_levels()`
  in `005_benchmark_runtime.R` (Kreuztabellen-Check statt reiner
  Levelzahl-Zaehlung), aus `030_baseline.R` aufgerufen. Regressionsgetestet
  gegen das Template-eigene Projekt (loest korrekt keine Warnung aus).
  `po("collapsefactors")` als Loesungsmuster (seltene Level automatisch
  zusammenfassen) in `openml-adult-income/030_baseline.R`/
  `040_preprocessing.R` demonstriert.
  - **`collapsefactors` als Template-Standard: ENTSCHIEDEN NEIN (2026-07-17,
    warn-only)**. Ein Sicherheits-Check am Template-eigenen `health_condition`
    (Frage: schadet ein `collapsefactors`-Default auf Daten, die ihn nicht
    brauchen?) fand einen klaren Blocker: `health_condition`s Faktoren
    enthalten ein Leerstring-Level `""`, und `po("collapsefactors")` wandelt
    dieses beim Kollabieren in `NA` um (686 NAs in `diet_type`, exakt die
    `""`-Level-Groesse). Die schlanke Baseline-Pipeline (`impute` ohne
    vorherige `""`->NA-Umwandlung) reicht das `NA` an LDA/Multinom weiter ->
    Absturz. `health_condition` laeuft heute nur, WEIL `030` kein
    `collapsefactors` enthaelt; als Default wuerde es das Template-eigene
    Projekt brechen (es sei denn, man zoege auch `040`s `empty_factor_to_na`
    mit rein). Diese Kontext-Abhaengigkeit ist das Argument gegen einen
    bedingungslosen Default. **Loesung bleibt `warn_rare_factor_levels()`**
    (erkennen + warnen, projektweise entscheiden), NICHT ein globaler
    Preprocessing-Schritt. Nebenbefund (Entwarnung): dieselben Parameter
    kollabierten im Adult-Projekt korrekt/sanft (`native.country` 41->5 usw.,
    0 NAs) - der `absolute=20`-Schutz greift dort, der `target_level_count=2`-
    Boden bindet nicht. Adult-Ergebnisse sind also nicht kompromittiert.
    `target_level_count` (Default 2) ist aber der eigentlich bindende
    Parameter, wenn `absolute` nicht schuetzt - bei kuenftiger Nutzung von
    `collapsefactors` beachten.
- **Per-Klassen-gewichteter Ensemble-Blend (2nd-place-SLSQP-Schritt) fuer
  Multiklassen-BAcc** - Anlass: 2nd-Place-Writeup zu `playground-series-s6e7`
  (health_condition, "Trusting CV & Mathematical Precision"). Deren zwei Hebel:
  (1) per-Klassen-optimierte Blend-Gewichte (SLSQP, LogLoss-minimierend) ueber
  viele Basismodelle, dann (2) metrik-optimale Klassen-Multiplikatoren
  (Nelder-Mead) auf dem Blend. **Hebel (2) ist bereits ERLEDIGT** (commit
  70745fb: `class_multiplier_tuning.R`, kontinuierlicher Optimizer in `130` -
  auf health_condition-OOF raw argmax 0.872 -> 0.945, +0.074; der groesste
  Einzelhebel, unabhaengig vom Ensemble). **Offen ist Hebel (1)**, der
  per-Klassen-Blend. Prototypisch gegen health_condition-OOF (10%-Subset,
  LightGBM + ranger, identische Folds, je + Multiplikatoren) gemessen:
  Multiplikator uebertraegt sich voll aufs Ensemble (+0.077 BAcc); ein
  GLEICHGEWICHTETES 2-Modell-Ensemble schlaegt das beste Einzelmodell aber
  NICHT (0.9449 vs 0.9454, Verwaesserung durch das schwaechere ranger); der
  per-Klassen-GEWICHTETE Blend behebt das (LogLoss 0.1040 -> 0.1000, BAcc
  +0.0005 ueber bestem Einzel, gelernte LightGBM-Gewichte je Klasse
  0.98/0.85/0.81). **Technik bestaetigt korrekt, aber Payoff an der
  Rauschgrenze** mit zwei korrelierten Baummodellen - wie schon beim
  Logits-Stacking-Eintrag oben (correlated bases). Der reale Sieger-Gewinn
  kam von echter DIVERSITAET (18 Modelle inkl. FT-Transformer, das das
  groesste Blend-Gewicht bekam), nicht vom Blend-Verfahren allein. Vorschlag:
  erst ein diverses, nicht-baumbasiertes Mitglied (mlr3torch: FT-Transformer/
  RealMLP) in den Benchmark aufnehmen, dann den per-Klassen-Blend (als
  `140_weighted_blend.R`, Softmax-Gewichte je Klasse, LogLoss-optimiert)
  gegen das beste Einzelmodell messen. Erst bei klarem Gewinn ODER 2-Projekt-
  Bestaetigung zurueckfuehren.
- ~~**Exact-value Target-Encoding auch auf NUMERISCHE Spalten**~~ **ERLEDIGT /
  UEBERNOMMEN (2. Bestaetigung)**: Anlass 4th-Place-Writeup zu `s6e7` (XGBoost OOF
  0.9489 -> 0.9496), zweite unabhaengige Bestaetigung auf `s6e8` (Smartphone
  Addiction, binaer/AUC): CV +0.0044 AUC, **LB 0.96353 -> 0.96731 (+0.0038)** - der
  CV->LB-Transfer trug fast exakt. Synthetischer Generator resampelt aus endlichem
  Support -> numerische Werte wiederholen stark (s6e8: age 18 Werte, alle Spalten
  uniq_frac < 0.003) und wirken wie hochkardinale Kategorien. Ins Template
  uebernommen: `features/target_encoding.R` -> `build_exact_value_te_graph()` /
  `build_exact_value_te_pipeline()` (numerisch-als-Faktor + encodeimpact, Originale
  bleiben, leck-sicher pro CV-Fold, generisch binaer+multiclass). VORBEDINGUNG vor
  Aktivierung: pruefen, dass die Werte tatsaechlich stark wiederholen (sonst
  Overfitting). Laufzeit: encodeimpact auf hochkardinal-numerisch ist teurer.
- ~~**155-Submission gibt immer Klassen-Labels aus**~~ **ERLEDIGT**: Anlass s6e8
  (binaer/AUC). `155_predict_submission.R` gab `$response` (Labels) aus - fuer
  wahrscheinlichkeitsbasierte Metriken (AUC/LogLoss) braucht Kaggle aber
  Wahrscheinlichkeiten. Jetzt metrik-abhaengig: `is_threshold_independent_metric(
  baseline_measure_ids[1])` + binaer -> P(positive) (positive Klasse aus
  `positive_class` in 000_config, in 020_task gesetzt), sonst Labels wie bisher.
  150 setzt `predict_type="prob"`, falls der Learner es kann. Rueckwirkungsfrei
  fuer das Eigenprojekt (health_condition, BAcc/multiclass -> weiter Labels;
  getestet). Multiclass-prob (Spalte je Klasse) bleibt projektspezifisch.
- **Screening-Falle: hochkardinale/statistik-basierte Features NICHT auf einem
  Zeilen-Subset screenen** - Anlass: 4th-Place-Writeup. Das exact-value-TE-Feature
  sah auf einem 70k-Zeilen-Screen -0.0017, auf vollen Daten aber +0.0012 - das
  Vorzeichen drehte. Per-Wert-Statistiken brauchen genug Wiederholungen; ein
  `subset_fraction`-Subset (wir: 0.10) zerstoert genau das. **Regel: zum
  Verbilligen Folds/Epochen reduzieren, nicht Zeilen** - gilt fuer Target-/
  Frequency-Encoding und alles, was auf hochkardinalen Zaehlungen beruht.
  **s6e8 bestaetigte das live**: dieselbe exact-value-TE-Pipeline gab auf 30k
  Zeilen -0.0027 AUC (Vorzeichen negativ), auf 138k +0.0044 - nur die Datenmenge
  entscheidet ueber Nutzen/Schaden. (Reine
  Multiplikator-/Prior-Korrektur ist davon NICHT betroffen: Klassen-Priors bleiben
  unter stratifiziertem Subsetting erhalten - deshalb war der `130`-Test auf 10%
  aussagekraeftig, der TE-Test waere es nicht.)
- ~~**`150_train_full_model.R`/`155_predict_submission.R` sourcen unbedingt
  hartcodierte Feature-Familien-Dateien**~~ **ERLEDIGT**: Zwei unabhaengige
  Uebertragungen (`playground-series-s6e5`, `playground-series-s5e12`, Letzteres
  explizit als "drittes Auftreten, sollte generalisiert werden" markiert)
  scheiterten beim Kopieren von `150`/`155` auf ein neues Projekt ohne (oder mit
  anderen) Feature-Familien-Dateien - die Skripte sourcten unbedingt `bmi.R`,
  `sleep.R`, `activity.R`, `hydration.R`, `cardio.R`, `interactions.R`,
  `surrogate_guided.R` per Namen, obwohl `TARGETS.md`s eigene
  Uebertragungs-Checkliste erlaubt, `feature_families` leer zu lassen. Jetzt:
  beide Skripte laden alle `features/*.R` per Glob
  (`list.files(..., pattern = "\\.R$")`) statt einzelner Dateinamen - bei einem
  neuen Projekt werden genau die vorhandenen Dateien geladen, kein "file not
  found" mehr. Rueckwirkungsfrei getestet (alle bisherigen `add_*_features`-/
  `build_*_po`-Funktionen bleiben nach dem Glob-Sourcing verfuegbar).
- **Fehlwert-Sentinels (numerisch, z.B. `-9999`) werden vom Template nicht
  erkannt** - Anlass: `geoai-aquaculture-pond-identification-challenge`
  (Sentinel-codierte fehlende Monate in Fernerkundungsdaten). Die
  Imputationspipelines (`imputemedian`/`imputemode`) fangen nur echtes `NA` ab,
  nicht numerische Sentinel-Werte - die wirken sonst wie extreme, aber gueltige
  Messwerte. Projekt-lokal in `000_config.R` geloest (Sentinel-Liste ->
  `sentinel_to_na()`-Transformation vor der Pipeline), noch nicht generalisiert.
  1-Projekt-Kandidat; ins Template uebernehmen (z.B. als
  `sentinel_to_na(dt, sentinel_values)`-Helfer analog zu
  `empty_factor_to_na()`), sobald ein 2. Projekt mit numerischen Sentinels
  auftritt.
- ~~**Target-Leakage-Audit als Workflow-Guard fehlt**~~ **ERLEDIGT**: Anlass
  `CreditScoringChallenge` (African Credit Scoring, stark unbalanciert, ~1.8%
  positive Klasse). Die naive Baseline erreichte F1 0.88 - getrieben durch einen
  Ex-post-Leak (`interest_ratio`, nur nach Kreditvergabe bekannt). Nach
  Bereinigung sank der ehrliche Wert auf F1 ~0.413, extern am Leaderboard fast
  exakt bestaetigt (0.4191, Δ+0.006). Externe Zweitbestaetigung ausserhalb dieses
  Templates: [[project_target_leak_audit]] im persoenlichen Memory.
  Umgesetzt als `015_target_leak_audit.R` (vor `020_task.R`, bewusst auf vollen
  Daten - Determinismus-/Stratum-Befunde brauchen Volumen): (1)
  Feature-Importance-Konzentration (LightGBM-Gain-Share >50%), (2)
  Determinismus-Check (`P(Ziel=Klasse|Feature=Wert)` bei ausreichender
  Gruppengroesse), (3) optionale Within-Stratum-Zieltrennung
  (`leak_audit_stratify_cols`), (4) Ehrlich-vs-aufgeblasen-Zerlegung
  (gepaarter Holdout, mit/ohne Verdaechtige, DB-geloggt als `custom_split`
  analog `130`). Schritt 5 (Verfuegbarkeit zur Entscheidungszeit) bleibt bewusst
  manuelles Urteil, das Skript listet nur die Leitfragen. Rueckwirkungsfrei
  getestet gegen das Template-eigene Projekt (health_condition, volle 690088
  Zeilen): kein Feature ueberschreitet 50% Gain-Share (Top: stress_level 42.9%,
  sleep_duration 34.8%), kein Determinismus-Fund - Audit korrekt unauffaellig,
  siehe README "Target-Leakage-Audit". **2./3. Bestaetigung (2026-08-05,
  PumpItUp + geoai-aquaculture)**: auf zwei reale, externe Projekte angewandt,
  beide korrekt unauffaellig - deckte zwei generische Bugs auf (Datumsspalten
  liessen `as_task_classif()` abstuerzen; rein kontinuierliche Feature-Saetze
  ohne jede niedrigkardinale Spalte liessen Schritt 2 abstuerzen), beide
  behoben. `enable_class_stratification()` ist jetzt keine harte Abhaengigkeit
  mehr (direkter `set_col_roles()`-Aufruf) - laeuft auch in Projekt-Kopien ohne
  diesen Helfer. **Sensitivitaetstest (2026-08-05, Regressions-Template,
  identische Suspects-Logik)**: an einem bekannten, deterministischen Leak
  (OpenML 42712 Bike-Sharing, `casual+registered==count` exakt) fand der Guard
  den dominanten Leak-Anteil korrekt (94.7% Gain-Share, RMSE-Zerlegung 3.12 ->
  32.50), liess aber einen SCHWAECHEREN Mit-Leaker (5.3%, unter der 50%-
  Einzelschwelle) durchrutschen - die "ehrliche" Zahl war noch ~20% zu
  optimistisch. **Bekannte Grenze: nur Einzelfeature-Konzentration, keine
  gemeinsam wirkenden Leak-Paare** - bewusst nicht automatisch nachgeschaerft
  (Risiko, legitime starke Feature-Gruppen faelschlich auszuschliessen;
  Schritt 5 faengt den Rest ab). Details/Backlog-Kandidat (kumulative
  Top-k-Schwelle) siehe `WORKFLOW_GUARDS.md`/`BACKLOG.md` im
  Regressions-Template - noch nicht unabhaengig an einem Klassifikations-
  projekt bestaetigt, dieselbe Code-Logik (`share > threshold`) gilt aber
  identisch hier.
- **Nested/gepooltes per-Fold-Threshold-Tuning fehlt** - Anlass:
  `CreditScoringChallenge`, Verfeinerung zu `130_threshold_tuning.R`. Aktuell nur
  ein einzelner stratifizierter 3-Wege-Split (Train/Tune/Eval) - keine
  per-Fold-Schwellenwahl mit gepoolter Auswertung auf den ausgelassenen Folds.
  Die im Projekt umgesetzte "Nested"-Variante war dort die Grundlage einer fast
  perfekten CV-LB-Kalibrierung. Kein Muss (der bestehende 3-Wege-Split
  funktioniert), aber ein dokumentierter, funktionierender
  Verfeinerungsvorschlag fuer `class_multiplier_tuning.R`/`130`. 1-Projekt-
  Kandidat, niedrigere Prioritaet.
- **Zwei implizite Architekturentscheidungen als ADR-Kandidaten vorgemerkt
  (2026-08-08, noch nicht umgesetzt)**: (a) `targets`-Pipeline deckt bewusst
  nur den finalen Produktionspfad ab, die explorativen Skripte (`030`-`147`)
  bleiben ausserhalb des Graphen - bisher nur in `README.md`-Prosa begruendet;
  (b) beide Templates (Klassifikation/Regression) halten ihr `experiments.db`-
  Schema bewusst identisch, um kuenftige Cross-Template-Analysen/-Merges zu
  ermoeglichen - ebenfalls nur Prosa. Beide erfuellen das Befoerderungs-
  Kriterium aus `adr/README.md` (echte Alternative + versehentlich umkehrbar),
  aber noch nicht zu eigenen ADR-Dateien ausgebaut - niedrige Prioritaet,
  keine akute Verwechslungsgefahr beobachtet.
