# =====================================================================
# test-agridatasets_adapter.R -- optionale Agrardaten-Quelle
# =====================================================================

source(testthat::test_path("..", "..", "modules", "agridatasets_adapter.R"))

test_that("agridatasets_available() liefert einen booleschen Wert", {
  expect_type(agridatasets_available(), "logical")
  expect_length(agridatasets_available(), 1)
})

test_that("validate_external_join_key() akzeptiert einen vollstaendigen Schluessel", {
  data <- data.frame(id = c("a", "b"), value = c(1, 2))
  expect_invisible(validate_external_join_key(data, "id"))
})

test_that("validate_external_join_key() lehnt fehlende Schluesselspalten ab", {
  data <- data.frame(id = c("a", "b"), value = c(1, 2))
  expect_error(validate_external_join_key(data, "location"), "fehlen")
})

test_that("validate_external_join_key() lehnt fehlende Schluesselwerte ab", {
  data <- data.frame(id = c("a", NA), value = c(1, 2))
  expect_error(validate_external_join_key(data, "id"), "fehlende Werte")
})

test_that("enrich_with_external_features() bewahrt Reihenfolge und praefigiert Features", {
  base <- data.frame(id = c("b", "a"), target = c(0, 1))
  external <- data.frame(id = c("a", "b"), rainfall = c(10, 20))

  out <- enrich_with_external_features(base, external, by = "id")

  expect_equal(out$id, c("b", "a"))
  expect_equal(out$target, c(0, 1))
  expect_equal(out$ext_rainfall, c(20, 10))
})

test_that("enrich_with_external_features() lehnt doppelte externe Schluessel ab", {
  base <- data.frame(id = c("a", "b"), target = c(0, 1))
  external <- data.frame(id = c("a", "a"), rainfall = c(10, 20))

  expect_error(
    enrich_with_external_features(base, external, by = "id"),
    "many-to-many"
  )
})

test_that("enrich_with_external_features() lehnt Spaltenkollisionen ab", {
  base <- data.frame(id = c("a", "b"), ext_rainfall = c(1, 2))
  external <- data.frame(id = c("a", "b"), rainfall = c(10, 20))

  expect_error(
    enrich_with_external_features(base, external, by = "id"),
    "kollidieren"
  )
})

test_that("load_agridatasets_dataset() behandelt optionale Abhaengigkeit kontrolliert", {
  if (agridatasets_available("0.1.1")) {
    out <- load_agridatasets_dataset("idn_rice_farms")
    expect_true(is.data.frame(out))
    expect_true(all(c("status", "region") %in% names(out)))
  } else {
    expect_error(load_agridatasets_dataset("idn_rice_farms"), "Optionales Paket")
  }
})
