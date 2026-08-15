# Referenz: DuckDB als lokaler Experiment-Mart

Diese Notiz beschreibt, wie DuckDB in diesem `mlr3`-AutoML-Template sinnvoll
eingesetzt werden kann: nicht als Ersatz fuer die bestehende
Experiment-Tracking-Datenbank (`experiments.db`), sondern als lokale
Analyse-Schicht fuer CSV-/Parquet-Artefakte und projektuebergreifende
Experimentauswertungen.

---

## 1. Kurzfazit

DuckDB passt sehr gut als **lokaler Experiment-Mart**:

- CSV-Artefakte in `_artifacts/` bleiben weiterhin die primaeren, einfachen
  Skriptoutputs.
- SQLite `experiments.db` bleibt die normalisierte Trial-/Run-Historie.
- DuckDB ergaenzt beides als schnelle analytische Schicht fuer breite Tabellen,
  viele CSVs, Parquet-Konvertierung, Ad-hoc-SQL und Dashboard-/Report-Vorarbeit.

DuckDB ist **nicht** als produktive OLTP-Datenbank fuer viele gleichzeitige
Schreibprozesse gedacht. Dafuer bleiben SQLite fuer lokale Projektlogs oder
PostgreSQL fuer produktive Systeme die bessere Wahl.

## 2. Motivation

Das Template erzeugt viele Artefakte:

- `baseline_results.csv`
- `feature_family_results.csv`
- `pipeline_results.csv`
- `ranger_tuning_search_results.csv`
- `lightgbm_tuning_search_results.csv`
- `ensemble_selection_results.csv`
- `generalization_gap_results.csv`
- `seed_stability_results.csv`
- weitere projektspezifische Diagnose- und Tuningtabellen

Diese Dateien sind gut fuer Nachvollziehbarkeit, aber weniger bequem fuer
Fragen wie:

- Welche Modellfamilie war ueber mehrere Skripte hinweg am stabilsten?
- Welche Featurefamilie verbessert LogLoss/Balanced Accuracy wirklich?
- Welche Tuninglaeufe waren teuer, aber wirkungslos?
- Welche Projekte zeigen dieselben Muster?
- Welche Ergebnisse liegen nur als CSV vor, aber noch nicht normalisiert in
  `experiments.db`?

DuckDB kann diese Dateien direkt mit SQL abfragen, ohne sie zuerst in R
vollstaendig als `data.table` oder `tibble` zu laden.

## 3. Rolle im Template

Empfohlene Aufgabenteilung:

| Ebene | Werkzeug | Zweck |
|---|---|---|
| Skriptoutputs | CSV/RDS in `_artifacts/` | einfache, transparente Artefakte je Skript |
| Trial-Historie | SQLite `experiments.db` | normalisierte Run-, Config- und Metrik-Historie |
| Analyse-Mart | DuckDB `experiment_mart.duckdb` | schnelle SQL-Analyse ueber viele Artefakte |
| Groessere Artefakte | Parquet | kompaktere, schnellere Alternative zu CSV |
| Produktive Transaktionen | PostgreSQL/SQLite | echte OLTP-/Mehrprozess-Schreibszenarien |

Wichtig: DuckDB soll die bestehenden CSVs nicht ersetzen. Die CSVs bleiben der
kleinste gemeinsame Nenner. DuckDB ist eine zusaetzliche Auswertungsschicht.

## 4. Vorgeschlagene Dateiorte

Pro Projekt:

```text
_artifacts/experiment_mart.duckdb
_artifacts/parquet/
```

Optional fuer projektuebergreifende Template-Auswertungen:

```text
_artifacts/template_experiment_mart.duckdb
```

Die DuckDB-Datei ist ein lokales Analyseartefakt. Sie sollte normalerweise nicht
in Git versioniert werden.

## 5. Minimaler Workflow

Direkte Abfrage einer CSV:

```sql
SELECT *
FROM read_csv_auto('_artifacts/feature_family_results.csv');
```

Dauerhaftes Laden in eine DuckDB-Tabelle:

```sql
CREATE OR REPLACE TABLE feature_family_results AS
SELECT *
FROM read_csv_auto('_artifacts/feature_family_results.csv');
```

Konvertierung nach Parquet:

```sql
COPY (
  SELECT *
  FROM read_csv_auto('_artifacts/feature_family_results.csv')
) TO '_artifacts/parquet/feature_family_results.parquet'
  (FORMAT PARQUET);
```

Abfrage mehrerer Parquet-Dateien:

```sql
SELECT *
FROM read_parquet('_artifacts/parquet/*.parquet');
```

## 6. Beispielabfragen

Beste Resultate ueber mehrere Ergebnisdateien koennen nach dem Import in
vereinheitlichte Tabellen abgefragt werden, zum Beispiel:

```sql
SELECT
  source_table,
  task_id,
  learner_id,
  metric,
  value
FROM experiment_metrics
WHERE metric IN ('classif.logloss', 'classif.bacc', 'classif.auc')
ORDER BY metric, value;
```

Teure Laeufe mit wenig Nutzen:

```sql
SELECT
  source_table,
  learner_id,
  elapsed_seconds,
  classif_logloss
FROM benchmark_results
WHERE elapsed_seconds > 30
ORDER BY classif_logloss DESC;
```

Featurefamilien vergleichen:

```sql
SELECT
  task_id,
  classif_logloss,
  classif_auc,
  elapsed_seconds
FROM feature_family_results
ORDER BY classif_logloss;
```

## 7. R-Integration

DuckDB kann aus R heraus als lokaler Analysehelfer genutzt werden:

```r
library(DBI)
library(duckdb)

con <- dbConnect(
  duckdb::duckdb(),
  dbdir = file.path("_artifacts", "experiment_mart.duckdb")
)

dbExecute(con, "
  CREATE OR REPLACE TABLE feature_family_results AS
  SELECT *
  FROM read_csv_auto('_artifacts/feature_family_results.csv')
")

dbGetQuery(con, "
  SELECT *
  FROM feature_family_results
  ORDER BY classif_logloss
  LIMIT 10
")

dbDisconnect(con, shutdown = TRUE)
```

Die R-Abhaengigkeit `duckdb` sollte optional bleiben. Das Kern-Template darf
nicht davon abhaengen, solange CSV und SQLite die stabilen Basiskomponenten
sind.

## 8. Python-Integration

Auch Python kann DuckDB als lokale Analyseebene nutzen:

```python
import duckdb

con = duckdb.connect("_artifacts/experiment_mart.duckdb")

con.sql("""
CREATE OR REPLACE TABLE feature_family_results AS
SELECT *
FROM read_csv_auto('_artifacts/feature_family_results.csv')
""")

print(con.sql("""
SELECT *
FROM feature_family_results
ORDER BY classif_logloss
LIMIT 10
""").df())
```

Das ist besonders nuetzlich fuer Python-basierte Submission- oder
Report-Helfer, ohne die R-Pipeline zu veraendern.

## 9. Abgrenzung zu `experiments.db`

`experiments.db` bleibt wichtig, weil es eine normalisierte Trial-Historie
erzwingt:

- Projekt
- Workflow
- Run
- Modellkonfiguration
- Hyperparameter
- Resampling
- Metriken
- Submission-Ergebnisse

DuckDB eignet sich besser fuer:

- schnelle, breite Ad-hoc-Auswertungen
- direkte CSV-/Parquet-Abfragen
- projektuebergreifende Artefakt-Marts
- Performance bei grossen Ergebnisdateien
- SQL-Reports ohne Import in R

Das heisst: **SQLite fuer Tracking, DuckDB fuer Analytics.**

## 10. Abgrenzung zu Traceability/MES

Im Traceability-Umfeld ist DuckDB ebenfalls interessant, aber in derselben
Rolle:

- lokale Analyse von Event-/Inbox-/Masterdata-Exports
- Plausibilitaetschecks auf CSV/Parquet/PostgreSQL-Exports
- schnelle Window-/ASOF-/Aggregationsabfragen
- Reporting, ohne produktive PostgreSQL- oder MES-Systeme zu belasten

Nicht geeignet ist DuckDB dort als zentrale produktive Schreibdatenbank fuer
viele parallele Prozesse. Traceability-OLTP bleibt ein Fall fuer PostgreSQL
oder ein anderes transaktionales System.

## 11. Risiken und Regeln

- DuckDB-Dateien nicht als neue Wahrheit behandeln. Wahrheit bleiben Skripte,
  CSV/RDS-Artefakte und `experiments.db`.
- Keine sensiblen oder wettbewerbsrechtlich geschuetzten Daten in Cloud-Dienste
  wie MotherDuck hochladen, wenn dies nicht ausdruecklich erlaubt ist.
- Keine Mehrprozess-Schreibannahmen treffen. DuckDB ist hervorragend fuer
  lokale analytische Nutzung, aber kein Ersatz fuer produktives OLTP.
- DuckDB-Imports muessen reproduzierbar sein: Tabelle immer aus bekannten
  Artefakten neu aufbaubar machen.
- Bei projektuebergreifenden Marts immer `project_name`, `source_file`,
  `source_script` und `created_at` mitschreiben.

## 12. Umsetzung (2026-08-15) - ERLEDIGT

[`170_build_duckdb_experiment_mart.R`](170_build_duckdb_experiment_mart.R)
setzt alle 5 Schritte um, bricht fruehzeitig mit einer klaren Meldung ab,
falls `duckdb` nicht installiert ist (kein Eingriff in die uebrige
Pipeline, kein `DESCRIPTION`-Eintrag noetig - Paket wird nur bei
tatsaechlicher Nutzung gebraucht).

**Schema-Erkennung statt Dateiname-Liste**: Schritt 3 (normalisierte View)
erkennt die Benchmark-Familie ueber das SPALTENMUSTER (`task_id`/
`learner_id`/`resampling_id` + mindestens eine `classif.*`-Spalte), nicht
ueber eine hartcodierte Dateiliste - neue Benchmark-Skripte mit demselben
Schema landen automatisch in `experiment_metrics`, ohne dieses Skript
anzufassen. Tabellen mit abweichendem Schema (Diagnose-Module wie
`generalization_gap_results`/`seed_stability_results`/...) bleiben als
eigene Rohtabellen bestehen, fliessen aber bewusst NICHT in die
Langformat-View ein (strukturell zu unterschiedlich ohne Informations-
verlust in ein gemeinsames `metric`/`value`-Format zu pressen).

**Regressionsgetestet gegen das Template-eigene Projekt**
(`health_condition`, 36 real vorhandene `_results.csv`-Dateien - der
groesste real verfuegbare Bestand): 22 Tabellen ins gemeinsame
Benchmark-Schema erkannt, 14 korrekt als eigenstaendige Rohtabellen
belassen, 36 Parquet-Dateien gespiegelt. **Der Report fand sofort einen
echten, bisher unbemerkten Befund**: ein Ranger-Lauf
(`selected_cv_results`) brauchte 7706 Sekunden (~128 Minuten), landete
aber nur auf **Rang 59 von 60+** nach BAcc (0.857) - ein teurer, aber
wirkungsloser Lauf, genau die Art Erkenntnis, fuer die dieses Werkzeug
gedacht ist. (Noch nicht weiter untersucht, warum dieser spezielle Lauf so
lange brauchte - eigener Punkt, falls relevant.)

## 13. Quellen und Einordnung

- *DuckDB in Action* beschreibt DuckDB als embedded analytische Datenbank fuer
  lokale SQL-Analysen, CSV/JSON/Parquet, Python-Integration, Datenpipelines und
  Performance auf groesseren Datensaetzen.
- Die DuckDB-Dokumentation betont direkte Abfragen von CSV/Parquet, Python-/R-
  Integration und die analytische, in-process Architektur.
- Fuer dieses Template folgt daraus: DuckDB ist ein sehr guter Analyse-Mart,
  aber kein Ersatz fuer die bestehende Experiment-DB und kein produktives
  Transaktionssystem.
