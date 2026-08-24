rm(list = ls())

suppressPackageStartupMessages({
  library(DBI)
  library(RSQLite)
  library(uuid)
})

project_dir <- normalizePath(".")
source("000_config.R")
source(file.path(project_dir, "db_logging.R"))

con <- db_connect()
on.exit(DBI::dbDisconnect(con), add = TRUE)

upsert_source <- function(key, title, year, source_type, url, benchmark_suite = NA_character_, notes = NA_character_) {
  existing <- dbGetQuery(con, "SELECT lsrc_id FROM literature_source WHERE lsrc_key = ?", params = list(key))
  if (nrow(existing) > 0) {
    dbExecute(
      con,
      paste(
        "UPDATE literature_source",
        "SET lsrc_title = ?, lsrc_year = ?, lsrc_source_type = ?, lsrc_url = ?,",
        "lsrc_benchmark_suite = ?, lsrc_notes = ?",
        "WHERE lsrc_key = ?"
      ),
      params = list(title, year, source_type, url, benchmark_suite, notes, key)
    )
    return(existing$lsrc_id[1])
  }

  id <- uuid::UUIDgenerate()
  dbExecute(
    con,
    paste(
      "INSERT INTO literature_source",
      "(lsrc_id, lsrc_key, lsrc_title, lsrc_year, lsrc_source_type, lsrc_url, lsrc_benchmark_suite, lsrc_notes)",
      "VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    ),
    params = list(id, key, title, year, source_type, url, benchmark_suite, notes)
  )
  id
}

upsert_result <- function(source_id, key, dataset_name, method, metric_name, metric_value,
                          metric_direction, result_kind, comparability,
                          openml_task_id = NA_integer_, openml_dataset_id = NA_integer_,
                          rank = NA_real_, time_budget_minutes = NA_real_,
                          resampling = NA_character_, notes = NA_character_) {
  existing <- dbGetQuery(con, "SELECT lres_id FROM literature_benchmark_result WHERE lres_key = ?", params = list(key))
  params <- list(
    source_id, dataset_name, openml_task_id, openml_dataset_id, method, metric_name,
    metric_value, metric_direction, rank, time_budget_minutes, resampling,
    result_kind, comparability, notes, key
  )
  if (nrow(existing) > 0) {
    dbExecute(
      con,
      paste(
        "UPDATE literature_benchmark_result",
        "SET lres_source_id = ?, lres_dataset_name = ?, lres_openml_task_id = ?,",
        "lres_openml_dataset_id = ?, lres_method = ?, lres_metric_name = ?,",
        "lres_metric_value = ?, lres_metric_direction = ?, lres_rank = ?,",
        "lres_time_budget_minutes = ?, lres_resampling = ?, lres_result_kind = ?,",
        "lres_comparability = ?, lres_notes = ?, lres_recorded_at = datetime('now')",
        "WHERE lres_key = ?"
      ),
      params = params
    )
    return(invisible(existing$lres_id[1]))
  }

  id <- uuid::UUIDgenerate()
  dbExecute(
    con,
    paste(
      "INSERT INTO literature_benchmark_result",
      "(lres_id, lres_source_id, lres_key, lres_dataset_name, lres_openml_task_id,",
      "lres_openml_dataset_id, lres_method, lres_metric_name, lres_metric_value,",
      "lres_metric_direction, lres_rank, lres_time_budget_minutes, lres_resampling,",
      "lres_result_kind, lres_comparability, lres_notes)",
      "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
    ),
    params = list(
      id, source_id, key, dataset_name, openml_task_id, openml_dataset_id,
      method, metric_name, metric_value, metric_direction, rank,
      time_budget_minutes, resampling, result_kind, comparability, notes
    )
  )
  invisible(id)
}

src_sota2 <- upsert_source(
  "sota2_automl39_2026",
  "SOTA2: Tabular Classification on AutoML Benchmark (39 datasets)",
  2026,
  "benchmark_page",
  "https://www.sota2.com/research/sota/tabular-classification-on-automl-benchmark-39-datasets-test",
  "OpenML AutoML Benchmark, 39 datasets",
  "Leaderboard summary crawled 2026-08-24; context only because exact splits/tool versions must be checked before direct comparison."
)

src_fedot <- upsert_source(
  "fedot_tabular_benchmark_docs",
  "FEDOT documentation: Tabular data benchmark table",
  2024,
  "documentation",
  "https://fedot.readthedocs.io/en/yadf/benchmarks/tabular.html",
  "OpenML tabular classification suite",
  "Documentation table with F1 scores for several AutoML frameworks; useful dataset/context layer, not local evidence."
)

src_ag_docs <- upsert_source(
  "autogluon_tabular_quickstart_docs",
  "AutoGluon Tabular Quick Start leaderboard example",
  2026,
  "documentation",
  "https://auto.gluon.ai/stable/tutorials/tabular/tabular-quick-start.html",
  "AutoGluon documentation knot_theory example",
  "Example leaderboard from official AutoGluon docs; not a literature benchmark but useful schema smoke-data."
)

src_tabrepo <- upsert_source(
  "tabrepo_2024",
  "TabRepo: A Large Scale Repository of Tabular Model Evaluations and its AutoML Applications",
  2024,
  "paper",
  "https://proceedings.mlr.press/v256/salinas24a.html",
  "TabRepo / TabArena",
  "Paper/source for repository-style tabular model evaluation; seed rows below only store metadata, not the full 200-dataset result corpus."
)

src_tabpfn <- upsert_source(
  "tabpfn_nature_2025",
  "Accurate predictions on small data with a tabular foundation model",
  2025,
  "paper",
  "https://www.nature.com/articles/s41586-024-08328-6",
  "Small-to-medium tabular classification/regression benchmarks",
  "Nature TabPFN paper; aggregate claims are context only unless exact benchmark tables are imported later."
)

src_automlbench_datasets <- upsert_source(
  "automlbench_100_datasets",
  "AutoMLBench benchmark dataset overview",
  2026,
  "benchmark_page",
  "https://datasystemsgrouput.github.io/AutoMLBench/datasets.html",
  "AutoMLBench 100 OpenML datasets",
  "Dataset metadata table; imported only for dataset IDs and dimensions."
)

src_alex_automl_benchmark <- upsert_source(
  "alex_automl_benchmark_binary",
  "AutoML Benchmark binary-classification ranking",
  2019,
  "repository",
  "https://github.com/alex-lekov/automl-benchmark",
  "Binary classification benchmark on OpenML datasets",
  "External benchmark ranking table; context only because benchmark implementation and versioning differ from local mlr3 runs."
)

openml_dataset_ids <- c(
  adult = 179L,
  amazon_employee_access = 4135L,
  `bank-marketing` = 1461L,
  `credit-g` = 31L
)

automl39 <- data.frame(
  method = c("AutoGluon", "H2O AutoML", "auto-sklearn", "GCP-Tables", "TPOT", "Auto-WEKA"),
  avg_rank = c(1.5455, 3.1818, 3.7273, 2.8182, 4.0909, 5.6364),
  avg_rescaled_loss = c(0.0474, 0.1914, 0.2176, 0.2010, 0.2900, 0.9383),
  champions = c(19, 5, 4, 5, 4, 2)
)
for (i in seq_len(nrow(automl39))) {
  row <- automl39[i, ]
  method_key <- gsub("[^a-z0-9]+", "_", tolower(row$method))
  upsert_result(
    src_sota2, paste0("sota2_automl39_", method_key, "_avg_rank"),
    "AutoML Benchmark 39 datasets", row$method, "avg_rank", row$avg_rank,
    "rank", "leaderboard_summary", "context_only",
    time_budget_minutes = 60,
    notes = "Lower is better; SOTA2 leaderboard summary."
  )
  upsert_result(
    src_sota2, paste0("sota2_automl39_", method_key, "_avg_rescaled_loss"),
    "AutoML Benchmark 39 datasets", row$method, "avg_rescaled_loss", row$avg_rescaled_loss,
    "minimize", "leaderboard_summary", "context_only",
    time_budget_minutes = 60,
    notes = "Lower is better; SOTA2 leaderboard summary."
  )
  upsert_result(
    src_sota2, paste0("sota2_automl39_", method_key, "_champions"),
    "AutoML Benchmark 39 datasets", row$method, "champion_count", row$champions,
    "count", "leaderboard_summary", "context_only",
    time_budget_minutes = 60,
    notes = "Count of champion datasets reported by SOTA2 leaderboard."
  )
}

fedot_scores <- data.frame(
  dataset = rep(c("adult", "amazon_employee_access", "bank-marketing", "credit-g"), each = 4),
  method = rep(c("FEDOT", "AutoGluon", "H2O", "TPOT"), times = 4),
  f1 = c(
    0.874, 0.874, 0.875, 0.874,
    0.949, 0.947, 0.951, 0.953,
    0.910, 0.910, 0.910, 0.899,
    0.753, 0.759, 0.766, 0.727
  )
)
for (i in seq_len(nrow(fedot_scores))) {
  row <- fedot_scores[i, ]
  upsert_result(
    src_fedot,
    paste0("fedot_docs_", row$dataset, "_", gsub("[^a-z0-9]+", "_", tolower(row$method)), "_f1"),
    row$dataset, row$method, "f1", row$f1,
    "maximize", "dataset_score", "context_only",
    openml_dataset_id = unname(openml_dataset_ids[[row$dataset]]),
    resampling = "10 folds according to documentation table",
    notes = "Documentation benchmark table; direct comparability to local mlr3 results is not guaranteed."
  )
}

automlbench_dataset_meta <- data.frame(
  dataset = c("adult", "Amazon_employee_access", "bank-marketing", "credit-g"),
  openml_dataset_id = c(179L, 4135L, 1461L, 31L),
  n_features = c(14, 9, 16, 20),
  n_rows = c(48842, 32769, 45211, 1000),
  stringsAsFactors = FALSE
)
for (i in seq_len(nrow(automlbench_dataset_meta))) {
  row <- automlbench_dataset_meta[i, ]
  dataset_key <- gsub("[^a-z0-9]+", "_", tolower(row$dataset))
  upsert_result(
    src_automlbench_datasets,
    paste0("automlbench_dataset_", dataset_key, "_n_features"),
    row$dataset, "dataset_metadata", "n_features", row$n_features,
    "count", "metadata_only", "context_only",
    openml_dataset_id = row$openml_dataset_id,
    notes = "AutoMLBench dataset overview table."
  )
  upsert_result(
    src_automlbench_datasets,
    paste0("automlbench_dataset_", dataset_key, "_n_rows"),
    row$dataset, "dataset_metadata", "n_rows", row$n_rows,
    "count", "metadata_only", "context_only",
    openml_dataset_id = row$openml_dataset_id,
    notes = "AutoMLBench dataset overview table."
  )
}

alex_binary_rank <- data.frame(
  method = c("AutoML_Alex", "AutoGluon", "H2O", "CatBoost", "Auto_ml", "auto-sklearn", "LightGBM", "TPOT"),
  reverse_position_sum = c(79, 74, 54, 52, 41, 37, 36, 23),
  stringsAsFactors = FALSE
)
for (i in seq_len(nrow(alex_binary_rank))) {
  row <- alex_binary_rank[i, ]
  method_key <- gsub("[^a-z0-9]+", "_", tolower(row$method))
  upsert_result(
    src_alex_automl_benchmark,
    paste0("alex_binary_", method_key, "_reverse_position_sum"),
    "Binary classification benchmark datasets", row$method, "reverse_position_sum", row$reverse_position_sum,
    "maximize", "leaderboard_summary", "context_only",
    notes = "Repository benchmark table: sum of reverse positions over binary classification datasets."
  )
}

ag_example <- data.frame(
  method = c("WeightedEnsemble_L2", "LightGBM", "LightGBMLarge", "CatBoost", "RandomForestEntr", "XGBoost"),
  accuracy = c(0.9462, 0.9456, 0.9444, 0.9432, 0.9384, 0.9380)
)
for (i in seq_len(nrow(ag_example))) {
  row <- ag_example[i, ]
  upsert_result(
    src_ag_docs,
    paste0("autogluon_docs_knot_theory_", tolower(row$method), "_accuracy"),
    "knot_theory", row$method, "accuracy", row$accuracy,
    "maximize", "dataset_score", "context_only",
    notes = "Official AutoGluon quickstart leaderboard example."
  )
}

upsert_result(
  src_tabrepo,
  "tabrepo_2024_repository_metadata",
  "TabRepo/TabArena repository contexts", "TabRepo", "dataset_count_reported", 200,
  "count", "metadata_only", "context_only",
  notes = "Paper context: large repository of model predictions/metrics; import full result corpus separately if needed."
)

upsert_result(
  src_tabpfn,
  "tabpfn_2025_classification_speedup_claim",
  "TabPFN classification benchmark aggregate", "TabPFN", "reported_classification_speedup_vs_tuned_baselines", 5140,
  "count", "aggregate_score", "context_only",
  notes = "Aggregate speedup claim from abstract; not a per-dataset score."
)

summary <- dbGetQuery(con, "
  SELECT lsrc_key, COUNT(*) AS n_results
  FROM v_literature_benchmark_results
  GROUP BY lsrc_key
  ORDER BY lsrc_key
")

cat("Literatur-/Benchmarkwerte importiert/aktualisiert:\n")
print(summary, row.names = FALSE)
