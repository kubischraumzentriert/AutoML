# features/

Projektspezifische Feature-Engineering-Helfer für `health_condition` (das
im Template mitgelieferte Beispielprojekt) - domänenspezifische
Transformationen aus rohen Gesundheits-/Fitness-Messwerten (Herzfrequenz,
Schritte, Schlaf, Wasseraufnahme etc.), keine generischen, projekt-
unabhängigen Bausteine wie `modules/`.

**Bei einer Übertragung auf ein neues Projekt (siehe `TARGETS.md`)**: diese
Dateien sind das Gegenteil von wiederverwendbar - sie kodieren
Domänenwissen zu genau diesem Datensatz. Ein neues Projekt braucht eigene,
neu geschriebene Feature-Funktionen nach demselben Muster (eine Datei je
thematischem Block, `add_<block>_features(data)` als Funktionsname), nicht
eine Anpassung dieser Dateien.

| Datei | Feature-Block |
|---|---|
| `activity.R` | Aktivität (Schritte, Kalorien, Trainingsdauer, abgeleitete Verhältnisse) |
| `bmi.R` | BMI-Kategorisierung |
| `cardio.R` | Herzfrequenz/Kreislauf |
| `hydration.R` | Wasseraufnahme |
| `sleep.R` | Schlafdauer/-defizit |
| `interactions.R` | Kategoriale Interaktions-Features (String-Kombinationen mehrerer Rohspalten) |
| `frequency_encoding.R` | Generisches Frequency-Encoding kategorialer Spalten (mlr3pipelines-`PipeOp`) |
| `target_encoding.R` | Generisches Target-Encoding kategorialer Spalten (mlr3pipelines-`PipeOp`) |
| `surrogate_guided.R` | Surrogat-modell-geleitete Feature-Vorschläge |
| `entity_history.R` | Generischer, zeit-respektierender Entitäts-Historie-Helfer (aus zwei unabhängigen Projekten zurückgeführt - siehe Kopfkommentar, eher `modules/`-artig als die übrigen Dateien hier) |
| `utils.R` | `safe_divide()` u.a. gemeinsame Hilfsfunktionen für die obigen Dateien |

Genutzt von `000_config.R` (Feature-Set-Definition), `150_train_full_model.R`,
`155_predict_submission.R`.
