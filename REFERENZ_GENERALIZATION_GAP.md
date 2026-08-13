# Referenz: Generalisierungsluecke formal quantifizieren/herausfordern

Formalisiert, was bisher ad-hoc als "CV<->LB-Luecke gross/klein?" beurteilt
wurde (siehe z.B. `REFERENZ_ENSEMBLE_SELECTION.md`, s6e8-Notizen): statt
eines Bauchgefuehls ein statistischer Vergleich der CV-Score-Verteilung
gegen eine Bootstrap-Verteilung auf unberuehrten Daten, eingeordnet gegen
einen Referenzbereich aus mehreren UNGETUNTEN Baseline-Algorithmen.

---

## 1. Herkunft

Direkt uebernommen aus Jason Brownlee, ["Data Science Diagnostic
Checklist"](https://github.com/Jason2Brownlee/DataScienceDiagnosticChecklist)
(GitHub), Abschnitte 5 ("Quantify the Performance Gap") und 6 ("Challenge
the Performance Gap"). Ein Abgleich der vollstaendigen 19-teiligen Checkliste
gegen den Template-Stand (Stand 2026-08-13) ergab starke Ueberschneidung mit
bestehenden Modulen (siehe Tabelle unten) und vier echte Luecken, von denen
diese (formale Gap-Quantifizierung) als wertvollste priorisiert wurde.

Verwandt (gleicher Autor, komplementaeres Thema, nicht direkt eingebaut):
[MachineLearningMischief](https://github.com/Jason2Brownlee/MachineLearningMischief)
katalogisiert bewusst unethische ML-Praktiken (Seed-Hacking, P-Hacking,
Test-Harness-Hacking, Leaderboard-Gaming) als Negativbeispiele - der
"Winner's Curse"-Mechanismus, den dieses Modul erkennen soll (Abschnitt 3),
ist strukturell dasselbe Phaenomen wie das dort beschriebene
Test-Harness-Hacking, nur unbeabsichtigt statt absichtlich herbeigefuehrt.

### Abgleich Checkliste vs. Template-Stand (Auszug)

| Checkliste | Template-Aequivalent |
|---|---|
| §7 Verteilungs-Checks (KS/Chi²) | `univariate_drift.R` |
| §7 multivariate Trennung | Adversarial Validation + ESS |
| §9 schwierige Segmente/Klassen | `147_error_analysis_ranger_segments.R` |
| §14 Feature-Rausch-/Invarianz-Robustheit | `sanity_checks.R` |
| §15.1 Seed-Ensembling | Ensemble Selection (Caruana) |
| §15.2 Nested CV fuers Tuning | `090`/`100` via `AutoTuner` |
| §2 i.i.d.-Verletzung (Gruppen) | `group_resampling.R` |
| §4 Data Leakage | anderer Fokus als `015_target_leak_audit.R` (dort: Feature-Target-Leakage; Checkliste: Train/Test-Grenzverletzung) - komplementaer, kein Duplikat |
| §5/§6 Gap-Quantifizierung | **neu, dieses Dokument** |
| §3 Split-Size-Sensitivity, §11 Lern-/Validierungskurven | offene Luecken, nicht priorisiert |

## 2. Mechanismus

Zwei Groessen werden verglichen:
- **CV-Scores** (typischerweise 5 Werte aus `rsmp("cv", folds=5)`) auf dem
  Trainingsanteil.
- **Bootstrap-Test-Scores** (typischerweise 200 Werte): ein EINMAL auf dem
  vollen Trainingsanteil gefittetes Modell wird auf einem komplett
  unberuehrten Testanteil vorhergesagt, die Vorhersagezeilen werden
  wiederholt mit Zuruecklegen resampled (`bootstrap_score_distribution()`).

Ein direkter statistischer Test zwischen diesen beiden Verteilungen
(Mann-Whitney-U, Kolmogorov-Smirnov, Cohen's d) ist strukturell schwach
gepowert: CV-Fold-Varianz (wenige Werte, Fold-zu-Fold-Modellvariabilitaet)
und Bootstrap-Varianz (viele Werte, aber nur Resampling-Unsicherheit EINES
fixen Modells) sind zwei verschiedene Rauschquellen unterschiedlicher
Groessenordnung - der p-Wert dieses paarweisen Tests bleibt daher als
Zusatzdiagnose erhalten, ist aber NICHT das Flagging-Kriterium.

Stattdessen: **Referenzbereich aus mehreren ungetunten Baseline-Algorithmen**
(dieselbe Prozedur, keine Hyperparameter-Auswahl) liefert die "normale"
Luecken-Groesse fuer genau dieses Projekt/diese CV-Prozedur. Die Luecke des
Kandidatenmodells wird als z-Score gegen diese Referenzverteilung
eingeordnet (`generalization_gap_report()`). Der z-Score ist
selbst-kalibrierend (dieselbe Prozedur-Verzerrung faellt auf beiden Seiten
gleich aus) und robuster als der direkte paarweise Test. Bewusst
ASYMMETRISCH: nur eine Luecke, die PESSIMISTISCHER ausfaellt als der
Referenzbereich (Test schlechter als CV, ueber das erwartbare Mass hinaus),
gilt als auffaellig - ein Test-Score, der besser als CV ausfaellt, ist kein
Alarmgrund.

## 3. Synthetische Verifikation

Zwei Szenarien (`rpart`, 2 informative + 40 Rausch-Features, n_train=400,
n_test=4000):

- **Szenario A** (eine feste, vernuenftige Konfiguration, keine Auswahl):
  z=+2.30 (Test SOGAR besser als CV) -> korrekt NICHT auffaellig.
- **Szenario B** ("Winner's Curse": bestes von 60 zufaellig konfigurierten
  Modellen NACH CV-Score ausgewaehlt, dann auf frischen Daten evaluiert -
  der klassische Mechanismus hinter Test-Harness-Ueberanpassung, siehe
  Checkliste §15.2 "nested CV" als Gegenmittel): z=-3.12 -> korrekt
  **auffaellig**.

Ein erster Modul-Entwurf koppelte das Flagging zusaetzlich an
`wilcox_p < 0.05` des direkten paarweisen Tests - das haette Szenario B
(wilcox_p=0.62 trotz realem Effekt, siehe Abschnitt 2) faelschlich als
unauffaellig durchgehen lassen. Korrigiert: z-Score allein ist das Gate.

## 4. Reale Anwendung (2 Projekte, ADR-003 erfuellt)

**`openml-steel-plates-fault`** (7-Klassen-Multiclass, 1941 Zeilen, siehe
`ML_Learning/openml-steel-plates-fault/README.md`): Referenzbereich aus
LDA/Multinom/Ranger-Default/LightGBM-Default zeigt eine "normale"
Hintergrund-Luecke von -0.039 BAcc (SD 0.017) bei diesem kleinen,
unbalancierten Datensatz. Die per Suche getunten Ranger-/LightGBM-Modelle
(`090`/`100`, bestes von 20/25 Kandidaten nach CV-Score) liegen mit z=-1.63
bzw. z=-0.39 BEIDE innerhalb des Referenzbereichs - kein Beleg fuer
zusaetzlichen Test-Harness-Optimismus durch die Suche.

**`openml-satimage-multiclass`** (6-Klassen-Multiclass, 6430 Zeilen, siehe
`ML_Learning/openml-satimage-multiclass/`): Referenzbereich zeigt eine
deutlich kleinere/engere Hintergrund-Luecke (+0.013 BAcc, SD 0.008) -
passend zur Erwartung, dass CV-Rauschen mit der Datensatzgroesse sinkt
(Vorzeichen positiv statt negativ, bei nur 5 CV-Fold-Werten pro Projekt
eher Stichprobenrauschen als ein echtes Muster). Getunte Kandidaten: z=1.03
bzw. z=0.50, ebenfalls unauffaellig.

Beide Male ein plausibles, informatives Negativergebnis: bestaetigt
indirekt, dass das `AutoTuner`-Innen-/Aussen-Resampling in `090`/`100`
seinen Zweck erfuellt. **Einschraenkung**: beide realen Anwendungen (plus
der Regressionstest gegen `health_condition`, Abschnitt 5) zeigen bisher
nur die "unauffaellig"-Seite - dass das Modul einen echten Fall erkennen
KANN, ist bisher nur synthetisch bewiesen (Abschnitt 3), nicht an echten
Daten.

## 5. Status

**Backportiert (2026-08-13)** als `136_generalization_gap.R` +
Config-Ergaenzungen (`000_config.R`: `generalization_gap_test_ratio`,
`generalization_gap_n_boot`, `generalization_gap_results_path`).
Referenzbereich wird generisch aus `base_learner_constructors` gebaut,
Kandidaten aus den `090`/`100`-Tuning-Instanzen extrahiert (`result_
learner_param_vals`, Baum-/Iterationszahl auf den Finalwert ueberschrieben)
- ueberspringt automatisch, falls `090`/`100` fuer ein Projekt noch nicht
gelaufen sind. Regressionsgetestet gegen das Template-eigene Projekt
(`health_condition`): laeuft fehlerfrei durch, Ergebnis unauffaellig (siehe
Abschnitt 4). Nimmt eine klassenresponse-basierte Zielmetrik an (BAcc/MCC/
Accuracy) - bei einer wahrscheinlichkeitsbasierten Metrik (AUC/LogLoss)
noch nicht abgedeckt (siehe Kopfkommentar in `136_generalization_gap.R`).

## 6. Quellen

- Jason Brownlee, [Data Science Diagnostic
  Checklist](https://github.com/Jason2Brownlee/DataScienceDiagnosticChecklist)
  (GitHub) - Abschnitte 5/6, direkte Quelle dieses Moduls.
- Jason Brownlee, [Machine Learning
  Mischief](https://github.com/Jason2Brownlee/MachineLearningMischief)
  (GitHub) - komplementaerer Negativbeispiel-Katalog, gleicher Autor.
- `ML_Learning/openml-steel-plates-fault/generalization_gap.R`,
  `135_generalization_gap.R`, `README.md` - Implementierung, synthetische
  Verifikation und reale Anwendung.
