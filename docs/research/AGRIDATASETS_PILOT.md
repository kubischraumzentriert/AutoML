# Optionaler `agridatasets`-Pilot

## Ergebnis

`agridatasets` 0.1.1 ist als optionale Agrardaten- und Benchmark-Quelle
brauchbar, aber nicht als allgemeine Wetterdatenquelle. Das Paket enthält
71 kuratierte Datensätze aus Landwirtschaft, Agronomie, Tierwissenschaft,
Boden und Pflanzenschutz. Viele Datensätze stammen ursprünglich aus anderen
R-Paketen und sind statische, dokumentierte Referenzdaten.

Der reproduzierbare Pilot verwendet `idn_rice_farms`:

- 1.026 Beobachtungen
- 20 Variablen
- fachliche Classification-Zielvariable `status`
- Standort-/Gruppeninformation `region`

Der Datensatz eignet sich damit als Domain-Fixture für Classification-Tests
und als Ausgangspunkt für fachliche Feature-Hypothesen. `rice_wheat_production`
ist dagegen eher eine Produktions-/Regressions-Fixture und kein direkter
Classification-Kandidat.

## Verwendung im Repository

Der optionale Adapter liegt in
`modules/agridatasets_adapter.R`. Er stellt drei Schutzregeln bereit:

1. Das Paket muss explizit installiert sein und mindestens Version 0.1.1
   haben.
2. Externe Anreicherung verlangt einen vollständigen, nicht fehlenden
   Join-Schlüssel.
3. Doppelte externe Schlüssel und Spaltenkollisionen werden abgebrochen;
   stille many-to-many-Joins sind nicht erlaubt.

Der Pilot kann mit einer temporär installierten oder regulär verwalteten
Paketumgebung ausgeführt werden:

```r
install.packages("agridatasets")
Rscript analysis/agridatasets_pilot.R
```

Das Paket ist absichtlich keine Pflichtabhängigkeit der Kernpipeline. Ein
Testlauf ohne Installation prüft weiterhin die Adapterlogik und überspringt
nur den echten Paketdaten-Test kontrolliert.

## Wetterdaten und Anreicherung

`agridatasets` enthält keine allgemeine, laufend aktualisierte Wetter-API.
Ein Wetter-Pilot braucht daher zusätzlich eine dedizierte Quelle mit
historischen Beobachtungen oder Reanalysewerten. Eine Anreicherung ist nur
zulässig, wenn mindestens ein belastbarer Orts-/Zeit-Schlüssel vorhanden ist
und die Information zum Vorhersagezeitpunkt verfügbar war.

Für jeden späteren A/B-Pilot werden mindestens dokumentiert:

- Primärdaten-Hash und externe Datenquelle inklusive Versionsstand
- räumlicher und zeitlicher Join, inklusive Zeitzone und Toleranzfenster
- As-of-Regel gegen Zukunftsinformation und Leakage
- Basismodell gegen Modell mit Zusatzfeatures
- Metrik, Seed, Laufzeit und Ergebnis pro Projekt

Ein einzelner positiver Pilot ist gemäß ADR-003 noch kein generischer
Backport-Beleg. Erst konsistente Befunde über unabhängige Projekte würden
eine allgemeine Workflow-Regel rechtfertigen.

## Entscheidung

`agridatasets` wird zunächst als optionale Domain-Fixture und Hypothesenquelle
beibehalten. Eine automatische Anreicherung aller Landwirtschaftsprojekte
wird nicht aktiviert. Für echte Wetteranreicherung folgt bei Bedarf ein
separater, versionierter Pilot mit einer dedizierten historischen Wetterquelle.
