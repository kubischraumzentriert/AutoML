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

curves <- rbindlist(lapply(algorithms_to_plot, function(algo) {
  preds <- load_latest_predictions(con, algo, positive_class = positive_class)
  curve <- compute_classif_curves(preds$pred_truth, preds$prob_positive, positive = positive_class)

  roc_auc <- curve_auc(curve$fpr, curve$tpr)
  db_auc <- dbGetQuery(con, "
    SELECT mr.mres_value
    FROM metric_result mr
    JOIN model_config mc ON mc.mconf_id = mr.mres_mconf_id
    JOIN run r ON r.run_id = mc.mconf_run_id
    WHERE mc.mconf_algorithm = ? AND mr.mres_measure_name = 'classif.auc' AND mr.mres_fold IS NULL
    ORDER BY r.run_started_at DESC LIMIT 1
  ", params = list(algo))$mres_value

  cat(sprintf(
    "  %-10s AUC (aus Kurve) = %.4f%s\n",
    algo, roc_auc,
    if (length(db_auc) == 1) sprintf(" | AUC (aus metric_result) = %.4f", db_auc) else ""
  ))

  curve[, algorithm := sprintf("%s (AUC=%.3f)", algo, roc_auc)]
}))

DBI::dbDisconnect(con)

p <- ggplot(curves, aes(x = fpr, y = tpr, color = algorithm)) +
  geom_line(linewidth = 0.9) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "grey60") +
  coord_equal() +
  labs(
    title = paste0("ROC-Kurve - ", project_name),
    x = "Falsch-Positiv-Rate (FPR)",
    y = "Richtig-Positiv-Rate (TPR)",
    color = "Modell"
  ) +
  theme_minimal()

roc_plot_path <- file.path(artifact_dir, "roc_curve.png")
ggsave(roc_plot_path, p, width = 7, height = 6, dpi = 150)

cat("\nGespeichert:", roc_plot_path, "\n")
