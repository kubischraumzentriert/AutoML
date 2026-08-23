# Anleitung: `targets`-Pipeline

Diese Datei erklärt, wie unsere `targets`-Pipeline (`_targets.R`) funktioniert,
welche Befehle man im Alltag braucht, und was zu tun ist, wenn dieser Workflow
auf einen neuen Klassifikationsaufgaben-Wettbewerb übertragen werden soll.
Für die inhaltlichen Ergebnisse (welches Modell, welche Klassengewichtung,
welche Features) siehe `README_DETAILS.md` - hier geht es nur um das *Werkzeug*.

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
   (siehe README_DETAILS.md, Abschnitt "Experiment-Tracking (SQLite)") - fuer einen
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

- **`renv.lock` eingefuehrt (2026-08-17) - Dokumentations-Snapshot, KEINE
  renv-Aktivierung.** Anlass: externe Projekt-Beurteilung
  (`Beurteilung_AutoML_Projekt.md`, Nutzer-Downloads) empfahl `renv` fuer
  Reproduzierbarkeit. Bewusst NUR `renv::snapshot(lockfile = "renv.lock")`
  aus der bestehenden, funktionierenden globalen Bibliothek geschrieben -
  KEIN `renv::init()` (haette eine isolierte Projekt-Bibliothek + Auto-
  Aktivierung per `.Rprofile` fuer jede kuenftige R-Sitzung hier bedeutet,
  mit echtem Zeit-/Bruchrisiko bei den schweren ML-Paketen: `torch`/
  `mlr3torch`, `catboost`, `xgboost` - siehe die dokumentierten
  Windows-Sackgassen in `adr/002`/`NEURAL_DEPLOY.md`). Kein `.Rprofile`,
  kein `renv/`-Ordner entstanden - bestehende Skript-Ausfuehrung
  vollstaendig unveraendert, `renv.lock` ist reine Versions-Dokumentation.

  Zwei echte Luecken beim automatischen Scan gefunden und behoben: (1) der
  implizite Abhaengigkeits-Scan (`type="implicit"`, parst `library()`/
  `pkg::fun()`-Aufrufe) uebersah `torch`/`mlr3torch`/`catboost`/`xgboost`,
  weil diese nur indirekt ueber `lrn("classif.xgboost")` etc. geladen
  werden - per `renv::record()` gezielt nachgetragen (`catboost` mit
  explizitem GitHub-Remote-Spec, da nicht auf CRAN). (2) `DESCRIPTION`
  listet `emoa`/`fastGHQuad`/`lhs` (mlr3mbo-Bausteine fuer Bayesian
  Optimization) als Imports, die lokal aber gar nicht installiert waren -
  nachinstalliert und ergaenzt. `tabpfn` bewusst NICHT aufgenommen (kein
  installiertes R-Paket in diesem Repo, nur in einzelnen `ML_Learning`-
  Projekten relevant). 200 Pakete final im Lockfile.

  **Perspektivisch offen**: eine echte `renv::init()`-Aktivierung (isolierte
  Projekt-Bibliothek) waere der naechste Reifegrad, aber bewusst NICHT
  jetzt umgesetzt - das Zeit-/Bruchrisiko bei den schweren ML-Paketen
  steht in keinem Verhaeltnis zum Nutzen fuer ein Projekt, das primaer als
  persoenliches Labor genutzt wird (nicht als extern verteiltes Framework,
  siehe Einordnung in der externen Beurteilung: 9/10 als persoenliches
  Labor vs. 6/10 als oeffentliches Framework).

**Hinweis zur didaktischen Dokumentation (DIDAKTIK_*.md)**: dieselbe
≥2-Projekt-Bestaetigungsregel wie fuer Code-Backports (siehe unten) gilt
seit 2026-08-14 auch fuer Theorie-/Didaktik-Dokumente in `ML_Learning`-
Projekten (Konvention etabliert an `ML_Learning\SubjektDatensatz\
DIDAKTIK_GROUP_CV.md`) - pro neuer Technik entsteht dort eine eigene
`DIDAKTIK_<THEMA>.md` mit Status-Vermerk, erst bei einer zweiten
unabhaengigen Bestaetigung wird die Schnittmenge als `REFERENZ_*.md` hierher
zurueckgefuehrt. Vollstaendig festgehalten in
[`adr/003-backport-after-confirmation.md`](adr/003-backport-after-confirmation.md),
Abschnitt "Erweiterung: gilt auch fuer didaktische Dokumentation" - dieser
Verweis hier nur, damit die Konvention auch beim Lesen von `TARGETS.md`
allein auffindbar bleibt.

- ~~**`id_col` als Vektor bricht `015`/`023`**~~ **ERLEDIGT (2026-08-15).**
  Anlass: `openml-eeg-eye-state-timeseries` (ML_Learning) setzt
  `id_col <- c("id", "time_block")`, um neben der reinen ID auch eine
  Zeit-Block-Hilfsspalte aus dem Standard-Feature-Set auszuschliessen -
  `020_task.R`s `select(-all_of(id_col))` unterstuetzte das bereits, aber
  `015_target_leak_audit.R`/`023_learning_curve.R` nutzten
  `if (id_col %in% names(...))`, das bei einem Vektor > Laenge 1 mit
  "condition has length > 1" abbricht. Behoben mit `any(id_col %in%
  names(...))` in beiden Dateien (rueckwirkungsfrei fuer skalares
  `id_col` - `any()` auf einem Ein-Element-Vektor ist identisch zum
  Vektor selbst), regressionsgetestet gegen `ci_smoke_test`.

- ~~**Group-aware CV (`group_resampling.R`) auf der Klassifikationsseite**~~
  **ERLEDIGT (2026-08-17): ZWEITE unabhaengige Bestaetigung UND Backport
  ins Template.** `group_resampling.R` (Regressionsseite bereits
  bestaetigt an `SubjektDatensatz`/`AStepAheadOfdrought`, siehe
  `REFERENZ_GROUP_AWARE_CV.md` im Regressions-Template) wurde am
  2026-08-15 nach `openml-eeg-eye-state-timeseries` portiert (1. Beleg
  Klassifikation: Random-CV BAcc 0.930 vs. Block-CV 0.717, -21.3 Punkte,
  Zeit-Block-Nachbarschaft als Leck-Mechanismus). **2. Beleg
  (`ML_Learning/uci-parkinsons-voice-groupcv`)**: UCI Parkinsons-Sprache
  (Little et al. 2007, direkt von UCI geladen - OpenML.org antwortete an
  diesem Tag durchgehend mit 504 Gateway Timeout, siehe auch
  `wdbc-plateau-test`), 195 Aufnahmen von 32 Probanden (~6-7 je Proband),
  binaeres Ziel (Parkinson/gesund). Random-CV BAcc 0.804 vs. Group-CV BAcc
  0.568 (-23.6 Punkte) - AEHNLICHE Groessenordnung wie `eeg-eye-state`,
  aber ein STRUKTURELL ANDERER Leck-Mechanismus (echte Entitaets-
  Wiederholung statt zeitliche Naehe), was den Befund staerker macht als
  eine blosse Wiederholung. No-Signal-Check bestanden: `classif.
  featureless` liegt bei Group-CV bei 0.469 (Zufallsniveau) - Rangers
  0.568 ist also echtes, wenn auch schwaches Signal, kein reines
  Rauschen-Artefakt der wenigen Gruppen (nur 8 gesunde Probanden).
  **Backport (2026-08-17)**: `group_resampling.R` (byte-identischer Code
  zur Regressionsseite) liegt jetzt im Template-Root, Theorie/Zahlen in
  [`REFERENZ_GROUP_AWARE_CV.md`](REFERENZ_GROUP_AWARE_CV.md) (verweist auf
  das Regressions-Pendant fuer die volle Herleitung, dokumentiert hier nur
  die Classif-spezifische Bestaetigungsgeschichte). Kein numeriertes
  Treiber-Skript/keine `000_config.R`-Aenderung noetig (wie auf der
  Regressionsseite - die Gruppenspalte ist immer projektspezifisch, opt-in
  wie `scan_group_candidates()`). `test_group_significance()`/
  `scan_group_candidates()` (eta^2-Permutationstest) waren zunaechst ein
  NICHT eigenstaendig fuer Classif bestaetigter Teil (setzen numerischen
  Zielwert voraus). Details in `openml-eeg-eye-state-timeseries/README.md`
  bzw. `uci-parkinsons-voice-groupcv/README.md`, konsolidiert in
  `SYSTEMATIC_EVALUATION.md`.

  ~~**Klassifikationstaugliche Variante des Gruppen-Permutationstests**~~
  **ERLEDIGT (2026-08-17): Cramer's V ergaenzt.** `test_group_
  significance()` erkennt jetzt automatisch numerische (eta^2) vs.
  kategoriale Zielwerte (Cramer's V - normierte Chi-Quadrat-
  Effektgroesse, dieselbe `[0,1]`-Skala, dieselbe Permutationslogik). An
  2 unabhaengigen Klassifikationsprojekten bestaetigt - dieselben, deren
  `diagnose_group_cv()`-Luecken bereits unabhaengig bestaetigt waren:
  `eeg-eye-state`s `time_block` vs. `class` (V=0.9298, p=0.002),
  `uci-parkinsons`s `subject` vs. `status` (V=**1.0000**, p=0.002 - exakt
  1.0 ist korrekt, `status` ist eine Per-Proband-Diagnose, `subject`
  determiniert sie deterministisch). Negativkontrolle (kuenstliche
  Zufallsgruppe auf `eeg-eye-state`): V=0.09, p=0.942, korrekt
  unauffaellig. Details/vollstaendige Herleitung in
  `REFERENZ_GROUP_AWARE_CV.md` Abschnitt 4. Rueckgabefeldnamen dabei
  generalisiert (`eta2_observed`->`statistic_observed` +
  `statistic_name`) - kein bisheriger Aufrufer betroffen, da diese
  Funktion auf der Classif-Seite noch nie genutzt wurde.

- ~~**Nelder-Mead in `class_multiplier_tuning.R` noch nicht didaktisch
  aufgearbeitet**~~ **ERLEDIGT (2026-08-15).** Als
  [`REFERENZ_NELDER_MEAD.md`](REFERENZ_NELDER_MEAD.md) geschrieben (analog
  `REFERENZ_GENERALIZATION_GAP.md`) - Mechanismus (ableitungsfreier
  Simplex-Optimierer), warum keine Gradientenmethode (BAcc ist stueckweise
  konstant, nicht differenzierbar), die `log`-Reparametrisierung fuer
  `mult > 0`, und der dokumentierte 1D-Grenzfall (binaere Aufgaben, gefixt
  durch `optimize()`/Brent) im Detail.

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
- ~~**`tnr("mbo")`s Initialdesign kann das Eval-Budget stillschweigend
  aufbrauchen**~~ **ERLEDIGT - Karteileiche korrigiert (2026-08-15).** Der
  hier vorgeschlagene Check ist laengst umgesetzt: `diagnose_mbo_search()`
  in `006_tuning_diagnostics.R` (prueft genau `batch_nr`-Eindeutigkeit +
  Spannweite/R² der Zielmetrik als Plateau-Indikator, exakt wie unten
  beschrieben) und in `100_lightgbm_tuning.R` fest verdrahtet
  (`diagnose_mbo_search(instance, tuning_measure_id)`, Zeile 79). Diese
  Backlog-Zeile war schlicht nicht aktualisiert worden - dritter
  Karteileichen-Fund dieser Session (nach `DIDAKTIK_GROUP_CV.md` und den
  beiden ADR-Kandidaten oben) - Muster: ein Feature wird umgesetzt, aber
  die urspruengliche Vorschlags-Zeile im Backlog nie als erledigt markiert.
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

  **Erster Versuch am vorgeschlagenen Weg (2026-08-15,
  `openml-synthetic-control-timeseries`) - CPU-Machbarkeit bestaetigt,
  Kandidat selbst aber ungeeignet.** `mlr3torch::lrn("classif.ft_transformer")`
  lief auf CPU reibungslos (600 Zeilen: 15 Epochen in 163s, 60
  Produktions-Epochen hochgerechnet ~11 Min. - klar unter der
  30-Minuten-Schwelle aus `adr/002`, siehe dortiger neuer Datenpunkt). 5-fach
  CV gegen Ranger auf denselben Folds: FT-Transformer BAcc 0.9833 (Ranger
  0.9900) UND Cohen's Kappa 0.976 (98% Uebereinstimmung der Vorhersagen) -
  sowohl schwaecher als AUCH kaum dekorreliert. Kein Ensemble-Gewinn zu
  erwarten (dieselbe "schwaches+korreliertes-Mitglied"-Lehre wie beim
  urspruenglichen health_condition-Befund oben), daher NICHT bis zum
  fertigen Blend-Wert weitergerechnet. Grund vermutlich: `synthetic_control`
  ist zu sauber/einfach trennbar (i.i.d. Zeitreihen-Klassifikation, 6 exakt
  balancierte Klassen) - fuer echte Dekorrelation braucht es ein Projekt mit
  mehr Rauschen/komplexeren Interaktionen, wo Baummodelle und
  Aufmerksamkeitsmechanismen strukturell unterschiedliche Fehler machen.
  Voller Befund inkl. Skripte (`095_ft_transformer_timing.R`/
  `096_ft_transformer_cv_ensemble.R`) in `openml-synthetic-control-
  timeseries/README.md`. Naechster Versuch: ein Projekt mit mehr Zeilen/
  Rauschen als Kandidat waehlen, nicht denselben einfachen Fall wiederholen.

  **Zweiter Versuch (2026-08-15, `openml-eeg-eye-state-timeseries`) -
  Dekorrelation erstmals bestaetigt, aber neue offene Frage.** Bei VOLLER
  Zeilenzahl (14980) war CPU-Training NICHT tragfaehig (111 Min. bei 60
  Produktions-Epochen, weit ueber der `adr/002`-Schwelle - neuer
  Datenpunkt: die Zeilenschwelle liegt irgendwo zwischen 600 und 14980).
  Daher auf 4500 Zeilen stratifiziert subgesamplet, 15 Epochen, 5-fach CV
  (33.3 Min.): FT-Transformer BAcc 0.764/MCC 0.532 vs. Ranger BAcc
  0.869/MCC 0.744 - UND Cohen's Kappa **0.581** (79.5% Uebereinstimmung),
  **erstmals tatsaechlich dekorreliert** (< 0.7-Schwelle), klarer
  Gegensatz zu `synthetic_control`s Kappa 0.976. Bestaetigt: auf einem
  rauschigeren Datensatz existiert das gesuchte Diversitaets-Potenzial
  grundsaetzlich.

  **Blend-Wert offen geblieben**: ein Bug (vereinzelte NaN-Wahrschein-
  lichkeiten des unternetrainierten FT-Transformers bei nur 15 Epochen)
  liess die Blend-Auswertung abstuerzen - bewusst NICHT erneut 33 Minuten
  gezahlt, um nur diese eine Zahl nachzutragen (Dekorrelation war die
  eigentliche Frage dieses Tests), Bug im Skript aber gefixt (betroffene
  Zeilen werden jetzt ausgeschlossen statt den Lauf abzubrechen) fuer eine
  kuenftige Wiederholung.

  **Per-Klassen-gewichteter Blend gebaut und getestet (2026-08-17,
  `097_weighted_blend.R`) - Hebel 1 NICHT bestaetigt.** Statt der teuren
  5-fach-CV (33 Min.) ein einzelner stratifizierter Train/Tune/Eval-
  3-Wege-Split (wie `130_threshold_tuning.R`) - FT-Transformer nur EINMAL
  trainiert (4.1 Min.), Blend-Gewicht(e) auf Tune gesucht (skalar via
  `optimize()`, per-Klasse via Nelder-Mead ueber logit-reparametrisierte
  Gewichte), ehrlich auf Eval bewertet: FT-Transformer 0.6862, Ranger
  **0.8439**, Blend gleichgewichtet 0.7617, Blend skalar getunt
  (`w_ft`=0.067) 0.8403, Blend per-Klasse getunt 0.8378 - **kein Blend
  schlaegt das beste Einzelmodell** (bester Blend -0.0036 unter Ranger).
  Die Gewicht-Suche schaltete FT-Transformer fast komplett ab (~0.07-0.10
  statt 0.5), weil er auf diesem Split noch schwaecher war als im
  `096`-CV-Mittel (0.686 vs. 0.764) - plausibel durch weniger
  Trainingsdaten (2700 statt ~3600 Zeilen) UND keine Fold-Mittelung in
  der guenstigeren 1-Split-Variante, also eine methodische Einschraenkung
  dieses konkreten Tests, kein endgueltiger Beweis gegen einen staerker
  trainierten FT-Transformer. **Fazit fuer Hebel 1 ueber beide bisher
  getesteten Projekte**: in keinem Fall hat ein gewichteter Blend
  gewonnen - bei `synthetic_control` mangels Dekorrelation, bei
  `eeg-eye-state` trotz echter Dekorrelation wegen zu grossem
  Qualitaetsabstand. Ein dritter Testfall mit staerker trainiertem
  neuronalem Kandidaten waere der naechste Schritt, falls Hebel 1
  weiterverfolgt werden soll - aktuell KEIN Backport-Kandidat (0/2
  Projekte positiv). Voller Befund in
  `openml-eeg-eye-state-timeseries/README.md`.

  **Folgetest mit klassischen (statt neuronalen) guenstigen
  Diversitaetskandidaten (2026-08-17)**, Anlass: externe Projekt-
  Beurteilung schlug nnet/Ranger-ExtraTrees/kNN/SVM vor, Nutzer ergaenzte
  Naive Bayes/LDA/QDA. Sechs Kandidaten an zwei Projekten getestet
  (`health_condition`: nnet/ExtraTrees/kNN; `openml-steel-plates-fault`:
  SVM/Naive Bayes/LDA/QDA, siehe volle Zahlen in dessen README) - **wieder
  kein robuster Mehrwert**: nnet/ExtraTrees fast Ranger-Klone (Kappa
  0.96), kNN/SVM/NaiveBayes/LDA einzeln moderat dekorreliert (Kappa
  0.72-0.85) aber zu schwach, QDA auf diesem Datensatz technisch nicht
  lauffaehig (Rang-Defizit bei der kleinsten Klasse). Ein Test mit der
  ECHTEN Caruana-Greedy-Selektion (statt naivem Blend, Algorithmus
  identisch zu `149_ensemble_selection.R`) zeigte bei einem Seed einen
  scheinbaren Ensemble-Gewinn (+0.0155 BAcc gegenueber dem besten
  Einzelmodell, SVM/Naive Bayes/LDA tatsaechlich ausgewaehlt) - **eine
  Robustheits-Gegenprobe mit zweitem Seed widerlegte das** (-0.0036,
  schlechter als das beste Einzelmodell, obwohl SVM/NB erneut ausgewaehlt
  wurden) - vermutlich Ueberanpassung an eine kleine Selektionsmenge bei
  grosser Ensemblegroesse (23-49 von 50 Runden), dieselbe "Winner's
  Curse"-Kategorie wie bei `generalization_gap.R`. Ein echtes SVM-Tuning
  (30 Random-Search-Evals, log2-Suchraum) verschlechterte das Ergebnis
  sogar gegenueber den Default-Hyperparametern unter 5-facher CV (0.7418
  getunt vs. 0.7586 Default) - dieselbe Suchphasen-Ueberanpassung, hier am
  Tuning-Ergebnis selbst statt an einem nachgelagerten Modell beobachtet.
  **Fazit**: "guenstige klassische Diversitaetsmodelle" bleibt wie Hebel 1
  ohne belastbaren Erfolg - kein Backport-Kandidat. Volle Zahlen/Skripte
  (`098_ensemble_diversity_pool.R`, `098b_..._seed2.R`,
  `099_svm_tuning.R`) in `openml-steel-plates-fault/README.md`.

  **Folgetest mit TabICLv2 (tabular foundation model, 2026-08-18)**,
  Anlass: Nutzer teilte arXiv 2602.11139 (offenes In-Context-Learning-
  Modell, kein Training noetig, schlaegt laut Paper ungetuned Baum-
  Ensembles auf TabArena/TALENT). Anders als FT-Transformer kein GPU-
  Trainings-Umweg noetig - lokaler CPU-Test via schlankem Python-Export
  (venv + PyPI-Paket `tabicl`, bewusst kein `reticulate`, um R-Repos
  leichtgewichtig zu halten - siehe `openml-steel-plates-fault/README.md`
  fuer die volle Konventions-Begruendung). Zwei Projekte, identischer
  Split/Code fuer alle Modelle im selben Skript (fairer Vergleich, keine
  R-vs-Python-Zahlenmischung):
  - `openml-steel-plates-fault` (7-Klassen, 1941 Zeilen): TabICLv2 BAcc
    0.8562 - staerkstes Nicht-Baum-Modell dieser ganzen Testreihe, aber
    unter LightGBM (0.8746). Kappa vs. LightGBM 0.83 (moderat). Mehrheits-
    Blend (0.8708) kein Gewinn.
  - `openml-credit-g` (binaer, 1000 Zeilen, schwerer/verrauschter):
    TabICLv2 BAcc 0.6500 - SCHWAECHSTES der drei Modelle, sogar unter dem
    R-Baseline (LDA 0.699). Kappa vs. LightGBM 0.60 (erstmals echt
    "dekorreliert" nach der Kappa-Konvention), aber zu schwach - Blend
    (0.6679) wieder kein Gewinn.

  **Gegenprobe an 2 weiteren Projekten (2026-08-18)**, gleicher Aufbau
  (identischer Split/Code im selben Python-Skript):
  - `uci-parkinsons-voice-groupcv` (196 Zeilen, binaer): TabICLv2 BAcc
    **0.9828** vs. RandomForest/LightGBM je 0.8828 - **klarer Sieg**
    (+0.10), der erste in der gesamten Diversitaets-Testreihe. Der naive
    Mehrheits-Blend faellt trotzdem auf 0.8828 zurueck (RF+LightGBM
    ueberstimmen TabICLv2 2-zu-1) - starkes Argument fuer die GEWICHTETE
    Greedy-Selektion (`149`) statt eines starren Mehrheitsvotums.
  - `wdbc-plateau-test` (683 Zeilen, binaer, nahezu perfekt trennbar):
    TabICLv2 BAcc 0.9671, exakter Gleichstand mit RandomForest
    (Kappa=1.0000 - identische Vorhersagen).

  **Nachtrag (5. Projekt)**: `openml-synthetic-control-timeseries` (600
  Zeilen, 6 Klassen) - Gleichstand mit RandomForest (BAcc 1.0000,
  Kappa=1.0 - nahezu perfekt trennbarer Datensatz, Deckeneffekt, aehnlich
  `wdbc-plateau-test`).

  **Fazit ueber alle 5 Projekte**: kein konsistentes Muster (kleinster
  Datensatz gewinnt klar, mittelgrosse Projekte schwaecher/gemischt,
  Groesse allein erklaert es nicht). Kein Backport-Kandidat fuer den
  naiven Blend (wuerde den Vorteil dort, wo er auftritt, zunichtemachen),
  aber der erste Kandidat dieser Testreihe mit einem echten, deutlichen
  Einzelsieg.

  **Echte Greedy-Selektion statt naivem Blend** (`predictingsmartphoneAddiction_s6e8`,
  5000-Zeilen-Stichprobe aus 691K Zeilen - zu gross fuer TabICLv2 auf der
  CPU, Nutzer-Entscheidung fuer einen groessenbeschraenkten Machbarkeits-
  Test statt der vollen Daten): Pool aus RandomForest x2/LightGBM x2/
  CatBoost x2 (Referenz) + TabICLv2 x1, 3-Wege-Split. **TabICLv2 wird von
  allen 7 Kandidaten am HAEUFIGSTEN gezogen** (9 von 22 Selektionen) -
  Greedy-Ensemble-BAcc 0.8411 vs. bestes Einzelmodell 0.8382 (+0.003,
  klein aber echt). Anders als beim naiven Blend bei `parkinsons`
  (zerstoert TabICLv2s Vorsprung) bevorzugt die gewichtete Selektion
  TabICLv2 hier tatsaechlich. Effekt klein genug fuer Rauschen bei ~1000
  Bestaetigungszeilen - kein Beweis, aber ein ermutigendes Signal fuer
  einen kuenftigen GPU-gestuetzten Test auf den vollen Daten.

  Volle Herleitung, Paper-/Repo-Referenzen und Setup-Anleitung (Python-
  Export statt reticulate) in `REFERENZ_TABICLV2.md`.

  **MotherNet (arXiv:2312.08598, Microsoft, ICLR 2025) - aktuell NICHT
  testbar (2026-08-19).** Anlass: MotherNet erzeugt in einem Forward-Pass
  ein eigenstaendiges kleines MLP statt bei jeder Vorhersage ueber den
  vollen Trainings-Kontext zu attendieren - haette genau das `s6e8`-
  Vorhersage-Problem geloest (siehe oben). Setup-Versuch: Paket `ticl`
  (nur via GitHub installierbar) zieht eager die komplette Trainings-
  Abhaengigkeitskette (wandb/mlflow/gpytorch/interpret/... nachinstalliert),
  zusaetzlich ein PyTorch-Versionsbug in `ticl/models/layer.py` lokal
  gepatcht (`Optional`/`Dropout`/etc. nicht mehr aus
  `torch.nn.modules.transformer` re-exportiert). Danach lauffaehig, aber
  **Checkpoint-Download scheitert**: der einzige offizielle Host
  (`amuellermothernet.blob.core.windows.net`) existiert laut DNS nicht
  mehr (NXDOMAIN) - bestaetigt durch offenes, unbeantwortetes GitHub-
  Issue microsoft/ticl#27. Der HuggingFace-Spiegel enthaelt nur einen
  alten TabPFN-Referenz-Checkpoint, nicht die MotherNet-Gewichte.
  Eigentraining unpraktikabel (~4 Wochen/A100 laut Paper). Kein Test
  moeglich - vor einem erneuten Versuch zuerst pruefen, ob das Issue
  inzwischen geloest wurde. Volle Details in `REFERENZ_TABICLV2.md`
  Abschnitt 6.
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
- ~~**Fehlwert-Sentinels (numerisch, z.B. `-9999`) werden vom Template nicht
  erkannt**~~ **ERLEDIGT (2026-08-15), ueber den No-op-Pfad aus ADR-003
  backported (noch 1-Projekt-Beleg fuer den NUTZEN, aber strukturell inert
  und regressionsgetestet).** Anlass: `geoai-aquaculture-pond-
  identification-challenge` (Sentinel-codierte fehlende Monate in
  Fernerkundungsdaten). Die Imputationspipelines (`imputemedian`/
  `imputemode`) fangen nur echtes `NA` ab, nicht numerische Sentinel-Werte -
  die wirken sonst wie extreme, aber gueltige Messwerte. Projekt-lokal war
  das bisher inline in `prepare_aquaculture_data()` geloest (fester
  `sentinel_value <- -9999`, kein wiederverwendbarer Helfer).

  **Umsetzung**: neue Funktion `sentinel_to_na(x, sentinel_values)` in
  `040_preprocessing.R`, analog zu `empty_factor_to_na()` aber fuer
  numerische Spalten und mit konfigurierbarer Sentinel-Liste statt eines
  festen Werts. Neue Config-Variable `sentinel_values <- numeric(0)` in
  `000_config.R` (Default leer). `build_preprocessing_graph()` liest
  `sentinel_values` per `get0("sentinel_values", envir = globalenv(),
  ifnotfound = numeric(0))` als Default-Argument - dadurch muessen die 10
  bestehenden Aufrufstellen (`030`/`080`/`081`/`095`/`140`/`147`/`features/
  target_encoding.R`/etc.) NICHT angefasst werden, ein Projekt aktiviert den
  Schritt allein durch Setzen von `sentinel_values` in seiner `000_config.R`.
  Bei leerer Liste (Default) wird kein zusaetzlicher `po("colapply")`-Schritt
  in den Graphen eingefuegt - strukturell identisch zum Verhalten vor dieser
  Aenderung.

  **Begruendung fuer den Backport trotz nur 1-Projekt-Bestaetigung**: ADR-003
  erlaubt Backporten auch ohne zweites Projekt, wenn die Aenderung
  "nachweislich ein No-op" ist (Guard/Feature, das bei sauberen Daten korrekt
  still bleibt) - hier per Konstruktion erfuellt (Default leer -> kein
  Eingriff in den Graphen) UND per Test verifiziert: `ci_smoke_test/
  030_baseline.R` (kein `sentinel_values` gesetzt) laeuft byteidentisch zum
  Vorher-Zustand durch (gleiche Learner-IDs
  `imputemedian.imputemode.classif.*`, kein `sentinel_to_na`-Schritt im
  Graphen). Zusaetzlich isoliert getestet: `sentinel_to_na()` trennt Sentinel
  und echtes `NA` korrekt (`c(1, 2, -9999, 4, -9999, NA, 6)` ->
  `c(FALSE,FALSE,TRUE,FALSE,TRUE,TRUE,FALSE)` als `is.na()`-Maske); ein
  synthetischer Task mit `sentinel_values <- c(-9999)` zeigt nach
  `build_preprocessing_graph()$predict()`, dass der Sentinel-Wert verschwindet
  (median-imputiert) statt als Extremwert ins Feature einzufliessen. Der
  **NUTZEN** (verbessert das tatsaechlich einen Score?) bleibt trotzdem ein
  1-Projekt-Befund, bis ein zweites Projekt mit numerischen Sentinels
  auftritt - nur die STRUKTURELLE Integration ins Template gilt als
  abgeschlossen.

  **2. Projekt getestet (2026-08-21) - KEIN Nutzen bestaetigt, echter
  Negativbefund.** `pima-diabetes-sentinel-test` (UCI Pima Indians
  Diabetes, klassischer Lehrbuch-Sentinel-Fall: `0` kodiert fehlende
  Werte bei `glucose`/`blood_pressure`/`skin_thickness`/`insulin`/`bmi`,
  0.7-48.7% der Zeilen betroffen). Repeated 10x5-fold CV, Ranger UND
  logistische Regression (skaliert): korrekte spaltenspezifische
  Sentinel-Behandlung ist NICHT besser als roh (0 als Wert belassen) -
  bei BAcc/MCC leicht schlechter (beide Lerner), bei AUC nur marginal
  besser (+0.003 bis +0.006, innerhalb der CV-Rauschgrenze bei 768
  Zeilen). Selbst bei linearem Modell (wo der Sentinel-Effekt laut
  Lehrbuch am staerksten sein sollte) kein klarer Vorteil. **Damit
  1 positiver (aquaculture) + 1 negativer/neutraler (Pima) Datenpunkt** -
  der Nutzen ist projektspezifisch, kein generischer Score-Hebel.

  **Nebenbei ein echter Architektur-Fund**: `sentinel_to_na()` wendet die
  Sentinel-Liste GLOBAL auf ALLE numerischen Spalten an (kein
  Spalten-Scoping) - bei Pima ist `0` NUR bei 5 der 8 Features ein
  Sentinel, bei `pregnancies` ist `0` legitim (14.5% der Zeilen). Ein
  naives `sentinel_values <- c(0)` waere dort AKTIV SCHAEDLICH, nicht nur
  wirkungslos. Kandidat fuer eine Erweiterung (`sentinel_values` als
  benannte Liste statt eines flachen Vektors), angesichts des
  ausbleibenden Nutzens hier aber NICHT prioritaer verfolgt - kein
  aktiver Code-Kandidat, nur dokumentiert. Volle Herleitung in
  `pima-diabetes-sentinel-test/README.md`.
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
  Schritt 5 faengt den Rest ab). Details siehe `WORKFLOW_GUARDS.md`/
  `BACKLOG.md` im Regressions-Template.

  ~~**Kumulative Top-k-Schwelle - Backlog-Kandidat**~~ **BACKPORTIERT
  (2026-08-17).** Auf der Regressionsseite laengst an 2 Projekten
  bestaetigt (bike-sharing: echter Leak-PAAR-Fund, `casual+registered`==
  `count` exakt 100.0%; road-accident-risk: Gegenprobe, 3 legitime
  Features tragen zusammen 88%, korrekt NICHT geflaggt). Dieselbe
  Code-Logik (`share > threshold`, `cumsum()` ueber die Top-k) 1:1 nach
  `015_target_leak_audit.R` uebernommen: ein neuer kumulativer Check
  direkt nach Schritt 1, der die fuehrenden `leak_audit_cumulative_max_k`
  Features darauf prueft, ob sie ZUSAMMEN ueber `leak_audit_cumulative_
  share_threshold` (Default 0.98) der Gain-Importance tragen -
  SICHERHEITSBEDINGUNG: laeuft NUR, wenn Schritt 1 bereits mindestens
  einen Einzelverdaechtigen gefunden hat (erweitert einen bestehenden
  Verdacht, statt einen neuen aus einer sauberen Verteilung zu erzeugen -
  sonst haetten z.B. `steel-plates-fault`s oder `satimage`s legitime
  Top-Features faelschlich angeschlagen).

  **Synthetisch verifiziert** (da kein reales Klassifikationsprojekt mit
  genau dieser Leak-Paar-Struktur sofort verfuegbar war, analog
  `road-accident-risk`s Gegenprobe-Logik nachgebaut): Szenario A (`class`
  aus `leak_a + leak_b > median`, 2 Features tragen zusammen fast 100%,
  `leak_b` allein bereits 51.0% > Einzelschwelle) - der kumulative Check
  erweitert korrekt um `leak_a` (zusammen 99.6% > 98%). Szenario B (3
  legitime, unabhaengige Features tragen zusammen 93.5%, keins einzeln
  ueber 35.8%) - Sicherheitsbedingung greift korrekt, kein Einzelverdacht
  vorhanden, Check uebersprungen, keine Fehlalarme. Regressionsgetestet
  gegen `ci_smoke_test`: unveraendertes Verhalten (keine Verdaechtigen,
  kumulative Erweiterung korrekt uebersprungen).

  **Realer Klassifikations-Anlass fuer den Port**: `CreditScoringChallenge`
  (African Credit Scoring) - die repay+funding-Feature-Gruppe (`Total_
  Amount_to_Repay`/`interest_ratio`/`repay_minus_amount`/`Lender_portion_
  to_be_repaid`) senkt F1 von 0.876 auf ~0.41, aber keines der Features ist
  zwingend einzeln ueber 50% (aeltere, ad-hoc-Analyse, nicht mit dem
  aktuellen `015`-Skript reproduziert).

  **Nachgeholt (2026-08-17), aber KEINE positive Bestaetigung - ein
  aufschlussreicher Grenzfall statt eines Trigger-Falls.** Das aktuelle
  `015`-Skript (inkl. kumulativer Schwelle) direkt auf `CreditScoring
  Challenge`s Rohdaten angewandt: kein Feature ueberschreitet einzeln die
  50%-Schwelle (`Total_Amount_to_Repay` 23.6%, `Total_Amount` 22.0%,
  `loan_type` 12.9%, `Amount_Funded_By_Lender` 10.6%, `Lender_portion_
  to_be_repaid` 9.4%) - die Sicherheitsbedingung blockiert die kumulative
  Pruefung komplett. Nachgerechnet: selbst OHNE Sicherheitsbedingung
  waere erst bei `max_k=11` (statt 5) die 98%-Schwelle ueberschritten -
  das haette dann aber 11 von 13 Features als "verdaechtig" markiert,
  genau das im Kopfkommentar des Moduls selbst befuerchtete Szenario
  ("gleichmaessig verteilte Importance -> triviale Schwellenerschoepfung").
  Dieser reale Leak ist DIFFUS ueber 5 Features verteilt, nicht in 1-2
  dominanten konzentriert wie beim Bike-Sharing-Regressions-Anlassfall -
  die konservative Auslegung (Sicherheitsbedingung + `max_k=5`) bleibt
  hier also korrekt zurueckhaltend, auf Kosten davon, diesen Leak nicht
  zu fangen. Volle Herleitung in `CreditScoringChallenge/README.md`.

  **Echte POSITIVE Bestaetigung gefunden (2026-08-20) - ERLEDIGT.**
  Gezielt (statt zufaellig) nach einem Datensatz mit dokumentiertem
  Ex-post-Leak gesucht: `sba-loan-default` (SBA Loans Case Data Set,
  Kaggle `larsen0966/sba-loans-case-data-set`, CC0, extern als
  Lehrbeispiel fuer Target-Leakage dokumentiert). Zwei Runden:
  - **Runde 1** (alle Rohfeatures): `MIS_Status` traegt 100% Gain-
    Importance - eine EXAKTE 1:1-Duplizierung des Ziels (kein Leak im
    eigentlichen Sinn, sondern das Label selbst), so dominant, dass die
    Kumulativ-Erweiterung nichts findet (Top-1 schon bei 100%,
    `ChgOffPrinGr`/`ChgOffDate` bekommen praktisch 0% Importance, weil
    ein Baum sie neben dem perfekten Duplikat nie braucht). Lehre: ein
    exaktes Label-Duplikat verdraengt jede weitere Leak-Erkennung.
  - **Runde 2** (`MIS_Status` entfernt, wie es ein Data Scientist ohnehin
    VOR jeder Analyse taete): `ChgOffDate` traegt 91.0% (Einzelschwelle
    ausgeloest), die kumulative Top-2-Summe mit `ChgOffPrinGr` (+7.0%)
    erreicht 98.1% - `ChgOffPrinGr` wird korrekt als NEU markiert
    ("Verdacht auf ein Leak-PAAR/eine Leak-GRUPPE"), genau das gesuchte
    Bike-Sharing-analoge Muster.

  **Quantifizierter Beweis, warum das zaehlt**: volles Modell BAcc
  0.9965. NUR `ChgOffDate` entfernt (Einzelschwelle allein) -> BAcc
  **weiterhin 0.9965, keine Aenderung** (der Baum verlagert sich
  komplett auf das redundante `ChgOffPrinGr`, derselbe geleakte Score).
  Erst BEIDE entfernt -> BAcc 0.8624, der ehrliche Wert. Ein Data
  Scientist, der nur der Einzelschwelle vertraut, haette faelschlich
  angenommen, der Leak sei behoben. Volle Herleitung in
  `sba-loan-default/README.md`. Erfuellt die ADR-003-Schwelle "1. realer
  Anlass bestaetigt" (1. Bestaetigung, 2. unabhaengige noch offen, aber
  kein aktiver Suchauftrag mehr - der Backport war ohnehin schon
  synthetisch abgesichert und default-inert).

  **2. Bestaetigung gesucht (2026-08-21) - KEIN Treffer, aber ein
  verwandter Negativbefund.** `aer-creditcard-leak-test` (AER Credit
  Card Data, Greene - der Datensatz aus dem offiziellen Kaggle-Learn-
  "Data Leakage"-Tutorial, ueber das CRAN-Paket `AER` geladen statt
  Kaggle-Download). Drei Runden: (1) volle Features - `expenditure`
  dominiert einzeln mit 89.2% (Ex-post-Feature: Kartenausgaben nur MIT
  bereits genehmigter Karte moeglich); (2) `expenditure` entfernt - das
  stark korrelierte `share` (= expenditure/income, r=0.84) uebernimmt
  fast identisch mit 89.5%, wieder EIN einzelnes dominantes Feature,
  keine kumulative Zusatzerkennung; (3) BEIDE entfernt - sauber, kein
  Feature ueber 30%. **Unterschied zu sba-loan-default**: dort ein
  echtes Leak-PAAR mit unterschiedlichem Einzelgewicht (91%+7%=98.1%
  kumulativ), hier eine 2-stufige Substitutionskette aus praktisch
  redundanten Features, die sich 1:1 ersetzen statt gemeinsam in
  moderaten Anteilen beizutragen - strukturell naeher am `MIS_Status`-
  Verdraengungseffekt als am gesuchten kumulativen Muster. Volle
  Herleitung in `aer-creditcard-leak-test/README.md` (nur lokal
  committet, kein Push-Ziel fuer `ML_Learning`). **2. unabhaengige
  Bestaetigung bleibt offen** - Suche geht weiter.

  **Weiterer Versuch (2026-08-21), ebenfalls kein Treffer.**
  `gmsc-leak-test` (Give Me Some Credit, Kaggle 2011): die oft als
  "Leakage"-Beispiel zitierten PastDue-Zaehler (NumberOfTime30-59/60-89
  DaysPastDueNotWorse, NumberOfTimes90DaysLate) sind bei genauerem
  Hinsehen legitime HISTORISCHE Praediktoren, kein Ex-post-Leak - kein
  Feature ueber 30-50%, kumulative Erweiterung gar nicht ausgeloest.
  Wertvoll als zusaetzliche Spezifitaets-Bestaetigung (stark korrelierte
  legitime Praediktoren loesen keinen falschen Verdacht aus), aber kein
  Fortschritt fuer die 2. Bestaetigung. Volle Herleitung in
  `gmsc-leak-test/README.md`. Erkenntnis aus beiden Fehlversuchen: gut
  dokumentierte "Leakage-Lehrbeispiele" sind entweder (a) eine einzelne/
  redundante dominante Substitution (AER) oder (b) gar kein echter Leak,
  nur eine missverstandene starke legitime Korrelation (GMSC) - fuer das
  gesuchte VERTEILTE Gruppen-Muster (wie SBA/Bike-Sharing) braucht es
  offenbar einen Datensatz mit MEHREREN, jeweils NUR TEILWEISE
  informativen Ex-post-Feldern (z.B. mehrere getrennte Zahlungs-/
  Abschluss-Felder wie bei Lending-Club-Rohdaten total_pymnt/recoveries/
  last_pymnt_amnt) statt einem einzelnen starken Praediktor oder dessen
  Duplikat/Substitut - naechster Kandidat waere ein Lending-Club-Mirror
  mit unbereinigten Post-Outcome-Spalten (Suche abgebrochen: verfuegbare
  Mirrors waren entweder zu gross/login-pflichtig oder bereits
  leak-bereinigt).

  **Lending Club (2026-08-21, Nutzer hat `loan.csv` manuell von Kaggle
  `adarshsng/lending-club-loan-data-csv` besorgt) - KEIN Treffer fuer das
  gesuchte Muster, aber ein WICHTIGERER, unerwarteter Fund.**
  `lending-club-leak-test` (1.303.607 Zeilen, Fully Paid vs. Charged Off,
  10 bekannte Post-Outcome-Kandidaten: out_prncp(_inv), total_pymnt(_inv),
  total_rec_prncp/_int/_late_fee, recoveries, collection_recovery_fee,
  last_pymnt_amnt): staerkstes Feature `int_rate` nur 18.9% Gain - die
  Einzelschwelle (30/50%) bleibt VOELLIG still, kumulative Erweiterung
  wird nie ausgeloest. **Trotzdem bricht der ehrliche Score massiv ein**:
  BAcc voll 0.9983 vs. ohne alle 10 Post-Outcome-Felder **0.5317**
  (praktisch Zufallsniveau) - der GROESSTE je in diesem Template
  gemessene Leak-Effekt, deutlich groesser als SBA (0.9965->0.8624), und
  der Guard haette ihn NICHT gefunden. Die 10 Leak-Features tragen
  zusammen nur ~31% Gain - selbst ein hypothetischer "kumulativ ohne
  Ausgangsverdacht"-Modus mit hoher Schwelle haette das nicht gefangen,
  die Gain-Verteilung selbst ist irrefuehrend, nicht nur unkonzentriert.
  **Wahrscheinliche Ursache**: LightGBM-Gain-Importance summiert Gain
  UEBER ALLE Splits/Baeume - ein hochentscheidendes Feature, das nur in
  wenigen fruehen Splits genutzt wird, sammelt weniger KUMULIERTEN Gain
  an als legitime Features, die fuer viele feine Splits wiederverwendet
  werden (bekanntes Problem von Split-/Gain-basierter Importance in der
  Literatur, Permutation-/SHAP-Importance waeren robuster, aber teurer).
  Volle Herleitung in `lending-club-leak-test/README.md`. **Einordnung**:
  dies ist die 2. unabhaengige Bestaetigung, dass Schritt 1 (Gain-
  Konzentration) einen massiven diffusen Leak systematisch uebersehen
  kann (1. war CreditScoringChallenge, 5-Feature-diffuser Leak, dort aber
  MEHRHEIT der Gain-Importance) - hier ist der Fall staerker: nur ~31%
  Gain-Anteil reicht schon fuer einen fast-vollstaendigen Score-Einbruch.
  **Offene Entscheidung fuer den Nutzer** (nicht eigenmaechtig
  entschieden): Guard um einen Pflicht-Decomposition-Schritt (Schritt 4
  IMMER laufen lassen, nicht nur bei bestehendem Verdacht) oder eine
  robustere Importance-Methode erweitern, oder als dokumentierte
  Guard-Grenze stehen lassen. **Die urspruenglich gesuchte 2.
  Bestaetigung fuer das SBA-analoge Leak-PAAR-Muster bleibt weiterhin
  offen** - drei Versuche (AER/GMSC/Lending-Club), keiner hat es
  reproduziert.

  **Guard-Verbesserung versucht (2026-08-21) - Teilerfolg, keine
  vollstaendige Loesung.** Nutzerentscheidung: Guard um einen Mechanismus
  erweitern, der einen ueber viele redundante Features verteilten Leak
  auch OHNE Einzelverdacht findet. Zwei Ansaetze getestet:
  - **Korrelations-Cluster-Zerlegung (implementiert, behalten)**: neuer
    "Schritt 1b" in `015_target_leak_audit.R` - numerische Features nach
    paarweiser Korrelation clustern, groessten Cluster (nach summierter
    Gain-Importance) per Retraining testen, nur bei Score-Abfall
    `>leak_audit_cluster_drop_threshold` (15 Punkte) als Verdacht flaggen.
    **Ergebnis am Lending-Club-Fall selbst**: zeigt immerhin ein
    informatives 7.9-Punkte-Signal (vorher: NICHTS sichtbar), ueberschreitet
    die Warnschwelle aber NICHT - bei Korrelationsschwelle 0.5 vermischt
    der groesste Cluster legitime Groessen-Features (`loan_amnt`,
    `funded_amnt`, `installment`) mit den echten Leak-Feldern (Kontamination,
    verwaessert den Effekt); bei Schwelle 0.8 trennt er sauber, aber
    `total_rec_int`/`last_pymnt_amnt` werden zu Singletons und fallen aus
    jedem >=2er-Cluster raus (Fragmentierung) - kein Cluster erreicht dann
    ueberhaupt die 30%-Vorfilter-Schwelle. Ein echter NA-Bug beim Clustern
    (Nullvarianz-Spalte macht auch die Diagonale der Korrelationsmatrix
    `NaN`) wurde dabei gefunden und gefixt (`diag(cor_mat) <- 1` nach dem
    NA-Fixup erzwingen).
  - **Iterative Einzelfeature-Entfernung (getestet, NICHT implementiert)**:
    wiederholt das staerkste Gain-Feature entfernen+neu trainieren (12
    Runden). Ergebnis: BAcc bleibt bei ~0.998 durch 11 Runden (obwohl 5 der
    10 bekannten Leak-Felder darunter entfernt wurden), faellt erst in
    Runde 12 (6 von 10 Leak-Feldern + 6 legitime Features entfernt) auf
    0.9655 - IMMER NOCH weit ueber dem ehrlichen Wert 0.5317. Zeigt, wie
    EXTREM redundant diese spezielle Leak-Gruppe ist (die verbleibenden 4
    Leak-Felder allein tragen fast die volle Leistung) - ein generischer
    Ansatz braeuchte hier unpraktikabel viele Retrainings, um zuverlaessig
    zu greifen. Verworfen (zu teuer, zu unzuverlaessig).
  **Entscheidung**: Korrelations-Cluster-Check BEHALTEN (echte, wenn auch
  unvollstaendige Verbesserung, bei sauberen Projekten praktisch kostenlos -
  regressionsgetestet gegen `health_condition` (still, byte-identische
  Schritt-1-Werte), `sba-loan-default` (Detektion unveraendert, 91%+7%=98.1%),
  `aer-creditcard-leak-test` (still, kein False Positive)). Der
  Lending-Club-Extremfall selbst bleibt eine dokumentierte, bewusst
  akzeptierte Guard-Grenze - siehe README_DETAILS.md "Target-Leakage-Audit"
  Schritt 1b fuer die volle Einordnung.

  **Positive synthetische Bestaetigung des Schritt-1b-Mechanismus
  (2026-08-21, `synth-redundant-leak-test`).** Statt eines weiteren echten
  Datensatzes (3 Fehlversuche bereits) ein kontrollierter Ground-Truth-
  Test: 50k Zeilen, 5 legitime + 4 outcome-abgeleitete "Leak"-Features mit
  gemeinsamem latentem Faktor + eigenstaendigem Rauschen, paarweise
  Korrelation 0.55-0.56 (deutlich unter Lending Clubs praktischer
  Fast-1.0-Substituierbarkeit). Ergebnis: **Schritt-1b funktioniert wie
  beabsichtigt** - staerkstes Einzelfeature nur 30.7% (unter der 50%-
  Warnschwelle, Guard waere ohne Schritt 1b still geblieben), Cluster-
  Check findet die Gruppe SAUBER (keine Kontamination durch die legitimen
  Features), Score-Abfall 29.8 Punkte klar ueber der 15-Punkte-Schwelle,
  WARNUNG korrekt ausgeloest, Schritt 4 bestaetigt identisch. Bestaetigt:
  der Mechanismus selbst ist tragfaehig - Lending Clubs Fast-Perfekt-
  Redundanz (10 Felder, ~1.0 gegenseitige Substituierbarkeit) war ein
  besonders haerter Extremfall, kein Hinweis auf einen fundamentalen
  Designfehler. Volle Herleitung in `synth-redundant-leak-test/README.md`.

  **Erweiterte Suche (2026-08-17), 17 reale Projekte gegen die
  Einzelschwelle geprueft** (Werte per LightGBM-Gain-Importance, hoechster
  zuerst): `s6e8` 49.3%, `amazon-access` 46.7% (`MGR_ID`), `health_
  condition` 42.9%, `bank-marketing` 39.4% (`duration`), `richter` 39.0%
  (`geo_level_1_id`), `s6e6` 37.4%, `s5e12` 34.9%, `adult-income` 26.2%,
  `credit-g` 26.9%, `CreditScoringChallenge` 23.6%, `s6e5` 29.2%, weitere
  <20%. **Kein einziges Projekt ueberschreitet 50%** - der engste Fall
  (`s6e8`) verfehlt sie nur knapp. Alle gepruefteten Naeherungsfaelle
  liessen sich inhaltlich plausibel als legitime Signale einordnen
  (Bildschirmzeit bei Sucht-Vorhersage, Managerfreigabe bei
  Zugriffsrechten, Anrufdauer bei Verkaufsgespraechen), keine weitere
  Untersuchung ausgeloest.

  **Daraus abgeleitet: neue informative Vorstufe statt Schwellen-
  Absenkung.** Nutzeridee nach dieser Suche: eine niedrigere Schwelle
  haette bei 7/17 Projekten ausgeloest (34.9-49.3%), obwohl alle sieben
  bereits als legitim eingeordnet wurden - eine Absenkung der HARTEN
  50%-Schwelle haette die "selten, aber berechtigt"-Eigenschaft des
  Guards verwaessert, UND haette den einen bekannten echten (aber
  diffusen) Leak-Fall trotzdem nicht gefangen (`CreditScoringChallenge`,
  kein Feature ueber 24%). Stattdessen: `leak_audit_advisory_share_
  threshold` (Default 0.30) ergaenzt - das staerkste Feature wird jetzt
  IMMER mit exakter Zahl + qualitativer Einordnung ausgegeben (`<10%`
  KLEIN, `10-30%` MITTEL, `30-50%` HOCH - nur Hinweis, `>=50%` SEHR HOCH -
  WARNUNG wie bisher). Der HOCH-Hinweis loest NICHTS in Schritt 3/4/5 aus
  (keine Zerlegung, kein Ausschluss) - rein informativ fuer den
  menschlichen Blick. Synthetisch verifiziert (HOCH bei 49.6%, SEHR HOCH
  bei 83.2% korrekt eingeordnet) und regressionsgetestet gegen
  `ci_smoke_test` (unveraendertes Verhalten, `x1` bei 28.5% korrekt als
  MITTEL eingeordnet, kein Hinweis ausgeloest).
- ~~**Nested/gepooltes per-Fold-Threshold-Tuning fehlt**~~ **ERLEDIGT
  (2026-08-15), ueber den No-op-Pfad aus ADR-003 backported.** Anlass:
  `CreditScoringChallenge`, Verfeinerung zu `130_threshold_tuning.R`. Der
  bestehende einzelne stratifizierte 3-Wege-Split (Train/Tune/Eval) nutzt
  nur einen Bruchteil der Daten fuer Multiplikator-Suche UND Bewertung - die
  in `CreditScoringChallenge/040_threshold_tuning.R` projekt-lokal gebaute
  "Nested"-Variante (binaer, F1-spezifisch, eigene Suchlogik) war dort
  Grundlage einer fast perfekten CV-LB-Kalibrierung.

  **Umsetzung**: statt die binaere F1-Suchlogik zu kopieren,
  `nested_cv_class_multiplier_tuning()` neu in `class_multiplier_tuning.R`
  - verallgemeinert das Prinzip (K-fach-CV-OOF-Vorhersagen, Multiplikatoren
  je Fold NUR auf den UEBRIGEN Folds suchen, gepoolt anwenden -> ehrliche
  Schaetzung ohne Datenleck zwischen Suche und Bewertung; finale
  Deployment-Multiplikatoren separat auf ALLEN OOF gesucht) generisch fuer
  beliebige Klassenzahl/Metrik, indem sie das bereits vorhandene
  `tune_class_multipliers()` wiederverwendet (das den binaeren 1D-Fall via
  `optimize()`/Brent und den Multiklassen-Fall via Nelder-Mead schon
  automatisch unterscheidet, siehe `REFERENZ_NELDER_MEAD.md`) - keine
  Logik-Duplikation. Opt-in in `130_threshold_tuning.R` ueber
  `threshold_tuning_nested` (Default `FALSE`, `000_config.R`) - laeuft nur,
  wenn ein Projekt es explizit aktiviert, erzeugt dann zusaetzlich
  `threshold_tuning_nested_results.csv` neben den bestehenden Ergebnissen,
  ohne diese zu veraendern.

  **Regressionsgetestet gegen `ci_smoke_test`**: Default (`FALSE`) liefert
  byteidentische Ergebnisse zum Vorher-Zustand. Mit `TRUE` aktiviert: nested
  BAcc 0.6160 vs. 0.5617 beim bestehenden 3-Wege-Split (mehr Daten fuer
  Suche UND Bewertung, weniger Rauschen - erwartungsgemaess). `130` laeuft
  im CI-Smoke-Test nicht mit (nicht in dessen Kopierliste), daher keine
  CI-Aenderung noetig; die neue Funktion wird von keinem der CI-Kernskripte
  geladen. Noch 1-Projekt-Kandidat fuer den NUTZEN (CreditScoringChallenge)
  - die STRUKTURELLE Integration ins Template gilt als abgeschlossen.
- ~~**Zwei implizite Architekturentscheidungen als ADR-Kandidaten
  vorgemerkt (2026-08-08)**~~ **ERLEDIGT - Karteileiche korrigiert
  (2026-08-15).** Diese Notiz war laengst veraltet: beide Entscheidungen
  wurden bereits am 2026-08-12 zu eigenen ADR-Dateien ausgebaut -
  [`adr/005-targets-covers-production-path-only.md`](adr/005-targets-covers-production-path-only.md)
  ((a) `targets`-Pipeline deckt bewusst nur den finalen Produktionspfad ab)
  und
  [`adr/006-identical-db-schema-across-templates.md`](adr/006-identical-db-schema-across-templates.md)
  ((b) identisches `experiments.db`-Schema). Diese TARGETS.md-Zeile wurde
  seither einfach nicht mehr aktualisiert - derselbe Karteileichen-Fehler
  wie bei `DIDAKTIK_GROUP_CV.md` (siehe dortiger Eintrag oben): ein
  Status-Update an einer Stelle (hier: neue ADR-Datei) zieht nicht
  automatisch die Querverweise an anderer Stelle nach.
- **Drei Ideen aus "Automated Machine Learning" (Hutter/Kotthoff/Vanschoren
  2019, offenes Springer-Buch) geprueft (2026-08-08)** - Kap. 1
  (Hyperparameter Optimization), Kap. 2 (Meta-Learning), Kap. 6
  (Auto-sklearn):
  - **Caruana-Greedy-Ensemble-Selection: 2-Projekt-Kriterium ERFUELLT,
    bereit zum Backporten.** Statt ein Einzelmodell zu waehlen
    (`148_select_submission_model.R`) oder wenige Modelle gleichzugewichten,
    einen Pool bereits trainierter Modelle per gieriger Vorwaertsauswahl
    (mit Wiederholung erlaubt, Caruana et al. 2004, wie in Auto-sklearn)
    zu einem Ensemble kombinieren. Verifiziert an ZWEI unabhaengigen,
    bewusst unterschiedlichen OpenML-Datensaetzen (Skript-Pool in
    `ML_Learning/openml-bank-marketing-ensemble-test/`, kein eigenes
    Projekt-Repo, standalone): bank-marketing (id 1461, 45211 Zeilen, stark
    unbalanciert ~11.7% positiv, gemischt kategorial/numerisch) und
    electricity (id 151, 45312 Zeilen, balanciert ~42.5%/57.5%,
    ueberwiegend numerisch). Pool je 45 Modelle (15 LightGBM/10 XGBoost/10
    CatBoost/10 ranger, variierte Hyperparameter), 3-Wege-Split
    Train/Valid/Test, Selektion NUR auf Valid, Test bleibt bis zum Schluss
    unberuehrt.
    | Datensatz | bestes Einzelmodell | Blend gleichgewichtet (45) | Greedy-Ensemble |
    |---|---:|---:|---:|
    | bank-marketing | 0.9326 | 0.9307 | **0.9348** |
    | electricity | 0.9740 | 0.9515 | **0.9743** |
    Greedy-Ensemble schlaegt in BEIDEN Faellen das beste Einzelmodell UND
    (deutlich staerker) den naiven Gleichgewichts-Blend - bestaetigt erneut
    "ein schwaecheres Modell verwaessert einen gleichgewichteten Blend",
    zeigt aber auch den Ausweg: die Methode konzentriert sich adaptiv auf
    wenige starke Modelle (electricity: `lgb_8` 27x von 34 gewaehlt), statt
    naiv gleichzugewichten. Laufzeit je Test ~7 Minuten (45-Modell-Pool),
    weit unter der 30-Minuten-Schwelle aus `adr/002-r-only-python-gpu-export.md`.
    **Integrationsaufwand vor dem echten Backport**: Benchmark-Skripte
    (`080`/`090`/`100` etc.) loggen aktuell nur die finale Metrik nach
    `experiments.db`, nicht die Vorhersagen jedes einzelnen Kandidaten auf
    einem gemeinsamen Holdout - das braeuchte die Selektion aber. Ein neues
    Modul (Arbeitstitel `149_ensemble_selection.R`, zwischen `148` und `150`)
    muesste diese Vorhersagen systematisch sammeln koennen. Noch nicht
    gebaut - naechste Session.
    **Update (2026-08-11): gebackportet.** Statt die bestehenden
    Benchmark-Skripte umzubauen (groesserer Eingriff, mehr Risiko), neues
    `148_ensemble_candidate_pool.R`: baut auf dem `147`-Artefakt auf
    (train/eval-Split + manuell imputierte Daten, kein neuer Split),
    trainiert einen Pool aus 24 Kandidaten (8 Ranger/8 LightGBM/8 CatBoost,
    variierte Hyperparameter per `expand.grid`+Zufallsstichprobe, analog zur
    Standalone-Verifikation, aber 3 statt 4 Familien - kein XGBoost als
    neue Abhaengigkeit) und speichert die Wahrscheinlichkeits-Matrizen aller
    Kandidaten auf dem Eval-Split. Laufzeit: 18.7 Minuten (24 Kandidaten,
    Ranger mit `num.trees=200` dominiert die Zeit, ~45s je Modell) - unter
    der 30-Minuten-Schwelle aus `adr/002-r-only-python-gpu-export.md`.
    Neues `149_ensemble_selection.R`: generalisiert die binaere AUC-Version
    aus der Standalone-Verifikation auf 3-Klassen-BAcc mit
    Wahrscheinlichkeits-Matrizen (elementweise gemittelt, Klasse = Argmax).
    Splittet den 147-Eval-Split weiter in Selektions-/Bestaetigungsmenge
    (`ensemble_selection_valid_ratio`, Default 0.5, klassenstratifiziert) -
    die Selektion darf nicht auf denselben Zeilen laufen, auf denen sie
    bewertet wird. **Ergebnis gegen health_condition (3. Bestaetigung nach
    bank-marketing/electricity, hier als Regressionstest gegen das
    Template-eigene Projekt, kein neues externes Datenset noetig)**:
    Bestes Einzelmodell (Selektions-BAcc) = `ranger_3`, Bestaetigungs-BAcc
    0.8806; gleichgewichteter Blend (alle 24) 0.8680 (schlechter als das
    beste Einzelmodell - bestaetigt erneut "ein schwaecheres Modell
    verwaessert einen gleichgewichteten Blend"); **Greedy-Ensemble 0.8822**
    (36 Modelle, davon `ranger_3` 28x, `ranger_6` 7x, `ranger_8` 1x -
    konzentriert sich fast ausschliesslich auf Ranger, konsistent damit,
    dass Ranger hier laengst die staerkste Familie ist, siehe die
    `147_error_analysis_ranger_*`-Namensgebung). Config-Ergaenzung in
    `000_config.R`: `ensemble_pool_n_per_family`/`ensemble_candidate_pool_path`/
    `ensemble_selection_rounds`/`ensemble_selection_valid_ratio`/
    `ensemble_selection_results_path`. DB-Logging analog zu den uebrigen
    Finalvergleich-Skripten (drei `model_config`-Zeilen: best_single/
    equal_blend/greedy_ensemble).
    **Luecke geschlossen (2026-08-11, gleicher Tag)**: `149_ensemble_
    selection.R` speichert jetzt zusaetzlich die eindeutigen ausgewaehlten
    Kandidaten+Gewichte (`ensemble_composition_path`, nicht jede Wiederholung
    einzeln). Neues `156_train_full_ensemble.R` trainiert nur diese
    eindeutigen Kandidaten auf dem VOLLEN Trainingsdatensatz (690k Zeilen -
    deutlich teurer als die 55k-Suchstichprobe: 127 Minuten fuer 3 Ranger-
    Modelle, `num.trees=200`, Kostenschaetzung vorab war zu niedrig, siehe
    [[feedback_runtime_cost_awareness]]-Lehre). Neues `157_predict_ensemble_
    submission.R` mittelt die Testvorhersagen GEWICHTET (Gewicht = wie oft
    in `149` gewaehlt) und schreibt `submission_ensemble.csv` (bestehende
    `submission.csv` bleibt unangetastet). End-to-end gegen health_condition
    verifiziert: 295753 Zeilen (= test.csv), Klassenverteilung plausibel,
    94.06% Uebereinstimmung mit der bestehenden Einzelmodell-Submission
    (sinnvoll unterschiedlich, nicht identisch/kaputt). Der Entscheidungs-
    Loop ist damit vollstaendig geschlossen: 148/149 entscheiden, 156/157
    deployen.
    **Echter Bug gefunden + behoben (2026-08-12), aufgedeckt durch eine
    Kaggle-Einreichung**: der Nutzer reichte `submission_ensemble.csv` ein
    (LB 0.87504, Rang ~2022) und verglich mit einer fruehen Einzelmodell-
    Submission vom 15.07. (LB **0.94740**) - eine Luecke von ~0.072, viel zu
    gross fuer reines Stichprobenrauschen. Ursache: `148_ensemble_candidate_
    pool.R` baute den Trainings-Task OHNE die Gewichtsspalte aus dem
    `147`-Artefakt (`train_imputed[, c(target_col_name, feature_cols)]` liess
    `"weight"` versehentlich weg), obwohl `147` selbst gewichtet trainiert -
    der GESAMTE 24er-Pool, die Selektion und das erste deployte Ensemble
    liefen dadurch ungewichtet, waehrend das etablierte Einzelmodell-
    Deployment (`150`/`155`) mit `class_weight_power=1.5` gewichtet - laut
    Memory der mit Abstand groesste BAcc-Hebel dieses Projekts (~0.87 roh vs.
    ~0.94-0.95 gewichtet, deckt sich fast exakt mit der beobachteten Luecke).
    **Fix**: `148` und `156` nutzen jetzt `add_balanced_class_weights()`
    (identischer Helfer wie `150`), mit einem `"weights" %in% learner$
    properties`-Check je Kandidat (Fallback ungewichtet, falls ein Learner
    keine Gewichte unterstuetzt - kommt bei Ranger/LightGBM/CatBoost hier
    nicht vor). **Korrigierte Zahlen** (24 Kandidaten, alle gewichtet
    trainiert, 60.2 Min. Pool-Training statt 18.7 - Gewichtung kostet
    spuerbar Laufzeit):

    | Ansatz | Bestaetigungs-BAcc (korrigiert) |
    |---|---:|
    | Gleichgewichteter Blend (24) | **0.9524** |
    | Greedy-Ensemble (10 Positionen, 4 eindeutige Modelle) | 0.9484 |
    | Bestes Einzelmodell (lightgbm_10) | 0.9484 |

    Passt jetzt gut zum bekannten LB-Referenzwert (0.9474). **Neuer, echter
    Befund**: mit korrekter Gewichtung gewinnt der EINFACHE BLEND lokal
    ueber Greedy (0.9524 vs. 0.9484) - Umkehrung des urspruenglichen
    (fehlerhaften) Ergebnisses. Plausibler Mechanismus: Gewichtung macht alle
    24 Kandidaten deutlich staerker UND aehnlicher (weniger "schwaches Glied"
    zum Vermeiden) - genau die in `REFERENZ_ENSEMBLE_SELECTION.md` Abschnitt
    5 dokumentierte Grenze der Methode (braucht einen diversen Pool mit
    echtem Staerke-Unterschied). Nutzer entschied sich trotzdem fuer das
    guenstigere Greedy-Ensemble (4 statt 24 Modelle neu zu trainieren, der
    Abstand zum Blend ist klein und bei n=6902 nicht sicher robust).
    `156`/`157` erneut gelaufen (17.7 Min. statt 127 - nur noch 1 Ranger statt
    3): neue `submission_ensemble.csv` stimmt jetzt zu **98.15%** mit der
    bekannten guten Einzelmodell-Submission ueberein (vorher 94.06%) -
    starke Bestaetigung, dass der Fix korrekt war. **Lehre**: ein lokaler
    Holdout-Wert kann durch das stille Weglassen eines etablierten,
    kritischen Preprocessing-Schritts systematisch verzerrt sein, ohne dass
    ein Fehler auftritt - ein echter, bekannter Referenzwert (hier: eine
    tatsaechliche LB-Einreichung) ist der zuverlaessigste Weg, das
    aufzudecken. Betraf ausschliesslich health_condition (BAcc + Klassen-
    gewichtung) - die anderen Bestaetigungen (bank-marketing/electricity/
    road-accident-risk/s6e6/s6e8) sind von diesem spezifischen Bug nicht
    betroffen (kein `class_weight_power`-Konzept in der Regression, AUC ist
    gewichtungsunempfindlich bei s6e8, s6e6 hatte Gewichtung bereits korrekt
    gesetzt).
    **LB-Bestaetigung**: die korrigierte Greedy-Ensemble-Submission erzielte
    **0.94884** - schlaegt den bekannten Einzelmodell-Referenzwert (0.94740)
    um +0.00144 und liegt nah an der lokalen Schaetzung (0.9484, Abweichung
    nur +0.0004). Sauberer Doppelbeleg: der Bug-Fix war korrekt (Sprung von
    0.875 auf 0.949 wie erwartet), UND Greedy-Ensemble-Selection liefert
    hier einen echten, LB-bestaetigten Gewinn ueber das beste Einzelmodell -
    trotz des lokal knapp vorn liegenden Blends, fuer den sich der Nutzer
    aus Kostengruenden bewusst nicht entschieden hat.
  - **Weitere Anwendungen (2026-08-11)**: road-accident-risk (Regression,
    RMSE-Version, 4. Bestaetigung), s6e6 (Methodik-Test, 5. Bestaetigung),
    s6e8 mit frischem 24er-Grid-Pool (6. Bestaetigung). **Negativer/neutraler
    Fall**: s6e8 mit den bereits abgestimmten, hoch korrelierten GBMs
    (LightGBM+XGBoost+CatBoost, exact-value TE, kein FT-Transformer) zeigt
    KEINEN Gewinn ueber den bestehenden Equal-Weight-Blend (0.9654 beide,
    Differenz 0.00001) - Greedy braucht einen grossen/diversen Pool, um sein
    Potenzial zu zeigen; bei wenigen, bereits stark abgestimmten, aehnlichen
    Modellen bringt es nichts zusaetzlich. Volle Zahlen + Einordnung in
    `REFERENZ_ENSEMBLE_SELECTION.md` Abschnitt 4/5.
  - **Meta-Learning-Warmstart fuer `tnr("mbo")`: geprueft, verifiziert -
    NEGATIVES Ergebnis, NICHT ins Template uebernommen (2026-08-08/10).**
    Auto-sklearn-Rezept (Feurer et al.): Meta-Features des neuen Datensatzes
    berechnen, k aehnlichste Referenz-Datensaetze per L1-Distanz im
    Meta-Feature-Raum finden, deren beste bekannte Konfigurationen als
    Initialdesign fuer `tnr("mbo")` injizieren (`instance$eval_batch()`)
    statt reinem Zufalls-Initialdesign. **Standalone-Skripte** (`ML_Learning/
    openml-drift-detection-test/020_meta_learning_warmstart_test.R` +
    `021_..._electricity.R`, kein Git-Projekt): Offline-Referenzpool aus 8
    OpenML-Datensaetzen (credit-g, phoneme, spambase, kc1, diabetes,
    kr-vs-kp, blood-transfusion, ilpd; 6 einfache/statistische Meta-Features,
    je beste LightGBM-Konfiguration per 20-Punkte-Zufallssuche), Online-
    Vergleich Baseline (Zufalls-Init) vs. Warmstart mit EXAKT demselben
    Gesamtbudget (fairer Vergleich per Terminator, unabhaengig von
    `mlr3mbo`-Interna) an 2 unabhaengigen Ziel-Datensaetzen, je 3 Seeds:
    | Ziel-Datensatz | Finales AUC Baseline | Finales AUC Warmstart | Differenz | Frueh (erste 6 Evals) |
    |---|---:|---:|---:|---|
    | bank-marketing (id 1461) | 0.9279 | 0.9280 | +0.0001 | Baseline 0.9233 vs. Warmstart 0.9252 |
    | electricity (id 151) | 0.9502 | 0.9504 | +0.0002 | **exakt gleich** (0.9477 vs. 0.9477) |
    Kein messbarer Effekt, weder finales AUC noch Konvergenzgeschwindigkeit,
    an BEIDEN Ziel-Datensaetzen - klar innerhalb der Seed-zu-Seed-Streuung.
    **Iterationsdetail**: der erste Lauf (Budget=20, 4 Hyperparameter, k=3,
    5-Datensatz-Pool) zeigte GP-Surrogat-Fehler ("number of experiments must
    be larger than the spatial dimension" - zu wenige injizierte Punkte fuer
    die Suchraum-Dimension) und ein widerspruechliches Signal (finaler
    Vorteil, aber schlechtere fruehe Konvergenz); nach Fix (Suchraum auf 3
    Hyperparameter reduziert, Budget 30, Pool auf 8 Datensaetze/k=4
    erweitert) verschwand der GP-Fehler, aber auch praktisch der gesamte
    Effekt - spricht dafuer, dass Lauf 1 Rauschen war, nicht ein echtes
    Signal. **Plausible Gruende (keine Ausreden, fuer kuenftige Versuche
    dokumentiert)**: unser Referenzpool (8 Datensaetze/6 einfache Meta-
    Features) ist winzig gegenueber Auto-sklearns Original (140 Datensaetze/
    38 Meta-Features inkl. Landmarking); bei Budget=30 auf nur 3
    Hyperparametern deckt reines Zufalls-Initialdesign den Suchraum schon
    gut ab (der Warmstart-Vorteil ist in der Literatur am groessten bei sehr
    kleinen Budgets/hochdimensionalen Raeumen); LightGBM ist relativ robust
    gegenueber der genauen Hyperparameter-Wahl. **Nicht weiterverfolgt** -
    anders als Ensemble-Selection und die univariaten Drift-Tests wird diese
    Idee NICHT ins Template zurueckgefuehrt.
    **Referenzpool in der zentralen DB gesichert (2026-08-10)**, fuer einen
    kuenftigen zweiten Versuch (z.B. groesserer Pool, mehr Meta-Features)
    ohne erneute OpenML-Abfragen: Skript `build_meta_learning_reference_pool.R`
    (Template-Root, analog zu `merge_project_experiments.R` ein Template-
    Utility, kein nummeriertes Projekt-Skript) loggt die 8 Referenz-
    Datensaetze als eigenes "Projekt" `meta-learning-reference-pool` in
    `experiments.db` - Meta-Features als `run_config`-Key-Value-Paare je
    `run`, beste bekannte LightGBM-Konfiguration als `model_config`/
    `hyperparam`/`metric_result`, alles ueber die bereits bestehenden
    `db_logging.R`-Funktionen (kein neues Tabellenschema noetig). Bewusst
    KEIN echtes Kaggle-Projekt - wird von `merge_project_experiments.R`s
    Auto-Discovery nicht aufgegriffen (die durchsucht Projekt-eigene
    `_artifacts/experiments.db`-Dateien, dieses "Projekt" existiert nur in
    der zentralen DB selbst). Abfragebeispiel im Skript-Header.
  - **Successive Halving fuer LightGBM-Tuning: geprueft, verifiziert -
    NEGATIVES/uneindeutiges Ergebnis, NICHT ins Template uebernommen
    (2026-08-10).** Kap. 1.4: Kandidaten-Konfigurationen mit kleinem Budget
    (Boosting-Runden) starten, schlechtere Haelfte verwerfen, Budget
    verdoppeln, wiederholen (`lgb.train(..., init_model=)` fuer
    Fortsetzung statt Neustart) - statt jede Kandidatenkonfiguration voll
    zu evaluieren. **Standalone-Skript** (`ML_Learning/openml-drift-
    detection-test/030_successive_halving_test.R`): 16 Kandidaten,
    Budget-Stufen 25->50->100->200->400 (klassisches eta=2-Schema) vs.
    Baseline (aktuelles Template-Muster: mehrere Kandidaten, jeder direkt
    auf vollem Budget) mit EXAKT demselben Gesamtbudget an kumulierten
    Boosting-Runden (1200), Bewertung auf einem separaten TEST-Set
    (weder fuer SH-Eliminierung noch Baseline-Auswahl verwendet), 3 Seeds:
    | Ziel-Datensatz | SH TEST-AUC | Baseline TEST-AUC | Differenz |
    |---|---:|---:|---:|
    | bank-marketing (id 1461) | 0.9307 | 0.9322 | -0.0015 |
    | electricity (id 151) | 0.9801 | 0.9776 | +0.0025 |
    Gegensaetzliche Richtung an den beiden Datensaetzen, beide Effekte
    winzig gegenueber der Seed-Streuung - kein robuster Effekt, aehnlich
    dem Meta-Learning-Warmstart-Befund oben. **Nicht weiterverfolgt.**
- **Univariate Drift-Tests: geprueft, verifiziert UND ins Template
  zurueckgefuehrt (2026-08-08)** - Herkunft: "Introducing MLOps"
  (Treveil/Dataiku 2020, offenes O'Reilly-Kapitel-Werk), Kap. 7. Domain-
  Classifier (== unsere bestehende Adversarial Validation) und univariate
  statistische Tests (Kolmogorov-Smirnov je stetigem Feature, Chi-Quadrat je
  kategorialem Feature) sind komplementaer: die Adversarial-AUC sagt nur
  "insgesamt trennbar ja/nein/wie stark", die univariaten Tests sagen WELCHE
  Features driften, mit Effektgroesse (KS-D bzw. Cramers V).
  **Verifikation** (Standalone-Skript `ML_Learning/openml-drift-detection-
  test/010_univariate_drift_test.R`, kein Git-Projekt), 3 Szenarien mit
  bekanntem Ground Truth (wie beim Leak-Audit-Sensitivitaetstest):
  | Szenario | Ground Truth | Adversarial-AUC | Univariate Tests |
  |---|---|---:|---|
  | A) electricity (id 151), chronologischer Split | echter Zeit-Drift erwartet | 1.0000 | 6/8 signifikant - Marktpreise/-nachfrage (D=0.43-0.57) ja, Kalenderstruktur (day/period) korrekt NICHT |
  | B) bank-marketing (id 1461), Zufalls-Split | KEIN Drift (Spezifitaets-Kontrolle) | 0.4991 | 0/16 signifikant nach BH-Korrektur - keine Fehlalarme |
  | C) bank-marketing, Split nach Feature-Median | konstruierter Drift, 1 Feature garantiert verschoben | 1.0000 | Split-Feature korrekt Rang 1 (D=1.000), 14/16 signifikant inkl. korrelierter Features (bis Cramers V=0.39) |
  Fall A zeigt den eigentlichen Mehrwert: die Adversarial-AUC (1.0, komplett
  trennbar) unterscheidet NICHT zwischen echtem Markt-Drift und stabiler
  Kalenderstruktur - die univariaten Tests tun es. Fall B bestaetigt, dass die
  BH-Korrektur noetig UND wirksam ist (einzelne rohe p-Werte lagen bei
  ~0.02-0.1, nichts ueberlebt die Korrektur).
  **Ins Template zurueckgefuehrt**: neues Modul `univariate_drift.R`
  (`run_univariate_drift_tests()`/`report_univariate_drift()`, generisch fuer
  beliebige zwei Datensaetze mit gleichen Spalten), eingebunden in
  `115_adversarial_validation.R` direkt nach dem Feature-Importance-Block.
  Neue Config-Variablen `univariate_drift_results_path`/`univariate_drift_alpha`
  in `000_config.R`. End-to-end gegen das Template-eigene Projekt
  (health_condition) regressionsgetestet: 2 von 13 Features signifikant
  (`gender` p_adj_BH~1e-297, aber Cramers V nur 0.037 - genau die
  "grosse-Datensaetze-Falle" aus dem Buch, hier live demonstriert), Rest des
  Skripts (Benchmark, DB-Logging) laeuft unveraendert weiter durch. Auch
  identisch ins Regressions-Template zurueckgefuehrt (`018_adversarial_
  validation.R`), dort ebenfalls end-to-end getestet (0/12 signifikant,
  konsistent mit Adversarial-AUC ~0.499 am Template-eigenen Projekt).
- **Segmentmetriken (Slice-Based Evaluation): geprueft, verifiziert UND ins
  Template zurueckgefuehrt (2026-08-10)** - Herkunft: "Designing Machine
  Learning Systems" (Chip Huyen, O'Reilly 2022), Kap. 6 "Model Development
  and Offline Evaluation". Kernargument: eine Gesamt-Metrik kann eine
  schwache Untergruppen-Performance verstecken oder sogar verkehrt anzeigen
  (Simpson-Paradoxon - Modell A kann in JEDER Untergruppe schlechter sein
  als Modell B und trotzdem insgesamt besser abschneiden, wenn die
  Gruppengroessen unterschiedlich sind; Buch-Beispiel: Berkeley-
  Zulassungsdaten 1973). **Bestehende Asymmetrie zwischen den Templates**:
  das Regressions-Template hat das schon (`125_segment_metrics.R`,
  `segment_metric_cols`), das Klassifikations-Template hatte es nicht -
  genau die Art Luecke, die unsere ADR-003-Frage "was uebertragen wir
  zwischen Templates" eigentlich systematisch schliessen sollte.
  **Verifikation** (Standalone-Skript `ML_Learning/openml-drift-detection-
  test/040_segment_metrics_test.R`), Ground-Truth-Design analog zum Leak-
  Audit-/Drift-Sensitivitaetstest: zwei synthetische Segment-Spalten je
  Datensatz - `noise_segment` (an ein ECHTES Feature gekoppelt per Median-
  Split, 45% der Trainings-Labels in einer Haelfte zufaellig geflippt,
  Auswertung gegen die ECHTEN/ungeflippten Test-Labels) mit erwarteter
  BAcc-Luecke, und `control_segment` (reiner Zufalls-Split) ohne erwartete
  Luecke. **Wichtige Lektion aus einem fehlgeschlagenen ersten Versuch**:
  eine Segmentzugehoerigkeit rein zufaellig (unabhaengig von den Features X)
  zu vergeben und NUR dort Label-Rauschen einzufuegen erzeugt KEINEN
  erkennbaren Effekt - das Modell lernt aus X, kann also keine
  Systematik fuer ein X-unabhaengiges Label lernen. Erst als das Rauschen an
  ein echtes Feature gekoppelt wurde (Median-Split), entstand ein
  lernbarer, segment-spezifischer Qualitaetsunterschied:
  | Datensatz | noise_segment-Luecke (BAcc) | control_segment-Luecke |
  |---|---:|---:|
  | bank-marketing (id 1461) | **0.0566** (korrekt geflaggt) | 0.0181 (korrekt still) |
  | electricity (id 151) | **0.1122** (korrekt geflaggt) | 0.0018 (korrekt still) |
  Sensitivitaet UND Spezifitaet an beiden Datensaetzen bestaetigt.
  **Ins Template zurueckgefuehrt**: neues Skript
  `147_error_analysis_ranger_segments.R` (Teil der 147-Fehleranalyse-Kette,
  laedt das `error_analysis_models_path`-Artefakt statt neu zu trainieren,
  wie die uebrigen 147-Skripte), neue Config-Variablen
  `segment_metric_cols`/`segment_metric_warn_gap`/`segment_metrics_path` in
  `000_config.R` (Default: `segment_metric_cols` leer -> uebersprungen, wie
  im Regressions-Vorbild). Berechnet BAcc/MCC je Segment fuer alle drei
  147-Vergleichsmodelle (Ranger/LightGBM/LDA), warnt bei einer BAcc-Luecke
  ueber `segment_metric_warn_gap` (Default 0.05) zum zeilengewichteten
  Segment-Mittel. End-to-end gegen das Template-eigene Projekt
  (health_condition, Segmente `gender`/`diet_type`) regressionsgetestet:
  laeuft sauber, keine Luecke ueber der Schwelle (unauffaellig, plausibel
  fuer einen synthetischen Playground-Datensatz ohne bekannte
  Subgruppenprobleme).
- **Drei weitere Ideen aus "Designing Machine Learning Systems" (Huyen 2022),
  Kap. 6 "Evaluation Methods" - geprueft/prototypisiert und VERIFIZIERT
  (2026-08-10, Update)**: Perturbation-, Invarianz- und
  Directional-Expectation-Tests. Standalone-Skripte in
  `ML_Learning\health-condition-huyen-sanity-tests\` (kein Git-Projekt):
  `perturbation_test.R`/`invariance_test.R`/`directional_test.R` (generische
  Helper), `010_verify_ground_truth.R` (Ground-Truth-Verifikation, analog zur
  Leak-Audit-Methodik: fuer jeden Test ein bewusst kaputtes vs. ein sauberes
  Modell konstruiert, Sensitivitaet+Spezifitaet geprueft - alle drei trennen
  korrekt), `020_run_against_health_condition.R`/`021_directional_deep_dive.R`
  (echter, deskriptiver Lauf gegen das 147-Ranger-Modell des
  Template-eigenen Projekts, kein erneutes Training noetig).
  - **Perturbation-Test**: 5% relative SD-Rauschen auf alle numerischen
    Features -> BAcc 0.9491 -> 0.9186 (Drop 0.0305). Ground Truth
    (exact-value-TE-Lookup vs. glm auf glattem Feature): Drop 0.355 vs. 0.000
    - der Test trennt fragile von robusten Modellen sauber. Auf
    health_condition: moderater, unauffaelliger Drop.
  - **Invarianz-Test** (Spalte `gender` gemischt): flip_rate=0.0012 (praktisch
    invariant). Ground Truth (Modell mit injiziertem Leak-Proxy vs. Modell
    ohne): flip_rate 0.502 vs. 0.000 - Test funktioniert. Kandidaten-Check,
    keine endgueltige fachliche Aussage.
  - **Directional-Expectation-Test** (ordinale Stufen-Verschiebung
    low->medium->high etc.): Ground Truth (korrektes vs. vorzeichen-
    invertiertes Modell) trennt perfekt (violation_rate 0.000 vs. 1.000).
    Auf health_condition drei Features geprueft, **echter Befund**:
    `physical_activity_level` und `smoking_alcohol` zeigen die erwartete
    Richtung im Mittel, Verletzungen sind ueberwiegend rauschartig-klein
    (Median-Betrag ~0.005, nur 1.3-1.5% der Verletzungen >0.05). Bei
    `stress_level` dagegen sind die Verletzungen SUBSTANZIELLER: 38% der
    betroffenen Zeilen verletzen die Erwartung (P(fit) steigt trotz mehr
    Stress), Median-Betrag 0.013, 14.4% der Verletzungen >0.05 (~3.4% aller
    Zeilen mit einer Wahrscheinlichkeits-Verschiebung >0.05 in die falsche
    Richtung). Aggregat-Richtung stimmt (mean_diff -0.05 ueber alle Zeilen),
    aber eine nicht-triviale Minderheit widerspricht deutlich - plausibel
    durch Interaktionseffekte mit anderen Features (Ranger-Ensemble lernt
    keine globale Monotonie), aber genau der Fall, den dieser Test laut
    Huyen finden soll (Richtung WAS wichtig ist reicht nicht).
  - **Genericity-Einschaetzung (Korrektur der 2026-08-10-Ersteinschaetzung
    oben im Diff)**: alle drei Mechanismen sind GENERISCH (Rauschen/Mischen/
    Stufen-Shift + Metrik-Vergleich braucht kein projektspezifisches Wissen im
    Code) - nur die KONFIGURATION ist projektspezifisch (welche Spalten,
    welche Richtung/Stufenordnung), exakt wie bei `segment_metric_cols` oder
    `leak_audit_stratify_cols` bereits im Template. Die urspruengliche
    Einschaetzung "eher pro-Projekt-Muster als generisches Modul" war zu
    vorsichtig.
  - **Zweites reales Projekt bestaetigt (ADR-003, gleicher Tag)**: PumpItUp
    (DrivenData, `drivendata-pump-it-up`, status_group 3-Klassen). Kein
    147-Artefakt dort vorhanden -> eigenes schnelles Ranger-Modell trainiert
    (num.trees=100, `030_run_against_pumpitup.R`, ~22 Sek. Trainingszeit,
    kein Hintergrundlauf noetig). Perturbation (4 dbl-Features, 5% Rauschen):
    BAcc 0.6579->0.6474 (Drop 0.0105, unauffaellig). Invarianz
    (`public_meeting` gemischt): flip_rate 0.0048 (unauffaellig). Directional
    (`construction_year` +10 Jahre -> P(functional) soll nicht sinken,
    n=11610 Zeilen mit bekanntem Baujahr): **bestaetigt dasselbe Muster wie
    health_condition** - Aggregat-Richtung stimmt (mean_diff +0.0050), aber
    violation_rate=0.4629, davon 11.4% mit Betrag >0.05 (~5.3% ALLER Zeilen
    mit substanzieller Verletzung >0.05 Wahrscheinlichkeitspunkte,
    Vergleichswert health_condition/stress_level: ~3.4%). **Zwei unabhaengige,
    domaenefremde Projekte (synthetisches Gesundheits-Playground vs. reale
    Infrastrukturdaten) zeigen dasselbe qualitative Bild: ein Tree-Ensemble
    erzwingt keine globale Monotonie, und der Directional-Test findet
    zuverlaessig eine nicht-triviale Verletzungs-Minderheit (3-5% aller
    Zeilen), waehrend Perturbation/Invarianz auf beiden Projekten unauffaellig
    blieben** (Spezifitaet bestaetigt, kein falscher Alarm).
  - **Status: bestaetigt UND gebackportet (2026-08-10, gleicher Tag)**.
    Neues `sanity_checks.R` (3 generische Funktionen + `build_ordinal_shift_fn()`)
    + `147_error_analysis_ranger_sanity_checks.R` (laedt das Modelle-Artefakt,
    kein erneutes Training, optional per Config-Listen aktiviert, default
    leer -> uebersprungen, analog zu `_segments.R`). Config-Ergaenzung in
    `000_config.R`: `perturbation_test_cols`/`perturbation_noise_sd_frac`/
    `perturbation_warn_drop`, `invariance_test_cols`/`invariance_warn_flip_rate`,
    `directional_expectation_specs`/`directional_warn_violation_rate`/
    `directional_effect_threshold`/`directional_warn_effect_share`.
    End-to-end gegen health_condition regressionsgetestet (Config temporaer
    mit den in dieser Session gemessenen Werten befuellt, Ergebnisse
    reproduzieren die obigen Zahlen; die integrierte Version filtert
    NA/Sentinel-Zeilen beim Directional-Test sauberer heraus als der erste
    Standalone-Prototyp), danach wieder auf leere Defaults zurueckgesetzt
    (Template bleibt default-inert, wie bei `segment_metric_cols`).
    `WorkflowDescription.md`/`README_DETAILS.md` aktualisiert. Neues
    `REFERENZ_MODEL_SANITY_CHECKS.md` (theoretischer Hintergrund, analog zu
    `REFERENZ_PROBABILITY_CALIBRATION.md`). **Committet und gepusht**
    (`87c4751`).
  - **Cross-Template-Port nach Regression (2026-08-10, gleicher Tag,
    separater Auftrag)**: `sanity_checks.R` dabei aufgabentyp-unabhaengig
    generalisiert (`higher_is_better`-Flag, numerische/kategoriale
    Invarianz-Erkennung, `build_numeric_shift_fn()` mit Integer-Erhalt) und
    identisch in beide Templates uebernommen, wie `univariate_drift.R`.
    Dritte unabhaengige Projekt-Bestaetigung des Directional-Musters
    (road-accident-risk, `num_reported_accidents`: 10.2% substanzielle
    Verletzungen) - siehe Regressions-`BACKLOG.md` fuer die vollen Zahlen
    und einen echten Design-Fund (numerische Invarianz braucht ein
    Magnitude-Gate, nicht nur flip_rate, bei grossen Boosting-Ensembles).

- **`lightgbm_tuning_evals`-Budget-Ablation (2026-08-10, aus der mlr3mbo-
  Literaturbewertung, `C:\Git\literatur\bewertung.md`) - gemessen, Ergebnis
  gemischt, Template-Default NICHT geaendert.** mlr3mbo-Paper legte nahe,
  dass der aktuelle Default `lightgbm_tuning_evals=25` knapp am/unter dem
  Init-Design-Bedarf liegt (Init-Design fuer den 5-Parameter-Suchraum =
  20 Punkte, live bestaetigt). Standalone-Ablation `lightgbm_budget_
  ablation.R` (Repo-Root, nach Auswertung wieder entfernt): Budget 25 vs. 45
  (Faustregel aus `006_tuning_diagnostics.R`: >=4x5 Parameter + 10-20),
  gleicher Suchraum/Seed, gegen health_condition.
  - Budget 25 (aktueller Default): 6 Batches (nur 5 echte Verfeinerungs-
    schritte nach dem Init-Design), Suchphase 642.9 Sek.
  - Budget 45: 26 Batches (25 echte Verfeinerungsschritte), Suchphase
    1051.2 Sek. (+64% Laufzeit).
  - Finalvergleich (5-fache CV): Default-LightGBM BAcc 0.8788/MCC 0.8631;
    getunt mit Budget 25 BAcc 0.8749/MCC 0.8567; getunt mit Budget 45
    BAcc 0.8778/MCC 0.8536.
  - **Gemischtes Bild**: mehr Budget verbessert die Zielmetrik der Tuning-
    Suche selbst leicht (BAcc 0.8749->0.8778), aber MCC sinkt leicht
    (0.8567->0.8536) - kein eindeutiger Gewinn. **Beide getunten Varianten
    bleiben unter dem UNGETUNTEN Default** (0.8788) - bestaetigt die
    laengst dokumentierte Lehre "Tuning bringt marginale Gewinne, LightGBM-
    Default schlaegt oft getuned" (siehe oben, mehrfach unabhaengig
    beobachtet), diesmal zusaetzlich mit einer harten Zahl zur Budget-
    Sensitivitaet selbst.
  - **Entscheidung: Template-Default bleibt bei 25.** Ein groesseres Budget
    erzeugt zwar nachweisbar mehr echte BO-Verfeinerung (26 vs. 6 Batches),
    aber der Effekt auf die tatsaechliche Zielmetrik ist hier klein/gemischt
    und rechtfertigt nicht +64% Laufzeit als neuen Template-weiten Default.
    `006_tuning_diagnostics.R`s bestehende Warnung bei `n_batches==1` leistet
    bereits das Richtige (pro-Projekt-Entscheidung ermoeglichen, statt einen
    global teureren Default zu erzwingen) - kein Aenderungsbedarf am
    Diagnose-Skript oder am Default.

- **Generalisierungsluecke formal quantifizieren/herausfordern (2026-08-13,
  aus einem Abgleich der Jason-Brownlee-"Data Science Diagnostic
  Checklist" gegen den Template-Stand) - Modul gebaut, synthetisch UND an 1
  echtem Projekt verifiziert, NOCH NICHT ins Template zurueckgefuehrt.**
  Siehe [`REFERENZ_GENERALIZATION_GAP.md`](REFERENZ_GENERALIZATION_GAP.md)
  fuer Theorie/Herkunft/Mechanismus. Synthetisch (`rpart`, 60-Konfig-
  "Winner's Curse"-Suche): korrekt als auffaellig erkannt (z=-3.12), eine
  feste Config korrekt nicht (z=+2.30). Real (`openml-steel-plates-fault`,
  1941 Zeilen, 7-Klassen): Referenzbereich aus 4 ungetunten Baselines zeigt
  eine Hintergrund-Luecke von -0.039 BAcc; die getunten Ranger-/LightGBM-
  Modelle aus `090`/`100` liegen mit z=-1.63/z=-0.39 beide innerhalb des
  Referenzbereichs - kein Beleg fuer Test-Harness-Optimismus durch die
  Suche (plausibles Negativergebnis, bestaetigt indirekt das
  `AutoTuner`-Design von `090`/`100`). **2. Bestaetigung
  (openml-satimage-multiclass, 6430 Zeilen): ebenfalls unauffaellig**
  (z=1.03/z=0.50) - dabei auffaellig kleinere/engere Hintergrund-Luecke
  (+0.013, SD 0.008) als bei steel-plates-fault, passend zur Erwartung
  "Luecke schrumpft mit Datensatzgroesse". **ERLEDIGT (2026-08-13):
  ADR-003-Schwelle erfuellt, als `136_generalization_gap.R` +
  Config-Ergaenzungen ins Template zurueckgefuehrt** (Referenzbereich aus
  `base_learner_constructors`, Kandidaten aus den `090`/`100`-Tuning-
  Instanzen extrahiert). Regressionsgetestet gegen das Template-eigene
  Projekt (`health_condition`, groesster der drei getesteten Datensaetze):
  erneut unauffaellig, mit der bisher engsten Luecke (+0.0025, SD 0.0032) -
  3/3 durchgehend konsistent, kein Fall hat bisher tatsaechlich geflaggt
  (nur synthetisch bewiesen, siehe `REFERENZ_GENERALIZATION_GAP.md`
  Abschnitt 3).

- **Drei weitere Luecken aus dem Brownlee-Checklisten-Abgleich (2026-08-13,
  siehe `REFERENZ_GENERALIZATION_GAP.md` Abschnitt 1 fuer die vollstaendige
  Tabelle) - noch NICHT begonnen:**
  - ~~**§3 Split-Size-Sensitivity-Analysis**~~ **ERLEDIGT (2026-08-13)**:
    neues Modul `split_size_sensitivity.R` (`split_ratio_sensitivity()` via
    `rsmp("subsampling", repeats, ratio)` + `report_split_ratio_sensitivity()`)
    + `022_split_size_sensitivity.R`. Synthetisch verifiziert (rpart, n=100/
    400, ratios 0.5-0.95): CV der Performance-Scores steigt mit sinkender
    Testset-Groesse wie erwartet (Faktor bis 3.56x ggue. dem besten ratio).
    Ein erster Entwurf koppelte das Flagging zusaetzlich an einen absoluten
    CV-Schwellenwert (0.03) - das flaggte faelschlich sogar das BESTE
    getestete ratio, weil die "normale" CV-Groessenordnung stark von
    Metrik/Task abhaengt. Korrigiert: nur der RELATIVE Faktor ggue. dem
    Minimum ist das Gate (dieselbe Selbst-Kalibrierungs-Lehre wie beim
    z-Score in `generalization_gap.R`, jetzt 2. Bestaetigung). Real an 2
    Projekten verifiziert (`health_condition`, `openml-satimage-multiclass`):
    beide Male der aktuelle Default `validation_ratio=0.80` unauffaellig
    (Faktor 1.47x/1.71x, mit Ranger) - bei den deutlich kleineren
    synthetischen Datensaetzen war derselbe Anteil naeher an der
    Flagging-Schwelle bzw. darueber. Ins Template zurueckgefuehrt.
  - **Update (2026-08-13), Kosten-Nutzen-Korrektur**: Nutzer wies zurecht
    darauf hin, dass der Check bei grossen Datensaetzen teuer UND am
    wenigsten informativ ist (beide realen Bestaetigungen unauffaellig),
    waehrend er bei kleinen Datensaetzen billig UND am nuetzlichsten waere -
    Kosten und Nutzen laufen gegenlaeufig zur Datensatzgroesse. Zwei
    Aenderungen: (1) `classif.rpart` statt Ranger als Default-Lerner (der
    Mechanismus - Streuung durch Testset-Groesse - ist weitgehend
    lernverfahren-unabhaengig, macht `base_learner_constructors` zudem
    unnoetig); (2) `split_sensitivity_max_n=5000` - Check wird bei groesseren
    Datensaetzen komplett uebersprungen (klare Meldung statt stillschweigend).
    Spot-Check mit dem neuen rpart-Default gegen `openml-satimage-multiclass`
    (3215 Zeilen, unter der Schwelle): gleiches qualitatives Muster
    (monotoner CV-Anstieg mit steigendem ratio), Faktor 1.26x bei
    ratio=0.80 (mit Ranger zuvor: 1.71x) - unauffaellig in beiden Faellen,
    bestaetigt die Lernverfahren-Unabhaengigkeit der Diagnose.
  - ~~**§11 Lern-/Validierungs-/Loss-Kurven**~~ **TEILWEISE ERLEDIGT
    (2026-08-13)**: nur die LERNKURVEN-Haelfte gebaut (Score vs. Trainings-
    groesse) - die Validierungskurven-Haelfte (Score vs. Modellkapazitaet)
    bewusst weggelassen, da weitgehend redundant mit dem, was `090`/`100`
    (Hyperparameter-Suche + Default-vs-getunt-Vergleich) schon liefern.
    `008_curve_diagnostics.R` ist trotz aehnlichem Namen KEIN Kandidat
    fuer beides - das sind ROC-/PR-Schwellenwert-Kurven, ein anderes Konzept.

    Neues Modul `learning_curve.R` (`learning_curve()` + `report_learning_
    curve()`) + `023_learning_curve.R`. ANDERS als `split_size_sensitivity.R`
    ist der Mechanismus hier NICHT lernverfahren-unabhaengig (Kapazitaet des
    Algorithmus bestimmt die Kurvenform) - ein rpart-Stellvertreter waere
    eine falsche Sicherheit, das Modul laeuft mit dem tatsaechlich
    eingesetzten Ranger.

    Synthetisch verifiziert (2 Szenarien, Ranger): ein erster Entwurf mit
    "letzter vs. erster Zuwachs" (2 Randpunkte) war zu instabil - bei einer
    bereits fast durchgehend flachen Kurve teilt man dann Rauschen durch
    Rauschen. Korrigiert auf eine Regression ueber ALLE Punkte
    (lm(val_score ~ log(n)), Steigung -> erwarteter Zuwachs bei Verdopplung
    von n, relativ zur beobachteten Score-Spannweite bewertet - 4.
    Bestaetigung derselben Selbst-Kalibrierungs-Lehre wie in
    split_size_sensitivity.R/generalization_gap.R). Danach: Szenario
    "datenhungrig" (n=350, 1 Interaktion + Rauschen) korrekt "NOCH
    STEIGEND", Szenario "saettigend" (n=2000, 1 dominantes Feature) korrekt
    "PLATEAU".

    Real an 2 Projekten verifiziert:
    - `health_condition` (Volldatensatz 690088 Zeilen, subset_fraction=0.10):
      BAcc 0.8304(1%)->0.8423(2%)->0.8499(5%)->**0.8586(10%)**->0.8618(20%),
      monoton steigend, bei 10% "NOCH STEIGEND" (23% der Spannweite pro
      Verdopplung). Absolut betrachtet kleiner Effekt (+0.32 BAcc-Punkte
      10%->20%) - Modellauswahl auf dem Subset ist leicht konservativ, aber
      kein Alarmsignal (das finale Modell trainiert ohnehin auf 100%,
      `150_train_full_model.R`).
    - `openml-satimage-multiclass` (Volldatensatz 6430 Zeilen,
      subset_fraction=0.50): BAcc 0.848(10%)->0.864(25%)->0.873(50%)->
      0.886(75%)->0.892(100%), auch bei 100% noch "NOCH STEIGEND" (30% der
      Spannweite) - bei diesem kleinen Datensatz waere selbst der volle
      Datensatz noch nicht am Plateau.

    DB-Logging ergaenzt (`023`): je fraction ein `model_config` (Hyperparams
    `train_fraction`/`n_train`) + 2 `metric_result`-Zeilen (Validierung +
    Training per Suffix `_train`) - keine Schema-Erweiterung noetig,
    verifiziert per direkter DB-Abfrage.

    **Offene Idee (Nutzer, 2026-08-13), NICHT umgesetzt**: "Wetterballon" -
    empirisch pruefen (nicht annehmen), ob eine BILLIGE Lernkurve (rpart/
    lda) mit dem teuren Ranger/LightGBM-Pendant ueber mehrere Projekte
    hinweg korreliert (z.B. Plateau-Punkt), um kuenftig die teure Kurve
    per kalibrierter Regel abzukuerzen. Braucht als Voraussetzung: `023`
    kuenftig fuer mehrere Lerner gleichzeitig aufrufen (Ranger UND rpart/
    lda) und beide in `experiments.db` loggen - noch keine einzige
    Vergleichsmessung vorhanden, reine Idee bis dahin.

    **Bugfix (2026-08-15): "PLATEAU"-Klassifikation war anfaellig gegen
    Einzelpunkt-Ausreisser bei kleinen Stichproben.** Anlass: bei der
    Suche nach einem zweiten Beleg fuer `openml-credit-g`s vermeintlichen
    ersten Plateau-Fall (siehe SYSTEMATIC_EVALUATION.md) zeigte
    `openml-synthetic-control-timeseries` (600 Zeilen, KLEINER als
    `credit-g`) "noch steigend" - direkter Widerspruch zur "kleine
    Datensaetze plateauen"-Hypothese. Ursache: `report_learning_curve()`
    bewertete den Regressions-Zuwachs relativ zur VOLLEN Score-Spannweite
    (max-min ueber alle Fraktionen) - bei `credit-g` dominierte ein
    einzelner Ausreisser bei winzigem n=20 (BAcc-Einbruch auf 0.475,
    trotz `repeats=5`-Mittelung: bei n=20/5-fach-CV bleiben nur ~4 Zeilen
    je Fold) die Spannweite und liess den tatsaechlich noch klar
    steigenden Trend (0.598 bei n=100 -> 0.653 bei n=1000) faelschlich
    unter der 10%-Schwelle erscheinen (6.5% statt der tatsaechlichen
    23.1%). **Fix**: Nenner auf IQR (Q3-Q1) statt volle Spannweite
    umgestellt - robust gegen genau diesen Fall, ohne neuen
    Schwellenwert. `credit-g` kippt damit von PLATEAU zu NOCH STEIGEND.
    Regressionsgetestet gegen `ci_smoke_test` (keine Aenderung) und alle
    vier weiteren real getesteten Projekte (`health_condition`/`satimage`/
    `synthetic_control`/`credit-g` selbst - alle bleiben bzw. werden "noch
    steigend", keine unbeabsichtigte Kippung). Explizit NICHT auf
    `split_size_sensitivity.R`/`generalization_gap.R` uebertragen - beide
    nutzen zwar dieselbe "selbstkalibrierend relativ zu einer Referenz"-
    Philosophie, aber technisch robustere Mechanismen (Minimum-Referenz
    bzw. echter SD-basierter z-Score), gezielt gegengeprueft, keine
    identische Schwachstelle gefunden.

    **Nebenbefund**: `openml-satimage-multiclass` hat gar kein
    `023_learning_curve.R` im Projektordner (nur das Modul
    `learning_curve.R` ohne aufrufendes Skript/Artefakt) - die oben
    zitierten Zahlen (0.848→0.892) stammen aus einer nicht mehr
    reproduzierbaren Ad-hoc-Analyse. Echte Reproduzierbarkeits-Luecke,
    niedrige Prioritaet (Klassifikation aendert sich unter beiden Nennern
    nicht - 29.7%/59.3%, beide klar "noch steigend").

    **Zweiter Methodik-Fix (2026-08-17): Mindest-n-Filter fuer die
    Regression.** Anlass: gezielte Suche nach einem ECHTEN Plateau-Fall
    (`ML_Learning/wdbc-plateau-test`, Wisconsin Breast Cancer via
    `mlbench::BreastCancer` - OpenML.org antwortete an diesem Tag
    durchgehend mit 504 Gateway Timeout, daher lokal ueber `mlbench` statt
    `mlr3oml`), NACHDEM der IQR-Fix den einzigen bisherigen Plateau-Fund
    (`credit-g`) widerlegt hatte - noch nie war bestaetigt, dass die
    PLATEAU-Klassifikation ueberhaupt je korrekt anschlaegt. Ergebnis: ein
    klassisch "sehr sauber trennbarer" Datensatz (Baseline-BAcc 0.983
    Ranger, 0.963 sogar mit LDA) zeigte ein eindeutiges Saettigungsmuster
    (val_score 0.722->0.917->0.961->**0.972** bei n=68, danach nur noch
    Rauschen zwischen 0.947-0.971 bis n=683) - wurde aber TROTZDEM als
    "NOCH STEIGEND" klassifiziert (114.6% des IQR). Ursache: dieselbe
    Klasse von Problem wie beim `credit-g`-Fund, aber ueber die REGRESSION
    statt den Nenner - `lm(val_score ~ log(n))` gewichtet jeden Punkt
    gleich, unabhaengig von seiner Zuverlaessigkeit; die beiden winzigen
    Anfangspunkte (n=6/n=14, bei 3-fach-CV nur ~2 Zeilen/Fold) dominierten
    die Steigung und verschleierten den ab n=68 klar flachen Trend. **Fix**:
    `report_learning_curve()` bekommt einen neuen `min_rows_per_fold`-
    Parameter (Default 10) + `cv_folds` (muss vom Aufrufer durchgereicht
    werden, `023_learning_curve.R` tut das jetzt) - Punkte mit weniger
    Zeilen als `min_rows_per_fold * cv_folds` werden VOR der Regression
    ausgeschlossen (in der Konsolen-Ausgabe/CSV weiterhin vollstaendig
    sichtbar). Mit dem Fix kippt `wdbc-plateau-test` korrekt zu `PLATEAU`
    (7.5% statt 114.6%). Regressionsgetestet gegen alle 5 real getesteten
    Projekte (`health_condition`/`satimage`/`credit-g`/`synthetic_control`/
    `eeg-eye-state`) + `ci_smoke_test`: keine ungewollte Kippung, alle
    bleiben "noch steigend" (teils sogar mit klarerem Signal, z.B. credit-g
    23.1%->45.9%, synthetic_control 45.4%->78.0%). Damit ist "NOCH STEIGEND
    ueberall bei den bisherigen realen Projekten" jetzt ein verlaesslicherer
    Nullbefund statt einer unbestaetigten Vermutung - die Klassifikation
    KANN nachweislich Plateaus erkennen, tut es bei den bisher getesteten
    echten Kaggle/OpenML-Datensaetzen aber tatsaechlich nicht. Siehe
    `SYSTEMATIC_EVALUATION.md` fuer die eingearbeitete Neubewertung.
  - ~~**§14 Seed-Varianz & Hyperparameter-Rausch-Stabilitaet**~~ **ERLEDIGT
    (2026-08-13)**: `sanity_checks.R` deckte bereits Feature-Rausch-
    Perturbation und Feature-Invarianz ab - neu: `seed_stability.R`
    (`seed_stability()` + `hyperparam_jitter_stability()` +
    `report_stability()`) + `092_seed_stability.R`, fuer Streuung durch
    das MODELL selbst bei FIXEN Daten (anderer Rauschkanal als Daten-
    Sampling in `split_size_sensitivity.R` oder Feature-Rauschen in
    `sanity_checks.R`).

    Referenzpunkt: die normale CV-Fold-Streuung (mischt Daten- UND
    Modellrauschen) - 5. Bestaetigung derselben Selbst-Kalibrierungs-Lehre.
    Synthetisch verifiziert (Ranger, n=4000): ein Modell mit 300 Baeumen
    zeigt kleine Seed-Streuung (0.14x der CV-Referenz), ein Einzelbaum
    (1 Baum, maximal instabil) deutlich mehr (0.61x) - Richtung korrekt,
    aber ein erster Schwellenwert-Entwurf (Paritaet, 1.0x) haette selbst
    den Extremfall nicht geflaggt, weil CV-Fold-Streuung strukturell
    IMMER Daten- und Modellrauschen zusammen misst und damit meist groesser
    bleibt als reines Modellrauschen allein. Korrigiert auf 0.5x (zwischen
    den beiden synthetischen Messpunkten).

    Real an 2 Projekten verifiziert (`health_condition`, `openml-satimage-
    multiclass`): beide Male BEIDE Checks unauffaellig (Seed-Varianz 0.24x/
    0.23x, Hyperparameter-Jitter um die getunte `090`-Konfiguration 0.09x-
    0.21x) - die eingesetzten 200-Baum-Ranger-Konfigurationen sind
    robust gegen Seed-/Hyperparameter-Rauschen bei beiden Datensatzgroessen.
    DB-Logging ergaenzt (`092`). Jitter-Test laeuft nur, wenn `090` bereits
    ausgefuehrt wurde (sonst uebersprungen, kein Fehler).

    **Nebenbefund (2026-08-17, 6. Stichproben-Runde SYSTEMATIC_EVALUATION.md)**:
    `openml-satimage-multiclass` hat KEIN `092_seed_stability.R` im
    Projektordner (nur das Modul `seed_stability.R` ohne aufrufendes
    Skript/Artefakt) - dieselbe Reproduzierbarkeits-Luecken-Klasse wie das
    bereits dokumentierte `023_learning_curve.R`-Fehlen weiter oben. Anders
    als dort aber KEIN Vertrauensproblem: die oben zitierten Zahlen
    (0.23x/0.21x) sind im Projekt-README (Abschnitt "Seed-/Hyperparameter-
    Rausch-Stabilitaet") mit konkreten SD-Werten belegt (SD=0.0025/0.23x,
    SD=0.0023/0.21x, Referenz-SD=0.0108) - eine echte, spezifische
    Textquelle, nur das ausfuehrbare Artefakt fehlt.

- **`subset_fraction`-Zeilenschwelle (2026-08-13) - ERLEDIGT.** Nutzer-Idee
  im Anschluss an die Lernkurve: ein fester Prozentsatz (Template-Default
  `0.10`) kann bei kleinen Datensaetzen zu wenige absolute Zeilen ergeben
  (steel-plates-fault: 1941*0.10 = 194 Zeilen, musste diese Session manuell
  auf `1.0` korrigiert werden). Neues Hilfsskript
  `suggest_subset_fraction.R` (`suggest_subset_fraction(n_full,
  default_fraction=0.10, min_rows=20000)`, `min(1, max(default_fraction,
  min_rows/n_full))`) - direkt per `Rscript suggest_subset_fraction.R` im
  Projektordner ausfuehrbar (liest `train.csv`) oder als Funktion
  importierbar. `min_rows=20000` ist eine FAUSTREGEL (an der unteren Grenze
  dessen, was diese Session als "unauffaellig" in den anderen vier
  Diagnose-Modulen beobachtet hat), KEIN separat statistisch verifizierter
  Wert - dafuer braucht es weitere Projekt-Erfahrung, anders als bei den
  vier Checklisten-Modulen also keine ADR-003-Bestaetigung noetig/sinnvoll
  (deterministische Formel, kein statistischer Test).

  Reproduziert rueckwirkend zwei der drei bereits manuell getroffenen
  Entscheidungen exakt: steel-plates-fault (1941 Zeilen) -> 1.0 (manuell:
  1.0, exakt), health_condition (690088 Zeilen) -> 0.10 (unveraendert,
  Floor bereits erreicht, exakt). `openml-satimage-multiclass` (6430
  Zeilen) -> 1.0 (manuell gewaehlt war 0.50, aus einem anderen Grund - dort
  ging es um stabile OvR-Kurven, nicht um eine Zeilen-Mindestzahl fuer
  Modellvergleiche; die Formel ist hier konservativer als die urspruengliche
  Wahl, nicht falsch). In Phase 1 der Kochbuch-Prosa (`WorkflowDescription.md`)
  als dritte, leicht uebersehbare `000_config.R`-Entscheidung ergaenzt.

- **CI-Smoke-Test (2026-08-14) - ERLEDIGT.** Systematisiert, was diese
  Session mehrfach manuell an `steel-plates-fault`/`satimage` gemacht hat:
  `.github/workflows/ci-smoke-test.yml` laesst bei jedem Push/PR (Pfad-
  Filter auf `**.R`/`DESCRIPTION`/den Workflow selbst) `015`-`136` gegen
  eine kleine, SYNTHETISCHE Fixture durchlaufen (`ci_smoke_test/
  generate_fixture.R`, deterministischer Seed, 800 Zeilen, 3 Klassen -
  bewusst kein Live-OpenML-Download, kein Netzwerk-/Flakiness-Risiko in
  CI). `DESCRIPTION` (kein echtes R-Paket, nur Dependency-Manifest fuer
  `r-lib/actions/setup-r-dependencies` + Cache). Kein Korrektheitstest
  (keine Score-Schwellenwerte) - reiner Smoke-Test: Exitcode 0 oder Fehler.
  Tuning-/Wiederholungs-Budgets in `ci_smoke_test/000_config.R` auf
  Minimalwerte gesetzt (z.B. `ranger_tuning_evals=4` statt 20) - nur der
  Code-Pfad zaehlt, nicht gute Hyperparameter.

  **Der erste lokale Trockenlauf fand sofort einen echten Bug**: `030_
  baseline.R` stuerzte bei `classif.ranger` mit "Indizierung ausserhalb der
  Grenzen" ab. Root Cause: ein Bug im eigenen Fixture-Generator (`cut()`-
  Grenzen aus einem rauschfreien Vektor berechnet, aber auf einen
  verrauschten Vektor angewendet - ein Wert fiel ausserhalb der Grenzen,
  wurde zu NA, rundete sich beim CSV-Rundweg (fwrite/fread) zu einer
  leeren Faktorstufe mit n=1 in der ZIELSPALTE), nicht ein Bug im Template
  selbst. Behoben (`cut()` jetzt auf demselben verrauschten Vektor, aus dem
  auch die Grenzen berechnet werden) + zwei Sicherheitschecks in
  `generate_fixture.R` ergaenzt (`stopifnot(!anyNA(target))`, Mindest-
  Zellenbesetzung je (Zielklasse, Faktorstufe)). Trotzdem ein echter,
  bisher undokumentierter Befund: `classif.ranger` crasht (anders als
  LDA/Multinom, die durchliefen) auf eine derart korrupte Zielspalte mit
  einer kryptischen Fehlermeldung statt einer klaren Diagnose - als
  eigenstaendige Untersuchung ausgelagert (Spawn-Task, nicht Teil dieses
  CI-Commits), da `020_task.R`/`005_benchmark_runtime.R` bisher nur
  FEATURE-Spalten auf seltene Level prueft (`warn_rare_factor_levels()`),
  nicht die Zielspalte selbst - potenziell relevant auch fuer echte
  Kaggle-CSVs mit vereinzelten NA/leeren Werten im Ziel.

  Nach dem Fix liefen alle 10 Skripte (`015`/`020`/`022`/`023`/`030`/`080`/
  `090`/`100`/`092`/`136`) lokal fehlerfrei durch.

  **Der GitHub-Actions-Runner selbst brauchte danach noch 4 weitere
  Iterationen** (von hier aus nicht lokal testbar, jede Runde ~1-20 Min):
  1. `mlr3extralearners` liegt nicht auf CRAN, nur im mlr-org R-Universe -
     `setup-r-dependencies@v2` kennt aber KEIN `extra-repositories`-Input
     (trotz Erwartung, siehe Aktions-Fehlermeldung "Unexpected input(s)").
  2. DESCRIPTIONs `Additional_repositories`-Feld (die naheliegende
     Alternative) wird von `pak` NICHT automatisch gelesen - identischer
     Fehler trotz gesetztem Feld. **Tatsaechlich wirksam**: ein `.Rprofile`
     im Repo-Root, das `options(repos = c(mlrorg = ..., CRAN = ...))`
     setzt - `pak` liest `getOption("repos")` direkt, sowohl lokal als auch
     in der von `setup-r-dependencies@v2` gestarteten R-Session.
  3. Der Push mit nur `.Rprofile`-Aenderung loeste den Workflow gar nicht
     aus - der Pfad-Filter deckte `.Rprofile` nicht ab (kein `**.R`-Match).
     Filter ergaenzt.
  4. Pipeline lief bis `100_lightgbm_tuning.R`, dann "packages could not be
     loaded: DiceKriging" - eine SUGGESTS-Abhaengigkeit von `mlr3mbo`, die
     `pak` nicht transitiv installiert, wenn `mlr3mbo` selbst nur ein
     Imports-Eintrag in der eigenen `DESCRIPTION` ist. `DiceKriging` +
     vorsorglich weitere ueblicherweise benoetigte `mlr3mbo`-Suggests
     (`rgenoud`/`nloptr`/`lhs`/`emoa`/`fastGHQuad`) ergaenzt, um nicht noch
     eine 18-Minuten-Iteration zu riskieren.

  **Ergebnis: gruener Lauf, alle 12 Schritte, 20:47 Min beim ersten Mal
  (kein Cache-Treffer)** - siehe https://github.com/kubischraumzentriert/
  AutoML/actions/runs/31792180343. Kuenftige Laeufe sollten dank
  `cache-version: 1` im Paket-Schritt deutlich schneller sein (erster Lauf
  baut den Cache erst auf).

- **`testthat`-Grundgeruest fuer echte Korrektheitstests (2026-08-19).**
  Anlass: externes ChatGPT-Review des Repos identifizierte zutreffend,
  dass die CI bisher NUR ein Smoke-Test ist (der Workflow-Kommentar sagt
  das selbst schon so) - keine automatisierten Tests mit bekanntem
  Erwartungswert. Gegen den Code geprueft statt blind uebernommen: die
  Behauptung stimmt (kein `tests/testthat/`, `DESCRIPTION` explizit "kein
  echtes R-Paket"); der Vorschlag "Windows-CI waere wertvoll" traf
  hingegen aus dem falschen Grund zu (die Smoke-Test-CI laeuft auf
  `ubuntu-latest`, nicht Windows - die dokumentierten Windows-Bugs dieser
  Session waeren dort gar nicht aufgefallen). Groessere Vorschlaege des
  Reviews (volle Paketifizierung, YAML-Config-Schicht, gemeinsamer Core
  mit `MLR3_Regression`) bewusst NICHT uebernommen - passen nicht zur
  etablierten Arbeitsweise (lose Kopplung, nummerierte Skripte) und haben
  unklaren Zusatznutzen fuer ein Ein-Personen-Forschungsrepo.

  Umgesetzt: `tests/testthat/` mit 3 Testdateien (24 Checks, alle gruen)
  fuer bereits mehrfach manuell verifizierte, aber bisher nicht
  konservierte Pruef-Logik:
  - `test-group_resampling.R`: `.eta_squared()`/`.cramers_v()`/
    `test_group_significance()` - Positiv-/Negativ-Kontrollen (perfekte
    Gruppenstruktur -> Statistik=1/kleiner p-Wert, keine Struktur ->
    Statistik~0/grosser p-Wert), degenerierter Fall (1 Level -> 0 statt
    NaN), Dispatch numerisch/kategorial.
  - `test-class_multiplier_tuning.R`: `apply_class_multipliers()` von
    Hand nachgerechnet, `prior_correction_multipliers()` gegen die
    1/prior-Formel verifiziert, `tune_class_multipliers()` monoton
    besser als Grid/Prior/roher argmax auf einem synthetischen
    unbalancierten 3-Klassen-Fall.
  - `test-generalization_gap.R`: `cohens_d()` gegen die gepoolte-SD-
    Formel von Hand + NA-statt-Division-durch-0-Fall,
    `bootstrap_score_distribution()` Laenge/Plausibilitaet,
    `compare_score_distributions()` erkennt eine echte Luecke UND zeigt
    KEINE bei identischen Verteilungen.

  `tests/testthat.R` als Runner (`test_check()` funktioniert nicht ohne
  echtes Paket, daher `test_dir()` + jede Testdatei sourced ihr Modul
  direkt via `testthat::test_path()`). Neuer `unit-tests`-Job in
  `.github/workflows/ci-smoke-test.yml` (parallel zum bestehenden
  `smoke-test`-Job, eigene schlanke Dependency-Liste statt des vollen
  Smoke-Test-Baums). `DESCRIPTION` um `Suggests: testthat` +
  `Config/testthat/edition: 3` ergaenzt.

  **Naechste Kandidaten fuer weitere Tests** (nicht in diesem Schritt):
  Ensemble-Selection-Greedy-Algorithmus (aktuell nur als Skriptlogik in
  `149_ensemble_selection.R`, keine eigenstaendige Funktion - muesste erst
  extrahiert werden), Leak-Audit-Einzelschritte (`015` ist ebenfalls ein
  monolithisches Skript, keine Funktionen).

- **Ranger-Absturz bei leerer Zielklasse - Root Cause bestaetigt UND
  Absicherung umgesetzt (2026-08-14).**
  Nachtrag zum obigen Spawn-Task (`classif.ranger` stuerzt auf eine
  Zielspalte mit einer leeren Faktorstufe `""` ab, LDA/Multinom nicht).

  **Frage 1 - warum ausgerechnet Ranger, nicht LDA/Multinom?** Per Minimal-
  Repro isoliert (mehrere Varianten gegeneinander getestet: mit/ohne
  `respect.unordered.factors="order"`, mit/ohne Faktor-Feature-Spalten,
  Zielklassenname `""` vs. ein gleich seltenes `"rare"` mit n=1) - **die
  Ursache liegt NICHT an der Seltenheit der Klasse (n=1 mit einem normalen
  Namen wie `"rare"` crasht NICHT), sondern ausschliesslich am woertlichen
  Klassennamen `""`, und ausschliesslich in ranger's eigenem R-Code, nicht in
  mlr3/mlr3learners/mlr3pipelines:**
  `ranger::ranger()`s Nachbearbeitung fuer Wahrscheinlichkeits-Forests
  (`R/ranger.R` im `imbs-hl/ranger`-Repo, im `oob.error`-Zweig fuer
  `treetype == 9`) macht:
  ```r
  colnames(result$predictions) <- unique(y)
  if (is.factor(y)) {
    result$predictions <- result$predictions[, levels(droplevels(y)), drop = FALSE]
  }
  ```
  `colnames<-` legt die Spalte `""` korrekt an (verifiziert:
  `colnames(m) <- unique(y)` erzeugt tatsaechlich eine Spalte mit dem
  woertlichen Namen `""`). Der Absturz passiert erst bei der anschliessenden
  Indizierung `result$predictions[, levels(droplevels(y)), drop = FALSE]`:
  **R's `[`-Operator behandelt einen Spaltennamen `""` bei der
  Character-Indizierung nie als echten Treffer, selbst wenn eine Spalte
  tatsaechlich `""` heisst** - reproduziert in einem isolierten 5-Zeilen-
  R-Schnipsel (`m[, "", drop = FALSE]` wirft `subscriptOutOfBoundsError`,
  obwohl `match("", colnames(m))` den richtigen Index liefert). Das ist
  reines Basis-R-Verhalten (Character-Matching in `[.default]` behandelt
  `""` als "kein Name angegeben", nicht als literalen String), keine
  mlr3-Eigenheit. `ranger::ranger()` crasht also **immer**, sobald ein
  Zielwert exakt `""` ist - unabhaengig von Seltenheit, Feature-Spalten oder
  Parametern. LDA (`MASS::lda`/`predict.lda`) und Multinom (`nnet::
  multinom`/`predict.multinom`) durchlaufen einen komplett anderen
  Vorhersage-Code-Pfad ohne diese Spaltennamen-Indizierung und sind davon
  nicht betroffen - deshalb liefen sie in der urspruenglichen Debug-Session
  durch. **Fazit: ein bestaetigter Implementierungs-Grenzfall in
  `ranger` selbst (keine mlr3pipelines-Interna, kein "erwartbares" Verhalten
  bei seltenen Klassen im Allgemeinen) - jede andere, nicht-leere
  Klassenbezeichnung mit n=1 crasht NICHT.** Verifikationsskripte lagen in
  der Session unter `repro_ranger_crash{2,3,4,5,6}.R` (Scratch, nicht
  eingecheckt) - kleinstes crashendes Beispiel: 400 Zeilen, 2 numerische
  Features, `classif.ranger` (Default-Parameter) in einer `imputemedian %>>%
  imputemode`-Pipeline, stratifizierter `rsmp("holdout")`, Zielspalte mit
  genau 1 Zeile Klasse `""`.

  **Frage 2 - Verteidigung (umgesetzt):** neue Funktion `check_target_column()`, analog zu
  `warn_rare_factor_levels()` in `005_benchmark_runtime.R`, aber fuer die
  ZIELSPALTE statt Feature-Spalten, aufgerufen in `020_task.R` direkt nach
  `train <- fread(train_path)` (also auf der vollen Rohspalte, bevor
  `slice_sample`/`as.factor()` greifen - faengt so auch Faelle ab, in denen
  eine kaputte Zeile durch Zufall aus dem 10%-Subset herausfaellt und der
  Fehler sich unbemerkt bis `150_train_full_model.R` auf dem VOLLEN
  Datensatz durchschleicht). Zwei harte Stops (NA, leerer String - beide
  waeren sonst als eigene, spaeter fatale Faktorstufe still durchgereicht)
  und eine Warnung (extrem seltene, aber gueltige Klasse - kein Ranger-Bug,
  aber ein bekanntes Stabilitaetsrisiko fuer stratifizierte Splits/BAcc-MCC):

  ```r
  # Prueft die ZIELSPALTE selbst (Ergaenzung zu warn_rare_factor_levels(),
  # die nur FEATURE-Spalten prueft) auf NA, leere Faktorstufen ("") und
  # extrem seltene Klassen, BEVOR ein mlr3-Task gebaut wird. Anlass: ein
  # Fixture-Bug im CI-Smoke-Test erzeugte durch einen fwrite/fread-Rundweg
  # eine einzelne Zeile mit leerem String "" im Ziel (aus einem
  # urspruenglichen NA) - das liess classif.ranger mit einem kryptischen
  # "Indizierung ausserhalb der Grenzen" abstuerzen. Bestaetigte Root
  # Cause (siehe TARGETS.md, Eintrag "Ranger-Absturz bei leerer
  # Zielklasse"): R's Matrix-Indizierung nach Spaltenname behandelt ""
  # nie als echten Treffer, selbst wenn diese Spalte existiert -
  # ranger::ranger()s eigene Nachbearbeitung "result$predictions[,
  # levels(droplevels(y)), drop = FALSE]" (R/ranger.R) schlaegt daher
  # IMMER fehl, sobald ein Zielwert exakt "" ist - unabhaengig von
  # Seltenheit. Betrifft nicht nur synthetische Fixtures: echte
  # Kaggle-CSVs koennen vereinzelte NA/leere Werte im Ziel haben, die ein
  # naiver as.factor()-Cast genau in diese Falle laufen liesse.
  check_target_column <- function(target_values, min_count_per_class = 2) {
    if (anyNA(target_values)) {
      stop(
        "Zielspalte enthaelt ", sum(is.na(target_values)), " NA-Wert(e). ",
        "Ein naiver as.factor()-Cast wuerde NA in eine eigene Faktorstufe ",
        "verwandeln, die spaeter classif.ranger mit einem kryptischen ",
        "Ranger-internen Fehler abstuerzen laesst (siehe TARGETS.md, ",
        "\"Ranger-Absturz bei leerer Zielklasse\"). Bitte vor dem Task-Bau ",
        "entscheiden: Zeilen entfernen oder NA bewusst als eigene Klasse ",
        "kodieren (z.B. \"unknown\").",
        call. = FALSE
      )
    }

    target_chr <- as.character(target_values)
    n_empty <- sum(!is.na(target_chr) & target_chr == "")
    if (n_empty > 0) {
      stop(
        "Zielspalte enthaelt ", n_empty, " leere(n) String-Wert(e) (''). ",
        "as.factor('') erzeugt eine Faktorstufe mit dem Namen '', die ",
        "classif.ranger IMMER zum Absturz bringt (bestaetigte Root Cause: ",
        "R's Matrix-Indizierung nach Spaltenname behandelt '' nie als ",
        "Treffer, selbst wenn diese Spalte existiert - ranger::ranger()s ",
        "eigene Nachbearbeitung 'result$predictions[, levels(droplevels(y)), ",
        "drop = FALSE]' schlaegt daher fehl, siehe TARGETS.md, \"Ranger-",
        "Absturz bei leerer Zielklasse\"). Typische Ursache: ein verstecktes ",
        "NA, das bei einem CSV-Rundweg (fwrite/fread) zu '' wurde. Bitte vor ",
        "dem Task-Bau bereinigen (leere Strings zu NA machen und behandeln, ",
        "oder Zeilen entfernen).",
        call. = FALSE
      )
    }

    tab <- table(target_values)
    rare <- tab[tab < min_count_per_class]
    if (length(rare) > 0) {
      warning(
        "Zielklasse(n) mit weniger als ", min_count_per_class, " ",
        "Beobachtung(en) gefunden: ",
        paste(names(rare), "=", rare, collapse = ", "), " - stratifizierte ",
        "CV/Holdout-Splits, Klassifikationsmasse (BAcc/MCC) und manche ",
        "Learner koennen bei derart duenn besetzten Klassen instabil werden. ",
        "Erwaegen: Zeilen entfernen oder Klasse mit einer anderen ",
        "zusammenfassen.",
        call. = FALSE
      )
    }

    invisible(NULL)
  }
  ```

  Aufrufstelle in `020_task.R` (vor `train_small <- train %>% ...`):
  ```r
  train <- fread(train_path)
  check_target_column(train[[target_col]])
  ```

  **Warum zwei harte `stop()` statt nur Warnungen (anders als
  `warn_rare_factor_levels()`)**: NA/`""` im Ziel sind strukturell IMMER
  fatal (spaetestens bei `classif.ranger`, s.o.) oder zumindest inhaltlich
  bedeutungslos als Klasse - anders als bei seltenen, aber validen
  Feature-Leveln (wo `collapsefactors` oder Ausschluss echte Alternativen
  sind) gibt es hier keine sinnvolle Fortsetzung ohne Nutzerentscheidung.
  Ein fruehes, sprechendes `stop()` in `020_task.R` ist strikt besser als
  ein Absturz zehn Skripte spaeter mit einem fuer Ranger-Interna
  spezifischen Fehler, der weder den Grund noch die betroffene Spalte
  nennt. Die dritte Pruefung (seltene, aber gueltige Klassen) bleibt
  bewusst eine Warnung, da sie kein Ranger-spezifischer Bug ist, sondern ein
  allgemeines Stratifizierungs-/Stabilitaetsrisiko (analog
  `warn_rare_factor_levels()`s Warn-statt-Stop-Politik).

  **Umsetzung (2026-08-14)**: `check_target_column()` in
  `005_benchmark_runtime.R` ergaenzt, Aufruf in `020_task.R` direkt nach
  `train <- fread(train_path)` (volle Rohspalte, vor `slice_sample()`/
  `as.factor()`). Beide `ci_smoke_test/`-Kopien synchron mitgezogen
  (byte-identisch zum Root-Skript, wie zuvor). Getestet: (1) Root-Fixture
  (`ci_smoke_test/020_task.R` gegen die bereits fehlerfreie 800-Zeilen-
  Fixture) laeuft unveraendert durch, keine Regression; (2) vier
  isolierte `check_target_column()`-Aufrufe direkt verifiziert - NA stoppt
  mit der geplanten Meldung, leerer String stoppt mit der geplanten
  Meldung, eine seltene-aber-gueltige Klasse (n=1, Name `"rare"`) wirft nur
  die Warnung und laeuft weiter, eine unauffaellige Zielspalte erzeugt
  keine Meldung.

  **Bewusst offen gelassen**: `min_count_per_class = 2` bleibt eine
  Faustregel (kleinstmoegliche Zahl, unter der ein stratifizierter Split
  eine Klasse strukturell nicht auf beide Seiten verteilen kann), kein
  statistisch hergeleiteter Wert - ein 2-Projekt-Kriterium (analog
  `warn_rare_factor_levels()`s eigener Historie) waere sinnvoll, bevor der
  Wert als endgueltig gilt.

- **"Wetterballon"-Idee getestet (2026-08-14) - NEGATIVES/GEMISCHTES
  ERGEBNIS, nicht umgesetzt.** Frage: korreliert eine BILLIGE Lernkurve
  (`classif.rpart`) mit der TEUREN (`classif.ranger`) genug, um sie
  kuenftig als guenstigen Stellvertreter zu nutzen? An 6 kleinen Projekten
  getestet (relative Steigung = Regressions-Slope*log(2) / Score-
  Spannweite, dieselbe Metrik wie in `report_learning_curve()`, fractions
  0.2/0.4/0.6/0.8/1.0, 3-fache CV, 3 Wiederholungen):

  | Projekt | Zeilen | rpart (billig) | Ranger (teuer) | Uebereinstimmung |
  |---|---|---|---|---|
  | steel-plates-fault | 1941 | +0.389 | +0.444 | ja |
  | satimage | 6430 | **-0.259** | **+0.435** | **NEIN - Vorzeichen entgegengesetzt** |
  | wine (WineQualityDataset) | 2056 | -0.106 | -0.392 | Richtung gleich, Groessenordnung sehr unterschiedlich |
  | yeast (Label Class1) | 2417 | +0.403 | +0.430 | ja |
  | scene (Label Beach) | 2407 | +0.478 | +0.476 | ja, fast identisch |
  | birds (Label Swainson.s.Thrush) | 645 | +0.446 | +0.449 | ja, fast identisch |

  Spearman-Korrelation ueber alle 6: **0.71** - bei n=6 statistisch nicht
  signifikant (kritischer Wert fuer p<0.05 waere ~0.81). Wichtiger als die
  Korrelationszahl: `satimage` zeigt ein ENTGEGENGESETZTES Vorzeichen -
  die billige Kurve haette "eher abflachend" signalisiert, waehrend Ranger
  tatsaechlich klar noch steigt. Ein einzelner klarer Gegenbeweis reicht,
  um der Idee nicht zu vertrauen, selbst bei einer moderaten
  Gesamtkorrelation. **Entscheidung: nicht umgesetzt, Idee bleibt
  verworfen** (nicht nur "vertagt") - waere jederzeit mit demselben Skript
  an weiteren Projekten neu pruefbar, falls neue Evidenz dazukommt.

  Nebenbefund beim Aufbau: `classif.rpart` stuerzte bei einer sehr
  seltenen Zielklasse (14/645, `Brown.Creeper` im `birds`-Datensatz) bei
  kleinen Lernkurven-Anteilen ab (zu wenige Positive je CV-Fold) - mit dem
  haeufigsten Label (`Swainson.s.Thrush`, 103/645) behoben. Kein
  Template-Bug, aber ein praktischer Hinweis fuer kuenftige Lernkurven-
  Anwendungen auf stark unbalancierten Zielspalten.

  Alle 6 Ergebnisse in die jeweiligen Projekt-`experiments.db` geloggt
  (measure_name `weather_balloon_relative_slope`) und per
  `merge_project_experiments.R` in die zentrale DB gemergt - siehe
  naechster Punkt fuer einen dabei gefundenen echten Bug im Merge-Skript.

- **Merge-Skript-Bug gefunden + behoben (2026-08-14): `merge_project_
  experiments.R` mergte Projekte nur EINMAL, nicht inkrementell.**
  Beim Versuch, die Wetterballon-Ergebnisse zu migrieren, fiel auf, dass
  `openml-satimage-multiclass` in der zentralen DB nur 6 `model_config`-
  Zeilen aus 3 Runs hatte, waehrend die PROJEKTEIGENE `experiments.db`
  bereits 57 Zeilen aus 6 Runs enthielt. Root Cause: das alte Skript prueft
  nur "existiert `proj_name` schon in der Ziel-DB?" - wenn ja, wird die
  GESAMTE Quelle uebersprungen, auch wenn seither neue Runs lokal
  dazukamen. `satimage` wurde im Juli (fuers urspruengliche OvR-Kurven-
  Projekt) einmal gemergt; alle 3 Runs aus DIESER Session (Split-Size-
  Sensitivity/Lernkurve/Seed-Stabilitaet/Generalisierungsluecke - alle
  vier ADR-003-Bestaetigungen fuer `satimage` in diesem Backlog!) blieben
  lokal haengen, obwohl das Skript brav "Bereits vollstaendig gemergt"
  meldete.

  **Betraf nicht nur `satimage`**: beim Beheben zeigte sich, dass auch
  `playground-series-s5e12`/`s6e5`/`s6e8`/`tweet` denselben Rueckstand
  hatten (neue lokale Runs seit ihrem jeweiligen Erst-Merge nie zentral
  gelandet).

  **Fix**: von "einmal pro Projekt" auf "pro Zeile, gefiltert nach UUID-
  Schluessel" umgestellt - `INSERT ... WHERE <id_col> NOT IN (SELECT
  <id_col> FROM <tabelle>)` fuer jede der 8 Tabellen, statt einer
  proj_name-basierten Vorab-Pruefung. Dadurch entfaellt die alte
  Unterscheidung "noch nicht gemergt / bereits gemergt" komplett - jede
  Quelle wird immer verarbeitet, die Filterung macht wiederholte Laeufe
  automatisch idempotent UND inkrementell zugleich. Verifiziert: 3x
  hintereinander ausgefuehrt, ab dem 2. Lauf ueberall `+0 Zeilen` fuer
  alle Projekte/Tabellen.

- **Workflow-Smoke-Test an neuem OpenML-Projekt (2026-08-14,
  `openml-credit-g`) - ERLEDIGT, 2 echte Funde behoben.** Auf Nutzerwunsch
  bewusst OHNE Rueckfragen durchgefuehrt, nur nach der in `WorkflowDescription.md`
  dokumentierten Entscheidungslogik - Test, ob ein Mensch ohne KI-Agent
  ebenso durchkommen wuerde. German Credit Data (OpenML 31, 1000 Zeilen,
  binaer gut/schlecht 700/300) - neu fuer diese Session, erstes BINAERE
  Projekt seit den Backports von `022`/`023`/`092`/`130`+`class_multiplier_
  tuning.R`/`136`. Alle 10 Kernskripte liefen fehlerfrei durch
  (`015`/`020`/`022`/`023`/`030`/`080`/`090`/`100`/`092`/`130`/`136`).

  **OpenML-Projekte haben keinen externen Testsatz** (anders als die
  Kaggle-Projekte dieser Session `health_condition`/`s6e6`/`s6e8`) - alle
  Zahlen sind interne CV-/Holdout-Schaetzungen auf demselben Datensatz,
  keine externe Leaderboard-Bestaetigung moeglich. `136_generalization_
  gap.R` liefert dafuer den naechstbesten internen Check (eigener 80/20-
  Split, Bootstrap-Test-Verteilung gegen die CV-Verteilung) - beide
  getunten Modelle unauffaellig.

  **Fund 1 - Dokumentationsluecke in `WorkflowDescription.md` Phase 0**:
  war ausschliesslich auf Kaggle-Wettbewerbe zugeschnitten (`train.csv`/
  `test.csv`/`sample_submission.csv`, "Kaggle-Wettbewerbsseite lesen") -
  fuer ein OpenML-Standalone-Projekt (kein externer Testsatz, keine
  Bewertungsmetrik-Vorgabe) gab es keine dokumentierte Anleitung, obwohl
  diese Session laengst eine etablierte (aber nirgends niedergeschriebene)
  Konvention dafuer hatte. **Behoben**: Phase 0 um einen Abschnitt "Zwei
  Projektarten" ergaenzt (OpenML-Abweichungen von den Kaggle-Schritten:
  `mlr3oml::odt(<exakte-ID>)` statt Kaggle-Download, `baseline_measure_ids`
  auf Template-Konvention statt Wettbewerbsseite, `suggest_subset_
  fraction.R` vor `000_config.R`).

  **Fund 2 - `class_multiplier_tuning.R`: Nelder-Mead auf 1 Freiheitsgrad.**
  Bei binaeren Aufgaben (2 Klassen) hat die kontinuierliche Multiplikator-
  Verfeinerung nur 1 freien Parameter (die Referenzklasse bleibt bei 1.0
  fixiert) - `optim(method="Nelder-Mead")` warnte 4x "eindimensionale
  Optimierung mit Nelder-Mead ist unzuverlaessig: nutze direkt Brent oder
  optimize()" (R selbst empfiehlt die Alternative in der Warnung). Kein
  Absturz, plausible Ergebnisse, aber ein echter, bisher unbeobachteter
  Fall (alle bisherigen Threshold-Tuning-Bestaetigungen dieser Session
  waren >=3-Klassen). **Behoben**: Fallunterscheidung ergaenzt -
  `length(others) == 1` (binaer) -> `optimize()` (Brent) auf einem festen
  weiten Log-Intervall, kein Start-Loop noetig; `length(others) >= 2`
  (>=3 Klassen) -> weiterhin Nelder-Mead mit mehreren Startpunkten wie
  bisher. Regressionsgetestet gegen `openml-credit-g`: keine Warnung mehr,
  UND ein besseres Optimum gefunden (LightGBM ungewichtet: BAcc 0.730 statt
  vorher 0.713 mit Nelder-Mead) - `optimize()` ist fuer den 1D-Fall nicht
  nur sauberer, sondern findet hier auch das tatsaechliche Optimum
  zuverlaessiger.

- **Externe Quelle geprueft (2026-08-14): "Introduction to Deep Learning
  Using R" (Taweh Beysolow II, Apress 2017) - KEINE Anwendung, dokumentiert
  statt verworfen.** Buchdatei: `\\endressserver\homes\MeineOrdner\
  MeineDokumente\50_ebook\010_DataScience\Introduction-to-Deep-Learning-
  Using-R.pdf`. Textextraktion via `pdftotext -layout` (kein `pdftoppm`
  auf diesem Rechner installiert, daher kein Seiten-Rendering moeglich -
  fuer reinen Text ausreichend). Kapitel 1-7 (SLP/MLP/CNN/RNN/Autoencoder/
  RBM/DBN) sind generische 2017er Deep-Learning-Theorie mit Bild-/
  Sequenzdaten-Fokus; Kapitel 8 (Experimental Design/Heuristics: ANOVA,
  Plackett-Burman/Full-Factorial/Space-Filling-DOE, A/B-Testing, Feature-
  Selection via AIC/BIC/PCA/Factor-Analysis/CCA, Encoding-Fallstricke).

  **RBM (Restricted Boltzmann Machine)**: zweischichtiges, ungerichtetes
  Energiemodell (sichtbare + versteckte Schicht, keine Verbindungen
  INNERHALB einer Schicht -> faktorisierbare bedingte Verteilungen),
  Training via Contrastive Divergence (Gibbs-Sampling-Approximation des
  Log-Likelihood-Gradienten, kein Backprop). **DBN (Deep Belief Network)**:
  Stapel von RBMs, schichtweise gierig vortrainiert, optional mit Backprop
  feinjustiert (Hinton & Osindero 2006) - geloest wurde damit primaer das
  Problem verschwindender Gradienten bei zufaelliger Gewichtsinitialisierung
  in tiefen Netzen.

  **Warum kein Thema mehr**: seit ~2010 loesen bessere Init-Schemata
  (Xavier/Glorot, He), ReLU statt Sigmoid, Batch-Normalization und Residual-
  Connections dasselbe Trainierbarkeits-Problem direkt per End-to-End-
  Backprop - generative RBM/DBN-Vortrainierung ist seither aus der Praxis
  verschwunden.

  **Wo die Pipeline ueberlegen ist (mit Referenz zum Buch)**:
  - RBM/DBN/CNN/RNN (Kap. 1-7) sind fuer Bild-/Sequenzdaten konzipiert,
    nicht fuer strukturierte/tabellarische Daten wie unsere Kaggle-/OpenML-
    Projekte. Fuer Tabellendaten dominieren gut getunte GBMs (LightGBM/
    XGBoost/CatBoost, unsere `090`/`100`-Bausteine) neuronale Architekturen
    empirisch durchgehend - RBM/DBN eingeschlossen (vgl. `mlr3torch`-
    Recherche in [[project_literatur_review_produktion_ki]]: falls ueberhaupt
    neuronal, dann modernere tabellar-spezifische Architekturen wie FT-
    Transformer via `mlr3torch`, nicht RBM/DBN).
  - Kap. 8s DOE-Methoden (Plackett-Burman, Full-Factorial, Space-Filling)
    fuer Hyperparameter-Suche sind strikt schwaecher als das bereits
    genutzte `mlr3mbo` (Bayesian Optimization/MBO) - starre faktorielle
    Designs vs. sequenzielle, modellbasierte Verfeinerung mit weniger
    Evaluationen.
  - Kap. 8s Bootstrap-Signifikanztest-Empfehlung ("Fishers Prinzipien",
    Test of Significance) ist konzeptionell bereits durch
    `136_generalization_gap.R` abgedeckt (Bootstrap-Test-Verteilung gegen
    CV-Verteilung, siehe `REFERENZ_GENERALIZATION_GAP.md`).
  - Kap. 8s PCA/Factor-Analysis/CCA zur Dimensionsreduktion adressieren
    kein Problem, das unsere GBM-lastige Pipeline hat (Baumverfahren sind
    robust gegen hochdimensionale/korrelierte Features; PCA wuerde hier
    eher Information kosten als helfen).
  - Kap. 8s Kategorial-Encoding-Diskussion (Label-Encoding-Fallstricke,
    High-Cardinality-Streets-Beispiel -> Cluster-Nummer als Ersatz) ist
    durch unser bestehendes Target-Encoding bereits geloest.

  **Entscheidung**: keine Code-Aenderung, keine ADR-003-Pipeline gestartet
  - Buch ist ein generisches 2017er Lehrbuch ohne Technik, die etwas
  schlaegt, das die Pipeline (mlr3mbo/GBM/Ensemble-Selection/Target-
  Encoding) bereits besser loest. Dient hier als dokumentierter Negativ-
  Befund, falls die Frage spaeter erneut aufkommt.

- **Multi-Label Per-Label-NA-Maskierung generalisiert und ins Template
  zurueckgefuehrt (2026-08-21).** Anlass: `tox21-multilabel` (Chemie,
  molekulare Fingerprints) war das erste Multi-Label-Projekt mit ECHTEN
  fehlenden Labels (26-38% je Assay nicht getestet) - die bisherigen 3
  Bestaetigungsprojekte (yeast/scene/birds) hatten alle vollstaendige
  Labelmatrizen. `binary_relevance_pool()` (`multilabel.R`) filtert jetzt
  pro Label auf nicht-NA-Zeilen (Training UND Vorhersage) und gibt NACH
  ROW-ID BENANNTE Wahrscheinlichkeits-Vektoren zurueck statt rein
  positionaler - `021_multilabel_workflow.R` wertet `names(...)` aus statt
  positional gegen `tune_ids`/`eval_ids` zu indizieren, und beschraenkt
  die GEPOOLTEN Metriken (Hamming Loss/Subset Accuracy/Makro-Mikro-F1) auf
  Eval-Zeilen, die fuer ALLE Labels getestet wurden (`eval_complete`).
  **Regressionsgetestet als No-op gegen 2 der 3 komplett-gelabelten
  Projekte**: `yeast` (Hamming Loss 0.1933, Subset Accuracy 0.1798 bei
  accuracy-getunter Schwelle - exakt identisch zu den vor dieser Aenderung
  bekannten Referenzwerten), `scene` (Hamming Loss 0.0806->0.0719, Subset
  Accuracy 0.581->0.664 bei Tuning - konsistent mit dem etablierten
  3-4-von-4-Verbesserungsmuster, keine gespeicherten exakten Referenz-
  werte verfuegbar, aber plausibilitaetsgeprueft). `birds` nicht erneut
  gegengeprueft (Zeitersparnis, 2 von 3 als ausreichende No-op-Evidenz
  gewertet). **Positiv bestaetigt gegen `tox21-multilabel`**: die
  generalisierte Template-Version reproduziert die Zahlen des
  eigenstaendigen NA-maskierten Skripts byte-identisch (Hamming Loss
  0.02590090/0.02942005, Subset Accuracy 0.7922297/0.7652027). Damit
  erfuellt: No-op an bestehenden Projekten + 1 echte positive Bestaetigung
  - nach ADR-003 ausreichend fuer einen Backport (kein neuer Datensatz
  noetig). `tox21-multilabel`s eigenstaendiges Skript durch die
  Template-Version ersetzt (identisch). Committed+gepusht.

- **4. und letzter Versuch fuer die kumulative Leak-PAAR-Bestaetigung
  (2026-08-21), Suche eingestellt.** `fremtpl2-claim-leak-test`: bewusst
  konstruierter Leak aus echten French-Motor-TPL-Daten (OpenML
  `freMTPL2freq`/`freMTPL2sev`) - Ziel "hat mindestens 1 Schaden",
  Features faelschlich inkl. zweier Ex-post-Aggregate aus der Severity-
  Tabelle (`claim_amount_total`, `claim_record_count`), nach demselben
  Muster wie SBAs Datum+Betrag konstruiert. Ergebnis: `claim_amount_total`
  dominiert einzeln (85.4%), `claim_record_count` bekommt **0% Gain**
  (ueber die 0-vs->0-Schwelle nahezu perfekt redundant zu
  `claim_amount_total`) - erscheint nie in der Top-k-Gain-Rangliste, die
  kumulative Erweiterung ist dafuer strukturell blind. **Schritt 2
  (Determinismus) faengt es trotzdem** (100% Reinheit bei den Werten
  1/2/3) - beide Features landen als Verdaechtige in Schritt 4 (BAcc
  0.8662->0.5012), nur ueber zwei verschiedene Mechanismen statt ueber
  die kumulative Schwelle. **Mechanistische Erklaerung fuer den
  wiederholten Fehlschlag**: SBAs Paar (`ChgOffDate`+`ChgOffPrinGr`)
  behielt trotz Korrelation genug UNABHAENGIGE Information, dass
  LightGBM beide nutzte (91%+7%) - bei allen 4 hier getesteten
  Kandidaten war das Paar entweder nahezu perfekt redundant
  (Substitutionskette, 0% Gain fuer den Partner) oder ueber viele
  Features verteilt (Lending Club). Diese spezifische Zwischenstufe
  laesst sich offenbar nicht einfach konstruieren. **Entscheidung (mit
  Nutzer abgestimmt): die gezielte Suche fuer dieses Muster wird nach 4
  Fehlversuchen eingestellt** - der Aufwand steht nicht mehr im
  Verhaeltnis zum Erkenntnisgewinn. Die 2. unabhaengige Bestaetigung
  bleibt offen, aber ohne aktiven Suchauftrag. Volle Herleitung in
  `fremtpl2-claim-leak-test/README.md`.

- **`error_analysis_uncertainty_threshold` bei binaeren Aufgaben gefixt
  (2026-08-21).** Bei einer Bestandsaufnahme lokaler `TEMPLATE_FRICTION.md`-
  Dateien (ML_Learning) auf noch offene Backport-Kandidaten fiel auf, dass
  die meisten bereits erledigt waren (Docs nur nie nachgezogen - gleiches
  Muster wie bei `AGENTS.md`, siehe oben), ABER `playground-series-s6e5`s
  Fund von 2026-07 zur strukturell entarteten `error_analysis_uncertainty_
  threshold=0.5` bei GENAU 2 Klassen (vorhergesagte Klasse hat immer
  Wahrscheinlichkeit >=0.5, "unsicher"-Eimer bleibt immer leer) war
  tatsaechlich nie zurueckgefuehrt. Gefixt in `147_error_analysis_ranger_
  confidence.R`: bei `n_classes<=2` wird der Median der Ranger-Konfidenz
  UNTER DEN FEHLERN als adaptive Grenze genutzt statt des Fixwerts.
  Regressionsgetestet byte-identisch gegen `health_condition` (3-Klassen,
  719/22 Fehler, 8.6%/77.7% Rescue-Rate, 138/136 harte Faelle - exakt wie
  vorher dokumentiert), binaerer Zweig isoliert synthetisch verifiziert
  (alter Bucket waere leer gewesen, neuer sinnvoll ~50/50 gefuellt).
  Nebenbei einen inkonsistenten hartcodierten `0.5`-Literal in der
  Bucket-Kategorisierung gefixt (nutzte die Konfigvariable bisher nicht).

- **Schritt 1b (Korrelations-Cluster): 5. reale Spezifitaetsbestaetigung,
  bisher groesster Cluster (2026-08-21, `geoai-aquaculture-pond-
  identification-challenge`).** Groesster gefundener Cluster: 36 Features
  (VH/VV-Radar- + optische Baender ueber mehrere Beobachtungsmonate),
  56.3% Gain-Importance - legitime, natuerlich stark korrelierte
  Zeitreihen-Wiederholung DERSELBEN Messung (kein Leak). Score-Effekt
  beim Entfernen: -0.0001 (praktisch null) - korrekt NICHT geflaggt.
  Wichtiger Beleg: der Retraining-Beweis (nicht nur Korrelation+Gain-
  Summe) entscheidet - ein reiner Schwellenwert-Check haette bei 56.3%
  Gain-Anteil eines derart grossen Clusters ein hohes Fehlalarm-Risiko
  gehabt. Reiht sich ein neben `health_condition`/`sba-loan-default`/
  `aer-creditcard-leak-test`/`bbbp-classification` (alle korrekt still).

- **CI Smoke Test war 3 Commits lang rot, unbemerkt (2026-08-20 bis
  2026-08-23), gefixt.** Root Cause: beim Hinzufuegen von Schritt 1b
  (Korrelations-Cluster, Commit `17ecf56`) wurde `ci_smoke_test/000_
  config.R` nicht mitgepflegt - nur das Haupt-`000_config.R` bekam
  `leak_audit_cluster_correlation_threshold`/`_drop_threshold`. Die CI
  kopiert `015_target_leak_audit.R` bei jedem Lauf frisch aus dem Root
  (`ci_smoke_test/*.R` ist gitignored, reine Laufzeit-Kopie), aber die
  Config-Datei bleibt der committete Stand - lief deshalb lokal ueberall
  erfolgreich (jedes getestete Projekt hatte seine eigene, nachgepflegte
  Config), aber nie gegen die CI-Fixture selbst. Betraf 3 Commits/CI-Laeufe
  (`17ecf56` Schritt 1b, `94d0eed` NA-Maskierung, `103c4e4` uncertainty-
  threshold-Fix) - alle schlugen am selben fruehen Schritt fehl, spaetere
  Commits wurden also nie tatsaechlich gegen die Fixture getestet, obwohl
  sie inhaltlich unabhaengig und korrekt waren. Gefixt (Commit `4dedbb6`),
  lokal gegen die Fixture verifiziert, CI-Lauf `32658179935` gruen
  (smoke-test + unit-tests). **Lehre**: `ci_smoke_test/000_config.R` ist
  eine SEPARATE, eigenstaendig zu pflegende Config-Datei - neue
  `leak_audit_*`/sonstige Config-Variablen dort IMMER mitziehen, wenn ein
  Skript im CI-Kopierpfad (`.github/workflows/ci-smoke-test.yml`) davon
  abhaengt. Regressionstests gegen reale Projekte reichen nicht aus, um
  das zu fangen - jede reale Projekt-Config wird ja selbst nachgepflegt.
  Nach jedem Push, der ein CI-abgedecktes Skript aendert, `gh run list`
  pruefen statt sich auf lokale Tests allein zu verlassen.

- **K-Means-Cluster-Features als Feature Engineering getestet (2026-08-23,
  `health-condition-kmeans-feature-test`) - modellabhaengiger Befund, kein
  Backport.** Nutzeridee: Cluster-ID + Distanz-zu-Zentren als zusaetzliche
  Features, fold-sicher gefittet (wie Target-Encoding). An `health_
  condition` (10%-Subset, 5-fold CV) getestet: bei **Ranger** klarer,
  monotoner NEGATIVBEFUND (-0.0035 bis -0.0076 BAcc, k=3/5/8) - Ranger
  kann Cluster-Struktur ueber Splits selbst approximieren, die Zusatz-
  Features sind nur Rauschen. Bei **multinomialer logistischer Regression**
  (linear) UMGEKEHRTER Trend, positiv (+0.009 BAcc bei k=8) - bestaetigt
  die Erklaerung direkt (gezielter Nachtest auf Nutzeranregung statt nur
  Vermutung). **Kein Backport-Kandidat**, da das Template primaer auf
  GBM/Ranger setzt, aber relevant fuer Projekte mit linearen Modellen als
  Hauptkandidaten (z.B. hochdimensionale duennbesetzte Chemie-Daten, wo
  SVM/LogReg ohnehin Kandidaten sind). Volle Herleitung in
  `health-condition-kmeans-feature-test/README.md`.

- **PCA-Feature-Test an einem Chemie-Projekt (2026-08-23,
  `bbbp-classification`) - Nachtest zum K-Means-Befund, differenzierteres
  Bild.** Fold-sicher (`prcomp()` nur auf Train gefittet), PCA ERSETZT die
  750 rohen Fingerprint-Bits (statt additiv wie beim K-Means-Test).
  Ergebnis widerlegt die einfache "linear vs. Baum"-Faustregel aus dem
  K-Means-Befund: **echte lineare Modelle (LogReg, SVM linear)
  profitieren klar und monoton** (LogReg BAcc 0.680->0.767, AUC
  0.723->0.873 bei 100 Komponenten) - passt zur Erklaerung (PCA loest die
  Quasi-perfekte-Separation bei 750 duennbesetzten Bits vs. ~1640 Zeilen).
  **SVM mit RBF-Kernel wird dagegen DEUTLICH schlechter** (0.809->0.730
  bei 10 Komponenten, naehert sich mit mehr Komponenten wieder an, erreicht
  aber nie das Rohdaten-Niveau) - der Kernel-Trick nutzt die
  hochdimensionalen Rohdaten offenbar schon gut, PCA-Reduktion verliert
  nur Information ohne entsprechenden Stabilitaetsgewinn. **Ranger bleibt
  unbeeindruckt** (Differenzen <=0.014, kein Trend), konsistent mit dem
  K-Means-Befund. **Praktische Lehre**: bei SVM kommt es auf den KERNEL
  an, nicht nur "linear vs. nichtlinear" als grobe Kategorie. Kein
  Backport-Kandidat, aber ein reusable Muster fuer kuenftige
  hochdimensionale duennbesetzte Projekte (Chemie/Text/Genomik): PCA
  gezielt fuer schwache lineare Baseline-Modelle einsetzen, nicht fuer
  bereits starke Kandidaten (Baeume, RBF-SVM). Volle Herleitung in
  `bbbp-classification/README.md`.

- **Autoencoder (ANN2) als nichtlineare Alternative zu PCA getestet
  (2026-08-23, `bbbp-classification`) - LogReg-Gewinn robust bestaetigt,
  aber Ranger diesmal geschadet.** Dritter Nachtest der K-Means-Idee
  (nach K-Means/`health_condition` und PCA/`bbbp-classification`).
  Reduzierter Umfang (1 Autoencoder-Fit/Fold statt /Lerner, 3 statt 5
  Folds, nur 30 Komponenten) wegen Laufzeit (~3-6 Min./Fit, siehe README
  fuer die Kostenabschaetzung, mit Nutzer vorab abgestimmt). **LogReg-
  Gewinn fast identisch zu PCA** (+0.059 vs. +0.061 BAcc) - bestaetigt,
  dass Dimensionsreduktion an sich (nicht PCA-Spezifisches) das
  Quasi-Separations-Problem loest. **Anders als PCA schadet der
  Autoencoder aber auch RANGER spuerbar** (-0.035, PCA war dort neutral)
  - plausibel durch die ungetunte, verrauschte nichtlineare Kompression
  (Split-Grenzen verwischt, waehrend PCAs saubere orthogonale Komponenten
  das nicht tun). SVM linear/radial aehnlich neutral/negativ wie bei PCA.
  **Wichtiger Vorbehalt**: schneller, ungetunter Autoencoder (50 Epochen),
  kein Bestwert-Vergleich. **Einordnung**: PCA hat hier das bessere
  Aufwand-Nutzen-Verhaeltnis (exakte Loesung, Sekunden statt Minuten,
  kein Ranger-Schaden) - kein Hinweis, dass laengeres Autoencoder-Tuning
  sich lohnen wuerde, nicht weiterverfolgt. Volle Herleitung in
  `bbbp-classification/README.md`.
