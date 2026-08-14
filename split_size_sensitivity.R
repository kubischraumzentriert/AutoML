# =============================================================================
# split_size_sensitivity.R -- Split-Size-Sensitivity-Analyse (Brownlee
# "Data Science Diagnostic Checklist", Abschnitt 3): prueft, ob der GEWAEHLTE
# Train/Test-Split-Anteil selbst stabil ist, BEVOR man mit dem Modellieren
# anfaengt bzw. bevor man einer einzelnen Holdout-Bewertung vertraut.
# =============================================================================
# Mechanismus: rsmp("subsampling", repeats, ratio) wiederholt den Split R-mal
# mit unterschiedlichem Zufalls-Seed bei FESTEM ratio - die SD der daraus
# resultierenden Performance-Scores zeigt, wie sehr "welche 20% man zufaellig
# zieht" das Ergebnis beeinflusst. Zwei gegenlaeufige Effekte ueber
# steigendes ratio (= Trainingsanteil): das TRAININGSSET wird groesser/
# stabiler (SD sollte sinken), aber das TESTSET wird kleiner (SD der
# Score-SCHAETZUNG sollte steigen) - das Optimum liegt i.d.R. in der Mitte,
# nicht am Rand. Ergaenzt (nicht ersetzt) target_leak_audit.R/
# univariate_drift.R: dort geht es um Verzerrung/Drift EINES Splits, hier um
# STABILITAET ueber viele moegliche Splits desselben Anteils.
#
# Wie reagieren, wenn "AUFFAELLIG" gemeldet wird (report_split_ratio_
# sensitivity()) - drei Ebenen, von taktisch zu strukturell:
#   1. Sofort umsetzbar: die Ergebnistabelle nennt direkt den ratio mit der
#      niedrigsten CV - diesen statt des bisherigen validation_ratio
#      verwenden (billiger Tausch, keine weitere Analyse noetig).
#   2. Strukturell wichtiger: eine auffaellige Meldung heisst "eine EINZELNE
#      Holdout-Bewertung bei diesem Datensatz/ratio ist nicht vertrauens-
#      wuerdig" - jede Projektentscheidung, die bisher auf einer einzelnen
#      Holdout-Zahl beruht (z.B. 030_baseline.R, ein Threshold-Tuning-
#      Split), sollte auf CV-/Repeated-CV-basierte Bewertung umgestellt
#      oder mit mehr Wiederholungen/Folds abgesichert werden.
#   3. Kommunikationspflicht: jedes berichtete Ergebnis dieses Projekts
#      (auch Richtung Kaggle-Write-up) sollte als Mittelwert +/- Streuung
#      kommuniziert werden, nicht als einzelne Punktschaetzung - dieselbe
#      Logik wie bei generalization_gap.R.
#   4. Falls die CV selbst beim BESTEN getesteten ratio noch hoch ist: keine
#      Split-Wahl behebt das, nur mehr Daten (meist nicht kurzfristig
#      umsetzbar) - wichtig zu wissen, bevor man Modellvergleichen an
#      diesem Projekt zu viel Gewicht gibt.
#
# Kosten/Nutzen laufen GEGENLAEUFIG zur Datensatzgroesse (siehe TARGETS.md,
# 2026-08-13-Korrektur): bei einem grossen Datensatz ist der Check teuer UND
# am wenigsten noetig, bei einem kleinen Datensatz billig UND am
# nuetzlichsten. Deshalb 022_split_size_sensitivity.R: classif.rpart als
# Default-Lerner (Mechanismus ist weitgehend lernverfahren-unabhaengig -
# per Spot-Check bestaetigt, siehe TARGETS.md) + split_sensitivity_max_n,
# das den Check bei grossen Datensaetzen ganz ueberspringt.

#' @param task mlr3 TaskClassif/TaskRegr
#' @param learner mlr3 Learner (wird pro Split neu gefittet)
#' @param measure mlr3 Measure (z.B. msr("classif.bacc"))
#' @param ratios numerischer Vektor der zu testenden Trainingsanteile
#' @param repeats Wiederholungen je ratio (Checkliste: 5-10, hier Default 20
#'   fuer eine stabilere SD-Schaetzung)
#' @return data.table: ratio, n_train, n_test, mean, sd, cv (=sd/|mean|)
split_ratio_sensitivity <- function(task, learner, measure, ratios, repeats = 20, seed = 42) {
  n <- task$nrow
  out <- lapply(ratios, function(r) {
    set.seed(seed)
    resampling <- rsmp("subsampling", repeats = repeats, ratio = r)
    rr <- mlr3::resample(task, learner$clone(deep = TRUE), resampling)
    scores <- rr$score(measure)[[measure$id]]
    data.table::data.table(
      ratio = r, n_train = round(r * n), n_test = n - round(r * n),
      mean = mean(scores), sd = sd(scores), cv = sd(scores) / abs(mean(scores))
    )
  })
  data.table::rbindlist(out)
}

#' Konsolen-Zusammenfassung + Speichern. Warnt, wenn die CV (Variationskoeffizient)
#' beim GEWAEHLTEN ratio deutlich hoeher liegt als das Minimum ueber alle
#' getesteten ratios (zeigt, ob eine andere Split-Groesse deutlich stabiler
#' waere). BEWUSST kein absoluter CV-Schwellenwert: die "normale" CV-
#' Groessenordnung haengt stark von Metrik/Task/Datensatzgroesse ab (siehe
#' Verifikation - selbst das BESTE getestete ratio kann absolut betrachtet
#' eine hohe CV haben). Der relative Faktor ggue. dem Minimum ist
#' selbst-kalibrierend, analog zum z-Score-Referenzbereich in
#' generalization_gap.R - dieselbe Lehre ein zweites Mal bestaetigt.
#' @param chosen_ratio der im Projekt tatsaechlich verwendete Split-Anteil
#'   (z.B. validation_ratio aus 000_config.R)
report_split_ratio_sensitivity <- function(sens, chosen_ratio, out_path = NULL,
                                            cv_warn_relative = 2) {
  data.table::setorder(sens, ratio)
  cat("\n=== Split-Size-Sensitivity-Analyse ===\n")
  print(sens)

  chosen_row <- sens[ratio == chosen_ratio]
  if (nrow(chosen_row) == 0) {
    cat("HINWEIS: chosen_ratio (", chosen_ratio, ") nicht in den getesteten ratios enthalten.\n", sep = "")
  } else {
    min_cv <- min(sens$cv)
    relative <- chosen_row$cv[1] / min_cv
    cat(sprintf(
      "\nGewaehltes ratio=%.2f: CV=%.4f (Minimum ueber alle ratios: %.4f, Faktor %.2fx)\n",
      chosen_ratio, chosen_row$cv[1], min_cv, relative
    ))
    flagged <- relative > cv_warn_relative
    if (flagged) {
      cat("=> AUFFAELLIG: gewaehlter Split-Anteil zeigt deutlich hoehere Score-Streuung\n",
          "   als andere getestete Anteile - eine einzelne Holdout-Bewertung bei diesem\n",
          "   ratio ist wenig verlaesslich. Reaktion: siehe Kopfkommentar dieser Datei\n",
          "   ('Wie reagieren, wenn AUFFAELLIG gemeldet wird') - kurz: anderen ratio\n",
          "   waehlen UND/ODER auf CV-basierte Bewertung umstellen statt einer\n",
          "   einzelnen Holdout-Zahl zu vertrauen.\n", sep = "")
    } else {
      cat("=> unauffaellig: Streuung beim gewaehlten Anteil liegt im normalen Bereich.\n")
    }
  }

  if (!is.null(out_path)) {
    data.table::fwrite(sens, out_path)
    cat("Gespeichert:", out_path, "\n")
  }
  invisible(sens)
}
