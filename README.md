# MLR3 Classification AutoML Prototype

Dieses Unterprojekt entwickelt eine wiederverwendbare AutoML-Struktur fuer Kaggle-Klassifikationsaufgaben mit `mlr3`.

Der aktuelle Datensatz stammt aus `playground-series-s6e7` und beschreibt Gesundheits- und Lifestyle-Merkmale. Zielvariable ist `health_condition` mit drei Klassen: `at-risk`, `unhealthy`, `fit`.

## Zielbild

Die Projektstruktur trennt bewusst mehrere Ebenen:

- `mlr3pipelines` beschreibt die Modell-Pipeline: Imputation, Faktorbehandlung, Encoding, Skalierung und Learner.
- Die nummerierten Skripte beschreiben den Workflow: Datenueberblick, Task-Erzeugung, Baselines, Feature Engineering, Kandidatenmodelle.
- `targets` (`_targets.R`) orchestriert den *finalen* Workflow (Task-Erzeugung bis Submission, siehe eigener Abschnitt), ersetzt aber nicht die `mlr3`-Pipelines und nicht die explorativen Einzel-Skripte zur Modellauswahl.
- Datenquellenspezifisches Feature Engineering bleibt austauschbar und liegt separat.

## Skriptstruktur

| Skript | Rolle |
|---|---|
| `000_config.R` | Zentrale Pfade, Zielspalte, Seed, Subset-Quote, Metriken, Modellbudgets |
| `005_benchmark_runtime.R` | Hilfsfunktion fuer Modellbenchmarking mit Laufzeitmessung |
| `010_eda.R` | Datenueberblick auf 10%-Subset mit `skimr` |
| `020_task.R` | Erzeugt den Rohfeature-`TaskClassif` |
| `025_feature_engineering.R` | Erzeugt je Feature-Familie (`features/*.R`) einen eigenen Task, den kombinierten Feature-Task (alle Familien) und den ausgewaehlten Feature-Task (Aktivitaet+Cardio+Schlaf) |
| `030_baseline.R` | Autarke Baseline mit LDA, Multinom und Ranger |
| `035_feature_baseline.R` | Dieselben Baseline-Modelle auf engineered Features |
| `036_feature_family_benchmark.R` | Vergleicht Roh-Task, jede Feature-Familie einzeln und den kombinierten Feature-Task (Holdout) |
| `037_selected_features_cv.R` | Bestaetigt die Familien-Auswahl per 5-facher Cross-Validation: LDA auf Rohfeatures, Multinom/Ranger auf Roh- vs. ausgewaehltem Feature-Set |
| `040_preprocessing.R` | Wiederverwendbare `mlr3pipelines`-Bausteine |
| `050_pipeline_benchmark.R` | Benchmark der allgemeinen Preprocessing-Pipeline |
| `060_regularized_linear.R` | Regularisierte lineare Modelle mit `cv.glmnet` |
| `070_final_models.R` | Trainiert je Learner aus `model_feature_sets` das passende Feature-Set (inkl. Klassengewichtung aus `model_class_weight_power`) und speichert das finale Modell |
| `080_boosting_benchmark.R` | Vergleicht XGBoost und LightGBM gegen die Ranger-Referenz (Rohfeatures, CV) |
| `090_ranger_tuning.R` | Random-Search-Tuning fuer Ranger (mtry.ratio, min.node.size, sample.fraction), Finalvergleich per CV |
| `095_tabpfn_benchmark.R` | Explorativer TabPFN-Vergleich auf einem CPU-vertraeglichen Mini-Subset (eigenes `tabpfn_subset_size`) |
| `100_lightgbm_tuning.R` | Bayesian-Optimization-Tuning fuer LightGBM (`mlr3mbo`), Finalvergleich per CV |
| `105_lightgbm_class_weights.R` | Vergleicht balancierte Klassengewichte (`power`-Stufen 0 bis 1) fuer LightGBM per CV, inkl. Konfusionsmatrizen |
| `110_lightgbm_feature_family_benchmark.R` | Wiederholt den Feature-Family-Vergleich (wie `036`) fuer LightGBM mit `power=1`-Gewichtung |
| `115_adversarial_validation.R` | Prueft per Adversarial Validation, ob Train und Test unterscheidbar sind (AUC + Feature Importance) |
| `120_lightgbm_empty_string_preprocessing.R` | Vergleicht `""` behalten vs. `"" -> NA -> Imputation` fuer LightGBM (`power=1`), per CV |
| `125_catboost_benchmark.R` | Vergleicht CatBoost gegen LightGBM (beide `power=1`, Rohfeatures, CV) |
| `130_threshold_tuning.R` | Sucht post-hoc Klassengewichte auf den Wahrscheinlichkeiten (`argmax(prob * weight)`) auf einem Tune-Split, vergleicht mit `class_weight_power` |
| `135_lightgbm_class_weight_power_extended.R` | Setzt die `power`-Kurve aus `105` ueber 1 hinaus fort, findet das innere BAcc-Maximum |
| `140_ensemble_candidates_weighted.R` | Vergleicht LightGBM, Ranger und XGBoost mit derselben `power=1.5`-Gewichtung (CV) |
| `142_ranger_tuning_weighted.R` | Wiederholt `090` auf dem `power=1.5`-gewichteten Task (Random Search), Finalvergleich per CV |
| `145_ensemble_ranger_lightgbm.R` | Gleichgewichtetes Wahrscheinlichkeits-Ensemble (`gunion()` + `po("classifavg")`) aus Ranger und LightGBM |
| `150_train_full_model.R` | Trainiert `submission_model_name` (aktuell Ranger, Rohfeatures, `power=1.5`) auf dem vollen Trainingsdatensatz (`train.csv`, alle Zeilen) |
| `155_predict_submission.R` | Wendet das volle Modell auf `test.csv` an und schreibt `submission.csv` im Format von `sample_submission.csv` |

## `targets`-Pipeline (`_targets.R`)

> **Ausfuehrliche Anleitung**: siehe [`TARGETS.md`](TARGETS.md) - Grundkonzepte, Befehlsuebersicht, ein durchgerechnetes Beispiel und eine Checkliste fuer die Uebertragung auf einen neuen Wettbewerb.

Die nummerierten Skripte `020`/`025`/`070`/`150`/`155` bilden zusammen den *finalen* Workflow: Rohtask erzeugen, Feature-Familien bauen, Modelle auf dem 10%-Subset trainieren, das finale Modell auf dem vollen Datensatz trainieren, Submission schreiben. Bisher musste man dafuer die richtige Reihenfolge kennen und jedes Skript manuell erneut anstossen, wenn sich z.B. `class_weight_power` in `000_config.R` aenderte (jedes Skript prueft nur "existiert die Datei schon", nicht "ist sie noch aktuell").

`_targets.R` bildet genau diesen Workflow als expliziten, cachenden Abhaengigkeitsgraphen ab (`targets`-Paket):

- `train_raw`/`train_full` laden `train.csv` (getrennt fuer Subset- bzw. volles Training).
- `task_family` ist ein **dynamisch verzweigtes** Ziel (`pattern = map(feature_family_name)`) - baut automatisch einen Task pro Eintrag in `feature_families`, ohne den Code pro Familie zu wiederholen.
- `task_raw`/`task_combined`/`task_selected` entsprechen den Roh-/Kombinierten/Ausgewaehlten Tasks aus `025`.
- `final_model_subset` verzweigt ebenso ueber `model_name` (alle Eintraege aus `model_feature_sets`) und entspricht `070`.
- `task_full`/`task_full_weighted`/`final_model_full` entsprechen `150`, `submission` entspricht `155`.

**Nutzung**:
```r
targets::tar_make()          # Pipeline ausfuehren (baut nur veraltete/fehlende Ziele neu)
targets::tar_visnetwork()    # Abhaengigkeitsgraphen interaktiv anzeigen
targets::tar_manifest()      # Zielliste ohne Ausfuehrung pruefen
targets::tar_read(final_model_full)  # Ein bestimmtes Ziel aus dem Cache laden
```

Aendert sich z.B. `class_weight_power` in `000_config.R`, erkennt `tar_make()` beim naechsten Aufruf automatisch, dass `task_full_weighted` und alles Nachgelagerte (`final_model_full`, `submission`) veraltet sind, und baut nur diese neu - `task_family`/`task_combined` (die nicht von `class_weight_power` abhaengen) bleiben unveraendert im Cache.

**Bewusst nicht in `targets` uebernommen**: die explorativen Einzel-Skripte `030`-`145`. Die dienten der Modellauswahl (welches Modell, welche Gewichtung, welche Feature-Familie) und sind eher Analysewerkzeuge fuer eine einmalige Entscheidungsfindung als Teil einer wiederholbaren Produktions-Pipeline - sie bleiben als eigenstaendige Skripte und als Vorlage fuer die *Methodik* (wie man Klassengewichte testet, wie man Adversarial Validation aufsetzt, etc.), wenn ein neuer Klassifikationsaufgaben-Workflow dieselben Fragen erneut beantworten muss.

**Fuer einen neuen Klassifikationsaufgaben-Workflow** (siehe auch "Modularitaet" oben) reduziert `targets` den Umstellungsaufwand: man aendert `000_config.R` (Metrik, Spalten, `model_feature_sets`/`model_class_weight_power`) und `features/*.R`, ruft `tar_make()` auf - der Abhaengigkeitsgraph selbst (welches Ziel von welchem abhaengt) bleibt strukturell gleich, muss also nicht neu durchdacht werden.

## Bewertungsmetriken

Wir verwenden aktuell:

- Balanced Accuracy (`classif.bacc`)
- Matthews Correlation Coefficient (`classif.mcc`)

Accuracy wurde bewusst nicht als Hauptmetrik gewaehlt, weil die Zielvariable unausgewogen ist. Im 10%-Subset liegt `at-risk` bei ca. 86%.

## Baseline-Ergebnisse

Die Roh-Baseline laesst leere Strings in kategorialen Features als eigene Faktorstufe bestehen.

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| LDA | 0.8425 | 0.7801 | 3.88 s |
| Multinom | 0.8484 | 0.8094 | 12.14 s |
| Ranger | 0.8657 | 0.8632 | 34.35 s |

Ranger ist aktuell der beste Baseline-Referenzpunkt im Verhaeltnis aus Metrik und Laufzeit.

## Preprocessing-Erkenntnis: Leere Strings

In einigen kategorialen Spalten treten leere Strings `""` auf. Zwei Strategien wurden beobachtet:

| Strategie | Bedeutung | Beobachtung |
|---|---|---|
| `""` als eigene Kategorie behalten | Modell darf Missing-artige Werte als Signal lernen | In der Roh-Baseline staerker |
| `"" -> NA -> Imputation` | Klassische Missing-Value-Behandlung in `mlr3pipelines` | Etwas schwaechere Scores |

Interpretation: Die leeren Strings koennen selbst Signal tragen. Fuer AutoML sollten beide Strategien als Preprocessing-Kandidaten behandelbar bleiben.

## Pipeline-Benchmark

Die allgemeine Pipeline aus `040_preprocessing.R` macht:

```text
empty_factor_to_na -> imputemedian -> imputemode -> fixfactors
```

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| LDA | 0.8394 | 0.7737 | ca. 4-5 s |
| Multinom | 0.8218 | 0.7897 | ca. 13 s |
| Ranger | 0.8558 | 0.8599 | ca. 49 s |

Diese Pipeline ist konzeptionell sauberer, aber nicht automatisch besser. Besonders die Behandlung von `""` als `NA` kostet hier vermutlich Signal.

## Feature Engineering

Die Feature-Funktionen liegen nach Familie getrennt in `features/*.R` (je eine Funktion `add_<familie>_features()`), damit jede Familie unabhaengig einen eigenen Task erzeugen und benchmarken kann:

- BMI (`features/bmi.R`): `bmi_category`
- Schlaf (`features/sleep.R`): `sleep_deficit_7h`, `sleep_excess_9h`, `sleep_distance_from_8h`
- Aktivitaet (`features/activity.R`): `steps_per_exercise_min`, `calories_per_step`, `calories_per_exercise_min`, `steps_per_sleep_hour`, `exercise_per_sleep_hour`
- Hydration (`features/hydration.R`): `water_per_1000_calories`, `water_per_exercise_min`
- Cardio (`features/cardio.R`): `heart_rate_per_bmi`, `cardio_strain_proxy`, `calories_per_bmi`
- Interaktionen (`features/interactions.R`): `stress_sleep_quality`, `activity_smoking_alcohol`, `diet_activity`

`025_feature_engineering.R` speichert sowohl je einen Task pro Familie (`task_train_small_features_<familie>.rds`) als auch den kombinierten Task mit allen Familien (`task_train_small_features.rds`, weiterhin von `035`/`050`/`060` verwendet). Feature Engineering erhoeht den kombinierten Task von 13 auf 30 Features.

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| LDA + Features | 0.8045 | 0.7131 | ca. 11 s |
| Multinom + Features | 0.8424 | 0.7939 | ca. 42 s |
| Ranger + Features | 0.8729 | 0.8638 | ca. 78 s |

Erkenntnis: LDA verschlechtert sich deutlich und meldet Kollinearitaet. Ranger profitiert leicht. Die engineered Features sind daher kein Standardpfad, sondern eine experimentelle Feature-Familie.

## Feature-Family-Benchmark

`036_feature_family_benchmark.R` vergleicht den Roh-Task, jede Feature-Familie einzeln und den kombinierten Feature-Task mit denselben drei Baseline-Modellen:

| Task | LDA BAcc | LDA MCC | Multinom BAcc | Multinom MCC | Ranger BAcc | Ranger MCC |
|---|---:|---:|---:|---:|---:|---:|
| Roh | 0.8425 | 0.7801 | 0.8484 | 0.8094 | 0.8657 | 0.8632 |
| + BMI | 0.8394 | 0.7918 | 0.8473 | 0.8138 | 0.8643 | 0.8647 |
| + Schlaf | 0.8398 | 0.7636 | 0.8660 | 0.8177 | 0.8685 | 0.8609 |
| + Aktivitaet | 0.8475 | 0.7782 | 0.8592 | 0.8181 | 0.8714 | 0.8673 |
| + Hydration | 0.8357 | 0.7760 | 0.8423 | 0.8017 | 0.8547 | 0.8528 |
| + Cardio | 0.8380 | 0.7854 | 0.8468 | 0.8113 | 0.8711 | 0.8698 |
| + Interaktionen | 0.7885 | 0.6493 | 0.8431 | 0.8020 | 0.8722 | 0.8654 |
| Kombiniert (alle Familien) | 0.7951 | 0.7076 | 0.8270 | 0.7944 | 0.8670 | 0.8608 |

Erkenntnis: Fuer Ranger bringt fast jede Familie einzeln einen kleinen Vorteil gegenueber der Roh-Baseline (v.a. Aktivitaet und Cardio), die Kombination aller Familien ist aber nicht besser als die staerksten Einzel-Familien. Bei LDA schadet vor allem die Interaktionen-Familie deutlich (Kollinearitaet durch die `str_c`-Kategorien), waehrend Multinom von Schlaf und Aktivitaet einzeln staerker profitiert als vom kombinierten Feature-Set. Das bestaetigt, dass "alle Features kombinieren" kein Freifahrtschein ist — einzelne Familien lohnt es sich, separat gegen Kandidatenmodelle zu testen.

**Vorsicht bei der Interpretation:** Die obige Tabelle basiert auf einem einzelnen Holdout-Split (`validation_ratio = 0.80`). Unterschiede von unter ca. 1 Prozentpunkt zwischen aehnlich guten Familien sind Rauschen dieses einen Splits, kein belastbarer Beweis. Siehe naechster Abschnitt.

## Cross-Validation: Ausgewaehltes Feature-Set

Um die Holdout-Ergebnisse gegenzupruefen, vergleicht `037_selected_features_cv.R` mit 5-facher Cross-Validation (`cv_folds` in `000_config.R`):

- LDA auf Rohfeatures (LDA reagiert empfindlich auf Kollinearitaet, bleibt daher bewusst ohne engineered Features).
- Multinom und Ranger auf Rohfeatures **und** auf einem ausgewaehlten Feature-Set aus den drei staerksten Familien (Aktivitaet + Cardio + Schlaf).

| Task | Modell | BAcc | MCC | Laufzeit |
|---|---|---:|---:|---:|
| Rohfeatures | LDA | 0.8389 | 0.7798 | 10.4 s |
| Rohfeatures | Multinom | 0.8462 | 0.8084 | 49.6 s |
| Rohfeatures | Ranger | 0.8610 | 0.8601 | 161.8 s |
| Aktivitaet+Cardio+Schlaf | Multinom | 0.8653 | 0.8253 | 81.2 s |
| Aktivitaet+Cardio+Schlaf | Ranger | 0.8569 | 0.8596 | 279.3 s |

Erkenntnis: Unter CV bestaetigt sich der Multinom-Vorteil aus dem Holdout-Vergleich (BAcc +1.9, MCC +1.7 Prozentpunkte gegenueber Rohfeatures) — Schlaf und Aktivitaet liefern hier ein echtes, robustes Signal. Fuer Ranger dreht sich das Bild dagegen um: Die Kombination liegt unter CV leicht **unter** der Roh-Baseline (BAcc -0.4 Punkte, MCC praktisch gleich). Der im Holdout beobachtete Ranger-Vorteil einzelner Familien war also groesstenteils Rauschen eines einzelnen guenstigen Splits, kein robuster Effekt. Empfehlung: LDA und Ranger auf Rohfeatures belassen, nur Multinom auf dem Aktivitaet+Cardio+Schlaf-Set trainieren.

## Regularisierte lineare Modelle

`glmnet` wird als ernsthafter Modellkandidat betrachtet, nicht als reine Baseline. Es verwendet:

- Ridge: `alpha = 0`
- Elastic Net: `alpha = 0.5`
- Lasso: `alpha = 1`
- `cv.glmnet` mit `nfolds = 3`, `nlambda = 30`
- `s = "lambda.1se"` als konservative Lambda-Wahl

| Task | Modell | BAcc | MCC | Laufzeit |
|---|---|---:|---:|---:|
| Rohfeatures | Ridge | 0.7417 | 0.7420 | ca. 33 s |
| Rohfeatures | Elastic Net | 0.8109 | 0.7924 | ca. 27 s |
| Rohfeatures | Lasso | 0.8205 | 0.7985 | ca. 18 s |
| Engineered Features | Ridge | 0.8102 | 0.7935 | ca. 41 s |
| Engineered Features | Elastic Net | 0.8592 | 0.8209 | ca. 132 s |
| Engineered Features | Lasso | 0.8586 | 0.8238 | ca. 286 s |

Erkenntnis: Feature Engineering hilft `glmnet` deutlich, besonders Elastic Net und Lasso. Trotzdem bleibt Ranger aktuell staerker und schneller genug.

## Boosting-Benchmark

`080_boosting_benchmark.R` vergleicht XGBoost und LightGBM gegen die Ranger-Referenz, alle drei auf Rohfeatures per 5-facher CV. LightGBM verarbeitet Faktoren nativ (wie Ranger), XGBoost braucht eine one-hot-encodierte Pipeline (wie bei `glmnet`). Beide mit `num.trees`/`nrounds`/`num_iterations = 200`, sonst Standardparameter:

| Modell | BAcc | MCC | Laufzeit (5-fache CV) |
|---|---:|---:|---:|
| Ranger | 0.8614 | 0.8611 | 162.7 s |
| LightGBM | **0.8779** | 0.8607 | **63.6 s** |
| XGBoost | 0.8586 | 0.8523 | 370.2 s |

Erkenntnis: LightGBM schlaegt Ranger bereits mit Standardparametern deutlich bei BAcc (+1.6 Punkte), bei praktisch gleichem MCC, und ist dabei 2.5x schneller. XGBoost liegt dagegen leicht unter Ranger und ist am langsamsten. LightGBM ist damit der neue staerkste Kandidat.

## Ranger-Tuning

`090_ranger_tuning.R` tunt `mtry.ratio`, `min.node.size` und `sample.fraction` per Random Search (20 Evaluationen, Holdout, `num.trees = 100` fuer die Suche), danach Finalvergleich von Default- vs. getuntem Ranger mit `num.trees = 200` per 5-facher CV:

| Modell | mtry.ratio | min.node.size | sample.fraction | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|---:|---:|---:|
| Ranger default | 0.333 | 1 | 1.0 | 0.8620 | 0.8607 | 188.0 s |
| Ranger getunt | 0.928 | 20 | 0.708 | 0.8760 | 0.8572 | 371.6 s |

Erkenntnis: Tuning hebt BAcc um 1.4 Punkte, kostet aber leicht MCC (-0.4 Punkte, da die Suche nur nach BAcc optimiert hat) und verdoppelt die Laufzeit (plus ca. 9 Minuten Suchphase). Wichtiger: **Der getunte Ranger bleibt hinter LightGBM mit Standardparametern zurueck** (BAcc 0.876 vs. 0.878, MCC 0.857 vs. 0.861, Laufzeit 372s vs. 64s). Tuning-Aufwand lohnt sich hier eher bei LightGBM als bei Ranger.

## LightGBM-Tuning

`100_lightgbm_tuning.R` tunt `learning_rate`, `num_leaves`, `min_data_in_leaf`, `feature_fraction` und `bagging_fraction` per **Bayesian Optimization** (`mlr3mbo`, Standard-Surrogat: Gaussian Process via `DiceKriging`, Akquisitionsoptimierung via `rgenoud`) statt Random Search wie bei Ranger — LightGBM hat mehr interagierende Hyperparameter, und bei guenstigen Einzel-Evaluationen lohnt sich ein Surrogatmodell. 25 Evaluationen, Holdout, `num_iterations = 100` fuer die Suche, danach Finalvergleich von Default- vs. getuntem LightGBM mit `num_iterations = 200` per 5-facher CV:

| Modell | learning_rate | num_leaves | min_data_in_leaf | feature_fraction | bagging_fraction | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| LightGBM default | 0.1 (Standard) | 31 (Standard) | 20 (Standard) | 1.0 (Standard) | 1.0 (Standard) | 0.8755 | 0.8584 | 62.1 s |
| LightGBM getunt | 0.081 | 70 | 92 | 0.930 | 0.600 | 0.8754 | 0.8574 | 106.1 s |

Erkenntnis: **Tuning bringt hier keinen Vorteil** — Default und getunte Konfiguration liegen innerhalb der CV-Rauschgrenze, die getunte Variante ist sogar minimal schlechter und deutlich langsamer. LightGBMs Standardparameter sind fuer diesen Datensatz bereits nah am Optimum. Empfehlung: LightGBM mit Standardparametern verwenden, den Tuning-Aufwand sparen.

## TabPFN (explorativ)

`095_tabpfn_benchmark.R` prueft, wie sich TabPFN (`mlr3extralearners::lrn("classif.tabpfn")`) schlaegt. TabPFN ist ein vortrainiertes Foundation-Modell, das nur als Python-Paket existiert (`reticulate`-Anbindung, benoetigt einmaligen Lizenz-Login bei Prior Labs) und auf CPU standardmaessig auf **1000 Trainingszeilen** begrenzt ist. Deshalb ein eigenes Mini-Subset (`tabpfn_subset_size = 1200`, sonst waere die Grenze beim Standard-`validation_ratio = 0.80` ueberschritten), Ranger/LightGBM als Referenz auf demselben Mini-Subset (Holdout, keine CV):

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| Ranger | 0.6667 | 0.7005 | 2.0 s |
| LightGBM | 0.5833 | 0.6060 | 8.3 s |
| TabPFN | **0.7867** | **0.7552** | 151.8 s |

Erkenntnis: Bei sehr wenig Trainingsdaten (~960 Zeilen) schlaegt TabPFN beide Baum-Modelle deutlich — genau sein Spezialgebiet als few-shot-taugliches Foundation-Modell. Nicht direkt vergleichbar mit den anderen Tabellen in diesem README (58x kleineres Subset), aber ein interessantes Signal fuer Datenregime, in denen kaum Trainingsdaten verfuegbar sind. Fuer den aktuellen Datensatz (69008 Zeilen im 10%-Subset) ist LightGBM/Ranger auf CPU praktikabler; TabPFN bliebe nur mit GPU oder der gehosteten `tabpfn-client`-API auf der vollen Datenmenge nutzbar.

## Klassengewichtung

Die Zielvariable ist stark unausgeglichen (`at-risk` ca. 86%, `unhealthy` ca. 8%, `fit` ca. 6%). `105_lightgbm_class_weights.R` testet balancierte Klassengewichte fuer LightGBM ueber `add_balanced_class_weights()` (`000_config.R`): `weight_i = (n_gesamt / (n_klassen * n_klasse_i))^power`. `power = 0` entspricht ungewichtet, `power = 1` voller Balance. Fuenf Stufen per 5-facher CV auf Rohfeatures:

| power | BAcc | MCC | Laufzeit |
|---:|---:|---:|---:|
| 0.00 (ungewichtet) | 0.8779 | 0.8607 | 75.4 s |
| 0.25 | 0.8945 | 0.8558 | 79.0 s |
| 0.50 | 0.9154 | 0.8489 | 98.8 s |
| 0.75 | 0.9278 | 0.8333 | 70.7 s |
| 1.00 (volle Balance) | **0.9358** | 0.8231 | 68.9 s |

Das ist ein glatter, monotoner Trade-off ohne Sweet Spot: BAcc steigt mit `power` stetig, MCC faellt stetig. Konfusionsmatrix-Vergleich (Holdout) zwischen `power=0` und `power=1` erklaert den Mechanismus: Klassengewichtung hebt den Recall der Minderheitsklassen deutlich an (`fit` 82.9% -> 92.7%, `unhealthy` 78.9% -> 92.4%), kostet dafuer Precision derselben Klassen (`fit` 92.2% -> 78.0%, `unhealthy` 94.7% -> 76.8%) — mehr `at-risk`-Faelle werden faelschlich als `fit`/`unhealthy` einsortiert. BAcc (reiner Recall-Durchschnitt) sieht nur den Gewinn, MCC bestraft die zusaetzlichen Falsch-Positiven.

**Entscheidung: `power = 1`** (`class_weight_power` in `000_config.R`). Ausschlaggebend: Kaggle bewertet diesen Wettbewerb ausschliesslich per BAcc, MCC fliesst nicht in die Bewertung ein — volle Balance ist damit fuer das konkrete Ziel (Kaggle-Score) die richtige Wahl, auch wenn das MCC als internes Qualitaetsmass sinkt. `model_class_weight_power` (`000_config.R`) legt fest, welche Modelle gewichtet werden (aktuell nur `lightgbm`); `070_final_models.R` wendet das automatisch ueber `add_balanced_class_weights()` an, bevor der Learner trainiert wird.

## LightGBM Feature-Family-Benchmark

`110_lightgbm_feature_family_benchmark.R` wiederholt den Feature-Family-Vergleich aus `036` fuer LightGBM, diesmal mit der finalen `power=1`-Klassengewichtung auf allen Tasks (sonst waere der Vergleich inkonsistent zur tatsaechlichen Endkonfiguration). 5-fache CV:

| Feature-Set | BAcc | MCC |
|---|---:|---:|
| Roh | 0.9357 | 0.8225 |
| + BMI | 0.9366 | 0.8228 |
| + Schlaf | **0.9372** | 0.8255 |
| + Aktivitaet | 0.9357 | 0.8255 |
| + Hydration | 0.9362 | 0.8261 |
| + Cardio | 0.9342 | 0.8241 |
| + Interaktionen | 0.9347 | 0.8261 |
| Ausgewaehlt (Aktivitaet+Cardio+Schlaf) | 0.9360 | **0.8293** |
| Kombiniert (alle Familien) | 0.9303 | 0.8284 |

Erkenntnis: Alle Werte liegen innerhalb von ca. 0.7 Prozentpunkten Streuung — das ist Rauschniveau, kein robuster Effekt, dasselbe Muster wie bei Ranger/Multinom/LDA in `036`/`037`. "Kombiniert" ist erneut die schwaechste Variante. LightGBM bleibt daher bei Rohfeatures; Feature Engineering bringt fuer dieses Modell keinen verlaesslichen Zusatznutzen.

## Adversarial Validation

`115_adversarial_validation.R` prueft, ob ein Klassifikator Trainings- von Testzeilen (volle `train.csv`/`test.csv`, nicht das 10%-Subset) unterscheiden kann — AUC nahe 0.5 heisst Train/Test sind aehnlich verteilt und CV-Ergebnisse sollten sich aufs Leaderboard uebertragen, AUC deutlich hoeher bedeutet Distribution Shift. LightGBM (statt eines linearen Modells wie LDA) wurde bewusst gewaehlt, weil es auch nichtlineare Verteilungsunterschiede/Interaktionen erkennen kann, die ein linearer Klassifikator uebersehen wuerde:

- **AUC (3-fache CV): 0.654** — ein spuerbarer, reproduzierbarer, aber moderater Shift (kein extremer Wert wie bei Leakage, der naeher an 0.9+ laege).
- Feature Importance des Adversarial-Klassifikators: `water_intake` (29.8%), `calorie_expenditure` (25.7%), `smoking_alcohol` (15.1%), `bmi` (13.8%) erklaeren zusammen ca. 84% der Unterscheidbarkeit.
- Ein direkter Vergleich von Mittelwert, Streuung, Min/Max, NA-Anteil (numerisch) bzw. Kategorienanteilen (`smoking_alcohol`) zwischen Train und Test zeigt fuer alle vier Merkmale **praktisch identische** Verteilungen (Abweichungen im Rauschbereich).

Erkenntnis: Der Shift ist real und reproduzierbar (bei ~985k Zeilen kein Zufallsrauschen), aber nicht als einfacher Mittelwert-/Range-Shift sichtbar — das deutet eher auf ein subtiles Artefakt der (vermutlich synthetischen) Datengenerierung von `playground-series-s6e7` hin als auf einen inhaltlichen Bedeutungsunterschied der Merkmale zwischen Train und Test. Da es keinen klassischen Verteilungsunterschied gibt, an dem man z.B. per Sample-Weighting ansetzen koennte, wird dieser Befund als geprueftes, akzeptables Risiko eingestuft — der bestehende CV-basierte Workflow wird unveraendert fortgesetzt.

## LightGBM: Leere Strings

`120_lightgbm_empty_string_preprocessing.R` wiederholt den Vergleich aus der Baseline (`030` vs. `050`) fuer LightGBM: `""` als eigene Faktorstufe behalten (aktueller Ansatz) vs. `"" -> NA -> Imputation` ueber `empty_factor_to_na` (`040_preprocessing.R`), beide mit `power=1`-Gewichtung, 5-fache CV:

| Variante | BAcc | MCC |
|---|---:|---:|
| `""` behalten | **0.9357** | **0.8225** |
| `"" -> NA -> Imputation` | 0.8951 | 0.7863 |

Erkenntnis: Der Unterschied ist fuer LightGBM sogar noch groesser als bei den urspruenglichen Baseline-Modellen (ca. 4 BAcc- und 3.6 MCC-Punkte) — `""` traegt echtes Signal, das durch Imputation verloren geht. Bestaetigt die bestehende Konfiguration (keine `empty_factor_to_na`-Behandlung im finalen Modell).

## Schwellenwert-Tuning

Idee: Statt (oder zusaetzlich zu) Klassengewichten beim Training koennte man die vorhergesagten Wahrscheinlichkeiten nachtraeglich mit klassenspezifischen Gewichten multiplizieren (`argmax(prob * weight)`) und dieses Gewicht auf einem separaten Tune-Split direkt auf BAcc optimieren. `130_threshold_tuning.R` testet das mit einem stratifizierten 3-Wege-Split (60% Train / 20% Tune / 20% Eval):

| Variante | BAcc (argmax) | MCC (argmax) | BAcc (Gewicht getunt) | MCC (Gewicht getunt) | Gefundene Gewichte |
|---|---:|---:|---:|---:|---|
| LightGBM ungewichtet trainiert | 0.8735 | 0.8626 | 0.9291 | 0.8330 | fit=6.0, unhealthy=6.0 |
| LightGBM `power=1` trainiert (final) | 0.9254 | 0.8323 | 0.9419 | 0.7927 | fit=6.0, unhealthy=6.0 |

**Wichtiger methodischer Befund**: Die gefundenen Gewichte (6.0/6.0) treffen exakt den Rand des Suchgitters (`threshold_tuning_weight_grid = seq(0.5, 6, by = 0.5)`) — es gibt kein inneres Optimum. Reines BAcc-Maximieren ohne Gegengewicht treibt die Gewichte prinzipiell unbegrenzt weiter (im Grenzfall werden Minderheitsklassen fast immer vorhergesagt, Recall steigt, Precision/MCC kollabieren). Post-hoc-Threshold-Tuning ist damit **kein unabhaengiger zusaetzlicher Hebel**, sondern derselbe BAcc/MCC-Trade-off wie bei `class_weight_power`, nur ueber einen anderen Mechanismus (Nachbearbeitung der Wahrscheinlichkeiten statt Trainingsgewichte) erreicht: "ungewichtet trainiert + getunt" (BAcc 0.929, MCC 0.833) landet fast exakt auf demselben Punkt der Kurve wie "`power=1` trainiert + normaler argmax" (BAcc 0.925, MCC 0.832).

**Entscheidung**: Threshold-Tuning wird nicht zusaetzlich zur Trainings-Klassengewichtung eingesetzt — das Stacken beider Mechanismen drueckt MCC weiter (0.793) fuer kaum zusaetzlichen BAcc-Gewinn (0.942 vs. 0.925), ohne einen neuen Freiheitsgrad zu erschliessen. `class_weight_power` bleibt der einzige Regler fuer den BAcc/MCC-Trade-off.

## CatBoost

`125_catboost_benchmark.R` vergleicht CatBoost (Standardparameter, `iterations = 200`, `power=1`-Gewichtung) gegen LightGBM. Anders als beim CatBoost-vs-LightGBM-Kategorien-Argument (siehe Modell-Erkenntnisse) geht es hier um CatBoosts *Ordered Boosting* (reduziert Prediction-Shift/Overfitting unabhaengig von Kategorien) - deshalb doch noch getestet:

| Modell | BAcc | MCC | Laufzeit (5-fache CV) |
|---|---:|---:|---:|
| LightGBM | 0.9357 | **0.8225** | 81.9 s |
| CatBoost | **0.9435** | 0.8022 | 805.8 s (~10x langsamer) |

Erkenntnis: CatBoost gewinnt bei BAcc, verliert bei MCC, bei fast 10x hoeherer Laufzeit — dasselbe Trade-off-Muster wie bei `class_weight_power`, nur ueber einen Modellwechsel statt einen Regler erreicht. Bevor deshalb auf CatBoost umgestiegen wird, lohnt sich der Test, ob LightGBM mit hoeherem `class_weight_power` denselben BAcc-Punkt guenstiger erreicht (siehe naechster Abschnitt).

## Klassengewichtung ueber power=1 hinaus

`135_lightgbm_class_weight_power_extended.R` setzt die Kurve aus `105` (dort nur bis `power=1`, monoton steigend) fort:

| power | BAcc | MCC | Laufzeit |
|---:|---:|---:|---:|
| 1.00 | 0.9357 | 0.8225 | 78.7 s |
| 1.25 | 0.9409 | 0.8116 | 78.5 s |
| 1.50 | 0.9445 | 0.8025 | 77.1 s |
| 1.75 (Peak) | 0.9449 | 0.7945 | 79.3 s |
| 2.00 | 0.9446 | 0.7848 | 70.9 s |
| 2.50 | 0.9417 | 0.7593 | 70.9 s |
| 3.00 | 0.9349 | 0.7304 | 70.4 s |

Anders als im Bereich 0-1 ist diese Kurve **nicht monoton** — sie hat ein inneres Maximum um `power ≈ 1.75` und faellt danach wieder (extreme Gewichte ueberkorrigieren, sodass selbst der Recall-Durchschnitt leidet).

**Entscheidung: `power = 1.5`** (nicht der exakte Peak bei 1.75): BAcc 0.9445 liegt nur 0.0004 unter dem Peak (Rauschniveau), MCC ist bei 1.5 aber spuerbar besser (0.8025 vs. 0.7945). Wichtiger: **`power=1.5` erreicht BAcc und MCC von CatBoost gleichzeitig** (0.9445/0.8025 vs. CatBoosts 0.9435/0.8022) bei gut 10x kuerzerer Laufzeit (77s vs. 806s) — kein Modellwechsel noetig, derselbe Effekt guenstiger ueber den bestehenden Regler erreichbar.

## Ranger und XGBoost mit Klassengewichtung (Ensemble-Kandidaten)

Alle bisherigen Klassengewichts-Experimente liefen nur mit LightGBM. `140_ensemble_candidates_weighted.R` testet Ranger und XGBoost mit derselben `power=1.5`-Gewichtung, um einen fairen Vergleich fuer eine moegliche Ensemble-Entscheidung zu haben (die bisherigen Ranger-/XGBoost-Zahlen aus `080`/`090` waren ungewichtet):

| Modell | BAcc | MCC | Laufzeit (5-fache CV) |
|---|---:|---:|---:|
| LightGBM | 0.9438 | 0.8016 | 79.6 s |
| **Ranger** | **0.9456** | **0.8144** | 135.3 s |
| XGBoost | 0.8912 | 0.7739 | 438.2 s |

**Ueberraschung**: Ranger mit Klassengewichtung schlaegt sowohl LightGBM als auch CatBoost auf beiden Metriken (CatBoost: 0.9435/0.8022) — bei weniger als einem Sechstel von CatBoosts Laufzeit. Ungewichtet war das komplett unsichtbar; der ungewichtete Ranger-Vergleich aus `080`/`090` haette diese Staerke nie gezeigt. XGBoost bleibt dagegen selbst gewichtet deutlich zurueck und ist mit Abstand am langsamsten — kein sinnvoller Ensemble-Kandidat.

**Entscheidung**: Ranger (Rohfeatures, `num.trees=200`, `power=1.5`) loest LightGBM als finales Modell ab (`model_feature_sets`/`model_class_weight_power`/`070_final_models.R`/`150_train_full_model.R`, gesteuert ueber `submission_model_name`).

**Erste Kaggle-Einreichung mit Ranger**: BAcc **0.9482** (vs. 0.94751 mit dem vorherigen LightGBM-Stand) - wieder nah an der CV-Schaetzung (0.9456), bestaetigt erneut die CV-Methodik.

## Ranger + LightGBM Ensemble (verworfen)

`145_ensemble_ranger_lightgbm.R` testet ein gleichgewichtetes Wahrscheinlichkeits-Ensemble (`gunion()` + `po("classifavg")`, beide Zweige `power=1.5`-gewichtet) gegen die Einzelmodelle:

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| Ranger | 0.9456 | **0.8144** | 136.1 s |
| LightGBM | 0.9438 | 0.8016 | 77.0 s |
| Ensemble (50/50) | 0.9459 | 0.8049 | 208.0 s |

Erkenntnis: Der BAcc-Gewinn gegenueber Ranger allein (+0.0003) ist Rauschen, MCC faellt dagegen spuerbar (LightGBMs schwaecherer MCC zieht den Durchschnitt runter), bei fast doppelter Laufzeit. **Entscheidung: kein Ensemble** - Ranger pur bleibt das finale Modell. Anders als bei LDA/Multinom (grosser Staerkeunterschied) liegt es hier daran, dass beide Modelle zu aehnlich in dieselbe Richtung ziehen, um echten Diversitaetsgewinn zu erzeugen.

## Ranger-Tuning unter Klassengewichtung (verworfen)

`090_ranger_tuning.R` tunte Ranger **ohne** Klassengewichtung. `142_ranger_tuning_weighted.R` wiederholt das Tuning auf dem `power=1.5`-gewichteten Task, da die Zielfunktionslandschaft mit Gewichtung eine andere ist:

| Modell | mtry.ratio | min.node.size | sample.fraction | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|---:|---:|---:|
| Default (gewichtet) | 0.333 | 1 | 1.0 | 0.9458 | **0.8148** | 114.3 s |
| Getunt (gewichtet) | 0.377 | 20 | 0.685 | **0.9473** | 0.7920 | 112.3 s |

Erkenntnis: Anders als bei LightGBM (`100`) findet das Tuning hier einen kleinen echten BAcc-Gewinn (+0.0015), aber wieder zum Preis eines spuerbaren MCC-Verlusts (-0.023). Der Gewinn liegt in der Groessenordnung der CV-Rauschgrenze, die wir in anderen Experimenten beobachtet haben. **Entscheidung: Standard-Hyperparameter behalten** - konsistent mit der Wahl `power=1.5` statt des BAcc-Peaks bei `power=1.75`: ein unsicherer, kleiner BAcc-Gewinn rechtfertigt nicht den sichereren, groesseren MCC-Verlust.

## Modell-Erkenntnisse

- Ranger war zunaechst die wichtigste Vergleichsbaseline, wurde von LightGBM abgeloest (Boosting-Benchmark) - und hat dann mit Klassengewichtung LightGBM (und CatBoost) wieder ueberholt (siehe oben). Lektion: Modellvergleiche ohne dieselbe Gewichtungs-/Preprocessing-Behandlung sind nicht belastbar, selbst wenn sie zuvor "eindeutig" aussahen.
- Lineare Modelle profitieren nicht automatisch von vielen abgeleiteten Features.
- LDA reagiert empfindlich auf Kollinearitaet.
- Unregularisierte multinomiale Regression ist schnell, aber nicht stark genug.
- `glmnet + engineered Features` ist methodisch interessant, aber deutlich teurer.
- `s = "lambda.1se"` ist konservativ; `lambda.min` kann spaeter fuer Kaggle-Performance getestet werden.
- SHAP ist noch zu frueh als fester Schritt. Es wird spaeter fuer stabile Baum-/Boosting-Kandidaten interessant.
- Holdout-Vergleiche zwischen aehnlich guten Feature-Varianten sind mit Vorsicht zu geniessen: Der per Cross-Validation bestaetigte Ranger-Befund dreht die Holdout-Erkenntnis (einzelne Familien helfen Ranger) sogar um. Vor einer Modell-/Feature-Entscheidung immer per CV gegenpruefen.
- LightGBM schlaegt mit Standardparametern sowohl Ranger default als auch getunten Ranger — Boosting-Kandidaten vor Hyperparameter-Tuning einzelner Modelle pruefen, nicht danach.
- TabPFN ist bei sehr kleinen Trainingsmengen (< ca. 1000 Zeilen auf CPU) konkurrenzfaehig, fuer den vollen 10%-Subset auf CPU aber nicht praktikabel (Kontextlaengen-Limit).
- CatBoosts Kernvorteil bei Kategorien (Ordered-Target-Statistics) greift hier nicht (nur 3-4 Auspraegungen je Spalte), aber CatBoosts *Ordered Boosting* ist ein unabhaengiger, kategorien-unabhaengiger Vorteil - deshalb doch getestet (siehe CatBoost-Abschnitt): gewinnt bei BAcc, verliert bei MCC, bei fast 10x hoeherer Laufzeit. LightGBM mit hoeherem `class_weight_power` erreicht denselben Punkt guenstiger.
- Auch LightGBM-Tuning per Bayesian Optimization bringt keinen messbaren Vorteil gegenueber den Standardparametern — bei bereits starken Default-Implementierungen (LightGBM, glmnet mit `lambda.1se`) ist der Ertrag von Hyperparameter-Tuning innerhalb eines vertretbaren Budgets gering.
- Klassengewichtung ist ein echter BAcc/MCC-Trade-off, kein Gratis-Gewinn: Welche Seite richtig ist, haengt davon ab, welche Metrik tatsaechlich zaehlt (hier: Kaggle-Bewertung per BAcc) — nicht vom Bauchgefuehl.
- Feature Engineering hilft auch LightGBM nicht robust (siehe Feature-Family-Benchmark) — dasselbe Muster wie bei Ranger/Multinom/LDA bestaetigt sich modelluebergreifend.
- Adversarial Validation zeigt einen moderaten, aber nicht per Mittelwert/Streuung erklaerbaren Train/Test-Unterschied (AUC 0.654) — vermutlich ein Generierungs-Artefakt des synthetischen Datensatzes, kein inhaltlicher Shift. Vor einer Sample-Weighting-Massnahme lohnt es sich, zu pruefen, ob ueberhaupt ein klassischer (Mittelwert-/Range-)Shift vorliegt, den man korrigieren koennte.
- Post-hoc Threshold-Tuning auf Wahrscheinlichkeiten ist kein unabhaengiger Hebel zusaetzlich zur Trainings-Klassengewichtung — beide optimieren denselben BAcc/MCC-Trade-off, nur an unterschiedlichen Stellen der Pipeline. Ein Suchgitter, das am Rand landet (statt an einem inneren Optimum), ist ein Warnsignal fuer eine unbeschraenkte Zielfunktion, nicht ein Zeichen fuer "mehr suchen".

## Modellauswahl pro Learner (Stand nach CV-Check)

- **LDA**: Rohfeatures, keine engineered Features (kollinearitaetsempfindlich, kein CV-bestaetigter Nutzen).
- **Multinom**: Aktivitaet+Cardio+Schlaf-Feature-Set (`task_train_small_features_selected.rds`) — CV-bestaetigter Vorteil gegenueber Rohfeatures.
- **Ranger (finales Modell, `submission_model_name`)**: Rohfeatures, Standardparameter (`num.trees = 200`, sonst Default), balancierte Klassengewichte mit `power = 1.5` — schlaegt gewichtetes LightGBM und CatBoost auf BAcc und MCC gleichzeitig, bei einem Sechstel von CatBoosts Laufzeit (siehe Ensemble-Kandidaten-Abschnitt). Bereits in `model_feature_sets`/`model_class_weight_power`/`070_final_models.R`/`150_train_full_model.R` uebernommen.
- **LightGBM**: weiterhin ein sehr starker Kandidat (Rohfeatures, `power = 1.5`, eigenes Hyperparameter-Tuning brachte keinen Zusatznutzen), aber knapp hinter Ranger — bleibt als moeglicher Ensemble-Partner interessant (siehe Ensemble-Kandidaten-Abschnitt).

Diese Zuordnung ist in `model_feature_sets` und `model_class_weight_power` (`000_config.R`) fest verdrahtet und wird von `070_final_models.R` automatisch angewendet: das Skript laedt je Learner ueber `resolve_task_path()` das passende Feature-Set-Task, wendet ueber `add_balanced_class_weights()` ggf. Klassengewichte an und trainiert/speichert das finale Modell (`_artifacts/final_model_<modell>.rds`).

**Modularitaet fuer einen anderen Klassifikationsaufgaben-Workflow:** `resolve_task_path()` kennt nur die generischen Bezeichner `"raw"`, `"features"`, `"selected"` sowie beliebige Eintraege aus `feature_families` - er ist nicht an dieses Dataset gebunden, ebenso wenig `add_balanced_class_weights()` (arbeitet generisch ueber `task$target_names`). Um das Setup auf eine andere Aufgabe zu uebertragen, muessen nur folgende Teile ausgetauscht werden:

1. `features/*.R` durch neue, aufgabenspezifische `add_<familie>_features()`-Funktionen ersetzen.
2. `feature_families`/`selected_families` in `000_config.R` an die neuen Familien anpassen.
3. `model_feature_sets` neu befuellen (welcher Learner nutzt welches Feature-Set).
4. `model_class_weight_power` neu befuellen (welcher Learner bekommt Klassengewichte, welche `power`-Staerke) - je nachdem, welche Metrik fuer die neue Aufgabe zaehlt.
5. `base_learner_constructors` um neue Modellnamen ergaenzen, falls noetig, und `submission_model_name` auf das gewuenschte finale Modell setzen.

`005_benchmark_runtime.R`, `040_preprocessing.R`, `025_feature_engineering.R`, `070_final_models.R` und `150_train_full_model.R` bleiben dabei unveraendert, da sie ausschliesslich ueber diese Konfigurationswerte arbeiten.

## Finales Training & Submission

`150_train_full_model.R` trainiert `submission_model_name` (aktuell `ranger`: Rohfeatures, Standardparameter, `class_weight_power = 1.5`) auf dem **vollen** Trainingsdatensatz (`train.csv`, 690088 Zeilen statt des 10%-Subsets) und speichert Modell + Faktorstufen der Merkmale gemeinsam (`_artifacts/final_model_<modell>_full.rds`) - Letzteres, damit `155_predict_submission.R` `test.csv` exakt auf dieselben Kategorie-Stufen abbildet, unabhaengig davon, ob im Test-Set zufaellig alle Stufen vorkommen. `155` erzeugt daraus `submission.csv` im Format von `sample_submission.csv` (Spalten `id`, `health_condition`).

Vorhergesagte Klassenverteilung auf `test.csv` (295753 Zeilen, Ranger): `at-risk` 81.8%, `unhealthy` 10.9%, `fit` 7.25% (Rohverteilung im Training war ca. 86/8/6%) - naeher an der Rohverteilung als LightGBMs Vorhersage, passend zu Rangers besserer Precision/MCC in der CV.

**Erste Kaggle-Einreichung** (LightGBM, `power=1.5`, vor der Ranger-Umstellung): BAcc **0.94751**, Platz 618/1104 - sehr nah an der lokalen CV-Schaetzung (0.9445), was die CV-Methodik nachtraeglich bestaetigt (kein Overfitting an das 10%-Subset, der Adversarial-Validation-Shift hat sich als unschaedlich erwiesen).

Kein erneutes Hyperparameter-Tuning auf dem vollen Datensatz: `100_lightgbm_tuning.R` zeigte auf dem Subset keinen Vorteil gegenueber Standardparametern, und eine erneute Suche haette auf der 10x groesseren Datenmenge grob geschaetzt 1.5-2.5 Stunden gekostet, ohne dass ein anderes Ergebnis zu erwarten war.

## Naechste Schritte

1. ~~Ranger als feste Referenzbaseline behalten~~ - Ranger ist (wieder) das finale Modell, diesmal mit Klassengewichtung, finales Training auf vollem Datensatz abgeschlossen (siehe oben).
2. ~~Feature Engineering in kleinere Feature-Familien aufteilen~~ - erledigt in `features/*.R`, `025`, `036` und `037`, fuer LightGBM in `110` bestaetigt (kein Zusatznutzen).
3. ~~Preprocessing-Strategien explizit fuer LightGBM vergleichen~~ - erledigt in `120`: `""` behalten bleibt klar besser (bestaetigt bestehende Konfiguration).
4. ~~Boosting-Kandidaten pruefen: XGBoost, LightGBM, CatBoost~~ - XGBoost/LightGBM erledigt in `080`, CatBoost in `125`, alle drei nochmal gewichtet in `140` (Ranger gewinnt).
5. ~~LightGBM tunen~~ - erledigt in `100` (Bayesian Optimization via `mlr3mbo`), kein Zusatznutzen gegenueber Standardparametern.
6. ~~Klassengewichtung pruefen~~ - erledigt in `105`/`135`, `power = 1.5` uebernommen; in `140` bestaetigt, dass Ranger davon noch staerker profitiert als LightGBM.
7. ~~Adversarial Validation durchfuehren~~ - erledigt in `115`. Moderater, aber nicht per Mittelwert/Streuung erklaerbarer Shift (AUC 0.654) - als geprueftes Risiko akzeptiert, kein Handlungsbedarf.
8. ~~Post-hoc Threshold-Tuning pruefen~~ - erledigt in `130`, kein unabhaengiger Hebel gegenueber `class_weight_power`.
9. ~~Ganz am Schluss: kompletten Trainingsdatensatz statt 10%-Subset verwenden~~ - erledigt in `150`/`155`, `submission.csv` erzeugt. Kaggle-Einreichungen: LightGBM-Stand BAcc 0.94751 (Platz 618/1104), Ranger-Stand BAcc 0.9482 - beide nah an der jeweiligen CV-Schaetzung.
10. ~~Ensemble aus LightGBM + Ranger~~ - erledigt in `145`: kein Zusatznutzen, BAcc-Gewinn ist Rauschen, MCC leidet. Ranger pur bleibt final. XGBoost bewusst ausgeschlossen (schwaecher und ~10x langsamer, siehe `140`).
11. ~~Ranger-Tuning unter Klassengewichtung pruefen~~ - erledigt in `142`: kleiner, unsicherer BAcc-Gewinn (+0.0015) zum Preis eines spuerbaren MCC-Verlusts (-0.023) - nicht uebernommen, Standard-Hyperparameter bleiben.
12. Pseudo-Labeling als moeglicher weiterer Hebel besprochen (mehr Trainingsdaten, passt Modell an Testverteilung an) - Risiko: kann die muehsam hergestellte Klassenbalance wieder unterlaufen, falls Konfidenz-Schwellen nicht pro Klasse gesetzt werden. Noch nicht umgesetzt.
13. Optional, falls noch gewuenscht: SHAP/Interpretierbarkeit fuer das finale Modell einsetzen.
14. ~~`targets` zur Orchestrierung der Skripte einfuehren~~ - erledigt (`_targets.R`), deckt den finalen Workflow ab (Task-Erzeugung bis Submission), siehe eigener Abschnitt oben.
