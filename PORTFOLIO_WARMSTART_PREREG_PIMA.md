# Portfolio-Warmstart Pre-Registered Test: Pima Diabetes

Stand: 2026-08-24, vor dem neuen Validierungslauf.

## Ziel

Dritter Projektvalidierungstest fuer die Portfolio-Warmstart-Linie nach
`PumpItUp` und `openml-credit-g`. Pima ist klein, binaer, numerisch und damit
ein weiteres Profil: keine hochkardinalen Kategorien, keine Kaggle-/DrivenData-
Submission, kein Multiclass.

## Projekt

- Projektname: `pima-diabetes-sentinel-test`
- Aufgabe: binaere Diabetes-Klassifikation
- Primaermetrik: `classif.bacc`
- Sekundaer: `classif.auc`, `classif.mcc`
- Daten: 768 Zeilen, lokales Projekt unter
  `C:\Users\HP\ML_Learning\pima-diabetes-sentinel-test`

## Vorab-Empfehlung

Die Portfolio-Linie empfiehlt erneut als Startkern:

1. `lightgbm`
2. `ranger`
3. `ensemble`

## Projektspezifische Festlegung

Pima ist ein klassischer Sentinel-Datensatz (`0` als fehlender Wert in einigen,
aber nicht allen Spalten). Die fruehere Projektanalyse zeigte jedoch keinen
klaren Score-Nutzen fuer korrekt spaltenspezifisches Sentinel-Handling. Fuer
diesen Warmstart-Test wird deshalb die rohe Variante verwendet, damit das
Portfolio getestet wird und nicht erneut die Sentinel-Strategie.

## Testprotokoll

- 5-fold CV, gleicher Seed, gleiche Folds fuer alle Kandidaten.
- Kandidat A: LightGBM mit Median-Imputation.
- Kandidat B: Ranger mit Median-Imputation.
- Kandidat C: schlichtes Probability-Average-Ensemble aus A+B.
- Kein Tuning, keine externen Daten.

## Erfolgskriterium

Die dritte Projektbestaetigung gilt als positiv, wenn einer der vorab
empfohlenen Kandidaten den besten BAcc-Score des Laufs erreicht und die
Ergebnisse eine sinnvolle fruehe Reihenfolge fuer kleine numerische Aufgaben
ergeben. Das Ensemble ist weiterhin optionaler Score-Hebel, kein erwarteter
Pflichtsieger.

