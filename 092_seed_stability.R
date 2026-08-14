# =====================================================================
# 092_seed_stability.R -- Seed-/Hyperparameter-Rausch-Stabilitaet (siehe
# seed_stability.R und TARGETS.md fuer Herkunft/Verifikation).
# =====================================================================
# Laeuft NACH 090_ranger_tuning.R (braucht ranger_tuning_instance_path fuer
# den Jitter-Test um die getunte Konfiguration) - der Seed-Test allein
# laeuft auch ohne 090 (nutzt base_learner_constructors$ranger), der
# Jitter-Test wird ohne vorhandene Tuning-Instanz uebersprungen.
rm(list = ls())
suppressPackageStartupMessages({
  library(data.table); library(mlr3); library(mlr3learners); library(DBI)
})

source("000_config.R")
source(file.path(project_dir, "seed_stability.R"))
source(file.path(project_dir, "db_logging.R"))
set.seed(seed)
dir.create(artifact_dir, showWarnings = FALSE, recursive = TRUE)

if (!file.exists(task_train_small_path)) {
  source(file.path(project_dir, "020_task.R"))
}
task <- readRDS(task_train_small_path)

set.seed(seed)
n <- task$nrow
test_idx <- sample(n, round((1 - validation_ratio) * n))
train_idx <- setdiff(seq_len(n), test_idx)
task_train <- task$clone(deep = TRUE)$filter(train_idx)
task_test <- task$clone(deep = TRUE)$filter(test_idx)

measure <- msr(baseline_measure_ids[1])

if (!"ranger" %in% names(base_learner_constructors)) {
  stop("base_learner_constructors braucht einen 'ranger'-Eintrag fuer diese Analyse.")
}
cv_learner <- base_learner_constructors$ranger()
rr <- resample(task_train, cv_learner, rsmp("cv", folds = seed_stability_cv_folds))
cv_scores <- rr$score(measure)[[measure$id]]
cat("CV-Referenz-Scores:", paste(round(cv_scores, 4), collapse = ", "), " SD=", round(sd(cv_scores), 5), "\n")

# --- Seed-Stabilitaet (immer) ------------------------------------------------
ctor_seed <- function(s) {
  l <- base_learner_constructors$ranger()
  l$param_set$values$seed <- s
  l
}
seed_scores <- seed_stability(task_train, task_test, ctor_seed, measure,
                               n_seeds = seed_stability_n_seeds, seed = seed)
res_seed <- report_stability("Seed-Varianz, base_learner_constructors$ranger", seed_scores, cv_scores,
                              cv_warn_relative = seed_stability_cv_warn_relative)

# --- Hyperparameter-Jitter (nur falls 090 bereits gelaufen ist) -------------
res_jitter <- NULL
if (exists("ranger_tuning_instance_path") && file.exists(ranger_tuning_instance_path)) {
  inst <- readRDS(ranger_tuning_instance_path)
  best <- inst$result_learner_param_vals
  names(best) <- sub("^classif\\.ranger\\.", "", names(best))
  base_params <- list(mtry.ratio = best$mtry.ratio, min.node.size = best$min.node.size,
                       sample.fraction = best$sample.fraction)
  jr <- seed_stability_jitter_relative
  jitter_fns <- list(
    mtry.ratio = function(x) min(1, max(0.05, x * runif(1, 1 - jr, 1 + jr))),
    min.node.size = function(x) max(1, round(x * runif(1, 1 - 2 * jr, 1 + 2 * jr))),
    sample.fraction = function(x) min(1, max(0.1, x * runif(1, 1 - jr, 1 + jr)))
  )
  learner_ctor <- function(p) lrn("classif.ranger", num.trees = ranger_tuning_final_trees, seed = seed,
                                   mtry.ratio = p$mtry.ratio, min.node.size = p$min.node.size,
                                   sample.fraction = p$sample.fraction)
  jitter_result <- hyperparam_jitter_stability(task_train, task_test, base_params, jitter_fns,
                                                learner_ctor, measure,
                                                n_jitter = seed_stability_n_jitter, seed = seed)
  res_jitter <- report_stability("Hyperparameter-Jitter um getunte Ranger-Config", jitter_result$scores,
                                  cv_scores, cv_warn_relative = seed_stability_cv_warn_relative)
} else {
  cat("\nHyperparameter-Jitter uebersprungen: ranger_tuning_instance_path fehlt - erst 090_ranger_tuning.R ausfuehren.\n")
}

results <- if (is.null(res_jitter)) res_seed else rbindlist(list(res_seed, res_jitter))
fwrite(results, seed_stability_results_path)
cat("\nGespeichert:", seed_stability_results_path, "\n")

# --- Experiment-Tracking (SQLite) -------------------------------------------
db_con <- db_connect()
db_proj_id <- db_get_or_create_project(db_con, project_name)
db_wf_id <- db_get_or_create_workflow(db_con, db_proj_id, "script", "092_seed_stability.R")
db_run_id <- db_create_run(db_con, db_wf_id, seed = seed,
  notes = paste0("Seed-/Hyperparameter-Rausch-Stabilitaet: ", nrow(results), " Checks"))
db_log_run_config(db_con, db_run_id, list(
  seed_stability_n_seeds = seed_stability_n_seeds, seed_stability_n_jitter = seed_stability_n_jitter,
  seed_stability_cv_folds = seed_stability_cv_folds
))
rsmp_id <- db_create_resampling(db_con, db_run_id, strategy = "holdout", ratio = validation_ratio, seed = seed)
for (i in seq_len(nrow(results))) {
  mconf_id <- db_create_model_config(
    db_con, db_run_id, task_type = "classif", algorithm = "ranger",
    feature_set = "raw", task_id = task$id,
    hyperparams = list(check = results$check[i])
  )
  db_log_metric_result(db_con, mconf_id, rsmp_id, "sd_own", results$sd_own[i])
  db_log_metric_result(db_con, mconf_id, rsmp_id, "sd_cv_reference", results$sd_cv_reference[i])
}
db_finish_run(db_con, db_run_id)
DBI::dbDisconnect(db_con)
cat("Experiment-DB   :", experiments_db_path, "\n")
