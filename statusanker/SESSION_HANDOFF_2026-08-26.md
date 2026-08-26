# Session Handoff (Stand 2026-08-26, 3. Aktualisierung) - Statusanker

Vorheriger Anker: `statusanker/SESSION_HANDOFF_2026-08-25.md` (Multi-Layer-
Stacking-Evidenzrunde). Dieselbe Sitzung lief ueber den Datumswechsel
hinweg weiter - dieser Anker deckt alles ab, was NACH dem 25.08.-Handoff
passiert ist: die restlichen 3 Punkte der Literatur-Roadmap vom 24.08.
(Hyperband, TabPFN, TabM), womit die gesamte Roadmap abgeschlossen wurde
- ein Housekeeping-Merge der zentralen Experiment-DB (2. Aktualisierung,
Abschnitt 4) - und, als 3. Aktualisierung desselben Tages, ein komplett
neuer Strang: ein von aussen (Codex/ChatGPT) vorgeschlagener P0-P3-
Refactor-Plan fuer `BACKLOG.md`, P0 vollstaendig umgesetzt, plus ein
P1.1-Prototyp (Abschnitt 5 unten).

## Repo-Zustand am Ende dieser Session

Alle drei Repos sauber (bis auf harmlose, nicht committete Catboost-
Trainings-Logs in `ML_Learning`, keine echten Aenderungen):
- `MLR3_Classifikation` @ `af154a0` "Add P1.1 prototype: full-workflow
  outer evaluation on health_condition" - gepusht, CI Smoke Test gruen.
- `MLR3_Regression` @ `645d6f5` (unveraendert seit dem 25.08.-Handoff).
- `ML_Learning` (rein lokal, kein Remote) @ `968437f` "Add TabM diversity
  check (s6e8)".
- Zentrale `experiments.db` (`_artifacts/`, gitignored - siehe ADR-001)
  wurde per `merge_project_experiments.R` aktualisiert (Abschnitt 4), das
  aendert keinen Commit-Hash der drei Repos oben.

## Was in dieser Session passiert ist (Fortsetzung nach dem 25.08.-Anker)

**1. Roadmap-Punkt 4 (Hyperband/BOHB) - NEGATIV, zweite Bestaetigung.**
Vorarbeit: einfaches Successive Halving (EINE feste Aggressivitaet) war
bereits am 2026-08-10 negativ/uneindeutig (bank-marketing/electricity).
Echtes Hyperband (mehrere Brackets unterschiedlicher Aggressivitaet, Li et
al. 2018) sollte pruefen, ob die methodisch vollstaendigere Variante das
aufhebt. `hyperband_budget_test.R` (Root-Skript, per Hand implementiert wie
der urspruengliche SH-Test - `lgb.train(..., init_model=)` fuer Budget-
Fortsetzung, volle Buchhaltungskontrolle): 4 Brackets (`eta=2`, `R_MAX=200`,
`R_MIN=25`) vs. Baseline (mehrere Kandidaten auf vollem Budget, exakt
gleiches Gesamtbudget), erstmals gegen das Template-eigene Projekt
(health_condition) statt eines OpenML-Datensatzes, 2 Seeds:

| Seed | Hyperband TEST-BAcc | Baseline TEST-BAcc |
|---|---|---|
| 1 | 0.8805 | 0.8733 |
| 2 | 0.8757 | 0.8791 |
| Mittel | 0.8781 | 0.8762 |

Differenz +0.0019 im Mittel, aber gegensaetzliche Richtung je Seed - exakt
dasselbe Rauschmuster wie beim urspruenglichen SH-Test. **Nicht ins
Template zurueckgefuehrt** - zweite unabhaengige Bestaetigung (anderer
Datensatz, andere Metrik, methodisch vollstaendigere Variante) schliesst
die Frage fuer Hyperband. BOHB bleibt mangels R/mlr3-Tooling ungetestet.
Vorlaeufiger API-Stolperstein: `predict.lgb.Booster(..., reshape=TRUE)` ist
in `lightgbm` 4.6.0 entfernt worden (Fehler beim ersten Lauf, per `sed`
gefixt) - `predict()` gibt bei Multiclass jetzt direkt eine Matrix zurueck.

**2. Roadmap-Punkt 3 (TabPFN als selektiver Kandidat) - NEGATIV, staerker
als der aeltere Naiv-Blend-Befund.** Anlass: ein seit 2026-08-08 offener
Hebel aus `tabpfn_diversity_check.R` (s6e8) - TabPFN dekorreliert echt von
den GBMs (0.899), ist aber schwaecher (0.9352 vs. ~0.964 AUC), ein
GLEICHGEWICHTETER Blend verwaesserte dadurch. Offene Frage: rettet eine
GEWICHTETE Greedy-Selektion den Kandidaten, wie bei TabICLv2 auf einem
anderen Projekt? Neues `tabpfn_greedy_selection_test.R` (s6e8-Ordner):
Pool aus 6 GBM-Varianten + 1x TabPFN (999-Zeilen-Kontext), Caruana Greedy
Ensemble Selection auf 1000/1000 Selektions-/Bestaetigungszeilen:

| Ansatz | AUC (Bestaetigung) |
|---|---|
| Blend nur GBMs (ohne TabPFN) | 0.9569 |
| Greedy Ensemble Selection (7 Kandidaten) | 0.9564 |
| Bestes Einzelmodell (catboost) | 0.9564 |
| Gleichgewichteter Blend (inkl. TabPFN) | 0.9563 |

**TabPFN wurde in 0 von 7 Greedy-Selektions-Zuegen gewaehlt** - komplett
ausgeschlossen, nicht nur niedrig gewichtet. Staerkeres Signal als der
Naiv-Blend-Befund: nicht "Gleichgewichtung verwaessert", sondern "nie die
bessere Wahl bei irgendeiner Gewichtung" auf diesem Projekt (grosser,
wenig verrauschter Datensatz, 999-Zeilen-Kontext kann gegen GBMs mit
voller Datenmenge nicht mithalten). **Nicht ins Template zurueckgefuehrt**,
bestaetigt aber die Roadmap-Linie selbst (TabPFN bleibt selektiv sinnvoll,
z.B. als Fehleranalyse-Werkzeug in `147_error_analysis_ranger_tabpfn.R`,
nicht als Default-Ensemble-Mitglied).

**3. Roadmap-Punkt 5 (TabM) - NEGATIV, schliesst die gesamte Roadmap ab.**
Nutzerfrage "was ist TabM" beantwortet: TabM (Gorishniy et al. 2024, Yandex
Research) trainiert statt Attention (FT-Transformer) EIN geteiltes MLP-
Backbone mit k "virtuellen" Ensemble-Mitgliedern via BatchEnsemble-
Parametrisierung (Wen et al. 2020, Rang-1-Eingangs-/Ausgangs-Skalierung
pro Mitglied auf geteiltem Gewicht) - Kosten ~k * ein MLP statt k
unabhaengiger MLPs. In `mlr3torch` nicht vorhanden - auf Nutzerwunsch
("R-Selbstbau, empfohlen") als eigenstaendiges `torch`-`nn_module` selbst
gebaut, Architektur vorab an einem synthetischen Smoke-Test verifiziert
(Shapes/Forward/Backward), bevor der volle Lauf gestartet wurde.
`tabm_diversity_check.R` (s6e8, k=8 Mitglieder, 2x96 Hidden, 30 Epochen,
identischer Holdout-Split wie `nnet_`/`tabpfn_diversity_check.R`):

| Modell | AUC (Holdout) |
|---|---|
| CatBoost | 0.9612 |
| XGBoost | 0.9609 |
| LightGBM | 0.9599 |
| **TabM** | 0.9558 |
| Blend3 (GBM) | 0.9616 |
| Blend4 (+TabM) | 0.9614 |

**Effizienz-These bestaetigt** (4.8 Min. fuer 30 Epochen vs. FT-Transformers
33 Min. fuer nur 15 - deutlich billiger), **Diversitaets-These NICHT**
(Korrelation zu den GBMs 0.975, ueber der 0.95-Gate-Schwelle, praktisch
gleichauf mit dem bereits verworfenen `nnet`). Plausible Ursache: ohne
Embeddings/Attention konvergiert auch ein effizient ensembletes MLP auf
One-Hot-Features zu einer baumaehnlichen Funktion - BatchEnsemble macht das
Training billiger, aendert aber nichts an der fehlenden architektonischen
Diversitaet. **Nicht ins Template zurueckgefuehrt.** FT-Transformer bleibt
der einzige bestaetigte Weg zu echter neuronaler Diversitaet.

**Damit haben jetzt ALLE 5 Punkte der Literatur-Roadmap vom 24.08. einen
abschliessenden Befund**: Punkt 1 (TabRepo/Portfolio-Warmstart) positiv
umgesetzt (optionaler Diagnose-Helper), Punkte 2 (Multi-Layer-Stacking, aus
dem 25.08.-Anker), 3 (TabPFN), 4 (Hyperband) und 5 (TabM) negativ, aber
jeweils sauber quantifiziert statt offen liegengelassen.

**4. Housekeeping: zentrale Experiment-DB gemergt (2. Aktualisierung,
selber Tag, Nutzeranfrage "Housekeeping-Check machen").** Letzter echter
Merge war 2026-08-14 - `merge_project_experiments.R` (idempotent/
inkrementell, automatisches Backup vor jedem Schreibzugriff) lief seither
nicht mehr. Ergebnis: 7 komplett neue Projekte in die zentrale DB
aufgenommen (`openml-eeg-eye-state-timeseries` 163 Metrik-Ergebnisse,
`openml-synthetic-control-timeseries` 181, `wdbc-plateau-test` 48,
`sba-loan-default` 12, `aer-creditcard-leak-test` 8,
`fremtpl2-claim-leak-test` 4, `synth-redundant-leak-test` 4) + 2 bestehende
Projekte mit neuen Runs (`dat-parkinsons-challenge` +216,
`openml-steel-plates-fault` +8). `git status` im Klassifikations-Repo
zeigt danach keine Aenderung - `_artifacts/` (inkl. `experiments.db`) ist
gitignored (ADR-001: lokale Projekt-DBs, keine geteilte Live-DB), nichts zu
committen. Zwei Backup-Dateien entstanden (Skript einmal zur Diagnose ein
zweites Mal aufgerufen, harmlos/idempotent) - keine Bereinigung noetig, nur
Speicherplatz (~20MB je Backup).

**5. Neuer Strang: externer BACKLOG.md-Refactor-Plan (Codex/ChatGPT), P0
vollstaendig umgesetzt, P1.1-Prototyp abgeschlossen (3. Aktualisierung).**

Ein neues `BACKLOG.md` erschien im Repo (vom Nutzer selbst ueber sein
GitHub-Konto verfasst, per `git pull` geholt) - ein Codex-orientierter
Refactor-Plan in 4 Phasen (P0 Stabilisieren/Absichern, P1 Kernlogik
testbar machen, P2 Evaluation/Nachvollziehbarkeit, P3 Aufraeumen). Nutzer:
"die Anweisung ist auch fuer Claude" - der Plan war also nicht nur zur
Kenntnisnahme, sondern explizit auch von Claude umzusetzen.

**Struktur-Konflikt erkannt und geklaert**: Der Plan setzt an mehreren
Stellen (P1 woertlich, P0.3 implizit) eine klassische R-Package-Struktur
voraus (`R/`, `NAMESPACE`, physisch aufgeteilte Config-Dateien). Das
kollidiert mit der bewusst FLACHEN Architektur dieses Templates (ein neues
Projekt entsteht durch Kopieren EINER Datei, z.B. `000_config.R` - siehe
`TARGETS.md`-Checkliste). Auf Nutzerwunsch ("schreibe eine Entgegnung ...
Begruende die Entgegnung") wurde eine begruendete Entgegnung verfasst und
an ChatGPT gegeben; ChatGPTs korrigierte Antwort akzeptierte die
Entgegnung. Scope-Entscheidung des Nutzers: "Erst nur P0 angehen, Rest
spaeter entscheiden."

**P0 komplett abgeschlossen** (Details/Commits: `BACKLOG.md`-Abschnitte
"P0 - Status", "P0.2 - Status", "P0.3 - Status", je datiert 2026-08-26):
- **P0.1 Testabdeckung**: neue `testthat`-Dateien fuer 8 bislang
  ungetestete Module (`target_leak_audit_helpers.R` [aus
  `015_target_leak_audit.R` extrahiert], `univariate_drift.R`,
  `seed_stability.R`, `db_logging.R`, `split_size_sensitivity.R`,
  `learning_curve.R`, `multilabel.R`, Probability-/Calibration-Helper
  [Teil von `db_logging.R`]) - Testsuite waechst von 4 auf 11 Dateien.
- **P0.2 Helper-Haertung**: implizite globale Abhaengigkeiten in
  `db_logging.R` (`project_dir`, `baseline_measure_ids`) durch explizite
  Parameter mit rueckwaertskompatiblem Default ersetzt; 7 nackte
  `stopifnot()`-Aufrufe in `group_resampling.R`/`univariate_drift.R`/
  `generalization_gap.R`/`ensemble_selection.R` mit verstaendlichen
  benannten Fehlermeldungen versehen.
- **P0.3 `validate_config()`**: neue, rein additive Datei
  `config_validation.R` (EINE Funktion, prueft die BESTEHENDEN
  `000_config.R`-Werte auf Konsistenz/Tippfehler - `000_config.R` selbst
  bewusst NICHT physisch aufgeteilt, analoger Struktur-Konflikt wie bei
  P1, gleiche Nutzerentscheidung: additiv statt aufteilend). 16 Testfaelle
  (29 Erwartungen) inkl. End-to-End-Kontrolle gegen die echte, geladene
  `000_config.R` von `health_condition`.

Volle Testsuite nach jedem Schritt gruen gehalten (jetzt 12 Testdateien
inkl. `config_validation`), jeder Schritt einzeln committet und gepusht,
CI Smoke Test nach jedem Push per `gh run list`/Monitor verifiziert.

**P1.1-Prototyp ("Full-Workflow Outer Evaluation") umgesetzt.** Auf "ja,
mach weiter mit P1" folgte ein Scope-/Kosten-Hinweis (per
`AskUserQuestion`); Nutzerentscheidung: "Prototyp zuerst: nur
`health_condition`, 3 Outer Folds" (statt ChatGPTs verlangten >= 2
Datensaetzen). Neues `outer_workflow_evaluation.R` (Repo-Wurzel, analog zu
`multilayer_stack_test.R`/`hyperband_budget_test.R` - kein Teil der
nummerierten Pipeline, daher kein dediziertes Testfile). 4 Vergleichs-Arme
je Outer-Fold, wobei Outer-Test-Zeilen NIE von einer Inner-Entscheidung
(Hyperparameter-Suche, Multiplier-Tuning) beruehrt werden:

| Arm | mean BAcc | SD | worst fold |
|---|---|---|---|
| `workflow_ranger` (echter Projekt-Workflow) | **0.9480** | 0.0051 | 0.9427 |
| `lightgbm_default` | 0.8745 | 0.0085 | 0.8646 |
| `lightgbm_tuned` (8-Eval-MBO, reduziertes Budget) | 0.8707 | 0.0065 | 0.8638 |
| `ranger_default` | 0.8633 | 0.0091 | 0.8532 |

Der echte, gelebte Workflow (klassengewichteter Ranger +
`class_multiplier_tuning.R`) generalisiert klar und konsistent besser als
alle 3 Baselines - in allen 3 Folds vorne, auf Daten, die das
Multiplier-Tuning nie gesehen hat. Dabei ein Bug gefunden und gefixt:
`mlr3measures::tnr()` (True Negative Rate) maskiert `mlr3tuning::tnr()`
(Tuner-Konstruktor), wenn `mlr3measures` nach `mlr3tuning` geladen wird -
`tnr("mbo")` rief dadurch die falsche Funktion auf und scheiterte kryptisch
an `assert_binary()`. Fix: expliziter `mlr3tuning::tnr("mbo")`-Aufruf.
Details/Limitationen in `BACKLOG.md`-Abschnitt "P1.1 - Status".

## Offene Punkte fuer die naechste Session

**Aus dem Literatur-Roadmap-Strang: keine dringenden**, komplett
abgeschlossen (siehe oben).

**Aus dem BACKLOG.md-Refactor-Strang**: P1.2 (Evidence Registry) und P1.3
(Experiment-/Daten-Provenienz) aus ChatGPTs korrigiertem Plan sind NICHT
angefasst - bislang nur explizit angeforderte Punkte umgesetzt (P0
komplett, P1.1 als Prototyp). P2/P3 aus demselben Plan komplett
unangefasst. Falls die naechste Session hier weitermachen soll: explizit
erfragen, WELCHER Punkt als naechstes drankommt (Muster dieser Session:
"ja, mach weiter mit X" je Einzelschritt, keine Bulk-Umsetzung). Ein
moeglicher voller P1.1-Nachfolger (>= 2 Datensaetze statt Prototyp) ist
ebenfalls offen, aber nicht angefordert.

Falls der Nutzer nichts Konkretes mitbringt: `TARGETS.md`/Memory auf neue
Ideen durchsehen, oder eine neue Literaturrunde/Domaenenerweiterung
anstossen.

## Wichtige Konventionen (falls die naechste Session sie noch nicht kennt)

- Commit und Push sind zwei separate, jeweils explizit vom User bestaetigte
  Schritte - nie automatisch pushen.
- Vor einem langen Hintergrundlauf mit neu geschriebenem Code (besonders
  bei API-Unsicherheiten wie einer selbstgebauten `torch`-Architektur):
  ERST ein winziger synthetischer Smoke-Test (Shapes/Forward/Backward),
  DANN der volle Lauf - verhindert, dass ein 5-30-Minuten-Hintergrundjob an
  einem trivialen Syntax-/API-Fehler scheitert (diese Session: TabM-
  Architektur so vorab verifiziert, TabM-Diversitaetsbefund war dadurch
  beim ersten echten Versuch bereits sauber).
- `lightgbm` R-Paket 4.6.0 hat `predict.lgb.Booster(..., reshape=)` entfernt
  - `predict()` gibt bei Multiclass-Objective jetzt direkt eine Matrix
  zurueck, kein `reshape=TRUE`-Argument mehr noetig/erlaubt.
- Bei Stacking-/Meta-Learner-Tests auf einer schwellenwertabhaengigen,
  unbalancierten Metrik (BAcc): Meta-Learner braucht dieselbe Klassen-
  gewichtung/Prior-Korrektur wie die Basismodelle (aus dem 25.08.-Anker,
  weiterhin gueltig).
- Ein negatives/uneindeutiges Ergebnis nach ausreichend breiter Evidenz darf
  als ENDGUELTIG beantwortet dokumentiert werden, nicht nur als "vorerst
  offen" (aus dem 25.08.-Anker, in dieser Session mehrfach angewendet: TabM/
  TabPFN/Hyperband alle klar als "nicht weiterverfolgt" markiert, nicht als
  vage Restfrage).
- Vollstaendiger Kontext: `TARGETS.md` (Klassifikation), `NEURAL_DEPLOY.md`
  (neuronale Kandidaten), `BACKLOG.md` (Klassifikation - jetzt zusaetzlich
  der Codex/ChatGPT-Refactor-Plan mit P0/P1.1-Status; Regression hat ein
  eigenes `BACKLOG.md`), sowie das persistente Gedaechtnis
  (`project_mlr3_automl_template.md`, Claude-Memory, automatisch geladen).
- Wenn ein extern (z.B. per `git pull`) eingebrachter Plan mit der
  bewusst flachen Architektur dieses Templates kollidiert (z.B. eine
  R-Package-Struktur mit `R/`/`NAMESPACE` voraussetzt): NICHT stillschweigend
  umsetzen oder ablehnen - eine begruendete Entgegnung formulieren und dem
  Nutzer zur Weitergabe an die externe Quelle anbieten, dann nach deren
  Antwort weiterarbeiten. In dieser Session zweimal so gehandhabt (P1
  R-Package-Struktur, P0.3 Config-Datei-Aufteilung), beide Male mit
  `AskUserQuestion` und Nutzerentscheidung fuer die additive/nicht-
  brechende Variante.
- Bei einem mehrstufigen externen Plan (P0/P1/P2/...): nur explizit vom
  Nutzer angeforderte Einzelschritte umsetzen ("ja, mach weiter mit X"),
  keine Bulk-Vorabumsetzung des gesamten Plans, auch wenn er als Ganzes
  "auch fuer Claude" gilt.
- Namenskollisionsfalle: `mlr3measures` UND `mlr3tuning` definieren beide
  eine Funktion `tnr()` (True Negative Rate vs. Tuner-Konstruktor). Wird
  `mlr3measures` NACH `mlr3tuning` geladen, maskiert es Letzteres - immer
  `mlr3tuning::tnr("mbo")` explizit qualifizieren, sobald beide Pakete in
  einem Skript geladen sind.

## Empfohlener erster Schritt der naechsten Session

Kein zwingender Einstiegspunkt. Zwei offene Baustellen zur Auswahl (siehe
"Offene Punkte" oben): (a) BACKLOG.md-Refactor-Plan fortsetzen (P1.2/P1.3
oder P2/P3, nur nach expliziter Nutzeranfrage), (b) Literatur-/Ideenrunde
wie gehabt (kurz pruefen, ob es seit dem letzten Merge neue Projekte in
`merge_project_experiments.R`s Auto-Discovery gibt, oder eine neue Runde
aehnlich der vom 24.08. anstossen).
