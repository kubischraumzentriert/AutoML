# DWD-Wetterdaten im Classification-Template

## Ziel

Das Template soll Wetterdaten bei passenden Projekten optional als externe
Featurequelle nutzen koennen, ohne die Standardpipeline, Vergleichbarkeit
oder Reproduzierbarkeit zu gefaehrden. Die DWD-Daten werden deshalb vor dem
eigentlichen ML-Lauf lokal eingefroren; Cross-Validation ruft niemals live
eine externe Quelle ab.

## Quellenregister

### `rdwd`

`rdwd` ist die R-Komfortschicht fuer Auswahl, Download und Einlesen von DWD-
Stations- und Rasterdaten. Der Adapter nutzt es optional; die Datenhoheit
und Lizenzbedingungen kommen weiterhin vom DWD.

- Dokumentation: <https://brry.github.io/rdwd/index.html>
- Auswahl typischer Stationsdaten: `selectDWD()` und `dataDWD()`
- Raster/Radar-Unterstuetzung: ueber die entsprechenden DWD-CDC-Dateien
- Nicht in die Pflichtabhaengigkeiten aufnehmen

### DWD Climate Data Center: Stationsdaten

- Quelle: <https://opendata.dwd.de/climate_environment/CDC/observations_germany/>
- Aufloesungen reichen von Minuten- bis Tages-/Monatsdaten
- Geeignet, wenn ein Projekt Datum und eine belastbare Orts- oder Stationsnaehe
  besitzt
- Typische Featuregruppen: Temperatur, Niederschlag, Wind, Sonnenschein und
  weitere Stationsmessungen, abhaengig vom gewaehlten CDC-Produkt

### DWD Climate Data Center: Rasterdaten

- Quelle: <https://opendata.dwd.de/climate_environment/CDC/grids_germany/>
- Enthalten sind unter anderem Tages-/Stundenraster, Evaporation,
  Frosttiefe, Bodenfeuchte, Bodentemperatur und RADOLAN-Produkte
- Geeignet, wenn Projektkoordinaten vorhanden sind und Stationsdistanz zu
  gross oder die raeumliche Variation relevant ist
- Raster sind technisch aufwendiger und werden erst nach dem Stationspilot
  als eigener Umsetzungsschritt aktiviert

### Lizenz und Attribution

Die CDC-OpenData-Bedingungen nennen CC BY 4.0. Jeder gespeicherte Snapshot
muss Quelle, Abrufdatum, Produktpfad, Datenstand und Attribution mitfuehren:

<https://opendata.dwd.de/climate_environment/CDC/Terms_of_use.pdf>

## Adapter im Repository

`modules/dwd_weather_adapter.R` enthaelt bewusst keinen Downloader. Es stellt
stattdessen die sicherheitskritische Verarbeitung bereit:

- `dwd_weather_source_catalog()` dokumentiert die Quellen maschinenlesbar.
- `validate_dwd_weather_table()` verlangt eindeutige Station-/Datumsdaten.
- `select_nearest_dwd_station()` waehlt die naechste Station per Haversine-
  Distanz und protokolliert die Entfernung.
- `join_dwd_weather_asof()` fuehrt einen rueckblickenden Join aus und waehlt
  nie ein Wetterdatum nach dem Eventdatum.

Die erwartete lokale Normalform ist:

```text
station_id | date       | temperature | rainfall | wind
-----------+------------+-------------+----------+-----
DE...      | 2024-05-01 | ...         | ...      | ...
```

Die konkrete Spaltenumbenennung aus einem DWD-Produkt bleibt projektspezifisch
und muss vor dem Adapter als eigener, getesteter Import-Schritt erfolgen.

## Umsetzungsscheiben

### Scheibe 1: Stationspilot

- Ein deutsches Projekt mit Datum plus Koordinaten oder plausibler Orts-ID
  waehlen.
- Ein CDC-Tagesprodukt ueber `rdwd` beziehen.
- Rohdatei lokal unter einem projektspezifischen External-Data-Verzeichnis
  speichern; keine Live-Abfrage im CV.
- Stationen ueber Koordinaten zuordnen und Distanzgrenze festlegen.
- A/B-Vergleich: bestehende Features gegen bestehende Features plus DWD.

Akzeptanz: Matchrate, Distanzverteilung, fehlende Wetterwerte, Metrikdelta,
Laufzeit und Daten-/Git-Hashes sind dokumentiert.

#### Evidenz: OpenML/DWD-Klassifikationspilot (2026-09-17)

- Datensatz: OpenML `weather_and_campsite_germany` (DID 46263), gefiltert auf
  `land == "Brandenburg"`, lokal als
  `ML_Learning/openml-weather-campsite-dwd/source.arff`.
- DWD-Quelle: CDC-Tagesstation Potsdam (`03987`), lokal entpackt unter
  `ML_Learning/openml-weather-campsite-dwd/dwd_potsdam/`, monatlich
  aggregiert (Mittel/Summe je Monat).
- Ziel: `high`/`low`-Klasse der Uebernachtungszahl des Folgemonats.
  Schwelle = Median von `target_next_month` ausschliesslich auf dem
  Trainingszeitraum vor `2019-01-01` bestimmt (kein Blick auf den Testanteil).
- Split: chronologisch, kein Zufalls-Resampling. Train: Zeilen vor
  `2019-01-01` (200 Zeilen). Test: Zeilen ab `2019-01-01` (61 Zeilen).
- Matchrate Wetterjoin: 100 % (alle 261 Baseline-Zeilen erhalten einen
  monatlichen DWD-Aggregatwert; keine fehlenden Wetterwerte).
- Modell: `classif.ranger` (200 Baeume, `respect.unordered.factors =
  "order"`), Seed 42, identisch fuer Baseline und Wettervariante.
- Metrikdelta (Wetter minus Baseline): BAcc 0.8241 -> 0.8777 (+0.0536), MCC
  0.6882 -> 0.7767 (+0.0886). Beide Metriken verbessern sich unter identischem
  Split/Seed/Modell.
- Laufzeit: gesamter Vergleich (beide Varianten, Training + Vorhersage)
  ca. 3.4 s.
- Skripte: `ML_Learning/openml-weather-campsite-dwd/prepare_pilot.R`
  (Datenaufbereitung), `compare_pilot.R` (Vergleich). Ergebnis-CSV:
  `pilot_comparison_results.csv`.
- Git-Stand zum Pilotlauf: `af5a94b`.
- Einordnung: einzelner Pilot, ein Datensatz/eine Station. Reicht laut
  Scheibe 5 noch nicht fuer einen generischen Template-Backport (dafuer sind
  mindestens zwei unabhaengige Projekte mit stabiler Importstrecke noetig).

#### Erweiterung: zweiter Fall Bayern/Muenchen-Stadt (2026-09-17)

Kein zweites unabhaengiges Projekt im Sinne von Scheibe 5 (derselbe OpenML-
Datensatz, nur ein anderes Bundesland/eine andere Station) - dient hier als
Regionsrobustheitspruefung der Technik, nicht als zweiter Backport-Beleg.

- Datensatz: dieselbe OpenML-Quelle wie oben, gefiltert auf
  `land == "Bayern"`.
- DWD-Quelle: CDC-Tagesstation Muenchen-Stadt (`03379`), lokal entpackt unter
  `ML_Learning/openml-weather-campsite-dwd/dwd_muenchen/`, identische
  monatliche Aggregation wie beim Potsdam-Fall.
- Split/Modell: identischer chronologischer Split (`2019-01-01`), identischer
  Seed 42, identischer `classif.ranger`-Learner wie beim Brandenburg-Fall.
- Matchrate Wetterjoin: 100 % (265 Baseline-Zeilen, keine fehlenden
  Wetterwerte).
- Train/Test: 204/61 Zeilen (vs. 200/61 bei Brandenburg - Bayern hat 265 statt
  261 Rohzeilen).
- Metrikdelta (Wetter minus Baseline): BAcc 0.9491 -> 0.9313 (-0.0179), MCC
  0.9012 -> 0.8692 (-0.0320). Beide Metriken verschlechtern sich hier leicht -
  Gegenrichtung zum Brandenburg-Befund.
- Baseline-Niveau bereits sehr hoch (BAcc 0.949 ohne Wetter) - fuer Bayern
  bleibt wenig Verbesserungsspielraum, in den Wetterfeatures ueberhaupt
  eingreifen koennten.
- Laufzeit: beide Faelle zusammen (4 Modelltrainings) ca. 4 s.
- Skripte: dieselben `prepare_pilot.R`/`compare_pilot.R`, jetzt fuer beide
  Faelle parametrisiert. Ergebnis-CSVs: `pilot_comparison_results.csv`
  (Brandenburg), `pilot_comparison_results_bayern.csv` (Bayern),
  `pilot_comparison_results_all.csv` (beide).
- Git-Stand zum Erweiterungslauf: `5b76334`.
- Einordnung: gemischter Befund innerhalb derselben Datenquelle - Wetter hilft
  in einem Bundesland, schadet leicht in einem anderen. Staerkt die
  Notwendigkeit von Scheibe 2 (Leakage-Gates) und Scheibe 5 (echte
  unabhaengige Projekte) vor jeder generischen Regel; ein Automatismus "DWD
  immer anreichern" ist durch diesen Pilot nicht gedeckt.

### Scheibe 2: Zeit- und Leakage-Gates

- Eventdatum und Wetterdatum explizit definieren.
- Standard ist exakter Tagesjoin; Rueckblicke werden nur als bewusste
  `max_lag_days`-Features aktiviert.
- Zukuenftige Messungen, nachtraegliche Aggregationen und Informationen nach
  dem Vorhersagezeitpunkt werden ausgeschlossen.
- Train/Test- und Outer-Fold-Grenzen muessen vor dem Wetterjoin feststehen.

Akzeptanz: synthetische Zukunftsdatentests bleiben gruen; jede Wetterfeature-
Gruppe hat eine fachliche Verfuegbarkeitsbegruendung.

### Scheibe 3: Provenienz und Datenvertrag

- DWD-Produktpfad, Snapshot-Datum, Abrufdatum, Lizenz, Stationen/Raster,
  Join-Regel und Datenhash in der Run-Provenienz speichern.
- Importierte Rohdaten nicht still ueberschreiben; neuer Snapshot bekommt
  neuen Pfad oder Hash.
- Wetterfeatures mit `dwd_` praefigieren und vom Rohfeature-Set trennen.

Akzeptanz: ein Run kann spaeter eindeutig rekonstruieren, welche DWD-Datei
und welche Join-Parameter verwendet wurden.

### Scheibe 4: Rasterpilot

- Nur beginnen, wenn Stationsdaten einen konkreten Mehrwert oder zu grosse
  Entfernungen zeigen.
- Einen festen Rasterdatensatz und eine Interpolations-/Zellenregel waehlen.
- Speicherbedarf, Aufloesung und Randzellen explizit dokumentieren.

Akzeptanz: Raster- und Stationsvariante werden getrennt bewertet; kein
automatischer Wechsel auf Rasterdaten.

### Scheibe 5: Template-Backport

- Zuerst mindestens zwei unabhaengige Projekte mit stabiler Importstrecke.
- Positive, neutrale und negative Wetterbefunde dokumentieren.
- Erst danach entscheiden, ob ein generischer Hook in die Orchestrierung
  aufgenommen wird.

Bis dahin bleibt der Adapter optional und wird nicht in `_targets.R` oder die
nummerierte Standardreihenfolge eingebaut. Dadurch ist keine Aenderung am
Workflow-Diagramm erforderlich.

## Projekt-Gate: Wann Wetterdaten sinnvoll sind

Wetteranreicherung ist nur ein Kandidat, wenn mindestens folgende Bedingungen
erfuellt sind:

- Beobachtung oder Prediction hat ein belastbares Datum/Zeitfenster.
- Standort kann direkt, ueber Koordinaten oder ueber eine dokumentierte
  Ortszuordnung mit DWD verknuepft werden.
- Der fachliche Mechanismus ist plausibel, etwa Ertrag, Krankheit,
  Bewaesserung, Frostschaden oder Aktivitaet.
- Das Wetter war zum Vorhersagezeitpunkt verfuegbar.
- Genug zeitliche und raeumliche Abdeckung ist vorhanden.

Ohne Datum oder Ort ist DWD keine sinnvolle automatische Zweitquelle.
`agridatasets` bleibt in diesem Fall weiterhin eine Domain-Fixture, aber keine
Ersatzquelle fuer fehlende Projektmetadaten.

## Vorlaeufige Entscheidung

DWD CDC wird als bevorzugte reale Wetterquelle aufgenommen, `rdwd` als
optionaler R-Zugriff. Die erste Umsetzung ist der Stationspilot mit lokalen,
versionierten Tagesdaten. Raster- und Live-Anreicherungen bleiben getrennte
spaetere Schritte. Die Entscheidung fuer einen generischen Backport wird erst
nach stabiler Evidenz ueber unabhaengige Projekte getroffen.
