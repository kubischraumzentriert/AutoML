suppressPackageStartupMessages(library(data.table))

# Generischer, ZEIT-RESPEKTIERENDER Entitaets-Historie-Feature-Helper.
#
# Rueckgefuehrt aus zwei unabhaengigen Projekten, die dasselbe Muster brauchten:
#   - geoai-drought (Regression): "legal-history" (last_known, months_since_known)
#   - african-credit-scoring (Klassifikation): Kunden-Kredit-Historie
#     (prior_default_rate/_ever, gefensterte Raten, Zeit-seit-letztem).
# Kern: pro Entitaet nur VERGANGENE Ereignisse aggregieren (strikt vor der Zeit
# der aktuellen Zeile). Die Target-Historie zaehlt nur vergangene GELABELTE
# Ereignisse (Test-Prioren haben target = NA und zaehlen nicht). Dadurch
# leak-frei by construction und spiegelt exakt die Test-Situation (eine Test-
# Zeile nutzt die Train-Historie ihrer Entitaet).
#
# NUR fuer Panel-/Forecasting-Daten (wiederholte Entitaeten ueber Zeit), NICHT
# fuer i.i.d.-Tabellen. Optionaler Baustein; vom Standard-Workflow nicht genutzt.
#
# Argumente:
#   dt            data.table (unveraendert; gibt eine erweiterte Kopie zurueck).
#   entity_cols   Spalte(n), die eine Entitaet identifizieren (z.B. "customer_id").
#   time_col      Zeitspalte (Date/IDate/numeric) fuer die Ordnung.
#   value_cols    numerische Spalten fuer Historie-Aggregate (Default: keine).
#   target_col    optional: Zielspalte (0/1 oder numerisch). Nur vergangene,
#                 nicht-NA Werte gehen in die Target-Historie ein.
#   windows       Fenstergroessen fuer gefensterte Aggregate (Default c(3, 6)).
#   tiebreak_col  optional: deterministischer Gleichstand-Brecher bei time_col.
#
# Erzeugte Features:
#   n_prior, is_first, time_since_last;
#   je value v: prior_<v>_last, prior_<v>_mean, prior_<v>_mean_w{k},
#               ratio_<v>_to_prior;
#   bei target: n_prior_known, prior_target_count, prior_target_rate,
#               prior_target_ever, prior_target_rate_w{k}, time_since_last_positive.
add_entity_history <- function(dt, entity_cols, time_col, value_cols = character(),
                               target_col = NULL, windows = c(3L, 6L),
                               tiebreak_col = NULL) {
  stopifnot(data.table::is.data.table(dt), length(entity_cols) >= 1L, length(time_col) == 1L)
  d <- copy(dt)
  d[, .orig_row := .I]
  setorderv(d, c(entity_cols, time_col, tiebreak_col))
  g <- entity_cols

  d[, n_prior := seq_len(.N) - 1L, by = g]
  d[, is_first := as.integer(n_prior == 0L)]
  d[, .tnum := as.numeric(get(time_col))]
  d[, time_since_last := .tnum - shift(.tnum, 1L), by = g]

  for (v in value_cols) {
    d[, paste0("prior_", v, "_last") := shift(get(v), 1L), by = g]
    d[, paste0("prior_", v, "_mean") := fifelse(n_prior > 0L,
        shift(cumsum(get(v)), 1L, fill = 0) / pmax(n_prior, 1L), NA_real_), by = g]
    for (w in windows) {
      d[, paste0("prior_", v, "_mean_w", w) := {
        cs <- cumsum(get(v))
        num <- shift(cs, 1L, fill = 0) - shift(cs, w + 1L, fill = 0)
        den <- pmin(n_prior, w)
        fifelse(den > 0, num / den, NA_real_)
      }, by = g]
    }
    d[, paste0("ratio_", v, "_to_prior") := {
      pl <- shift(get(v), 1L)
      fifelse(!is.na(pl) & pl != 0, get(v) / pl, NA_real_)
    }, by = g]
  }

  if (!is.null(target_col)) {
    d[, .tgt0 := fifelse(is.na(get(target_col)), 0, as.numeric(get(target_col)))]
    d[, .known0 := as.integer(!is.na(get(target_col)))]
    d[, .cum_tgt := cumsum(.tgt0), by = g]
    d[, .cum_known := cumsum(.known0), by = g]
    d[, n_prior_known := shift(.cum_known, 1L, fill = 0), by = g]
    d[, prior_target_count := shift(.cum_tgt, 1L, fill = 0), by = g]
    d[, prior_target_rate := fifelse(n_prior_known > 0L, prior_target_count / n_prior_known, NA_real_)]
    d[, prior_target_ever := as.integer(prior_target_count > 0)]
    for (w in windows) {
      d[, paste0("prior_target_rate_w", w) := {
        pd <- shift(.cum_tgt, 1L, fill = 0) - shift(.cum_tgt, w + 1L, fill = 0)
        pk <- shift(.cum_known, 1L, fill = 0) - shift(.cum_known, w + 1L, fill = 0)
        fifelse(pk > 0, pd / pk, NA_real_)
      }, by = g]
    }
    d[, .pos_t := fifelse(.known0 == 1L & .tgt0 == 1, .tnum, NA_real_)]
    d[, .last_pos := shift(nafill(.pos_t, "locf"), 1L), by = g]
    d[, time_since_last_positive := .tnum - .last_pos]
    d[, c(".tgt0", ".known0", ".cum_tgt", ".cum_known", ".pos_t", ".last_pos") := NULL]
  }

  setorderv(d, ".orig_row")
  d[, c(".orig_row", ".tnum") := NULL]
  d[]
}
