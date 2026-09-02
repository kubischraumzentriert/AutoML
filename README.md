# MLR3 Classification AutoML Template

[![CI Smoke Test](https://github.com/kubischraumzentriert/AutoML/actions/workflows/ci-smoke-test.yml/badge.svg)](https://github.com/kubischraumzentriert/AutoML/actions/workflows/ci-smoke-test.yml)

Ein wiederverwendbares `mlr3`-AutoML-Template für Kaggle-/Zindi-/OpenML-
Klassifikationsaufgaben (R). Kein Einzelprojekt, sondern eine Methodik, die
über inzwischen mehr als 15 unabhängige Projekte (Kaggle, Zindi,
DrivenData, OpenML) hinweg gehärtet wurde.

## Los geht's (Start Here)

Dieses Repository ist selbst kein leeres Template, sondern ein
**vollständig durchgespieltes Beispielprojekt**: `train.csv`/`test.csv`/
`sample_submission.csv` sowie `000_config.R` gehören zu einem echten,
abgeschlossenen Kaggle-Wettbewerb (`health_condition`, Playground Series
S6E7). Wer das Template kennenlernen will, klont das Repo und probiert es
zuerst genau **so** aus, bevor er es auf ein eigenes Projekt überträgt:

1. **Umgebung einrichten**: R (aktuelle Release-Version) + Pakete aus
   `DESCRIPTION` installieren - der exakte, in CI verifizierte Referenzpfad
   steht in [`ENVIRONMENT.md`](ENVIRONMENT.md) (`r-lib/actions/setup-r-dependencies`
   liest `DESCRIPTION` automatisch; manuell reicht z.B.
   `pak::pak(gsub("\n", "", readLines("DESCRIPTION")))` oder einfach jedes
   fehlende Paket beim ersten Skriptlauf einzeln nachinstallieren).
2. **Test-Suite laufen lassen**, um die Installation zu prüfen:
   `Rscript tests/testthat.R` (sollte grün sein - derselbe Befehl läuft
   auch in CI, siehe Badge oben).
3. **Einen einzelnen Baustein ausführen**, um das Muster zu sehen, z.B.
   `Rscript 015_target_leak_audit.R` oder `Rscript 030_baseline.R` -
   jedes nummerierte Skript ist eigenständig lauffähig und schreibt seine
   Ergebnisse nach `_artifacts/`.
4. **Den kompletten Workflow nachvollziehen**: entweder Schritt für
   Schritt in der R-Konsole (Kochbuch mit erwarteten Ausgaben:
   [`WorkflowDescription.md`](WorkflowDescription.md)) oder automatisiert
   über `targets` (`tar_make()`, siehe [`TARGETS.md`](TARGETS.md) für
   Befehlsübersicht und Caching-Modell).
5. **Auf ein eigenes Projekt übertragen**: [`TARGETS.md`](TARGETS.md)s
   Abschnitt "Checkliste: Übertragung auf einen neuen Kaggle-Wettbewerb"
   (kurz) bzw. [`WorkflowDescription.md`](WorkflowDescription.md) (mit
   Beispielbefehlen und Entscheidungsregeln pro Schritt) - im Kern: eigene
   `train.csv`/`test.csv` einsetzen, `000_config.R` neu befüllen
   (`target_col`, Zielmetrik, Feature-Familien), Rest der Pipeline bleibt
   strukturell gleich.

Fragen oder Probleme dabei? [`CONTRIBUTING.md`](CONTRIBUTING.md)
beschreibt, wie Bug-Reports/Support-Anfragen in der Praxis gehandhabt
werden (GitHub Issues als einziger Kanal).

## Warum dieses Template anders ist

Die meisten Kaggle-Repos zeigen einen Score. Dieses hier zeigt, **wie**
Entscheidungen zustande kommen, und macht sie nachprüfbar:

- **Nichts wird ungeprüft übernommen.** Jedes neue Diagnose-Modul (z.B.
  Generalisierungslücke, Split-Size-Sensitivität, Seed-Stabilität) muss
  erst synthetisch auf bekanntem Ground Truth verifiziert und dann an
  **zwei unabhängigen Projekten** bestätigt werden, bevor es ins Template
  zurückfließt — festgehalten als Architekturentscheidung ([`adr/003`](adr/003-backport-after-confirmation.md)),
  nicht nur als Konvention im Kopf.
- **Negativbefunde werden dokumentiert, nicht versteckt.** Wenn eine Idee
  nicht hält, was sie verspricht (z.B. ein getestetes Ensemble, das keinen
  Zusatznutzen brachte, oder eine verworfene Korrelations-Abkürzung), steht
  das genauso im Protokoll wie ein Erfolg — siehe [`TARGETS.md`](TARGETS.md).
- **Automatisiert geprüft, nicht nur behauptet.** Zwei unabhängige
  CI-Jobs laufen bei jedem Push (Badge oben): eine `testthat`-Suite mit
  echten Korrektheitstests für die einzelnen Helper-Funktionen (inzwischen
  15+ Testdateien, z.B. Ensemble Selection, Config Validation, DB
  Logging, Provenienz, Evidence Registry), und ein Smoke-Test, der die
  Kernpipeline end-to-end gegen eine synthetische Fixture laufen lässt.

## Ein paar bestätigte Ergebnisse

**Ein scheinbar starkes Modell entpuppte sich als Messfehler, bevor Zeit
verschwendet wurde.** Bei einem Kredit-Scoring-Projekt (CreditScoringChallenge,
Zindi) erreichte ein erstes Modell F1 0.88 — beeindruckend, aber falsch: es
nutzte ein Feature, das zum Zeitpunkt der Kreditvergabe noch gar nicht
existierte (Strafgebühren, die erst nach einem Zahlungsausfall entstehen).
Das automatisierte Leak-Audit deckte das auf. Der ehrliche Wert (F1 ≈ 0.41)
wurde später extern fast exakt bestätigt (Zindi-Leaderboard: 0.4191) — ein
Beleg, dass die interne Prüfung stimmte, nicht nur eine Vermutung war.

**"Das eine beste Modell" gibt es nicht — jedes Projekt bekommt einen
eigenen, fairen Vergleich statt einer Standardannahme.** Bei einem
Erdbebenschaden-Datensatz (drivendata_richter) schlug ein einfacherer
Random-Forest-Ansatz (Ranger) das sonst meist überlegene LightGBM — sowohl
in der eigenen Validierung als auch auf dem echten Leaderboard (Rang 437
statt 1414). Die Konsequenz: das Template zwingt zu einem echten Vergleich
pro Projekt, statt "nimm einfach das, was letztes Mal gewonnen hat".

**Mehrere Modelle klug kombinieren statt nur das beste einzeln zu nehmen.**
Greedy Ensemble Selection (nach Caruana et al. 2004) wählt automatisch die
beste Kombination aus einem Pool von Kandidatenmodellen aus — bei einer zum
Zeitpunkt dieses Schreibens noch laufenden Kaggle-Competition
(`predictingsmartphoneAddiction_s6e8`) führte das zu einer echten,
messbaren Leaderboard-Verbesserung, nicht nur zu einem besseren CV-Wert.

**Die eigene Erfolgsmessung wird selbst hinterfragt, nicht blind
geglaubt.** Ein Modell kann in der Kreuzvalidierung gut aussehen, obwohl es
eigentlich nur die Testmethode ausgenutzt hat. Ein eigens gebautes
Diagnose-Modul vergleicht dafür die Kreuzvalidierung gegen einen
unabhängigen Bootstrap-Test — an zwei unabhängigen Datensätzen bisher
unauffällig, was für die Zuverlässigkeit der Methodik selbst spricht.

**Ein konkretes Endergebnis**: Balanced Accuracy **0.9482** auf dem
vollständigen, nie zuvor gesehenen Testdatensatz von `health_condition`
(Kaggle) — mit einem einfachen, gut erklärbaren Random-Forest-Modell statt
einer aufwendigen Blackbox.

## Mehr Tiefe

- [`docs/reference/REFERENZ_DUCKDB_EXPERIMENT_MART.md`](docs/reference/REFERENZ_DUCKDB_EXPERIMENT_MART.md) — DuckDB als optionaler lokaler Analyse-Mart fuer CSV-/Parquet-Artefakte und Experimentauswertungen.
- [`docs/reference/REFERENZ_PORTFOLIO_WARMSTART.md`](docs/reference/REFERENZ_PORTFOLIO_WARMSTART.md) — Portfolio-Warmstart aus der zentralen Experiment-DB: `lightgbm`/`ranger` frueh pruefen, Ensemble spaet optional.
- [`README_DETAILS.md`](README_DETAILS.md) — vollständige Skriptübersicht (85+ Skripte), alle Baseline-/Tuning-/Ensemble-Ergebnisse im Detail.
- [`WorkflowDescription.md`](WorkflowDescription.md) — der komplette Ablauf als Mermaid-Diagramm inkl. aller Entscheidungspunkte; auch ohne KI-Unterstützung nachvollziehbar.
- [`TARGETS.md`](TARGETS.md) — die `targets`-Pipeline (Caching/Reproduzierbarkeit) und die vollständige Entscheidungshistorie.
- [`adr/`](adr/) — Architekturentscheidungen (warum lokale Projekt-DBs statt einer geteilten Live-DB, R-only-Policy, die ≥2-Projekt-Backport-Regel).
- [`CONTRIBUTING.md`](CONTRIBUTING.md) — wie Beiträge/Bug-Reports/Support-Anfragen in der Praxis gehandhabt werden.
- [`docs/research/JOSS_TECHNIQUE_WATCH.md`](docs/research/JOSS_TECHNIQUE_WATCH.md) — gezielte Suche im JOSS-Paper-Korpus nach Trust-/Reproduzierbarkeits-/Evaluationstechniken, mit ADR-003-Backport-Gate statt Feature Creep.

Schwesterprojekt für Regressionsaufgaben: [`AutoML_Regression`](https://github.com/kubischraumzentriert/AutoML_Regression), gleiche Methodik, geteiltes DB-Schema.
