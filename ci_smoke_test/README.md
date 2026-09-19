# ci_smoke_test

## Was ist ein Smoke-Test, und wozu dient er hier?

Ein Smoke-Test prueft NICHT, ob die Modell-Scores gut/korrekt sind (das
macht `tests/testthat/`, siehe dort) - er prueft nur, ob die Kernskripte
End-to-End FEHLERFREI durchlaufen ("laeuft es noch, oder raucht es?").
`.github/workflows/ci-smoke-test.yml`s `smoke-test`-Job kopiert dafuer bei
jedem Push/PR (Pfadfilter `**.R`) die nummerierten Kernskripte (015-137,
`db_logging.R`, referenzierte `modules/`-Dateien) hierher und fuehrt sie
gegen eine kleine, synthetische Fixture aus - kein einziger Score-
Schwellenwert wird geprueft, nur ob jedes Skript ohne Fehler durchlaeuft.

Das faengt eine Fehlerklasse, die reine Unit-Tests (`tests/testthat/`)
NICHT abdecken: ein Skript kann in Isolation getestete, korrekte
Bausteine nutzen und trotzdem als Ganzes brechen (falscher Spaltenname
beim Zusammenspiel zweier Skripte, ein vergessenes `library()`, eine
Reihenfolge-Abhaengigkeit zwischen Skripten). Der `unit-tests`-Job in
derselben Workflow-Datei ist unabhaengig davon der ECHTE
Korrektheitstest (bekannte Erwartungswerte, siehe `tests/testthat/`) -
beide Jobs ergaenzen sich, keiner ersetzt den anderen.

**Warum eine SYNTHETISCHE Fixture statt eines echten/heruntergeladenen
Datensatzes?** Kein Netzwerkzugriff in CI noetig (schneller, keine externe
Abhaengigkeit die CI brechen kann), und ein deterministisch erzeugter
Datensatz ist reproduzierbar exakt gleich bei jedem Lauf.

Kein eigenstaendiges Projekt - nur zwei Dateien werden tatsaechlich
committed:

- `000_config.R` - Config fuer die Fixture (target_col="target", id_col="id",
  `subset_fraction=1.0`, Tuning-/Wiederholungs-Budgets auf Minimalwerte
  gesetzt - nur der Code-Pfad zaehlt in CI, nicht gute Hyperparameter).
- `generate_fixture.R` - erzeugt einen deterministischen, synthetischen
  Trainingsdatensatz (800 Zeilen, 3 Klassen, 8 numerische + 2 kategoriale
  Features). Bewusst synthetisch statt eines echten/heruntergeladenen
  Datensatzes - kein Netzwerkzugriff in CI noetig.

Alles andere (die nummerierten Pipeline-Skripte, `db_logging.R`, etc.) wird
vom Workflow zur Laufzeit aus dem Repo-Root hierher kopiert (siehe
`.gitignore` - diese Kopien werden nicht committed, Original lebt nur im
Root).

**Lokal nachvollziehen** (z.B. nach einer Skript-Aenderung im Root, bevor man
pusht):

```bash
cd ci_smoke_test
for f in db_logging.R db_schema.sql 005_benchmark_runtime.R 006_tuning_diagnostics.R \
         class_multiplier_tuning.R split_size_sensitivity.R learning_curve.R \
         seed_stability.R generalization_gap.R \
         015_target_leak_audit.R 020_task.R 022_split_size_sensitivity.R \
         023_learning_curve.R 030_baseline.R 080_boosting_benchmark.R \
         090_ranger_tuning.R 100_lightgbm_tuning.R 092_seed_stability.R \
         136_generalization_gap.R; do
  cp "../$f" "./$f"
done
Rscript generate_fixture.R
Rscript 015_target_leak_audit.R && Rscript 020_task.R && Rscript 022_split_size_sensitivity.R && \
  Rscript 023_learning_curve.R && Rscript 030_baseline.R && Rscript 080_boosting_benchmark.R && \
  Rscript 090_ranger_tuning.R && Rscript 100_lightgbm_tuning.R && Rscript 092_seed_stability.R && \
  Rscript 136_generalization_gap.R
```
