# Portfolio-Warmstart Pre-Registered Test: OpenML Credit-G

Stand: 2026-08-24, vor dem neuen Validierungslauf.

## Ziel

Zweiter echter Projektvalidierungstest fuer die Portfolio-Warmstart-Linie nach
`PumpItUp`. Dieses Projekt ist klein, binaer und deutlich anders strukturiert
als PumpItUp; es ist in der aktuellen Leave-one-project-out-Evidenzdatei
`portfolio_warmstart_validation_leave_one_project_out.csv` nicht enthalten.

## Projekt

- Projektname: `openml-credit-g`
- Aufgabe: binaere Kreditrisiko-Klassifikation
- Primaermetrik: `classif.bacc`
- Sekundaer: `classif.mcc`
- Daten: 1000 Zeilen, lokaler Task unter
  `C:\Users\HP\ML_Learning\openml-credit-g`

## Vorab-Empfehlung

Die Portfolio-Linie empfiehlt erneut als Startkern:

1. `lightgbm`
2. `ranger`
3. `ensemble`

## Testprotokoll

- 5-fold CV, gleicher Seed, gleiche Folds fuer alle Kandidaten.
- Kandidat A: LightGBM mit Median-/Mode-Imputation.
- Kandidat B: Ranger mit Median-/Mode-Imputation.
- Kandidat C: schlichtes Probability-Average-Ensemble aus A+B.
- Kein Tuning, keine externen Daten.

## Erfolgskriterium

Die zweite Projektbestaetigung gilt als positiv, wenn einer der vorab
empfohlenen Kandidaten den besten BAcc-Score des Laufs erreicht und der
Ensemble-Schritt keinen klaren Schaden gegenueber beiden Einzelmodellen
verursacht. Da nur die empfohlenen Kandidaten getestet werden, ist dies eine
Validierung der Startportfolio-Linie, kein vollstaendiger Modellvergleich.

