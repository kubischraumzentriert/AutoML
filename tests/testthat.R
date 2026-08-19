# =====================================================================
# tests/testthat.R -- Test-Runner
# =====================================================================
# Kein echtes R-Paket (siehe DESCRIPTION) - testthat::test_check() setzt
# ein installierbares Paket voraus, funktioniert hier also nicht. Jede
# Testdatei sourced ihr Zielmodul stattdessen direkt ueber
# testthat::test_path("..", "..", "<modul>.R"). Aufruf vom Projekt-Root:
#   Rscript tests/testthat.R
library(testthat)

test_dir("tests/testthat", reporter = "summary")
