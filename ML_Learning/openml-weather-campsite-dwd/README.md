# OpenML/DWD Weather Enrichment Pilot

## Ziel

Dieser Pilot prueft, ob externe DWD-Wettermerkmale die Klassifikation der
Camping-Nachfrage in Brandenburg verbessern.

- OpenML dataset: `weather_and_campsite_germany`, DID `46263`
- OpenML source file: `source.arff`
- DWD CDC station: Potsdam, station `03987`
- DWD source file: `dwd_potsdam/produkt_klima_tag_18930101_20251231_03987.txt`
- Licence: OpenML CC-BY; DWD CC BY 4.0

## Vergleich

`prepare_pilot.R` erzeugt zwei identische Tabellen:

- `pilot_baseline.csv`: Kalender- und Camping-/Nachfrage-Lags, ohne Wetter
- `pilot_weather.csv`: dieselben Merkmale plus monatlich aggregierte DWD-
  Wetterwerte

Das Ziel ist `high`/`low` fuer die Uebernachtungszahl des Folgemonats. Die
Schwelle wird nur auf dem Zeitraum vor `2019-01-01` bestimmt. Der Split ist
chronologisch, nicht zufaellig.

Die Dateien sind vorbereitete, eingefrorene Snapshots. Es gibt keinen Live-
DWD-Download innerhalb von Resampling oder Cross-Validation.

## Ausfuehrung

```powershell
Rscript prepare_pilot.R
```

Danach werden beide Tabellen mit derselben Workflow-Konfiguration bewertet.
Der erste Vergleich bleibt bewusst klein: Baseline gegen Wetter-Features,
identischer Seed, identische Modelle und identischer zeitbasierter Test.
