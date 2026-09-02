# Portfolio-Warmstart Pre-Registered Test: Pump It Up

Stand: 2026-08-24, vor dem neuen Validierungslauf.

## Ziel

Erster echter Projektvalidierungstest fuer die Portfolio-Warmstart-Linie auf
einem Projekt, das nicht in der aktuellen zentralen
`portfolio_warmstart_algorithm_best.csv`/LOO-Evidenz als regulärer
Klassifikationsbenchmark enthalten ist: `C:\Users\HP\ML_Learning\PumpItUp`.

## Projekt

- Projektname: `drivendata-pump-it-up`
- Aufgabe: 3-Klassen-Klassifikation fuer Pumpenstatus
- Primaermetrik: `classif.acc` (DrivenData Classification Rate)
- Sekundaer: `classif.bacc`, `classif.mcc`
- Daten: 59k Train-Zeilen, vorhandenes lokales Projekt

## Vorab-Empfehlung

Die Portfolio-Linie empfiehlt als Startkern:

1. `lightgbm`
2. `ranger`
3. `ensemble`

Projektspezifische Einschraenkung: PumpItUp hat hochkardinale kategoriale
Spalten (`funder`, `installer`, `ward`, `subvillage`). Das alte Projekt-README
haelt fest, dass Ranger darauf nicht direkt der faire Default ist. Deshalb
wird Ranger fuer diesen Test mit zielwertfreiem Frequency-Encoding fuer diese
Spalten getestet, waehrend LightGBM seine native Kategorienbehandlung nutzt.

## Testprotokoll

- 3-fold CV, gleicher Seed, gleiche Folds fuer alle Kandidaten.
- Kandidat A: LightGBM native Kategorien, nahe am alten Baseline-Setup.
- Kandidat B: Ranger mit Frequency-Encoding fuer hochkardinale Spalten.
- Kandidat C: schlichtes Probability-Average-Ensemble aus A+B.
- Kein Tuning, keine Kaggle/DrivenData-Submission, keine externen Daten.

## Erfolgskriterium

Die Warmstart-Linie gilt fuer diesen Test als bestaetigt, wenn einer der
vorab empfohlenen Kandidaten den besten Score des Laufs erreicht und die
Reihenfolge keine offensichtlich nutzlose Fruehphase erzeugt. Da nur die
empfohlenen Kandidaten getestet werden, ist dies eine Projektvalidierung der
Praktikabilitaet und Reihenfolge, kein vollstaendiger Modellvergleich.

