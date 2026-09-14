rm(list = ls())

# =====================================================================
# reproduce_publication_benchmark.R -- eigenstaendige Reproduktion des
# in BACKLOG.md/PAPER_DRAFT.md berichteten externen 6-Datensatz-
# Benchmarks, OHNE jede Abhaengigkeit von `ML_Learning` (lokal, kein
# Git-Remote). Schliesst die in docs/research/REPRODUCIBILITY_CHECKLIST.md
# dokumentierte Luecke (AutoML-Conference ABCD-Track, Applications-
# Kategorie: "all benchmarking results must be easily reproducible").
# =====================================================================
# Laedt die 6 in docs/research/EXTERNAL_BENCHMARK_SET.md eingefrorenen
# OpenML-CC18-Datensaetze direkt per mlr3oml (kein lokaler Cache noetig,
# `git clone` + dieses Skript reicht). Fuehrt je Datensatz Protokoll v2
# (docs/research/BENCHMARK_PROTOCOL.md, "faire getunte Baselines") aus -
# dieselbe Logik wie outer_workflow_evaluation_v2_fair_baselines.R, hier
# aber selbstaendig (ohne projekteigenes 000_config.R/020_task.R/
# db_logging.R), damit EIN Skript ALLE 6 Datensaetze durchlaeuft statt
# 6 separate Projektordner zu brauchen.
#
# Primaermetrik: `classif.bacc` (Template-Standardkonvention, siehe
# BACKLOG.md "Primaermetrik classif.bacc/classif.mcc"). Kein
# Multiplier-Tuning (class_multiplier_tuning.R ist projektspezifisch,
# hier bewusst weggelassen - "Erlaubte Abweichungen" in
# BENCHMARK_PROTOCOL.md deckt das ab, `workflow_ranger` reduziert sich
# auf klassengewichtetes Training ohne Multiplier-Korrektur).
#
# Laufzeit-Hinweis: 6 Datensaetze x 3 Outer-Folds x 2 AutoTuner (15
# Evals) + 2 Default-Arme + 1 Workflow-Arm - kann je nach Maschine
# 30-90 Minuten dauern (kleine Datensaetze, aber viele Einzel-Fits).

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3oml)
  library(mlr3learners)
  library(mlr3extralearners)
  library(mlr3pipelines)
  library(mlr3tuning)
  library(mlr3mbo)
  library(mlr3measures)
  library(paradox)
})
lgr::get_logger("mlr3")$set_threshold("warn")
lgr::get_logger("bbotk")$set_threshold("warn")

seed <- 20260829  # identisch zum Auswahl-Seed in EXTERNAL_BENCHMARK_SET.md
set.seed(seed)

# --- Eingefrorenes Set (docs/research/EXTERNAL_BENCHMARK_SET.md) -------
benchmark_datasets <- data.table(
  did = c(23L, 28L, 38L, 458L, 1464L, 1480L),
  label = c("cmc", "optdigits", "sick", "analcatdata_authorship",
           "blood-transfusion", "ilpd")
)

class_weight_power <- 1.5  # Template-Default (BENCHMARK_PROTOCOL.md "Erlaubte Abweichungen")
tuning_measure_id <- "classif.bacc"
tuning_measure <- msr(tuning_measure_id)
n_outer_folds <- 3L
inner_split_ratio <- 0.75
tuned_baseline_evals <- 15L

enable_class_stratification <- function(task) {
  roles <- task$col_roles
  if (!all(task$target_names %in% roles$stratum)) {
    roles$stratum <- unique(c(roles$stratum, task$target_names))
    task$col_roles <- roles
  }
  task
}
add_balanced_class_weights <- function(task, power) {
  target_values <- task$data(cols = task$target_names)[[task$target_names]]
  class_counts <- table(target_values)
  base_weights <- length(target_values) / (length(class_counts) * class_counts)
  weights <- base_weights^power
  task_weighted <- task$clone(deep = TRUE)
  task_weighted$id <- paste0(task$id, "_weighted_p", power)
  task_weighted$cbind(data.table(weight = as.numeric(weights[as.character(target_values)])))
  task_weighted$set_col_roles("weight", roles = "weights_learner")
  task_weighted
}
make_imputed_learner <- function(base_learner, id = NULL) {
  graph <- po("imputemedian") %>>% po("imputemode") %>>% base_learner
  learner <- as_learner(graph)
  if (!is.null(id)) learner$id <- id
  learner
}
score_prediction <- function(pred) pred$score(tuning_measure)

run_ranger_default <- function(outer_train, outer_test) {
  learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  learner$train(outer_train)
  score_prediction(learner$predict(outer_test))
}
run_lightgbm_default <- function(outer_train, outer_test) {
  learner <- make_imputed_learner(lrn("classif.lightgbm", num_iterations = 200, predict_type = "prob"))
  learner$train(outer_train)
  score_prediction(learner$predict(outer_test))
}
run_tuned_ranger <- function(outer_train, outer_test) {
  base_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  search_space <- ps(
    classif.ranger.mtry.ratio = p_dbl(0.1, 1),
    classif.ranger.min.node.size = p_int(1, 20),
    classif.ranger.sample.fraction = p_dbl(0.5, 1)
  )
  at <- auto_tuner(
    tuner = mlr3tuning::tnr("random_search"), learner = base_learner,
    resampling = rsmp("holdout", ratio = inner_split_ratio),
    measure = tuning_measure, search_space = search_space,
    terminator = trm("evals", n_evals = tuned_baseline_evals)
  )
  at$train(outer_train)
  list(score = score_prediction(at$predict(outer_test)), inner_score = at$tuning_result[[tuning_measure_id]])
}
run_tuned_lightgbm <- function(outer_train, outer_test) {
  base_learner <- make_imputed_learner(
    lrn("classif.lightgbm", num_iterations = 100, bagging_freq = 1, predict_type = "prob")
  )
  search_space <- ps(
    classif.lightgbm.learning_rate = p_dbl(0.01, 0.3),
    classif.lightgbm.num_leaves = p_int(15, 255),
    classif.lightgbm.min_data_in_leaf = p_int(5, 100),
    classif.lightgbm.feature_fraction = p_dbl(0.5, 1.0),
    classif.lightgbm.bagging_fraction = p_dbl(0.5, 1.0)
  )
  at <- auto_tuner(
    tuner = mlr3tuning::tnr("mbo"), learner = base_learner,
    resampling = rsmp("holdout", ratio = inner_split_ratio),
    measure = tuning_measure, search_space = search_space,
    terminator = trm("evals", n_evals = tuned_baseline_evals)
  )
  at$train(outer_train)
  list(score = score_prediction(at$predict(outer_test)), inner_score = at$tuning_result[[tuning_measure_id]])
}
run_workflow_ranger <- function(outer_train, outer_test) {
  weighted_outer_train <- add_balanced_class_weights(outer_train, class_weight_power)
  final_learner <- make_imputed_learner(lrn("classif.ranger", predict_type = "prob", seed = seed))
  final_learner$train(weighted_outer_train)
  score_prediction(final_learner$predict(outer_test))
}

run_dataset <- function(did, label) {
  cat(sprintf("\n########## %s (OpenML DID %d) ##########\n", label, did))
  odata <- odt(id = did)
  task_full <- as_task(odata)
  task_full$id <- label
  task_full <- enable_class_stratification(task_full)

  outer_resampling <- rsmp("cv", folds = n_outer_folds)
  outer_resampling$instantiate(task_full)

  results <- data.table(dataset = character(0), outer_fold = integer(0), arm = character(0), score = numeric(0))
  for (fold in seq_len(n_outer_folds)) {
    train_ids <- outer_resampling$train_set(fold)
    test_ids <- outer_resampling$test_set(fold)
    outer_train <- task_full$clone(deep = TRUE)$filter(train_ids)
    outer_test <- task_full$clone(deep = TRUE)$filter(test_ids)
    cat(sprintf("  -- Outer Fold %d/%d (Train n=%d, Test n=%d) --\n", fold, n_outer_folds, outer_train$nrow, outer_test$nrow))

    s_rd <- run_ranger_default(outer_train, outer_test)
    results <- rbind(results, data.table(dataset = label, outer_fold = fold, arm = "ranger_default", score = s_rd))
    s_ld <- run_lightgbm_default(outer_train, outer_test)
    results <- rbind(results, data.table(dataset = label, outer_fold = fold, arm = "lightgbm_default", score = s_ld))
    r_tr <- run_tuned_ranger(outer_train, outer_test)
    results <- rbind(results, data.table(dataset = label, outer_fold = fold, arm = "tuned_ranger", score = r_tr$score))
    r_tl <- run_tuned_lightgbm(outer_train, outer_test)
    results <- rbind(results, data.table(dataset = label, outer_fold = fold, arm = "tuned_lightgbm", score = r_tl$score))
    best_is_ranger <- r_tr$inner_score >= r_tl$inner_score
    s_best <- if (best_is_ranger) r_tr$score else r_tl$score
    results <- rbind(results, data.table(dataset = label, outer_fold = fold, arm = "best_single_tuned_model", score = s_best))
    s_wf <- run_workflow_ranger(outer_train, outer_test)
    results <- rbind(results, data.table(dataset = label, outer_fold = fold, arm = "workflow_ranger", score = s_wf))
    cat(sprintf("     ranger_default=%.4f lightgbm_default=%.4f tuned_ranger=%.4f tuned_lightgbm=%.4f workflow_ranger=%.4f\n",
                s_rd, s_ld, r_tr$score, r_tl$score, s_wf))
  }
  results
}

all_results <- rbindlist(lapply(seq_len(nrow(benchmark_datasets)), function(i)
  run_dataset(benchmark_datasets$did[i], benchmark_datasets$label[i])
))

summary_dt <- all_results[, .(mean_score = mean(score), sd_score = sd(score)),
                          by = .(dataset, arm)][order(dataset, -mean_score)]

cat("\n\n=== Reproduktion: Zusammenfassung ueber alle 6 Datensaete (Metrik: classif.bacc) ===\n")
print(summary_dt)

out_dir <- file.path(".", "_artifacts")
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
fwrite(all_results, file.path(out_dir, "reproduce_publication_benchmark_results.csv"))
fwrite(summary_dt, file.path(out_dir, "reproduce_publication_benchmark_summary.csv"))
cat("\nGespeichert unter:", out_dir, "\n")
cat("\nVergleich mit BACKLOG.md/PAPER_DRAFT.md: workflow_ranger sollte bei\n")
cat("ilpd/sick/blood-transfusion klar vorne liegen, bei cmc/optdigits/\n")
cat("analcatdata_authorship nah an den getunten Baselines (siehe P1-Status).\n")
