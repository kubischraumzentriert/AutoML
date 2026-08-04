rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(DBI)
  library(ggplot2)
})

source("000_config.R")
source(file.path(project_dir, "db_logging.R"))
source(file.path(project_dir, "008_curve_diagnostics.R"))

# Welche Algorithmen geplottet werden - muessen vorher vollstaendig geloggte
# Vorhersagen in experiments.db haben (siehe 147_error_analysis_ranger.R,
# db_log_predictions() mit ALLEN Eval-Zeilen statt nur "interessanten").
algorithms_to_plot <- c("ranger", "lightgbm", "lda")

# compute_classif_curves() braucht keine binaere Aufgabe: "truth == positive"
# fasst bei >=3 Klassen automatisch alle anderen Klassen als "negativ"
# zusammen - das Ergebnis ist eine One-vs-Rest-Kurve fuer genau DIESE eine
# Klasse. Positive Klasse: bei BINAEREN Aufgaben aus 000_config.R
# (positive_class); bei Multiclass (positive_class = NULL) hier eine Klasse
# fuer die One-vs-Rest-Kurve waehlen (Default: klinisch relevanteste Klasse
# des Template-Eigenprojekts).
if (is.null(positive_class)) positive_class <- "unhealthy"

con <- db_connect()

# Anteil der positiven Klasse im Eval-Split - die Baseline eines "zufaelligen"
# Klassifikators in der PR-Kurve (im Gegensatz zur ROC-Kurve, wo die Diagonale
# unabhaengig von der Klassenverteilung ist).
prevalence <- NA_real_

curves <- rbindlist(lapply(algorithms_to_plot, function(algo) {
  preds <- load_latest_predictions(con, algo, positive_class = positive_class)
  curve <- compute_classif_curves(preds$pred_truth, preds$prob_positive, positive = positive_class)

  if (is.na(prevalence)) {
    prevalence <<- mean(preds$pred_truth == positive_class)
  }

  pr_auc <- curve_auc(curve$recall, curve$precision)
  cat(sprintf("  %-10s PR-AUC (Average Precision) = %.4f\n", algo, pr_auc))

  curve[, algorithm := sprintf("%s (PR-AUC=%.3f)", algo, pr_auc)]
}))

DBI::dbDisconnect(con)

p <- ggplot(curves, aes(x = recall, y = precision, color = algorithm)) +
  geom_line(linewidth = 0.9) +
  geom_hline(yintercept = prevalence, linetype = "dashed", color = "grey60") +
  labs(
    title = paste0("Precision-Recall-Kurve - ", project_name),
    subtitle = sprintf("Gestrichelte Linie = Praevalenz der positiven Klasse (%.1f%%, Zufalls-Baseline)", 100 * prevalence),
    x = "Recall (= TPR)",
    y = "Precision",
    color = "Modell"
  ) +
  ylim(0, 1) +
  theme_minimal()

pr_plot_path <- file.path(artifact_dir, "pr_curve.png")
ggsave(pr_plot_path, p, width = 7, height = 6, dpi = 150)

cat("\nGespeichert:", pr_plot_path, "\n")
