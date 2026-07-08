# MLR3 Classification AutoML Prototype

Dieses Unterprojekt entwickelt eine wiederverwendbare AutoML-Struktur fuer Kaggle-Klassifikationsaufgaben mit `mlr3`.

Der aktuelle Datensatz stammt aus `playground-series-s6e7` und beschreibt Gesundheits- und Lifestyle-Merkmale. Zielvariable ist `health_condition` mit drei Klassen: `at-risk`, `unhealthy`, `fit`.

## Zielbild

Die Projektstruktur trennt bewusst mehrere Ebenen:

- `mlr3pipelines` beschreibt die Modell-Pipeline: Imputation, Faktorbehandlung, Encoding, Skalierung und Learner.
- Die nummerierten Skripte beschreiben den Workflow: Datenueberblick, Task-Erzeugung, Baselines, Feature Engineering, Kandidatenmodelle.
- Spaeter kann `targets` diese Skripte orchestrieren, ersetzt aber nicht die `mlr3`-Pipelines.
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

## Modell-Erkenntnisse

- Ranger ist die wichtigste Vergleichsbaseline.
- Lineare Modelle profitieren nicht automatisch von vielen abgeleiteten Features.
- LDA reagiert empfindlich auf Kollinearitaet.
- Unregularisierte multinomiale Regression ist schnell, aber nicht stark genug.
- `glmnet + engineered Features` ist methodisch interessant, aber deutlich teurer.
- `s = "lambda.1se"` ist konservativ; `lambda.min` kann spaeter fuer Kaggle-Performance getestet werden.
- SHAP ist noch zu frueh als fester Schritt. Es wird spaeter fuer stabile Baum-/Boosting-Kandidaten interessant.
- Holdout-Vergleiche zwischen aehnlich guten Feature-Varianten sind mit Vorsicht zu geniessen: Der per Cross-Validation bestaetigte Ranger-Befund dreht die Holdout-Erkenntnis (einzelne Familien helfen Ranger) sogar um. Vor einer Modell-/Feature-Entscheidung immer per CV gegenpruefen.

## Modellauswahl pro Learner (Stand nach CV-Check)

- **LDA**: Rohfeatures, keine engineered Features (kollinearitaetsempfindlich, kein CV-bestaetigter Nutzen).
- **Multinom**: Aktivitaet+Cardio+Schlaf-Feature-Set (`task_train_small_features_selected.rds`) — CV-bestaetigter Vorteil gegenueber Rohfeatures.
- **Ranger**: Rohfeatures — der Holdout-Vorteil einzelner Familien haelt der Cross-Validation nicht stand.

## Naechste Schritte

1. Ranger als feste Referenzbaseline behalten (auf Rohfeatures, siehe Modellauswahl oben).
2. ~~Feature Engineering in kleinere Feature-Familien aufteilen~~ - erledigt in `features/*.R`, `025`, `036` und `037`. Modellspezifische Feature-Auswahl steht fest (siehe oben).
3. Preprocessing-Strategien explizit vergleichen: `""` behalten vs. `"" -> NA`.
4. Boosting-Kandidaten pruefen: XGBoost, LightGBM, CatBoost.
5. Erst danach SHAP/Interpretierbarkeit fuer starke Kandidaten einsetzen.
6. Spaeter `targets` zur Orchestrierung der Skripte einfuehren.
