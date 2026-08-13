# =====================================================================
# multilabel.R -- Multi-Label-Klassifikation (Binary Relevance)
# =====================================================================
# Generische Bausteine fuer Aufgaben mit MEHREREN nicht-exklusiven
# Zielspalten (anders als Multiclass: mehrere Labels koennen gleichzeitig
# 1 sein). Weder mlr3 noch CRAN haben ein natives Multi-Label-Paket
# (geprueft 2026-08-13/14) - Standardweg ist Problem-Transformation.
#
# Verifiziert an 3 unabhaengigen OpenML-Datensaetzen (Standalone-Skripte,
# kein Git): `openml-yeast-multilabel` (14 Labels, Protein),
# `openml-scene-multilabel` (6 Labels, Bild), `openml-birds-multilabel`
# (19 Labels, Bioakustik, GEMISCHTE Feature-Typen). Volle Zahlen dort
# bzw. in REFERENZ_METRIC_TARGET_MISMATCH.md.
#
# EMPFOHLENER WEG (3/3 bestaetigt bester Ansatz): Binary Relevance
# (N unabhaengige Binaerklassifikatoren) + Schwellenwert je Label auf
# ROHER ACCURACY getunt (NICHT BAcc - siehe REFERENZ_METRIC_TARGET_
# MISMATCH.md: BAcc-Tuning verschlechtert Hamming Loss/Subset Accuracy in
# 3/3 Faellen trotz besserer Pro-Label-BAcc, weil BAcc eine BALANCIERTE
# Metrik optimiert, Hamming Loss/Subset Accuracy aber ROHE Fehlerraten
# sind - bei Label-Imbalance laufen beide Ziele auseinander).
#
# Classifier Chains (Read et al. 2011) sind IMPLEMENTIERT (unten), aber
# NICHT der empfohlene Weg - 3/3 unabhaengige Tests zeigten keinen
# Vorteil gegenueber Binary Relevance (Basisvariante ohne Nested
# Stacking/Ensemble-of-Chains). Als Referenz/Ausgangspunkt belassen,
# falls jemand eine staerkere CC-Variante probieren will.

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
})

# --- Multi-Label-Metriken -------------------------------------------------
# truth_mat/pred_mat: Matrizen (Zeilen x Labels), Werte 0/1, gleiche
# Spaltenreihenfolge.

#' Hamming Loss: mittlerer Fehler ueber ALLE (Zeile,Label)-Paare
#' (kleiner=besser). Das ist eine ROHE (unbalancierte) Fehlerrate - siehe
#' REFERENZ_METRIC_TARGET_MISMATCH.md fuer die Konsequenz beim Tuning.
hamming_loss <- function(truth_mat, pred_mat) mean(truth_mat != pred_mat)

#' Subset Accuracy / Exact Match: Anteil Zeilen, bei denen ALLE Labels
#' exakt stimmen - striktestes Multi-Label-Mass, bestraft jeden
#' Einzelfehler voll (multiplikativ ueber alle Labels).
subset_accuracy <- function(truth_mat, pred_mat) mean(rowSums(truth_mat != pred_mat) == 0)

#' F1 fuer ein einzelnes binaeres Label (0/1-Vektoren).
f1_binary <- function(truth, pred) {
  tp <- sum(truth == 1 & pred == 1); fp <- sum(truth == 0 & pred == 1); fn <- sum(truth == 1 & pred == 0)
  if (tp == 0) return(0)
  precision <- tp / (tp + fp); recall <- tp / (tp + fn)
  2 * precision * recall / (precision + recall)
}

#' Makro-F1: F1 je Label einzeln, dann UNGEWICHTET gemittelt - jedes
#' Label zaehlt gleich viel, unabhaengig von seiner Haeufigkeit.
macro_f1 <- function(truth_mat, pred_mat) {
  mean(vapply(seq_len(ncol(truth_mat)), function(j) f1_binary(truth_mat[, j], pred_mat[, j]), numeric(1)))
}

#' Mikro-F1: TP/FP/FN ueber ALLE Labels gepoolt, dann EINMAL F1 - haeufige
#' Labels dominieren staerker als bei Makro-F1.
micro_f1 <- function(truth_mat, pred_mat) {
  tp <- sum(truth_mat == 1 & pred_mat == 1); fp <- sum(truth_mat == 0 & pred_mat == 1); fn <- sum(truth_mat == 1 & pred_mat == 0)
  precision <- tp / (tp + fp); recall <- tp / (tp + fn)
  2 * precision * recall / (precision + recall)
}

# --- Schwellenwert-Suche ---------------------------------------------------

#' Rohe (unbalancierte) Trefferquote bei einer gegebenen Schwelle - das ist
#' die Groesse, die Hamming Loss tatsaechlich treibt (Hamming Loss = 1 -
#' mittlere Roh-Accuracy ueber alle Labels). NICHT BAcc verwenden - siehe
#' Modul-Kopfkommentar.
accuracy_at_threshold <- function(prob, truth01, thr) mean(as.integer(prob >= thr) == truth01)

#' Sucht die Accuracy-optimale Schwelle auf einem Grid.
tune_threshold_accuracy <- function(prob, truth01, threshold_grid) {
  acc_per_thr <- vapply(threshold_grid, function(t) accuracy_at_threshold(prob, truth01, t), numeric(1))
  threshold_grid[which.max(acc_per_thr)]
}

# --- Binary Relevance -------------------------------------------------------

#' Trainiert fuer JEDES Label einen unabhaengigen Binaerklassifikator
#' (ignoriert Label-Korrelationen bewusst - das ist Binary Relevance).
#' `learner_constructor`: Funktion ohne Argumente, die einen NEUEN
#' mlr3-Learner mit predict_type="prob" zurueckgibt (z.B.
#' `function() lrn("classif.ranger", predict_type="prob", num.trees=200)`).
#' `dt` muss die Spalten `feature_cols` + `label_cols` enthalten, Labels
#' als 0/1 (integer). Gibt je Split eine benannte Liste von
#' Wahrscheinlichkeits-Vektoren zurueck (ein Eintrag je Label).
binary_relevance_pool <- function(dt, feature_cols, label_cols, train_ids, predict_ids_list, learner_constructor, seed = 42) {
  set.seed(seed)
  result <- setNames(vector("list", length(label_cols)), label_cols)
  learners <- setNames(vector("list", length(label_cols)), label_cols)
  for (lbl in label_cols) {
    dt_lbl <- copy(dt[, c(feature_cols, lbl), with = FALSE])
    dt_lbl[[lbl]] <- factor(dt_lbl[[lbl]], levels = c(0, 1), labels = c("no", "yes"))
    task <- as_task_classif(dt_lbl, target = lbl, id = lbl, positive = "yes")
    learner <- learner_constructor()
    learner$train(task, row_ids = train_ids)
    learners[[lbl]] <- learner
    result[[lbl]] <- lapply(predict_ids_list, function(ids) {
      pred <- learner$predict(task, row_ids = ids)
      pred$prob[, "yes"]
    })
  }
  list(probs = result, learners = learners)
}

# --- Classifier Chains (implementiert, NICHT empfohlen - siehe oben) ------

#' Classifier Chains (Read et al. 2011): Label j nutzt die WAHREN Labels
#' 1..j-1 als Zusatz-Features beim Training, die eigenen (geschwellten)
#' Vorhersagen bei der Anwendung - der bekannte Train/Serving-Mismatch der
#' Basisvariante (kein Nested Stacking). 3/3 Tests zeigten KEINEN Vorteil
#' gegenueber Binary Relevance - als Referenz belassen, nicht der
#' empfohlene Weg. `chain_order`: Reihenfolge der label_cols (z.B.
#' absteigende Basisrate).
classifier_chain_pool <- function(dt, feature_cols, chain_order, train_ids, tune_ids, eval_ids,
                                   learner_constructor, threshold_grid, seed = 42) {
  set.seed(seed)
  chain_feats_tune <- data.table(matrix(NA_integer_, nrow = length(tune_ids), ncol = 0))
  chain_feats_eval <- data.table(matrix(NA_integer_, nrow = length(eval_ids), ncol = 0))
  thresholds <- setNames(numeric(length(chain_order)), chain_order)
  pred_eval01 <- setNames(vector("list", length(chain_order)), chain_order)

  for (step in seq_along(chain_order)) {
    lbl <- chain_order[step]
    prior_labels <- chain_order[seq_len(step - 1)]

    train_dt <- copy(dt[train_ids, c(feature_cols, prior_labels, lbl), with = FALSE])
    train_dt[[lbl]] <- factor(train_dt[[lbl]], levels = c(0, 1), labels = c("no", "yes"))
    task <- as_task_classif(train_dt, target = lbl, id = lbl, positive = "yes")
    learner <- learner_constructor()
    learner$train(task)

    tune_newdata <- copy(dt[tune_ids, c(feature_cols, lbl), with = FALSE])
    if (length(prior_labels) > 0) tune_newdata[, (prior_labels) := chain_feats_tune[, prior_labels, with = FALSE]]
    tune_newdata[[lbl]] <- factor(tune_newdata[[lbl]], levels = c(0, 1), labels = c("no", "yes"))
    prob_tune <- learner$predict_newdata(tune_newdata, task = task)$prob[, "yes"]
    best_thr <- tune_threshold_accuracy(prob_tune, as.integer(dt[[lbl]][tune_ids]), threshold_grid)
    thresholds[lbl] <- best_thr
    chain_feats_tune[, (lbl) := as.integer(prob_tune >= best_thr)]

    eval_newdata <- copy(dt[eval_ids, c(feature_cols, lbl), with = FALSE])
    if (length(prior_labels) > 0) eval_newdata[, (prior_labels) := chain_feats_eval[, prior_labels, with = FALSE]]
    eval_newdata[[lbl]] <- factor(eval_newdata[[lbl]], levels = c(0, 1), labels = c("no", "yes"))
    prob_eval <- learner$predict_newdata(eval_newdata, task = task)$prob[, "yes"]
    pred_eval01[[lbl]] <- as.integer(prob_eval >= best_thr)
    chain_feats_eval[, (lbl) := pred_eval01[[lbl]]]
  }
  list(pred_eval01 = pred_eval01, thresholds = thresholds)
}
