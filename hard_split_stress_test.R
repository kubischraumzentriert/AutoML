# =============================================================================
# hard_split_stress_test.R -- P2, JOSS-Technique-Watch-Prototyp #2
# (2026-08-31, inspiriert durch astartes - Burns et al. 2023, JOSS
# 10.21105/joss.05996, siehe JOSS_TECHNIQUE_WATCH.md).
# =============================================================================
# LUECKE, die dieses Modul schliesst: normale (zufaellige) Train/Test-
# Splits pruefen vor allem INTERPOLATION - ob das Modell innerhalb
# derselben Datenverteilung generalisiert, aus der es trainiert wurde.
# Ein strukturell schwierigerer, distanzbasierter Split (Train/Test durch
# Feature-Raum-Clusterung statt Zufall getrennt) prueft dagegen
# EXTRAPOLATION - ob das Modell auch auf eine STRUKTURELL ANDERE Region
# des Feature-Raums generalisiert, die es beim Training nie gesehen hat.
# Ein Modell, das nur beim Zufalls-Split stabil ist, aber beim
# Cluster-Split stark einbricht, traegt ein hoeheres Generalisierungs-
# risiko, als ein normaler CV-Score allein zeigt.
#
# Bewusst NICHT die Kennard-Stone-/astartes-Implementierung uebernommen
# (Python, Cheminformatik-fokussiert) - stattdessen dieselbe GRUNDIDEE
# (strukturell schwieriger statt zufaelliger Split) mit einer einfacheren,
# nativen R-Umsetzung (`kmeans()` auf den numerischen Features): das
# kleinste Cluster wird als Test-Set gehalten, der Rest ist Training -
# eine bewusst simple, aber echte Extrapolations-Herausforderung.
#
# Ergaenzt `group_resampling.R` (dort: eine BEKANNTE Gruppenstruktur, z.B.
# Patienten-ID, wird respektiert) UM den Fall, dass KEINE explizite
# Gruppenspalte existiert - die "Gruppen" werden hier direkt aus dem
# Feature-Raum abgeleitet (Clusterung), nicht aus einer vorgegebenen
# Spalte.
#
# Folgt demselben Referenzbereich-/z-Score-Muster wie
# `generalization_gap.R` (dort: Luecken-Referenzbereich aus mehreren
# ungetunten Baselines; hier: Score-Referenzbereich aus mehreren
# ZUFAELLIGEN Holdout-Splits GLEICHER Testgroesse) - |z| > 2 => auffaellig,
# aus Konsistenzgruenden derselbe Schwellenwert wie dort.

#' Teilt einen mlr3-Task per k-means-Clusterung der numerischen Features in
#' einen strukturell schwierigen Train/Test-Split: das KLEINSTE Cluster wird
#' als Test-Set gehalten (Extrapolations-Herausforderung), der Rest ist
#' Training.
#' @param task ein mlr3 Task (TaskClassif/TaskRegr)
#' @param k Anzahl Cluster (Default 2 - haelt den Test-Anteil meist in einer
#'   plausiblen Groessenordnung; hoehere k erzeugen tendenziell kleinere,
#'   "extremere" Test-Cluster)
#' @param seed Seed fuer `kmeans()` (Clustering selbst ist deterministisch
#'   bei festem Seed - KEIN Wiederholungs-Rauschen wie bei einem Zufalls-
#'   Split, das ist bewusst so: der Cluster-Split ist eine STRUKTURELLE
#'   Eigenschaft der Daten, kein Zufalls-Draw)
#' @return list(train = Zeilen-IDs, test = Zeilen-IDs, test_ratio = Anteil)
cluster_based_hard_split <- function(task, k = 2, seed = 1) {
  numeric_cols <- task$feature_names[task$feature_types$type %in% c("numeric", "integer")]
  stopifnot("cluster_based_hard_split() braucht mindestens 1 numerisches Feature fuer die Clusterung" = length(numeric_cols) >= 1)
  feat <- task$data(cols = numeric_cols)
  feat <- as.data.frame(lapply(feat, function(col) {
    col[is.na(col)] <- median(col, na.rm = TRUE)
    col
  }))
  feat_scaled <- scale(as.matrix(feat))
  feat_scaled[is.nan(feat_scaled)] <- 0 # Spalten mit SD=0 (konstant) -> scale() liefert NaN, auf 0 setzen

  set.seed(seed)
  km <- kmeans(feat_scaled, centers = k, nstart = 5)
  cluster_sizes <- table(km$cluster)
  test_cluster <- as.integer(names(which.min(cluster_sizes)))
  test_rows <- task$row_ids[km$cluster == test_cluster]
  train_rows <- setdiff(task$row_ids, test_rows)

  list(train = train_rows, test = test_rows, test_ratio = length(test_rows) / task$nrow)
}

#' Score-Verteilung bei ZUFAELLIGEN Holdout-Splits GLEICHER Testgroesse wie
#' der harte Cluster-Split - der "Referenzbereich" fuer normale
#' Split-zu-Split-Streuung.
#' @param task,learner_ctor,measure siehe `hard_split_stress_test()`
#' @param test_ratio Ziel-Testanteil (aus `cluster_based_hard_split()`)
#' @param n_repeats Anzahl Wiederholungen (Default 10)
random_split_score_distribution <- function(task, learner_ctor, measure, test_ratio, n_repeats = 10, seed = 1) {
  set.seed(seed)
  vapply(seq_len(n_repeats), function(i) {
    ids <- mlr3::partition(task, ratio = 1 - test_ratio)
    learner <- learner_ctor()
    learner$train(task, row_ids = ids$train)
    pred <- learner$predict(task, row_ids = ids$test)
    pred$score(measure)[[measure$id]]
  }, numeric(1))
}

#' Voller Extrapolations-Stresstest: harter Cluster-Split vs. Referenzbereich
#' aus zufaelligen Splits gleicher Groesse, mit z-Score-Einordnung (dasselbe
#' Muster wie `generalization_gap_report()`).
#' @param higher_is_better TRUE fuer BAcc/MCC/AUC, FALSE fuer RMSE/Deviance
#' @param flag_threshold_z Schwelle fuer "AUFFAELLIG" (Default -2, siehe
#'   Kopfkommentar - konsistent mit `generalization_gap.R`)
hard_split_stress_test <- function(task, learner_ctor, measure, k = 2, n_repeats = 10,
                                    seed = 1, higher_is_better = TRUE, flag_threshold_z = -2,
                                    label = "hard-split-stress-test") {
  split <- cluster_based_hard_split(task, k = k, seed = seed)

  learner_hard <- learner_ctor()
  learner_hard$train(task, row_ids = split$train)
  pred_hard <- learner_hard$predict(task, row_ids = split$test)
  hard_score <- pred_hard$score(measure)[[measure$id]]

  ref_scores <- random_split_score_distribution(task, learner_ctor, measure, split$test_ratio, n_repeats, seed)
  ref_mean <- mean(ref_scores); ref_sd <- sd(ref_scores)

  hard_oriented <- if (higher_is_better) hard_score else -hard_score
  ref_oriented_mean <- if (higher_is_better) ref_mean else -ref_mean
  z <- if (ref_sd == 0) NA_real_ else (hard_oriented - ref_oriented_mean) / ref_sd
  flagged <- !is.na(z) && z < flag_threshold_z

  cat(sprintf("\n=== Hard-Split-Stresstest: %s ===\n", label))
  cat(sprintf("Cluster-Split (k=%d): Test-Cluster n=%d (%.1f%% von n=%d)\n",
              k, length(split$test), split$test_ratio * 100, task$nrow))
  cat(sprintf("Score auf hartem Cluster-Split: %.4f\n", hard_score))
  cat(sprintf("Referenzbereich (%d zufaellige Splits, gleiche Testgroesse): Mittel=%.4f SD=%.4f\n",
              n_repeats, ref_mean, ref_sd))
  cat(sprintf("z-Score des harten Splits ggue. Referenz: %s\n", if (is.na(z)) "n/a" else sprintf("%.2f", z)))
  cat(if (flagged)
    "=> AUFFAELLIG: der harte Cluster-Split faellt deutlich schlechter aus als normale Split-Streuung -\n   Hinweis auf echtes Extrapolationsrisiko, das ein zufaelliger CV-Score allein nicht zeigt.\n"
    else "=> unauffaellig: der harte Split liegt im/nahe des normalen Referenzbereichs.\n")

  invisible(list(hard_score = hard_score, ref_scores = ref_scores, ref_mean = ref_mean,
                  ref_sd = ref_sd, z = z, flagged = flagged, test_ratio = split$test_ratio))
}
