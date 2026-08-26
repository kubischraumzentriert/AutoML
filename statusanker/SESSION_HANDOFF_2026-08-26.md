# Session Handoff (Stand 2026-08-26, 2. Aktualisierung) - Statusanker

Vorheriger Anker: `statusanker/SESSION_HANDOFF_2026-08-25.md` (Multi-Layer-
Stacking-Evidenzrunde). Dieselbe Sitzung lief ueber den Datumswechsel
hinweg weiter - dieser Anker deckt alles ab, was NACH dem 25.08.-Handoff
passiert ist: die restlichen 3 Punkte der Literatur-Roadmap vom 24.08.
(Hyperband, TabPFN, TabM), womit die gesamte Roadmap jetzt abgeschlossen ist
- und, als 2. Aktualisierung desselben Tages, ein Housekeeping-Merge der
zentralen Experiment-DB (Abschnitt 4 unten).

## Repo-Zustand am Ende dieser Session

Alle drei Repos sauber (bis auf harmlose, nicht committete Catboost-
Trainings-Logs in `ML_Learning`, keine echten Aenderungen):
- `MLR3_Classifikation` @ `b07e691` "Add session handoff for 2026-08-26
  (Hyperband/TabPFN/TabM, roadmap complete)" - gepusht.
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

## Offene Punkte fuer die naechste Session

**Keine dringenden.** Die komplette Literatur-Roadmap vom 24.08. ist
abgeschlossen. Backlog ist wieder "leer" im Sinne von "alles bearbeitet und
ehrlich dokumentiert", auch wenn 4 von 5 Punkten negativ ausgingen -
bewusst als Erfolg zu werten (jede Frage wurde sauber quantifiziert
beantwortet, kein Punkt bleibt vage offen). Falls der Nutzer nichts
Konkretes mitbringt: `TARGETS.md`/Memory auf neue Ideen durchsehen, oder
eine neue Literaturrunde/Domaenenerweiterung anstossen.

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
  (neuronale Kandidaten), `BACKLOG.md` (Regression), sowie das persistente
  Gedaechtnis (`project_mlr3_automl_template.md`, Claude-Memory, automatisch
  geladen).

## Empfohlener erster Schritt der naechsten Session

Kein zwingender Einstiegspunkt - Backlog ist leer. Falls der Nutzer nichts
Konkretes mitbringt: kurz pruefen, ob es seit dem letzten Merge neue
Projekte in `merge_project_experiments.R`s Auto-Discovery gibt, oder eine
neue Literatur-/Ideenrunde anstossen (aehnlich der vom 24.08.).
