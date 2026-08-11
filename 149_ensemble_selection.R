rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3measures)
})

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

# Caruana-Greedy-Ensemble-Selection (Caruana et al. 2004, wie in Auto-
# sklearn) - verifiziert an 2 unabhaengigen OpenML-Datensaetzen
# (bank-marketing/electricity, siehe TARGETS.md). Baut auf dem
# `148_ensemble_candidate_pool.R`-Artefakt auf, kein erneutes Training.
if (!file.exists(ensemble_candidate_pool_path)) {
  stop("Kandidaten-Pool fehlt. Erst 148_ensemble_candidate_pool.R ausfuehren.")
}
pool <- readRDS(ensemble_candidate_pool_path)
truth <- pool$truth
class_names <- pool$class_names
n_candidates <- length(pool$prob_list)
n_eval <- length(truth)

# Weiterer Split des 147-Eval-Splits in Selektions- und Bestaetigungsmenge -
# die Selektion darf NICHT auf denselben Zeilen laufen, auf denen sie
# bewertet wird (sonst ueberpasst sich die Selektion an sich selbst),
# analog zum 3-Wege-Split der Standalone-Verifikation.
set.seed(seed)
by_class <- split(seq_len(n_eval), truth)
selection_ids <- unlist(lapply(by_class, function(idx) {
  sample(idx, round(ensemble_selection_valid_ratio * length(idx)))
}))
confirmation_ids <- setdiff(seq_len(n_eval), selection_ids)
cat(sprintf("Eval-Split (147): %d Zeilen -> Selektion=%d, Bestaetigung=%d\n",
            n_eval, length(selection_ids), length(confirmation_ids)))

bacc_from_probs <- function(prob_mat, truth_subset) {
  response <- factor(class_names[max.col(prob_mat, ties.method = "first")], levels = levels(truth_subset))
  mlr3measures::bacc(truth_subset, response)
}

truth_sel <- truth[selection_ids]
truth_conf <- truth[confirmation_ids]
probs_sel <- lapply(pool$prob_list, function(m) m[selection_ids, , drop = FALSE])
probs_conf <- lapply(pool$prob_list, function(m) m[confirmation_ids, , drop = FALSE])

# --- Bestes Einzelmodell (nach Selektionsmenge) -----------------------------
bacc_sel_per_candidate <- vapply(probs_sel, bacc_from_probs, numeric(1), truth_subset = truth_sel)
best_idx <- which.max(bacc_sel_per_candidate)
best_single_bacc_conf <- bacc_from_probs(probs_conf[[best_idx]], truth_conf)
cat(sprintf("\nBestes Einzelmodell (Selektions-BAcc): %s | Selektion=%.4f | Bestaetigung=%.4f\n",
            pool$labels[best_idx], bacc_sel_per_candidate[best_idx], best_single_bacc_conf))

# --- Gleichgewichteter Blend (alle Kandidaten) ------------------------------
mean_prob_conf_all <- Reduce(`+`, probs_conf) / n_candidates
blend_equal_bacc_conf <- bacc_from_probs(mean_prob_conf_all, truth_conf)
cat(sprintf("Gleichgewichteter Blend (alle %d): Bestaetigung=%.4f\n", n_candidates, blend_equal_bacc_conf))

# --- Caruana Greedy Ensemble Selection (auf der Selektionsmenge) -----------
cat("\n=== Caruana Greedy Ensemble Selection (Selektionsmenge) ===\n")
selected <- integer(0)
running_sum_sel <- matrix(0, nrow = length(selection_ids), ncol = length(class_names))
best_sel_bacc_so_far <- -Inf
best_selected_at_step <- integer(0)
for (round in seq_len(ensemble_selection_rounds)) {
  gains <- vapply(seq_len(n_candidates), function(i) {
    trial_mean <- (running_sum_sel + probs_sel[[i]]) / (length(selected) + 1)
    bacc_from_probs(trial_mean, truth_sel)
  }, numeric(1))
  best_gain_idx <- which.max(gains)
  selected <- c(selected, best_gain_idx)
  running_sum_sel <- running_sum_sel + probs_sel[[best_gain_idx]]
  if (gains[best_gain_idx] > best_sel_bacc_so_far) {
    best_sel_bacc_so_far <- gains[best_gain_idx]
    best_selected_at_step <- selected
  }
}
cat(sprintf("Beste Selektions-BAcc waehrend der Selektion: %.4f bei Ensemblegroesse %d\n",
            best_sel_bacc_so_far, length(best_selected_at_step)))
sel_counts <- table(pool$labels[best_selected_at_step])
cat("Ausgewaehlte Modelle (mit Haeufigkeit):\n"); print(sel_counts)

ensemble_prob_conf <- Reduce(`+`, probs_conf[best_selected_at_step]) / length(best_selected_at_step)
ensemble_bacc_conf <- bacc_from_probs(ensemble_prob_conf, truth_conf)
cat(sprintf("\nGreedy-Ensemble Bestaetigungs-BAcc: %.4f\n", ensemble_bacc_conf))

# --- Zusammenfassung ---------------------------------------------------------
summary_dt <- data.table(
  approach = c("best_single", "equal_blend", "greedy_ensemble"),
  n_models = c(1L, n_candidates, length(best_selected_at_step)),
  bacc_confirmation = c(best_single_bacc_conf, blend_equal_bacc_conf, ensemble_bacc_conf)
)
setorder(summary_dt, -bacc_confirmation)
fwrite(summary_dt, ensemble_selection_results_path)

cat("\n=== Zusammenfassung (Bestaetigungs-BAcc, unabhaengig von Selektion) ===\n")
print(summary_dt)
cat("\nGespeichert:", ensemble_selection_results_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "149_ensemble_selection.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes = sprintf(
  "Caruana Greedy Ensemble Selection auf %d Kandidaten (%s)", n_candidates, paste(unique(pool$families), collapse = "/")
))
db_log_run_config(db_con, db_run_id, list(
  n_candidates = n_candidates, ensemble_selection_rounds = ensemble_selection_rounds,
  ensemble_selection_valid_ratio = ensemble_selection_valid_ratio,
  selected_ensemble_size = length(best_selected_at_step)
))
db_rsmp_id <- db_create_resampling(db_con, db_run_id, strategy = "custom_split", ratio = ensemble_selection_valid_ratio, seed = seed)

for (i in seq_len(nrow(summary_dt))) {
  mconf_id <- db_create_model_config(
    db_con, db_run_id, task_type = "classif", algorithm = summary_dt$approach[i],
    feature_set = "raw", preprocessing = "impute_median_mode", class_weight_power = NA_real_,
    task_id = pool$target_col_name, hyperparams = list(n_models = summary_dt$n_models[i])
  )
  db_log_metric_result(db_con, mconf_id, db_rsmp_id, "classif.bacc", summary_dt$bacc_confirmation[i])
}

db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
