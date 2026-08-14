# =============================================================================
# seed_stability.R -- Seed-/Hyperparameter-Rausch-Stabilitaet (Brownlee
# "Data Science Diagnostic Checklist", Abschnitt 14): prueft, wie sehr der
# Score AUF DENSELBEN DATEN (fixer Train/Test-Split) allein durch den
# Zufalls-Seed des Lerners bzw. durch leichtes Jitter auf den gewaehlten
# Hyperparametern schwankt.
# =============================================================================
# Ergaenzt sanity_checks.R (dort: Robustheit gegen Feature-Rauschen/
# Invarianz - eine EIGENSCHAFT DER DATEN wird gestoert) und
# split_size_sensitivity.R (dort: Streuung durch WELCHE Zeilen im Split
# landen - Daten-Sampling-Rauschen). Hier: Streuung durch das MODELL selbst
# bei UNVERAENDERTEN Daten - ein anderer Rauschkanal.
#
# Referenzpunkt ist die normale CV-Fold-zu-Fold-Streuung (dieselbe
# Selbst-Kalibrierungs-Idee wie in den drei vorherigen Modulen, jetzt 5.
# Bestaetigung): CV-Fold-Streuung mischt ohnehin schon Daten- UND
# Modell-Rauschen. Ist die REINE Seed-/Jitter-Streuung (Daten fix) im
# Vergleich dazu gross, treibt das Modell selbst einen erheblichen Teil der
# ueblichen CV-Unsicherheit - relevant z.B. fuer die Frage "mehr Baeume vs.
# mehr CV-Folds", oder wie sehr man den GEFUNDENEN Hyperparametern
# vertrauen sollte (090/100).

#' Score-Verteilung bei FESTEM Train/Test-Split, NUR der Lerner-Seed
#' variiert.
#' @param learner_constructor function(seed) -> mlr3 Learner
#' @return numerischer Vektor der Laenge n_seeds
seed_stability <- function(task_train, task_test, learner_constructor, measure, n_seeds = 10, seed = 42) {
  set.seed(seed)
  seeds <- sample.int(1e6, n_seeds)
  vapply(seeds, function(s) {
    fit <- learner_constructor(s)
    fit$train(task_train)
    pred <- fit$predict(task_test)
    pred$score(measure)[[measure$id]]
  }, numeric(1))
}

#' Score-Verteilung bei FESTEM Train/Test-Split, Hyperparameter werden um
#' base_params herum leicht gejittert (Daten UND Lerner-Seed bleiben fix).
#' @param base_params benannte Liste der Ausgangs-Hyperparameter
#' @param jitter_fns benannte Liste function(value) -> gejitterter Wert, ein
#'   Eintrag je Parameter in base_params (fehlende Parameter bleiben fix)
#' @param learner_ctor function(params_list) -> mlr3 Learner
#' @return list(scores=numerischer Vektor, params=data.table der gezogenen Werte)
hyperparam_jitter_stability <- function(task_train, task_test, base_params, jitter_fns,
                                         learner_ctor, measure, n_jitter = 10, seed = 42) {
  set.seed(seed)
  draws <- lapply(seq_len(n_jitter), function(i) {
    p <- base_params
    for (nm in names(jitter_fns)) p[[nm]] <- jitter_fns[[nm]](base_params[[nm]])
    p
  })
  scores <- vapply(draws, function(p) {
    fit <- learner_ctor(p)
    fit$train(task_train)
    pred <- fit$predict(task_test)
    pred$score(measure)[[measure$id]]
  }, numeric(1))
  list(scores = scores, params = data.table::rbindlist(lapply(draws, as.data.table)))
}

#' Konsolen-Zusammenfassung: vergleicht seed_scores/jitter_scores (Streuung
#' bei fixen Daten) gegen die normale CV-Fold-Streuung (mischt Daten- UND
#' Modellrauschen) als Referenz. Faktor > cv_warn_relative => Modell-eigene
#' Streuung treibt einen ueberproportionalen Teil der ueblichen Unsicherheit.
#' @param cv_scores Vektor der CV-Fold-Scores (Referenz, z.B. aus rr$score())
#' cv_warn_relative=0.5 (statt z.B. 1.0/Paritaet): CV-Fold-Streuung mischt
#' Daten- UND Modellrauschen, reine Seed-/Jitter-Streuung (Daten fix) bleibt
#' deshalb strukturell meist UNTER der CV-Streuung, auch bei einem stark
#' instabilen Modell (synthetisch: 1 Baum 0.61x vs. 300 Baeume 0.14x - siehe
#' TARGETS.md). Paritaet (1.0x) als Schwelle haette selbst den Extremfall
#' (1 Baum) nicht geflaggt.
report_stability <- function(label, scores, cv_scores, out_path = NULL, cv_warn_relative = 0.5) {
  sd_own <- sd(scores)
  sd_cv <- sd(cv_scores)
  relative <- if (sd_cv == 0) NA_real_ else sd_own / sd_cv
  cat(sprintf("\n=== %s ===\n", label))
  cat(sprintf("Scores: %s\n", paste(round(scores, 4), collapse = ", ")))
  cat(sprintf("SD (fixe Daten, nur %s variiert): %.5f\n", label, sd_own))
  cat(sprintf("SD (normale CV-Fold-Streuung, Referenz): %.5f\n", sd_cv))
  cat(sprintf("Verhaeltnis: %s\n", if (is.na(relative)) "n/a" else sprintf("%.2fx", relative)))
  flagged <- !is.na(relative) && relative > cv_warn_relative
  if (flagged) {
    cat(sprintf("=> AUFFAELLIG: Streuung durch \"%s\" allein ist so gross wie oder groesser\n", label),
        "   als die normale CV-Fold-Streuung - ein erheblicher Teil der ueblichen Unsicherheit\n",
        "   kommt vom Modell selbst, nicht von den Daten. Reaktion: mehr Baeume/Iterationen\n",
        "   (Modell-Varianz senken) und/oder ueber mehrere Seeds mitteln (Ensemble Selection\n",
        "   nutzt das bereits), statt einer einzelnen Zahl zu vertrauen.\n", sep = "")
  } else {
    cat(sprintf("=> unauffaellig: Streuung durch \"%s\" ist klein im Vergleich zur normalen CV-Streuung.\n", label))
  }
  res <- data.table::data.table(check = label, sd_own = sd_own, sd_cv_reference = sd_cv,
                                 relative = relative, flagged = flagged)
  if (!is.null(out_path)) {
    data.table::fwrite(res, out_path, append = file.exists(out_path))
  }
  invisible(res)
}
