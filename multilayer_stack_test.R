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
source(file.path(project_dir, "ensemble_selection.R"))

# =====================================================================
# multilayer_stack_test.R -- Test: echtes Multi-Layer-Stacking (AutoGluon-
# Idee) vs. bereits getestetes einlagiges Logits-Stacking (NEGATIV, s6e5,
# siehe TARGETS.md) und die bestehenden Ensemble-Bausteine (bestes
# Einzelmodell / Blend / Caruana Greedy Selection).
#
# Bisheriger Befund (3x bestaetigt): einlagiges Stacking/gewichteter Blend
# ueber korrelierte Baummodelle bringt kaum etwas (Rauschgrenze), weil nicht
# das Kombinationsverfahren limitiert, sondern fehlende Diversitaet der
# Basismodelle. AutoGluons eigentlicher Hebel ist aber NICHT der einlagige
# Meta-Learner, sondern MEHRSTUFIGES Stacking (Layer-1-Meta-Learner lernen
# aus den Basis-Wahrscheinlichkeiten, ein Layer-2-Meta-Learner lernt aus den
# Layer-1-Vorhersagen). Das wurde hier noch nie getestet - dieser Test prueft
# gezielt NUR diese offene Frage, nicht den bereits beantworteten Diversitaets-
# Punkt (kein neuer FT-Transformer, weiterhin nur Ranger/LightGBM/CatBoost aus
# dem 148-Pool).
#
# Baut auf dem bestehenden 148-Kandidaten-Pool auf (24 Modelle, Wahrschein-
# lichkeiten auf dem 147-Eval-Split) - KEIN erneutes Basis-Training.
if (!file.exists(ensemble_candidate_pool_path)) {
  stop("Kandidaten-Pool fehlt. Erst 148_ensemble_candidate_pool.R ausfuehren.")
}
pool <- readRDS(ensemble_candidate_pool_path)
truth <- pool$truth
class_names <- pool$class_names
n_candidates <- length(pool$prob_list)
n_eval <- length(truth)
bacc_from_probs <- function(prob_mat, truth_subset) .bacc_from_probs(prob_mat, truth_subset, class_names)

# --- 3-Wege-Split (klassenstratifiziert) ------------------------------------
# layer1_ids: trainiert die Layer-1-Meta-Learner (auf den rohen Basis-
# Wahrscheinlichkeiten). layer2_ids: trainiert den finalen Layer-2-Meta-
# Learner (auf den Layer-1-VORHERSAGEN, nicht den Rohdaten - sonst wuerde
# Layer 2 auf denselben Zeilen lernen, auf denen Layer 1 schon trainiert
# wurde, und sich an sich selbst ueberanpassen). confirmation_ids: komplett
# unberuehrt, einzige ehrliche Bewertungsmenge fuer ALLE Ansaetze unten.
# layer1+layer2 zusammen = dieselbe Datenmenge wie "selection" fuer die
# Baselines (best_single/blend/greedy/single-layer-stack) - fairer Vergleich,
# wie viele Daten insgesamt genutzt wurden.
set.seed(seed)
by_class <- split(seq_len(n_eval), truth)
make_split <- function(idx, ratios) {
  n <- length(idx)
  cuts <- round(cumsum(ratios) * n)
  idx_shuffled <- sample(idx)
  list(idx_shuffled[seq_len(cuts[1])],
       idx_shuffled[(cuts[1] + 1):cuts[2]],
       idx_shuffled[(cuts[2] + 1):n])
}
splits <- lapply(by_class, make_split, ratios = c(0.35, 0.35, 0.30))
layer1_ids <- unlist(lapply(splits, `[[`, 1))
layer2_ids <- unlist(lapply(splits, `[[`, 2))
confirmation_ids <- unlist(lapply(splits, `[[`, 3))
selection_ids <- c(layer1_ids, layer2_ids)
cat(sprintf("Eval-Split (147/148): %d Zeilen -> Layer1=%d, Layer2=%d, Bestaetigung=%d (Selektion gesamt=%d)\n",
            n_eval, length(layer1_ids), length(layer2_ids), length(confirmation_ids), length(selection_ids)))

truth_sel <- truth[selection_ids]
truth_l1 <- truth[layer1_ids]
truth_l2 <- truth[layer2_ids]
truth_conf <- truth[confirmation_ids]
probs_sel <- lapply(pool$prob_list, function(m) m[selection_ids, , drop = FALSE])
probs_conf <- lapply(pool$prob_list, function(m) m[confirmation_ids, , drop = FALSE])

# --- Baselines (wie 149_ensemble_selection.R, dieselbe Selektions-/
# Bestaetigungsmenge wie oben definiert) ------------------------------------
bacc_sel_per_candidate <- vapply(probs_sel, bacc_from_probs, numeric(1), truth_subset = truth_sel)
best_idx <- which.max(bacc_sel_per_candidate)
best_single_bacc <- bacc_from_probs(probs_conf[[best_idx]], truth_conf)

mean_prob_conf_all <- Reduce(`+`, probs_conf) / n_candidates
blend_equal_bacc <- bacc_from_probs(mean_prob_conf_all, truth_conf)

greedy_result <- greedy_ensemble_selection(probs_sel, truth_sel, class_names, rounds = ensemble_selection_rounds)
greedy_prob_conf <- Reduce(`+`, probs_conf[greedy_result$selected]) / length(greedy_result$selected)
greedy_bacc <- bacc_from_probs(greedy_prob_conf, truth_conf)

cat(sprintf("\nBestes Einzelmodell: %.4f | Gleichgewichteter Blend: %.4f | Greedy Ensemble (%d Modelle): %.4f\n",
            best_single_bacc, blend_equal_bacc, length(unique(greedy_result$selected)), greedy_bacc))

# --- Basis-Wahrscheinlichkeiten als flache Feature-Matrix -------------------
# Jede Zeile: n_candidates * n_classes Spalten (Wahrscheinlichkeit jedes
# Kandidaten fuer jede Klasse) - die "Meta-Features" fuer alle Stacking-
# Varianten unten.
flatten_probs <- function(prob_list, labels, class_names) {
  mats <- lapply(seq_along(prob_list), function(i) {
    m <- prob_list[[i]][, class_names, drop = FALSE]
    colnames(m) <- paste0(labels[i], "_", class_names)
    m
  })
  do.call(cbind, mats)
}
feat_sel <- flatten_probs(probs_sel, pool$labels, class_names)
feat_conf <- flatten_probs(probs_conf, pool$labels, class_names)

build_meta_task <- function(feat_mat, truth_vec, id) {
  dt <- as.data.table(feat_mat)
  dt[, target := truth_vec]
  as_task_classif(dt, target = "target", id = id)
}

# Diagnose-Vorlauf (dieser Session) zeigte: ein UNGEWICHTETER Meta-Learner
# auf stark unbalancierten Klassen (health_condition: ~72/5/7% Anteile)
# faellt beim argmax Richtung Mehrheitsklasse zurueck und verliert damit
# genau die Kalibrierung, die die Basismodelle durch ihr gewichtetes
# Training (class_weight_power, siehe 000_config.R) schon hatten - ein reiner
# Kalibrierungs-Artefakt, kein Stacking-Befund (glmnet ungewichtet 0.896 vs.
# gewichtet 0.956, praktisch gleichauf mit dem besten Einzelmodell). Beide
# Meta-Learner-Stufen unten bekommen daher dieselben balancierten Gewichte
# wie die Basismodelle - sonst waere ein Nullbefund hier nicht von einem
# reinen Kalibrierungsfehler zu unterscheiden.
attach_balanced_weights <- function(task, power) {
  target_values <- task$data(cols = task$target_names)[[task$target_names]]
  class_counts <- table(target_values)
  base_weights <- length(target_values) / (length(class_counts) * class_counts)
  weights <- base_weights^power
  task_w <- task$clone(deep = TRUE)
  task_w$cbind(data.table(weight = as.numeric(weights[as.character(target_values)])))
  task_w$set_col_roles("weight", roles = "weights_learner")
  task_w
}

# --- Einlagiges Logits-Stacking (Replikation des s6e5-Negativbefunds, hier
# auf Multiclass-BAcc statt binaerem AUC - prueft, ob derselbe Nullbefund
# auch in diesem Projekt/dieser Metrik auftritt, als interner Vergleichspunkt
# fuer die Mehrschichten-Variante unten). EIN Meta-Learner (multinom, wie im
# urspruenglichen Writeup: einfacher Logistic-Regression-Meta-Learner) auf
# der gesamten Selektionsmenge. -------------------------------------------
task_stack1_train <- attach_balanced_weights(build_meta_task(feat_sel, truth_sel, "stack1_train"), class_weight_power)
meta_multinom <- lrn("classif.multinom", predict_type = "prob")
if ("trace" %in% meta_multinom$param_set$ids()) meta_multinom$param_set$values$trace <- FALSE
meta_multinom$train(task_stack1_train)
pred_stack1 <- meta_multinom$predict_newdata(as.data.table(feat_conf))
stack1_bacc <- mlr3measures::bacc(truth_conf, pred_stack1$response)
cat(sprintf("Einlagiges Stacking (multinom, wie s6e5): %.4f\n", stack1_bacc))

# --- Mehrschichten-Stacking (AutoGluon-Idee) --------------------------------
# Layer 1: DREI verschiedene Meta-Learner-Familien (multinom/ranger/
# lightgbm - dieselben Familien, die schon im 148-Pool stecken, aber jetzt
# als META-Lerner auf den Basis-Wahrscheinlichkeiten statt auf den
# Rohfeatures) lernen je einen eigenen Blick auf die Basis-Vorhersagen.
# feat_sel ist ueber selection_ids <- c(layer1_ids, layer2_ids) aufgebaut -
# die ersten length(layer1_ids) Zeilen von feat_sel entsprechen also genau
# layer1_ids (Positions-, nicht Wert-Index).
task_layer1_train <- attach_balanced_weights(
  build_meta_task(feat_sel[seq_along(layer1_ids), , drop = FALSE], truth_l1, "layer1_train"), class_weight_power)
feat_layer2 <- feat_sel[(length(layer1_ids) + 1):nrow(feat_sel), , drop = FALSE]

layer1_learners <- list(
  multinom = { l <- lrn("classif.multinom", predict_type = "prob"); if ("trace" %in% l$param_set$ids()) l$param_set$values$trace <- FALSE; l },
  ranger = lrn("classif.ranger", predict_type = "prob", num.trees = 200, seed = seed),
  lightgbm = lrn("classif.lightgbm", predict_type = "prob", num_iterations = 100)
)
for (nm in names(layer1_learners)) layer1_learners[[nm]]$train(task_layer1_train)

# Layer-1-Vorhersagen auf Layer2-Zeilen (=Trainingsdaten fuer Layer 2) und auf
# der Bestaetigungsmenge (=finale Eingabe fuer Layer 2 bei der Bewertung).
# WICHTIG: Layer 2 sieht NIE die rohen Basis-Wahrscheinlichkeiten direkt, nur
# die Layer-1-Vorhersagen - das ist der strukturelle Unterschied zum
# einlagigen Stacking oben.
make_layer2_features <- function(newdata) {
  mats <- lapply(names(layer1_learners), function(nm) {
    p <- layer1_learners[[nm]]$predict_newdata(newdata)$prob[, class_names, drop = FALSE]
    colnames(p) <- paste0("l1_", nm, "_", class_names)
    p
  })
  do.call(cbind, mats)
}
feat_layer2_l2train <- make_layer2_features(as.data.table(feat_layer2))
feat_layer2_confirm <- make_layer2_features(as.data.table(feat_conf))

task_layer2_train <- attach_balanced_weights(build_meta_task(feat_layer2_l2train, truth_l2, "layer2_train"), class_weight_power)
meta_layer2 <- lrn("classif.multinom", predict_type = "prob")
if ("trace" %in% meta_layer2$param_set$ids()) meta_layer2$param_set$values$trace <- FALSE
meta_layer2$train(task_layer2_train)
pred_multilayer <- meta_layer2$predict_newdata(as.data.table(feat_layer2_confirm))
multilayer_bacc <- mlr3measures::bacc(truth_conf, pred_multilayer$response)
cat(sprintf("Mehrschichten-Stacking (3 Layer-1 + 1 Layer-2): %.4f\n", multilayer_bacc))

# --- Zusammenfassung ---------------------------------------------------------
summary_dt <- data.table(
  approach = c("best_single", "equal_blend", "greedy_ensemble", "single_layer_stack", "multilayer_stack"),
  bacc_confirmation = c(best_single_bacc, blend_equal_bacc, greedy_bacc, stack1_bacc, multilayer_bacc)
)
setorder(summary_dt, -bacc_confirmation)
multilayer_stack_test_results_path <- file.path(artifact_dir, "multilayer_stack_test_results.csv")
fwrite(summary_dt, multilayer_stack_test_results_path)

cat("\n=== Zusammenfassung (Bestaetigungs-BAcc, dieselbe Menge fuer alle Ansaetze) ===\n")
print(summary_dt)
cat("\nGespeichert:", multilayer_stack_test_results_path, "\n")

# --- Experiment-Tracking (SQLite) ------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "multilayer_stack_test.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed, notes =
  "Test: mehrschichtiges Stacking (AutoGluon-Idee) vs. einlagiges Stacking/Blend/Greedy-Ensemble auf dem 148-Pool")
db_log_run_config(db_con, db_run_id, list(n_candidates = n_candidates, n_layer1 = length(layer1_ids),
                                            n_layer2 = length(layer2_ids), n_confirmation = length(confirmation_ids)))
db_rsmp_id <- db_create_resampling(db_con, db_run_id, strategy = "custom_split", ratio = 0.30, seed = seed)
for (i in seq_len(nrow(summary_dt))) {
  mconf_id <- db_create_model_config(
    db_con, db_run_id, task_type = "classif", algorithm = summary_dt$approach[i],
    feature_set = "raw", preprocessing = "impute_median_mode", class_weight_power = NA_real_,
    task_id = pool$target_col_name, hyperparams = list()
  )
  db_log_metric_result(db_con, mconf_id, db_rsmp_id, "classif.bacc", summary_dt$bacc_confirmation[i])
}
db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
