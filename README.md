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
| `025_feature_engineering.R` | Erzeugt datenquellenspezifische Gesundheits-Proxies und Interaktionen |
| `030_baseline.R` | Autarke Baseline mit LDA, Multinom und Ranger |
| `035_feature_baseline.R` | Dieselben Baseline-Modelle auf engineered Features |
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

Das Feature-Skript erzeugt u.a.:

- BMI-Kategorie
- Schlafabweichungen: `sleep_deficit_7h`, `sleep_excess_9h`, `sleep_distance_from_8h`
- Aktivitaets- und Energie-Ratios: `steps_per_exercise_min`, `calories_per_step`, `calories_per_exercise_min`
- Hydration-Ratios: `water_per_1000_calories`, `water_per_exercise_min`
- Herz-Kreislauf-Proxies: `heart_rate_per_bmi`, `cardio_strain_proxy`
- Kategoriale Interaktionen: `stress_sleep_quality`, `activity_smoking_alcohol`, `diet_activity`

Feature Engineering erhoeht den Task von 13 auf 30 Features.

| Modell | BAcc | MCC | Laufzeit |
|---|---:|---:|---:|
| LDA + Features | 0.8045 | 0.7131 | ca. 11 s |
| Multinom + Features | 0.8424 | 0.7939 | ca. 42 s |
| Ranger + Features | 0.8729 | 0.8638 | ca. 78 s |

Erkenntnis: LDA verschlechtert sich deutlich und meldet Kollinearitaet. Ranger profitiert leicht. Die engineered Features sind daher kein Standardpfad, sondern eine experimentelle Feature-Familie.

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

## Naechste Schritte

1. Ranger als feste Referenzbaseline behalten.
2. Feature Engineering in kleinere Feature-Familien aufteilen: Schlaf, Aktivitaet, Hydration, Interaktionen.
3. Preprocessing-Strategien explizit vergleichen: `""` behalten vs. `"" -> NA`.
4. Boosting-Kandidaten pruefen: XGBoost, LightGBM, CatBoost.
5. Erst danach SHAP/Interpretierbarkeit fuer starke Kandidaten einsetzen.
6. Spaeter `targets` zur Orchestrierung der Skripte einfuehren.
