suppressPackageStartupMessages(library(data.table))

# ============================================================================
# Ordinale Ziele + Quadratic Weighted Kappa (QWK) - generischer Baustein.
# Neu ggue. den bestehenden Templates: QWK ist eine NICHT-ZERLEGBARE, ordnungs-
# sensitive Metrik. Der bewaehrte Ansatz: das Ziel als REGRESSION vorhersagen
# und die kontinuierliche Ausgabe QWK-optimal in ordinale Klassen RUNDEN
# (statt Multiclass, das die Ordnung ignoriert). Zwei Funktionen:
#   qwk()                        - die Metrik.
#   optimize_ordinal_thresholds()- sucht die QWK-optimalen Schnittpunkte.
#   apply_ordinal_thresholds()   - wendet Schnittpunkte an (kontinuierlich->ordinal).
# ============================================================================

# Quadratic Weighted Kappa (Cohen, quadratische Gewichte). truth/response ganz-
# zahlige Ratings. Rating-Range optional fest vorgeben (sonst aus den Daten).
qwk <- function(truth, response, min_rating = NULL, max_rating = NULL) {
  truth <- as.integer(round(truth)); response <- as.integer(round(response))
  if (is.null(min_rating)) min_rating <- min(c(truth, response))
  if (is.null(max_rating)) max_rating <- max(c(truth, response))
  ratings <- min_rating:max_rating; n <- length(ratings)
  ti <- match(truth, ratings); ri <- match(response, ratings)
  O <- matrix(0, n, n)
  for (k in seq_along(ti)) O[ti[k], ri[k]] <- O[ti[k], ri[k]] + 1
  W <- outer(seq_len(n), seq_len(n), function(i, j) (i - j)^2) / (n - 1)^2
  hist_t <- rowSums(O); hist_r <- colSums(O)
  E <- outer(hist_t, hist_r) / sum(O)
  1 - sum(W * O) / sum(W * E)
}

# Kontinuierliche Vorhersage -> ordinale Klasse ueber sortierte Schnittpunkte.
apply_ordinal_thresholds <- function(pred, thresholds, levels) {
  levels[findInterval(pred, sort(thresholds)) + 1L]
}

# Sucht die (length(levels)-1) Schnittpunkte, die QWK auf (pred, truth) maximieren.
# Start bei den Mittelpunkten (z.B. 3.5, 4.5, ...), Nelder-Mead auf -QWK.
optimize_ordinal_thresholds <- function(pred, truth, levels = sort(unique(truth))) {
  init <- head(levels, -1) + 0.5
  neg_qwk <- function(thr) -qwk(truth, apply_ordinal_thresholds(pred, thr, levels),
                                min(levels), max(levels))
  best <- optim(init, neg_qwk, method = "Nelder-Mead", control = list(maxit = 1000))
  # mehrere Starts fuer Robustheit gegen lokale Optima
  for (jit in list(rep(0, length(init)), runif(length(init), -0.3, 0.3))) {
    o <- optim(init + jit, neg_qwk, method = "Nelder-Mead", control = list(maxit = 1000))
    if (o$value < best$value) best <- o
  }
  sort(best$par)
}
