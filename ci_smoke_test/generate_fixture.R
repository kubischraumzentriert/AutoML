# =====================================================================
# generate_fixture.R -- erzeugt einen deterministischen, synthetischen
# Trainingsdatensatz fuer den CI-Smoke-Test (siehe TARGETS.md).
# =====================================================================
# Bewusst SYNTHETISCH statt eines echten/heruntergeladenen Datensatzes:
# kein Netzwerkzugriff in CI (kein OpenML-Download, keine Flakiness/Rate-
# Limits), voll reproduzierbar (fester Seed), und klein genug fuer einen
# schnellen Smoke-Test. 3 Klassen, 8 numerische + 2 kategoriale Features,
# eine Mischung aus informativen und Rausch-Spalten - genug Struktur, damit
# LDA/Multinom/Ranger/LightGBM sich sinnvoll unterscheiden koennen, ohne
# dass die tatsaechliche Modellqualitaet fuer den Smoke-Test eine Rolle
# spielt (es geht nur darum, ob die Skripte fehlerfrei durchlaufen).
suppressPackageStartupMessages(library(data.table))

set.seed(42)
n <- 800

x1 <- rnorm(n); x2 <- rnorm(n); x3 <- rnorm(n); x4 <- rnorm(n)
x5 <- rnorm(n); x6 <- rnorm(n); x7 <- rnorm(n); x8 <- rnorm(n)
cat1 <- sample(c("a", "b", "c"), n, replace = TRUE)
cat2 <- sample(c("low", "mid", "high"), n, replace = TRUE, prob = c(0.5, 0.3, 0.2))

# WICHTIG: cut() auf GENAU demselben Vektor anwenden, aus dem die Grenzen
# berechnet wurden. Eine erste Version berechnete die Grenzen aus dem
# rauschfreien "score", wandte cut() aber auf "score + Rauschen" an - dabei
# fiel gelegentlich ein verrauschter Wert ausserhalb der Grenzen und wurde
# zu NA, was beim CSV-Rundweg (fwrite/fread) zu einer eigenen leeren
# Faktorstufe mit n=1 wurde. Genau diese Rand-Stufe liess classif.ranger in
# 030_baseline.R mit "Indizierung ausserhalb der Grenzen" abstuerzen (siehe
# TARGETS.md fuer die volle Fehlersuche - ausgeloest durch den Bug hier,
# nicht durch ein Template-Problem an sich).
score <- 1.2 * x1 - 0.9 * x2 + 0.6 * x3 * x4 + rnorm(n, sd = 0.8)
target <- cut(score, breaks = quantile(score, probs = c(0, 1/3, 2/3, 1)),
              labels = c("low", "mid", "high"), include.lowest = TRUE)

dt <- data.table(
  id = seq_len(n), x1 = x1, x2 = x2, x3 = x3, x4 = x4, x5 = x5, x6 = x6, x7 = x7, x8 = x8,
  cat1 = cat1, cat2 = cat2, target = as.character(target)
)

# Sicherheitschecks: kein NA im Ziel (siehe Kommentar oben), und jede
# (Zielklasse, Faktorstufe)-Zelle ausreichend besetzt (sonst kann ein
# 80/20-Split leere Zellen erzeugen) - bricht die Fixture-Erzeugung lieber
# sofort ab, als still eine instabile Fixture zu erzeugen.
stopifnot("NA im Ziel - cut()-Grenzen pruefen" = !anyNA(dt$target))
min_cell <- min(table(dt$target, dt$cat1), table(dt$target, dt$cat2))
stopifnot("Zu duenn besetzte (Zielklasse, Faktorstufe)-Zelle - n erhoehen" = min_cell >= 20)

# Laeuft mit ci_smoke_test/ als Arbeitsverzeichnis (gleiche Konvention wie
# alle nummerierten Pipeline-Skripte - project_dir = cwd).
fwrite(dt, "train.csv")

cat("=== CI-Fixture erzeugt ===\n")
cat("Zeilen:", nrow(dt), " Spalten:", ncol(dt), "\n")
cat("Klassenverteilung:\n"); print(table(dt$target))
