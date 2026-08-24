# Session Handoff (Stand 2026-08-24) - Statusanker

Dies ist der Tagesanker fuer die neue Literatur-/Portfolio-Warmstart-Linie.
Der vorherige dauerhafte Anker ist
`statusanker/SESSION_HANDOFF_2026-08-23.md`.

## Repo-Zustand beim Einstieg

- Repo: `C:\Users\HP\OneDrive\Dokumente\R_Workspace\MLR3_Classifikation`
- Start-Commit: `dc51441`
- Arbeitskontext: Klassifikations-AutoML-Template in R/mlr3, aktuelles
  Template-Beispiel `playground-series-s6e7-health-condition`, finale
  Produktionspipeline ueber `_targets.R`, Explorations-/Backport-Arbeit
  bewusst ausserhalb des finalen Targets-Graphen.
- Nutzerhinweis aus der vorherigen Projektkontext-Erfassung: beim
  Smartphone-Addiction-Projekt ist `subset_fraction <- 0.20` lokal so
  gewollt.

## Neue Aufgabe

Der Nutzer bat nach einer Literaturrecherche zu 10 Veroeffentlichungen darum,
die daraus abgeleitete Roadmap in Backlog/Statusanker zu schreiben und dann
zu starten.

Priorisierte Literatur-Hebel fuer dieses Template:

1. **TabRepo**: eigene konsolidierte `experiments.db` als internes Mini-
   Repository fuer Portfolio- und Ensemble-Entscheidungen nutzen.
2. **AutoGluon-Tabular**: OOF-Stacking und mehrstufige, diverse Candidate
   Pools als Score-Hebel.
3. **TabPFN/TabICL**: Foundation-Modelle nur selektiv nach Datengroesse,
   Laufzeit und Diversitaetsnutzen einsetzen.
4. **BOHB/Hyperband/Auto-sklearn 2.0**: Budgetierung und Warmstart statt
   teurer Voll-CV fuer jeden Kandidaten.
5. **TabM**: effizienter Neural-Kandidat, erst nach Neural-Gate und echter
   Evidenz.

## Wichtige Abgrenzung

Der alte Meta-Learning-Warmstart mit nur 8 OpenML-Referenzdatensaetzen ist
weiterhin ein dokumentierter Negativbefund und wird nicht als Default
uebernommen. Die neue Linie ist breiter: eigene Projekt-DB auswerten,
algorithmisches Portfolio ableiten, dann gegen reale Projekte pruefen.

## Gestarteter erster Sprint

1. Backlog-Eintrag in `TARGETS.md` ergaenzen.
2. Erstes Diagnose-/Evidenzskript `build_portfolio_warmstart_evidence.R`
   anlegen.
3. Skript ausfuehren und daraus die naechsten agentischen Arbeitspakete
   ableiten.
4. `recommend_portfolio_warmstart.R` als ersten Empfehlungs-Helper anlegen
   und im Defaultbudget `balanced` ausfuehren.
5. `validate_portfolio_warmstart_retrospective.R` anlegen und Leave-in plus
   Leave-one-project-out gegen die vorhandene Projekt-DB ausfuehren.
6. Ersten pre-registered Projektvalidierungslauf auf `PumpItUp` starten:
   `PORTFOLIO_WARMSTART_PREREG_PUMPITUP.md` + 
   `validate_portfolio_warmstart_pumpitup.R`.
7. Zweiten pre-registered Projektvalidierungslauf auf `openml-credit-g`
   starten: `PORTFOLIO_WARMSTART_PREREG_CREDIT_G.md` +
   `validate_portfolio_warmstart_credit_g.R`.
8. Dritten pre-registered Projektvalidierungslauf auf
   `pima-diabetes-sentinel-test` starten: `PORTFOLIO_WARMSTART_PREREG_PIMA.md`
   + `validate_portfolio_warmstart_pima.R`.

## Erster Befund aus der Experiment-DB

`build_portfolio_warmstart_evidence.R` wurde erfolgreich ausgefuehrt. Es
schreibt zwei ignorierte Artefakte:

- `_artifacts/portfolio_warmstart_algorithm_best.csv`
- `_artifacts/portfolio_warmstart_summary.csv`

Die erste familienbasierte Zusammenfassung aus der vorhandenen zentralen
`experiments.db`:

- `lightgbm`: Core-Portfolio, 35 Projekt-Metriken, 25 Siege, Top-3-Rate
  0.91, Median-Regret 0.0000.
- `ranger`: Core-Portfolio, 46 Projekt-Metriken, 23 Siege, Top-3-Rate
  0.93, Median-Regret 0.0010.
- `ensemble`: Core-Portfolio, 5 Projekt-Metriken, Top-3-Rate 0.80,
  Median-Regret 0.0085; Evidenz noch kleiner, aber als Score-Hebel
  plausibel.
- `stack_logreg`, `xgboost`, `catboost`: Kandidaten-Portfolio, aber noch
  nicht als pauschale Defaults.
- `tabpfn`: in der vorhandenen DB teuer/niedrig priorisiert; Foundation-
  Modelle bleiben selektive Spezialkandidaten statt Default.

Interpretation fuer den naechsten Agentenlauf: Der erste echte Warmstart-
Kern ist kein exotisches Modell, sondern eine evidenzbasierte Reihenfolge
`lightgbm`/`ranger`/`ensemble`, plus gezielte Diversitaetskandidaten. Der
erste Empfehlungs-Helper existiert jetzt und schreibt:

- `_artifacts/portfolio_warmstart_recommendation.csv`
- `_artifacts/portfolio_warmstart_recommendation.md`

Default-Befund fuer das aktuelle Template-Beispiel (`balanced`, grosse
`train.csv`): `lightgbm` und `ranger` frueh benchmarken/tunen, `ensemble`
spaet als Score-Hebel pruefen. `catboost`/`xgboost` werden erst bei
kleinerem Projekt oder groesserem Budget empfohlen; `tabpfn` nur als
expliziter Spezialtest bei kleinen Projekten und reichem Budget.

Retrospektive Validierung:

- `_artifacts/portfolio_warmstart_validation.csv`
- `_artifacts/portfolio_warmstart_validation.md`
- `_artifacts/portfolio_warmstart_validation_leave_one_project_out.csv`

Zahlen: 50 Projekt-Metriken aus 16 realen Projekten. Die Gewinnerfamilie ist
in Leave-in und Leave-one-project-out jeweils 48/50 in der empfohlenen Top-3;
Median-Regret nach 1, 2 und 3 Kandidaten jeweils 0. Das ist noch kein
externer Benchmark-Beweis, aber ein deutlich belastbarer interner Hinweis,
dass `lightgbm`/`ranger`/`ensemble` als Startportfolio sinnvoll ist.

Erste echte Projektvalidierung:

- Pre-Registration: `PORTFOLIO_WARMSTART_PREREG_PUMPITUP.md`
- Skript: `validate_portfolio_warmstart_pumpitup.R`
- Artefakte:
  - `_artifacts/portfolio_warmstart_pumpitup_validation.csv`
  - `_artifacts/portfolio_warmstart_pumpitup_validation.md`

PumpItUp war nicht als regulaerer Klassifikationsbenchmark in der Portfolio-
LOO-Evidenz enthalten. Vorab festgelegte Reihenfolge: `lightgbm -> ranger ->
ensemble`; wegen hochkardinaler Faktoren wurde Ranger mit zielwertfreiem
Frequency-Encoding getestet. Ergebnis 3-fold CV, Accuracy: Ensemble 0.8116,
Ranger 0.8039, LightGBM 0.8032. Interpretation: erster echter positiver
Beleg fuer die Startportfolio-Linie, besonders fuer den spaeten Ensemble-
Hebel.

Zweite Projektvalidierung:

- Pre-Registration: `PORTFOLIO_WARMSTART_PREREG_CREDIT_G.md`
- Skript: `validate_portfolio_warmstart_credit_g.R`
- Artefakte:
  - `_artifacts/portfolio_warmstart_credit_g_validation.csv`
  - `_artifacts/portfolio_warmstart_credit_g_validation.md`

Credit-G ist klein, binaer und anders strukturiert als PumpItUp. Vorab
festgelegte Reihenfolge: `lightgbm -> ranger -> ensemble`. Ergebnis 5-fold
CV, BAcc: Ranger 0.6640, Ensemble 0.6636, LightGBM 0.6629. Interpretation:
zweiter positiver Beleg fuer das Startportfolio, aber mit Nuance: Ensemble
ist optionaler spaeter Score-Hebel, kein garantierter Gewinner. Das reicht
fuer einen optionalen Empfehlungs-/Diagnose-Helper, nicht fuer einen harten
Workflow-Zwang.

Dritte Projektvalidierung:

- Pre-Registration: `PORTFOLIO_WARMSTART_PREREG_PIMA.md`
- Skript: `validate_portfolio_warmstart_pima.R`
- Artefakte:
  - `_artifacts/portfolio_warmstart_pima_validation.csv`
  - `_artifacts/portfolio_warmstart_pima_validation.md`

Pima ist klein, binaer und numerisch. Die rohe Sentinel-Variante wurde vorab
fixiert, damit der Lauf nicht erneut Sentinel-Handling testet. Ergebnis
5-fold CV, BAcc: Ranger 0.7172, Ensemble 0.7019, LightGBM 0.6960. Interpretation:
dritter positiver Beleg fuer das Startportfolio. Muster ueber drei Projekte:
`lightgbm`/`ranger` frueh als Kern ist robust; Ensemble ist wertvoll, aber
projektspezifisch optional.

Template-Ueberfuehrung:

- Referenz: `REFERENZ_PORTFOLIO_WARMSTART.md`
- Helper: `build_portfolio_warmstart_evidence.R`
- Helper: `recommend_portfolio_warmstart.R`
- Validierung: `validate_portfolio_warmstart_retrospective.R`

Status: als optionaler Diagnose-/Empfehlungs-Helper uebernommen. Keine
`_targets`-Aenderung und kein neuer Pflichtschritt in `WorkflowDescription.md`,
weil die Methode die explorative Modellauswahl startet, aber nicht die finale
Produktionspipeline veraendert.

Literaturwerte-Layer:

- Schema erweitert in `db_schema.sql`:
  - `literature_source`
  - `literature_benchmark_result`
  - `v_literature_benchmark_results`
- Seed-Skript: `seed_literature_benchmark_results.R`

Zweck: Paper-/Benchmark-/Dokumentationswerte als Kontext speichern, aber
strikt getrennt von lokalen `metric_result`-Runs. `build_portfolio_warmstart_
evidence.R` nutzt diese Tabellen bewusst nicht.

Nacharbeit Literaturvergleich:

- `compare_literature_vs_own_results.R` erstellt.
- OpenML-Dataset-IDs gepflegt: adult=179, Amazon_employee_access=4135,
  bank-marketing=1461, credit-g=31.
- Seed erweitert um AutoMLBench-Dataset-Metadaten und externe Binary-
  Classification-Rangliste.
- `reproduce_literature_f1_adult_amazon.R` erstellt und ausgefuehrt, um fuer
  bereits vorhandene lokale Projekte die Literaturmetrik F1 bewusst lokal zu
  loggen.
- `reproduce_literature_f1_credit_bank.R` erstellt und ausgefuehrt: gezielt
  nur Kandidaten mit OpenML-ID, klarer F1-Metrik und lokaler Evidenz
  (`credit-g` 10-fold-CV, `bank-marketing` vorhandene Holdout-Predictions
  aus Ensemble-Selection).
- Aktueller Triage-Befund nach zweitem Nachlauf: 32
  `matched_context_only`, 32 `no_local_dataset`. Die grossen Deltas,
  besonders bei `amazon_employee_access` und `bank-marketing`, sind ein
  Signal fuer fehlende direkte Vergleichbarkeit, nicht fuer ein lokales
  Leaderboard-Urteil.
- `classify_literature_comparability.R` erstellt und ausgefuehrt. Ergebnis:
  35 `aggregate_or_metadata_context`, 12 `resampling_mismatch_context`,
  7 `source_context_missing_openml_id`, 4 `split_match_candidate`.
  Nur `credit-g` landet als `split_match_candidate`; Adult/Amazon bleiben
  wegen lokaler 5-fold-CV vs. Literatur-10-fold im Resampling-Mismatch,
  Bank-Marketing wegen Holdout vs. 10-fold ebenfalls.
- Manueller Quellenreview mit `review_literature_split_candidates.R`:
  `credit-g` bleibt `keep_context_only`. Quelle bestaetigt F1-Werte,
  OpenML-Suite und 10-fold-Wording, aber nicht exakte OpenML-Task-ID,
  positive Klasse, Harness-/Preprocessing-Details oder Zeitbudget.

## Naechste Entscheidungen

- Nur Diagnose/Ranking reicht ohne `WorkflowDescription.md`-Aenderung.
- Ein echter neuer nummerierter Workflow-Schritt oder ein neues Gate wuerde
  `WorkflowDescription.md` und ggf. ein ADR erfordern.
- Vor Backport nach ADR-003: mindestens zwei reale Projektbestaetigungen
  oder ein expliziter No-op-Beleg.
- Naechster sinnvoller Schritt: echte Paper-Tabellen nur dann weiter importieren,
  wenn `lres_comparability` explizit gepflegt ist; fuer die 32
  `no_local_dataset` bevorzugt zuerst datasets mit OpenML-ID und klarer
  Metrik/Split-Beschreibung auswaehlen.
- Keine DB-Umschreibung der `lres_comparability`-Werte aus dem aktuellen
  FEDOT-F1-Block; der gepruefte Split-Kandidat bleibt `context_only`.
