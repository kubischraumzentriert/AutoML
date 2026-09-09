# =====================================================================
# test-composition_reweighting.R -- Korrektheitstests fuer
# segment_composition_shift()/reweight_metric_by_test_composition()/
# composition_diagnosis_report() (composition_reweighting.R), synthetisch
# auf konstruierten Faellen mit BEKANNTER Komposition/Metrik, bevor der
# reale Anwendungsfall (AStepAheadOfdrought Phase 9, 5-Projekt-Bestaetigung,
# siehe Kopfkommentar composition_reweighting.R) als gegeben angenommen wird.
# =====================================================================
source(testthat::test_path("..", "..", "composition_reweighting.R"))

test_that("segment_composition_shift() erkennt IDENTISCHE Verteilung als unauffaellig (TVD=0)", {
  set.seed(1)
  train_values <- sample(c("A", "B", "C"), 1000, replace = TRUE, prob = c(0.5, 0.3, 0.2))
  test_values <- sample(c("A", "B", "C"), 1000, replace = TRUE, prob = c(0.5, 0.3, 0.2))

  res <- segment_composition_shift(train_values, test_values, tvd_threshold = 0.05)
  expect_lt(res$tvd, 0.05) # grosse Stichprobe, Abweichung nur Sampling-Rauschen
  expect_false(res$auffaellig)
  expect_equal(sum(res$shares$train_share), 1, tolerance = 1e-9)
  expect_equal(sum(res$shares$test_share), 1, tolerance = 1e-9)
})

test_that("segment_composition_shift() erkennt eine DEUTLICH verschobene Verteilung als auffaellig", {
  train_values <- rep(c("kurz", "lang"), c(900, 100)) # 90/10
  test_values <- rep(c("kurz", "lang"), c(100, 900))  # 10/90 - stark verschoben

  res <- segment_composition_shift(train_values, test_values, tvd_threshold = 0.05)
  expect_true(res$auffaellig)
  expect_equal(res$tvd, 0.8, tolerance = 1e-9) # TVD = 0.5*(|0.9-0.1|+|0.1-0.9|) = 0.8
})

test_that("segment_composition_shift() behandelt ein im Train fehlendes Testsegment korrekt (share 0 im Train)", {
  train_values <- rep("A", 100)
  test_values <- c(rep("A", 80), rep("B", 20)) # B kommt im Train NIE vor

  res <- segment_composition_shift(train_values, test_values)
  b_row <- res$shares[segment == "B"]
  expect_equal(b_row$train_share, 0)
  expect_equal(b_row$test_share, 0.2, tolerance = 1e-9)
})

test_that("reweight_metric_by_test_composition() reproduziert den einfachen gewichteten Mittelwert", {
  segment_metric <- data.table::data.table(segment = c("2", "3", "4"), metric = c(0.5, 0.7, 0.9))
  test_shares <- c("2" = 0.2, "3" = 0.3, "4" = 0.5)

  res <- reweight_metric_by_test_composition(segment_metric, test_shares)
  expected <- 0.2 * 0.5 + 0.3 * 0.7 + 0.5 * 0.9
  expect_equal(res$composition_corrected_estimate, expected, tolerance = 1e-9)
  expect_equal(res$coverage, 1, tolerance = 1e-9)
})

test_that("reweight_metric_by_test_composition() liefert bei GLEICHER Metrik je Segment denselben Wert (Komposition egal)", {
  # Wenn die Metrik ueberhaupt nicht vom Segment abhaengt, darf die
  # Neugewichtung nichts aendern - der Kernbefund aus geoai-aquaculture
  # (Komposition erklaert dort kaum etwas, weil der Werte-Shift dominiert,
  # NICHT weil die Metrik segment-unabhaengig ist - aber als Grenzfall
  # muss das Modul das exakt abbilden).
  segment_metric <- data.table::data.table(segment = c("A", "B"), metric = c(0.8, 0.8))
  test_shares <- c(A = 0.9, B = 0.1)
  cv_shares <- c(A = 0.1, B = 0.9)

  res <- reweight_metric_by_test_composition(segment_metric, test_shares, cv_shares)
  expect_equal(res$composition_corrected_estimate, 0.8, tolerance = 1e-9)
  expect_equal(res$cv_weighted_estimate, 0.8, tolerance = 1e-9)
})

test_that("reweight_metric_by_test_composition() zeigt einen ECHTEN Kompositionseffekt bei segmentabhaengiger Metrik", {
  # Konstruiert wie Drought/geoai: die Metrik variiert deutlich nach Segment,
  # und Test hat viel mehr vom "schlechten" Segment als die CV-Gewichtung.
  segment_metric <- data.table::data.table(segment = c("kurz", "lang"), metric = c(0.60, 0.95))
  cv_shares <- c(kurz = 0.1, lang = 0.9)   # CV sieht ueberwiegend "lang" (gutes Segment)
  test_shares <- c(kurz = 0.9, lang = 0.1) # Test hat ueberwiegend "kurz" (schlechtes Segment)

  res <- reweight_metric_by_test_composition(segment_metric, test_shares, cv_shares)
  cv_weighted <- 0.1 * 0.60 + 0.9 * 0.95
  test_weighted <- 0.9 * 0.60 + 0.1 * 0.95

  expect_equal(res$cv_weighted_estimate, cv_weighted, tolerance = 1e-9)
  expect_equal(res$composition_corrected_estimate, test_weighted, tolerance = 1e-9)
  expect_lt(res$composition_corrected_estimate, res$cv_weighted_estimate) # Test-Komposition ist schlechter
})

test_that("reweight_metric_by_test_composition() meldet unvollstaendige Deckung (Segment im Test, aber nie gemessen)", {
  segment_metric <- data.table::data.table(segment = c("A"), metric = c(0.9))
  test_shares <- c(A = 0.7, B = 0.3) # B wurde nie gemessen

  res <- reweight_metric_by_test_composition(segment_metric, test_shares)
  expect_equal(res$coverage, 0.7, tolerance = 1e-9)
  expect_equal(res$composition_corrected_estimate, 0.9, tolerance = 1e-9) # nur ueber das gemessene Segment
})

test_that("reweight_metric_by_test_composition() akzeptiert test_shares als data.table", {
  segment_metric <- data.table::data.table(segment = c("A", "B"), metric = c(0.4, 0.6))
  test_shares_dt <- data.table::data.table(segment = c("A", "B"), share = c(0.25, 0.75))

  res <- reweight_metric_by_test_composition(segment_metric, test_shares_dt)
  expect_equal(res$composition_corrected_estimate, 0.25 * 0.4 + 0.75 * 0.6, tolerance = 1e-9)
})

test_that("reweight_metric_by_test_composition() bricht bei doppelten Segmenten in segment_metric kontrolliert ab", {
  segment_metric <- data.table::data.table(segment = c("A", "A"), metric = c(0.4, 0.5))
  expect_error(reweight_metric_by_test_composition(segment_metric, c(A = 1)), "EINE Zeile")
})

test_that("composition_diagnosis_report() rechnet Stufe 2 bei unauffaelligem Vorab-Check NICHT automatisch", {
  set.seed(2)
  train_values <- sample(c("A", "B"), 500, replace = TRUE, prob = c(0.5, 0.5))
  test_values <- sample(c("A", "B"), 500, replace = TRUE, prob = c(0.5, 0.5))
  segment_metric <- data.table::data.table(segment = c("A", "B"), metric = c(0.8, 0.9))

  out <- testthat::capture_output(
    res <- composition_diagnosis_report(train_values, test_values, segment_metric, label = "test-iid")
  )
  expect_false(res$auffaellig)
  expect_true(is.na(res$composition_corrected_estimate))
})

test_that("composition_diagnosis_report() rechnet Stufe 2 bei auffaelligem Vorab-Check automatisch", {
  train_values <- rep(c("kurz", "lang"), c(100, 900))
  test_values <- rep(c("kurz", "lang"), c(900, 100))
  segment_metric <- data.table::data.table(segment = c("kurz", "lang"), metric = c(0.6, 0.95))

  out <- testthat::capture_output(
    res <- composition_diagnosis_report(train_values, test_values, segment_metric, label = "test-shift")
  )
  expect_true(res$auffaellig)
  expect_false(is.na(res$composition_corrected_estimate))
  expect_lt(res$composition_corrected_estimate, 0.95) # dominiert vom "kurz"-Segment im Test
})

test_that("composition_diagnosis_report() rechnet Stufe 2 bei force=TRUE auch wenn unauffaellig", {
  set.seed(3)
  train_values <- sample(c("A", "B"), 500, replace = TRUE, prob = c(0.5, 0.5))
  test_values <- sample(c("A", "B"), 500, replace = TRUE, prob = c(0.5, 0.5))
  segment_metric <- data.table::data.table(segment = c("A", "B"), metric = c(0.8, 0.9))

  out <- testthat::capture_output(
    res <- composition_diagnosis_report(train_values, test_values, segment_metric,
                                         label = "test-force", force = TRUE)
  )
  expect_false(res$auffaellig)
  expect_false(is.na(res$composition_corrected_estimate))
})
