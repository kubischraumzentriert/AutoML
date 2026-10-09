# Session Handoff 2026-10-09

## Stand

- Template-Repo: `C:\Users\HP\OneDrive\Dokumente\R_Workspace\MLR3_Classifikation`
- Branch: `main`
- HEAD: `9933040` (`Record credit-g literature reproduction`)
- Remote-Stand: `9933040` auf `origin/main`; Arbeitsbaum sauber.

## Heute abgeschlossen

- Die zentrale Template-DB wurde um das S6E10-Projekt erweitert:
  `playground-series-s6e10-airline-satisfaction`.
- Zentral verifiziert: Kaggle Public AUC `0.95785`, Submission-ID
  `fc657dc7-74a3-43de-a7c0-11bebf962352`, Modell-ID
  `085ee4b0-b350-4c34-9759-d5de7cfeea91`.
- Merge-Statistik fuer S6E10: 16 Workflows, 469 Modellkonfigurationen,
  3109 Metrikergebnisse, 1 `submission_result`.
- Merge-Backup: `_artifacts/experiments_backup_20261009T060132.db`.
- Der Merge liest Quell-DBs jetzt ueber temporaere lokale Kopien. Ein
  expliziter Override ist ueber `AUTOML_MERGE_SOURCE_DB_PATHS` moeglich.
- `analysis/compare_literature_vs_own_results.R` erfolgreich ausgefuehrt:
  110 gematchte Paare (`context_only`), 32 aggregierte Benchmark-Zeilen ohne
  lokales Dataset. Reports liegen unter `_artifacts/literature_vs_own_results.*`.
- `analysis/classify_literature_comparability.R` und das manuelle Review
  erfolgreich ausgefuehrt: 10 Kandidaten, alle bleiben `keep_context_only`.
  Hauptluecken bei `credit-g`: positive Klasse, exakter Task, Preprocessing,
  Benchmark-Harness/Ressourcen und Seed-Protokoll.
- `analysis/reproduce_literature_f1_credit_bank.R` ausgefuehrt: `credit-g`
  mit positiver Klasse `bad`, 10-Fold-CV, Seed 42 und Imputation. LightGBM:
  F1 `0.5394`, AUC `0.7627`, BAcc `0.6750`; Ranger: F1 `0.5061`, AUC
  `0.7907`, BAcc `0.6595`. Werte sind in der Template-DB protokolliert und
  bleiben als lokale Reproduktion getrennt von Literaturwerten.
- Appendix-A-Harnessdaten der LightAutoML-Quelle sind jetzt erfasst:
  10 OpenML-Folds, ROC-AUC, 1h Framework-Limit/2h Hard-Kill, 8 CPU, 32 GB
  RAM, Ubuntu 18.04/Xeon Gold 6148. Der lokale Lauf bleibt bewusst
  `context_only`, da er nicht den Docker-/Framework-Harness ausfuehrt.
- Umgebungscheck fuer einen direkten Lauf: `lightautoml` und
  `automlbenchmark` fehlen im lokalen Python; Docker ist nicht verfuegbar.
  Kein Installationsversuch ohne separate Entscheidung ueber Aufwand und
  Reproduzierbarkeitsnutzen.
- WSL-/Podman-Umgebung inzwischen eingerichtet: LightAutoML `0.4.2` in
  `/home/anen/.venvs/automl-paper`, AutoMLBenchmark-Commit `dfe8d21` in
  `/home/anen/src/automlbenchmark` mit eigener venv
  `/home/anen/.venvs/automlbenchmark`. Podman `4.9.3` laeuft; der interne
  `docker`-Aufruf des Benchmarks wird ueber `/home/anen/bin/docker` auf
  Podman abgebildet.

## Naechster Schritt

1. Reproduzierende `credit-g`-Konfiguration mit explizitem Task, positiver
   Klasse, 10-Fold-Resampling und dokumentiertem Ressourcenbudget weiter
   gegen die Paper-Harness-Annahmen abgleichen.
2. Nur aus gut vergleichbaren, reproduzierten Paaren Template-Kandidaten
   ableiten.
3. Vor dem Vollbudget einen einzelnen `credit-g`-Smoke-Fold im
   AutoMLBenchmark-/Podman-Pfad ausfuehren.
