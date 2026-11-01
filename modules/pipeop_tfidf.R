# =====================================================================
# pipeop_tfidf.R -- foldsicherer TF-IDF-PipeOp fuer Freitext-Spalten
# =====================================================================
# Rohinput ist ein Text, keine Tabelle. Vokabular UND IDF-Gewichte sind
# gelernter Zustand - sie muessen INNERHALB jedes CV-Folds nur auf dem
# Trainingsteil gefittet werden, sonst sind sie von den Test-Texten
# mitbestimmt. Deshalb ein echter PipeOp (po("tfidf")) statt einer
# Vorberechnung ueber den ganzen Datensatz.
#
# Die Vokabular-Auswahl erfolgt nach Dokumenthaeufigkeit (label-frei), NICHT
# nach Spam-/Klassen-Trennschaerfe - eine labelbasierte Termauswahl waere ein
# Leck, wenn sie nicht ebenfalls im Fold laeuft.
#
# Ausgabe sind DICHTE numerische Spalten `tf_<term>` (mlr3-Tasks halten keine
# duennen Matrizen). Das ist der Engpass bei grossen Vokabularen: cv_glmnet auf
# 1000-3000 dichten Spalten brauchte ~5-12 Minuten je 5-fach-CV (siehe unten).
#
# Verwendung (Textspalte `text` bleibt als character-Feature im Task, der
# PipeOp entfernt sie und fuegt die tf_*-Spalten hinzu):
#   gl <- as_learner(po("tfidf", max_terms = 1000L) %>>%
#                    po("select", selector = selector_grep("^tf_")) %>>%
#                    lrn("classif.cv_glmnet", predict_type = "prob"))
#
# Parameter: text_col (Default "text"), max_terms (1000), min_doc_count (5),
# ngram_max (1; 2 = Uni+Bigramme).
#
# ADR-003: an 2 unabhaengigen Projekten bestaetigt, Modul unveraendert
# uebertragen - ML_Learning/uci-sms-spam-text (kurze SMS, 13 % Spam, AUC 0.986
# TF-IDF-only) und ML_Learning/text2vec-movie-review (lange Rezensionen,
# ausgewogen, AUC 0.9315 mit 3000 Termen uni+bigram -> glmnet). NICHT
# zurueckgefuehrt: handgemachte Textstatistiken (Laenge/Ziffern/Waehrung) -
# bei SMS stark (AUC 0.992 allein), bei Rezensionen wirkungslos (AUC 0.54),
# also domaenenspezifisch. Hinweis: bei SMS war TF-IDF (1000 Unigramme)
# ungetunt; Bigramme/groesseres Vokabular halfen bei Rezensionen (0.9195 ->
# 0.9315). Benoetigt das Paket text2vec (Suggests, nicht Imports).

suppressPackageStartupMessages({
  library(data.table)
  library(mlr3)
  library(mlr3pipelines)
  library(paradox)
})

PipeOpTfidf <- R6::R6Class("PipeOpTfidf",
  inherit = mlr3pipelines::PipeOpTaskPreproc,
  public = list(
    initialize = function(id = "tfidf", param_vals = list()) {
      ps <- paradox::ps(
        text_col = paradox::p_uty(default = "text", tags = c("train", "predict")),
        max_terms = paradox::p_int(lower = 10L, default = 1000L, tags = "train"),
        min_doc_count = paradox::p_int(lower = 1L, default = 5L, tags = "train"),
        ngram_max = paradox::p_int(lower = 1L, upper = 3L, default = 1L, tags = "train")
      )
      ps$values <- list(text_col = "text", max_terms = 1000L, min_doc_count = 5L, ngram_max = 1L)
      super$initialize(id, param_set = ps, param_vals = param_vals, packages = "text2vec")
    }
  ),
  private = list(
    .tokens = function(txt) {
      text2vec::itoken(tolower(txt), tokenizer = text2vec::word_tokenizer, progressbar = FALSE)
    },
    .make_features = function(task, vectorizer, tfidf, fit) {
      pv <- self$param_set$values
      txt <- task$data(cols = pv$text_col)[[pv$text_col]]
      dtm <- text2vec::create_dtm(private$.tokens(txt), vectorizer)
      m <- if (fit) tfidf$fit_transform(dtm) else tfidf$transform(dtm)
      m <- as.matrix(m)
      colnames(m) <- paste0("tf_", make.names(colnames(m), unique = TRUE))
      keep <- setdiff(task$feature_names, pv$text_col)
      task$select(keep)$cbind(data.table::as.data.table(m))
    },
    .train_task = function(task) {
      pv <- self$param_set$values
      txt <- task$data(cols = pv$text_col)[[pv$text_col]]
      vocab <- text2vec::create_vocabulary(private$.tokens(txt), ngram = c(1L, pv$ngram_max))
      vocab <- text2vec::prune_vocabulary(vocab, doc_count_min = pv$min_doc_count)
      if (nrow(vocab) > pv$max_terms) {
        vocab <- vocab[order(-vocab$doc_count), ][seq_len(pv$max_terms), ]
      }
      vectorizer <- text2vec::vocab_vectorizer(vocab)
      tfidf <- text2vec::TfIdf$new(norm = "l2")
      self$state <- list(vocab_size = nrow(vocab), vectorizer = vectorizer, tfidf = tfidf)
      private$.make_features(task, vectorizer, tfidf, fit = TRUE)
    },
    .predict_task = function(task) {
      private$.make_features(task, self$state$vectorizer, self$state$tfidf, fit = FALSE)
    }
  )
)

# Mehrfaches source() (z.B. aus zwei Skripten derselben R-Session) darf nicht
# mit "key already exists" abbrechen.
if (!"tfidf" %in% mlr3pipelines::mlr_pipeops$keys()) {
  mlr3pipelines::mlr_pipeops$add("tfidf", PipeOpTfidf)
}
