# =============================================================================
# benchmark_statistics_report.R -- generische Mehrfach-Datensatz-Statistik
# fuer "ist Methode A ueber mehrere Datensaetze hinweg systematisch besser".
# =============================================================================
# JOSS_TECHNIQUE_WATCH.md Kandidat #3 (Autorank/Herbold 2020, Methodik nach
# Demsar 2006) - Backlog-Vorschlag, 2026-09-18. Ergaenzt bootstrap_metric_ci.R
# (beantwortet "ist A besser als B auf DIESEM EINEN Datensatz") um die
# komplementaere Frage "ist A ueber MEHRERE Datensaetze hinweg systematisch
# besser" - bislang nur als Einzelskript fuer einen konkreten Vergleich
# geloest (analysis/p2_level2_significance_test.R), hier generalisiert.
#
# Demsar (2006) "Statistical Comparisons of Classifiers over Multiple Data
# Sets": bei genau 2 Methoden -> gepaarter Wilcoxon-Signed-Rank-Test; bei
# >=3 Methoden -> Friedman-Test (omnibus, rangbasiert, verteilungsfrei) und
# bei Signifikanz ein Nemenyi-Post-hoc-Test (paarweise, kontrolliert die
# Familienfehlerrate ueber alle Paare). R-only-Policy: keine `scmamp`-
# Abhaengigkeit, Nemenyi-kritische-Differenz per Standard-Formel + der in
# Demsar (2006) Tabelle 5(b) veroeffentlichten q_alpha-Werte (alpha=0.05,
# k=2..10 Methoden) selbst nachgebaut - Basis-R (`stats::friedman.test`)
# reicht.

.nemenyi_q_alpha_05 <- c(
  `2` = 1.960, `3` = 2.343, `4` = 2.569, `5` = 2.728, `6` = 2.850,
  `7` = 2.949, `8` = 3.031, `9` = 3.102, `10` = 3.164
)

#' Gepaarter Wilcoxon-Signed-Rank-Test fuer genau 2 Methoden ueber n
#' Datensaetze - Demsar (2006) Abschnitt 3.1.
#'
#' @param x,y Numerische Vektoren gleicher Laenge (ein Wert je Datensatz).
#' @param higher_better TRUE, wenn ein hoeherer Wert besser ist (Default).
#' @return Liste: `median_diff` (Median von x-y, im Sinne von "positiv =
#'   x besser" bei `higher_better=TRUE`), `statistic`, `p_value`,
#'   `n` (Anzahl Datensaetze), `wins_x`/`wins_y`/`ties`.
paired_wilcoxon_report <- function(x, y, higher_better = TRUE) {
  stopifnot(length(x) == length(y), length(x) >= 2)
  diff <- if (higher_better) x - y else y - x
  test <- suppressWarnings(stats::wilcox.test(x, y, paired = TRUE, exact = FALSE))
  list(
    median_diff = stats::median(diff), statistic = unname(test$statistic),
    p_value = test$p.value, n = length(x),
    wins_x = sum(diff > 0), wins_y = sum(diff < 0), ties = sum(diff == 0)
  )
}

#' Friedman-Omnibus-Test + Nemenyi-Post-hoc fuer >=3 Methoden ueber n
#' Datensaetze - Demsar (2006) Abschnitt 3.2/3.3.
#'
#' @param score_matrix Matrix/data.frame, Zeilen = Datensaetze, Spalten =
#'   Methoden (Spaltennamen = Methodennamen), ein Score je Zelle.
#' @param higher_better TRUE, wenn ein hoeherer Score besser ist (Default).
#' @param alpha Signifikanzniveau fuer die Nemenyi-kritische-Differenz -
#'   NUR 0.05 unterstuetzt (Demsar-2006-Tabelle), andere Werte -> Fehler.
#' @return Liste: `mean_rank` (benannter Vektor, 1 = beste Methode),
#'   `friedman_statistic`, `friedman_df`, `friedman_p_value`,
#'   `critical_difference`, `significant_pairs` (data.table: method_a,
#'   method_b, rank_diff, significant [|rank_diff| > CD]).
friedman_nemenyi_report <- function(score_matrix, higher_better = TRUE, alpha = 0.05) {
  m <- as.matrix(score_matrix)
  n <- nrow(m); k <- ncol(m)
  stopifnot(k >= 3, n >= 2, !is.null(colnames(m)))
  if (alpha != 0.05) stop("friedman_nemenyi_report(): nur alpha=0.05 unterstuetzt (Demsar-2006-Tabelle).")
  if (as.character(k) %in% names(.nemenyi_q_alpha_05) == FALSE) {
    stop(sprintf("friedman_nemenyi_report(): keine Nemenyi-q_alpha-Tabelle fuer k=%d Methoden (unterstuetzt: 2-10).", k))
  }

  rank_m <- if (higher_better) t(apply(-m, 1, rank)) else t(apply(m, 1, rank))
  mean_rank <- setNames(colMeans(rank_m), colnames(m))

  friedman <- stats::friedman.test(m)

  q_alpha <- .nemenyi_q_alpha_05[[as.character(k)]]
  cd <- q_alpha * sqrt(k * (k + 1) / (6 * n))

  pairs <- utils::combn(colnames(m), 2, simplify = FALSE)
  significant_pairs <- data.table::rbindlist(lapply(pairs, function(p) {
    rank_diff <- mean_rank[[p[1]]] - mean_rank[[p[2]]]
    data.table::data.table(method_a = p[1], method_b = p[2],
                            rank_diff = rank_diff, significant = abs(rank_diff) > cd)
  }))

  list(mean_rank = mean_rank, friedman_statistic = unname(friedman$statistic),
       friedman_df = unname(friedman$parameter), friedman_p_value = friedman$p.value,
       critical_difference = cd, significant_pairs = significant_pairs)
}

#' Einstiegspunkt: waehlt automatisch gepaarten Wilcoxon (k=2) oder
#' Friedman+Nemenyi (k>=3) je nach Spaltenzahl von `score_matrix`.
#'
#' @param score_matrix Matrix/data.frame, Zeilen = Datensaetze, Spalten =
#'   Methoden (benannt), ein Score je Zelle (z.B. mittlerer CV-Score je
#'   Datensatz/Methode - NICHT einzelne Fold-Werte, siehe
#'   `bootstrap_metric_ci.R`/`bootstrap_paired_comparison()` dafuer).
#' @param higher_better,alpha Wie bei den Einzelfunktionen.
#' @return Liste mit `method` ("wilcoxon" oder "friedman_nemenyi") plus den
#'   Feldern der jeweiligen Einzelfunktion, sowie stets `mean_rank`.
benchmark_statistics_report <- function(score_matrix, higher_better = TRUE, alpha = 0.05) {
  m <- as.matrix(score_matrix)
  k <- ncol(m)
  stopifnot(k >= 2, !is.null(colnames(m)))

  if (k == 2) {
    wilcoxon <- paired_wilcoxon_report(m[, 1], m[, 2], higher_better = higher_better)
    rank_m <- if (higher_better) t(apply(-m, 1, rank)) else t(apply(m, 1, rank))
    mean_rank <- setNames(colMeans(rank_m), colnames(m))
    c(list(method = "wilcoxon", mean_rank = mean_rank), wilcoxon)
  } else {
    c(list(method = "friedman_nemenyi"),
      friedman_nemenyi_report(m, higher_better = higher_better, alpha = alpha))
  }
}
