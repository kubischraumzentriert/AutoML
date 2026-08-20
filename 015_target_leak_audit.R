rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3measures)
})

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

# =============================================================================
# Target-Leak-Audit
# =============================================================================
# Eine zu gute Baseline auf einer schweren/unbalancierten Aufgabe ist ein
# Warnsignal, kein Erfolg. WICHTIG: CV<->Leaderboard-Uebereinstimmung faengt
# einen Leak NICHT - das Artefakt steckt meist auch in den Testdaten, ein Leak
# taeuscht also konsistent hohe CV- UND LB-Werte vor. Nur ein Feature-Audit
# deckt das auf. Herkunft: African-Credit-Scoring-Fall (F1 0.88 auf 1.8%
# positiver Klasse war ein Ex-post-Leak; nach Bereinigung F1 ~0.41, extern am
# Leaderboard fast exakt bestaetigt). Vier von fuenf Schritten sind
# automatisiert, Schritt 5 (Verfuegbarkeit zur Entscheidungszeit) bleibt
# fachliches Urteil.
#
# Bewusst OHNE subset_fraction: Determinismus-/Stratum-Befunde brauchen
# Volumen - ein Subset kann seltene Gruppen unterrepraesentieren und sogar das
# Vorzeichen eines Befunds verfaelschen (dieselbe Screening-Falle wie bei
# exact-value Target-Encoding, siehe README).
cat("=== Target-Leak-Audit ===\n")
cat("Eine zu gute Baseline auf einer schweren/unbalancierten Aufgabe ist ein\n")
cat("Warnsignal, kein Erfolg. CV<->Leaderboard-Uebereinstimmung faengt einen\n")
cat("Leak NICHT (das Artefakt steckt meist auch in den Testdaten).\n\n")

train <- fread(train_path)
# any(): id_col kann ein Vektor sein (020_task.R unterstuetzt das bereits
# ueber select(-all_of(id_col)), z.B. um neben der reinen ID auch eine
# Hilfsspalte wie einen Zeit-Block-Index auszuschliessen, siehe
# openml-eeg-eye-state-timeseries in ML_Learning) - ein einzelnes %in%
# ergaebe sonst einen Vektor, den if() bei Laenge > 1 ablehnt.
if (any(id_col %in% names(train))) train[, (id_col) := NULL]

char_cols <- names(train)[vapply(train, is.character, logical(1))]
train[, (char_cols) := lapply(.SD, as.factor), .SDcols = char_cols]
# Datumsspalten (Date/IDate/POSIXct, z.B. aus fread()) werden von mlr3-Tasks
# nicht unterstuetzt -> numerisch (Tage/Sekunden seit Epoch) statt fallenlassen,
# ein Datum kann selbst leak-relevant sein (z.B. "erfasst am" nach dem Ausgang).
date_cols <- names(train)[vapply(train, function(x) inherits(x, c("Date", "IDate", "POSIXct")), logical(1))]
train[, (date_cols) := lapply(.SD, as.numeric), .SDcols = date_cols]
train[, (target_col) := as.factor(get(target_col))]

# LightGBM verarbeitet fehlende Werte und Faktoren nativ, daher ohne
# Imputations-Pipeline - vereinfacht auch den Zugriff auf importance().
task_full <- as_task_classif(train, target = target_col, id = "leak_audit")
# Direkt gesetzt statt ueber enable_class_stratification() (000_config.R) - so
# ist das Skript auch in Projekten lauffaehig, die diesen Helfer (noch) nicht
# definieren (z.B. aeltere Template-Kopien).
task_full$set_col_roles(target_col, add_to = "stratum")
feature_cols <- task_full$feature_names
target_vals <- train[[target_col]]

# Fester Holdout-Split (seed-deterministisch), wiederverwendet von Schritt 1b
# (Cluster-Zerlegung) und Schritt 4 (Ehrlich-vs-aufgeblasen-Zerlegung) - ein
# einziger gepaarter Split fuer alle Retraining-Vergleiche in diesem Skript.
holdout <- rsmp("holdout", ratio = validation_ratio)
holdout$instantiate(task_full)
train_ids <- holdout$train_set(1)
test_ids <- holdout$test_set(1)

# --- Schritt 1: Feature-Importance-Konzentration ----------------------------
cat("=== Schritt 1: Feature-Importance-Konzentration ===\n")
learner_imp <- lrn("classif.lightgbm", num_iterations = 200, predict_type = "prob")
learner_imp$train(task_full)
imp <- learner_imp$importance()
importance_dt <- data.table(feature = names(imp), gain = as.numeric(imp))
importance_dt[, share := gain / sum(gain)]
setorder(importance_dt, -share)
fwrite(importance_dt, leak_audit_importance_path)
print(importance_dt)

suspects_importance <- importance_dt[share > leak_audit_importance_share_threshold, feature]

# Staerkstes Feature IMMER mit exakter Zahl + qualitativer Einordnung
# zeigen (2026-08-17, Nutzeranregung nach einer Suche ueber 17 reale
# Projekte, bei der mehrere Faelle knapp unter der 50%-Schwelle lagen -
# 30-50% ("HOCH") ist informativ genug, um kurz hinzuschauen, aber bei
# weitem nicht selten genug, um automatisch etwas auszuloesen (7/17
# gepruefte Projekte lagen in diesem Band, alle bislang als legitim
# eingeordnet - ein automatischer Trigger dort haette die "selten, aber
# berechtigt"-Eigenschaft des Guards verwaessert). Rein informativ, loest
# NICHTS in Schritt 3/4/5 aus - nur der `leak_audit_importance_share_
# threshold`-Verdacht (>=50%) tut das weiterhin.
top_feature <- importance_dt$feature[1]
top_share <- importance_dt$share[1]
share_rating <- if (top_share >= leak_audit_importance_share_threshold) {
  "SEHR HOCH"
} else if (top_share >= leak_audit_advisory_share_threshold) {
  "HOCH"
} else if (top_share >= 0.10) {
  "MITTEL"
} else {
  "KLEIN"
}
cat(sprintf(
  "\nStaerkstes Feature: %s (%.1f%% der Gain-Importance, Einordnung: %s)\n",
  top_feature, top_share * 100, share_rating
))

if (length(suspects_importance) > 0) {
  cat(sprintf(
    "WARNUNG: %s traegt/tragen ueber %.0f%% der Gain-Importance - genauer pruefen (moeglicher Leak).\n",
    paste(suspects_importance, collapse = ", "), leak_audit_importance_share_threshold * 100
  ))
} else {
  advisory_features <- importance_dt[
    share > leak_audit_advisory_share_threshold & share <= leak_audit_importance_share_threshold, feature
  ]
  if (length(advisory_features) > 0) {
    cat(sprintf(
      "Hinweis (kein automatischer Verdacht, keine Zerlegung ausgeloest): %s liegt zwischen %.0f%% und %.0f%% - bei Gelegenheit kurz pruefen, ob das Feature zum Vorhersagezeitpunkt wirklich bekannt ist.\n",
      paste(advisory_features, collapse = ", "),
      leak_audit_advisory_share_threshold * 100, leak_audit_importance_share_threshold * 100
    ))
  } else {
    cat(sprintf(
      "Kein Feature traegt ueber %.0f%% der Gain-Importance.\n",
      leak_audit_advisory_share_threshold * 100
    ))
  }
}

# --- Kumulative Top-k-Erweiterung eines BESTEHENDEN Verdachts --------------
# Der Einzelfeature-Check oben uebersieht einen Leak-PARTNER, der knapp unter
# der Einzelschwelle liegt (Anlass: CreditScoringChallenge, repay+funding-
# Gruppe - keines der Features zwingend einzeln >50%, gemeinsam aber F1
# 0.876->~0.41). Aus MLR3_Regression zurueckgefuehrt, dort an 2 Projekten
# bestaetigt (bike-sharing echter Fund, road-accident-risk Gegenprobe).
#
# WICHTIG: dieser Check laeuft NUR, wenn Schritt 1 bereits mindestens einen
# Einzelverdaechtigen gefunden hat - er ERWEITERT einen bestehenden Verdacht,
# er ERZEUGT keinen neuen aus einer sauberen Verteilung. Ohne diese Bedingung
# markiert der Check faelschlich die staerksten LEGITIMEN Features als
# verdaechtig, sobald wenige Features gemeinsam den Grossteil der Importance
# tragen (siehe road-accident-risk-Gegenprobe: 3 legitime Features tragen
# zusammen 88%, keins einzeln ueber 50% - ohne diese Bedingung waeren sie
# faelschlich geflaggt worden). Nur die fuehrenden `leak_audit_cumulative_
# max_k` Features werden ueberhaupt betrachtet.
importance_dt[, cum_share := cumsum(share)]
if (length(suspects_importance) == 0) {
  suspects_cumulative <- character(0)
  cat("Kein Feature ueber der Einzelschwelle - kumulative Erweiterung uebersprungen (kein Ausgangsverdacht, siehe Kommentar oben).\n")
} else {
  top_k_candidates <- importance_dt[seq_len(min(leak_audit_cumulative_max_k, nrow(importance_dt)))]
  crossing_idx <- which(top_k_candidates$cum_share > leak_audit_cumulative_share_threshold)
  suspects_cumulative <- if (length(crossing_idx) > 0) {
    top_k_candidates$feature[seq_len(min(crossing_idx))]
  } else {
    character(0)
  }
  new_cumulative_suspects <- setdiff(suspects_cumulative, suspects_importance)
  if (length(new_cumulative_suspects) > 0) {
    cat(sprintf(
      "WARNUNG: zusammen mit dem/den bereits verdaechtigen Feature(s) tragen die fuehrenden %d Feature(s)\n",
      length(suspects_cumulative)
    ))
    cat(sprintf(
      "  (%s) ueber %.0f%% der Gain-Importance - %s NEU gegenueber der Einzelschwelle,\n",
      paste(suspects_cumulative, collapse = ", "), leak_audit_cumulative_share_threshold * 100,
      paste(new_cumulative_suspects, collapse = ", ")
    ))
    cat("  Verdacht auf ein Leak-PAAR/eine Leak-GRUPPE (nicht nur ein Einzelfeature).\n")
  } else {
    cat(sprintf(
      "Kumulative Top-%d-Schwelle (%.0f%%) bestaetigt nur die bereits per Einzelschwelle Verdaechtigen - kein Zusatzbefund.\n",
      length(suspects_cumulative), leak_audit_cumulative_share_threshold * 100
    ))
  }
}

# --- Schritt 1b: Korrelierte Feature-Cluster (Gruppenverdacht) --------------
# Anlass (2026-08-21, lending-club-leak-test): ein Leak kann ueber viele
# MITEINANDER REDUNDANTE Features verteilt sein, bei denen weder die
# Einzelschwelle noch die kumulative Top-k-Erweiterung oben greifen (die
# betrachtet nur die FUEHRENDEN Gain-Features - bei Redundanz genuegt deren
# Entfernen nicht, die uebrigen redundanten Features tragen die Leistung
# unveraendert weiter). Mechanismus: numerische Features nach paarweiser
# Korrelation clustern (Redundanz zeigt sich darin, unabhaengig von der
# individuellen - hier irrefuehrenden - Gain-Importance). Nur der Cluster
# mit der groessten summierten Gain-Importance wird geprueft (hoechstens 1
# zusaetzliches Retraining), und nur wenn diese Summe schon die Advisory-
# Schwelle ueberschreitet (billiger Vorfilter). Siehe README/000_config.R.
cat("\n=== Schritt 1b: Korrelierte Feature-Cluster (Gruppenverdacht) ===\n")
numeric_cols_all <- feature_cols[vapply(train[, ..feature_cols], is.numeric, logical(1))]
suspects_cluster <- character(0)

if (length(numeric_cols_all) < 2) {
  cat("Weniger als 2 numerische Features - Cluster-Check uebersprungen.\n")
} else {
  # NA-Ursache: eine Spalte mit (fast) Varianz 0 macht auch ihre eigene
  # Diagonale NaN (sd=0) - erst auf 0 setzen, DANN die Diagonale wieder auf
  # 1 erzwingen (Selbstkorrelation ist immer 1, unabhaengig vom NA-Fixup),
  # sonst wuerde so eine Spalte als maximal UNAEHNLICH zu sich selbst gelten.
  cor_mat <- suppressWarnings(cor(train[, ..numeric_cols_all], use = "pairwise.complete.obs"))
  cor_mat[is.na(cor_mat)] <- 0
  diag(cor_mat) <- 1
  hc <- hclust(as.dist(1 - abs(cor_mat)), method = "complete")
  clusters <- cutree(hc, h = 1 - leak_audit_cluster_correlation_threshold)
  cluster_dt <- data.table(feature = names(clusters), cluster_id = as.integer(clusters))
  cluster_dt <- merge(cluster_dt, importance_dt[, .(feature, share)], by = "feature", all.x = TRUE)
  cluster_sizes <- cluster_dt[, .(n = .N, total_share = sum(share, na.rm = TRUE)), by = cluster_id]
  cluster_sizes <- cluster_sizes[n >= 2]

  if (nrow(cluster_sizes) == 0) {
    cat(sprintf(
      "Keine Gruppe von >=2 korrelierten (|r|>=%.2f) Features gefunden.\n",
      leak_audit_cluster_correlation_threshold
    ))
  } else {
    setorder(cluster_sizes, -total_share)
    top_cluster_id <- cluster_sizes$cluster_id[1]
    top_cluster_share <- cluster_sizes$total_share[1]
    top_cluster_features <- cluster_dt[cluster_id == top_cluster_id, feature]
    cat(sprintf(
      "Groesster korrelierter Cluster (|r|>=%.2f): %s (%d Features, zusammen %.1f%% Gain-Importance)\n",
      leak_audit_cluster_correlation_threshold, paste(top_cluster_features, collapse = ", "),
      length(top_cluster_features), top_cluster_share * 100
    ))
    if (top_cluster_share <= leak_audit_advisory_share_threshold) {
      cat("Unter der Advisory-Schwelle - keine Zerlegung ausgeloest.\n")
    } else {
      cat("Ueber der Advisory-Schwelle - teste per Retraining, ob das Entfernen\n")
      cat("dieses Clusters den Score einbrechen laesst (auch wenn kein Einzelfeature\n")
      cat("oder die Top-k-Kumulativsumme das anzeigt)...\n")
      task_cluster_reduced <- task_full$clone(deep = TRUE)
      task_cluster_reduced$select(setdiff(feature_cols, top_cluster_features))
      learner_cluster <- lrn("classif.lightgbm", num_iterations = 200, predict_type = "prob")
      score_variant_cluster <- function(task) {
        l <- learner_cluster$clone(deep = TRUE)
        l$train(task, row_ids = train_ids)
        pred <- l$predict(task, row_ids = test_ids)
        pred$score(msr(baseline_measure_ids[1]))
      }
      score_full_cluster <- score_variant_cluster(task_full)
      score_reduced_cluster <- score_variant_cluster(task_cluster_reduced)
      cluster_drop <- score_full_cluster - score_reduced_cluster
      cat(sprintf(
        "%s: voll=%.4f  ohne Cluster=%.4f  Differenz=%.4f\n",
        baseline_measure_ids[1], score_full_cluster, score_reduced_cluster, cluster_drop
      ))
      if (cluster_drop > leak_audit_cluster_drop_threshold) {
        suspects_cluster <- top_cluster_features
        cat(sprintf(
          "WARNUNG: Entfernen des korrelierten Clusters (%s) laesst %s um %.4f einbrechen -\n",
          paste(top_cluster_features, collapse = ", "), baseline_measure_ids[1], cluster_drop
        ))
        cat("  Verdacht auf eine REDUNDANTE Leak-GRUPPE, die die Einzel-/Kumulativschwelle\n")
        cat("  wegen verteilter Gain-Importance umgeht.\n")
      } else {
        cat("Abfall unter der Warnschwelle - vermutlich legitime Korrelation, kein Verdacht.\n")
      }
    }
  }
}

# --- Schritt 2: Determinismus (P(Ziel | Feature = Wert)) --------------------
# Nur Spalten mit ueberschaubarer Kardinalitaet (Kategorien oder kleine
# numerische Codes) - bei quasi-stetigen Spalten ist jeder Wert quasi
# eindeutig, "Determinismus" waere dort bedeutungslos (siehe Kardinalitaets-
# Vorbedingung bei exact-value Target-Encoding, README).
cat("\n=== Schritt 2: Determinismus (P(Ziel = Klasse | Feature = Wert)) ===\n")
low_card_cols <- feature_cols[vapply(feature_cols, function(c) {
  data.table::uniqueN(train[[c]]) <= leak_audit_cardinality_max
}, logical(1))]

compute_determinism <- function(col_name) {
  dt <- data.table(value = as.character(train[[col_name]]), target = target_vals)
  dt <- dt[!is.na(value)]
  agg <- dt[, .(n = .N), by = .(value, target)]
  agg[, total := sum(n), by = value]
  agg[, share := n / total]
  best <- agg[agg[, .I[which.max(share)], by = value]$V1]
  data.table(
    feature = col_name, value = best$value, n_group = best$total,
    dominant_class = as.character(best$target), purity = best$share
  )
}

if (length(low_card_cols) == 0) {
  # z.B. rein kontinuierliche Feature-Saetze (Spektralindizes etc.) ohne jede
  # Spalte <= leak_audit_cardinality_max - rbindlist(list()) haette hier eine
  # spaltenlose Tabelle erzeugt und den nachfolgenden Zugriff zum Absturz
  # gebracht, daher expliziter Kurzschluss statt stillem/kaputtem Leerfall.
  cat(sprintf(
    "Keine Spalte mit <= %d eindeutigen Werten - Schritt uebersprungen.\n",
    leak_audit_cardinality_max
  ))
  determinism_dt <- data.table(
    feature = character(0), value = character(0), n_group = integer(0),
    dominant_class = character(0), purity = numeric(0), flagged = logical(0)
  )
} else {
  determinism_dt <- rbindlist(lapply(low_card_cols, compute_determinism), fill = TRUE)
  determinism_dt[, flagged := purity >= (1 - leak_audit_determinism_eps) & n_group >= leak_audit_determinism_min_n]
  setorder(determinism_dt, -flagged, -n_group)
}
fwrite(determinism_dt, leak_audit_determinism_path)

flagged_determinism <- determinism_dt[flagged == TRUE]
if (nrow(flagged_determinism) > 0) {
  cat(sprintf(
    "WARNUNG: %d Wert-Gruppe(n) mit exaktem Determinismus (n>=%d) gefunden:\n",
    nrow(flagged_determinism), leak_audit_determinism_min_n
  ))
  print(flagged_determinism)
} else if (length(low_card_cols) > 0) {
  cat(sprintf("Keine Wert-Gruppe mit n>=%d zeigt exakten Determinismus.\n", leak_audit_determinism_min_n))
}
suspects_determinism <- unique(flagged_determinism$feature)

# --- Schritt 3: Within-Stratum-Zieltrennung (optional) -----------------------
# Vergleicht den Mittelwert eines verdaechtigen NUMERISCHEN Features je
# Zielklasse INNERHALB derselben Stufe einer eigentlich neutralen kategorialen
# Spalte (leak_audit_stratify_cols). Trennt das Feature die Klassen sogar
# innerhalb derselben Kategorie deutlich, ist es eher outcome- statt
# ex-ante-getrieben (der entscheidende Ex-post-Test, siehe README). Braucht
# projektspezifisches Wissen, welche Spalte "neutral" sein sollte -> ohne
# Konfiguration wird dieser Schritt uebersprungen, nicht automatisch geraten.
cat("\n=== Schritt 3: Within-Stratum-Zieltrennung ===\n")
numeric_cols <- feature_cols[vapply(train[, ..feature_cols], is.numeric, logical(1))]
numeric_suspects <- intersect(union(suspects_importance, suspects_cumulative), numeric_cols)

if (length(leak_audit_stratify_cols) == 0 || length(numeric_suspects) == 0) {
  cat("Uebersprungen (kein 'leak_audit_stratify_cols' konfiguriert oder keine\n")
  cat("numerischen Verdaechtigen aus Schritt 1).\n")
} else {
  stratum_dt <- rbindlist(lapply(numeric_suspects, function(nf) {
    rbindlist(lapply(leak_audit_stratify_cols, function(sc) {
      dt <- data.table(value = train[[sc]], feat = train[[nf]], target = target_vals)
      agg <- dt[, .(n = .N, mean_feature = mean(feat, na.rm = TRUE)), by = .(value, target)]
      agg[, `:=`(numeric_feature = nf, stratify_col = sc)]
      agg
    }))
  }), fill = TRUE)
  fwrite(stratum_dt, leak_audit_stratum_path)
  print(stratum_dt)
  cat("\nGespeichert:", leak_audit_stratum_path, "\n")
  cat("Interpretation: variiert der Mittelwert INNERHALB einer Stratum-Stufe\n")
  cat("systematisch mit der Zielklasse, ist das Feature vermutlich outcome-\n")
  cat("getrieben statt ex-ante bekannt - manuelles Urteil, siehe README.\n")
}

# --- Schritt 4: Ehrlich-vs-aufgeblasen-Zerlegung -----------------------------
# Fairer, gepaarter Split (dieselben Zeilen fuer beide Varianten): einmal mit
# allen Features, einmal ohne die Verdaechtigen aus Schritt 1+2. Die Differenz
# quantifiziert, wieviel vom Score "Leak" statt echtes Signal war.
cat("\n=== Schritt 4: Ehrlich-vs-aufgeblasen-Zerlegung ===\n")
suspects <- head(Reduce(union, list(suspects_importance, suspects_cumulative, suspects_determinism, suspects_cluster)), leak_audit_suspect_top_n)

if (length(suspects) == 0) {
  cat("Keine verdaechtigen Features aus Schritt 1/2 - Audit unauffaellig,\n")
  cat("Zerlegung uebersprungen.\n")
} else {
  cat("Verdaechtige Features:", paste(suspects, collapse = ", "), "\n\n")

  task_reduced <- task_full$clone(deep = TRUE)
  task_reduced$select(setdiff(feature_cols, suspects))

  measures <- msrs(baseline_measure_ids)
  learner_dec <- lrn("classif.lightgbm", num_iterations = 200, predict_type = "prob")

  score_task <- function(task) {
    l <- learner_dec$clone(deep = TRUE)
    l$train(task, row_ids = train_ids)
    pred <- l$predict(task, row_ids = test_ids)
    setNames(vapply(measures, function(m) pred$score(m), numeric(1)), baseline_measure_ids)
  }

  scores_full <- score_task(task_full)
  scores_reduced <- score_task(task_reduced)

  decomposition_dt <- as.data.table(rbind(scores_full, scores_reduced))
  decomposition_dt[, variante := c("mit Verdaechtigen (voll)", "ohne Verdaechtige")]
  setcolorder(decomposition_dt, c("variante", baseline_measure_ids))
  fwrite(decomposition_dt, leak_audit_decomposition_path)
  print(decomposition_dt)

  primary <- baseline_measure_ids[1]
  drop <- scores_full[[primary]] - scores_reduced[[primary]]
  cat(sprintf(
    "\n%s: voll=%.4f  ohne Verdaechtige=%.4f  Differenz=%.4f\n",
    primary, scores_full[[primary]], scores_reduced[[primary]], drop
  ))
  cat("Ein grosser Abfall bestaetigt, dass die verdaechtigen Features einen\n")
  cat("substanziellen Teil des Scores tragen - je nach Schritt-5-Urteil gehoert\n")
  cat("der ehrliche (reduzierte) Wert als realistische Erwartung, nicht der volle.\n")

  # --- Experiment-Tracking (SQLite) ------------------------------------------
  db_con <- db_connect()
  db_proj_id <- db_get_or_create_project(db_con, project_name)
  db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "015_target_leak_audit.R")
  db_run_id <- db_create_run(
    db_con, db_wf_id, seed = seed,
    notes = paste0("Target-Leak-Audit: mit vs. ohne Verdaechtige (", paste(suspects, collapse = ", "), ")")
  )
  db_log_run_config(db_con, db_run_id, list(
    leak_audit_importance_share_threshold = leak_audit_importance_share_threshold,
    leak_audit_determinism_min_n = leak_audit_determinism_min_n,
    suspects = paste(suspects, collapse = ", ")
  ))
  db_rsmp_id <- db_create_resampling(db_con, db_run_id, strategy = "custom_split", ratio = validation_ratio, seed = seed)

  mconf_full <- db_create_model_config(
    db_con, db_run_id, task_type = "classif", algorithm = "lightgbm",
    feature_set = "all_incl_suspects", preprocessing = "none",
    task_id = task_full$id, hyperparams = list(num_iterations = 200)
  )
  for (m in names(scores_full)) db_log_metric_result(db_con, mconf_full, db_rsmp_id, m, scores_full[[m]])

  mconf_reduced <- db_create_model_config(
    db_con, db_run_id, task_type = "classif", algorithm = "lightgbm",
    feature_set = "excl_suspects", preprocessing = "none",
    task_id = task_full$id,
    hyperparams = list(num_iterations = 200, excluded = paste(suspects, collapse = ", "))
  )
  for (m in names(scores_reduced)) db_log_metric_result(db_con, mconf_reduced, db_rsmp_id, m, scores_reduced[[m]])

  db_finish_run(db_con, db_run_id)
  DBI::dbDisconnect(db_con)
  cat("Experiment-DB:", experiments_db_path, "\n")
}

# --- Schritt 5: Verfuegbarkeit zur Entscheidungszeit (manuelles Urteil) -----
cat("\n=== Schritt 5: Verfuegbarkeit zur Entscheidungszeit (manuelles Urteil) ===\n")
if (length(suspects) > 0) {
  cat("Fuer jedes verdaechtige Feature (", paste(suspects, collapse = ", "), ") pruefen:\n", sep = "")
  cat("  - Ist der Wert zum Zeitpunkt der Vorhersage TATSAECHLICH bekannt (ex-ante),\n")
  cat("    oder haengt er vom Ausgang/einer spaeteren Entscheidung ab (ex-post)?\n")
  cat("  - Ist er nur DEFINITORISCH mit dem Ziel gekoppelt (z.B. strukturell\n")
  cat("    unmoeglich, ein bestimmtes Ziel zu erreichen), statt inhaltlich prediktiv?\n")
  cat("  Nicht automatisierbar - siehe README 'Target-Leakage-Audit' fuer die\n")
  cat("  drei Kategorien (Ex-post-Leak / definitorisch gekoppelt / legitim ex-ante).\n")
} else {
  cat("Keine Verdaechtigen aus Schritt 1/2 - kein manuelles Urteil noetig.\n")
}

cat("\nGespeichert:\n")
cat("Importance    :", leak_audit_importance_path, "\n")
cat("Determinismus :", leak_audit_determinism_path, "\n")
if (length(leak_audit_stratify_cols) > 0 && length(numeric_suspects) > 0) {
  cat("Within-Stratum:", leak_audit_stratum_path, "\n")
}
if (length(suspects) > 0) {
  cat("Zerlegung     :", leak_audit_decomposition_path, "\n")
}
