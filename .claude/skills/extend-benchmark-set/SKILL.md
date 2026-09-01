---
name: extend-benchmark-set
description: Erweitert das eingefrorene externe CC18-Benchmark-Set (siehe EXTERNAL_BENCHMARK_SET.md) um N neue Datensaetze - deterministische Auswahl, Task-Setup, Level-2-Evaluation, Decision-Stability, Korrelationsanalyse, Evidence-Logging, Dokumentation. Nutzen, wenn der Nutzer "das Benchmark-Set erweitern"/"n auf X erweitern"/"Weg B" (oder aehnlich) sagt.
---

# Externes Benchmark-Set erweitern

Wiederholbare Prozedur, zweimal identisch angewendet (2026-08-31 n=6->10,
2026-09-01 n=10->15, siehe BACKLOG.md fuer beide vollstaendigen
Durchlaeufe als Referenz). Diese Skill fasst den Ablauf zusammen, damit
er nicht jedes Mal neu hergeleitet werden muss.

## Wann anwenden

Der Nutzer bittet, das externe Benchmark-Set (aktuell 15 CC18-
Datensaetze, siehe `EXTERNAL_BENCHMARK_SET.md`) um weitere N Datensaetze
zu erweitern - typischerweise fuer die Decision-Stability-Forschungs-
frage (`decision_stability_level2_analysis_n15.R`) oder eine aehnliche
uebergreifende Analyse.

**Vor dem Start pruefen**: lohnt sich eine weitere Erweiterung ueberhaupt
noch? Nach 3 unabhaengigen Erweiterungen (n=6/10/15) ist der Nullbefund
fuer die Decision-Stability-Frage bereits sehr robust bestaetigt (rho
durchgehend nicht signifikant, siehe BACKLOG.md) - ein weiterer Ausbau
braucht eine explizite Nutzerbegruendung, kein automatisches "weiter
so". Bei einer NEUEN Forschungsfrage gilt das nicht.

## Ablauf

### 0. Kosten vorab flaggen

Jeder neue Datensatz braucht: Task-Setup + Level-2-Prototyp (Tuning
ueber 3 Outer-Folds, ~1-3 Min bei kleinen Datensaetzen, kann bei grossen
>10000 Zeilen mehrere Minuten dauern) + Decision-Stability (10
Wiederholungen x 3 Folds = 30 zusaetzliche Tuning-Laeufe, deutlich
teurer als Level-2 allein). Bei unklarer Nutzeranweisung ("wie viele
neue?") IMMER per AskUserQuestion nachfragen statt zu raten - siehe
BACKLOG.md, "mach weiter mit der Weg-B-Erweiterung" fuehrte zu genau
dieser Rueckfrage.

### 1. Auswahl deterministisch ziehen und SOFORT einfrieren

Ein neues Selektionsskript nach dem Muster von
`select_weg_b_extension.R`/`select_n15_extension.R` schreiben:

- Dieselben Einschlusskriterien wie immer (500-20000 Instanzen, <=100
  Features, 2-10 Klassen) - siehe `EXTERNAL_BENCHMARK_SET.md`.
- `already_used_names` um ALLE bisher verwendeten Datensaetze erweitern
  (Template-Projekte + alle bisherigen externen Datensaetze - Liste aus
  der letzten Version des Selektionsskripts uebernehmen und ergaenzen).
- **NEUER, dokumentierter Seed** fuer jede Ziehung (z.B. `set.seed(
  20260901)`, Datum der Ziehung) - NIEMALS den alten Seed auf dem
  reduzierten Pool wiederverwenden, das waere KEINE echte Fortsetzung
  der urspruenglichen Ziehung, sondern ein anderes, vom reduzierten Pool
  abhaengiges Ergebnis (siehe Kopfkommentar der bisherigen
  Selektionsskripte fuer die genaue Begruendung).
- Metadaten ueber OpenMLs eigene "qualities" abrufen (NICHT `$data()`
  aufrufen nur fuer Metadaten - loest bei grossen Datensaetzen wie
  CIFAR_10/Fashion-MNIST einen vollen ARFF-Download aus). Bereits
  abgerufene Metadaten (`_artifacts/cc18_full_metadata.csv`) wenn
  vorhanden wiederverwenden statt erneut abzufragen.
- Ergebnis in `EXTERNAL_BENCHMARK_SET.md` dokumentieren (neue
  Ueberschrift "n=X->Y" mit Tabelle) UND sofort committen/pushen -
  BEVOR irgendein Modell-Lauf stattfindet. Das Einfrieren-vor-Berechnung
  ist der ganze Sinn dieser Methodik (Benchmark Selection Bias
  vermeiden).

### 2. Projektordner anlegen

Fuer jeden neuen Datensatz einen `ML_Learning/openml-cc18-<name>/`-
Ordner:

- **Generische Skripte IMMER aus dem ZENTRALEN Template kopieren**
  (`MLR3_Classifikation/*.R`), NIEMALS aus einer bestehenden lokalen
  Projekt-Kopie (`openml-cc18-cmc/` o.ae.) - lokale Kopien koennen
  veraltete, ungepatchte Versionen enthalten (echter Vorfall: der
  `class_multiplier_tuning.R`-OOM-Fix war in 5 von 6 bestehenden Kopien
  nie nachgezogen worden und wurde beim Kopieren als Vorlage
  reproduziert, siehe BACKLOG.md 2026-09-01).
- Zu kopieren: `db_logging.R`, `db_schema.sql`, `class_multiplier_
  tuning.R`, `decision_stability.R`, `hard_split_stress_test.R`,
  `outer_workflow_evaluation.R`, `outer_workflow_evaluation_v2_fair_
  baselines.R`, `outer_workflow_evaluation_v3_level2.R`,
  `decision_stability_level2_prototype.R`, `hard_split_stress_test_
  prototype.R`.
- Neu schreiben: `000_config.R` (seed=42, target_col als grobe Schaetzung
  - wird beim ersten `020_task.R`-Lauf durch den echten OpenML-
  Zielspaltennamen bestaetigt, `openml_did`, `baseline_measure_ids =
  c("classif.bacc", "classif.mcc")`, `class_weight_power = 1.5`) und
  `020_task.R` (laedt via `mlr3oml::odt()`, speichert `task_train_
  small.rds`).
- `020_task.R` braucht `000_config.R` bereits geladen - beim manuellen
  Testen `source('000_config.R'); source('020_task.R')` in EINEM
  R-Aufruf, nicht `020_task.R` allein ausfuehren (crasht mit "Objekt
  'openml_did' nicht gefunden").

### 3. Level-2-Prototyp je Datensatz

`Rscript outer_workflow_evaluation_v3_level2.R` je Projektordner.

- **SEQUENZIELL, nicht mehrere gleichzeitig im Hintergrund** - ein
  paralleler Lauf hat einmal einen echten OOM-Crash (38GB-Allokation)
  UND bei einem anderen Lauf verschluckte stdout-Pufferung die
  Konsolen-Ausgabe (Ergebnis im gespeicherten `.rds` aber trotzdem
  korrekt, siehe BACKLOG.md). Kleinere/schnellere Datensaetze zuerst,
  groesste zuletzt.
- Delta = `level2_workflow`-Mittelwert minus bester Baseline-Arm-
  Mittelwert (`ranger_default`/`lightgbm_default`), in BAcc-Punkten.
- Bei einem Fehler "cannot allocate vector of size X Gb": zuerst
  pruefen, ob `class_multiplier_tuning.R` im Projektordner die
  `max_grid_combos`-Obergrenze enthaelt (`grep -n max_grid_combos`) -
  falls nicht, ist es der bekannte Bug, Fix aus dem zentralen Template
  kopieren.

### 4. Decision-Stability je Datensatz, alle 3 Outer-Folds

Fuer jeden Datensatz:

```bash
for f in 1 2 3; do
  DECISION_STABILITY_OUTER_FOLD=$f Rscript decision_stability_level2_prototype.R > "decision_stability_fold${f}.log" 2>&1
done
```

Ergebnis je Fold aus dem Log: `grep -n "Verteilung:\|Mehrheitsentscheidung:"`.

### 5. Korrelationsanalyse aktualisieren

Ein neues Skript `decision_stability_level2_analysis_n<X>.R` nach dem
Muster von `decision_stability_level2_analysis_weg_b.R`/`_n15.R`
schreiben - ALLE bisherigen Datensaetze (nicht nur die neuen) mit
`stab_fold1/2/3` und `delta_level2` auflisten, `avg_stability`
berechnen, Spearman-Korrelation gegen `delta_level2`. Immer auch den
Vergleich ueber alle bisherigen Stichprobengroessen ausgeben (n=6 vs.
n=10 vs. n=X) - zeigt, ob das Ergebnis stabil bleibt oder kippt.

### 6. Evidence-Logging + Dokumentation + Commit

- Ein Logging-Skript nach dem Muster von `log_weg_b_evidence.R`/
  `log_n15_evidence.R`: Level-2-Ergebnisse (`role="score_lever"`),
  Decision-Stability-Ergebnisse je Fold (`role="trust_gate"`), die
  uebergreifende Korrelation (`role="trust_gate", status="negative"`
  falls weiterhin kein Zusammenhang).
- `BACKLOG.md`: neuer Abschnitt mit Level-2-Tabelle, Decision-Stability-
  Tabelle, Korrelationsergebnis, Vergleich zu fruegeren n, Fazit.
- Zwei separate Commits: `MLR3_Classifikation` (Selektionsskript,
  `EXTERNAL_BENCHMARK_SET.md`, Analyseskript, `BACKLOG.md`) UND
  `ML_Learning` (neue Projektordner, lokal, kein Remote).
- Statusanker nur auf explizite Nutzeranweisung "Statusanker
  aktualisieren und committen" aktualisieren, nicht automatisch.

## Bekannte Stolpersteine (bereits einmal aufgetreten)

- Bash-Variable in Pfaden: `"...\$d\..."` escaped `$d` in doppelten
  Anfuehrungszeichen (Backslash vor `$` macht es literal) - fuer
  Windows-Pfade mit Variablen `/` statt `\` verwenden oder die
  Variable nicht direkt hinter einem Backslash platzieren.
- `Get-Process | Where-Object {$_.WS...}` ueber die Bash-Tool-
  `powershell -Command "..."`-Bruecke: `$_` wird von Bash VOR
  PowerShell interpretiert und zerstoert den Ausdruck - fuer
  `$_`-Referenzen das PowerShell-Tool direkt verwenden, nicht die
  Bash-Bruecke.
- Ein `run_in_background: true`-Bash-Aufruf, dessen Kommando selbst
  noch ein trailendes `&` enthaelt, kann eine VERFRUEHTE "completed"-
  Meldung erzeugen (der Hintergrundprozess laeuft in Wirklichkeit
  weiter) - niemals `&` innerhalb eines bereits als Hintergrund
  markierten Kommandos verwenden, stattdessen den Befehl normal
  (ohne eigenes `&`) uebergeben und `run_in_background: true` allein
  die Backgrounding-Arbeit machen lassen.
