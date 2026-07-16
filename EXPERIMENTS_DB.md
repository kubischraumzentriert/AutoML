# Anleitung: Experiment-Tracking-Datenbank (`experiments.db`)

Diese Datei erklärt Aufbau und Konzept der SQLite-Datenbank, in die alle
explorativen Skripte (`030`-`147`) ihre Ergebnisse schreiben. Für die
inhaltlichen Ergebnisse (welches Modell, welche Klassengewichtung) siehe
`README.md` - hier geht es nur um das *Werkzeug*: Schema, Konventionen,
Logging-Code und wie man die Datenbank abfragt.

## Warum ueberhaupt eine Datenbank

Jedes Skript druckt seine Ergebnisse auf die Konsole und schreibt sie
zusaetzlich als CSV nach `_artifacts/`. Beides hat Grenzen:

- Die Konsolenausgabe ist aggregiert (Mittelwert ueber alle CV-Folds) - die
  Streuung zwischen Folds geht verloren.
- Jede CSV hat ihre eigene Spaltenstruktur (`105` hat eine `weight_power`-
  Spalte, `090` hat `mtry.ratio`/`min.node.size`/..., `130` hat
  `bacc_plain`/`bacc_tuned`/...) - Ergebnisse aus verschiedenen Skripten
  lassen sich nicht direkt gegeneinander abfragen, ohne jede CSV-Struktur
  einzeln zu kennen.
- Es gibt keinen Ort, an dem "was haben wir mit LightGBM insgesamt schon
  alles getestet, ueber alle Skripte hinweg" in einer Abfrage beantwortet
  werden kann.

Die Datenbank loest das, indem sie ein **gemeinsames, normalisiertes Schema**
fuer "welche Konfiguration wurde getestet, mit welchem Ergebnis" definiert,
unabhaengig davon, welches Skript sie erzeugt hat. Ziel ist explizit auch,
dass eine KI (Claude) in einer *spaeteren* Session direkt per SQL nachsehen
kann, was frueher schon probiert wurde, statt sich nur auf README-Prosa oder
Skript-Wiederausfuehrung verlassen zu muessen.

## Grundkonzept

- **Projekt** (`project`): ein Kaggle-Wettbewerb / eine Aufgabe (hier:
  `playground-series-s6e7-health-condition`). Der `proj_name` ist der einzige
  Bezug zu diesem konkreten Datensatz im ganzen Schema.
- **Workflow** (`workflow`): eine Ausfuehrungseinheit innerhalb eines
  Projekts - im Alltag ein einzelnes nummeriertes Skript (`wf_type =
  'script'`, `wf_name = "105_lightgbm_class_weights.R"`). Das Schema
  unterstuetzt auch `wf_type = 'targets'` fuer eine `_targets.R`-Pipeline,
  das wird aktuell aber nicht genutzt (siehe "Bekannte Einschraenkung").
- **Run** (`run`): ein einzelner Aufruf eines Workflows (ein `Rscript
  030_baseline.R` z.B.) - mit Zeitstempel, Seed und Git-Commit, damit
  spaeter nachvollziehbar ist, mit welchem Codestand ein Ergebnis erzeugt
  wurde. Ein Skript kann mehrfach ausgefuehrt werden (z.B. nach einer
  Config-Aenderung) - jeder Aufruf ist ein eigener Run, alte Runs bleiben
  erhalten statt ueberschrieben zu werden.
- **Model-Config** (`model_config`): eine konkrete getestete Kombination aus
  Algorithmus, Feature-Set, Preprocessing und Klassengewicht - das
  Herzstueck des Schemas. Ein Run erzeugt typischerweise mehrere
  Model-Configs (z.B. eine je Learner in einem Benchmark, oder eine je
  Parameter-Kombination in einer Tuning-Suche).
- **Hyperparameter** (`hyperparam`): beliebige Key-Value-Paare zu einer
  Model-Config (z.B. `num_iterations = 200`). Als Key-Value statt fester
  Spalten modelliert, damit ein neues Modell mit voellig anderen
  Hyperparametern keine Schema-Aenderung braucht.
- **Resampling** (`resampling`): die Validierungsstrategie (`cv`/`holdout`/
  `custom_split`) fuer eine Gruppe von Model-Configs innerhalb eines Runs.
- **Metric-Result** (`metric_result`): ein einzelner Messwert (`classif.bacc`,
  `classif.mcc`, `classif.auc`, ...) fuer eine Model-Config unter einer
  Resampling-Strategie - **sowohl aggregiert als auch pro Fold** (siehe
  unten).
- **Submission-Result** (`submission_result`): ein externer Leaderboard-Score
  zu einem finalen Modell, getrennt nach Public und Private Score. So bleibt
  nachvollziehbar, welche Submission mit welchem Modell erzeugt wurde.

## Namenskonvention

Uebernommen aus einem MES-Traceability-Referenzprojekt (Postgres-DDL), an
SQLite angepasst. Jede Tabelle hat ein kurzes Praefix (`proj`, `wf`, `run`,
`rconf`, `mconf`, `hparam`, `rsmp`, `mres`, `subm`); alle Spalten der Tabelle tragen
dieses Praefix, z.B. `mconf_algorithm`, `mconf_task_id`.

| Spaltenmuster | Bedeutung | SQLite-Umsetzung |
|---|---|---|
| `<praefix>_seq` | Fortlaufende Nummer | `INTEGER PRIMARY KEY` (Alias auf `rowid`, autoincrement bei `NULL`-Insert) |
| `<praefix>_id` | Fachlicher, stabiler Schluessel | `TEXT NOT NULL UNIQUE`, eine UUID (Paket `uuid` in R, da SQLite kein natives `uuid_generate_v4()` hat) |
| `<praefix>_created_at`/`_started_at`/... | Zeitstempel | `TEXT` (ISO8601 ueber `datetime('now')`, SQLite hat keinen nativen Timestamp-Typ) |

Fremdschluessel referenzieren immer den `_id` (UUID), nie den `_seq`
(Autoincrement) - der `_seq` existiert nur, weil SQLite ohne einen
`INTEGER PRIMARY KEY` keinen echten `rowid`-Alias anlegt, nicht als
fachlicher Bezug.

**Bewusste Ausnahme**: `prediction`/`prediction_prob` (siehe unten) haben
**keine** `_id`-UUID, nur `_seq`. Bei potenziell tausenden Zeilen pro Lauf
waere eine UUID pro Zeile reiner Speicher-/Join-Overhead, ohne dass irgendwo
ausserhalb der Datenbank auf eine einzelne Vorhersage per fachlichem
Schluessel verwiesen werden muesste - der SQLite-`rowid` (`pred_seq`) reicht
als Fremdschluessel fuer `prediction_prob`.

## ER-Diagramm

```
project (1)───<(n) workflow (1)───<(n) run (1)───<(n) run_config
                                          │
                                          ├──<(n) resampling ──<(n) metric_result
                                          │         │                 │
                                          │         └──<(n) prediction ┤
                                          │                    │       │
                                          └──<(n) model_config─┴──<(n)─┤
                                                     │                │
                                                     └──<(n) hyperparam

prediction (1)───<(n) prediction_prob   [ueber pred_seq, keine UUID]
```

`metric_result` haengt an **beiden** Elternteilen (`model_config` UND
`resampling`), weil ein Messwert immer die Kombination "welche Konfiguration,
unter welcher Validierungsstrategie" ist - dieselbe Model-Config koennte
theoretisch unter verschiedenen Resampling-Strategien gemessen werden (kommt
aktuell in den Skripten nicht vor, ist aber durch das Schema abgedeckt, z.B.
falls man dieselbe Konfiguration einmal per Holdout und einmal per CV
pruefen wollte). `prediction` haengt aus demselben Grund ebenfalls an beiden.

## Tabellen im Detail (`db_schema.sql`)

### `project`

Ein Eintrag pro Kaggle-Wettbewerb/Aufgabe. `proj_name` ist `UNIQUE` und
dient als der eigentliche Bezugspunkt (`db_get_or_create_project()` legt
nur an, wenn der Name noch nicht existiert - wiederholte Aufrufe sind
idempotent).

### `workflow`

Ein Eintrag pro Skript/Pipeline innerhalb eines Projekts. `UNIQUE
(wf_proj_id, wf_type, wf_name)` sorgt dafuer, dass z.B.
`"105_lightgbm_class_weights.R"` innerhalb eines Projekts nur einmal als
Workflow existiert, auch wenn das Skript zehnmal laeuft - jeder Lauf wird
stattdessen ein neuer `run`-Eintrag.

### `run`

Ein Eintrag pro Skriptausfuehrung: `run_seed` (der in `000_config.R`
gesetzte globale Seed), `run_git_commit` (per `git rev-parse HEAD` zum
Zeitpunkt des Laufs - `get_git_commit()` in `db_logging.R`), `run_notes`
(Freitext, was das Skript inhaltlich testet), `run_started_at`/
`run_finished_at` (Start automatisch bei `db_create_run()`, Ende explizit
per `db_finish_run()` am Skriptende - ein Run ohne `run_finished_at` bedeutet
also, dass das Skript abgebrochen ist, bevor es fertig geloggt hat).

### `run_config`

Skriptweite Konfigurationswerte als Key-Value (z.B. `cv_folds = 5`,
`class_weight_power = 1.5`). Bewusst nicht als feste Spalten modelliert,
weil jedes Skript andere relevante Config-Werte hat (siehe `hyperparam` fuer
dieselbe Ueberlegung auf Modellebene).

### `model_config`

Die zentrale Tabelle - eine Zeile pro getesteter Konfiguration:

| Spalte | Bedeutung |
|---|---|
| `mconf_task_type` | `"classif"` (aktuell immer, da alle Skripte Klassifikation sind - fuer eine Regressionsaufgabe waere das der Unterscheidungspunkt) |
| `mconf_algorithm` | Kurzname des Learners (`"ranger"`, `"lightgbm"`, `"catboost"`, ...) - siehe `algorithm_from_learner_id()` unten |
| `mconf_feature_set` | `"raw"`/`"features"`/`"selected"` oder ein Familienname (`"bmi"`, `"cardio"`, ...) - siehe `feature_set_from_task_id()` unten |
| `mconf_preprocessing` | Freitext-Label fuer die Preprocessing-Pipeline (`"impute_median_mode"`, `"empty_to_na_onehot"`, `"none"`, ...) - getrennt von `feature_set` (welche Spalten) und `algorithm` (welcher Learner) |
| `mconf_class_weight_power` | Der `power`-Exponent aus `add_balanced_class_weights()`, `NA` wenn ungewichtet |
| `mconf_task_id` | Die `mlr3`-Task-`id` (z.B. `"health_condition_10pct_weighted_p1.5"`) - der Rohbezug, aus dem `feature_set`/`class_weight_power` oft erst abgeleitet werden |

### `hyperparam`

Key-Value-Paare zu einer `model_config` (z.B. `num_iterations = 200`,
`mtry.ratio = 0.377`). Ein neues Modell mit komplett anderen Parametern
braucht keine Schema-Aenderung, nur passende Eintraege beim Logging.

**Zweckentfremdung fuer Datei-Pfade**: `150_train_full_model.R` loggt hier
zusaetzlich einen `model_artifact_path`-Eintrag - den Pfad der gespeicherten
`.rds`-Modell-Datei fuer genau diesen Lauf. Grund: `final_model_full_path()`
(`000_config.R`) haengt die `run_id` an den Dateinamen (z.B.
`final_model_ranger_full_<run_id>.rds`), damit ein neuer Trainingslauf die
vorherige Modell-Datei nicht kommentarlos ueberschreibt - vorher gab es
dafuer keine Versionierung, jeder Lauf ueberschrieb denselben fixen Namen.
`db_get_latest_model_artifact_path(con, algorithm)` (`db_logging.R`) holt den
zur neuesten `run_id` passenden Pfad zurueck (siehe `155_predict_submission.R`).
Kein Schema-Bruch: `hyperparam` ist bewusst eine generische Key-Value-Tabelle,
"beliebige" Werte sind ihr dokumentierter Zweck.

### `resampling`

Eine Validierungsstrategie: `rsmp_strategy` (`'cv'`/`'holdout'`/
`'custom_split'`, per `CHECK`-Constraint erzwungen), plus `rsmp_folds`
(bei `cv`), `rsmp_ratio` (bei `holdout`/`custom_split`), `rsmp_seed`.
`custom_split` deckt Faelle wie `130_threshold_tuning.R` ab (stratifizierter
Train/Tune/Eval-Split, weder reines CV noch reines Holdout).

### `metric_result`

Ein Messwert: `mres_measure_name` (`"classif.bacc"`, `"classif.mcc"`,
`"classif.auc"`), `mres_value`, `mres_elapsed_seconds`. **`mres_fold`** ist
der Schluessel zum Pro-Fold-vs-Aggregat-Unterschied:

- `mres_fold IS NULL` → aggregierter Wert (Mittelwert ueber alle Folds bzw.
  der einzelne Holdout-Wert) - das, was auch in der Konsole/CSV auftaucht.
- `mres_fold = 1, 2, 3, ...` → der Wert eines einzelnen CV-Folds.

Beide Varianten werden fuer dieselbe `model_config`/`resampling`-Kombination
gespeichert (siehe `db_log_benchmark_metrics()` unten), damit sowohl "was
war der Durchschnitt" als auch "wie stark hat es zwischen Folds gestreut"
abfragbar ist, ohne die Rohwerte aus mlr3 erneut berechnen zu muessen.

### `submission_result`

Externe Ergebnisse einer erzeugten Submission, etwa vom Kaggle-Leaderboard.
Die Tabelle referenziert die konkrete finale `model_config`, nicht einen
Resampling-Lauf: `subm_public_score` ist das Zwischenfeedback waehrend eines
Wettbewerbs, `subm_private_score` der nach Wettbewerbsschluss entscheidende
Score. `subm_status` unterscheidet normale Einreichungen (`submitted`) von
Late Submissions (`late_submission`).

`db_log_submission_result()` legt den Eintrag an oder aktualisiert ihn bei
einem erneuten Aufruf fuer dieselbe Modell-/Plattform-/Status-Kombination.
Die Modellreferenz liefert `db_get_latest_model_config_id(con, algorithm)`.

### `prediction` / `prediction_prob`

Zeilenebene fuer *einzelne* Vorhersagen: `pred_row_id` (die mlr3-`row_id`
innerhalb des Tasks aus `mconf_task_id`), `pred_truth`, `pred_response`,
`pred_fold` (wie `mres_fold`: `NULL` bei Holdout/Custom-Split). Die
Wahrscheinlichkeitsverteilung liegt in einer eigenen EAV-Tabelle
(`prediction_prob`: `pprob_class`, `pprob_value`), damit die Klassenzahl
projektunabhaengig bleibt - ein Projekt mit 10 Klassen braucht keine
Schema-Aenderung.

**Wichtig**: Diese Tabellen werden **nicht** routinemaessig fuer jede
`model_config` befuellt - bei CV ueber alle Zeilen x alle Konfigurationen
waere das schnell im zweistelligen Millionenbereich. Stattdessen entscheidet
das aufrufende Skript, welche Zeilen geloggt werden (`db_log_predictions()`
filtert selbst nicht) - i.d.R. nur der eine Holdout-Split in `147_error_analysis_ranger.R`,
nicht jede Benchmark-/Tuning-Config.

Seit 2026-07-15 loggt `147_error_analysis_ranger.R` fuer Ranger/LightGBM/LDA
**alle** Eval-Zeilen (nicht mehr nur die falsch klassifizierten/unsicheren) -
das macht `prediction`/`prediction_prob` gross genug fuer eine echte ROC-/
PR-Kurve (siehe `008_curve_diagnostics.R`/`160`/`161`), waere eine reine
Teilmenge dafuer systematisch verzerrt (die einfachen, hochkonfidenten
richtigen Vorhersagen fehlten). TabPFN bleibt bei der gefilterten Teilmenge
(nur "interessante" Zeilen, falsch klassifiziert **oder** Konfidenz unter
`error_analysis_uncertainty_threshold` aus `000_config.R`) - es wird ohnehin
nur auf dieser Teilmenge ausgewertet (CPU-Kontextlimit, siehe `095_tabpfn_benchmark.R`).

## Views (ebenfalls in `db_schema.sql`)

**Hinweis zur Aktualisierung**: Views werden per `DROP VIEW IF EXISTS` +
`CREATE VIEW` definiert (nicht `CREATE VIEW IF NOT EXISTS`), damit eine
geaenderte View-Definition in einer bereits existierenden DB beim naechsten
`db_connect()` tatsaechlich greift. Views halten keine Daten - das
Neuanlegen bei jedem Connect ist gefahrlos. (Tabellen behalten
`CREATE TABLE IF NOT EXISTS` - die duerfen nicht gedroppt werden.)

**Metrik-Abdeckung**: Die Pivot-Views (`v_model_results`, `v_run_summary`)
und `v_best_per_algorithm` waren urspruenglich auf BAcc/MCC zugeschnitten.
Fuer Projekte mit anderer Primaermetrik (AUC bei `playground-series-s6e5`/
`s5e12`, LogLoss bei `openml-adult-income`) blieben deren Ergebnisse
unsichtbar. Behoben (2026-07-16): Pivot-Views um AUC/LogLoss/PRAUC ergaenzt,
plus zwei generische Langformat-Views (`v_metric_results`,
`v_best_per_algorithm_metric`), die JEDE geloggte Metrik ohne Schemaaenderung
abbilden.

### `v_metric_results` (generisch, Langformat)

Eine Zeile je (`model_config`, Metrik) fuer die aggregierten Werte
(`mres_fold IS NULL`), mit vollem Modellkontext und Hyperparametern. Die
richtige Anlaufstelle fuer eine Metrik, die die Pivot-Views unten nicht als
benannte Spalte fuehren - hier taucht jede geloggte Metrik als Zeile auf
(`mres_measure_name`/`mres_value`), unabhaengig vom Projekt.

### `v_model_results`

Eine Zeile je `model_config` mit den gaengigen Metriken nebeneinander
herauspivotet (aus den `mres_fold IS NULL`-Zeilen per `MAX(CASE WHEN ...)`),
Resampling-Info und allen Hyperparametern als ein zusammengefasster Text
(`GROUP_CONCAT(hparam_name || '=' || hparam_value, ', ')`). Deckt jetzt
`bacc`, `mcc`, `auc`, `logloss`, `prauc` als Spalten ab (`NA`, wenn die
Metrik fuer die Zeile nicht geloggt wurde). Der normalisierte Ersatz fuer die
bisherigen CSV-Exporte - eine Zeile pro getesteter Konfiguration, unabhaengig
davon, aus welchem Skript sie stammt. Fuer eine hier nicht gelistete Metrik:
`v_metric_results`.

### `v_fold_detail`

Alle Pro-Fold-Werte (`mres_fold IS NOT NULL`) mit Algorithmus/Feature-Set/
Gewichtung als Kontext - fuer Streuungs-/Stabilitaetsanalysen zwischen
Folds (z.B. "war der BAcc-Vorteil von Ranger stabil ueber alle 5 Folds, oder
kommt er nur von einem guenstigen Fold?").

### `v_run_summary`

Ein Rollup je Run: Anzahl getesteter Model-Configs, bester Wert je gaengiger
Metrik. Richtungsabhaengig: `best_bacc`/`best_mcc`/`best_auc` sind `MAX`
(hoeher=besser), `best_logloss` ist `MIN` (niedriger=besser). Schneller
Ueberblick "was kam bei diesem Skriptlauf im Wesentlichen heraus", ohne
einzelne Model-Configs durchzugehen.

### `v_prediction_detail`

Eine Zeile je geloggter Einzelvorhersage, mit Modellkontext (`mconf_algorithm`,
`mconf_class_weight_power`) und den beiden meistgebrauchten Wahrscheinlich-
keiten schon herausgepivotet: `response_prob` (Konfidenz in die eigene
Vorhersage) und `truth_prob` (Wahrscheinlichkeit, die dem tatsaechlichen
Label gegeben wurde) - erspart den manuellen Join gegen `prediction_prob`
fuer den Standardfall. Zwei `v_prediction_detail`-Ergebnisse lassen sich
ueber `pred_row_id` gegeneinander joinen, um zwei Modelle auf denselben
Zeilen zu vergleichen (siehe Beispielabfragen).

### `v_best_per_algorithm`

Die aktuell beste (hoechste BAcc) Konfiguration je Algorithmus, ueber alle
Runs/Skripte/Projekte hinweg - per `ROW_NUMBER() OVER (PARTITION BY
mconf_algorithm ORDER BY bacc DESC)`. Direkte Antwort auf "was ist gerade
unser bestes Ranger-Ergebnis, unser bestes LightGBM-Ergebnis, etc."
Beibehalten fuer den BAcc-Standardfall/Rueckwaertskompatibilitaet - fuer eine
andere Metrik siehe `v_best_per_algorithm_metric`.

### `v_best_per_algorithm_metric` (generisch, richtungsabhaengig)

Die beste Konfiguration je (`proj_name`, `mconf_algorithm`,
`mres_measure_name`) - der generische Ersatz fuer `v_best_per_algorithm`.
Sortiert richtungsabhaengig: Fehlermetriken (LogLoss, CE, Brier) niedriger=
besser, alle anderen hoeher=besser (per `CASE` in der `ORDER BY`-Klausel
kodiert). Funktioniert fuer jede geloggte Metrik ohne Schemaaenderung.
Zusaetzlich nach Projekt partitioniert, damit dieselbe Metrik ueber mehrere
Projekte hinweg nicht vermischt wird.

## Logging-Code (`db_logging.R`)

`db_connect(db_path = experiments_db_path)` oeffnet (und legt bei Bedarf an)
die Datenbank: liest `db_schema.sql`, splittet es an `;` und fuehrt jedes
Statement einzeln aus. Da alle `CREATE TABLE`/`CREATE INDEX`/`CREATE VIEW`
Anweisungen `IF NOT EXISTS` verwenden, ist das idempotent - jeder Skriptlauf
kann `db_connect()` unbesorgt aufrufen, auch wenn das Schema schon existiert.

Jedes der Skripte `030`-`145` haengt am Ende einen Block nach demselben
Muster an:

```r
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "105_lightgbm_class_weights.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = "...")
db_log_run_config(db_con, db_run_id, list(cv_folds = cv_folds, ...))

# ... Modelle/Konfigurationen loggen (siehe unten) ...

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
```

Fuer das eigentliche Modell-/Ergebnis-Logging gibt es zwei Ebenen:

**1. Der Normalfall — `db_log_timed_benchmark()`:** Fast alle Skripte rufen
`run_timed_benchmark()` (`005_benchmark_runtime.R`) auf, das ein
`mlr3::BenchmarkResult` fuer mehrere Task/Learner-Kombinationen erzeugt.
`db_log_timed_benchmark()` nimmt dieses Ergebnis, legt **ein** `resampling`
fuer alle Zeilen an (dieselbe Strategie gilt ueblicherweise fuer den ganzen
Benchmark-Aufruf) und ruft je Ergebniszeile eine vom Skript uebergebene
Funktion `model_config_fn(row)` auf, die aus der Zeile (Task-ID, Learner-ID)
die Metadaten ableitet:

```r
model_config_fn = function(row) list(
  task_type = "classif",
  algorithm = algorithm_from_learner_id(row$learner_id[1]),
  feature_set = feature_set_from_task_id(row$task_id[1]),
  preprocessing = "impute_median_mode",
  class_weight_power = class_weight_power,
  task_id = row$task_id[1],
  hyperparams = list(num_iterations = lightgbm_tuning_final_iterations)
)
```

`db_log_timed_benchmark()` legt daraus `model_config`+`hyperparam` an und
ruft `db_log_benchmark_metrics()` auf, die sowohl den aggregierten Wert
(aus `timed_benchmark$results`) als auch alle Pro-Fold-Werte (aus
`timed_benchmark$scores`, gefiltert auf dieselbe Task-/Learner-Kombination)
loggt.

`algorithm_from_learner_id()` und `feature_set_from_task_id()`
(`000_config.R`) sind reine String-Heuristiken auf mlr3-IDs:

- `algorithm_from_learner_id("classif.lightgbm")` → `"lightgbm"` (Praefix
  `classif.` abgeschnitten); bei benutzerdefinierten IDs ohne dieses Praefix
  (z.B. `"ranger_tuned"`, `"lightgbm_keep_empty"`) wird das letzte
  Punkt-getrennte Segment genommen bzw. die ID unveraendert zurueckgegeben,
  wenn sie keine Punkte enthaelt.
- `feature_set_from_task_id("health_condition_10pct_bmi_weighted_p1.5")` →
  `"bmi"` (Gewichtungs-Suffix `_weighted_p...` zuerst abgeschnitten, dann der
  bekannte Task-Namens-Praefix entfernt).

**2. Sonderfaelle — direkte Bausteine:** Skripte mit einer eigenen
Such-/Tuning-Schleife (`090`, `100`, `142`, per `mlr3tuning`/`mlr3mbo`) oder
einem komplett eigenen Aufbau ohne `BenchmarkResult` (`115` mit einem
einzelnen `msr("classif.auc")`, `130` mit einem manuellen Train/Tune/Eval-
Split) rufen `db_create_model_config()`/`db_create_resampling()`/
`db_log_metric_result()` direkt auf, statt `db_log_timed_benchmark()` zu
nutzen - z.B. loggt `090_ranger_tuning.R` jede der 20 Random-Search-
Evaluationen als eigene `model_config` unter einem gemeinsamen
`holdout`-`resampling`, bevor die finale CV-Vergleichsphase wieder ueber
`db_log_timed_benchmark()` laeuft.

**3. Zeilenebene — `db_log_predictions()`:** Nur von `147_error_analysis_ranger.R`
genutzt. Nimmt `row_ids`/`truth`/`response`/eine Wahrscheinlichkeits-Matrix
(eine Spalte je Klasse) entgegen und schreibt sie in `prediction`/
`prediction_prob`. Filtert selbst nicht - der Aufrufer uebergibt bereits nur
die Zeilen, die geloggt werden sollen (siehe Tabelle `prediction` oben).
Vergibt `pred_seq` manuell in einer Transaktion (`dbBegin()`/`dbCommit()`),
da `dbAppendTable()` keine generierten `rowid`s zurueckgibt, die zugehoerigen
`prediction_prob`-Zeilen aber sofort denselben Schluessel brauchen.

## Beispielabfragen

```sql
-- Bestes Modell je Algorithmus, ueber alle Skripte/Runs hinweg
SELECT * FROM v_best_per_algorithm ORDER BY bacc DESC;

-- Streuung zwischen Folds fuer ein bestimmtes Modell
SELECT mres_fold, mres_value FROM v_fold_detail
WHERE mconf_algorithm = 'ranger' AND mres_measure_name = 'classif.bacc'
ORDER BY mres_fold;

-- Wie hat sich BAcc/MCC mit steigendem class_weight_power entwickelt?
SELECT wf_name, mconf_class_weight_power, bacc, mcc
FROM v_model_results
WHERE mconf_algorithm = 'lightgbm' AND mconf_class_weight_power IS NOT NULL
ORDER BY mconf_class_weight_power;

-- Welche Feature-Sets wurden fuer LightGBM je getestet, und mit welchem Ergebnis?
SELECT mconf_feature_set, bacc, mcc FROM v_model_results
WHERE mconf_algorithm = 'lightgbm' ORDER BY bacc DESC;

-- Alle Hyperparameter einer bestimmten Model-Config nachschlagen
SELECT hparam_name, hparam_value FROM hyperparam WHERE hparam_mconf_id = '<mconf_id>';

-- Externe Scores der finalen Submission je Modell einsehen
SELECT mconf_algorithm, subm_status, subm_public_score, subm_private_score
FROM v_submission_results
WHERE subm_platform = 'kaggle'
ORDER BY subm_recorded_at DESC;

-- Wie lange dauerten die einzelnen Runs eines Skripts (fuer Laufzeit-Planung)?
SELECT run_started_at, run_finished_at, run_notes FROM run r
JOIN workflow w ON r.run_wf_id = w.wf_id
WHERE w.wf_name = '125_catboost_benchmark.R';

-- Zwei Modelle auf denselben Zeilen vergleichen (z.B. "hat LightGBM bei
-- Rangers Fehlern richtig gelegen?", siehe 147_error_analysis_ranger.R)
SELECT r.pred_row_id, r.pred_truth, r.pred_response AS ranger_pred, r.response_prob AS ranger_prob,
       l.pred_response AS lightgbm_pred, l.response_prob AS lightgbm_prob
FROM v_prediction_detail r
JOIN v_prediction_detail l ON l.pred_row_id = r.pred_row_id AND l.mconf_algorithm = 'lightgbm'
WHERE r.mconf_algorithm = 'ranger' AND r.correct = 0;
```

Direkt aus R (z.B. in einer neuen Claude-Session):

```r
con <- DBI::dbConnect(RSQLite::SQLite(), "_artifacts/experiments.db")
DBI::dbGetQuery(con, "SELECT * FROM v_best_per_algorithm ORDER BY bacc DESC")
DBI::dbDisconnect(con)
```

## ROC-/PR-Kurven (`008_curve_diagnostics.R`, `160`/`161`)

Voraussetzung: `prediction`/`prediction_prob` enthalten fuer den jeweiligen
Algorithmus vollstaendige Vorhersagen (alle Eval-Zeilen, nicht nur eine
gefilterte Teilmenge - seit 2026-07-15 der Standard in `147_error_analysis_ranger.R`
fuer Ranger/LightGBM/LDA, siehe oben).

```r
Rscript 160_plot_roc_curve.R   # _artifacts/roc_curve.png
Rscript 161_plot_pr_curve.R    # _artifacts/pr_curve.png
```

Beide Skripte laden je Algorithmus (`algorithms_to_plot`) die zuletzt
geloggten vollstaendigen Vorhersagen, berechnen per Schwellenwert-Sweep
(`compute_classif_curves()`) ROC- bzw. PR-Kurvenpunkte und die Flaeche
darunter (`curve_auc()`, Trapezregel) - als Cross-Check gegen den in
`metric_result` geloggten `classif.auc`-Wert ausgegeben, falls vorhanden.
Funktioniert auch bei >=3 Klassen als One-vs-Rest-Kurve fuer eine gewaehlte
`positive_class` (in diesem 3-Klassen-Projekt standardmaessig `"unhealthy"`,
anpassbar am Skriptanfang).

## Uebertragung auf ein neues Projekt

Das Schema ist bewusst projektunabhaengig: kein Bezug zu `health_condition`,
den drei Klassen oder sonstigen Datensatz-Spezifika. Fuer einen neuen Kaggle-
Wettbewerb (analog zur Checkliste in `TARGETS.md`):

1. `db_schema.sql` und `db_logging.R` bleiben **unveraendert**.
2. Nur `project_name` in `000_config.R` aendern - `db_get_or_create_project()`
   legt beim ersten Lauf automatisch einen neuen `project`-Eintrag an.
   Bisherige Ergebnisse anderer Projekte bleiben in derselben `experiments.db`
   erhalten und sauber getrennt abfragbar (`WHERE proj_name = ...`).
3. Neue explorative Skripte haengen den immer gleichen Logging-Block
   (siehe oben) an ihr Ende an und schreiben eine passende
   `model_config_fn`, die aus ihren eigenen Task-/Learner-IDs die Metadaten
   ableitet - `algorithm_from_learner_id()`/`feature_set_from_task_id()`
   koennen dabei wiederverwendet werden, wenn die Task-Namenskonvention aus
   `020_task.R`/`025_feature_engineering.R` gleich bleibt.

**In der Praxis** (Stand `playground-series-s6e5`/`s6e6`/`s5e12`) zeigt sich
ein leicht abweichendes Muster: jedes Projekt bekommt beim Uebertragen sein
**eigenes** `_artifacts/experiments.db` (eigener `experiments_db_path` in der
kopierten `000_config.R`), statt von Anfang an direkt in die zentrale
Template-DB zu schreiben - einfacher, weil der Projektordner dadurch
selbstaendig bleibt (kein absoluter Pfad zurueck zum Template-Repo,
keine parallele Schreibkonkurrenz auf eine gemeinsame Datei waehrend der
aktiven Arbeit an mehreren Projekten). Siehe naechster Abschnitt, wie sich
mehrere solcher Projekt-DBs nachtraeglich fuer projektuebergreifende
Analysen konsolidieren lassen.

## Mehrere Projekt-DBs konsolidieren (`merge_project_experiments.R`)

Nach Abschluss eines Projekts lassen sich dessen aggregierte Ergebnisse in
die zentrale Template-`experiments.db` ueberfuehren, um spaeter
projektuebergreifende Muster per SQL zu finden (z.B. "in wie vielen Projekten
hat Tuning den Default tatsaechlich geschlagen", "AUC- vs. BAcc-Projekte im
Vergleich") - bisher nur in README-/`TEMPLATE_FRICTION.md`-Prosa dokumentiert,
jetzt zusaetzlich abfragbar.

```r
Rscript merge_project_experiments.R
```

- Sichert die Ziel-DB zuerst per Dateikopie (`experiments_backup_<Zeitstempel>.db`).
- Kopiert `project`/`workflow`/`run`/`run_config`/`model_config`/`resampling`/
  `hyperparam`/`metric_result` aus jeder in `source_db_paths` gelisteten
  Projekt-DB. Alle diese Tabellen haengen ausschliesslich an UUID-Text-
  Schluesseln (`<praefix>_id`) - kollisionsfrei kopierbar, die lokale
  `<praefix>_seq`-Spalte (SQLite-rowid-Alias, dient nur als lokaler
  Primary Key) wird dabei bewusst ausgeschlossen und in der Ziel-DB neu
  vergeben.
- **Bewusst NICHT gemergt**: `prediction`/`prediction_prob` (Zeilenebene).
  Diese beziehen sich auf projektspezifische `row_id`/`truth`/`response`-Werte
  (nicht projektuebergreifend vergleichbar) und nutzen zusaetzlich lokale
  INTEGER-Keys statt UUIDs (`pred_seq`/`pprob_pred_seq`, siehe
  `db_schema.sql`-Kommentar) - ein Merge muesste diese umschreiben, ohne
  echten Mehrwert fuer projektuebergreifende Analysen. Die vollstaendigen
  Vorhersagedaten bleiben in der jeweiligen Projekt-`experiments.db` fuer
  lokale Fehleranalyse (`147`) erhalten.
- Idempotent: ein Projekt (per `proj_name`) wird nur gemergt, wenn es in der
  Ziel-DB noch nicht existiert - mehrfaches Ausfuehren ist gefahrlos, auch
  nach neuen Projekten einfach `source_db_paths` ergaenzen und erneut
  ausfuehren.
- Fuer ein neues Projekt `source_db_paths` im Skript um den Pfad zu dessen
  `_artifacts/experiments.db` ergaenzen.

## Bekannte Einschraenkung

`_targets.R` schreibt aktuell **nicht** in `experiments.db` (das Schema
unterstuetzt `wf_type = 'targets'` bereits dafuer, es wird aber von keinem
Code genutzt). Grund: Der finale Produktions-Workflow trifft keine neuen
Modell-/Feature-/Gewichtungsentscheidungen mehr - die sind bereits ueber die
Skripte `030`-`145` getroffen und in `000_config.R` festgeschrieben. Sollte
sich das aendern (z.B. `_targets.R` soll selbst mehrere Kandidaten
vergleichen statt nur `submission_model_name` zu trainieren), koennte
`db_logging.R` unveraendert auch aus `_targets.R` heraus aufgerufen werden.
