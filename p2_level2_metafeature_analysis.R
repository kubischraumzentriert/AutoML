# =====================================================================
# p2_level2_metafeature_analysis.R -- Research Aspect, 3. Schritt
# (2026-08-30): pruefen, ob einfache Datensatz-Metafeatures den
# gemischten Level-2-vs-bester-Wert-Befund (P2) erklaeren koennen -
# reine Nachanalyse, KEIN neuer Modell-Lauf.
# =====================================================================
# Kandidaten (aus der Diskussion in BACKLOG.md/PAPER_DRAFT.md Abschnitt
# 6): Datensatzgroesse, Klassenimbalance, effektive Zeilenzahl fuer die
# innere Modellwahl (Minderheitsklasse in `inner_tune` = 25% von
# outer_train), Streuung des Level2-Scores ueber die Outer-Folds
# (Instabilitaets-Proxy), und "Deckennaehe" (bisher bester Wert als
# Sättigungs-Proxy). Klassenverteilungen direkt aus den gespeicherten
# `task_train_small.rds`-Objekten gelesen (nicht aus dem Gedaechtnis
# geschaetzt), nicht aus einem neuen Modell-Training.
#
# ERGEBNIS: KEINE der 5 getesteten Metafeatures korreliert nennenswert
# mit dem Delta (alle |Spearman-rho| < 0.4, alle p > 0.49 bei n=6).
# Ein ehrliches Nullergebnis - nach Ausschluss von Groesse, Imbalance
# UND Tuning-Budget (siehe p2_level2_significance_test.R) bleibt das
# gemischte P2-Muster ohne einfache univariate Erklaerung.

datasets <- c("ilpd", "sick", "blood-transfusion", "cmc", "analcatdata-authorship", "optdigits")

n_total          <- c(583, 3772, 748, 1473, 841, 5620) # aus task_train_small.rds
minority_prop    <- c(0.2864, 0.0612, 0.2380, 0.2261, 0.0654, 0.0986) # aus task_train_small.rds
sd_score_level2  <- c(0.0510, 0.0181, 0.0493, 0.0235, 0.0044, 0.0036) # level2_workflow @10 Evals, aus den v3-Summary-CSVs
best_prior       <- c(0.6840, 0.9714, 0.6576, 0.5374, 0.9921, 0.9840) # "Deckennaehe"-Proxy
delta            <- c(-0.0367, 0.0009, 0.0302, -0.0261, -0.0190, 0.0019) # Level2@10 - bisher bester Wert (Zielsignal)

n_inner_tune        <- round(n_total * (2 / 3) * 0.25) # ~outer_train * inner_split_ratio(0.25)
minority_inner_tune <- round(minority_prop * n_inner_tune)

df <- data.frame(datasets, n_total, minority_prop, n_inner_tune, minority_inner_tune,
                  sd_score_level2, best_prior, delta)
cat("=== Datensatz-Metafeatures + Zielsignal ===\n")
print(df)

cat("\n=== Spearman-Korrelationen mit delta (n=6, rein explorativ) ===\n")
for (col in c("n_total", "minority_prop", "minority_inner_tune", "sd_score_level2", "best_prior")) {
  ct <- suppressWarnings(cor.test(df[[col]], df$delta, method = "spearman"))
  cat(sprintf("%-22s rho = %6.3f   p = %.3f\n", col, ct$estimate, ct$p.value))
}
