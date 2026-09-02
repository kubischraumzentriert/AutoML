rm(list = ls())
# =====================================================================
# select_weg_b_extension.R -- P1-Rest ("Weg B"): Erweiterung des
# eingefrorenen externen Benchmark-Sets von n=6 auf n=10 (siehe
# docs/research/EXTERNAL_BENCHMARK_SET.md und BACKLOG.md, Nutzerentscheidung
# 2026-08-31 "erst Weg A", jetzt "+4 neue (n=10 insgesamt)").
# =====================================================================
# Repliziert EXAKT dieselbe Methodik wie die urspruengliche 6er-Auswahl
# (siehe docs/research/EXTERNAL_BENCHMARK_SET.md "Einschlusskriterien"/"Auswahl-
# mechanismus"): OpenML-CC18 (Studie 99), 500<=Instanzen<=20000,
# Features<=100, 2<=Klassen<=10, NICHT bereits im Template verwendet -
# UND JETZT ZUSAETZLICH nicht bereits eines der bestehenden 6 externen
# Datensaetze. Deterministisch, 2 binaer + 2 multiclass (dieselbe leichte
# Strukturierung wie beim Original), NEUER Seed (Datum dieser Ziehung,
# 20260831 - nicht derselbe wie beim Original, da derselbe Seed auf dem
# UM 6 Kandidaten reduzierten Pool ein anderes Ergebnis liefern wuerde
# als eine echte Fortsetzung der urspruenglichen Ziehung - siehe
# Kopfkommentar unten fuer die genaue Begruendung). KEINE Performance-
# Kennzahl wird vor dieser Ziehung eingesehen.

suppressPackageStartupMessages({ library(mlr3oml); library(data.table) })

cat("Lade OpenML-CC18-Studie (ID 99) ...\n")
study <- ocl(99)
task_ids <- study$task_ids
cat(sprintf("CC18 enthaelt %d Tasks.\n", length(task_ids)))

# Metadaten je Task/Datensatz abrufen (Instanzen/Features/Klassen) - bewusst
# NUR ueber die von OpenML selbst vorberechneten "qualities" (leichtgewichtige
# JSON-Abfrage), NICHT ueber $data()/$feature_names (wuerde bei grossen
# Datensaetzen wie CIFAR_10/Fashion-MNIST/mnist_784 einen vollstaendigen
# ARFF-Download ausloesen, unnoetig teuer nur fuer 3 Metadatenwerte).
meta <- rbindlist(lapply(task_ids, function(tid) {
  tryCatch({
    task_meta <- otsk(tid)
    did <- task_meta$data_id
    data_meta <- odt(did)
    q <- data_meta$qualities
    get_q <- function(nm) {
      v <- q[q$name == nm, "value"][[1]]
      if (length(v) == 0) NA_real_ else as.numeric(v)
    }
    list(
      task_id = tid, data_id = did, name = data_meta$name,
      n_instances = get_q("NumberOfInstances"),
      n_features = get_q("NumberOfFeatures") - 1,  # OpenML zaehlt die Zielspalte mit
      n_classes = get_q("NumberOfClasses")
    )
  }, error = function(e) NULL)
}), fill = TRUE)

fwrite(meta, "_artifacts/cc18_full_metadata.csv")
cat(sprintf("Metadaten fuer %d/%d Tasks erfolgreich geladen, gespeichert unter _artifacts/cc18_full_metadata.csv\n",
            nrow(meta), length(task_ids)))

# Bereits verwendet (im Template ODER in den bestehenden 6 externen Datensaetzen).
already_used_names <- c(
  "credit-g", "satimage", "steel-plates-fault", "bank-marketing", "adult",
  "diabetes", "wdbc",
  "cmc", "optdigits", "sick", "analcatdata_authorship",
  "blood-transfusion-service-center", "ilpd"
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
cat("\nDavon binaer:", sum(eligible$category == "binary"), " | multiclass:", sum(eligible$category == "multiclass"), "\n")

set.seed(20260831)
n_binary_draw <- 2L
n_multiclass_draw <- 2L
drawn_binary <- eligible[category == "binary"][sample(.N, n_binary_draw)]
drawn_multiclass <- eligible[category == "multiclass"][sample(.N, n_multiclass_draw)]
drawn <- rbind(drawn_binary, drawn_multiclass)

cat("\n=== Gezogene Weg-B-Erweiterung (4 neue Datensaetze) ===\n")
print(drawn[, .(data_id, name, n_instances, n_features, n_classes, category)])

fwrite(drawn, "_artifacts/weg_b_extension_selection.csv")
cat("\nGespeichert: _artifacts/weg_b_extension_selection.csv (EINGEFROREN - vor jeder Ergebnisberechnung)\n")
