# =====================================================================
# target_leak_audit_helpers.R -- reine, testbare Funktionen aus
# 015_target_leak_audit.R extrahiert (P0-Testabdeckung, kein Verhaltens-
# aenderung - siehe tests/testthat/test-target_leak_audit_helpers.R).
# =====================================================================
# Der volle Mechanismus (WARUM Determinismus/kumulative Schwelle/Cluster-
# Erkennung einen Leak anzeigen) ist in README.md ("Target-Leakage-Audit")
# beschrieben. Diese Datei enthaelt nur die drei eigenstaendig testbaren
# Kernberechnungen, damit sie mit bekanntem Ground Truth (synthetische
# Positiv-/Negativ-Faelle, analog den bereits dokumentierten realen
# Bestaetigungen road-accident-risk/bike-sharing/lending-club) regressions-
# getestet werden koennen, statt nur manuell einmalig verifiziert zu sein.

#' Schritt 2: Determinismus P(Ziel = Wert | Feature = Wert) fuer EINE
#' niedrig-kardinale Spalte.
#'
#' @param feature_values Vektor der Feature-Werte (eine Zeile je
#'   Beobachtung).
#' @param target_values Vektor der Zielwerte (gleiche Laenge).
#' @param col_name Name des Features (nur fuer die Ergebnis-Spalte).
#' @return `data.table` mit einer Zeile je eindeutigem Feature-Wert: der
#'   dominante Zielwert, dessen Anteil (`purity`) und die Gruppengroesse.
compute_determinism <- function(feature_values, target_values, col_name) {
  dt <- data.table::data.table(value = as.character(feature_values), target = target_values)
  dt <- dt[!is.na(value)]
  agg <- dt[, .(n = .N), by = .(value, target)]
  agg[, total := sum(n), by = value]
  agg[, share := n / total]
  best <- agg[agg[, .I[which.max(share)], by = value]$V1]
  data.table::data.table(
    feature = col_name, value = best$value, n_group = best$total,
    dominant_class = as.character(best$target), purity = best$share
  )
}

#' Kumulative Top-k-Erweiterung eines BESTEHENDEN Einzelfeature-Verdachts
#' (findet Leak-PAARE/-GRUPPEN, bei denen kein Feature einzeln ueber der
#' Schwelle liegt, die fuehrenden Features zusammen aber fast die gesamte
#' Gain-Importance tragen). WICHTIG (siehe 015): laeuft nur, wenn
#' `suspects_importance` bereits nicht-leer ist - erweitert einen
#' bestehenden Verdacht, erzeugt keinen neuen aus einer sauberen
#' Verteilung (siehe road-accident-risk-Spezifitaetskontrolle im Test).
#'
#' @param importance_dt `data.table` mit Spalten `feature`, `share`
#'   (absteigend nach `share` sortiert erwartet).
#' @param suspects_importance Zeichenvektor der bereits per Einzelschwelle
#'   verdaechtigen Features (leer = Check wird uebersprungen).
#' @param cumulative_share_threshold Schwelle fuer die kumulative Summe
#'   (z.B. 0.98).
#' @param cumulative_max_k Wie viele fuehrende Features hoechstens betrachtet
#'   werden.
#' @return Zeichenvektor der (kumulativ) verdaechtigen Features, leer wenn
#'   kein Ausgangsverdacht vorlag oder die Schwelle nicht ueberschritten wird.
find_cumulative_suspects <- function(importance_dt, suspects_importance,
                                      cumulative_share_threshold, cumulative_max_k) {
  if (length(suspects_importance) == 0) {
    return(character(0))
  }
  dt <- data.table::copy(importance_dt)
  dt[, cum_share := cumsum(share)]
  top_k <- dt[seq_len(min(cumulative_max_k, nrow(dt)))]
  crossing_idx <- which(top_k$cum_share > cumulative_share_threshold)
  if (length(crossing_idx) == 0) {
    return(character(0))
  }
  top_k$feature[seq_len(min(crossing_idx))]
}

#' Schritt 1b: groesster Cluster paarweise korrelierter numerischer
#' Features (Redundanz-Verdacht) - NUR die Gruppierung, ohne das
#' anschliessende Retraining/die Score-Zerlegung (die braucht ein echtes
#' Modell und ist kein reiner Berechnungsschritt).
#'
#' @param cor_mat Quadratische Korrelationsmatrix (Feature-Namen als
#'   Dimnames), Diagonale = 1, keine `NA`.
#' @param importance_dt `data.table` mit Spalten `feature`, `share`.
#' @param correlation_threshold Mindest-`|r|`, ab der zwei Features im
#'   selben Cluster landen.
#' @return `list(features = <Zeichenvektor>, total_share = <numerisch>)`
#'   fuer den Cluster mit der groessten summierten Gain-Importance (nur
#'   Cluster mit >= 2 Mitgliedern zaehlen); `features = character(0)`, wenn
#'   kein solcher Cluster existiert.
find_correlated_clusters <- function(cor_mat, importance_dt, correlation_threshold) {
  hc <- hclust(as.dist(1 - abs(cor_mat)), method = "complete")
  clusters <- cutree(hc, h = 1 - correlation_threshold)
  cluster_dt <- data.table::data.table(feature = names(clusters), cluster_id = as.integer(clusters))
  cluster_dt <- merge(cluster_dt, importance_dt[, c("feature", "share")], by = "feature", all.x = TRUE)
  cluster_sizes <- cluster_dt[, .(n = .N, total_share = sum(share, na.rm = TRUE)), by = cluster_id]
  cluster_sizes <- cluster_sizes[n >= 2]
  if (nrow(cluster_sizes) == 0) {
    return(list(features = character(0), total_share = 0))
  }
  data.table::setorder(cluster_sizes, -total_share)
  top_cluster_id <- cluster_sizes$cluster_id[1]
  list(
    features = cluster_dt[cluster_id == top_cluster_id, feature],
    total_share = cluster_sizes$total_share[1]
  )
}
