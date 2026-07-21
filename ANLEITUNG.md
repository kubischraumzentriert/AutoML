# Anleitung: Kompletter Workflow ohne KI, nur mit der R-Konsole

Diese Datei ist ein **Kochbuch**, kein Nachschlagewerk. Ziel: ein Mensch kann
jeden Schritt der Modellauswahl (`010`-`155`) manuell in der R-Konsole
nachvollziehen - Befehl eingeben, Ausgabe lesen, Entscheidung treffen, naechster
Befehl - ohne dass eine KI die Ergebnisse interpretiert. `TARGETS.md`
dokumentiert das *Werkzeug* `targets` (wie der Cache/Abhaengigkeitsgraph
funktioniert); `README.md` dokumentiert die *inhaltlichen Ergebnisse* dieses
konkreten Projekts. Diese Datei dokumentiert den *Ablauf*: was in welcher
Reihenfolge zu tun ist, welche Ausgabe was bedeutet, und an welchen Stellen ein
Mensch eine echte Entscheidung treffen muss (die kein Skript automatisch trifft).

Jeder Abschnitt entspricht einer Phase der `TARGETS.md`-Checkliste
"Uebertragung auf einen neuen Kaggle-Wettbewerb", aber ausführlicher: mit
Beispielbefehlen, erwarteten Ausgabeformen und Entscheidungsregeln.

## Phase 0: Vorbereitung

1. Projektordner mit `train.csv`, `test.csv`, `sample_submission.csv` von
   Kaggle anlegen (z.B. `C:/Users/HP/OneDrive/Dokumente/R_Workspace/<projekt>/`).
2. Alle nummerierten Skripte, `000_config.R`, `005_benchmark_runtime.R`,
   `006_tuning_diagnostics.R`, `db_logging.R`, `db_schema.sql` aus diesem
   Template-Repo in den neuen Ordner kopieren. `features/utils.R`
   (nur `safe_divide()`) ebenfalls kopieren, `features/*.R` sonst leer lassen.
3. **Kaggle-Wettbewerbsseite lesen** (Overview + Data), BEVOR `000_config.R`
   ausgefuellt wird: Zielspalte, Bewertungsmetrik (steht im Abschnitt
   "Evaluation" der Overview-Seite, Wortlaut genau lesen - z.B. "area under
   the ROC curve" = AUC, nicht automatisch BAcc/Accuracy annehmen), erwartetes
   Submission-Format (Wahrscheinlichkeit oder Klassenlabel?).
4. `000_config.R` ausfuellen (siehe Phase 1).
5. Windows/R-spezifisch (siehe `project_r_windows_env`-Hinweise, gelten fuer
   jedes Projekt):
   - `Rscript` ist meist nicht im PATH - vollen Pfad verwenden, z.B.
     `C:\Users\HP\Programme\R\R-4.5.2\bin\Rscript.exe skriptname.R`.
   - **Nie mehrzeiligen R-Code direkt per `-e` an ein Terminal uebergeben** -
     das fuehrt zu Segfaults/falscher Shell-Interpolation. Immer zuerst in
     eine `.R`-Datei schreiben, dann `Rscript.exe datei.R` ausfuehren.
   - Wird ein Skript ausgefuehrt, das (noch) gar nicht existiert (z.B. beim
     Kopieren vergessen), kann `Rscript.exe` unter Windows/Git-Bash statt
     einer klaren "file not found"-Fehlermeldung einen **Segmentation
     fault** werfen. Bei einem Segfault direkt nach dem Kopieren der Skripte
     zuerst pruefen, ob die Datei tatsaechlich am erwarteten Pfad liegt
     (`ls`/`Get-ChildItem`), bevor man tiefer im Code sucht.
   - Rechenintensive Skripte im Hintergrund starten und Fortschritt per
     Log-Datei pruefen, nicht die Konsole blockieren.

## Phase 1: `000_config.R` ausfuellen

Pflichtfelder (siehe `TARGETS.md`-Checkliste Punkt 2):

| Variable | Bedeutung | Beispiel |
|---|---|---|
| `id_col` | Name der ID-Spalte | `"id"` |
| `target_col` | Name der Zielspalte | `"diagnosed_diabetes"` |
| `project_name` | Label fuer `experiments.db` | `"playground-series-s5e12-diabetes"` |
| `baseline_measure_ids` | Zielmetrik zuerst, Diagnose-Metrik danach | `c("classif.auc", "classif.bacc")` |

Alles andere (`task_id_prefix`, Pfade unter `artifact_dir`, `resolve_task_path()`,
`resolve_submission_model_name()`, `add_balanced_class_weights()`,
`feature_set_from_task_id()`, `algorithm_from_learner_id()`) laesst sich
unveraendert aus diesem Template kopieren - das sind generische Helfer, keine
projektspezifischen Werte.

**Zwei Entscheidungen, die die Checkliste leicht uebersieht:**

- **`error_analysis_uncertainty_threshold`**: bei genau 2 Zielklassen ist die
  Konfidenz der vorhergesagten Klasse mathematisch immer >= 0.5 (beide
  Klassenwahrscheinlichkeiten summieren zu 1). Ein Schwellenwert von 0.5 waere
  dort entartet (der "unsicher"-Eimer bleibt leer) - bei binaeren Aufgaben
  bewusst hoeher setzen, z.B. `0.7`. Bei >=3 Klassen ist `0.5` dagegen sinnvoll.
- **`class_weight_power`**: als Startwert `0` (ungewichtet) setzen, nicht
  raten. Der tatsaechlich sinnvolle Wert ist ein **Ergebnis** von Phase 9
  (Klassengewichtung pruefen), keine Config-Eingabe im Voraus.

`feature_families`/`selected_families` zunaechst `character(0)` lassen, falls
noch kein Feature Engineering feststeht (siehe Phase 6).

## Phase 2: EDA (`010_eda.R`)

```r
setwd("<projektordner>")
source("010_eda.R")
```

Worauf achten:

- **Zeilen-/Spaltenzahlen** (Train voll/10%-Subset/Test) - Plausibilitaetscheck.
- **Klassenverteilung der Zielvariable** (`count()`-Ausgabe): grobes
  Ungleichgewicht (z.B. 80/20) beeinflusst spaeter, ob Klassengewichtung
  wichtig wird (Phase 9).
- **`skimr`-Summary**: `n_missing`/`complete_rate` je Spalte (fehlende Werte?
  die Imputations-Pipeline in `030`/`070`/etc. faengt das zwar automatisch
  ab, aber ein sehr hoher Anteil fehlender Werte in einer wichtigen Spalte ist
  trotzdem eine Entscheidung wert), `n_unique` bei character-Spalten
  (hochkardinale Spalten vormerken, siehe Phase 4 Warnung).

Keine automatisierte Entscheidung hier - reine Bestandsaufnahme.

## Phase 3: Rohfeature-Task bauen (`020_task.R`)

```r
source("020_task.R")
```

Zieht ein `subset_fraction`-Sample (stratifiziert nach Zielklasse), wandelt
character-Spalten in Faktoren um, speichert den `mlr3`-`TaskClassif` unter
`task_train_small_path`. Ausgabe zeigt Feature-Typen (`int`/`fct`/`dbl`) und
bei binaeren Aufgaben, welche Klasse `mlr3` als "positive class" waehlt
(alphabetisch erste Faktorstufe, z.B. `"0"` vor `"1"`) - das betrifft NUR die
interne Zaehlrichtung von Sensitivitaet/Spezifitaet bei Diagnose-Ausgaben.
AUC und BAcc sind symmetrisch bezueglich der Wahl der positiven Klasse (siehe
Phase 12, dort ist die Wahl der richtigen Wahrscheinlichkeitsspalte fuer die
Kaggle-Submission dagegen entscheidend).

Der Task markiert die Zielspalte zudem als `stratum`. Damit erhalten alle
klassifikationsbasierten Holdout- und CV-Resamplings im Workflow die
Klassenanteile. Fuer Zeitreihen oder gruppierte Daten muss dieser Standard vor
der Ausfuehrung durch ein passendes Zeit- bzw. Group-Resampling ersetzt werden.

## Phase 4: Baselines (`030_baseline.R`)

```r
source("030_baseline.R")
```

Trainiert LDA, Multinom, Ranger (jeweils mit `imputemedian`/`imputemode`-
Vorverarbeitung) per Holdout, misst `baseline_measure_ids`.

**Zwei Fallstricke, auf die die Skripte selbst hinweisen (nicht raten,
Warnungen lesen):**

1. **`warn_high_cardinality_factors()`** (aus `005_benchmark_runtime.R`) warnt,
   wenn eine Faktor-Spalte > 50 Auspraegungen hat. LDA/Multinom kodieren
   Faktoren implizit als One-Hot - bei sehr vielen Auspraegungen kann das zu
   Spalten fuehren, die innerhalb einer Zielklasse konstant sind, was `lda`/
   `multinom` zum Abstuerzen bringt. Bei einer Warnung: Spalte fuer diese
   Modelle ausschliessen (z.B. in `020_task.R`) oder sinnvoll kodieren
   (Frequenz-/Zielkodierung, spaeter als Feature Engineering).
2. **`baseline_measure_ids` enthaelt eine schwellenwertunabhaengige Metrik
   wie `classif.auc`?** Dafuer braucht jeder Learner `predict_type = "prob"`,
   nicht nur eine Klassenvorhersage (`response`). `030_baseline.R`,
   `080_boosting_benchmark.R`, `090_ranger_tuning.R`, `100_lightgbm_tuning.R`
   und `105_lightgbm_class_weights.R` setzen das bereits standardmaessig (seit
   2026-07-14) - kostet fuer `classif.bacc`/`classif.mcc` nichts, macht die
   Skripte aber sofort AUC-/LogLoss-tauglich. Ebenso optimieren `090`/`100`
   bereits `baseline_measure_ids[1]` statt hart codiertem `classif.bacc` beim
   Tuning. **Trotzdem pruefen** bei eigenen/weiteren Skripten mit `lrn(...)`-
   Aufrufen (`110`, `120`, `125`, `140`, `142`, `145` usw.) - dieser Punkt trat
   vor der Behebung zweimal unabhaengig auf (`playground-series-s6e5`,
   `playground-series-s5e12`), das Muster kann sich bei neuen/eigenen
   Skripten wiederholen.

Ergebnis interpretieren: `baseline_results.csv`/Konsolen-Tabelle zeigt
`classif.auc`/`classif.bacc` je Learner. Liegen alle drei nah beieinander
(z.B. AUC ~0.69-0.70 fuer alle), ist das ein erstes Signal, dass simple
lineare Trennbarkeit an einer Grenze angekommen ist - noch keine
abschliessende Aussage, aber ein Hinweis, spaeter (Phase 11) nach
modelluebergreifend identischen Fehlern zu suchen.

## Phase 5: Adversarial Validation (`115_adversarial_validation.R`)

```r
source("115_adversarial_validation.R")
```

Trainiert einen LightGBM-Klassifikator, der Train- von Test-Zeilen unterscheiden
soll (Zielspalte entfernt, neue Binaerspalte `is_test`). Interpretation:

- **AUC nahe 0.5**: Train und Test aehnlich verteilt. CV-Ergebnisse aus den
  folgenden Phasen sollten sich auf das Leaderboard uebertragen - normal
  weitermachen.
- **AUC deutlich > 0.5** (z.B. > 0.6-0.7): Distribution Shift. Die
  Feature-Importance-Tabelle zeigt, welche Spalten den Unterschied treiben -
  diese Spalten mit Vorsicht behandeln (ggf. ausschliessen oder robuster
  kodieren), CV-basierte Entscheidungen in spaeteren Phasen kritischer pruefen.

**Bei hartem oder strukturellem Shift** (AUC ~0.9+, oder wenn die Feature-
Importance nicht auf einzelne Spalten reduzierbar ist) reicht die reine
Importance-Betrachtung nicht - dann dem Playbook `REFERENZ_DISTRIBUTION_SHIFT.md`
folgen: gestufte Shift-Zerlegung (roh -> missing-robuste Aggregate -> gleiche
Achse), ESS-Gate vor Importance-Weighting, Invarianz statt Korrektur, und - der
zentrale Punkt - die CV kann Shift-Robustheit NICHT bewerten, die Feature-Set-
Wahl gehoert dann auf ein shift-exponiertes Set (Leaderboard/Holdout).

Diese Phase bewusst VOR Feature Engineering/Tuning einordnen - ein Shift
wuerde sonst alle nachfolgenden CV-Vergleiche unbemerkt verzerren.

## Phase 5b: Probability-Kalibrierung vormerken

Wenn die Wettbewerbsmetrik LogLoss/Brier oder eine Multi-Metric-Kombination mit
LogLoss enthaelt, ist Kalibrierung ein spaeterer sauberer Hebel. Nicht vor den
Baselines anwenden, aber frueh vormerken:

- Alle relevanten Learner mit `predict_type = "prob"` trainieren.
- Neben AUC auch LogLoss/Brier und mittlere vorhergesagte Wahrscheinlichkeit
  tracken.
- Nach Modell-/Feature-Auswahl OOF-Vorhersagen erzeugen und eine monotone
  Kalibrierung testen.

Fuer Details siehe `REFERENZ_PROBABILITY_CALIBRATION.md`. Wichtigster Punkt:
Kalibrierung nie auf denselben Zeilen bewerten, auf denen sie gefittet wurde.
Platt-Kalibrierung ist:

```text
p_cal = sigmoid(a + b * logit(p_raw))
```

Dabei sind `logit` und `sigmoid` Umkehrfunktionen, nicht dasselbe.

Fairness-Regel fuer Wettbewerbe: Wenn ein lokal/OOF validierter Kalibrierungs-
oder Ensemble-Kandidat einmal auf dem Leaderboard bestaetigt wurde, nicht weiter
mit sehr aehnlichen Nachbarvarianten nachlegen. Weitere Submissions brauchen eine
neue methodische Idee; reine Mikrovarianten wie minimale Regularisierungswerte,
Clipping-Schwellen oder Temperaturwerte sind sonst schnell Leaderboard-Fitting.

## Phase 6: Feature Engineering (optional, `025`/`035`-`038`)

Nur durchfuehren, wenn Phase 4 (Baselines) noch klar unterhalb einer
plausiblen Obergrenze liegt (z.B. deutlich unter 1.0 AUC/BAcc, mit Rest-
Spielraum) UND konkrete inhaltliche Ideen fuer neue Merkmale vorhanden sind
(reines Ausprobieren ohne Hypothese bringt selten etwas).

0. **Vor dem Schreiben pruefen**: sind die geplanten Features reine
   Linearkombinationen/Verhaeltnisse aus bereits vorhandenen numerischen
   Rohspalten (z.B. `a - b`, `a / b`, gewichtete Summen)? Baum-/Boosting-
   Modelle koennen solche Beziehungen ueber Splits meist selbst approximieren
   (kein Informationsgewinn), fuer lineare Modelle (LDA/Multinom) drohen sogar
   Kollinearitaetsprobleme. Bei `playground-series-s5e12` verschlechterten
   genau solche Features (Cholesterin-/Blutdruck-Verhaeltnisse) die Zielmetrik
   konsistent ueber vier Modelle, mit expliziten `lda.default`-
   Kollinearitaetswarnungen. Aussichtsreicher sind Features, die echte NEUE
   Information codieren, die in den Rohspalten nicht linear enthalten ist
   (Cross-Row-Aggregationen, domaenenspezifische nichtlineare Kategorien).
1. Neue Datei(en) `features/<familie>.R` mit `add_<familie>_features(data)`
   schreiben (Signatur: Data-Frame rein, Data-Frame mit zusaetzlichen Spalten
   raus, `%>%`/`mutate()`-Stil wie die bestehenden Beispiele).
2. `feature_families` in `000_config.R` um die neuen Namen ergaenzen.
3. `025_feature_engineering.R` ausfuehren - baut je Familie einen eigenen
   Task plus einen kombinierten Task.
4. `035_feature_baseline.R`/`036_feature_family_benchmark.R` ausfuehren -
   vergleicht Roh-Task gegen jede Familie einzeln und kombiniert (Holdout).
5. **Entscheidungsregel**: nur Familien in `selected_families` uebernehmen,
   die den Holdout-Wert der Zielmetrik spuerbar verbessern (nicht nur im
   Rauschen). `037_selected_features_cv.R` bestaetigt die Auswahl per 5-facher
   CV, bevor sie in `model_feature_sets` (`000_config.R`) uebernommen wird.
   Verbessert **keine** Familie den Holdout-Wert (moeglich, siehe Schritt 0) -
   `037` ueberspringen (nichts zu bestaetigen), `selected_families` leer
   lassen und bei Rohfeatures bleiben. Ein negatives Ergebnis ist ein
   valides Ergebnis, keine gescheiterte Analyse.

`038_surrogate_guided_features.R` ist ein Sonderfall fuer automatisch
entdeckte Interaktionsfeatures (rpart-Ensemble als Scout) - nur relevant, wenn
manuelle Feature-Ideen ausgehen; siehe Kopfkommentar der Datei.

## Phase 7: Boosting-Vergleich (`080`/`081`, XGBoost braucht `040`)

```r
source("080_boosting_benchmark.R")   # Ranger + LightGBM per CV (kein One-Hot)
source("081_xgboost_benchmark.R")    # XGBoost per CV (braucht 040 One-Hot)
```

Der Vergleich ist bewusst auf zwei Skripte aufgeteilt: `080` deckt Ranger und
LightGBM ab, die Faktoren nativ verarbeiten und KEINE Preprocessing-Pipeline
brauchen. `081` deckt XGBoost ab, das als einziges eine One-Hot-Pipeline aus
`040_preprocessing.R` braucht (`classif.xgboost` akzeptiert nur logical/integer/
numeric, keine rohen Faktoren). So laesst sich der guenstige Ranger/LightGBM-
Vergleich (`080`) laufen, ohne die XGBoost-Preprocessing-Abhaengigkeit
mitzuziehen - `081` ist optional/nachgelagert. Vor dem Start die Laufzeit grob
abschaetzen (naechster Absatz).

**Laufzeit vorab schaetzen**: `estimate_cv_runtime()` (`db_logging.R`) liest
bereits geloggte Holdout-Laufzeiten aus `experiments.db` und multipliziert mit
der Fold-Zahl - hilfreiche Faustregel, um vor einem mehrminuetigen CV-Lauf zu
wissen, ob man warten oder im Hintergrund starten sollte.

## Phase 8: Tuning (`090`/`100`)

```r
source("100_lightgbm_tuning.R")   # oder 090_ranger_tuning.R
```

Nutzt `tnr("mbo")` (Bayesian Optimization via `mlr3mbo`). **Wichtige Falle**:
das Initialdesign skaliert mit ~4x der Anzahl Suchraum-Parameter. Ist das
Eval-Budget (`lightgbm_tuning_evals`/`ranger_tuning_evals`) kleiner als
Initialdesign + ~10-20, findet KEINE echte sequenzielle Verfeinerung statt -
alle Punkte laufen im selben `batch_nr`, das Ergebnis ist reines
(quasi-)Zufalls-Sampling, sieht aber oberflaechlich wie ein normaler
Tuning-Lauf aus.

`diagnose_mbo_search()` (`006_tuning_diagnostics.R`) wird nach jedem
`tnr("mbo")`-Lauf automatisch aufgerufen und meldet:

1. Ob mehr als ein `batch_nr` vorkommt (echte Verfeinerung ja/nein).
2. Ob das Budget die 4x-Dimensionen-Faustregel erfuellt.
3. Spannweite/R² der Zielmetrik ueber alle Archiv-Punkte (Plateau-Indikator).

**Entscheidungsregel**: Ergebnis eines Tuning-Laufs nur uebernehmen, wenn (1)
echte Verfeinerung stattfand UND (2) eine unabhaengige CV-Gegenprobe (nicht
nur der Tuning-Holdout-Split selbst) die Verbesserung bestaetigt. Ein
Tuning-Ergebnis, das nur auf dem Such-Holdout besser ist, aber in der
CV-Gegenprobe schlechter als der Default abschneidet, wurde ueberangepasst -
verwerfen, nicht uebernehmen.

## Phase 9: Klassengewichtung pruefen (`105`/`135`)

```r
source("105_lightgbm_class_weights.R")
```

Testet `class_weight_power` ueber ein Gitter (typ. 0 bis 1, `135` erweitert
bis 3). **Bevor die Ergebnisse interpretiert werden**: pruefen, ob die
Zielmetrik schwellenwertunabhaengig ist.

```r
is_threshold_independent_metric(baseline_measure_ids[1])
```

- **Schwellenwertunabhaengig** (AUC, LogLoss): Klassengewichtung veraendert
  zwar die Verlustfunktion beim Training und kann daher einen echten (meist
  kleinen) Effekt haben, ist aber nachrangig. Post-hoc Schwellenwert-Tuning
  (Phase 10) ist dagegen komplett irrelevant - AUC integriert ueber alle
  Schwellenwerte, eine reine Cutoff-Verschiebung aendert an bereits
  berechneten Wahrscheinlichkeiten nichts an der Rangfolge.
- **Schwellenwertabhaengig** (BAcc, MCC, Accuracy, F1): beide Hebel
  (Klassengewichtung UND Schwellenwert-Tuning) koennen stark wirken - hohe
  Prioritaet.

`warn_if_threshold_step_low_value()` gibt genau diese Einschaetzung
automatisch aus, sobald `class_weight_power`-Ergebnisse geloggt sind - nicht
nur raten, Ausgabe lesen.

**Entscheidung**: den `power`-Wert mit dem besten Kompromiss aus Zielmetrik
und Diagnose-Metrik (z.B. BAcc vs. MCC) in `class_weight_power` sowie
`model_class_weight_power` (fuer die konkret gewinnenden Modelle) uebernehmen.

## Phase 10: Schwellenwert-Tuning (`130`/`146`, oft ueberspringbar)

Nur relevant, wenn Phase 9 eine schwellenwertabhaengige Zielmetrik ergeben
hat UND am Ende eine harte Klassenentscheidung (nicht nur eine
Wahrscheinlichkeit) gebraucht wird. Fuer AUC-/LogLoss-bewertete Wettbewerbe
i.d.R. ueberspringen (siehe Phase 9).

## Phase 11: Fehleranalyse (`147`)

Fuenf lose gekoppelte Skripte statt eines Monolithen - jedes laedt das
Ergebnis des vorherigen als `.rds`-Artefakt, statt selbst neu zu trainieren.
Das hat sich als wichtig erwiesen: eine kleine Aenderung am DB-Logging
(letzter Schritt) erforderte vorher, KernelSHAP und TabPFN (die teuersten
Teile, teils >1h) jedes Mal neu laufen zu lassen, nur um sie zu testen.

```r
source("147_error_analysis_ranger_models.R")           # trainiert einmal, loggt vollstaendig
source("147_error_analysis_ranger_confidence.R")        # Rescue-Rate, "einig falsch"-Faelle
source("147_error_analysis_ranger_isolation_forest.R")  # Ausreissercheck
source("147_error_analysis_ranger_kernelshap.R")        # welche Features treiben Fehler?
source("147_error_analysis_ranger_tabpfn.R")            # komplett andere Methodik
```

`_models.R` speichert Modelle+Vorhersagen unter `error_analysis_models_path`,
`_confidence.R` baut darauf auf und speichert abgeleitete Zeilen-Indizes
(misclassified/hard_case/...) unter `error_analysis_indices_path` - die
letzten drei Skripte laden beide Artefakte und lassen sich dadurch **einzeln
und in beliebiger Reihenfolge** neu ausfuehren, ohne die anderen anzufassen.

Das Muster (`_ranger`) ist auf das hier gewinnende Modell (Ranger)
zugeschnitten. Gewinnt in einem neuen Projekt ein anderes Modell (z.B.
LightGBM, siehe Phase 4/7), die Skripte entsprechend umbenennen/anpassen
(Primaermodell austauschen, Vergleichsmodelle bleiben strukturell andere
Modellfamilien) - Vorlage dafuer ist die schlankere Variante mit nur drei
Skripten (`_models`/`_confidence`/`_isolation_forest`, ohne KernelSHAP/
TabPFN), sinnvoll, solange noch kein Feature Engineering betrieben wird.

**KernelSHAP kann ueberraschend lange dauern** (mehr als eine Stunde, je nach
Klassenzahl/Stichprobengroesse `error_analysis_shap_sample_size`/
`_background_size` in `000_config.R`) - vor einem produktiven Lauf mit einer
kleinen Stichprobe (z.B. 15/15) testen, dass das Skript selbst korrekt
durchlaeuft, dann erst mit der vollen Groesse (im Hintergrund) starten.

Analysiert falsch klassifizierte/unsichere Zeilen des besten Modells:
Konfidenz-Verteilung, Vergleich mit anderen Modellfamilien (stimmen sie bei
denselben Zeilen ueberein?), Isolation-Forest-Ausreissercheck, KernelSHAP.

**Zwei Fallen, die die Skripte selbst pruefbar machen:**

1. **Rescue-Rate-Falle**: "Modell B rettet X% von As Fehlern" klingt nach
   einem guten Korrektur-Argument, ist aber oft Mehrheitsklassen-Bias (ein
   ungewichtetes Modell "rettet" viel, weil es meist auf die Mehrheitsklasse
   tippt, die zufaellig oft stimmt).
2. **Bedingte-Wahrscheinlichkeit-Falle**: relevant ist NICHT P(B richtig | A
   falsch), sondern P(B richtig | A und B uneinig) - eine andere Groesse.
   `check_disagreement_accuracy()` (`005_benchmark_runtime.R`) berechnet genau
   diese und gibt eine explizite Empfehlung aus ("Korrekturregel lohnt sich" /
   "wuerde vermutlich schaden") - vor jeder Ensemble-/Korrekturentscheidung
   aufrufen, nicht die Rescue-Rate allein interpretieren. **Bei genau 2
   Zielklassen** ist der ausgegebene "Keiner hat recht"-Anteil strukturell
   immer 0% (Uneinigkeit bedeutet dort zwangslaeufig: einer sagt Klasse 0,
   der andere Klasse 1, und einer davon ist die Wahrheit) - kein Fehler,
   nur bei >=3 Klassen aussagekraeftig.

Findet die Analyse einen Kern modelluebergreifend identischer Fehler (mehrere
strukturell verschiedene Modelle einig, hohe Konfidenz, falsch): das ist ein
Hinweis auf eine strukturelle Grenze (Feature-/Datenqualitaets-Decke,
haeufig bei synthetischen Playground-Datensaetzen), kein Modellwahl- oder
Tuning-Problem - weiteres Tuning bringt dann typischerweise wenig
(Vorher-Nachher-Vergleich der Fehleranalyse rund um Phase 8 kann das direkt
bestaetigen).

## Phase 12: Submission-Modell waehlen, finales Training, Predict

```r
source("148_select_submission_model.R")   # datengetriebener Vorschlag
```

Fragt `experiments.db` nach dem besten Wert von `baseline_measure_ids[1]` je
Algorithmus, schreibt eine Rangliste nach `submission_model_selection.csv`.
**Nur eine einzelne Metrik auf Rohfeatures** - Abwaegungen wie
Metrik-Trade-offs, Feature-Set-Wahl oder Klassengewichtung muss ein Mensch
selbst pruefen, bevor er sich auf den Vorschlag verlaesst. Danach
`submission_model_override` in `000_config.R` entweder auf `NULL` (Vorschlag
automatisch uebernehmen) oder explizit auf eine bewusst abweichende
Entscheidung setzen.

```r
source("150_train_full_model.R")   # trainiert auf dem VOLLEN train.csv
source("155_predict_submission.R") # schreibt submission.csv
```

**Bei einer Wahrscheinlichkeits-Submission (AUC/LogLoss-Wettbewerb)**: in
`155_predict_submission.R` explizit die Wahrscheinlichkeitsspalte fuer die
tatsaechliche Zielklasse (`predictions$prob[, "<positive-wert-als-string>"]`)
auswaehlen, NICHT sich auf `mlr3`s automatisch gewaehlte "positive class"
verlassen (die ist bei binaeren Aufgaben oft die alphabetisch erste
Faktorstufe, nicht zwingend die Klasse, die Kaggle als "1"/Ereignis erwartet).
Kaggle schreibt das erwartete Spaltenformat in `sample_submission.csv` vor -
gegenpruefen, bevor die Datei hochgeladen wird.

**Jede von `150` gespeicherte Modell-Datei ist an eine `run_id` gebunden**
(`final_model_full_path(model_name, run_id)`, kein fixer Dateiname mehr) - ein
erneuter Lauf ueberschreibt die vorherige Datei nicht mehr kommentarlos. Der
Pfad wird als `model_artifact_path`-Hyperparameter in `experiments.db`
geloggt; `155` findet ihn ueber `db_get_latest_model_artifact_path()`
(`db_logging.R`) automatisch wieder - keine manuelle Pfadverwaltung noetig.

## Entscheidungsregeln im Ueberblick

| Frage | Antwort |
|---|---|
| Zielmetrik schwellenwertunabhaengig (AUC/LogLoss)? | Klassengewichtung mit niedriger Prioritaet pruefen, Schwellenwert-Tuning (`130`/`146`) ueberspringen. |
| Zielmetrik schwellenwertabhaengig (BAcc/MCC/Accuracy/F1)? | Beide Hebel mit hoher Prioritaet pruefen. |
| Genau 2 Zielklassen? | `error_analysis_uncertainty_threshold` deutlich > 0.5 setzen (z.B. 0.7). |
| Faktor-Spalte mit > 50 Auspraegungen? | Fuer LDA/Multinom ausschliessen oder kodieren, sonst Absturz. |
| `tnr("mbo")`-Ergebnis uebernehmen? | Nur wenn `diagnose_mbo_search()` echte Verfeinerung bestaetigt UND eine unabhaengige CV-Gegenprobe die Verbesserung stuetzt. |
| Adversarial-Validation-AUC deutlich > 0.5? | Feature-Importance-Treiber mit Vorsicht behandeln, CV-Entscheidungen kritischer pruefen. |
| Rescue-Rate hoch, Korrekturregel erwaegen? | Erst `check_disagreement_accuracy()` pruefen, nicht die Rescue-Rate allein. |
| Modelluebergreifend identische, selbstsichere Fehler? | Wahrscheinlich strukturelle Grenze - weiteres Tuning bringt typischerweise wenig, Vorher-Nachher-Fehleranalyse zur Bestaetigung. |

## Siehe auch

- `TARGETS.md` - das `targets`-Werkzeug selbst (Caching, Abhaengigkeitsgraph,
  Uebertragungs-Checkliste in Kurzform).
- `README.md` - inhaltliche Ergebnisse und Begruendungen dieses konkreten
  Projekts (`health_condition`).
- `EXPERIMENTS_DB.md` - Schema und Query-Sammlung fuer `experiments.db`.
