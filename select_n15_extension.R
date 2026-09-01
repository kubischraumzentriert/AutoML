rm(list = ls())
# =====================================================================
# select_n15_extension.R -- "Weg B", 2. Tranche: Erweiterung des
# externen Benchmark-Sets von n=10 auf n=15 (siehe EXTERNAL_BENCHMARK_
# SET.md und BACKLOG.md, Nutzeranweisung 2026-09-01 "n=10 auf n=15
# erweitern").
# =====================================================================
# Repliziert EXAKT dieselbe Methodik wie die 1. Weg-B-Tranche
# (select_weg_b_extension.R): OpenML-CC18 (Studie 99), 500<=Instanzen
# <=20000, Features<=100, 2<=Klassen<=10, NICHT bereits im Template ODER
# in einem der bestehenden 10 externen Datensaetze verwendet.
# Deterministisch, NEUER Seed (Datum dieser Ziehung, 20260901), keine
# Performance-Kennzahl vor der Ziehung eingesehen.

suppressPackageStartupMessages({ library(mlr3oml); library(data.table) })

meta <- fread("_artifacts/cc18_full_metadata.csv")
if (nrow(meta) == 0) stop("cc18_full_metadata.csv leer/fehlt - zuerst select_weg_b_extension.R erneut laufen lassen.")
cat(sprintf("Metadaten aus vorheriger Ziehung wiederverwendet (%d Tasks).\n", nrow(meta)))

already_used_names <- c(
  "credit-g", "satimage", "steel-plates-fault", "bank-marketing", "adult",
  "diabetes", "wdbc",
  "cmc", "optdigits", "sick", "analcatdata_authorship",
  "blood-transfusion-service-center", "ilpd",
  "PhishingWebsites", "qsar-biodeg", "mfeat-karhunen", "eucalyptus"
)

eligible <- meta[
  n_instances >= 500 & n_instances <= 20000 &
  n_features <= 100 &
  n_classes >= 2 & n_classes <= 10 &
  !(name %in% already_used_names)
]
cat(sprintf("\nZulaessiger Pool nach Kriterien (ohne die bereits verwendeten %d Namen): %d Datensaetze.\n",
            length(already_used_names), nrow(eligible)))

eligible[, category := ifelse(n_classes == 2, "binary", "multiclass")]
cat("Davon binaer:", sum(eligible$category == "binary"), " | multiclass:", sum(eligible$category == "multiclass"), "\n")

set.seed(20260901)
n_binary_draw <- 3L
n_multiclass_draw <- 2L
drawn_binary <- eligible[category == "binary"][sample(.N, n_binary_draw)]
drawn_multiclass <- eligible[category == "multiclass"][sample(.N, n_multiclass_draw)]
drawn <- rbind(drawn_binary, drawn_multiclass)

cat("\n=== Gezogene n=15-Erweiterung (5 neue Datensaetze) ===\n")
print(drawn[, .(data_id, name, n_instances, n_features, n_classes, category)])

fwrite(drawn, "_artifacts/n15_extension_selection.csv")
cat("\nGespeichert: _artifacts/n15_extension_selection.csv (EINGEFROREN - vor jeder Ergebnisberechnung)\n")
