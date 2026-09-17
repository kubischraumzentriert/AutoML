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

`prepare_pilot.R` erzeugt fuer zwei Bundesland/Station-Faelle je zwei
identische Tabellen:

- Brandenburg/Potsdam (Station `03987`): `pilot_baseline.csv` /
  `pilot_weather.csv`
- Bayern/Muenchen-Stadt (Station `03379`): `pilot_baseline_bayern.csv` /
  `pilot_weather_bayern.csv`

Je Fall: eine Tabelle mit Kalender- und Camping-/Nachfrage-Lags ohne Wetter,
eine mit denselben Merkmalen plus monatlich aggregierten DWD-Wetterwerten.

Das Ziel ist `high`/`low` fuer die Uebernachtungszahl des Folgemonats. Die
Schwelle wird nur auf dem Zeitraum vor `2019-01-01` bestimmt. Der Split ist
chronologisch, nicht zufaellig - identisch fuer beide Faelle.

Die Dateien sind vorbereitete, eingefrorene Snapshots. Es gibt keinen Live-
DWD-Download innerhalb von Resampling oder Cross-Validation.

Beide Faelle stammen aus derselben OpenML-Quelle (nur Bundesland/Station
unterscheiden sich) und pruefen damit Regionsrobustheit, nicht Uebertragbarkeit
auf ein unabhaengiges Projekt. Ergebnis: Wetter hilft in Brandenburg, schadet
leicht in Bayern - siehe
[`docs/research/DWD_WEATHER_INTEGRATION.md`](../../docs/research/DWD_WEATHER_INTEGRATION.md)
fuer die vollstaendige Evidenz.

## Ausfuehrung

```powershell
Rscript prepare_pilot.R
```

Danach werden beide Tabellen mit derselben Workflow-Konfiguration bewertet.
Der erste Vergleich bleibt bewusst klein: Baseline gegen Wetter-Features,
identischer Seed, identische Modelle und identischer zeitbasierter Test.
