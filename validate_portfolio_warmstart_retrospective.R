rm(list = ls())

project_dir <- normalizePath(".")
source("000_config.R")

algorithm_best_path <- file.path(artifact_dir, "portfolio_warmstart_algorithm_best.csv")
recommendation_path <- file.path(artifact_dir, "portfolio_warmstart_recommendation.csv")
validation_csv_path <- file.path(artifact_dir, "portfolio_warmstart_validation.csv")
validation_md_path <- file.path(artifact_dir, "portfolio_warmstart_validation.md")
loo_csv_path <- file.path(artifact_dir, "portfolio_warmstart_validation_leave_one_project_out.csv")

if (!file.exists(algorithm_best_path)) {
  stop(
    "Algorithmus-Evidenz fehlt: ", algorithm_best_path, "\n",
    "Bitte zuerst build_portfolio_warmstart_evidence.R ausfuehren."
  )
}
if (!file.exists(recommendation_path)) {
  stop(
    "Warmstart-Empfehlung fehlt: ", recommendation_path, "\n",
    "Bitte zuerst recommend_portfolio_warmstart.R ausfuehren."
  )
}

algorithm_best <- read.csv(algorithm_best_path, stringsAsFactors = FALSE)
recommendation <- read.csv(recommendation_path, stringsAsFactors = FALSE)
recommended_families <- recommendation$algorithm_family

recommendation_position <- setNames(seq_along(recommended_families), recommended_families)

assign_role <- function(n_projects, win_rate, top3_rate, median_regret, median_elapsed_seconds) {
  if (n_projects < 2) {
    return("observe_more")
  }
  if (win_rate >= 0.25 || (top3_rate >= 0.60 && median_regret <= 0.01)) {
    return("core_portfolio")
  }
  if (top3_rate >= 0.35 && median_regret <= 0.03) {
    return("candidate_portfolio")
  }
  if (!is.na(median_elapsed_seconds) && median_elapsed_seconds > 300 && top3_rate < 0.25) {
    return("expensive_low_priority")
  }
  "low_priority"
}

summarize_families <- function(rows) {
  if (nrow(rows) == 0) return(data.frame())
  rows <- do.call(rbind, lapply(split(rows, rows$project_metric), function(dt) {
    dt <- dt[order(dt$loss, dt$algorithm_family), , drop = FALSE]
    dt$rank_family <- rank(dt$loss, ties.method = "min")
    best_loss <- min(dt$loss)
    dt$family_regret <- dt$loss - best_loss
    dt
  }))

  summary_rows <- do.call(rbind, lapply(split(rows, rows$algorithm_family), function(dt) {
    n_projects <- length(unique(dt$project_metric))
    wins <- sum(dt$rank_family == 1)
    top3 <- sum(dt$rank_family <= 3)
    median_elapsed <- median(dt$mres_elapsed_seconds, na.rm = TRUE)
    if (!is.finite(median_elapsed)) median_elapsed <- NA_real_
    median_regret <- median(dt$family_regret, na.rm = TRUE)
    if (!is.finite(median_regret)) median_regret <- NA_real_

    data.frame(
      algorithm_family = dt$algorithm_family[1],
      n_project_metrics = n_projects,
      wins = wins,
      top3 = top3,
      win_rate = wins / n_projects,
      top3_rate = top3 / n_projects,
      median_regret = median_regret,
      mean_regret = mean(dt$family_regret, na.rm = TRUE),
      median_elapsed_seconds = median_elapsed,
      role = assign_role(n_projects, wins / n_projects, top3 / n_projects, median_regret, median_elapsed),
      stringsAsFactors = FALSE
    )
  }))

  summary_rows[order(
    match(summary_rows$role, c("core_portfolio", "candidate_portfolio", "observe_more", "low_priority", "expensive_low_priority")),
    -summary_rows$win_rate,
    -summary_rows$top3_rate,
    summary_rows$median_regret,
    summary_rows$median_elapsed_seconds
  ), ]
}

recommend_from_training <- function(training_rows, k = 3L) {
  family_summary <- summarize_families(training_rows)
  if (nrow(family_summary) == 0) return(character(0))
  candidates <- family_summary[family_summary$role %in% c("core_portfolio", "candidate_portfolio"), , drop = FALSE]
  if (nrow(candidates) == 0) {
    candidates <- family_summary
  }
  head(candidates$algorithm_family, k)
}

project_metric_groups <- split(algorithm_best, algorithm_best$project_metric)
validation <- do.call(rbind, lapply(project_metric_groups, function(dt) {
  dt <- dt[order(dt$rank_algorithm, dt$algorithm_family), , drop = FALSE]
  observed_recommended <- dt[dt$algorithm_family %in% recommended_families, , drop = FALSE]

  if (nrow(observed_recommended) == 0) {
    return(data.frame(
      proj_name = dt$proj_name[1],
      measure = dt$mres_measure_name[1],
      n_observed_families = length(unique(dt$algorithm_family)),
      n_recommended_observed = 0L,
      best_family_overall = dt$algorithm_family[1],
      best_family_recommended = NA_character_,
      best_after_1 = NA_real_,
      best_after_2 = NA_real_,
      best_after_all_recommended = NA_real_,
      winner_found_by_recommendation = FALSE,
      winner_position = NA_integer_,
      regret_after_1 = NA_real_,
      regret_after_2 = NA_real_,
      regret_after_all_recommended = NA_real_,
      stringsAsFactors = FALSE
    ))
  }

  observed_recommended$recommended_position <- recommendation_position[observed_recommended$algorithm_family]
  observed_recommended <- observed_recommended[order(observed_recommended$recommended_position), , drop = FALSE]

  best_loss <- min(dt$loss)
  best_after <- function(k) {
    subset <- observed_recommended[observed_recommended$recommended_position <= k, , drop = FALSE]
    if (nrow(subset) == 0) return(NA_real_)
    min(subset$loss) - best_loss
  }

  best_recommended <- observed_recommended[order(observed_recommended$loss), , drop = FALSE][1, ]
  winner_family <- dt$algorithm_family[dt$loss == best_loss][1]
  winner_pos <- if (winner_family %in% observed_recommended$algorithm_family) {
    observed_recommended$recommended_position[match(winner_family, observed_recommended$algorithm_family)]
  } else {
    NA_integer_
  }

  data.frame(
    proj_name = dt$proj_name[1],
    measure = dt$mres_measure_name[1],
    n_observed_families = length(unique(dt$algorithm_family)),
    n_recommended_observed = nrow(observed_recommended),
    best_family_overall = winner_family,
    best_family_recommended = best_recommended$algorithm_family[1],
    best_after_1 = best_after(1),
    best_after_2 = best_after(2),
    best_after_all_recommended = min(observed_recommended$loss) - best_loss,
    winner_found_by_recommendation = winner_family %in% observed_recommended$algorithm_family,
    winner_position = winner_pos,
    regret_after_1 = best_after(1),
    regret_after_2 = best_after(2),
    regret_after_all_recommended = min(observed_recommended$loss) - best_loss,
    stringsAsFactors = FALSE
  )
}))

validation <- validation[order(validation$proj_name, validation$measure), ]
write.csv(validation, validation_csv_path, row.names = FALSE)

covered <- validation[validation$n_recommended_observed > 0, , drop = FALSE]
full_candidates <- validation[validation$n_recommended_observed >= min(2L, length(recommended_families)), , drop = FALSE]
winner_hits <- sum(covered$winner_found_by_recommendation, na.rm = TRUE)
after_1_median <- median(covered$regret_after_1, na.rm = TRUE)
after_2_median <- median(covered$regret_after_2, na.rm = TRUE)
after_all_median <- median(covered$regret_after_all_recommended, na.rm = TRUE)

project_summary <- aggregate(
  winner_found_by_recommendation ~ proj_name,
  data = covered,
  FUN = function(x) c(n = length(x), hit_rate = mean(x))
)
project_summary <- do.call(data.frame, project_summary)
names(project_summary) <- c("proj_name", "n_metrics", "hit_rate")
project_summary <- project_summary[order(-project_summary$hit_rate, project_summary$proj_name), ]

md <- c(
  "# Portfolio-Warmstart-Retrospektive",
  "",
  paste0("- Empfehlung: `", paste(recommended_families, collapse = " -> "), "`"),
  paste0("- Bewertete Projekt-Metriken: ", nrow(validation)),
  paste0("- Mit mindestens einem empfohlenen Kandidaten: ", nrow(covered)),
  paste0("- Mit mindestens zwei empfohlenen Kandidaten: ", nrow(full_candidates)),
  paste0("- Eindeutige reale Projekte: ", length(unique(covered$proj_name))),
  paste0("- Gewinnerfamilie in Empfehlung enthalten: ", winner_hits, " / ", nrow(covered)),
  paste0("- Median-Regret nach 1 Kandidat: ", round(after_1_median, 4)),
  paste0("- Median-Regret nach 2 Kandidaten: ", round(after_2_median, 4)),
  paste0("- Median-Regret nach allen empfohlenen Kandidaten: ", round(after_all_median, 4)),
  "",
  "## Projektueberblick",
  ""
)

for (i in seq_len(min(12L, nrow(project_summary)))) {
  row <- project_summary[i, ]
  md <- c(md, paste0("- `", row$proj_name, "`: ", row$n_metrics, " Metriken, Hit-Rate ", round(row$hit_rate, 2)))
}

md <- c(
  md,
  "",
  "## Einordnung",
  "",
  paste(
    "Diese Retrospektive ist noch keine echte Out-of-sample-Validierung, weil",
    "die Empfehlung aus derselben zentralen DB abgeleitet wurde. Sie prueft aber,",
    "ob die Startliste intern plausibel und auf mehr als zwei realen Projekten",
    "anschlussfaehig ist. Der naechste strengere Schritt ist Leave-one-project-out:",
    "Empfehlung ohne das jeweilige Projekt bauen und dann gegen dieses",
    "zuruecktesten."
  )
)

writeLines(md, validation_md_path, useBytes = TRUE)

heldout_projects <- sort(unique(algorithm_best$proj_name))
loo_rows <- list()
for (heldout in heldout_projects) {
  training_rows <- algorithm_best[algorithm_best$proj_name != heldout, , drop = FALSE]
  test_groups <- split(algorithm_best[algorithm_best$proj_name == heldout, , drop = FALSE], algorithm_best$project_metric[algorithm_best$proj_name == heldout])
  loo_families <- recommend_from_training(training_rows, k = 3L)
  loo_position <- setNames(seq_along(loo_families), loo_families)

  for (nm in names(test_groups)) {
    dt <- test_groups[[nm]]
    dt <- dt[order(dt$loss, dt$algorithm_family), , drop = FALSE]
    observed_recommended <- dt[dt$algorithm_family %in% loo_families, , drop = FALSE]
    best_loss <- min(dt$loss)
    winner_family <- dt$algorithm_family[dt$loss == best_loss][1]

    if (nrow(observed_recommended) == 0) {
      loo_rows[[length(loo_rows) + 1L]] <- data.frame(
        heldout_project = heldout,
        measure = dt$mres_measure_name[1],
        recommended_families = paste(loo_families, collapse = " -> "),
        winner_family = winner_family,
        winner_found = FALSE,
        regret_after_1 = NA_real_,
        regret_after_2 = NA_real_,
        regret_after_3 = NA_real_,
        stringsAsFactors = FALSE
      )
      next
    }

    observed_recommended$recommended_position <- loo_position[observed_recommended$algorithm_family]
    best_after <- function(k) {
      subset <- observed_recommended[observed_recommended$recommended_position <= k, , drop = FALSE]
      if (nrow(subset) == 0) return(NA_real_)
      min(subset$loss) - best_loss
    }

    loo_rows[[length(loo_rows) + 1L]] <- data.frame(
      heldout_project = heldout,
      measure = dt$mres_measure_name[1],
      recommended_families = paste(loo_families, collapse = " -> "),
      winner_family = winner_family,
      winner_found = winner_family %in% observed_recommended$algorithm_family,
      regret_after_1 = best_after(1),
      regret_after_2 = best_after(2),
      regret_after_3 = best_after(3),
      stringsAsFactors = FALSE
    )
  }
}

loo_validation <- do.call(rbind, loo_rows)
write.csv(loo_validation, loo_csv_path, row.names = FALSE)

loo_hit_rate <- mean(loo_validation$winner_found, na.rm = TRUE)
loo_after_1 <- median(loo_validation$regret_after_1, na.rm = TRUE)
loo_after_2 <- median(loo_validation$regret_after_2, na.rm = TRUE)
loo_after_3 <- median(loo_validation$regret_after_3, na.rm = TRUE)

loo_block <- c(
  "",
  "## Leave-one-project-out",
  "",
  paste0("- Artefakt: `_artifacts/", basename(loo_csv_path), "`"),
  paste0("- Bewertete Projekt-Metriken: ", nrow(loo_validation)),
  paste0("- Gewinnerfamilie in LOO-Empfehlung enthalten: ", sum(loo_validation$winner_found), " / ", nrow(loo_validation), " (", round(loo_hit_rate, 2), ")"),
  paste0("- Median-Regret nach 1 Kandidat: ", round(loo_after_1, 4)),
  paste0("- Median-Regret nach 2 Kandidaten: ", round(loo_after_2, 4)),
  paste0("- Median-Regret nach 3 Kandidaten: ", round(loo_after_3, 4)),
  "",
  paste(
    "Das ist die strengere interne Pruefung: Das jeweils bewertete Projekt",
    "wird beim Ableiten der Kandidatenliste ausgeschlossen. Damit ist der",
    "Befund noch keine externe Benchmark-Studie, aber deutlich belastbarer",
    "als die reine Leave-in-Zusammenfassung."
  )
)

writeLines(c(readLines(validation_md_path, warn = FALSE), loo_block), validation_md_path, useBytes = TRUE)

cat("Portfolio-Warmstart-Retrospektive geschrieben:\n")
cat("  -", validation_csv_path, "\n")
cat("  -", validation_md_path, "\n\n")
cat("  -", loo_csv_path, "\n\n")
cat("Kurzbefund:\n")
cat("  Projekt-Metriken:", nrow(validation), "\n")
cat("  Reale Projekte:", length(unique(covered$proj_name)), "\n")
cat("  Gewinner in Empfehlung:", winner_hits, "/", nrow(covered), "\n")
cat("  Median-Regret nach 1/2/allen Kandidaten:", round(after_1_median, 4), "/", round(after_2_median, 4), "/", round(after_all_median, 4), "\n")
cat("  LOO Gewinner in Empfehlung:", sum(loo_validation$winner_found), "/", nrow(loo_validation), "\n")
cat("  LOO Median-Regret nach 1/2/3 Kandidaten:", round(loo_after_1, 4), "/", round(loo_after_2, 4), "/", round(loo_after_3, 4), "\n")
