# Session Handoff (Stand 2026-09-18) - Statusanker

Vorheriger Anker: `statusanker/SESSION_HANDOFF_2026-08-29.md` (66.
Aktualisierung, 20 Tage/3020 Zeilen gewachsen - Rotation faellig, siehe
unten "Warum ein neuer Anker"). Diese Datei fasst den Endstand zusammen
und macht dort weiter. Fuer die vollstaendige Historie jeder einzelnen
Aenderung: der alte Anker bleibt unveraendert als Archiv liegen.

## Warum ein neuer Anker

Nutzeranfrage "schau, ob sonst noch was aufzuraeumen ist" (2026-09-18) -
Fund: die bisherigen Statusanker wurden im Schnitt alle 1-6 Tage neu
begonnen (7-23 KB je Datei). Der `...-29`-Anker lief dagegen 20 Tage
ununterbrochen weiter (181 KB, 66 Aktualisierungs-Eintraege) - 8-25x
groesser als jede fruehere Datei und dadurch selbst schwer navigierbar.
Nutzerbestaetigung "ja, mach das so" -> diese Rotation.

## Zusammenfassung des alten Ankers (Aktualisierungen 1-66)

**JOSS-Einreichung** (Aktualisierungen 1-19, 23, siehe auch fruehere
Anker): vollstaendig vorbereitet (Paper mit allen 6 Pflichtabschnitten,
Lizenz, Contributing, Draft-PDF-CI), dann nach 2 echten, gegen JOSS'
eigene Docs verifizierten Risiken (6-Monats-Repo-Alters-Gate, Scope-
Fit-Frage fuer "research software") bewusst PAUSIERT statt aufgegeben -
Wiedervorlage ~November 2026, weiterhin der einzige nicht akut
handlungsrelevante offene Punkt.

**Decision-Stability-/Hard-Split-Forschungsfrage** (Aktualisierungen
11, 14-21): VeridicalFlow/PCS-inspirierter Prototyp, ueber n=6 -> 10 ->
15 externe OpenML-CC18-Datensaetze erweitert, urspruenglicher
suggestiver Fold-1-Befund (rho=-0.28) haelt der Erweiterung NICHT
stand (rho=-0.147 bei n=15) - als widerlegt dokumentiert. Hard-Split-
Stresstest (astartes-inspiriert) dagegen erfolgreich ins Template
zurueckgefuehrt (`137_hard_split_stress_test.R`), inkl. einer echten
neuen Erkenntnis (harte Cluster-Splits koennen ein VERDECKTER
Class-Holdout sein, `class_holdout_suspected`-Flag ergaenzt).

**4 externe Bewertungsdokumente** (Aktualisierungen 3-13, 22-43)
vollstaendig abgearbeitet: zentraler DB-Merge (2 echte Bugs gefixt),
P0-P3-Roadmaps, 3 Evaluations-Ebenen definiert (Level 1/2/3,
`docs/research/EVALUATION_LEVELS.md`), externes OpenML-CC18-Benchmark-
Set, faire getunte Baselines (Protokoll v2), Level-2-Prototyp
(Protokoll v3, gemischtes Ergebnis - mehr Prozesskomplexitaet ist NICHT
automatisch besser), Paper-Claim-Hygiene, `reproduce_publication_
benchmark.R` (unabhaengig reproduzierbares 6-Datensatz-Benchmark fuer
AutoML-Conf-Reproduzierbarkeitsstandards).

**Backlog-Kandidaten-Runde "Trust-Layer-Module"** (Aktualisierungen
44-48, diese und die vorige Session): 5 neue Module, jeweils synthetisch
verifiziert UND an `health_condition` real angewendet:
- `probability_calibration.R` (Kalibrierung bereits gut, Platt machte es
  leicht schlechter - Post-hoc-Kalibrierung ist kein Automatismus).
- `rolling_drift_diagnosis.R` (an `beijing-air-quality-panel`: Drift
  oszilliert saisonal, rho=0,000 - kein Klimatrend).
- `subgroup_fairness_disparity.R` (0/24 auffaellige Paar-Metriken bei
  `gender`-Subgruppen).
- `feature_importance_stability.R`, `decision_stability*.R` (bereits
  frueher gebaut, hier real angewendet).
- `bootstrap_metric_ci.R` (NEU, 2026-09-17): Bootstrap-Konfidenz-
  intervalle fuer die finale Metrik statt nackter Punktschaetzung -
  Luecke war, dass `joss/paper.md`s "BAcc 0.9482" ohne Unsicherheits-
  angabe stand. An `health_condition`s OOF-Vorhersagen demonstriert:
  workflow_ranger BAcc 0.9452 [90%-CI: 0.9426, 0.9478] vs.
  ranger_default 0.8640 [90%-CI: 0.8595, 0.8685], gepaarter Unterschied
  +0.0812, p<0.0001 - bestaetigt den Klassengewichtungs-Effekt erstmals
  MIT Unsicherheitsmass.

**Root-Aufraeumung, alle 3 Schnitte + Regression + ML_Learning-Fund**
(Aktualisierungen 44-57, Kernstueck der letzten Session): Codebase-
Review fand 130+ Root-Skripte in `MLR3_Classifikation` unuebersichtlich.
- `outer_workflow_helpers.R` aus den 4 ADR-008-eingefrorenen
  `outer_workflow_evaluation*.R`-Protokollen extrahiert (Plumbing-
  Duplikation entfernt), dann alle 5 nach `protocols/` verschoben.
- Schnitt 1 (19 Diagnose-/Trust-Layer-Module), Schnitt 2 (4 kernnahe
  Module), Schnitt 3 (4 Standalone-Utilities) -> alle nach `modules/`
  verschoben. Root von 92 auf 61 nummerierte + nur noch 4 echte
  Kern-Infrastruktur-Dateien geschrumpft.
- `MLR3_Regression` bekam ZUERST eigene CI (`run_all_tests.R` +
  `.github/workflows/ci-tests.yml`, 5 Debug-Runden bis gruen - u.a. der
  bereits in `MLR3_Classifikation/.Rprofile` geloeste, hier erneut
  aufgetretene `mlr3extralearners`-Repo-Fund), DANACH analog zu
  Klassifikation in einem Rutsch aufgeraeumt (19 Module -> `modules/`,
  kleinerer/einfacherer Fall, kein `tests/testthat/` dort).
- **`ML_Learning`-Codebase-Audit**: 7 von 23 `class_multiplier_
  tuning.R`-Kopien hatten den 2026-08-31 gefundenen OOM-Fix noch nicht -
  chirurgisch in allen 7 nachgezogen (nur der betroffene Codeblock,
  nicht komplett ueberschrieben - die Kopien sind bewusst gefrorene
  Punkt-in-Zeit-Snapshots).
- `ML_Learning` selbst NICHT mit-umstrukturiert (begruendet: Root
  bereits sauber, jeder Projektordner eine gewollt eingefrorene Kopie,
  kein lebendes Repo) - stattdessen nur punktuelle Aufraeumung
  (veraltetes `SESSION_HANDOFF_2026-08-05.md` entfernt,
  `catboost_info/`-Trainings-Logs aus dem Tracking genommen + generisch
  gitignored, `DAT_Parkinsons`-Iteration nachtraeglich committed).
- 2 neue Skills aus den Lehren dieser Arbeit: `setup-r-ci-tests`
  (5-Punkte-Checkliste fuer R-CI-Debugging), Ergaenzung in
  `declutter-flat-scripts` (git-mv+git-add-Staging-Falle).

**Externe Parallel-Session-Pulls** (2x in dieser Session): eine externe
Session (andere Commit-Konvention "feat:"/"fix:") pushte direkt auf
GitHub - einmal 6 Commits (DWD-/Destatis-Wetterpiloten, dabei
versehentlich `ML_Learning/`-Inhalte ins Template-Repo committet, hier
entfernt + `.gitignore`-Eintrag ergaenzt), einmal 1 Commit ("Trust-Gate
v2"). Bei letzterem: `git pull --ff-only` scheiterte wiederholt an
einem OneDrive-Dateisperren-Effekt ("unable to unlink 'docs'") - sicher
umgangen durch manuelles Materialisieren der 4 geaenderten Dateien +
`git update-ref` statt vollem Checkout.

## Repo-Zustand am Ende des alten Ankers

- `MLR3_Classifikation` @ `79d0b48` (Statusanker Punkte 56-57), gepusht,
  CI gruen, `git status` leer.
- `MLR3_Regression` @ `a9bdd76` (Root-Aufraeumung), gepusht, CI gruen,
  `git status` leer.
- `ML_Learning` (lokal, kein Remote) @ `bd3c3d4`, `git status` leer.

## Was seit diesem Anker passiert ist

**1. Aktualisierung:** Nutzeranfrage "schau, ob sonst noch was
aufzuraeumen ist" - Fund: der (jetzt archivierte) alte Statusanker war
20 Tage/3020 Zeilen gewachsen, faellig fuer diese Rotation (siehe oben).
`MLR3_Regression`/`ML_Learning` zeigten keine vergleichbaren
Auffaelligkeiten.

**2. Aktualisierung:** Nutzeranfrage "mach weiter mit etwas Neuem" -
Kandidat #3 aus `docs/research/JOSS_TECHNIQUE_WATCH.md` (Autorank/
Demsar 2006) aufgegriffen: neues `modules/benchmark_statistics_
report.R` - `paired_wilcoxon_report()` (k=2 Methoden), `friedman_
nemenyi_report()` (k>=3, Friedman-Omnibus + Nemenyi-Post-hoc,
kritische Differenz per Demsar-2006-Tabelle selbst nachgebaut, keine
`scmamp`-Abhaengigkeit), `benchmark_statistics_report()` (waehlt
automatisch). Ergaenzt `bootstrap_metric_ci.R` (Einzeldatensatz) um die
Mehrfach-Datensatz-Frage. 25 Checks gruen.

**Erste Realprojekt-Anwendung** (`162_benchmark_statistics_report.R`) -
nutzt ausschliesslich bereits vorhandene Protokoll-v2-Ergebnisse der 6
externen CC18-Datensaetze (kein neuer Lauf noetig): `workflow_ranger`
hat den besten mittleren Rang (2.17/6), aber bei n=6 Datensaetzen haelt
kein Paar der Nemenyi-Schwelle stand (Friedman p=0.477) - bestaetigt
exakt die eigene Vorhersage des JOSS_TECHNIQUE_WATCH.md-Eintrags ("erst
bei mehr Datensaetzen aussagekraeftig"), ein ehrliches informatives
Nullergebnis. Dabei 2 veraltete Statuseintraege dort korrigiert
(Kandidaten #1 VeridicalFlow/Decision-Stability, #2 astartes/Hard-
Split-Stresstest standen noch als "Prototype: nein", obwohl laengst
gebaut/zurueckgefuehrt). Volle testthat-Suite + CI gruen.
(`MLR3_Classifikation` `5d3c7af`.)

**3. Aktualisierung:** Nutzeranfrage "schau, ob sonst noch was
aufzuraeumen ist" (2. Runde) - systematischer Check aller relativen
Markdown-Links (`[text](pfad.R/.md)`) repo-weit, aufgeloest relativ zur
jeweiligen referenzierenden Datei (nicht root-relativ - die naive
erste Pruefung lieferte 30 falsche Positive, danach korrekt pro Datei
aufgeloest). Fund: **8 kaputte Links in 8 Dateien**:
- 2 eigene Fehler aus dem `protocols/`-Umzug (`docs/research/
  BENCHMARK_PROTOCOL.md`/`EVALUATION_LEVELS.md` bekamen damals
  versehentlich root-relative statt `../../`-praefigierte Pfade).
- 6 aeltere, von der docs/-Restrukturierung (2026-09-02) uebrig
  gebliebene Bugs (`REFERENZ_DUCKDB_EXPERIMENT_MART.md`,
  `JOSS_TECHNIQUE_WATCH.md`, `PAPER_DRAFT.md`, `EXTERNAL_BENCHMARK_
  SET.md`, `joss/README.md` - `PAPER_DRAFT.md` selbst zog damals nach
  `docs/research/` um, der Rueckverweis aus `joss/README.md` wurde
  dabei nie nachgezogen).
- 1 echter Cross-Repo-Link (`REFERENZ_GROUP_AWARE_CV.md` ->
  `MLR3_Regression`), den relative Pfade auf GitHub grundsaetzlich
  nicht aufloesen koennen - auf eine absolute GitHub-URL zum
  Schwester-Repo umgestellt statt weiter kaputt zu bleiben.

Alle 8 gefixt, erneuter Vollcheck zeigt 0 verbleibende kaputte Links.
`MLR3_Regression` separat geprueft - dort keine Funde. Volle testthat-
Suite weiterhin gruen (reine Doku-Aenderung, kein neuer CI-Lauf noetig -
`ci-smoke-test.yml` triggert nur bei `.R`-Aenderungen).
(`MLR3_Classifikation` `bdb1b4f`.)

**4. Aktualisierung:** Nutzeranfrage "schau, ob sonst noch was
aufzuraeumen ist" (3. Runde) - Abgleich aller `library()`/`require()`-
Aufrufe im Repo gegen `DESCRIPTION`s Imports-Liste. Fund: **7 tatsaechlich
genutzte, aber fehlende Pakete** - `duckdb` (`170_build_duckdb_
experiment_mart.R`, `analysis/merge_duckdb_experiment_marts.R`),
`ggplot2` (`160`/`161_plot_*.R`), `isotree`/`kernelshap` (147er-
Fehleranalyse-Reihe), `mlr3oml` (`analysis/select_*_extension.R`,
`modules/reproduce_publication_benchmark.R`), `skimr` (**`010_eda.R`,
der allererste Schritt des README.md-"Los geht's"-Pfads** - echtes
Reibungsrisiko fuer neue Nutzer), `targets` (`_targets.R`). Ergaenzt +
Description-Text praezisiert (Doppelzweck CI + lokales Setup explizit
benannt). `MLR3_Regression`s `DESCRIPTION` separat geprueft - dort
bewusst NUR auf `ci-tests.yml` beschraenkt (eigener ehrlicher
Beschreibungstext, kein README-Verweis fuer lokales Setup, CI bereits
ohne diese Pakete gruen) - kein Fund, bewusst unveraendert gelassen.
(`MLR3_Classifikation` `58e2fdb`.)

**Noch offen bei Abschluss dieses Anker-Updates (damals)**: der
ausgeloeste CI-Lauf (`35363545432`) haengt seit >20 Minuten in der
Dependency-Installation (vermutlich `duckdb`/`mlr3oml` kompilieren ohne
Cache-Treffer zum ersten Mal, analog zur fruehen `MLR3_Regression`-CI-
Saga) - noch nicht abgeschlossen, wird in einer der naechsten
Aktualisierungen nachgetragen.

**5. Aktualisierung:** CI-Haenger-Diagnose abgeschlossen. Der haengende
Lauf `35363545432` wurde geprueft (per `gh run view` bestaetigt >40 Min.
in der `setup-r-dependencies`-Installation stecken geblieben, danach
abgebrochen) - Root Cause: `duckdb` UND die 6 weiteren neu zu
`Imports` hinzugefuegten Suggests-Pakete wurden ueber den Action-
Default `dependencies="all"` + `deps::.` bei JEDEM CI-Job (auch
`unit-tests`, der keines davon braucht) installiert; `duckdb` hat kein
verfuegbares Ubuntu-Binary und kompiliert aus dem Quellcode. **Fix**:
die 7 Pakete (duckdb, ggplot2, isotree, kernelshap, mlr3oml, skimr,
targets) von `Imports` nach `Suggests` verschoben (bereits in der 4.
Aktualisierung geschehen, hier nur bestaetigt), zusaetzlich in
`ci-smoke-test.yml` beide Jobs (`unit-tests`, `smoke-test`) explizit auf
`dependencies: 'c("Depends", "Imports", "LinkingTo")'` beschraenkt -
das schliesst Suggests-Pakete aus der CI-Installation komplett aus,
unabhaengig vom Action-Default. Vorab per `grep` verifiziert: keines der
tatsaechlich in der CI-Fixture ausgefuehrten Skripte (015-137,
`db_logging.R`, referenzierte `modules/`) nutzt eines der 7 Pakete.
Committed (`48f246b`), gepusht. **Verifiziert**: neuer CI-Lauf
`35367987508` erfolgreich, `unit-tests` 2m7s, `smoke-test` 2m17s - von
>40 Minuten Haenger auf ~2 Minuten runter.

**6. Aktualisierung:** Nutzeranfrage "schau dir die anderen Verzeichnisse
an - ... manche sind sehr kurz gehalten" fuehrte zu einem README-Pass
ueber alle Top-Level-Verzeichnisse: `ci_smoke_test/README.md` um einen
"Was ist ein Smoke-Test, wozu dient er hier"-Abschnitt erweitert (bisher
nur ein Verweis auf `TARGETS.md`); neue READMEs fuer `protocols/`
(ADR-008-Einfrier-Konvention + Versionstabelle), `features/`
(projektspezifisch vs. generisch), `docs/` (Index ueber reference/
research/ablations), `tests/` (Abgrenzung zu `ci_smoke_test/`),
`statusanker/` (diese Datei hier - Rotationskonvention erklaert).
`joss/README.md` war seit 2026-08-29 veraltet (suggerierte "Einreichung
steht unmittelbar bevor") - auf den echten Pause-Status (siehe oben,
JOSS-Abschnitt) synchronisiert. `adr/`/`analysis/` hatten bereits gute
READMEs, unveraendert gelassen. Committed `b617c79`/`96747b8`.

**7. Aktualisierung:** Nutzeranfrage "ein neues Thema" -> 3 Optionen
vorgeschlagen (ReciPies-Gegenpruefung, 2. Projekt-Zeuge fuer ein
Regression-Backlog-Item, komplett neues Thema). Erst faelschlich "Research
Aspect" vorgeschlagen (bereits abgeschlossen, siehe 2026-08-30-Eintraege
im alten Anker - Fehler korrigiert, dabei festgestellt: das P2-Level-2-
Muster ist bereits ueber 4 ausgeschlossene Kandidaten-Erklaerungen bis
n=15 Datensaetze ehrlich als ungeklaert dokumentiert, "natuerlicher
Abschlusspunkt").

**ReciPies-Gegenpruefung (JOSS_TECHNIQUE_WATCH.md Kandidat #5,
`MLR3_Classifikation`)**: echte, schmale Luecke gefunden - der
bestehende `feature_names_hash` hashte nur resultierende Spaltennamen
eines Feature-Sets, nicht die Transformationslogik selbst (ein stiller
Verhaltenswechsel in einer `add_*_features()`-Funktion waere unbemerkt
geblieben). Neue `feature_transform_function_hash()` (`000_config.R`)
hasht die Funktionskoerper der tatsaechlich angewendeten Familien-
funktionen; `feature_family_functions()` dafuer aus `apply_feature_set()`
herausgeloest. 8 neue Tests (u.a. direkter Beweis: identischer
Spaltenname, veraenderte Logik -> unterschiedlicher Hash). Volle Suite +
CI gruen (`c945093`, Lauf `35432105330`, 2m6s).

**2. Projekt-Zeuge fuer Missing-Data-Mechanismus-Audit (BACKLOG-Kandidat
27, `MLR3_Regression`)**: `openml-house-prices-regression` (lokal,
`ML_Learning`) bewusst mit strukturell ANDEREM Missingness-Mechanismus
gewaehlt (informative Abwesenheit - "kein Pool"/"keine Garage"/"kein
Keller" als leeres Feld kodiert - statt Beijings Sensorluecken) und
~300x kleinerer Stichprobe (n=1.168 vs. 360.966). 17/18 Spalten zeigen
substanzielle Effektgroessen (KS-D 0,17-0,64); die eine Ausnahme
(`MiscFeature`) zeigt korrekt keinen Ziel-Hinweis trotz MAR-Signal -
Beleg gegen "meldet pauschal alles". ADR-003-Kriterium fuer die
`min_effect_size`-Verfeinerung erfuellt. Committed lokal in `ML_Learning`
(`e4e5c23`) und `MLR3_Regression/BACKLOG.md` (`2a0765b`, gepusht).

## Stand jetzt

`MLR3_Classifikation`: alle Top-Level-Verzeichnisse haben jetzt eine
aktuelle README, `feature_transform_function_hash()` neu (ReciPies-
Luecke geschlossen), CI gruen, `git status` sauber. `MLR3_Regression`:
Kandidat 27 hat jetzt 2 unabhaengige, strukturell verschiedene
Projekt-Zeugen, `git status` sauber. `ML_Learning`: neues Diagnose-
Skript in `openml-house-prices-regression`, lokal committed. Kein
offener fachlicher oder struktureller Punkt in irgendeinem der 3 Repos.
Einzige nicht akut handlungsrelevante Sache bleibt: JOSS-Einreichung
pausiert, Wiedervorlage ~November 2026.

## Empfohlener erster Schritt

Kein akuter Punkt offen. Naechste sinnvolle Optionen: Nutzer nach einem
neuen Thema/Projekt fragen, oder bis zur JOSS-Wiedervorlage (~November
2026) abwarten.
