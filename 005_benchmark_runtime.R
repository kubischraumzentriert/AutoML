suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
})

# Warnt (statt spaeter mit einem kryptischen lda.default-Fehler abzubrechen),
# wenn ein Faktor-Feature so hochkardinal ist, dass eine One-Hot-Kodierung
# (implizit bei classif.lda/classif.multinom) zu Spalten fuehrt, die
# innerhalb einer Zielklasse konstant sind. Aufgetreten bei einer
# Uebertragung dieses Templates auf ein Projekt mit einer 887-Level-Spalte
# (siehe TEMPLATE_FRICTION.md des jeweiligen Projekts) - das gesunde
# Gesundheitsdaten-Set hier hat keine derart hochkardinalen Spalten, daher
# rueckwirkungsfrei, aber als Absicherung fuer kuenftige Uebertragungen
# nuetzlich. threshold ist eine Faustregel, keine harte Grenze.
warn_high_cardinality_factors <- function(task, threshold = 50) {
  feature_types <- task$feature_types
  factor_cols <- feature_types[type %in% c("factor", "ordered"), id]
  if (length(factor_cols) == 0) {
    return(invisible(NULL))
  }

  data <- task$data(cols = factor_cols)
  cardinalities <- vapply(data, function(x) length(unique(x)), integer(1))
  high_card <- cardinalities[cardinalities > threshold]

  if (length(high_card) > 0) {
    warning(
      "Hochkardinale Faktor-Spalte(n) gefunden (> ", threshold, " Auspraegungen): ",
      paste(names(high_card), "=", high_card, collapse = ", "),
      " - LDA/Multinom kodieren Faktoren implizit als One-Hot und koennen bei ",
      "so vielen Auspraegungen abstuerzen (Spalten konstant innerhalb einer ",
      "Klasse). Erwaegen, die Spalte(n) fuer diese Modelle auszuschliessen ",
      "oder sinnvoll zu kodieren (Frequenz-/Zielkodierung), bevor 030/037/",
      "080 laufen.",
      call. = FALSE
    )
  }

  invisible(high_card)
}

# Ergaenzt warn_high_cardinality_factors(): die rohe Levelzahl (> threshold)
# ist nur ein Proxy fuer die eigentliche Absturzursache, kein zuverlaessiger
# Indikator - siehe openml-adult-income/TEMPLATE_FRICTION.md #1. Dort
# stuerzte LDA/Multinom sowohl an native.country (41 Level, UNTER der
# 50er-Schwelle) als auch an niedrig-kardinalen Spalten (occupation: 14,
# workclass: 8, marital.status: 7 Level) mit einzelnen seltenen Leveln ab -
# die eigentliche Ursache ist ein Level, das (durch Zufall oder echte
# Seltenheit) in mindestens einer Zielklasse gar nicht vorkommt, unabhaengig
# von der Gesamt-Levelzahl der Spalte. Diese Funktion prueft das direkt per
# Kreuztabelle, statt nur die Levelzahl zu zaehlen.
warn_rare_factor_levels <- function(task, min_count_per_class = 1) {
  feature_types <- task$feature_types
  factor_cols <- feature_types[type %in% c("factor", "ordered"), id]
  if (length(factor_cols) == 0) {
    return(invisible(NULL))
  }

  target_col_name <- task$target_names[1]
  data <- task$data(cols = c(factor_cols, target_col_name))
  target_values <- data[[target_col_name]]

  problems <- list()
  for (col in factor_cols) {
    tab <- table(data[[col]], target_values)
    zero_rows <- rownames(tab)[apply(tab, 1, function(r) any(r < min_count_per_class))]
    if (length(zero_rows) > 0) {
      problems[[col]] <- zero_rows
    }
  }

  if (length(problems) > 0) {
    details <- paste(
      vapply(names(problems), function(col) paste0(col, " (", paste(problems[[col]], collapse = ", "), ")"), character(1)),
      collapse = "; "
    )
    warning(
      "Faktor-Spalte(n) mit seltenen Leveln gefunden, die in mindestens einer ",
      "Zielklasse mit weniger als ", min_count_per_class, " Beobachtung(en) vorkommen: ",
      details, " - LDA/Multinom koennen daran abstuerzen (Dummy-Spalte konstant ",
      "innerhalb einer Klasse), UNABHAENGIG von der Gesamt-Levelzahl der Spalte ",
      "(siehe warn_high_cardinality_factors() - deren Schwelle allein reicht ",
      "nicht aus). Erwaegen: po('collapsefactors') vor dem Klassifikator ",
      "einfuegen, um seltene Level automatisch zusammenzufassen (siehe ",
      "openml-adult-income/030_baseline.R fuer ein Anwendungsbeispiel).",
      call. = FALSE
    )
  }

  invisible(problems)
}

# Prueft die ZIELSPALTE selbst (Ergaenzung zu warn_rare_factor_levels(),
# die nur FEATURE-Spalten prueft) auf NA, leere Faktorstufen ("") und
# extrem seltene Klassen, BEVOR ein mlr3-Task gebaut wird. Anlass: ein
# Fixture-Bug im CI-Smoke-Test erzeugte durch einen fwrite/fread-Rundweg
# eine einzelne Zeile mit leerem String "" im Ziel (aus einem
# urspruenglichen NA) - das liess classif.ranger mit einem kryptischen
# "Indizierung ausserhalb der Grenzen" abstuerzen. Bestaetigte Root
# Cause (siehe TARGETS.md, Eintrag "Ranger-Absturz bei leerer
# Zielklasse"): R's Matrix-Indizierung nach Spaltenname behandelt ""
# nie als echten Treffer, selbst wenn diese Spalte existiert -
# ranger::ranger()s eigene Nachbearbeitung "result$predictions[,
# levels(droplevels(y)), drop = FALSE]" (R/ranger.R) schlaegt daher
# IMMER fehl, sobald ein Zielwert exakt "" ist - unabhaengig von
# Seltenheit. Betrifft nicht nur synthetische Fixtures: echte
# Kaggle-CSVs koennen vereinzelte NA/leere Werte im Ziel haben, die ein
# naiver as.factor()-Cast genau in diese Falle laufen liesse.
check_target_column <- function(target_values, min_count_per_class = 2) {
  if (anyNA(target_values)) {
    stop(
      "Zielspalte enthaelt ", sum(is.na(target_values)), " NA-Wert(e). ",
      "Ein naiver as.factor()-Cast wuerde NA in eine eigene Faktorstufe ",
      "verwandeln, die spaeter classif.ranger mit einem kryptischen ",
      "Ranger-internen Fehler abstuerzen laesst (siehe TARGETS.md, ",
      "\"Ranger-Absturz bei leerer Zielklasse\"). Bitte vor dem Task-Bau ",
      "entscheiden: Zeilen entfernen oder NA bewusst als eigene Klasse ",
      "kodieren (z.B. \"unknown\").",
      call. = FALSE
    )
  }

  target_chr <- as.character(target_values)
  n_empty <- sum(!is.na(target_chr) & target_chr == "")
  if (n_empty > 0) {
    stop(
      "Zielspalte enthaelt ", n_empty, " leere(n) String-Wert(e) (''). ",
      "as.factor('') erzeugt eine Faktorstufe mit dem Namen '', die ",
      "classif.ranger IMMER zum Absturz bringt (bestaetigte Root Cause: ",
      "R's Matrix-Indizierung nach Spaltenname behandelt '' nie als ",
      "Treffer, selbst wenn diese Spalte existiert - ranger::ranger()s ",
      "eigene Nachbearbeitung 'result$predictions[, levels(droplevels(y)), ",
      "drop = FALSE]' schlaegt daher fehl, siehe TARGETS.md, \"Ranger-",
      "Absturz bei leerer Zielklasse\"). Typische Ursache: ein verstecktes ",
      "NA, das bei einem CSV-Rundweg (fwrite/fread) zu '' wurde. Bitte vor ",
      "dem Task-Bau bereinigen (leere Strings zu NA machen und behandeln, ",
      "oder Zeilen entfernen).",
      call. = FALSE
    )
  }

  tab <- table(target_values)
  rare <- tab[tab < min_count_per_class]
  if (length(rare) > 0) {
    warning(
      "Zielklasse(n) mit weniger als ", min_count_per_class, " ",
      "Beobachtung(en) gefunden: ",
      paste(names(rare), "=", rare, collapse = ", "), " - stratifizierte ",
      "CV/Holdout-Splits, Klassifikationsmasse (BAcc/MCC) und manche ",
      "Learner koennen bei derart duenn besetzten Klassen instabil werden. ",
      "Erwaegen: Zeilen entfernen oder Klasse mit einer anderen ",
      "zusammenfassen.",
      call. = FALSE
    )
  }

  invisible(NULL)
}

# Prueft, ob eine Korrekturregel "bei Uneinigkeit auf Modell B umschalten"
# (z.B. ein staerkeres Modell A durch ein schwaecheres, aber manchmal
# treffenderes Modell B ergaenzen) tatsaechlich sinnvoll waere. Die in der
# Fehleranalyse (147) berechnete Rescue-Rate - P(B richtig | A falsch) -
# reicht dafuer NICHT aus (siehe README, "Zweite methodische Falle"):
# relevant ist P(B richtig | A und B uneinig), eine andere bedingte
# Wahrscheinlichkeit. Ein insgesamt viel staerkeres Modell A hat oft auch bei
# den meisten Uneinigkeitsfaellen noch recht, selbst wenn B einen ueberdurch-
# schnittlichen Anteil von As SPEZIFISCHEN Fehlern trifft - eine "bei
# Uneinigkeit B glauben"-Regel kann dann per Saldo mehr schaden als nuetzen.
# response_a/response_b/truth: gleich lange Vektoren (z.B. aus $response auf
# demselben Eval-Split).
check_disagreement_accuracy <- function(response_a, response_b, truth, name_a = "A", name_b = "B") {
  disagree_idx <- which(response_a != response_b)
  if (length(disagree_idx) == 0) {
    cat("Keine Uneinigkeit zwischen", name_a, "und", name_b, "- keine Korrekturregel moeglich/noetig.\n")
    return(invisible(NULL))
  }

  acc_a <- mean(response_a[disagree_idx] == truth[disagree_idx])
  acc_b <- mean(response_b[disagree_idx] == truth[disagree_idx])
  neither <- mean(response_a[disagree_idx] != truth[disagree_idx] & response_b[disagree_idx] != truth[disagree_idx])

  cat(
    "=== Uneinigkeits-Genauigkeit: ", name_a, " vs. ", name_b, " (", length(disagree_idx),
    " von ", length(truth), " Zeilen uneinig, ", sprintf("%.1f%%", 100 * length(disagree_idx) / length(truth)), ") ===\n",
    sep = ""
  )
  cat(name_a, "hat recht:", sprintf("%.1f%%", 100 * acc_a), "\n")
  cat(name_b, "hat recht:", sprintf("%.1f%%", 100 * acc_b), "\n")
  cat("Keiner hat recht:", sprintf("%.1f%%", 100 * neither), "\n")

  if (acc_b > acc_a) {
    cat("-> Bei Uneinigkeit ist", name_b, "im Mittel vertrauenswuerdiger - eine Korrekturregel koennte sich lohnen (trotzdem per CV gegenpruefen).\n")
  } else {
    cat("-> Bei Uneinigkeit ist", name_a, "im Mittel vertrauenswuerdiger - eine 'bei Uneinigkeit auf", name_b, "umschalten'-Regel wuerde vermutlich schaden.\n")
  }

  invisible(list(acc_a = acc_a, acc_b = acc_b, neither = neither, n_disagree = length(disagree_idx)))
}

run_timed_benchmark <- function(tasks, learners, resampling, measures) {
  benchmark_results <- list()
  result_rows <- list()
  score_rows <- list()
  run_id <- 1L

  for (task in tasks) {
    task <- enable_class_stratification(task)
    task_resampling <- resampling$clone(deep = TRUE)
    task_resampling$instantiate(task)

    for (learner in learners) {
      design <- data.table(
        task = list(task),
        learner = list(learner),
        resampling = list(task_resampling$clone(deep = TRUE))
      )

      timing <- system.time({
        benchmark_result <- benchmark(design)
      })

      result <- benchmark_result$aggregate(measures = measures)
      result[, elapsed_seconds := as.numeric(timing[["elapsed"]])]

      # Werte pro einzelnem Resampling-Fold (nicht nur aggregiert) - fuer das
      # Experiment-Tracking (siehe db_logging.R, metric_result.mres_fold).
      scores <- benchmark_result$score(measures = measures)
      scores[, elapsed_seconds := as.numeric(timing[["elapsed"]])]

      benchmark_results[[run_id]] <- benchmark_result
      result_rows[[run_id]] <- result
      score_rows[[run_id]] <- scores
      run_id <- run_id + 1L
    }
  }

  list(
    results = rbindlist(result_rows, fill = TRUE),
    scores = rbindlist(score_rows, fill = TRUE),
    benchmarks = benchmark_results
  )
}
