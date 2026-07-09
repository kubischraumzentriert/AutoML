# Anleitung: `targets`-Pipeline

Diese Datei erklärt, wie unsere `targets`-Pipeline (`_targets.R`) funktioniert,
welche Befehle man im Alltag braucht, und was zu tun ist, wenn dieser Workflow
auf einen neuen Klassifikationsaufgaben-Wettbewerb übertragen werden soll.
Für die inhaltlichen Ergebnisse (welches Modell, welche Klassengewichtung,
welche Features) siehe `README.md` - hier geht es nur um das *Werkzeug*.

## Das Wichtigste zuerst: Was `targets` NICHT macht

`targets` trifft **keine inhaltlichen Entscheidungen**. Es führt exakt den
Code aus, der in `_targets.R` und den referenzierten Konfigurationswerten
(`000_config.R`) steht - nicht mehr und nicht weniger.

Konkret: `submission_model_name <- "ranger"` in `000_config.R` legt fest,
dass `tar_make()` immer Ranger als finales Modell trainiert. Das bleibt so,
**auch wenn ein besseres Modell existieren würde**, das wir nicht eingebaut
haben. Ob Ranger tatsächlich das beste Modell ist, wurde durch die
explorativen Skripte (`080`-`145`) und manuelle Analyse entschieden - nicht
durch `targets`. Wenn sich die Faktenlage ändert (z.B. ein neuer Datensatz,
eine neue Idee), muss ein Mensch (oder eine KI) das erneut untersuchen und
die Config/den Pipeline-Code entsprechend anpassen. `targets` automatisiert
danach nur noch die *Ausführung* dieser Entscheidung - zuverlässig,
nachvollziehbar, ohne unnötige Neuberechnung.

## Grundkonzept

- **Ziel (Target)**: ein benanntes R-Objekt, erzeugt durch ein Code-Snippet
  (`tar_target(name, command)`). Wird nach der Berechnung in `_targets/objects/`
  gecacht.
- **Abhängigkeitsgraph**: `targets` erkennt automatisch per Code-Analyse,
  welches Ziel von welchem abhängt - taucht der Name von Ziel A im Code von
  Ziel B auf, hängt B von A ab. Keine manuelle Verkabelung nötig.
- **Caching/Invalidierung**: `targets` hasht sowohl die Konfigurationswerte
  als auch den Code jedes Ziels (inklusive aufgerufener Funktionen aus
  `000_config.R`/`features/*.R`). Ändert sich einer der beiden, gilt das Ziel
  und alles Nachgelagerte als veraltet und wird bei `tar_make()` neu gebaut -
  alles andere bleibt unverändert im Cache und wird übersprungen.

## Befehlsübersicht

Alles wird aus einer R-Konsole mit Arbeitsverzeichnis im Projektordner
ausgeführt (wo `_targets.R` liegt), z.B.:

```r
setwd("C:/Users/HP/OneDrive/Dokumente/R_Workspace/MLR3_Classifikation")
library(targets)
```

| Befehl | Zweck |
|---|---|
| `tar_make()` | Hauptbefehl: baut alles Veraltete/Fehlende neu, überspringt den Rest |
| `tar_visnetwork()` | Zeigt den Abhängigkeitsgraphen interaktiv (gruen = aktuell, andere Farbe = muss neu laufen) - **vor** `tar_make()` aufrufen, um zu sehen, was passieren wuerde |
| `tar_outdated()` | Listet nur die Namen der veralteten Ziele auf |
| `tar_manifest()` | Zeigt Zielliste + Code, ohne etwas auszuführen (schnelle Strukturpruefung) |
| `tar_read(name)` | Lädt ein Ziel aus dem Cache, um es anzuschauen (z.B. `tar_read(submission)`) |
| `tar_load(name)` | Wie `tar_read()`, legt das Ergebnis aber als Variable `name` in der Session ab |
| `tar_meta(fields = warnings)` | Zeigt Warnungen/Fehler aus dem letzten Lauf |

Aus dem Terminal (ohne R-Konsole zu öffnen) geht es auch direkt:

```bash
Rscript -e "targets::tar_make()"
```

## Unsere Pipeline im Überblick (17 Ziele)

`_targets.R` bildet den *finalen* Workflow ab (entspricht den nummerierten
Skripten `020`/`025`/`070`/`150`/`155`), in vier Phasen:

1. **Rohdaten** (`train_raw_file`, `train_raw`, `test_file`, `train_full_file`,
   `train_full`) - laedt `train.csv`/`test.csv`.
2. **Feature-Familien und 10%-Subset-Tasks** (`feature_family_name` →
   `task_family` als **dynamisch verzweigtes Ziel**, ein Branch pro Eintrag in
   `feature_families`; dazu `task_raw`, `task_combined`, `task_selected`).
3. **Finale Modelle auf dem Subset** (`model_name` → `final_model_subset`,
   ebenfalls dynamisch verzweigt über `model_feature_sets`).
4. **Volles Training & Submission** (`train_full`, `full_feature_levels`,
   `task_full`, `task_full_weighted`, `final_model_full`, `submission`).

Die **dynamische Verzweigung** (`pattern = map(...)`) ist der Grund, warum wir
z.B. für sechs Feature-Familien nicht sechs fast identische `tar_target()`-
Aufrufe schreiben mussten - ein Branch pro Eintrag in `feature_families`
entsteht automatisch. Fügt man in `000_config.R` eine siebte Familie hinzu
(und die passende Funktion in `features/`), erzeugt `tar_make()` beim
nächsten Lauf automatisch einen siebten Branch, ohne dass `_targets.R`
angefasst werden muss.

**Bewusst nicht in dieser Pipeline enthalten**: die explorativen Skripte
`030`-`145` (Baselines, Boosting-Vergleich, Klassengewicht-Kurven, Ranger-
Tuning, Ensemble-Test, Adversarial Validation, ...). Die dienten der
*einmaligen* Modellauswahl fuer *diesen* Wettbewerb, nicht einem
wiederholbaren Produktions-Workflow. Fuer einen neuen Wettbewerb muesste man
dieselben *Fragen* erneut stellen (siehe Checkliste unten), aber das ist
Analysearbeit, die `targets` nicht automatisiert - nur die Vorlage
(Methodik/Code-Struktur der Skripte) ist wiederverwendbar.

## Praktisches Beispiel: Etwas aendern und neu bauen

Angenommen, du willst `class_weight_power` von 1.5 auf 1.75 testen:

1. Aendere den Wert in `000_config.R`.
2. `targets::tar_visnetwork()` - du siehst: `task_full_weighted`,
   `final_model_full` und `submission` sind jetzt als veraltet markiert
   (haengen von `class_weight_power` ab). `task_family`, `task_combined` etc.
   bleiben unveraendert (aktuell), da sie nicht von diesem Wert abhaengen.
3. `targets::tar_make()` - nur die drei veralteten Ziele werden neu berechnet
   (inkl. dem vollen Ranger-Training, ca. 12 Minuten). Der Rest kommt aus dem
   Cache, ohne neu zu laufen.
4. `submission.csv` (bzw. `targets::tar_read(submission)`) enthaelt das neue
   Ergebnis.

## Checkliste: Uebertragung auf einen neuen Kaggle-Wettbewerb

1. `train.csv`/`test.csv`/`sample_submission.csv` durch die neuen Dateien ersetzen.
2. `000_config.R`: `id_col`, `target_col`, `baseline_measure_ids` (die Ziel-
   metrik ist wahrscheinlich eine andere als BAcc/MCC!), `feature_families`/
   `selected_families`, `model_feature_sets`, `model_class_weight_power`,
   `submission_model_name` neu befuellen.
3. `features/*.R` durch neue, domaenenspezifische `add_<familie>_features()`-
   Funktionen ersetzen (oder zunaechst leer lassen, falls noch kein Feature
   Engineering feststeht).
4. Falls ein neues Modell `submission_model_name` werden soll, das noch nicht
   in `base_learner_constructors` (`000_config.R`) steht: dort ergaenzen.
5. `_targets.R` selbst muss dabei in der Regel **nicht** angefasst werden -
   der Graph (welches Ziel von welchem abhaengt) bleibt strukturell gleich,
   er liest nur die neuen Config-Werte.
6. Vor dem finalen `tar_make()`: die Methodik aus `030`-`145` (als Vorlage,
   nicht als Copy-Paste) fuer den neuen Datensatz wiederholen - Feature-
   Familien testen, Modelle vergleichen, Klassengewichtung pruefen,
   Adversarial Validation - und die Ergebnisse in Schritt 2/4 einfliessen
   lassen. Alle diese Skripte loggen automatisch in `_artifacts/experiments.db`
   (siehe README.md, Abschnitt "Experiment-Tracking (SQLite)") - fuer einen
   neuen Wettbewerb reicht ein neuer `project_name` in `000_config.R`, Schema
   und Logging-Code bleiben unveraendert.

## Bekannte Einschraenkung

`task_full`/`final_model_full` unterstuetzen aktuell nur
`model_feature_sets[[submission_model_name]] == "raw"` (siehe `stop()` in
`_targets.R`). Soll das finale Modell stattdessen ein `"features"`- oder
`"selected"`-Feature-Set auf dem **vollen** Datensatz nutzen, muss diese
Stelle erweitert werden (entsprechendes Feature Engineering muesste dann auch
fuer den vollen Datensatz existieren, nicht nur fuer das 10%-Subset).
