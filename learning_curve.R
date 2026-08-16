# =============================================================================
# learning_curve.R -- Lernkurve (Brownlee "Data Science Diagnostic
# Checklist", Abschnitt 11 "Learning Curve Tests"): prueft, ob mehr
# Trainingsdaten den Score noch spuerbar verbessern wuerden, oder ob eine
# kleinere Stichprobe (z.B. subset_fraction in 000_config.R) bereits
# ausreicht.
# =============================================================================
# ANDERS als split_size_sensitivity.R (dort war der Mechanismus weitgehend
# lernverfahren-unabhaengig, rpart als billiger Stellvertreter genuegte):
# hier haengt das Ergebnis direkt von der KAPAZITAET des Algorithmus ab - ein
# einzelner Baum (rpart) plateaut typischerweise frueh, ein Ensemble
# (Ranger)/Boosting (LightGBM) kann bei denselben Daten noch deutlich
# steigen. Ein billiger Stellvertreter waere hier eine FALSCHE Sicherheit -
# das Modul muss mit dem tatsaechlich eingesetzten Algorithmus laufen.
#
# Fuer jede Trainingsgroesse (stratifizierte Teilstichprobe): Validierungs-
# score per EINMALIGER k-facher CV (kein Repeat - wir wollen den TREND,
# nicht die Streuung, dafuer gibt es split_size_sensitivity.R) + Trainings-
# score (Fit auf der Teilstichprobe, Vorhersage auf denselben Zeilen).

#' @param task mlr3 TaskClassif/TaskRegr
#' @param learner mlr3 Learner (wird pro Groesse neu gefittet)
#' @param measure mlr3 Measure (z.B. msr("classif.bacc"))
#' @param fractions numerischer Vektor der zu testenden Trainingsgroessen-Anteile
#' @param cv_folds Folds fuer den Validierungsscore je Groesse (Default 5)
#' @param repeats Wiederholungen je fraction (verschiedene Teilstichproben +
#'   CV-Aufteilungen, gemittelt) - EIN einzelner Lauf je Groesse war in der
#'   Verifikation zu verrauscht, um den Trend (steigend vs. Plateau)
#'   verlaesslich von Stichproben-/Fold-Rauschen zu unterscheiden (Faktor
#'   ~5 Wiederholungen glaettet das ausreichend, siehe TARGETS.md)
#' @return data.table: fraction, n, train_score, val_score (je Mittelwert
#'   ueber repeats)
learning_curve <- function(task, learner, measure, fractions, cv_folds = 5, repeats = 5, seed = 42) {
  target <- task$target_names[1]
  dt <- task$data()
  out <- lapply(fractions, function(frac) {
    rep_scores <- lapply(seq_len(repeats), function(r) {
      set.seed(seed * 1000L + r)
      idx <- unlist(lapply(split(seq_len(nrow(dt)), dt[[target]]), function(ix) {
        sample(ix, size = max(2, round(frac * length(ix))))
      }))
      sub_task <- task$clone(deep = TRUE)$filter(idx)

      resampling <- rsmp("cv", folds = cv_folds)
      rr <- mlr3::resample(sub_task, learner$clone(deep = TRUE), resampling)
      val_score <- mean(rr$score(measure)[[measure$id]])

      fit <- learner$clone(deep = TRUE)
      fit$train(sub_task)
      pred <- fit$predict(sub_task)
      train_score <- pred$score(measure)[[measure$id]]

      c(n = length(idx), train_score = train_score, val_score = val_score)
    })
    rep_mat <- do.call(rbind, rep_scores)
    data.table::data.table(fraction = frac, n = round(mean(rep_mat[, "n"])),
                            train_score = mean(rep_mat[, "train_score"]),
                            val_score = mean(rep_mat[, "val_score"]))
  })
  data.table::rbindlist(out)
}

#' Konsolen-Zusammenfassung + Speichern. "Noch steigend" wird per Regression
#' UEBER ALLE Punkte bestimmt (lm(val_score ~ log(n))), NICHT per Differenz
#' zweier Randpunkte - ein erster Entwurf mit "letzter vs. erster Zuwachs"
#' war in der Verifikation zu instabil: bei einer bereits fast durchgehend
#' flachen Kurve (frueh saettigend) sind beide Einzel-Zuwaechse selbst schon
#' nahe Null, ihr Verhaeltnis wird dann von Rauschen dominiert statt vom
#' echten Trend. Die Regressions-Steigung nutzt alle Punkte und ist deutlich
#' robuster (siehe TARGETS.md fuer die Verifikationszahlen).
#'
#' SELBST-KALIBRIEREND (4. Bestaetigung derselben Lehre wie in
#' split_size_sensitivity.R/generalization_gap.R): die vorhergesagte
#' Verbesserung durch eine Verdopplung von n wird relativ zur beobachteten
#' Score-STREUUNG bewertet, nicht gegen einen absoluten Score-Schwellenwert
#' - die "normale" Score-Skala haengt stark von Metrik/Task ab.
#'
#' IQR statt max-min als Nenner (2026-08-15, Korrektur nach einem echten
#' Fund): die urspruengliche volle Spannweite (max-min ueber ALLE fractions)
#' ist anfaellig fuer einen einzelnen verrauschten Ausreisser bei winzigen
#' Fraktionen (z.B. openml-credit-g: ein Einbruch bei n=20 dominierte die
#' Spannweite und liess einen tatsaechlich noch klar steigenden Trend
#' faelschlich als "PLATEAU" erscheinen - mit repeats=5 gemittelt, aber bei
#' n=20/5-fach-CV bleiben nur ~4 Zeilen je Fold, selbst gemittelt instabil).
#' IQR (Q3-Q1) ignoriert die extremsten 25% auf jeder Seite und ist damit
#' robust gegen genau diesen Fall, siehe TARGETS.md fuer die Herleitung.
#' @param out_path optional CSV-Speicherpfad
#' @param plateau_relative Anteil der Gesamtspannweite, den eine Verdopplung
#'   von n mindestens noch bringen muesste, um als "noch steigend" zu gelten
report_learning_curve <- function(lc, out_path = NULL, plateau_relative = 0.10) {
  data.table::setorder(lc, fraction)
  cat("\n=== Lernkurve ===\n")
  print(lc)

  n_pts <- nrow(lc)
  gap <- lc$train_score[n_pts] - lc$val_score[n_pts]
  cat(sprintf("\nTrain-Validation-Luecke bei %.0f%%: %.4f\n", lc$fraction[n_pts] * 100, gap))

  if (n_pts < 3) {
    cat("HINWEIS: mindestens 3 fractions noetig fuer eine Trend-Einordnung.\n")
  } else {
    fit <- lm(val_score ~ log(n), data = lc)
    slope <- unname(coef(fit)["log(n)"])
    gain_per_doubling <- slope * log(2)
    total_range <- max(lc$val_score) - min(lc$val_score)
    iqr_range <- stats::IQR(lc$val_score)
    relative <- if (iqr_range == 0) NA_real_ else gain_per_doubling / iqr_range

    cat(sprintf(
      "Regressions-Steigung (val_score ~ log(n)): %.5f  Erwarteter Zuwachs bei\n",
      slope
    ))
    cat(sprintf(
      "Verdopplung von n: %.4f (%s des IQR %.4f; volle Spannweite zum Vergleich: %.4f)\n",
      gain_per_doubling, if (is.na(relative)) "n/a" else sprintf("%.1f%%", relative * 100), iqr_range, total_range
    ))
    still_climbing <- is.na(relative) || relative > plateau_relative
    if (still_climbing) {
      cat("=> NOCH STEIGEND: eine Verdopplung von n wuerde noch einen relevanten\n",
          "   Anteil der bisher beobachteten Score-Spannweite bringen - mehr\n",
          "   Trainingsdaten wuerden den Score vermutlich noch spuerbar verbessern.\n",
          "   Modellvergleiche auf einem kleineren Subset koennen das Ranking\n",
          "   gegenueber dem vollen Datensatz verzerren.\n", sep = "")
    } else {
      cat("=> PLATEAU: eine Verdopplung von n wuerde kaum noch etwas bringen -\n",
          "   die getestete Trainingsgroesse ist fuer diesen Algorithmus ausreichend.\n", sep = "")
    }
  }

  if (!is.null(out_path)) {
    data.table::fwrite(lc, out_path)
    cat("Gespeichert:", out_path, "\n")
  }
  invisible(lc)
}
