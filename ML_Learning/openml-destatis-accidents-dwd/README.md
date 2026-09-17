# Destatis/DWD Weather Enrichment Pilot: Verkehrsunfaelle

## Ziel

Prueft, ob DWD-Wetteranreicherung die Klassifikation des naechsten-Monats-
Unfallvolumens (Unfaelle mit Personenschaden) in Nordrhein-Westfalen
verbessert. Unabhaengiges Projekt zum Camping-Piloten
([`../openml-weather-campsite-dwd/`](../openml-weather-campsite-dwd/)):
andere Datenquelle (Destatis-Unfallstatistik statt Tourismusdaten), anderer
Zielmechanismus, andere Region/Station.

- Quelle: GENESIS-Online (Destatis) Tabelle `46241-0021` "Unfaelle
  (polizeilich erfasste): Bundeslaender, Monate, Unfallkategorie, Ortslage"
- DWD CDC-Station: Koeln-Bonn, Station `02667`
- Abgerufen 2026-09-17 ueber den oeffentlichen, unauthentifizierten
  GENESIS-REST-Endpunkt (`Accept: application/json` + `Referer` auf die
  Tabellenseite - kein Login/API-Key noetig)

## Vergleich

`prepare_pilot.R` erzeugt `pilot_baseline.csv` (Kalender- und
Unfall-Lags, ohne Wetter) und `pilot_weather.csv` (dieselben Merkmale plus
monatlich aggregierte DWD-Wetterwerte). Ziel ist `high`/`low` fuer die
Anzahl der Unfaelle mit Personenschaden im Folgemonat. Schwelle nur auf dem
Zeitraum vor `2022-01-01` bestimmt, Split chronologisch.

`compare_pilot.R` vergleicht beide Varianten mit identischem Split/Seed/
Modell (siehe Camping-Pilot fuer die Begruendung des Skript-Aufbaus).

Ergebnis: Wetter hilft leicht (BAcc +0,037, MCC +0,065) - siehe
[`docs/research/DWD_WEATHER_INTEGRATION.md`](../../docs/research/DWD_WEATHER_INTEGRATION.md)
fuer die vollstaendige Evidenz.
