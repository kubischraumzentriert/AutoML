# =====================================================================
# test-pipeop_tfidf.R -- Korrektheitstests fuer PipeOpTfidf (pipeop_tfidf.R)
# =====================================================================
# Kernanforderung: Vokabular/IDF stammen NUR aus den Trainingstexten. Der
# Test baut ein Spielkorpus, in dem ein Wort ausschliesslich im Testteil
# vorkommt - es darf keine Spalte erzeugen.
skip_if_not_installed("text2vec")
source(testthat::test_path("..", "..", "modules", "pipeop_tfidf.R"))

toy_task <- function() {
  d <- data.table::data.table(
    text = c("win free cash now", "call me later", "free prize call now", "see you later",
             "zzzuniqueword appears only in test", "free cash prize"),
    target = factor(c("spam", "ham", "spam", "ham", "ham", "spam"))
  )
  mlr3::as_task_classif(d, target = "target", id = "toy")
}

test_that("Vokabular stammt nur aus dem Trainingsteil", {
  task <- toy_task()
  po_tf <- po("tfidf", min_doc_count = 1L, max_terms = 50L)
  out <- po_tf$train(list(task$clone()$filter(1:4)))[[1]]
  expect_false("tf_zzzuniqueword" %in% out$feature_names)
  expect_false("text" %in% out$feature_names)
  expect_gt(po_tf$state$vocab_size, 0)
})

test_that("predict() aendert den Zustand nicht und liefert dieselben Spalten", {
  task <- toy_task()
  po_tf <- po("tfidf", min_doc_count = 1L, max_terms = 50L)
  out_train <- po_tf$train(list(task$clone()$filter(1:4)))[[1]]
  size_before <- po_tf$state$vocab_size
  out_test <- po_tf$predict(list(task$clone()$filter(5:6)))[[1]]
  expect_identical(po_tf$state$vocab_size, size_before)
  expect_identical(sort(out_test$feature_names), sort(out_train$feature_names))
  expect_equal(out_test$nrow, 2L)
})

test_that("max_terms begrenzt das Vokabular, min_doc_count filtert seltene Terme", {
  task <- toy_task()
  capped <- po("tfidf", min_doc_count = 1L, max_terms = 10L)
  capped$train(list(task$clone()))
  expect_lte(capped$state$vocab_size, 10L)
  strict <- po("tfidf", min_doc_count = 3L, max_terms = 50L)
  strict$train(list(task$clone()))
  expect_lt(strict$state$vocab_size, 10L)
})

test_that("Bigramme erweitern das Vokabular", {
  task <- toy_task()
  uni <- po("tfidf", min_doc_count = 1L, max_terms = 100L, ngram_max = 1L)
  bi <- po("tfidf", min_doc_count = 1L, max_terms = 100L, ngram_max = 2L)
  uni$train(list(task$clone())); bi$train(list(task$clone()))
  expect_gt(bi$state$vocab_size, uni$state$vocab_size)
})

test_that("Pipeline laeuft in der Resampling-Schleife und lernt ein trennbares Signal", {
  set.seed(1)
  n <- 80
  spam <- paste("free cash prize", sample(c("now", "win", "claim"), n / 2, TRUE))
  ham <- paste("see you", sample(c("later", "tomorrow", "soon"), n / 2, TRUE))
  d <- data.table::data.table(text = c(spam, ham), target = factor(rep(c("spam", "ham"), each = n / 2)))
  task <- mlr3::as_task_classif(d, target = "target", id = "separable")
  gl <- mlr3::as_learner(
    po("tfidf", min_doc_count = 2L, max_terms = 50L) %>>%
      po("select", selector = selector_grep("^tf_")) %>>%
      mlr3::lrn("classif.rpart")
  )
  rr <- mlr3::resample(task, gl, mlr3::rsmp("cv", folds = 3))
  expect_gt(rr$aggregate(mlr3::msr("classif.bacc")), 0.95)
})

test_that("mehrfaches source() bricht nicht ab", {
  expect_silent(source(testthat::test_path("..", "..", "modules", "pipeop_tfidf.R")))
})
