rm(list = ls())

project_dir <- normalizePath(".")
source("000_config.R")

args <- commandArgs(trailingOnly = TRUE)
budget <- "balanced"
if (length(args) > 0) {
  budget_arg <- sub("^--budget=", "", args[grepl("^--budget=", args)])
  if (length(budget_arg) > 0 && nzchar(budget_arg[1])) {
    budget <- budget_arg[1]
  }
}
allowed_budgets <- c("lean", "balanced", "rich")
if (!budget %in% allowed_budgets) {
  stop("Unbekanntes Budget: ", budget, ". Erlaubt: ", paste(allowed_budgets, collapse = ", "))
}

summary_path <- file.path(artifact_dir, "portfolio_warmstart_summary.csv")
recommendation_csv_path <- file.path(artifact_dir, "portfolio_warmstart_recommendation.csv")
recommendation_md_path <- file.path(artifact_dir, "portfolio_warmstart_recommendation.md")

if (!file.exists(summary_path)) {
  stop(
    "Portfolio-Summary fehlt: ", summary_path, "\n",
    "Bitte zuerst build_portfolio_warmstart_evidence.R ausfuehren."
  )
}

portfolio <- read.csv(summary_path, stringsAsFactors = FALSE)

estimate_project_shape <- function(train_path, id_col, target_col) {
  if (!file.exists(train_path)) {
    return(list(n_rows = NA_integer_, n_features = NA_integer_, size_bucket = "unknown"))
  }

  header <- strsplit(readLines(train_path, n = 1, warn = FALSE), ",", fixed = TRUE)[[1]]
  n_cols <- length(header)
  excluded_cols <- intersect(c(id_col, target_col), header)
  n_features <- n_cols - length(excluded_cols)

  con <- file(train_path, open = "r")
  on.exit(close(con), add = TRUE)
  n_lines <- 0L
  repeat {
    chunk <- readLines(con, n = 100000L, warn = FALSE)
    if (length(chunk) == 0L) break
    n_lines <- n_lines + length(chunk)
  }
  n_rows <- max(n_lines - 1L, 0L)

  size_bucket <- if (is.na(n_rows)) {
    "unknown"
  } else if (n_rows <= 10000L) {
    "small"
  } else if (n_rows <= 100000L) {
    "medium"
  } else {
    "large"
  }

  list(n_rows = n_rows, n_features = n_features, size_bucket = size_bucket)
}

project_shape <- estimate_project_shape(train_path, id_col, target_col)
primary_metric <- baseline_measure_ids[1]

portfolio_row <- function(family) {
  hit <- portfolio[portfolio$algorithm_family == family, , drop = FALSE]
  if (nrow(hit) == 0) return(NULL)
  hit[1, , drop = FALSE]
}

make_item <- function(priority, family, stage, action, reason, evidence_role = NA_character_) {
  ev <- portfolio_row(family)
  if (!is.null(ev)) {
    evidence_role <- ev$role[1]
    evidence <- sprintf(
      "n=%s, wins=%s, top3=%.2f, median_regret=%.4f, median_elapsed=%s",
      ev$n_project_metrics[1], ev$wins[1], ev$top3_rate[1], ev$median_regret[1],
      ifelse(is.na(ev$median_elapsed_seconds[1]), "NA", round(ev$median_elapsed_seconds[1], 1))
    )
  } else {
    evidence <- "keine interne Portfolio-Evidenz"
  }

  data.frame(
    priority = priority,
    algorithm_family = family,
    evidence_role = evidence_role,
    stage = stage,
    action = action,
    reason = reason,
    internal_evidence = evidence,
    stringsAsFactors = FALSE
  )
}

items <- list()
items[[length(items) + 1L]] <- make_item(
  1, "lightgbm", "early_core",
  "Frueh benchmarken und als ersten Tuning-Kandidaten behandeln.",
  "Staerkster interner Siegeranteil; guter Default fuer tabellarische Klassifikation."
)
items[[length(items) + 1L]] <- make_item(
  2, "ranger", "early_core",
  "Frueh benchmarken; als robuste Gegenprobe zu LightGBM halten.",
  "Sehr hohe Top-3-Rate und niedriger Median-Regret; stabiler Baum-Ensemble-Anker."
)

if (budget %in% c("balanced", "rich") && project_shape$size_bucket != "large") {
  items[[length(items) + 1L]] <- make_item(
    3, "catboost", "diversity_candidate",
    "Als Diversitaetskandidat testen, besonders bei kategorialen Features.",
    "Interne Evidenz kleiner, aber plausible CatBoost-Staerke bei Kategorien/Ordered Boosting."
  )
}

if (budget == "rich" || project_shape$size_bucket %in% c("small", "medium")) {
  items[[length(items) + 1L]] <- make_item(
    4, "xgboost", "diversity_candidate",
    "Optional benchmarken, wenn One-Hot/Preprocessing ohnehin vorliegt.",
    "Mehrere Top-3-Treffer, aber bisher kein interner Sieg; guter Kontrollkandidat."
  )
}

items[[length(items) + 1L]] <- make_item(
  5, "ensemble", "late_score_lever",
  "Nach den Einzelmodellen Greedy-/gewichtete Ensemble-Selektion pruefen.",
  "AutoGluon/TabRepo-Linie: Diverse Kandidaten werden erst im Ensemble voll nutzbar."
)

if (budget == "rich") {
  items[[length(items) + 1L]] <- make_item(
    6, "stack_logreg", "late_diversity_stack",
    "Nur bei vorhandenen OOF-Predictions als spaetes Stacking-Experiment pruefen.",
    "Hohe interne Top-3-Rate, aber sehr kleine Evidenz und hohe Laufzeit."
  )
}

if (project_shape$size_bucket == "small" && budget == "rich") {
  items[[length(items) + 1L]] <- make_item(
    7, "tabpfn", "selective_foundation_model",
    "Nur als expliziten Spezialtest starten, nicht als Default.",
    "Foundation-Modelle sind literarisch spannend, interne Evidenz hier aber teuer/niedrig priorisiert."
  )
}

recommendation <- do.call(rbind, items)
recommendation <- recommendation[order(recommendation$priority), ]
recommendation$priority <- seq_len(nrow(recommendation))
write.csv(recommendation, recommendation_csv_path, row.names = FALSE)

md <- c(
  "# Portfolio-Warmstart-Empfehlung",
  "",
  paste0("- Projekt: `", project_name, "`"),
  paste0("- Zielspalte: `", target_col, "`"),
  paste0("- Primaermetrik: `", primary_metric, "`"),
  paste0("- Budget: `", budget, "`"),
  paste0("- Groesse: `", project_shape$size_bucket, "` (", project_shape$n_rows, " Zeilen, ", project_shape$n_features, " Features)"),
  "",
  "## Empfohlene Reihenfolge",
  ""
)

for (i in seq_len(nrow(recommendation))) {
  row <- recommendation[i, ]
  md <- c(
    md,
    paste0(
      row$priority, ". `", row$algorithm_family, "` - ", row$stage, ": ",
      row$action, " ",
      row$reason, " Evidenz: ", row$internal_evidence, "."
    )
  )
}

md <- c(
  md,
  "",
  "## Interpretation",
  "",
  paste(
    "Dies ist noch kein Template-Default, sondern eine agentische Startliste.",
    "Der naechste Validierungsschritt ist ein Rueckblick auf mindestens zwei",
    "reale Projekte: Haette diese Reihenfolge frueher bessere Kandidaten",
    "gefunden oder unnoetige Laeufe reduziert?"
  )
)

writeLines(md, recommendation_md_path, useBytes = TRUE)

cat("Portfolio-Warmstart-Empfehlung geschrieben:\n")
cat("  -", recommendation_csv_path, "\n")
cat("  -", recommendation_md_path, "\n\n")
print(recommendation, row.names = FALSE)
