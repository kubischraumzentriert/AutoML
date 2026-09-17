# Destatis/DWD Weather Enrichment Pilot: Sterbefaelle

## Ziel

Prueft, ob DWD-Wetteranreicherung die Klassifikation der naechsten-Monats-
Sterbefallzahl in Sachsen verbessert. Mechanismus: dokumentierte
Winterexzess-Mortalitaet (kalte Monate korrelieren mit mehr Sterbefaellen,
vor allem kardiovaskulaer/respiratorisch). Unabhaengiges Projekt zu den
anderen Piloten in diesem Ordnerverzeichnis (Tourismus, Verkehrsunfaelle).

- Quelle: GENESIS-Online (Destatis) Tabelle `12613-0012` "Gestorbene:
  Bundeslaender, Monate"
- DWD CDC-Station: Dresden-Klotzsche, Station `01048`
- Abgerufen 2026-09-17 ueber denselben oeffentlichen GENESIS-REST-Endpunkt
  wie der Verkehrsunfall-Pilot (kein Login/API-Key noetig)

## Vergleich

`prepare_pilot.R` erzeugt `pilot_baseline.csv` (Kalender- und
Sterbefall-Lags, ohne Wetter) und `pilot_weather.csv` (dieselben Merkmale
plus monatlich aggregierte DWD-Wetterwerte). Ziel ist `high`/`low` fuer die
Sterbefallzahl im Folgemonat. Schwelle nur auf dem Zeitraum vor
`2022-01-01` bestimmt, Split chronologisch.

`compare_pilot.R` vergleicht beide Varianten mit identischem Split/Seed/
Modell.

Ergebnis: Wetter schadet hier (BAcc -0,024, MCC -0,088) - siehe
[`docs/research/DWD_WEATHER_INTEGRATION.md`](../../docs/research/DWD_WEATHER_INTEGRATION.md)
fuer die vollstaendige Evidenz.
