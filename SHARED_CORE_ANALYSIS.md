# Shared-Core-Analyse: Classification vs. Regression

P2.2 aus ChatGPTs korrigiertem Plan (siehe `BACKLOG.md`): **nicht sofort
einen gemeinsamen Package-Core bauen**, sondern zuerst ehrlich pruefen,
welche der neun genannten Komponenten zwischen `MLR3_Classifikation` und
`MLR3_Regression` TATSAECHLICH identisch sind - und nur extrahieren, wenn
reale Doppelpflege ein nachweisbares Problem darstellt. Diese Datei ist
das Ergebnis dieser Pruefung, kein Umsetzungsplan. **Es wurde noch nichts
extrahiert.**

Methodik: fuer jede Komponente wurde die tatsaechliche Datei (nicht die
Erinnerung/Doku) in beiden Repos diff't - Funktionsnamen verglichen,
bei kleinen Diffs der komplette Funktionskoerper Zeile fuer Zeile.

## Vergleichstabelle

| Component | Classification | Regression | identical | candidate |
|---|---|---|---|---|
| Experiment Logging (`db_logging.R`) | 19 Funktionen, 479 Zeilen | 18 Funktionen (+`db_log_regression_predictions`, `estimate_tuning_runtime`), etwas kuerzer | **Kern JA** - alle 18 gemeinsamen Funktionsnamen identisch, Kernfunktionen (`db_connect`, `db_create_run`, `db_log_metric_result`, ...) strukturell gleich; Datei als Ganzes NEIN (gewachsene Divergenz) | **JA** - siehe Befund unten (`merge_project_experiments.R` hatte genau diese Art Divergenz schon einmal zu einem echten Bug gefuehrt) |
| DB Schema (`db_schema.sql`) | 15 Tabellen, 499 Zeilen | 11 Tabellen, ~190 Zeilen | **JA fuer die 11 Kern-Tabellen** (`project`/`workflow`/`run`/`run_config`/`model_config`/`hyperparam`/`resampling`/`metric_result`/`prediction`/`prediction_prob`/`submission_result`) - strukturell deckungsgleich. Classification hat zusaetzlich `evidence` (P1.2), `literature_source`/`literature_benchmark_result` (Literatur-Vergleich) | **JA** fuer den Kern |
| Runtime Helpers (`005_benchmark_runtime.R`) | 5 Funktionen | 1 Funktion (`run_timed_benchmark`) | **`run_timed_benchmark()` selbst: JA, fast wortgleich** (6 Diff-Zeilen bei ~50 Zeilen Funktionskoerper, einzig ein `enable_class_stratification()`-Aufruf classification-spezifisch) - die 4 uebrigen Classification-Funktionen (`check_target_column`, `warn_rare_factor_levels`, ...) sind Klassifikations-Sanity-Checks ohne Regressions-Pendant | **Teilweise** - nur `run_timed_benchmark()`, nicht die ganze Datei |
| Resampling (`group_resampling.R`) | 7 Funktionen | 5 Funktionen | **JA fuer 5/6 gemeinsame Funktionen** - `set_group_role()` ist BYTE-IDENTISCH, `diagnose_group_cv()`/`scan_group_candidates()`/`test_group_significance()`/`.eta_squared()` gleich. Classification hat zusaetzlich `.cramers_v()`/`.group_association_stat()` (kategoriale Assoziationsmasse) | **JA** fuer den Kern |
| Generalization Gap (`generalization_gap.R`) | vorhanden (+`136_generalization_gap.R`) | **nicht vorhanden** | N/A - nichts zum Vergleichen, existiert nur einseitig | **Nein** (kein Duplication-Problem) - das ist eine Backport-Frage, keine Extraktions-Frage (siehe Hinweis unten) |
| Provenienz (`provenance.R`, P1.3) | vorhanden | **nicht vorhanden** | N/A | **Nein** - Backport-Frage |
| Config Validation (`config_validation.R`, P0.3) | vorhanden | **nicht vorhanden** | N/A | **Nein** - Backport-Frage |
| Evidence Registry (`evidence_registry.R`, P1.2) | vorhanden | **nicht vorhanden** | N/A | **Nein** - Backport-Frage |
| Artifact Management | `db_housekeeping.R` (P2.1), `_artifacts/`-Konvention | nur `_artifacts/`-Konvention (informell gleich, kein eigenes Modul) | Nur die Verzeichniskonvention, kein Code zum Vergleichen | **Nein** - Backport-Frage fuer `db_housekeeping.R` |

## Wichtiger methodischer Hinweis

Von den 9 im Plan genannten Komponenten sind nur 4 (Experiment Logging,
DB Schema, Runtime Helpers, Resampling) tatsaechlich in BEIDEN Repos
vorhanden und damit eine echte "ist das dieselbe Logik zweimal gepflegt?"-
Frage. Die restlichen 5 (Generalization Gap, Provenienz, Config
Validation, Evidence Registry, Artifact Management) existieren bislang
NUR in `MLR3_Classifikation` (alles P0/P1/P2.1-Arbeit dieser Woche) - dort
gibt es nichts zu deduplizieren, sondern hoechstens eine spaetere
Backport-Entscheidung ("soll `MLR3_Regression` das auch bekommen?"). Das
ist eine andere Frage als P2.2 stellt und wird hier bewusst nicht
mitbeantwortet.

## Konkreter Beleg fuer "reale Doppelpflege ist ein Problem"

`merge_project_experiments.R` (nicht in der Tabelle oben, da nicht auf
der Plan-Liste, aber strukturell dieselbe Kategorie wie Experiment
Logging/DB Schema) demonstriert das Risiko bereits konkret: laut
Kopfkommentar der Regression-Version war die Datei bis 2026-08-08 eine
"unangepasste Kopie der Klassifikations-Version" - `target_db_path` zeigte
faelschlich auf die KLASSIFIKATIONS-DB statt auf die eigene. Das ist
genau das Szenario, vor dem eine Shared-Core-Extraktion schuetzen wuerde
- und genau das Kriterium, das der Plan fuer eine Extraktion verlangt
("nur wenn reale Doppelpflege ein Problem darstellt"). `db_logging.R` hat
strukturell dasselbe Risikoprofil (grosse Datei, viele Funktionen, beide
Seiten aendern sie unabhaengig voneinander) - dort wurde ein aehnlicher
Bug bislang nicht gefunden, aber die Wahrscheinlichkeit ist nicht
niedriger.

## Empfehlung (nicht umgesetzt, nur dokumentiert)

Die drei staerksten Kandidaten fuer eine spaetere, bewusste Extraktion
(nicht in dieser Session umgesetzt, siehe Plan: "nur wenn reale
Doppelpflege ein Problem darstellt"):

1. **`db_schema.sql`** (Kern-Tabellen) - am risikoaermsten zu extrahieren
   (reine Struktur, kein Verhalten), UND es gibt bereits einen konkreten
   Bug-Beleg in einer strukturell aehnlichen Datei.
2. **`db_logging.R`** (Kernfunktionen) - groesster Umfang, groesster
   potenzieller Diskrepanz-Schaden, aber auch der aufwendigste Umbau
   (API-Aenderungen muessten in BEIDEN Repos synchron nachgezogen werden).
3. **`group_resampling.R`**/**`run_timed_benchmark()`** - kleinster,
   risikoaermster erster Schritt, falls ueberhaupt mit einer Extraktion
   begonnen werden soll (bereits fast identisch, kleine Diff-Flaeche).

Eine tatsaechliche Extraktion sollte laut Plan erst erfolgen, wenn eine
konkrete Doppelpflege-Situation (ein Bugfix/eine Erweiterung, die in
BEIDEN Repos manuell nachgezogen werden musste) das rechtfertigt - nicht
prophylaktisch. Diese Analyse liefert die Diagnose, keine Entscheidung.
