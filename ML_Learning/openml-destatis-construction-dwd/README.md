# Destatis/DWD Weather Enrichment Pilot: Baugewerblicher Umsatz

## Ziel

Prueft, ob DWD-Wetteranreicherung die Klassifikation des naechsten-Monats-
Umsatzes im Bauhauptgewerbe in Baden-Wuerttemberg verbessert. Mechanismus:
Aussenbaustellenarbeit ist direkt witterungsabhaengig (Frost/Schnee legen
Baustellen lahm). Unabhaengiges Projekt zu den anderen Piloten in diesem
Ordnerverzeichnis (Tourismus, Verkehrsunfaelle, Sterbefaelle).

- Quelle: GENESIS-Online (Destatis) Tabelle `44111-0003` "Geleistete
  Arbeitsstunden, Baugewerblicher Umsatz im Bauhauptgewerbe (alle
  Betriebe): Bundeslaender, Monate (bis 2016), Bauarten"
- DWD CDC-Station: Stuttgart-Schnarrenberg, Station `04928`
- Abgerufen 2026-09-17 ueber denselben oeffentlichen GENESIS-REST-Endpunkt
  wie die anderen Destatis-Piloten (kein Login/API-Key noetig)

**Datenbesonderheit:** Die regionale/monatliche Aufschluesselung dieser
Tabelle wurde nach 2016 eingestellt (Werte ab 2017 sind `0`, keine
Fehlwerte - eine eingestellte Zeitreihe, keine "kein Bau"-Beobachtung).
Der Pilot nutzt deshalb 1995-2016 statt des 2011-2025-Fensters der anderen
Piloten - weiterhin 22 volle Jahre Monatsdaten.

## Vergleich

`prepare_pilot.R` erzeugt `pilot_baseline.csv` (Kalender- und
Umsatz-Lags, ohne Wetter) und `pilot_weather.csv` (dieselben Merkmale plus
monatlich aggregierte DWD-Wetterwerte). Ziel ist `high`/`low` fuer den
Bauumsatz im Folgemonat. Schwelle nur auf dem Zeitraum vor `2011-01-01`
bestimmt, Split chronologisch.

`compare_pilot.R` vergleicht beide Varianten mit identischem Split/Seed/
Modell.

Ergebnis: Wetter schadet hier (BAcc -0,036, MCC -0,056) - siehe
[`docs/research/DWD_WEATHER_INTEGRATION.md`](../../docs/research/DWD_WEATHER_INTEGRATION.md)
fuer die vollstaendige Evidenz.
