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

**8. Aktualisierung:** Nutzeranfrage "Sollen wir eigentlich mal einen
Refaktorierungslauf ueber die R-Scripte machen - Clean Code ist mir
wichtig" - Empfehlung: kein Rundumschlag ueber alle ~66 Root-Skripte
(hohes Regressionsrisiko, `protocols/outer_workflow_evaluation*.R` ist
laut ADR-008 ohnehin eingefroren), stattdessen gezielt mit dem
`clean-code`-Skill im REVIEW-Modus. Nutzerbestaetigung "ja mach das".

**`000_config.R` (`MLR3_Classifikation`)**: 2 sichere Funde umgesetzt -
(1) `apply_feature_set()`/`feature_transform_function_hash()` hatten
denselben Familien-Aufloesungsblock wortgleich dupliziert (durch die
ReciPies-Aenderung neu entstanden) -> `resolve_feature_families()`
extrahiert. (2) `feature_transform_function_hash()` rief `hash_value()`
(aus `provenance.R`) ohne Guard auf -> expliziter `exists()`-Check +
klare `stop()`-Meldung, konsistent mit dem bestehenden Guard-Stil im
selben File. Neuer Testfall (mit `new.env(parent = baseenv())`, um
Test-Pollution durch `test-provenance.R`s globales `source()`
auszuschliessen). Volle Suite + CI gruen (`bfc3bd3`, Lauf `35438034983`,
2m6s). Ein 3. Fund (Datei behauptet "reine Basis-Konfiguration" zu sein,
enthaelt aber ~10 Funktionen) bewusst NUR als Backlog-Notiz festgehalten,
nicht umgesetzt (groesserer, risikoreicherer Schritt).

**`000_config.R` (`MLR3_Regression`, Nutzeranfrage "ja, mach den
Regression-Review auch")**: deutlich kleiner/einfacher (325 vs. 854
Zeilen), keine Duplikation gefunden. Fund: `add_log_offset()`s
abschliessender `stopifnot()` hatte keine benannten Fehlermeldungen
(anders als das P0.2-Muster, das im Klassifikations-Template bereits auf
alle vergleichbaren Faelle angewendet wurde) -> nachgezogen. Dabei
aufgefallen: `add_log_offset()`/`algorithm_from_learner_id()` hatten
trotz realer 2-Projekt-Bestaetigung (tweet/dataCar) nie eine eigene
Testdatei -> neue `test_config_helpers.R` (10 Checks, Projekt-eigene
`test_*.R`-Konvention). Alle 10 Testdateien + CI gruen (`0ff28e1`, Lauf
`35438322749`, 1m32s).

**Alle 7 `147_error_analysis_ranger_*.R`-Dateien (768 Zeilen)**:
Nutzeranfrage "mach weiter mit den 147ern" - **kein nennenswerter Fund**.
Bereits sauber (loses Kopplungsmuster ueber Artefakte, echte
Funktionsextraktion wo sinnvoll, gute Guard Clauses). Einziger
Grenzfall (147_..._models.R trainiert Ranger/LightGBM/LDA in 3 aehnlichen
Bloecken) bewusst NICHT angefasst - echte Unterschiede je Learner, und
das Muster zieht sich konsistent durchs gesamte nummerierte
Skript-Repertoire (ADR-007-Philosophie).

**9. Aktualisierung:** Nutzeranfrage "schau, ob sonst noch was
aufzuraeumen ist - bzw. ob wir was refactorieren koennen" (4. Runde
dieser Frage in der Session, wieder ein echter Fund statt Wiederholung).

**Fund 1**: `MLR3_Regression/modules/` hatte - anders als
`MLR3_Classifikation/modules/` - noch keine README, obwohl auch dort 19
Dateien ohne Uebersicht liegen. Neue `modules/README.md` (analog
gruppiert: Trust-Layer/Diagnose, Panel-/Forecasting-spezifisch [opt-in],
Prediction Intervals, Metriken/Infra). Committed+gepusht (`f20194b`).

**Fund 2 (groesser)**: die P0.2-stopifnot-Bereinigung (2026-08-26) deckte
nur 7 Aufrufe in 4 Dateien ab - seither kamen etliche weitere ungenannte
`stopifnot()`-Aufrufe dazu. Per selbstgeschriebenem AST-Parser
(`getParseData()`) systematisch gefunden (grobe Heuristik lieferte viele
falsch-positive Treffer bei bereits benannten Mehrfach-Bedingungen -
jede Fundstelle einzeln per `Read` verifiziert, bevor editiert wurde).
Nutzerbestaetigung "ja, mach das ueber beide Repos durchziehen".

**`MLR3_Classifikation`**: 9 Dateien gefixt (`benchmark_statistics_
report.R`, `bootstrap_metric_ci.R`, `composition_reweighting.R`,
`feature_importance_stability.R`, `missingness_mechanism_audit.R`,
`probability_calibration.R`, `rolling_drift_diagnosis.R`,
`subgroup_fairness_disparity.R`, `159_bootstrap_metric_ci.R`). Ein Test
erwartete die alte generische Meldung ("k >= 3") und wurde auf die neue
angepasst. Volle Suite + CI gruen (`8abf68e`, Lauf `35438963137`, 2m10s).

**`MLR3_Regression`**: 13 Dateien gefixt (`combined_task_helper.R`,
`composition_reweighting.R`, `deviance_measures.R`,
`feature_importance_stability.R`, `group_resampling.R`,
`missingness_mechanism_audit.R`, `paired_fold_comparison.R`,
`quantile_regression.R`, `regular_lags_helper.R`,
`rolling_drift_diagnosis.R`, `time_blocked_resampling.R`,
`univariate_drift.R`, `110_oof_ensemble.R`) - deutlich mehr als in
Klassifikation, da die P0.2-Bereinigung dort offenbar nie ankam (z.B.
`group_resampling.R`/`univariate_drift.R` waren hier noch komplett
unbenannt, obwohl ihre Klassifikations-Kopien laengst benannt waren).
Alle 10 Testdateien + CI gruen (`4b1e89e`, Lauf `35439110117`, 1m25s).

**10. Aktualisierung:** Nutzeranfrage "wie machen wir weiter" -> 3
Optionen vorgeschlagen (neuer 2. Projekt-Zeuge, warten bis JOSS-
Wiedervorlage, etwas komplett anderes). Nutzerentscheidung: "OK 1.)" -
2. Projekt-Zeuge fuer Multi-Horizont-Forecasting (`MLR3_Regression`-
BACKLOG-Kandidat 31, bisher nur `beijing-air-quality-panel`).

**`electricity-load-panel`** (lokal, `ML_Learning`) als 2. Zeuge -
bereits als "2. Zeuge-Projekt" fuer Kandidaten 25/26 angelegt und
hatte laut eigenem README schon die passenden Lag-Features fuer eine
24h-Variante vorbereitet, aber diese selbst noch nicht gebaut. Zuerst
die fehlende 24h-Horizont-Referenz nachgezogen (`027_forecast_24h_
reference.R`, `forecast_horizon_24h_drop_cols` in `000_config.R`,
analog zu Beijings `027`) - LightGBM RMSE 168,86 auf dem echten
Held-out-Test, klar vor Persistence-Baseline (221,53) - echtes Signal,
kein Persistenz-Artefakt.

**Multi-Horizont-Modell** (`036_multi_horizon_forecasting.R`,
"horizon-as-feature"-Ansatz, jede Zeile 2x gestapelt): bestaetigt
**exakt denselben qualitativen Trade-off wie bei Beijing** - 1h-Horizont
wird schlechter (+10,04 RMSE, 122,51 vs. 112,47), 24h-Horizont wird
besser (-5,83 RMSE, 163,03 vs. 168,86), wenn beide in EINEM gemeinsamen
Modell gelernt werden. Deutlich groessere Betraege als bei Beijing
(+1,41/-0,69), aber gleiche Richtung in beiden unabhaengigen Projekten -
**ADR-003-Kriterium erfuellt**. Kein Backport als Modul: die Stapel-/
NA-Masken-Technik selbst ist ~10 Zeilen direkter Code, uebertragbar ist
nur der empirische Befund selbst (kein klarer Gewinner, Betriebsvorteil
vs. letzte RMSE-Punkte), kein wiederverwendbarer Baustein.

Committed lokal in `ML_Learning` (`68c3985`) und `MLR3_Regression/
BACKLOG.md` (`df84b8f`, gepusht). Details: `ML_Learning/electricity-
load-panel/README.md` Abschnitt 10.

**11. Aktualisierung:** Nutzeranfrage "koennen wir weitere
Refaktorierungen in den Rskripten machen im Klassifikation-Template" ->
zunaechst `db_logging.R` gezielt geprueft (Clean-Code-Review): (1)
`db_log_predictions()` nutzte manuelles `dbBegin()`/`dbCommit()` ohne
Rollback-Pfad bei einem Fehler zwischen den beiden Aufrufen -> auf
`DBI::dbWithTransaction()` umgestellt (automatischer Rollback,
empirisch mit einem Standalone-Testskript verifiziert: Variablen aus
dem Block bleiben im Aufrufer-Scope sichtbar, die Verbindung bleibt nach
einem Rollback nutzbar). (2) `db_create_run()`/`db_finish_run()` hatten
identische inline Lazy-Sourcing-Logik fuer `provenance.R` dupliziert ->
`.ensure_provenance_sourced()` extrahiert. Nutzerbestaetigung "ja, mach
das". Committed `c0d6e5e`, CI gruen.

Anschliessend die groessere, explizit "nach eigenem Ermessen"
autorisierte Anfrage: *"Gehe anschliessend durch alle Skripte des
Workflows und schaue was du refaktorieren kannst ... Ich wuerde
vorschlagen immer ein Skript nach dem anderen und dann CI - oder was
meinst Du?"* - Gegenvorschlag (Batch-Commits mit vollem lokalem Test
nach jeder Aenderung statt ~66 einzelner CI-Laeufe) implizit akzeptiert,
systematische Durchsicht praktisch des gesamten nummerierten
Skript-Korpus (Clean-Code-REVIEW-Methodik) in 3 weiteren Batches:

- **Batch B**: echter Bug gefunden - `016_feature_importance_
  stability.R`/`017_probability_calibration.R`/`018_subgroup_fairness_
  disparity.R` entfernten `id_col` NICHT vor dem Task-Bau (nur `015`
  tat das) - `id` waere als bedeutungsloses Feature mittrainiert worden
  (bei `016` sichtbar in der Feature-Importance-Rangfolge). Neues
  `modules/task_data_coercion.R` (`prepare_classif_task_data()`, 10
  Tests) fasst die Coercion-Logik fuer alle 4 Skripte zusammen,
  `ci-smoke-test.yml` um die neue Modul-Datei ergaenzt. Alle 4 Skripte
  gegen echte `health_condition`-Daten neu ausgefuehrt, "id" verschwand
  aus `016`s Feature-Liste. Committed `3f2bb82`, CI gruen.
- **Batch C**: `base_learner_constructors` (aus `000_config.R`, bereits
  bestehende Single Source of Truth mit vorkonfiguriertem
  `predict_type="prob"`) wurde von den meisten Benchmark-Skripten nicht
  genutzt - jedes rekonstruierte `lrn("classif.*")`+`predict_type`
  lokal neu. In `025/030/035/036/037/050/080` auf die zentrale Funktion
  umgestellt; `025_feature_engineering.R` bekam zusaetzlich eine 3.
  unentdeckte lokale Kopie der Familie->Funktion-Zuordnung entfernt
  (`feature_family_functions()` aus `000_config.R` statt Neubau).
  Committed `6fddddd`, CI gruen.
- **Batch D**: dieselbe `base_learner_constructors`-Bereinigung auf
  `095/105/110/120/125/130/135/140` ausgeweitet; `_targets.R` hatte eine
  4. unentdeckte Kopie der Familien-Zuordnung -> ebenfalls auf
  `feature_family_functions()` umgestellt. Alle 9 Dateien gegen die
  echten Projektdaten laufen lassen (mehrere wegen >180s CV-Laufzeit im
  Hintergrund), Ergebnisse konsistent mit dokumentierten Referenzwerten
  (z.B. CatBoost BAcc 0.9446 exakt wie dokumentiert). Committed
  `3dffad5`, CI gruen (Lauf `35454322560`, 2m15s).

Bewusst NICHT angefasst (mit Begruendung dokumentiert): `142_ranger_
tuning_weighted.R`/`146_threshold_tuning_ranger.R` (nutzen echte
tuning-abgeleitete Baumzahlen statt eines zufaellig passenden Defaults -
Vereinheitlichung waere eine stille Fehlkopplung), `148_ensemble_
candidate_pool.R` (echte Parametervariation je Kandidat, keine
Duplikation), `155/157_predict_*_submission.R` (teilen Logik, laden
Modelle aber ueber unterschiedliche Pfade - Vereinigung als zu
risikoreich/niedrignutzig bewertet), `db_get_or_create_project/
workflow()` (~15 Zeilen SQL-Duplikation, Abstraktion waere Overmodeling).

**12. Aktualisierung:** Nutzeranfrage "was koennen wir noch bereinigen",
dann konkret "wie sind die Scripte hinsichtlich Uebersichtlichkeit/
Effizienz aufgestellt - wurde Piping verwendet wo sinnvoll?" - Pipe-Audit
repo-weit: `%>%` wird in genau den 5 tibble-lastigen EDA-/Feature-
Skripten genutzt (`010_eda.R`, `020_task.R`, `025_feature_engineering.R`,
`095_tabpfn_benchmark.R`, `_targets.R`), der native `|>` nur in 2
Diagnose-Skripten, kein Skript mischt beide. Die uebrigen ~55
data.table-lastigen Skripte verketten per `dt[...][...]` statt Pipe -
das ist idiomatisch korrekt (data.table+Pipe gilt als Antipattern,
verschleiert by-reference-Semantik) und **kein Fund**.

**Echter Fund 1**: `150_train_full_model.R`/`155_predict_submission.R`
laden `library(tidyverse)` (8 Pakete), nutzen aber **keine einzige**
tidyverse-Funktion (reiner data.table-Code, 0 Treffer bei
`%>%`/`mutate`/`select`/... verifiziert) - reine Ladezeit-Verschwendung
in zwei Skripten, die typischerweise isoliert (neue Submission)
ausgefuehrt werden. `library(tidyverse)`-Zeile in beiden entfernt.

**Echter Fund 2**: `160_plot_roc_curve.R`/`161_plot_pr_curve.R` teilten
sich eine fast identische `rbindlist(lapply(algo, ...))`-Schleife zum
Kurvenaufbau (war schon in der 9. Aktualisierung als niedrigprioritaerer
Kandidat notiert, jetzt umgesetzt). Neue `compute_algorithm_curves()`
in `008_curve_diagnostics.R` (parametrisiert ueber x/y-Spalte + Metrik-
Label), skriptspezifische Teile (160s db_auc-Kreuzcheck gegen
`metric_result`, 161s Praevalenz-Baseline) bleiben lokal in den
jeweiligen Skripten.

Alle 5 geaenderten Dateien: Syntax-Check OK, volle testthat-Suite gruen,
alle 5 Skripte einzeln gegen echte `health_condition`-Daten ausgefuehrt
(150: Ranger-Training auf 690k Zeilen erfolgreich; 155: Submission mit
295.753 Zeilen erzeugt; 160/161: ROC-/PR-Kurven mit plausiblen
AUC-Werten erzeugt, PNG-Dateien gespeichert). Committed `561f58a`,
gepusht, **CI-Lauf `35565952794` verifiziert: completed/success, 1m51s**.

**13. Aktualisierung:** Nutzeranfrage "was koennen wir noch machen" ->
Bestandsaufnahme beider Backlogs (alle Kandidaten "erledigt"/"geprueft,
negativ") + `JOSS_TECHNIQUE_WATCH.md`-Durchsicht -> 3 Optionen
vorgeschlagen (externen Benchmark erweitern / 2. Projekt-Zeuge fuer
Regression-Kandidat 28/30 / komplett neues Projekt). Nutzerentscheidung
"Option 1, mach das" - externen CC18-Benchmark von n=6 auf n=15
erweitern.

**Vorab-Diagnose**: die 9 "Weg B"-Datensaetze (eingefroren 2026-08-31/
09-01) hatten bereits Task-Vorbereitung + Decision-Stability-/Level-2-
Laeufe (Protokoll v3), aber **kein** Protokoll-v2-Ergebnis (faire
getunte Baselines) - genau das, was `benchmark_statistics_report()`
(Kandidat 6, Autorank) braucht. `docs/research/EXTERNAL_BENCHMARK_SET.md`
hatte dafuer sogar noch einen veralteten "noch NICHT ausgefuehrt"-Vermerk
stehen (Status nach der Task-Vorbereitung nie aktualisiert) - dabei
korrigiert.

**Ausfuehrung**: `outer_workflow_evaluation_v2_fair_baselines.R` (bereits
in jedem `ML_Learning/openml-cc18-*`-Projektordner als Kopie vorhanden)
fuer alle 9 fehlenden Datensaetze sequenziell im Hintergrund laufen
lassen (Laufzeitschaetzung vorab kommuniziert: 30-90 Min., basierend auf
den bestehenden 6). Waehrend `mfeat-karhunen`s Fold 3 ging der Rechner in
Standby - der Nutzer erkannte das sofort richtig an der Symptomatik
(niedrige CPU-Zeit ueber lange Wanduhrzeit), per `Get-Process`-CPU-Zeit-
Vergleich vor/nach bestaetigt: kein Haenger, der Prozess rechnete nach
dem Aufwachen normal weiter. Alle 9 Laeufe nach insgesamt ~9,5h
Wanduhrzeit (davon der groesste Teil Standby, reine Rechenzeit ~70 Min.)
fehlerfrei durchgelaufen, alle 9 `outer_workflow_evaluation_v2_summary.csv`
verifiziert (korrekte Zeilenzahl, keine Fehler im Log).

**Ergebnis**: neues, eigenstaendiges `163_benchmark_statistics_
report_n15.R` (162 bleibt als abgeschlossene n=6-Analyse unveraendert).
**Bei n=15 wird der Friedman-Test signifikant** (chi2=14.017, p=**0.0155**
statt p=0.477 bei n=6), 1 Nemenyi-Paar signifikant (`ranger_default` vs.
`tuned_lightgbm`, Rangdifferenz 2 > kritische Differenz 1.947).
Bemerkenswert: `workflow_ranger` faellt von Rang 1 (2.17/6 bei n=6) auf
Rang 3 (3.07/6 bei n=15) - `tuned_lightgbm`/`best_single_tuned_model`
liegen jetzt davor. **Bestaetigt exakt die eigene Vorhersage aus
`JOSS_TECHNIQUE_WATCH.md`** ("erst bei mehr Datensaetzen
aussagekraeftig") - kein Widerspruch zu den bisherigen Einzelbefunden
(`workflow_ranger` gewinnt/haelt weiterhin klar bei den kleineren/
unausgeglicheneren Datensaetzen wie `ilpd`/`sick`/`blood-transfusion`,
das globale Rang-Ergebnis mittelt nur ueber alle 15). `BACKLOG.md`
Kandidat 6 und `JOSS_TECHNIQUE_WATCH.md` Kandidat 3 (inkl. Prioritaets-
tabelle) entsprechend aktualisiert. Volle testthat-Suite gruen. Committed
`9121338`, gepusht, CI gruen (`35689686621`, 2m6s).

## Stand jetzt

`MLR3_Classifikation`: der vollstaendige Refaktorierungs-Sweep (Nutzer-
auftrag "gehe durch alle Skripte ... nach eigenem Ermessen") ist
abgeschlossen - praktisch das gesamte nummerierte Skript-Korpus (~66
Dateien) wurde per Clean-Code-REVIEW durchgesehen. Reale Funde: ein
echter `id`-Spalten-Bug in 3 Skripten (behoben, neues `modules/
task_data_coercion.R`), Duplikation von `base_learner_constructors`/
`feature_family_functions()` in 13 Dateien (dedupliziert), ein totes
`library(tidyverse)` in 2 Dateien (entfernt), eine Kurvenaufbau-
Duplikation in 2 Plot-Skripten (dedupliziert). Danach: der externe
CC18-Benchmark ist von n=6 auf n=15 gewachsen, mit einem echten neuen
Forschungsergebnis (Friedman-Test bei n=15 signifikant, `workflow_
ranger`s scheinbarer Vorsprung haelt der groesseren Stichprobe global
NICHT stand, bleibt aber bei kleinen/unausgeglichenen Datensaetzen
bestehen) - `JOSS_TECHNIQUE_WATCH.md` Kandidat 3 damit vollstaendig
abgeschlossen. Alle Aenderungen einzeln gegen echte Projektdaten
verifiziert, keine Regressionen. CI gruen (`35689686621`, 2m6s),
`git status` sauber. `MLR3_Regression`/`ML_Learning`: unveraendert seit
dem 10. Eintrag (bis auf die 9 neuen `openml-cc18-*`-Protokoll-v2-Laeufe
in `ML_Learning`, lokal, kein separater Commit noetig - Artefakte, keine
Skript-Aenderung). Einzige nicht akut handlungsrelevante Sache bleibt:
JOSS-Einreichung pausiert, Wiedervorlage ~November 2026.

## Empfohlener erster Schritt

Kein akuter Punkt offen. Zwei der drei in der 13. Aktualisierung
vorgeschlagenen Optionen bleiben fuer eine kuenftige Session: 2. Projekt-
Zeuge fuer `MLR3_Regression`-Kandidat 28 (Quantilregression) oder 30
(robuste Loss-Funktionen), oder ein komplett neues Projekt (z.B. aktuelle
Kaggle-Playground-Series-Season pruefen). Sonst: Nutzer nach einem neuen
Thema fragen, oder bis zur JOSS-Wiedervorlage (~November 2026) abwarten.
