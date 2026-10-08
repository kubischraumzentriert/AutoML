# Session Handoff: 2026-10-08 - S6E10 P0/P1-Backports

Vorherige Template-Historie: SESSION_HANDOFF_2026-09-18.md.
Dieser Anker dokumentiert die begrenzten P0/P1-Backports, keine Neubewertung
der frueheren Forschung/Publikationsplanung.

## Qualifiziert und umgesetzt

- 015: restore_lightgbm_importance_names im bestehenden Helper-Modul.
  Originalnamen fuer Leerzeichen-/Unterstrich-Normalisierung, Reihenfolge
  und Werte unveraendert; Kollisionen/fehlende/unknown Namen abbrechen.
  Kollisionen werden auch vor einem vermeintlichen Exact-Match erkannt.
- 030: Abschluss-Provenienz nutzt das tatsaechlich instanziierte
  Resampling des Benchmarks statt der uninstanziierten Eingabevorlage.
  Die fruehere Beschreibung als undefinierte Variable war ungenau.
- Fuenf neue Mapping-Testfaelle (inklusive echter LightGBM-Integration)
  und ein Benchmark-/SQLite-Regressionstest fuer den echten 030-Aufruf.
- Template-health_condition: vorhandene Importance-Werte/Namen exakt
  unveraendert; keine neue Modellauswahl oder Score-Behauptung.
- ADR-003: defensive No-op-Qualifikation, kein zweiter Nutzen-Pilot fuer
  neue Modelltechnologie erforderlich. Kein ADR-/DB-Schema-Umbau.

## Pruefungen

- Gezielte Tests und health_condition-No-op bestanden.
- Volle Suite: 33 Testdateien ohne Fehler bei LC_CTYPE
  English_United States.utf8; nur Package-Build-Warnungen.
- Erster Gesamtlauf unter ungueltiger Startup-Locale C.UTF-8 hatte drei
  Unicode-Symbolfehler im unveraenderten generate_systematic_evaluation-
  Test. Locale-Gegenprobe und erneuter Gesamtlauf bestanden.
- Anleitung in tests/README.md, kein Windows-Zwang im generischen Runner.
- Logs: _artifacts/p0_backport_checks.log, p0_full_suite.log,
  p0_full_suite_utf8.log; No-op-Bericht p0_backport_regression.rds.

## Offen / Weiter

- Nutzerfreigabe fuer Commit und Push der Template-P0/P1-Aenderungen
  am 2026-10-08; Commit-/Remote-Ergebnis im Git-Verlauf nachvollziehbar.
  Lokale S6E10-Commits bleiben 9830c03 und 9dbb22c im getrennten
  ML_Learning-Repo; keine S6E10-Daten/Modelle im Template-Push.
- Task-P1 erledigt: 000_config apply_positive_class, 023 foldweise
  Median-/Modus-Imputation plus Rollen nach CSV/RDS-Laden; 150 effektive
  positive Klasse im Task, additiv im Bundle und Manifest.
- Naechster P1: generischer Submission-Vertrag (Spalten/IDs/P(TRUE),
  Modellreferenz und Hashes), danach Kandidaten-/Einreichungsstatus.
- S6E10 unveraendert: 200 Iterationen, raw; Public AUC laut Nutzer 0.95785.
  400er-Kandidat in zwei CVs verworfen; kein weiterer Upload/Full-Train.

## Task-P1-Pruefungen

Sieben neue Task-/Lade-/Bundle-Testfaelle und drei Imputationsfaelle
bestanden. NULL behaelt Defaults/Caches, Multiclass positive bleibt NA,
ungueltige binaere Klasse wird abgewiesen. Fold-Imputation nachgewiesen:
Trainingsmedian 4 und Modus a trotz extremer heldout-Werte/globalem Modus b.
Bei vollstaendigen Daten identische Ranger-Wahrscheinlichkeiten/Labels.
Lernkurven mit NAs: binaer/multiclass, drei Groessen und LogLoss endlich.

Template-health_condition-Gegenprobe: 300 vollstaendige Zeilen, 13 Features
aus vorhandenem Task; positive Klasse/Stratum/Labels/Probabilities identisch.
Vollstaendige Zeilen bewusst selektiert, weil der Originaltask NAs hat.
Keine No-op-Behauptung fuer fehlende Werte oder bisher unstratifizierte CV;
diese Diagnose-Korrekturen duerfen die Scores aendern. Keine neuen
Modell-/Thread-Defaults, kein Score-Hebel allgemein bestaetigt.

Volle Suite: 35 Testdateien unter UTF-8-Locale ohne Fehler. Logs:
_artifacts/p1_targeted_checks.log, p1_full_suite_utf8.log,
p1_template_noop.log und p1_template_noop.rds (Input-/Codehashes).
Konfiguration 000_config bei spaeterer Projekt-Aktualisierung gemeinsam
mit 023/150 kopieren. Lokales S6E10 blieb unveraendert.

## Generischer Submission-Vertrag abgeschlossen

P0/Task-P1 wurden als 694c88c nach origin/main gepusht. Die folgenden
Export-Aenderungen sind neu und noch nicht committed/gepusht:

- modules/submission_contract.R mit reinen Vertragschecks und sichtbarem
  staged CSV-I/O. Standard: eine ID + binaere Probability oder Labels.
- 155: project-scoped completed model snapshot (ID/Datei/Manifest),
  Modell-SHA256, Constructor-Parameter, Feature-Set/Transformationshash;
  Faktorlevels nicht still zu NA umwandeln. CSV-Rundweg vor Uebernahme.
- 155 --validate-only: bestehende CSV gegen frische Vorhersagen pruefen,
  kein Training/Datei-Overwrite; lokaler Pruefbericht und DB-run/run_config.
  Kein submitted-Eintrag oder externer Score.
- _targets: gleicher Export, P(positive) statt bisheriger Labels bei
  binaerer Prob-Metrik; Full-Task-Klasse konsistent. Optionales Sample-
  Filetarget mit always-Cue fuer spaeter hinzugefuegte Sample-Datei.
- Konstante Wahrscheinlichkeiten sind gueltig. Mehrspaltige Multiclass-
  Prob-Formate verlangen eigene Zuordnung und brechen bewusst ab.
- Ohne Sample keine Sample-Pruefung; im 155-Bericht sichtbar.
- Nacharbeit zur vorigen P1-Phase: eigene CI-Smoke-Config um den fehlenden
  apply_positive_class-Helper ergaenzt; Konsistenztest verhindert Drift.

Pruefung: 37 Testdateien unter UTF-8 ohne Fehler. End-to-end Rscript-
Fixtures mit rpart/SQLite fuer binaere Probabilities und Multiclass-Labels;
Fremdprojekt/unfinished model nicht ausgewaehlt, falsche Probability-Spalte
und stale Parameter abgewiesen, targets-Ausdruck bytegleich zu 155.

Template-eigene Label-CSV: 295753 Zeilen byteidentisch durch den neuen
Writer roundgetrippt, keine neue Modell-/Score-Evaluation. S6E10 rein
lesend: Originalmodell-/Submissionhashes und alle IDs/Format gueltig,
256 frisch berechnete P(TRUE)-Werte mit max. Fehler 5.55e-16; keine
Projektdatei/DB geaendert. ADR-003 defensive Export-Qualifikation.

Echter isolierter 023-CI-Smoke-Lauf auf 800 Zeilen abgeschlossen.
Optionaler empty targets-Filetarget und Produktionsgraph-Kompilation
mit installiertem Runtime geprueft; kein produktives tar_make/Full-Train.
Logs/Berichte: _artifacts/submission_targeted_checks.log,
submission_full_suite_utf8.log, submission_s6e10_readonly.log/.rds,
submission_template_roundtrip.log/.rds und submission_smoke_023.log.

Naechste Aufgabe: Kandidaten-/Einreichungs-Protokollierung und Modell-
Zuordnung fuer 158 reviewen. Aktuell mconf_id aus dem Pruefbericht dort
explizit uebergeben; bisherige Latest-Helfer sind nicht project-scoped.
DB-Schema wurde nicht geaendert; ADR-006 vor einem Schema-Ausbau beachten.

## Kandidaten- und Score-Registry abgeschlossen

Die oben genannte naechste Aufgabe ist fuer registrierte 150/155-Artefakte
erledigt. Neue Aenderungen inkl. Export-Vertrag weiterhin uncommitted,
kein neuer Push; bisheriger Remote-Stand 694c88c.

modules/submission_registry.R pinnt CSV-SHA auf abgeschlossenen 155-
Kandidaten im passenden Projekt, dann auf dessen konkrete Modell-ID und
Modell-/Manifesthash. Keine Latest-Auswahl in 158 mehr. Mehrere Modelle
mit denselben Bytes verlangen --mconf-id; fremde/falsche Referenzen,
inkonsistente EAV-Metadaten und veraenderte Dateien werden abgewiesen.

run/run_config ist Kandidaten-/Event-Historie, submission_result Summary.
158 schreibt Event und Summary in einer Transaktion, haengt Ereignisse an
statt sie zu ersetzen. Reportete und effektive Scores getrennt; fehlende
Werte behalten bekannte Scores nur fuer gleichen CSV-SHA, nicht fuer neue
Bytes desselben Modells. Competition-Konflikte nicht ueberschreiben.
Metrik-Default aus Kandidat; Legacy ohne metric_name braucht explizites
Flag. Competition-Default bei Updates aus bestehendem Eintrag. Kein Upload.

db_list_submission_candidates/events als project-scoped Reader. Kein
DDL-/Schema-Umbau, keine Aenderung des Regression-Templates (ADR-006).
Alte Latest-Helfer bleiben fuer andere Aufrufer aus Kompatibilitaet.

Pruefung: 38 Testdateien unter UTF-8 ohne Fehler. Direkte Score-Upsert-
Regressionen und Rscript-/SQLite-End-to-end: alter Kandidat trotz neuerem
Modell, Partial-Score-Erhalt, Mehrdeutigkeit/explicit ID, Competition-,
CSV-, Modell- und CLI-Fehler ohne Ghost-Events. History bleibt erhalten.

Legacy-S6E10: Kopie der bestehenden DB rein lesend abgefragt; Kandidat
95a61fae-9707-40d5-b599-c0aa06e18659, Modell
085ee4b0-b350-4c34-9759-d5de7cfeea91, Public 0.95785/Private unbekannt.
Original-DB-/CSV-Hashes unveraendert; keine Neuregistrierung vorgenommen.
Evidenz: _artifacts/registration_targeted_checks.log,
registration_full_suite_utf8.log, registration_s6e10_readonly.log/.rds.

Die hier noch offene Bridge fuer targets-Cache und 156/157 ist im
nachfolgenden Arbeitsblock umgesetzt. Weiterhin kein Validierungs-Bypass;
unregistrierte Dateien bekommen keine geratenen IDs.
158 zusammen mit neuem db_logging/provenance/Registry-Modul kopieren.

## Targets-/Ensemble-Registrierungsbruecke (2026-10-08)

modules/submission_artifacts.R: gemeinsames transaktionales Kandidaten-Logging
inkl. Pruefbericht sowie Modell-SHA-Pruefung, targets-Persistenz und validiertes
Ensemble-Mittel. 155 verwendet denselben Logger wie 157 und targets.

targets final_model_artifacts: eindeutiges Modell-RDS plus Referenz-RDS als
format=file. DB-Modellworkflow _targets.R; Submissionworkflow _targets_submission.
Export nutzt das gespeicherte Modell statt einer geratenen neuesten DB-Zeile.
Unveraenderter zweiter Lauf erhaelt Modell-ID/Kandidat; geaendertes Artefakt
invalidiert das Datei-Target. DB-Fehler rollt Run zurueck und entfernt neue RDS.
SQLite bewusst kein Datei-Target: nach DB-Verlust wiederherstellen oder beide
Artefakt-/Submission-Targets invalidieren, siehe EXPERIMENTS_DB.md.

156 speichert positive_class additiv; 157 prueft registrierten Modell-SHA,
raw-Features, Gewichte, Klassen, Faktoren und CSV-Vertrag. --validate-only
ohne Training/Dateiaenderung; Einzelmodell-CSV unveraendert. 158 bestimmt
Trainingsworkflow aus gepinnter Modell-ID (150/156/targets); optionaler
--workflow-name bleibt Filter. Keine DDL oder neue externe Scores.

ADR-003-No-op: vorhandenes health_condition-Ensemble, 256 Testzeilen,
Probabilitaeten bit-identisch zum bisherigen gewichteten Mittel; Modell-SHA
unveraendert. Evidenz: _artifacts/bridge_template_noop.log. Kein reales
Full-Training/Upload und keine Aenderung am lokalen S6E10-Projekt.

Noch nicht committet/gepusht; letzter Remote-Stand weiterhin 694c88c.
Volle Suite: 38 Testdateien, UTF-8, ohne Fehler; nur bestehende
Paket-Build-Warnungen. Produktionsgraph mit 20 Targets geparst.
Evidenz: _artifacts/bridge_full_suite_utf8.log. Tatsachliche tar_make()-
Cache-Laeufe isoliert per Rscript, keine produktive Pipeline gestartet.
Naechster fachlicher Backlog-Punkt: kontrollierte LightGBM-Seeds/Threads
und gepaarte Bestaetigung als generischen Versuchsbaustein qualifizieren.

## LightGBM Seed-/Thread-Screening (2026-10-08)

093_lightgbm_seed_thread_stability.R ist neu und misst auf dem bestehenden
health_condition-10%-Task bei fixer Holdout-Zerlegung drei Seeds (42/43/44)
und zwei Threadzahlen (1/4), jeweils 200 Iterationen. Ergebnis: sechs Mal
classif.bacc 0.8733064, SD ueber Seeds/Threads 0, jede gepaarte Thread-
Differenz 0. Threads 4 brauchten ca. 15-18 s je Fit, Threads 1 ca. 9-10 s.
Kein Score-Hebel; keine Konfigurationsaenderung im Template empfohlen.

DB-Run `6f204de2-489b-4adc-9bc0-91edd1f44c09`, sechs Modellkonfigurationen.
Artefakte: `_artifacts/lightgbm_seed_thread_results.csv`,
`_artifacts/lightgbm_seed_thread_paired.csv`,
`_artifacts/lightgbm_seed_thread_summary.csv`,
`_artifacts/lightgbm_seed_thread_artifact.rds`, Log
`_artifacts/lightgbm_seed_thread_db_retry.log`. Der erste Lauf hatte nur
einen SQLite-Loggingfehler wegen NULL-Holdout-Folds; der erfolgreiche Lauf
verwendet explizit `folds = 1`. Keine Produktionssubmission und kein Upload.
