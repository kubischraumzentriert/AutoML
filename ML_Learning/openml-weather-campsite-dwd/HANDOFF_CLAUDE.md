# Uebergabe an Claude: OpenML/DWD-Klassifikationspilot

Stand: 2026-09-17

## Nutzerziel

Ein kleines OpenML-Klassifikationsprojekt nach dem AutoML-Workflow ausfuehren
und pruefen, ob die Anreicherung mit externen DWD-Wetterdaten die Ergebnisse
verbessert. Wegen knappem Nutzungskontingent wurde die Arbeit hier bewusst
nach der Vorbereitung angehalten.

## Bereits erledigt

- OpenML-Datensatz `weather_and_campsite_germany`, DID `46263`, lokal abgelegt
  als `source.arff`.
- DWD-CDC-Potsdam-Station `03987` lokal geladen und entpackt unter
  `dwd_potsdam/`.
- `prepare_pilot.R` angelegt.
- `README.md` mit Datenquellen, Vergleich und Leakage-Regeln angelegt.
- Der erste R-Lauf scheiterte nur an `sys.frame(1)$ofile` bei direktem
  `Rscript`-Aufruf. Das Skript wurde danach auf den `--file`-Pfad umgestellt.

## Noch offen

1. Vorbereitung erneut ausfuehren:

   ```powershell
   & 'C:\Program Files\R\R-4.5.3\bin\Rscript.exe' `
     'ML_Learning/openml-weather-campsite-dwd/prepare_pilot.R'
   ```

2. Erzeugen der erwarteten Dateien pruefen:
   - `pilot_baseline.csv`
   - `pilot_weather.csv`
   - `pilot_manifest.csv`

3. Beide Tabellen mit identischen chronologischen Splits und identischem Seed
   klassifizieren. Kein zufaelliges Resampling verwenden: Ziel ist die
   Uebernachtungs-Klasse des Folgemonats.

4. Die bereits vorhandenen Root-Workflow-Skripte nur gezielt uebertragen oder
   aufrufen. Vor einem langen Lauf Laufzeit abschaetzen und bevorzugt zuerst
   einen kleinen Smoke-Test ausfuehren.

5. Ergebnis als Evidenzzeile dokumentieren: Datensatz, Features, Metrik,
   Split, Laufzeit, Baseline, Wettervariante, Differenz, Trust-/Leak-Befunde.

6. Erst nach erfolgreichem Vergleich separat committen und danach separat
   pushen. Die Nutzeranweisung zum Commit/Push liegt fuer diesen neuen Pilot
   noch nicht vor.

## Methodische Regeln

- Die bereits im OpenML-Datensatz enthaltenen Wetterspalten duerfen nicht in
  die Baseline gelangen.
- Wetterdaten werden monatlich aus der DWD-Tagesstation aggregiert.
- Nur Wetterdaten der passenden Periode bzw. vor dem Vorhersagezeitpunkt
  verwenden; keine Zukunftswerte.
- Keine Live-DWD-Abfrage innerhalb von CV/Resampling. Den lokalen Snapshot und
  seine Quelle/Version dokumentieren.
- Der Pilot ist bewusst auf Brandenburg/Potsdam beschraenkt, weil der
  Datensatz nur Bundesland, aber keine exakten Feldkoordinaten besitzt.

## Git-Stand

Vor dieser Arbeit waren bereits folgende DWD-Aenderungen uncommitted:

- `BACKLOG.md`
- `docs/research/DWD_WEATHER_INTEGRATION.md`
- `modules/dwd_weather_adapter.R`
- `tests/testthat/test-dwd_weather_adapter.R`

Zusaetzlich neu fuer diesen Pilot:

- `ML_Learning/openml-weather-campsite-dwd/source.arff`
- `ML_Learning/openml-weather-campsite-dwd/dwd_potsdam/`
- `ML_Learning/openml-weather-campsite-dwd/prepare_pilot.R`
- `ML_Learning/openml-weather-campsite-dwd/README.md`
- diese Uebergabe-Datei

Vor Staging unbedingt `git status --short` pruefen und keine fremden oder
unbekannten Aenderungen zuruecksetzen.
