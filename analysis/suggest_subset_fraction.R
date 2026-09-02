# =====================================================================
# suggest_subset_fraction.R -- Vorschlag fuer subset_fraction in
# 000_config.R, bei der Uebertragung auf ein NEUES Projekt auszufuehren
# (siehe TARGETS.md fuer Herkunft).
# =====================================================================
# subset_fraction als fester Prozentsatz (Template-Default 10%) kann bei
# kleinen Datensaetzen zu wenige ABSOLUTE Zeilen ergeben - z.B.
# steel-plates-fault: 1941*0.10 = 194 Zeilen, faktisch zu wenig fuer
# verlaessliche Baseline-/Tuning-Entscheidungen (musste diese Session
# manuell auf 1.0 gesetzt werden). Dieses Skript schlaegt stattdessen einen
# Anteil vor, der eine MINDEST-Zeilenzahl sicherstellt, statt blind am
# Prozentsatz festzuhalten.
#
# min_rows=20000 als Default: an der unteren Grenze dessen, was diese
# Session als "noch unauffaellig" beobachtet hat (health_condition-Subset
# bei 69008 Zeilen zeigte in split_size_sensitivity.R/generalization_gap.R
# durchgehend kleine Streuung; satimage bei 6430 Zeilen war in mehreren
# Checks naeher an der jeweiligen Flagging-Schwelle). Reine Faustregel,
# KEIN separat statistisch verifizierter Schwellenwert wie bei den anderen
# vier Diagnose-Modulen - dafuer braucht es weitere Projekt-Erfahrung.
#
# Reproduziert rueckwirkend die bereits manuell getroffenen Entscheidungen:
# steel-plates-fault (1941 Zeilen) -> 1.0 (manuell gewaehlt: 1.0, exakt
# reproduziert). health_condition (690088 Zeilen) -> 0.10 (unveraendert,
# Floor bereits erreicht, exakt reproduziert).

#' @param n_full Zeilenzahl des vollen Trainingsdatensatzes
#' @param default_fraction Ausgangspunkt, wenn die Mindestzeilenzahl schon
#'   erreicht ist (Template-Konvention: 0.10)
#' @param min_rows Mindest-absolute Zeilenzahl, die subset_fraction * n_full
#'   erreichen soll
#' @return vorgeschlagener subset_fraction-Wert (0, 1]
suggest_subset_fraction <- function(n_full, default_fraction = 0.10, min_rows = 20000) {
  stopifnot(n_full > 0, default_fraction > 0, default_fraction <= 1, min_rows > 0)
  min(1, max(default_fraction, min_rows / n_full))
}

# --- Direkter Aufruf: train.csv im aktuellen Projektverzeichnis -------------
if (!interactive() && sys.nframe() == 0) {
  if (!file.exists("train.csv")) {
    cat("train.csv nicht im aktuellen Verzeichnis gefunden - Pfad manuell anpassen und\n",
        "suggest_subset_fraction(n_full) direkt aufrufen.\n", sep = "")
  } else {
    n_full <- data.table::fread("train.csv", select = 1L)[, .N]
    fraction <- suggest_subset_fraction(n_full)
    cat(sprintf("Zeilen (train.csv): %d\n", n_full))
    cat(sprintf("Vorschlag subset_fraction: %.3f  (=> %d Zeilen im Subset)\n",
                fraction, round(fraction * n_full)))
    cat("In 000_config.R uebernehmen (oder bewusst abweichen und begruenden).\n")
  }
}
