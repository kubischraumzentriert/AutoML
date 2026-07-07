rm(list = ls())

suppressPackageStartupMessages({
  library(data.table)
  library(tidyverse)
  library(skimr)
})

source("000_config.R")

set.seed(seed)

train <- fread(train_path)
test <- fread(test_path)

# Fuer den ersten Ueberblick arbeiten wir nur mit 10% der Trainingsdaten.
# Inhaltliche Transformationen kommen spaeter in die mlr3-Pipeline.
train_small <- train %>%
  as_tibble() %>%
  group_by(.data[[target_col]]) %>%
  slice_sample(prop = subset_fraction) %>%
  ungroup() %>%
  select(-all_of(id_col)) %>%
  mutate(!!target_col := as.factor(.data[[target_col]]))

cat("=== Datengroessen ===\n")
cat("Train voll:", nrow(train), "Zeilen,", ncol(train), "Spalten\n")
cat("Train 10% :", nrow(train_small), "Zeilen,", ncol(train_small), "Spalten\n")
cat("Test voll :", nrow(test), "Zeilen,", ncol(test), "Spalten\n\n")

cat("=== Zielvariable im 10%-Subset ===\n")
train_small %>%
  count(.data[[target_col]], sort = TRUE) %>%
  print()
cat("\n")

cat("=== skimr Summary fuer das 10%-Subset ===\n")
train_small %>%
  skim() %>%
  print()
