# =====================================================================
# task_data_coercion.R -- gemeinsame Rohdaten-Vorbereitung fuer
# mlr3-Classif-Tasks (id-Spalte entfernen, Date/IDate/POSIXct ->
# numerisch, character -> Faktor, Zielspalte -> Faktor). Extrahiert aus
# 4 Diagnose-Skripten (015-018), die denselben Coercion-Block wortgleich
# enthielten (Clean-Code-Review 2026-09-19).
# =====================================================================
# Dabei ein echter Fund: 016/017/018 entfernten id_col NICHT vor dem
# Task-Bau (anders als 015) - "id" wurde dadurch als bedeutungsloses
# numerisches Feature mittrainiert (bei 016, Feature-Importance-
# Stabilitaet, haette das sogar in der Importance-Rangfolge auftauchen
# koennen). Hier korrekt vereinheitlicht: id_col wird IMMER entfernt,
# bevor der Task gebaut wird.
#
# mlr3-Tasks unterstuetzen weder Date-/POSIXct- noch reine character-
# Spalten - Datumsspalten werden numerisch (Tage/Sekunden seit Epoch)
# statt fallengelassen (ein Datum kann selbst leak-relevant sein, siehe
# 015_target_leak_audit.R), character-Spalten werden zu Faktoren. Die
# Zielspalte wird immer als Faktor behandelt, unabhaengig von ihrem
# Ausgangstyp.
#
# `id_col` kann ein Vektor sein (any(), analog zu 015/020_task.R - z.B.
# um neben der reinen ID auch eine Hilfsspalte wie einen Zeit-Block-
# Index auszuschliessen). Aendert `dt` IN-PLACE (data.table-Konvention
# wie der Rest des Templates) und gibt sie zusaetzlich unsichtbar zurueck.
prepare_classif_task_data <- function(dt, target_col, id_col = NULL) {
  if (!is.null(id_col) && any(id_col %in% names(dt))) {
    dt[, (id_col) := NULL]
  }

  date_cols <- names(dt)[vapply(dt, function(x) inherits(x, c("Date", "IDate", "POSIXct")), logical(1))]
  dt[, (date_cols) := lapply(.SD, as.numeric), .SDcols = date_cols]

  char_cols <- setdiff(names(dt)[vapply(dt, is.character, logical(1))], target_col)
  dt[, (char_cols) := lapply(.SD, as.factor), .SDcols = char_cols]

  dt[, (target_col) := as.factor(get(target_col))]
  invisible(dt)
}
