# Pure helpers for paired LightGBM seed/thread checks.

lightgbm_seed_thread_grid <- function(seeds, threads) {
  if (!length(seeds) || anyNA(seeds) || any(!is.finite(seeds))) {
    stop("seeds must be finite numeric values.", call. = FALSE)
  }
  if (!length(threads) || anyNA(threads) || any(!is.finite(threads)) ||
      any(threads < 1) || any(threads != as.integer(threads))) {
    stop("threads must be positive integer values.", call. = FALSE)
  }
  expand.grid(seed = as.integer(seeds), num_threads = as.integer(threads),
              KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE)
}

paired_seed_thread_summary <- function(results, metric_name) {
  required <- c("seed", "num_threads", metric_name)
  missing <- setdiff(required, names(results))
  if (length(missing)) stop("Missing result columns: ", paste(missing, collapse = ", "), call. = FALSE)
  if (anyDuplicated(as.data.frame(results)[c("seed", "num_threads")])) {
    stop("Each seed/thread pair must occur exactly once.", call. = FALSE)
  }
  counts <- table(results$seed)
  if (any(counts != 2L)) stop("Each seed must have exactly two thread settings.", call. = FALSE)
  data.table::rbindlist(lapply(split(results, results$seed), function(rows) {
    if (length(unique(rows$num_threads)) != 2L) return(NULL)
    ordered <- rows[order(rows$num_threads), ]
    data.table::data.table(
      seed = ordered$seed[[1]],
      threads_low = ordered$num_threads[[1]],
      threads_high = ordered$num_threads[[2]],
      score_low = ordered[[metric_name]][[1]],
      score_high = ordered[[metric_name]][[2]],
      delta_high_minus_low = ordered[[metric_name]][[2]] - ordered[[metric_name]][[1]]
    )
  }), fill = TRUE)
}

summarize_seed_thread_check <- function(results, metric_name) {
  paired <- paired_seed_thread_summary(results, metric_name)
  data.table::data.table(
    metric = metric_name,
    n_runs = nrow(results),
    n_seeds = length(unique(results$seed)),
    threads = paste(sort(unique(results$num_threads)), collapse = ","),
    mean_score = mean(results[[metric_name]]),
    sd_score = stats::sd(results[[metric_name]]),
    mean_paired_delta_high_minus_low = if (nrow(paired)) mean(paired$delta_high_minus_low) else NA_real_,
    sd_paired_delta_high_minus_low = if (nrow(paired)) stats::sd(paired$delta_high_minus_low) else NA_real_
  )
}
