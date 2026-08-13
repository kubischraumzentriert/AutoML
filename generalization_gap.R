# =============================================================================
# generalization_gap.R -- formale Quantifizierung/Herausforderung der
# Generalisierungsluecke (CV-/Train-Score vs. Score auf unberuehrten Daten).
# =============================================================================
# Herkunft: Jason Brownlee, "Data Science Diagnostic Checklist", Abschnitte
# 5 ("Quantify the Performance Gap") und 6 ("Challenge the Performance Gap").
# Formalisiert, was bisher ad-hoc als "CV<->LB-Luecke gross/klein?" beurteilt
# wurde (siehe s6e6/s6e8-Notizen in REFERENZ_ENSEMBLE_SELECTION.md): statt
# eines Bauchgefuehls ein statistischer Test (Mann-Whitney U, robust bei
# kleinem n/keiner Normalitaetsannahme - Alternative zum t-Test, siehe
# Checkliste) + Effektgroesse (Cohen's d) + ein Referenzbereich aus mehreren
# UNGETUNTEN Baseline-Algorithmen (deren eigene Luecke zeigt, was "normal"
# ist, bevor man das Kandidatenmodell als auffaellig einstuft).
#
# Getrennt von target_leak_audit.R: das dort gepruefte "Leakage" ist
# Feature-Target-Leakage (verraet ein FEATURE das Ziel selbst); hier geht es
# um Train/Test-Grenz-Optimismus (z.B. Hyperparameter-Auswahl, die zufaellig
# gut zu genau diesen CV-Folds passt, aber nicht zu frischen Daten
# generalisiert - der klassische "Winner's-Curse"-Effekt einer Suche ueber
# viele Konfigurationen).

#' Bootstrap-Verteilung eines Scores auf (idealerweise unberuehrten) Zeilen.
#' @param truth,response Vektoren gleicher Laenge (Wahrheit/Vorhersage)
#' @param measure_fn function(truth, response) -> Skalar (z.B. Accuracy/BAcc)
#' @param n_boot Anzahl Bootstrap-Resamples (Checkliste: 30-1000)
#' @return numerischer Vektor der Laenge n_boot
bootstrap_score_distribution <- function(truth, response, measure_fn, n_boot = 200, seed = NULL) {
  stopifnot(length(truth) == length(response))
  if (!is.null(seed)) set.seed(seed)
  n <- length(truth)
  vapply(seq_len(n_boot), function(i) {
    idx <- sample.int(n, n, replace = TRUE)
    measure_fn(truth[idx], response[idx])
  }, numeric(1))
}

#' Cohen's d (gepoolte SD) zwischen zwei Score-Verteilungen.
cohens_d <- function(a, b) {
  na <- length(a); nb <- length(b)
  pooled_sd <- sqrt(((na - 1) * var(a) + (nb - 1) * var(b)) / (na + nb - 2))
  if (pooled_sd == 0) return(NA_real_)
  (mean(b) - mean(a)) / pooled_sd
}

#' Statistischer Vergleich zweier Score-Verteilungen (z.B. CV-Fold-Scores vs.
#' Bootstrap-Scores auf unberuehrten Daten). Mann-Whitney U statt t-Test als
#' Default (robuster bei kleinem n/Nicht-Normalitaet, siehe Checkliste
#' Abschnitt 6) + Kolmogorov-Smirnov auf Verteilungsform + Cohen's d.
#' @return 1-Zeilen-data.table
compare_score_distributions <- function(scores_a, scores_b, name_a = "cv", name_b = "test") {
  wt <- suppressWarnings(wilcox.test(scores_b, scores_a))
  kst <- suppressWarnings(ks.test(scores_b, scores_a))
  d <- cohens_d(scores_a, scores_b)
  data.table::data.table(
    name_a = name_a, name_b = name_b,
    mean_a = mean(scores_a), mean_b = mean(scores_b),
    gap = mean(scores_b) - mean(scores_a),
    wilcox_p = wt$p.value, ks_p = kst$p.value, cohens_d = d
  )
}

#' Referenzbereich der Luecke aus mehreren UNGETUNTEN/nicht-selektierten
#' Baseline-Algorithmen: zeigt, wie gross eine Luecke "normalerweise" ist,
#' ohne dass ueberhaupt eine Auswahl/Suche stattgefunden hat.
#' @param cv_scores_list,test_scores_list benannte Listen (ein Eintrag je
#'   Algorithmus), Namen muessen uebereinstimmen.
#' @return data.table mit einer Zeile je Algorithmus (Spalte "gap")
reference_gap_distribution <- function(cv_scores_list, test_scores_list) {
  stopifnot(identical(names(cv_scores_list), names(test_scores_list)))
  algos <- names(cv_scores_list)
  data.table::rbindlist(lapply(algos, function(a) {
    data.table::data.table(
      algorithm = a,
      cv_mean = mean(cv_scores_list[[a]]),
      test_mean = mean(test_scores_list[[a]]),
      gap = mean(test_scores_list[[a]]) - mean(cv_scores_list[[a]])
    )
  }))
}

#' Gesamtbefund fuer EIN Kandidatenmodell: eigene Luecke + statistischer
#' Test + Einordnung gegen den Referenzbereich (z-Score bzgl. Referenz-
#' Luecken-Verteilung; |z| > 2 => auffaellig, siehe Kommentar unten).
#' @param higher_is_better TRUE fuer BAcc/MCC/AUC, FALSE fuer RMSE/Deviance
generalization_gap_report <- function(candidate_name, candidate_cv_scores, candidate_test_scores,
                                       reference_gaps, higher_is_better = TRUE) {
  cmp <- compare_score_distributions(candidate_cv_scores, candidate_test_scores,
                                      name_a = "cv", name_b = "test")
  candidate_gap <- cmp$gap
  ref_gap <- if (higher_is_better) reference_gaps$gap else -reference_gaps$gap
  cand_gap_oriented <- if (higher_is_better) candidate_gap else -candidate_gap
  ref_mean <- mean(ref_gap); ref_sd <- sd(ref_gap)
  z <- if (ref_sd == 0) NA_real_ else (cand_gap_oriented - ref_mean) / ref_sd
  # "auffaellig" = die Luecke ist optimistischer als beim Referenzbereich
  # (z < -2). BEWUSST NICHT zusaetzlich an wilcox_p < 0.05 gekoppelt: der
  # paarweise Test zwischen CV-Fold-Scores (typischerweise n=5) und
  # Bootstrap-Test-Scores (n=200+) vergleicht zwei verschiedene Rausch-
  # quellen (Fold-zu-Fold-Variabilitaet vs. Resampling-Unsicherheit EINES
  # fixen Modells) und ist dadurch strukturell schwach gepowert (siehe
  # Verifikation: Winner's-Curse-Szenario zeigte z=-3.1, aber wilcox_p=0.62).
  # Der z-Score gegen den Referenzbereich ist selbst-kalibrierend (dieselbe
  # Prozedur, dieselbe Verzerrung faellt auf beiden Seiten gleich aus) und
  # damit das robustere Kriterium - wilcox/KS/Cohen's d bleiben als
  # Zusatzdiagnose, nicht als Gate.
  flagged <- !is.na(z) && z < -2

  cat(sprintf("\n=== Generalisierungsluecke: %s ===\n", candidate_name))
  cat(sprintf("CV-Mittel=%.4f  Test-Mittel=%.4f  Luecke(test-cv)=%.4f\n",
              cmp$mean_a, cmp$mean_b, candidate_gap))
  cat(sprintf("Mann-Whitney-U p=%.4f  KS p=%.4f  Cohen's d=%.3f\n",
              cmp$wilcox_p, cmp$ks_p, cmp$cohens_d))
  cat(sprintf("Referenzbereich (n=%d ungetunte Algorithmen): Luecke Mittel=%.4f SD=%.4f\n",
              nrow(reference_gaps), ref_mean, ref_sd))
  cat(sprintf("z-Score der Kandidaten-Luecke ggue. Referenz: %s\n",
              if (is.na(z)) "n/a" else sprintf("%.2f", z)))
  cat(if (flagged) "=> AUFFAELLIG: Luecke deutlich groesser als bei ungetunten Baselines (moeglicher Test-Harness-Optimismus).\n"
      else "=> unauffaellig: Luecke im/nahe des Referenzbereichs.\n")

  data.table::data.table(candidate = candidate_name, cv_mean = cmp$mean_a, test_mean = cmp$mean_b,
                          gap = candidate_gap, wilcox_p = cmp$wilcox_p, cohens_d = cmp$cohens_d,
                          z_vs_reference = z, flagged = flagged)
}
