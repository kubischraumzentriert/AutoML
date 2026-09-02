rm(list = ls())

suppressPackageStartupMessages({ library(data.table); library(lightgbm) })

source("000_config.R")

# =====================================================================
# hyperband_budget_test.R -- Test: echtes Hyperband (mehrere Successive-
# Halving-Brackets mit unterschiedlicher Aggressivitaet, Li et al. 2018)
# vs. "mehrere Kandidaten auf vollem Budget" (aktuelles Template-Muster)
# beim LightGBM-Tuning. Literaturroadmap-Punkt 4 (siehe TARGETS.md):
# "Hyperband/BOHB statt teurer Voll-CV fuer jeden Kandidaten". BOHB
# (Bayesian-Optimization+Hyperband) ist in der R-mlr3-Oekosystem NICHT
# als fertiger Tuner verfuegbar (mlr3hyperband hat nur Successive-
# Halving/Hyperband, kein BOHB) - dieser Test deckt daher gezielt
# Hyperband ab, nicht BOHB.
#
# Vorarbeit: einfaches Successive Halving (EINE feste Aggressivitaet)
# wurde bereits 2026-08-10 getestet (openml-drift-detection-test,
# bank-marketing/electricity) - negativ/uneindeutig (gegensaetzliche
# Richtung auf beiden Datensaetzen, beide winzig). Hyperbands Kernidee
# ist aber genau, dass man die Aggressivitaet NICHT festlegen muss -
# mehrere Brackets (von sehr aggressiv bis "kein fruehes Verwerfen")
# laufen parallel, das schwaechste Glied der einfachen SH-Idee wird
# dadurch strukturell vermieden. Dieser Test prueft, ob das den
# fruehen Negativbefund aufhebt - UND laeuft erstmals gegen das
# Template-eigene Projekt (health_condition, 3-Klassen-BAcc) statt der
# frueheren OpenML-Datensaetze.
#
# Bewusst per Hand implementiert (nicht mlr3hyperband) - LightGBM
# unterstuetzt Hotstart (`init_model`), volle Kontrolle ueber die
# Budget-Buchhaltung ist damit einfacher zu verifizieren als ueber die
# mlr3tuning/mlr3hyperband-Abstraktion (dieselbe Entscheidung wie beim
# vorherigen SH-Test). Baseline identisch zum SH-Test: M Kandidaten
# direkt auf vollem Budget, M so gewaehlt, dass beide Ansaetze exakt
# dasselbe Gesamtbudget (kumulierte Boosting-Runden) verbrauchen -
# isoliert die Frage "adaptive fruehe Elimination vs. volles Budget je
# Kandidat" von der separaten (in diesem Projekt bereits beantworteten)
# Frage "Random Search vs. Bayesian Optimization" (siehe TARGETS.md:
# "Tuning bringt marginale Gewinne").
SEED_BASE <- 42
N_SEEDS <- 2L
R_MAX <- 200L      # = lightgbm_tuning_final_iterations
R_MIN <- 25L       # = lightgbm_tuning_search_iterations (Ausgangsbudget)
ETA <- 2

# --- Daten vorbereiten (einmalig median-imputiert, Faktoren integer-
# kodiert - fuer rohes lgb.train(), analog zum SH-Test) -------------------
task <- readRDS(task_train_small_path)
dt <- task$data()
feat_cols <- task$feature_names
for (col in feat_cols) {
  if (is.numeric(dt[[col]])) dt[is.na(get(col)), (col) := median(dt[[col]], na.rm = TRUE)]
}
X_full <- as.matrix(as.data.table(lapply(dt[, feat_cols, with = FALSE], function(col) {
  if (is.factor(col)) as.integer(col) - 1L else as.numeric(col)
})))
y_full <- as.integer(dt[[task$target_names]]) - 1L
n_classes <- length(unique(y_full))

bacc_multiclass <- function(truth_int, pred_prob_mat) {
  pred <- max.col(pred_prob_mat, ties.method = "first") - 1L
  cm <- table(factor(truth_int, levels = 0:(n_classes - 1)), factor(pred, levels = 0:(n_classes - 1)))
  mean(diag(cm) / rowSums(cm))
}

random_cfg <- function() list(
  num_leaves = sample(15:255, 1), learning_rate = runif(1, 0.01, 0.3),
  min_data_in_leaf = sample(5:100, 1), feature_fraction = runif(1, 0.5, 1.0),
  bagging_fraction = runif(1, 0.5, 1.0)
)
lgb_params <- function(cfg) list(
  objective = "multiclass", num_class = n_classes, verbose = -1L,
  num_leaves = cfg$num_leaves, learning_rate = cfg$learning_rate,
  min_data_in_leaf = cfg$min_data_in_leaf, feature_fraction = cfg$feature_fraction,
  bagging_fraction = cfg$bagging_fraction, bagging_freq = 1L
)

# --- EIN Successive-Halving-Bracket (n Kandidaten, Start bei r_min,
# verdoppelt bis R_MAX, eliminiert je Stufe auf 1/ETA) ----------------------
run_bracket <- function(n, r_start, Xtr, ytr, Xva, yva) {
  cands <- lapply(seq_len(n), function(i) list(cfg = random_cfg(), booster = NULL, rounds_done = 0L))
  budget <- r_start
  total_spent <- 0L
  repeat {
    for (i in seq_along(cands)) {
      inc <- budget - cands[[i]]$rounds_done
      if (inc > 0) {
        m <- lgb.train(lgb_params(cands[[i]]$cfg), lgb.Dataset(Xtr, label = ytr, free_raw_data = FALSE),
                        nrounds = inc, init_model = cands[[i]]$booster)
        cands[[i]]$booster <- m; cands[[i]]$rounds_done <- budget
        total_spent <- total_spent + inc
      }
      cands[[i]]$bacc <- bacc_multiclass(yva, predict(cands[[i]]$booster, Xva))
    }
    if (budget >= R_MAX || length(cands) <= 1) break
    ord <- order(vapply(cands, `[[`, numeric(1), "bacc"), decreasing = TRUE)
    keep_n <- max(1L, floor(length(cands) / ETA))
    cands <- cands[ord[seq_len(keep_n)]]
    budget <- min(R_MAX, round(budget * ETA))
  }
  ord <- order(vapply(cands, `[[`, numeric(1), "bacc"), decreasing = TRUE)
  list(best = cands[[ord[1]]], total_spent = total_spent)
}

# --- Hyperband: mehrere Brackets mit fallender Aggressivitaet --------------
run_hyperband <- function(Xtr, ytr, Xva, yva, seed) {
  set.seed(seed)
  s_max <- floor(log(R_MAX / R_MIN) / log(ETA))
  B <- (s_max + 1) * R_MAX
  best_overall <- NULL; total_spent <- 0L
  for (s in rev(seq(0, s_max))) {
    n <- ceiling(B / R_MAX * ETA^s / (s + 1))
    r_start <- max(R_MIN, round(R_MAX * ETA^(-s)))
    bracket <- run_bracket(n, r_start, Xtr, ytr, Xva, yva)
    total_spent <- total_spent + bracket$total_spent
    cat(sprintf("  Bracket s=%d: n=%d, Start-Budget=%d, bestes Valid-BAcc=%.4f (Budget=%d Runden)\n",
                s, n, r_start, bracket$best$bacc, bracket$best$rounds_done))
    if (is.null(best_overall) || bracket$best$bacc > best_overall$bacc) best_overall <- bracket$best
  }
  list(best = best_overall, total_spent = total_spent)
}

# --- Baseline: M Kandidaten direkt auf vollem Budget (identisches
# Gesamtbudget wie Hyperband) -----------------------------------------------
run_baseline_full_budget <- function(Xtr, ytr, Xva, yva, seed, n_candidates) {
  set.seed(seed)
  best <- NULL; total_spent <- 0L
  for (i in seq_len(n_candidates)) {
    cfg <- random_cfg()
    m <- lgb.train(lgb_params(cfg), lgb.Dataset(Xtr, label = ytr), nrounds = R_MAX)
    total_spent <- total_spent + R_MAX
    bacc <- bacc_multiclass(yva, predict(m, Xva))
    if (is.null(best) || bacc > best$bacc) best <- list(cfg = cfg, booster = m, bacc = bacc, rounds_done = R_MAX)
  }
  list(best = best, total_spent = total_spent)
}

# --- 3-Wege-Split (klassenstratifiziert): Tune-Train/Tune-Valid fuer
# Hyperband/Baseline, Bestaetigung UNBERUEHRT fuer die finale Bewertung -----
set.seed(SEED_BASE)
by_class <- split(seq_len(nrow(X_full)), y_full)
splits <- lapply(by_class, function(idx) {
  n <- length(idx); idx_s <- sample(idx)
  cuts <- round(cumsum(c(0.6, 0.2, 0.2)) * n)
  list(idx_s[seq_len(cuts[1])], idx_s[(cuts[1] + 1):cuts[2]], idx_s[(cuts[2] + 1):n])
})
i_tr <- unlist(lapply(splits, `[[`, 1)); i_va <- unlist(lapply(splits, `[[`, 2)); i_te <- unlist(lapply(splits, `[[`, 3))
Xtr <- X_full[i_tr, ]; ytr <- y_full[i_tr]
Xva <- X_full[i_va, ]; yva <- y_full[i_va]
Xte <- X_full[i_te, ]; yte <- y_full[i_te]
cat(sprintf("Split: train=%d valid=%d bestaetigung=%d\n", length(i_tr), length(i_va), length(i_te)))

hb_res <- list(); base_res <- list()
for (s_idx in seq_len(N_SEEDS)) {
  cat(sprintf("\n--- Seed %d/%d ---\n", s_idx, N_SEEDS))
  cat("Hyperband:\n")
  hb <- run_hyperband(Xtr, ytr, Xva, yva, SEED_BASE + s_idx)
  n_baseline_candidates <- max(1L, round(hb$total_spent / R_MAX))
  cat(sprintf("Hyperband-Gesamtbudget: %d Runden -> Baseline-Kandidaten (je %d Runden): %d\n",
              hb$total_spent, R_MAX, n_baseline_candidates))
  bl <- run_baseline_full_budget(Xtr, ytr, Xva, yva, SEED_BASE + s_idx, n_baseline_candidates)

  hb_test_bacc <- bacc_multiclass(yte, predict(hb$best$booster, Xte))
  bl_test_bacc <- bacc_multiclass(yte, predict(bl$best$booster, Xte))
  hb_res[[s_idx]] <- list(valid_bacc = hb$best$bacc, test_bacc = hb_test_bacc, rounds = hb$total_spent)
  base_res[[s_idx]] <- list(valid_bacc = bl$best$bacc, test_bacc = bl_test_bacc, rounds = bl$total_spent)
  cat(sprintf("Seed %d: Hyperband TEST-BAcc=%.4f (Runden=%d) | Baseline TEST-BAcc=%.4f (Runden=%d)\n",
              s_idx, hb_test_bacc, hb$total_spent, bl_test_bacc, bl$total_spent))
}

hb_test_baccs <- sapply(hb_res, `[[`, "test_bacc")
bl_test_baccs <- sapply(base_res, `[[`, "test_bacc")
cat(sprintf("\n=== Zusammenfassung (health_condition, %d Seeds) ===\n", N_SEEDS))
cat(sprintf("Hyperband mean TEST-BAcc=%.4f [%s]\n", mean(hb_test_baccs), paste(round(hb_test_baccs, 4), collapse = ", ")))
cat(sprintf("Baseline  mean TEST-BAcc=%.4f [%s]\n", mean(bl_test_baccs), paste(round(bl_test_baccs, 4), collapse = ", ")))
cat(sprintf("Differenz (Hyperband - Baseline): %+.4f\n", mean(hb_test_baccs) - mean(bl_test_baccs)))

saveRDS(list(hyperband = hb_res, baseline = base_res), file.path(artifact_dir, "hyperband_budget_test_result.rds"))
cat("\nGespeichert:", file.path(artifact_dir, "hyperband_budget_test_result.rds"), "\n")
