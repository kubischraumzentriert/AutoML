---
name: pilot-external-technique
description: Testet eine extern gefundene Technik (Paper, Kaggle-Writeup, Seminar) systematisch an mehreren kleinen OpenML-CC18-Projekten, bevor eine Faustregel formuliert oder ein Backport ins Template erwogen wird (ADR-003). Nutzen, wenn der Nutzer eine externe Idee ausprobieren will ("sollten wir X probieren", "koennte das ins Template?") oder "noch 2 Projekte" fuer einen laufenden Pilot anfragt.
---

# Externe Technik pilotieren (Setup + Eskalationsdisziplin)

Wiederholbares Verfahren, entstanden aus dem Reshuffling-/Ensemble-
Diversitaets-Pilot (2026-09-04 bis -06, siehe `BACKLOG.md` fuer den
vollstaendigen Durchlauf als Referenz, `adr/003-backport-after-
confirmation.md` fuer die Eskalationsklausel).

## Wann anwenden

Der Nutzer moechte eine extern gefundene Idee (Paper, Kaggle-Writeup,
Konferenz-/Seminar-Fund) systematisch testen, bevor sie als Faustregel
dokumentiert oder ins Template backported wird - typischerweise bei
kleinen/mittleren Datensaetzen, wo ein Effekt am ehesten sichtbar waere.

## Ablauf

### 1. Setup fuer ein kleines CC18-Projekt (pro Kandidat wiederholt)

Viele kleine externe Benchmark-Projekte (`openml-cc18-*`) haben bisher
NUR die Decision-Stability-/Hard-Split-Stresstest-Infrastruktur, keine
numerierte Tuning-/Ensemble-Pipeline. Fuer einen Pilot-Test braucht es
typischerweise (aus dem zentralen Template kopiert, NIEMALS aus einer
anderen lokalen Projekt-Kopie - siehe `extend-benchmark-set`-Skill):

- `005_benchmark_runtime.R`, ggf. `090_ranger_tuning.R`,
  `147_error_analysis_ranger_models.R`, `148_ensemble_candidate_pool.R`,
  `149_ensemble_selection.R`, `ensemble_selection.R`, `db_logging.R`,
  `db_schema.sql`, `provenance.R` - je nach getesteter Technik.
- **Config-Ergaenzungen**, die ein minimales `000_config.R` (nur
  `seed`/`target_col`/`baseline_measure_ids`/`class_weight_power`/
  `openml_did`) fast immer NICHT enthaelt: `project_name`,
  `task_id_prefix <- project_name`, `validation_ratio`, `cv_folds`,
  `error_analysis_models_path`, `ensemble_pool_n_per_family`,
  `ensemble_candidate_pool_path`, `ensemble_selection_rounds`,
  `ensemble_selection_valid_ratio`, `ensemble_selection_results_path`,
  `ensemble_composition_path`, `lightgbm_tuning_final_iterations`, sowie
  die Helferfunktionen `enable_class_stratification()`,
  `add_balanced_class_weights()`, `feature_set_from_task_id()`,
  `algorithm_from_learner_id()` (alle aus dem zentralen `000_config.R`
  uebernehmbar, dort als Referenz nachschlagen).
- `task_train_small.rds` liegt bei den meisten `openml-cc18-*`-Projekten
  (aus der Decision-Stability-Arbeit) bereits in `_artifacts/` - vor dem
  Kopieren pruefen, `020_task.R` muss dann NICHT erneut laufen.

**Bash-Falle**: `\\.` (fuer eine R-Regex wie `grepl("classif\\.", ...)`)
in einem Bash-Heredoc/`printf` wird oft zu `\.` zusammengestrichen (von
Bash vor der Uebergabe entfernt) - das ist in R ein ungueltiges Escape
und bricht das Skript erst beim Ausfuehren, nicht beim Schreiben. Fix:
R-Code mit Escapes NICHT per inline `printf`/Heredoc schreiben, sondern
per Write-Tool in eine Datei (z.B. `config_addition.R` im Scratchpad),
dann `cat datei >> ziel_config.R` - das Anhaengen per `cat` transportiert
den Dateiinhalt byte-genau, ohne dass die Shell nochmal durch die
Escape-Verarbeitung geht.

### 2. Bekannte datensatzspezifische Fallstricke - pragmatisch ersetzen, nicht debuggen

Diese Fehler sind NICHT das eigentliche Thema des Pilots - beim
Auftreten den Datensatz durch einen anderen kleinen CC18-Kandidaten
ersetzen, statt Zeit in eine Reparatur zu stecken:

- **LDA + Kollinearitaet**: `lda.default(...) : Variablen ... scheinen
  innerhalb der Gruppen konstant zu sein` - manche Datensaetze haben
  nach Median-/Modus-Imputation kollineare/konstante Spalten je Klasse
  (Fund: `openml-cc18-dresses-sales`).
- **LDA + fast komplett fehlende Spalte**: `has missing values in
  column(s) 'X', but learner 'classif.lda' does not support this` -
  eine numerische Spalte kann so gut wie vollstaendig NA sein, sodass
  auch `median()` bei der manuellen Imputation NA bleibt (Fund:
  `openml-cc18-sick`, Spalte `TBG`).

### 3. Eskalationsdisziplin (ADR-003-Ergaenzung, siehe dort fuer den
vollen Wortlaut)

- Die formale ADR-003-Mindestschwelle (>=2 unabhaengige Projekte) reicht
  NUR, wenn beide Bestaetigungen KONSISTENT sind (gleiches Vorzeichen,
  vergleichbare Groessenordnung) UND die gemessene Groesse nicht
  offensichtlich rauschanfaellig ist (kleine Stichproben, Benchmark-
  Deltas).
- Bei einem knappen/uneindeutigen Ergebnis ODER einer von Natur aus
  rauschanfaelligen Messung: NICHT bei n=2 eine Faustregel formulieren.
  Auf n>=4 erweitern.
- **Auch n=4 ist keine garantierte Grenze** - im eigenen Pilot kippte
  das Bild bei n=4 (2 positiv/2 negativ), erst n=10 ergab ein stabiles
  Gesamtbild. Es gibt keine feste Ziel-Zahl - massgeblich ist, ob der
  Befund bei weiterer Erweiterung STABIL bleibt (Vorzeichen/
  Groessenordnung wiederholen sich) oder weiter durchmischt (dann: kein
  verlaesslicher Effekt, Pilot mit dieser ehrlichen Schlussfolgerung
  abschliessen, KEIN Backport).
- Ein "kein Unterschied"-Ergebnis (Deckeneffekt, identische Werte) ist
  NICHT dasselbe wie ein negatives Ergebnis - beide zaehlen als eigene
  Kategorie bei der Gesamtauswertung, nicht als "positiv" umdeuten.
- Jede Zwischenauswertung (z.B. nach n=2) explizit als VORLAEUFIG
  kennzeichnen, bevor sie dokumentiert wird - eine bereits geschriebene
  Faustregel/Doku-Ergaenzung wird bei Erweiterung NICHT stillschweigend
  ueberschrieben, sondern per explizitem Korrektur-Eintrag zurueckgenommen
  (Nachvollziehbarkeit, siehe BACKLOG.md-Eintrag "Korrektur: ...").

### 4. Dokumentation

- Laufende Tabelle in `BACKLOG.md` fuehren (Projekt, Ergebnis, Vorzeichen),
  nicht erst am Ende zusammenfassen - bei jedem Batch von 1-2 neuen
  Projekten einen eigenen Commit mit Zwischenstand.
- Bei einer Korrektur: die vorherige Aussage nicht loeschen, sondern
  explizit als "Korrektur" referenzieren (welcher fruehere Eintrag
  widerlegt wird, warum).
- Abschliessendes Fazit immer mit der GENAUEN Verteilung (n positiv/n
  negativ/n kein Unterschied), nicht nur "es hat sich nicht bestaetigt".
- `docs/reference/REFERENZ_*.md` nur aktualisieren, wenn das
  Gesamtbild stabil ist (nach der Eskalation) - nicht nach jedem
  Zwischenschritt.
