# Referenz: Portfolio-Warmstart fuer Klassifikationsprojekte

Stand: 2026-08-24.

## Kurzfassung

Die Portfolio-Warmstart-Linie nutzt die zentrale `experiments.db` als kleines
internes TabRepo: Aus bisherigen Projektlaeufen wird abgeleitet, welche
Modellfamilien bei einem neuen Klassifikationsprojekt frueh getestet werden
sollten.

Aktueller Template-Status: **optional uebernommen als Diagnose-/Empfehlungs-
Helper**, nicht als harter Workflow-Zwang.

Empfohlener Kern:

1. `lightgbm` frueh pruefen.
2. `ranger` frueh als robuste Gegenprobe pruefen.
3. `ensemble` spaet als optionalen Score-Hebel pruefen, wenn mindestens zwei
   brauchbare Kandidaten mit Wahrscheinlichkeiten vorliegen.

Wichtige Grenze: Das Ensemble ist nicht pauschal Gewinner. Es gewann klar auf
PumpItUp, lag aber auf Credit-G und Pima zwischen den Einzelmodellen. Deshalb
bleibt es ein spaeter Hebel, kein Pflichtsieger.

## Herkunft

Die Linie ist aus einer Literaturrecherche und anschliessender interner
Validierung entstanden:

- TabRepo: Modell-/Portfolio-Evidenz aus vielen Datensaetzen wiederverwenden.
- AutoGluon-Tabular: diverse Modellpools und Stacking/Ensembling als starke
  tabellarische Baseline.
- Auto-sklearn 2.0 / BOHB / Hyperband: Budget und Suchreihenfolge sind selbst
  ein Optimierungshebel.
- TabPFN/TabICL/TabM: moderne Kandidaten, aber selektiv nach Datengroesse,
  Laufzeit und Projektprofil, nicht als pauschaler Default.

## Lokale Evidenz

### Interne Retrospektive

`validate_portfolio_warmstart_retrospective.R` prueft die aus der zentralen
Experiment-DB abgeleitete Empfehlung gegen vorhandene Projekt-Metriken:

- 50 Projekt-Metriken aus 16 realen Projekten.
- Leave-in: Gewinnerfamilie in 48/50 Faellen in der empfohlenen Top-3.
- Leave-one-project-out: ebenfalls 48/50.
- Median-Regret nach 1, 2 und 3 Kandidaten: jeweils 0.

Das ist kein externer Benchmark-Beweis, aber ein belastbarer interner Hinweis,
dass `lightgbm` und `ranger` als frueher Kern sinnvoll sind.

### Pre-registered Projektvalidierungen

Alle drei Laeufe wurden vorab mit derselben Reihenfolge festgelegt:
`lightgbm -> ranger -> ensemble`.

| Projekt | Profil | Primaermetrik | Gewinner | Ergebnis |
|---|---|---|---|---|
| PumpItUp | mittelgross, multiclass, hochkardinale Kategorien | Accuracy | Probability-Average-Ensemble | 0.8116 vs Ranger 0.8039 vs LightGBM 0.8032 |
| OpenML Credit-G | klein, binaer, gemischte Features | BAcc | Ranger | 0.6640 vs Ensemble 0.6636 vs LightGBM 0.6629 |
| Pima Diabetes | klein, binaer, numerisch | BAcc | Ranger | 0.7172 vs Ensemble 0.7019 vs LightGBM 0.6960 |

Interpretation: Drei positive Projektbestaetigungen fuer das Startportfolio.
Die robuste Lehre ist der fruehe Vergleich `lightgbm`/`ranger`; der Ensemble-
Schritt ist wertvoll, aber projektspezifisch.

## Nutzung

Im Template-Repo:

```r
source("build_portfolio_warmstart_evidence.R")
source("recommend_portfolio_warmstart.R")
```

Oder per Konsole:

```powershell
Rscript build_portfolio_warmstart_evidence.R
Rscript recommend_portfolio_warmstart.R --budget=balanced
```

Optionales Budget:

- `lean`: nur Kernkandidaten.
- `balanced`: Standard, groessenabhaengige Diversitaetskandidaten.
- `rich`: mehr Diversitaet, spaet auch Stacking/Foundation-Model-Spezialtests.

Erzeugte Artefakte:

- `_artifacts/portfolio_warmstart_summary.csv`
- `_artifacts/portfolio_warmstart_algorithm_best.csv`
- `_artifacts/portfolio_warmstart_recommendation.csv`
- `_artifacts/portfolio_warmstart_recommendation.md`

Validierungsartefakte:

- `_artifacts/portfolio_warmstart_validation.csv`
- `_artifacts/portfolio_warmstart_validation.md`
- `_artifacts/portfolio_warmstart_validation_leave_one_project_out.csv`
- `_artifacts/portfolio_warmstart_pumpitup_validation.*`
- `_artifacts/portfolio_warmstart_credit_g_validation.*`
- `_artifacts/portfolio_warmstart_pima_validation.*`

## Literaturwerte-Layer

Ergaenzend gibt es ein eigenes DB-Schema fuer Literatur-/Benchmarkwerte:

- `literature_source`
- `literature_benchmark_result`
- `v_literature_benchmark_results`
- Seed-Skript: `seed_literature_benchmark_results.R`

Diese Werte sind **Kontext**, nicht lokale Evidenz. Sie werden nicht von
`build_portfolio_warmstart_evidence.R` genutzt. Der Grund ist wichtig:
Paperwerte haben andere Zeitbudgets, Splits, Frameworks, Preprocessing-
Konventionen und Metriken. Fuer Publikationsarbeit und Benchmark-Auswahl sind
sie wertvoll; fuer automatische lokale Portfolio-Gewichte waeren sie ohne
explizite Vergleichbarkeitspruefung gefaehrlich.

## Backport-Entscheidung

Nach ADR-003 ist das Kriterium fuer einen optionalen Helper erfuellt:

- mehrere unabhaengige Projektbestaetigungen,
- ein klarer Nutzen als Startreihenfolge/Diagnose,
- keine harte Kopplung an den finalen Produktionsworkflow.

Nicht uebernommen wird:

- ein Pflicht-Ensemble,
- ein automatischer Modellwechsel im finalen `_targets`-Graphen,
- ein neuer nummerierter Pflichtschritt in `WorkflowDescription.md`.

Der Grund: Die Methode verbessert die **Modellauswahl-Startreihenfolge**, nicht
die finale Produktionspipeline selbst. Ein neues Projekt soll weiterhin seine
eigene Evidenz erzeugen und nicht blind den letzten Gewinner kopieren.
