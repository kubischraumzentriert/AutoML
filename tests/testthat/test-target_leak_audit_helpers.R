# =====================================================================
# test-target_leak_audit_helpers.R -- Korrektheitstests fuer
# compute_determinism()/find_cumulative_suspects()/find_correlated_clusters()
# (target_leak_audit_helpers.R, extrahiert aus 015_target_leak_audit.R).
# =====================================================================
# Positiv-/Negativ-Faelle spiegeln die bereits dokumentierten realen
# Bestaetigungen wider (siehe TARGETS.md): bike-sharing (Leak-PAAR, kumulative
# Schwelle), road-accident-risk (Spezifitaets-Kontrolle - 3 legitime Features
# tragen zusammen 88%, OHNE Einzelverdaechtigen, duerfen NICHT geflaggt
# werden), lending-club (redundanter Leak-Cluster ueber viele Features).
suppressPackageStartupMessages(library(data.table))
source(testthat::test_path("..", "..", "target_leak_audit_helpers.R"))

# --- compute_determinism() --------------------------------------------------

test_that("compute_determinism() erkennt exakten Determinismus (purity=1)", {
  feature <- rep(c("a", "b", "c"), each = 20)
  target <- rep(c("klasse1", "klasse2", "klasse3"), each = 20)  # feature legt target exakt fest
  res <- compute_determinism(feature, target, "testfeature")
  expect_true(all(res$purity == 1))
  expect_equal(nrow(res), 3)
})

test_that("compute_determinism() zeigt KEINEN Determinismus bei Unabhaengigkeit", {
  set.seed(1)
  feature <- sample(letters[1:5], 1000, replace = TRUE)
  target <- sample(c("x", "y"), 1000, replace = TRUE)  # unabhaengig von feature
  res <- compute_determinism(feature, target, "testfeature")
  # Bei Unabhaengigkeit und grossen Gruppen sollte die dominante Klasse nahe
  # der Zufalls-Basisrate liegen (~0.5), nicht bei 1.
  expect_true(all(res$purity < 0.65))
})

test_that("compute_determinism() ignoriert NA-Feature-Werte", {
  feature <- c("a", "a", NA, NA)
  target <- c("x", "x", "y", "x")
  res <- compute_determinism(feature, target, "testfeature")
  expect_equal(nrow(res), 1)  # nur Wert "a" bleibt uebrig
  expect_equal(res$value, "a")
})

# --- find_cumulative_suspects() ---------------------------------------------

test_that("find_cumulative_suspects() findet ein Leak-PAAR (bike-sharing-Muster)", {
  # `registered` (94.7%) ist bereits Einzelverdaechtiger; `casual` (5.3%)
  # liegt knapp darunter, gemeinsam aber 100% - klassisches Leak-PAAR.
  importance_dt <- data.table(feature = c("registered", "casual", "weather", "temp"),
                               share = c(0.947, 0.053, 0.0002, 0.0001))
  res <- find_cumulative_suspects(importance_dt, "registered",
                                   cumulative_share_threshold = 0.98, cumulative_max_k = 5L)
  expect_setequal(res, c("registered", "casual"))
})

test_that("find_cumulative_suspects() flaggt NICHTS ohne Ausgangsverdacht (road-accident-risk-Kontrolle)", {
  # 3 legitime Features tragen zusammen 88% (> 80%, aber unter der 98%-
  # Schwelle waere es ohnehin egal) - entscheidend ist: KEIN Feature liegt
  # einzeln ueber der Einzelschwelle, suspects_importance ist daher LEER.
  # Der Check darf dann NICHTS erzeugen, auch wenn die kumulative Summe hoch ist.
  importance_dt <- data.table(feature = c("curvature", "lighting", "speed_limit", "rest"),
                               share = c(0.364, 0.270, 0.253, 0.113))
  res <- find_cumulative_suspects(importance_dt, character(0),
                                   cumulative_share_threshold = 0.80, cumulative_max_k = 5L)
  expect_equal(res, character(0))
})

test_that("find_cumulative_suspects() bleibt leer, wenn die kumulative Summe die Schwelle nicht ueberschreitet", {
  importance_dt <- data.table(feature = c("suspect", "b", "c", "d"), share = c(0.55, 0.20, 0.15, 0.10))
  res <- find_cumulative_suspects(importance_dt, "suspect",
                                   cumulative_share_threshold = 0.98, cumulative_max_k = 5L)
  # Selbst alle 4 Features zusammen kommen nur auf 1.00 - aber max_k=2 schneidet
  # nach den ersten beiden (0.75) ab, die Schwelle 0.98 wird dort nicht erreicht.
  res2 <- find_cumulative_suspects(importance_dt, "suspect",
                                    cumulative_share_threshold = 0.98, cumulative_max_k = 2L)
  expect_equal(res2, character(0))
})

# --- find_correlated_clusters() ---------------------------------------------

test_that("find_correlated_clusters() findet einen redundanten Cluster (lending-club-Muster)", {
  set.seed(2)
  n <- 200
  base <- rnorm(n)
  # 4 fast-identische (redundante) Spalten + 2 unabhaengige.
  dt <- data.table(
    leak1 = base + rnorm(n, sd = 0.01), leak2 = base + rnorm(n, sd = 0.01),
    leak3 = base + rnorm(n, sd = 0.01), leak4 = base + rnorm(n, sd = 0.01),
    indep1 = rnorm(n), indep2 = rnorm(n)
  )
  cor_mat <- cor(dt)
  importance_dt <- data.table(
    feature = names(dt), share = c(0.10, 0.08, 0.07, 0.06, 0.35, 0.34)
  )
  res <- find_correlated_clusters(cor_mat, importance_dt, correlation_threshold = 0.5)
  expect_setequal(res$features, c("leak1", "leak2", "leak3", "leak4"))
  expect_equal(res$total_share, 0.31, tolerance = 1e-6)
})

test_that("find_correlated_clusters() findet KEINEN Cluster bei unabhaengigen Features", {
  set.seed(3)
  n <- 200
  dt <- data.table(a = rnorm(n), b = rnorm(n), c = rnorm(n), d = rnorm(n))
  cor_mat <- cor(dt)
  importance_dt <- data.table(feature = names(dt), share = c(0.3, 0.3, 0.2, 0.2))
  res <- find_correlated_clusters(cor_mat, importance_dt, correlation_threshold = 0.5)
  expect_equal(res$features, character(0))
  expect_equal(res$total_share, 0)
})
