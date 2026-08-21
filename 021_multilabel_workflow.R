# =====================================================================
# 021_multilabel_workflow.R -- Binary Relevance + Accuracy-Threshold-Tuning
# =====================================================================
# Nur aktiv, wenn `label_cols` in 000_config.R gesetzt ist (mehrere nicht-
# exklusive Zielspalten statt eines einzelnen `target_col`). Siehe
# multilabel.R fuer die Bausteine, REFERENZ_METRIC_TARGET_MISMATCH.md fuer
# das Warum der Accuracy- statt BAcc-Schwellenwertsuche (3/3 unabhaengig
# bestaetigt: BAcc-Tuning verschlechtert Hamming Loss/Subset Accuracy trotz
# besserer Pro-Label-BAcc, weil BAcc eine balancierte, Hamming Loss/Subset
# Accuracy aber rohe Fehlerraten sind).
#
# NA-Maskierung (2026-08-21, aus tox21-multilabel generalisiert): Labels
# duerfen NA sein (nicht getestet). `binary_relevance_pool()` filtert pro
# Label auf nicht-NA-Zeilen und gibt NACH ROW-ID BENANNTE Wahrscheinlich-
# keits-Vektoren zurueck (siehe multilabel.R) - hier ueber `names(...)`
# ausgewertet statt positional indiziert. Fuer die GEPOOLTEN Metriken
# (Hamming Loss etc.) werden nur Eval-Zeilen verwendet, die fuer ALLE
# Labels getestet wurden (`eval_complete`) - bei vollstaendigen
# Labelmatrizen (kein NA) ist `eval_complete == eval_ids` und das gesamte
# Skript verhaelt sich wie zuvor (regressionsgetestet byte-identisch in
# den numerischen Ergebnissen gegen yeast/scene/birds, siehe TARGETS.md).
rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3learners)
})

source("000_config.R")
source(file.path(project_dir, "multilabel.R"))

if (!length(label_cols)) {
  cat("Keine label_cols in 000_config.R gesetzt. Multi-Label-Workflow uebersprungen.\n")
  quit(save = "no", status = 0)
}

set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

train <- fread(train_path)
if (id_col %in% names(train)) train[, (id_col) := NULL]
feature_cols <- setdiff(names(train), label_cols)

char_feature_cols <- feature_cols[vapply(train[, ..feature_cols], is.character, logical(1))]
if (length(char_feature_cols) > 0) train[, (char_feature_cols) := lapply(.SD, as.factor), .SDcols = char_feature_cols]
# Labels robust normalisieren - OpenML-Multi-Label-Quellen liefern oft
# FALSE/TRUE-Faktoren statt 0/1 (zweimal in dieser Session als Falle
# aufgetreten, siehe REFERENZ_METRIC_TARGET_MISMATCH.md/Session-Notizen).
# NA bleibt NA (weder as.logical(NA) noch as.integer(NA) veraendern das).
train[, (label_cols) := lapply(.SD, function(x) {
  if (is.logical(x) || is.factor(x)) as.integer(as.logical(as.character(x))) else as.integer(x)
}), .SDcols = label_cols]

n <- nrow(train)
shuffled <- sample.int(n)
n_train <- round(multilabel_train_ratio * n)
n_tune <- round(multilabel_tune_ratio * n)
train_ids <- shuffled[seq_len(n_train)]
tune_ids <- shuffled[(n_train + 1):(n_train + n_tune)]
eval_ids <- shuffled[(n_train + n_tune + 1):n]
# Nur fuer die GEPOOLTEN Multi-Label-Metriken (Hamming Loss/Subset Accuracy/
# Makro-Mikro-F1) gebraucht - diese Funktionen erwarten eine vollstaendige
# Wahrheitsmatrix ohne NA. Bei vollstaendigen Labelmatrizen (kein NA)
# identisch zu eval_ids.
eval_complete <- eval_ids[complete.cases(train[eval_ids, label_cols, with = FALSE])]
cat(sprintf("Zeilen: %d -> Train=%d, Tune=%d, Eval=%d (davon mit allen %d Labels: %d), Features=%d\n",
            n, length(train_ids), length(tune_ids), length(eval_ids), length(label_cols), length(eval_complete), length(feature_cols)))

learner_constructor <- function() lrn("classif.ranger", predict_type = "prob", num.trees = 200, seed = seed)

pool <- binary_relevance_pool(train, feature_cols, label_cols, train_ids,
                               list(tune = tune_ids, eval = eval_ids, eval_complete = eval_complete),
                               learner_constructor, seed = seed)

truth_mat <- as.matrix(train[eval_complete, label_cols, with = FALSE])
pred_mat_default <- matrix(NA_integer_, nrow = length(eval_complete), ncol = length(label_cols), dimnames = list(NULL, label_cols))
pred_mat_tuned <- matrix(NA_integer_, nrow = length(eval_complete), ncol = length(label_cols), dimnames = list(NULL, label_cols))
per_label_results <- vector("list", length(label_cols))

for (j in seq_along(label_cols)) {
  lbl <- label_cols[j]
  prob_tune <- pool$probs[[lbl]]$tune
  prob_eval <- pool$probs[[lbl]]$eval
  prob_eval_complete <- pool$probs[[lbl]]$eval_complete
  # Wahrheitswerte ueber die tatsaechlich verwendeten row_ids (Namen der
  # zurueckgegebenen Vektoren) holen, NICHT positional gegen tune_ids/
  # eval_ids indizieren - bei NA-Maskierung sind das TEILMENGEN.
  truth_tune01 <- as.integer(train[[lbl]][as.integer(names(prob_tune))])
  truth_eval01 <- as.integer(train[[lbl]][as.integer(names(prob_eval))])

  best_thr <- tune_threshold_accuracy(prob_tune, truth_tune01, multilabel_threshold_grid)
  pred_mat_default[, j] <- as.integer(prob_eval_complete >= 0.5)
  pred_mat_tuned[, j] <- as.integer(prob_eval_complete >= best_thr)

  acc_default <- accuracy_at_threshold(prob_eval, truth_eval01, 0.5)
  acc_tuned <- accuracy_at_threshold(prob_eval, truth_eval01, best_thr)
  n_positive_train <- sum(train[[lbl]][train_ids] == 1, na.rm = TRUE)
  n_tested_train <- sum(!is.na(train[[lbl]][train_ids]))
  per_label_results[[j]] <- data.table(
    label = lbl, n_tested_train = n_tested_train,
    n_tested_eval = length(names(prob_eval)), base_rate = mean(truth_eval01),
    n_positive_train = n_positive_train, best_threshold = best_thr,
    accuracy_default = acc_default, accuracy_tuned = acc_tuned
  )
  cat(sprintf("  %s: n_eval=%d  Basisrate=%.3f  n_pos_train=%d  Schwelle=%.2f  Accuracy 0.5->%.3f getunt->%.3f\n",
              lbl, length(names(prob_eval)), mean(truth_eval01), n_positive_train, best_thr, acc_default, acc_tuned))
  if (n_positive_train < 10L) {
    cat(sprintf("    HINWEIS: nur %d positive Trainingsbeispiele - Schwellen-Tuning fuer dieses Label\n", n_positive_train))
    cat("    ist laut REFERENZ_METRIC_TARGET_MISMATCH.md unzuverlaessig (Faustregel: >=10 noetig).\n")
  }
}

per_label_dt <- rbindlist(per_label_results)
fwrite(per_label_dt, multilabel_per_label_results_path)

cat("\n=== Multi-Label-Metriken (nur Eval-Zeilen mit allen Labels getestet): Default (0.5) vs. Accuracy-getunte Schwelle ===\n")
summary_dt <- data.table(
  variante = c("Default-Schwelle (0.5)", "Accuracy-getunte Schwelle je Label"),
  hamming_loss = c(hamming_loss(truth_mat, pred_mat_default), hamming_loss(truth_mat, pred_mat_tuned)),
  subset_accuracy = c(subset_accuracy(truth_mat, pred_mat_default), subset_accuracy(truth_mat, pred_mat_tuned)),
  macro_f1 = c(macro_f1(truth_mat, pred_mat_default), macro_f1(truth_mat, pred_mat_tuned)),
  micro_f1 = c(micro_f1(truth_mat, pred_mat_default), micro_f1(truth_mat, pred_mat_tuned))
)
print(summary_dt)
fwrite(summary_dt, multilabel_results_path)

cat("\nGespeichert:\n")
cat("Pro-Label   :", multilabel_per_label_results_path, "\n")
cat("Zusammenfass.:", multilabel_results_path, "\n")
cat("\nHinweis: BAcc-Schwellenwert-Tuning (analog 130_threshold_tuning.R) ist HIER\n")
cat("bewusst NICHT verwendet - siehe REFERENZ_METRIC_TARGET_MISMATCH.md, warum das\n")
cat("Hamming Loss/Subset Accuracy in 3/3 Testfaellen verschlechtert haette.\n")
