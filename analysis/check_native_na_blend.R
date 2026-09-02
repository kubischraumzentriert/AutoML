rm(list = ls())

suppressPackageStartupMessages({
  library(data.table); library(mlr3); library(mlr3learners)
  library(mlr3extralearners); library(mlr3pipelines); library(mlr3measures)
})

source("000_config.R")
lgr::get_logger("mlr3")$set_threshold("warn")
set.seed(seed)

# Fairer Test der Notebook-Idee: NA-native Learner (LightGBM) OHNE Imputation vs.
# unser imputiertes LightGBM vs. Ranger; plus Ranger+LightGBM-Blend (lohnt nur,
# wenn native-NA-LightGBM nah an Ranger ist -> gleich starke Modelle). s6e7 hat
# 7-12% strukturierte, train/test-identische Missingness -> native NA-Behandlung
# koennte das Missingness-Signal nutzen, das Median/Mode-Imputation loescht.
#
# ERGEBNIS (2026-07-21, 10%-Subset-CV, power=1.5) - BEIDE Hypothesen widerlegt:
#   LightGBM imputiert   BAcc 0.9407 / MCC 0.8078
#   LightGBM native-NA   BAcc 0.9407 / MCC 0.8125  <- BAcc IDENTISCH (native NA
#                        aendert Vorhersagen leicht -> MCC, aber KEIN BAcc-Gewinn)
#   Ranger               BAcc 0.9464 / MCC 0.8102  <- weiter bestes Modell
#   Blend Ranger+LGB     BAcc 0.9443 / MCC 0.8123  <- SCHLECHTER als Ranger (LGB
#                        bleibt ~0.006 unter Ranger -> verwaessert, 4. Bestaetigung)
# Fazit: Imputation kostet hier keine BAcc; Blend hilft nicht (LGB nicht stark
# genug). Der Notebook-Wert 0.9498 kam von VOLLEN Daten, nicht von native-NA.
# -> keine Template-Aenderung, s6e7 an seiner Decke. Beleg-Skript.
if (!file.exists(task_train_small_path)) source(file.path(project_dir, "020_task.R"))
task_w <- add_balanced_class_weights(readRDS(task_train_small_path), 1.5)

lgb_cfg <- function() lrn("classif.lightgbm", num_iterations = 500, learning_rate = 0.05, predict_type = "prob")
rf_cfg  <- function() lrn("classif.ranger", num.trees = 500, respect.unordered.factors = "order", predict_type = "prob")
impute  <- function() po("imputemedian") %>>% po("imputemode")

learners <- list(
  as_learner(impute() %>>% lgb_cfg()),                       # LightGBM imputiert (unser Weg)
  as_learner(lgb_cfg()),                                     # LightGBM native NA (Notebook-Weg)
  as_learner(impute() %>>% rf_cfg()),                        # Ranger (braucht Imputation)
  as_learner(po("copy", 2, id = "cp") %>>% gunion(list(      # Blend: Ranger(imp) + LightGBM(native)
    po("imputemedian", id = "ri") %>>% po("imputemode", id = "rm") %>>% po("learner", rf_cfg(), id = "rf"),
    po("learner", lgb_cfg(), id = "lgb"))) %>>% po("classifavg", innum = 2, id = "avg"))
)
labels <- c("LightGBM imputiert (Ref)", "LightGBM native-NA", "Ranger (Ref)",
            "Blend Ranger + native-NA-LightGBM")

rs <- rsmp("cv", folds = cv_folds)
res <- rbindlist(lapply(seq_along(learners), function(i) {
  set.seed(seed)
  rr <- resample(task_w, learners[[i]], rs$clone(deep = TRUE))
  data.table(learner = labels[i],
             bacc = round(rr$aggregate(msr("classif.bacc")), 4),
             mcc  = round(rr$aggregate(msr("classif.mcc")), 4))
}))

cat("=== s6e7: native-NA vs. Imputation + Ranger+LightGBM-Blend (power=1.5, CV) ===\n")
print(res)
cat("\nDB-Referenz: Ranger 0.9473 CV, unser LightGBM 0.9460, altes Ensemble 0.9459.\n")
fwrite(res, file.path(artifact_dir, "native_na_blend_check.csv"))
