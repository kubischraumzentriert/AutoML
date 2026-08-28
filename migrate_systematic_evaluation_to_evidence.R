# =====================================================================
# migrate_systematic_evaluation_to_evidence.R -- P1.2 Schritt 2:
# historische Befunde aus SYSTEMATIC_EVALUATION.md in die Evidence
# Registry (evidence-Tabelle) nachtragen.
# =====================================================================
# Einmaliges Migrations-Skript (kein Teil der nummerierten Pipeline,
# analog zu merge_project_experiments.R). Quelle: die grosse Projekt x
# Modul-Tabelle in SYSTEMATIC_EVALUATION.md (Stand "alle Zellen aufgeloest,
# 2026-08-15", siehe dortiger Kopf).
#
# Scope-Entscheidung: NUR Zellen mit einem echten Legenden-Symbol
# (✓/✓✓/~/✗) werden migriert - `—`-Zellen sind strukturelle Luecken
# ("Modul existiert nicht im Projekt"), kein Befund, und werden bewusst
# NICHT als eigene evidence-Zeile angelegt (das waeren >100 inhaltsleere
# Zeilen). Das deckt sich mit dem Plan-Wortlaut "wichtige historische
# Befunde nachziehen" - eine strukturelle Nicht-Anwendbarkeit ist kein
# Befund.
#
# Numerische Werte (AUC, BAcc, Prozentsaetze, z-Werte, ...) werden NICHT
# automatisiert aus dem Fliesstext geparst und in
# evid_baseline_value/evid_result_value/evid_delta gegossen - das waere
# bei uneinheitlicher Prosa (unterschiedliche Metriken, teils zwei Zahlen
# pro Zelle, teils Prozent vs. absolute Werte) fehleranfaellig und wuerde
# stillschweigend falsche Zahlen erzeugen. Stattdessen bleibt der
# komplette urspruengliche Zellentext (leicht gekuerzt um reine
# Klammer-Boilerplate wie "kein 115 im Projekt") als `notes` erhalten -
# durchsuchbar, aber nicht falsch-praezise.
#
# Rollen-Zuordnung je Spalte (fest, siehe BACKLOG.md/P1.2-Status):
#   015/115/022/023/092/136 (Diagnose-/Trust-Module)      -> trust_gate
#   148/149 (Ensemble Selection), 130 (Threshold-Tuning)   -> score_lever
#   021 (Multi-Label-Workflow)                             -> workflow_automation
#
# Status-Zuordnung aus der Legende:
#   ✓  -> confirmed   | ✓✓ -> core_finding | ~ -> neutral | ✗ -> negative

source("000_config.R")
source("db_logging.R")
source("evidence_registry.R")

evidence_source_label <- "SYSTEMATIC_EVALUATION.md (historischer Backfill, P1.2 Schritt 2, 2026-08-27)"

findings <- list(
  # --- health_condition (Template-eigen) ---------------------------------
  list(project = "health_condition", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed",
       notes = "stress_level 42.9%, kein Determinismus"),
  list(project = "health_condition", module = "115_adversarial_validation", role = "trust_gate", status = "confirmed",
       notes = "AUC 0.654, moderat, unschaedlich"),
  list(project = "health_condition", module = "022_split_size_sensitivity", role = "trust_gate", status = "confirmed", notes = NA),
  list(project = "health_condition", module = "023_learning_curve", role = "trust_gate", status = "confirmed",
       notes = "noch steigend, klein"),
  list(project = "health_condition", module = "092_seed_stability", role = "trust_gate", status = "confirmed", notes = NA),
  list(project = "health_condition", module = "136_generalization_gap", role = "trust_gate", status = "confirmed",
       notes = "engste bisher gemessene Luecke, +0.0025, SD 0.0032, unauffaellig"),
  list(project = "health_condition", module = "148_149_ensemble_selection", role = "score_lever", status = "core_finding",
       notes = "3./6. Bestaetigung, live s6e8 deployed"),
  list(project = "health_condition", module = "130_threshold_tuning", role = "score_lever", status = "core_finding",
       notes = "class_multiplier_tuning.R, kontinuierlicher Optimizer: OOF raw argmax 0.872->0.945 BAcc, +0.074 - groesster Einzelhebel des Projekts, unabhaengig vom Ensemble"),

  # --- CreditScoringChallenge (Zindi) ------------------------------------
  list(project = "CreditScoringChallenge", module = "015_target_leak_audit", role = "trust_gate", status = "core_finding",
       notes = "F1 0.88->0.41, echter Ex-post-Leak"),

  # --- PumpItUp (DrivenData) ----------------------------------------------
  list(project = "PumpItUp", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed",
       notes = "2. Bestaetigung, `ward` 28.5%, kein Leak"),

  # --- geoai-aquaculture-pond-identification-challenge (Zindi) -----------
  list(project = "geoai-aquaculture-pond-identification-challenge", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed",
       notes = "3. Bestaetigung, `re3_08` 27.5%, kein Leak"),
  list(project = "geoai-aquaculture-pond-identification-challenge", module = "115_adversarial_validation", role = "trust_gate", status = "core_finding",
       notes = "AUC 0.99998 roh / 0.978 Band-Mittel - echter, extremer Train/Test-Shift; ESS 2.6% -> Reweighting verworfen, Invarianz-Ansatz stattdessen"),

  # --- openml-satimage-multiclass -----------------------------------------
  list(project = "openml-satimage-multiclass", module = "022_split_size_sensitivity", role = "trust_gate", status = "confirmed",
       notes = "Faktor 1.26x, unauffaellig"),
  list(project = "openml-satimage-multiclass", module = "023_learning_curve", role = "trust_gate", status = "confirmed",
       notes = "noch steigend bei 100%"),
  list(project = "openml-satimage-multiclass", module = "092_seed_stability", role = "trust_gate", status = "confirmed",
       notes = "Seed-Varianz 0.23x/Jitter 0.21x, unauffaellig - aus README nachgetragen (kein eigenes 092-Skript im Ordner)"),
  list(project = "openml-satimage-multiclass", module = "136_generalization_gap", role = "trust_gate", status = "confirmed",
       notes = "2. Bestaetigung, z=1.03/z=0.50, kleinere/engere Hintergrund-Luecke als steel-plates-fault, unauffaellig"),

  # --- openml-steel-plates-fault -------------------------------------------
  list(project = "openml-steel-plates-fault", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed",
       notes = "1 Determinismus-Fund dokumentiert, nicht als Leak entfernt"),
  list(project = "openml-steel-plates-fault", module = "136_generalization_gap", role = "trust_gate", status = "confirmed",
       notes = "1. Bestaetigung, z=-1.63/z=-0.39, Hintergrund-Luecke -0.039 BAcc, beide Kandidaten innerhalb des Referenzbereichs"),
  list(project = "openml-steel-plates-fault", module = "130_threshold_tuning", role = "score_lever", status = "confirmed",
       notes = "1/prior schlaegt Grid: 0.840 vs. 0.832"),

  # --- openml-credit-g -------------------------------------------------------
  list(project = "openml-credit-g", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed",
       notes = "unauffaellig, Top-Feature `credit_amount` 26.9%, 0/68 Determinismus"),
  list(project = "openml-credit-g", module = "022_split_size_sensitivity", role = "trust_gate", status = "confirmed",
       notes = "Faktor 1.53x bei ratio=0.80, unauffaellig"),
  list(project = "openml-credit-g", module = "023_learning_curve", role = "trust_gate", status = "confirmed",
       notes = "NOCH STEIGEND, 23.1% des IQR - korrigiert 2026-08-15 (urspruenglich PLATEAU-Fehlmessung durch einen Ausreisser bei n=20, IQR-Nenner robuster)"),
  list(project = "openml-credit-g", module = "092_seed_stability", role = "trust_gate", status = "confirmed",
       notes = "2 Checks, 17.3%/16.6% relativ, beide unauffaellig"),
  list(project = "openml-credit-g", module = "136_generalization_gap", role = "trust_gate", status = "confirmed",
       notes = "unauffaellig, eigener 80/20-Split"),
  list(project = "openml-credit-g", module = "130_threshold_tuning", role = "score_lever", status = "confirmed",
       notes = "binaerer Nelder-Mead-Fix gefunden+behoben"),

  # --- playground-series-s6e5 -----------------------------------------------
  list(project = "playground-series-s6e5", module = "115_adversarial_validation", role = "trust_gate", status = "confirmed",
       notes = "AUC 0.4996, kein Shift"),
  list(project = "playground-series-s6e5", module = "148_149_ensemble_selection", role = "score_lever", status = "negative",
       notes = "KEIN 148/149 im Projekt - stattdessen 140_stack_ensemble.R (Logits-Stacking-Meta-Learner), negativ getestet: +0.00016 AUC ggue. bestem Einzelmodell, unter dem Rausch-Band, bei ~19x Rechenaufwand - nicht uebernommen"),

  # --- playground-series-s6e6 -----------------------------------------------
  list(project = "playground-series-s6e6", module = "115_adversarial_validation", role = "trust_gate", status = "confirmed",
       notes = "AUC ca. 0.4996, kein Shift, widerlegt Kardinalitaets-Artefakt-Verdacht aus s6e5"),
  list(project = "playground-series-s6e6", module = "148_149_ensemble_selection", role = "score_lever", status = "confirmed",
       notes = "5. Bestaetigung, Methodik-Test - lokal 146_ensemble_selection.R, gleiche Greedy-Ensemble-Selection-Methodik; laut Roh-CSV gewinnt der Greedy-Ensemble hier NICHT gegen das beste Einzelmodell, BAcc 0.9633 vs. 0.9638 - Mechanismus lief korrekt, aber ohne Performance-Gewinn"),

  # --- predictingsmartphoneAddiction_s6e8 ------------------------------------
  list(project = "predictingsmartphoneAddiction_s6e8", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed",
       notes = "nachgeholt 2026-08-17: daily_screen_time_hours staerkstes Feature 49.3% Gain-Share, knapp unter Einzelschwelle, kein Determinismus-Fund - unauffaellig, plausibles ex-ante-Signal"),
  list(project = "predictingsmartphoneAddiction_s6e8", module = "115_adversarial_validation", role = "trust_gate", status = "confirmed",
       notes = "AUC 0.565, moderat; ESS-Ratio 0.94, unschaedlich"),
  list(project = "predictingsmartphoneAddiction_s6e8", module = "148_149_ensemble_selection", role = "score_lever", status = "core_finding",
       notes = "6. Bestaetigung, live Kaggle-Submission"),

  # --- drivendata_richter -----------------------------------------------------
  list(project = "drivendata_richter", module = "115_adversarial_validation", role = "trust_gate", status = "confirmed",
       notes = "AUC 0.5002, kein Shift"),

  # --- openml-yeast-multilabel -------------------------------------------------
  list(project = "openml-yeast-multilabel", module = "130_threshold_tuning", role = "score_lever", status = "confirmed",
       notes = "Binary Relevance, 1. Bestaetigung"),
  list(project = "openml-yeast-multilabel", module = "021_multilabel_workflow", role = "workflow_automation", status = "confirmed",
       notes = "1. Bestaetigung"),

  # --- openml-scene-multilabel --------------------------------------------------
  list(project = "openml-scene-multilabel", module = "130_threshold_tuning", role = "score_lever", status = "confirmed",
       notes = "2. Bestaetigung"),
  list(project = "openml-scene-multilabel", module = "021_multilabel_workflow", role = "workflow_automation", status = "confirmed",
       notes = "2. Bestaetigung"),

  # --- openml-birds-multilabel --------------------------------------------------
  list(project = "openml-birds-multilabel", module = "130_threshold_tuning", role = "score_lever", status = "confirmed",
       notes = "3. Bestaetigung"),
  list(project = "openml-birds-multilabel", module = "021_multilabel_workflow", role = "workflow_automation", status = "confirmed",
       notes = "3. Bestaetigung"),

  # --- FinancialStressPredictionChallenge ---------------------------------------
  list(project = "FinancialStressPredictionChallenge", module = "115_adversarial_validation", role = "trust_gate", status = "confirmed",
       notes = "AUC 0.4971, kein Shift"),

  # --- openml-bank-marketing-ensemble-test ---------------------------------------
  list(project = "openml-bank-marketing-ensemble-test", module = "148_149_ensemble_selection", role = "score_lever", status = "confirmed",
       notes = "fruehe Ensemble-Selection-Bestaetigung, vor health_condition"),

  # --- openml-synthetic-control-timeseries -----------------------------------------
  list(project = "openml-synthetic-control-timeseries", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed", notes = "unauffaellig"),
  list(project = "openml-synthetic-control-timeseries", module = "022_split_size_sensitivity", role = "trust_gate", status = "confirmed",
       notes = "Faktor 1.25x, unauffaellig"),
  list(project = "openml-synthetic-control-timeseries", module = "023_learning_curve", role = "trust_gate", status = "confirmed",
       notes = "noch steigend, 45.4% des IQR - Zelle am 2026-08-17 korrigiert (stand veraltet als 17.5% seit vor dem IQR-Fix)"),
  list(project = "openml-synthetic-control-timeseries", module = "092_seed_stability", role = "trust_gate", status = "confirmed",
       notes = "SD=0.000, vollstaendig deterministisch"),
  list(project = "openml-synthetic-control-timeseries", module = "136_generalization_gap", role = "trust_gate", status = "confirmed",
       notes = "beide unauffaellig, z=0.05/-0.63"),
  list(project = "openml-synthetic-control-timeseries", module = "130_threshold_tuning", role = "score_lever", status = "confirmed",
       notes = "keine Verbesserung, exakt balancierte Klassen"),

  # --- playground-series-s5e12 (Kaggle) ---------------------------------------------
  list(project = "playground-series-s5e12", module = "115_adversarial_validation", role = "trust_gate", status = "confirmed",
       notes = "AUC 0.627, moderater aber echter Shift, Treiber physical_activity_minutes_per_week/triglycerides"),
  list(project = "playground-series-s5e12", module = "148_149_ensemble_selection", role = "score_lever", status = "negative",
       notes = "KEIN 148/149 im heutigen Sinn - lokal 148_select_submission_model.R/149_disagreement_check.R, ZWEI ANDERE Verfahren (datengetriebene Modellwahl aus experiments.db bzw. Uneinigkeits-Vertrauenscheck), keine Greedy-Ensemble-Selection; drittes Projekt nach s6e5/s6e6 mit diesem Namenskollisions-Muster"),
  list(project = "playground-series-s5e12", module = "130_threshold_tuning", role = "score_lever", status = "neutral",
       notes = "130_threshold_tuning.R im Ordner, aber keine Artefakte - Zielmetrik AUC ist schwellenwertunabhaengig, warn_if_threshold_step_low_value() greift; dasselbe Muster wie predictingsmartphoneAddiction_s6e8"),

  # --- openml-eeg-eye-state-timeseries -----------------------------------------------
  list(project = "openml-eeg-eye-state-timeseries", module = "015_target_leak_audit", role = "trust_gate", status = "confirmed", notes = "unauffaellig"),
  list(project = "openml-eeg-eye-state-timeseries", module = "023_learning_curve", role = "trust_gate", status = "confirmed",
       notes = "noch steigend, 31.0% des IQR - Zelle am 2026-08-17 korrigiert (stand veraltet als 14.7% seit vor dem IQR-Fix)"),
  list(project = "openml-eeg-eye-state-timeseries", module = "092_seed_stability", role = "trust_gate", status = "confirmed",
       notes = "unauffaellig, 0.23x/0.21x"),
  list(project = "openml-eeg-eye-state-timeseries", module = "136_generalization_gap", role = "trust_gate", status = "confirmed",
       notes = "beide unauffaellig, aber bisher hoechste z-Werte: z=1.67/1.27"),
  list(project = "openml-eeg-eye-state-timeseries", module = "130_threshold_tuning", role = "score_lever", status = "confirmed",
       notes = "binaerer optimize()/Brent-Pfad, modester Gewinn"),

  # --- wdbc-plateau-test (Diagnose-Testfall, kein reguläres Projekt) -----------------
  list(project = "wdbc-plateau-test", module = "023_learning_curve", role = "trust_gate", status = "core_finding",
       notes = "gezielt gebauter PLATEAU-Fall, 7.5% des IQR nach Mindest-n-Fix - erster echter Plateau-Fund")
)

cat(sprintf("Migriere %d historische Befunde aus SYSTEMATIC_EVALUATION.md in die evidence-Tabelle...\n", length(findings)))

con <- db_connect(experiments_db_path)
logged_ids <- character(0)
for (f in findings) {
  id <- db_log_evidence(
    con,
    project = f$project, module = f$module, role = f$role, status = f$status,
    evidence_source = evidence_source_label,
    notes = f$notes
  )
  logged_ids <- c(logged_ids, id)
}
cat(sprintf("Fertig: %d Zeilen geloggt.\n", length(logged_ids)))

summary_by_status <- evidence_registry_summary(con)[evid_evidence_source == evidence_source_label, .N, by = evid_status]
cat("\nVerteilung nach Status:\n")
print(summary_by_status)

dbDisconnect(con)
