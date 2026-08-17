# Systematische Evaluation: Workflow-Komponenten über Projekte

Konsolidierte Ergebnistabelle für das mittelfristige Publikationsziel
(siehe `AGENTS.md`, "Mittelfristiges Ziel"). Beantwortet: welche
Workflow-Komponente wurde auf welchem Projekt bestätigt, war neutral/
No-op, oder wurde verworfen?

**Status: alle Zellen aufgelöst (2026-08-15), keine `?` mehr offen.**
Methodik: jede Zelle stützt sich auf einen konkreten Textbeleg in
`TARGETS.md`/`README_DETAILS.md`, oder - wo Prosa fehlte - direkt auf
nachgerechnete Werte aus dem jeweiligen `_artifacts`-CSV im Projektordner
(z.B. Adversarial-Validation-AUC, Split-Size-/Learning-Curve-/Seed-
Stabilitäts-Kennzahlen); keine Zelle wurde aus Erinnerung geraten. Ein
Grossteil der `—`-Zellen ist eine echte MARKER-LÜCKE (das jeweilige
nummerierte Skript existiert schlicht nicht im Projektordner, meist weil
das Modul erst nach der Projekt-Erstellung ins Template gebackportet
wurde) statt eines negativen Befunds - siehe die Abschnittshinweise unten
für die Einordnung je Spalte. Das ist eine erste vollständige Fassung,
keine finale Qualitätssicherung - ein zweiter Korrekturdurchgang (z.B.
Stichproben-Gegenprobe einzelner Zellen) bleibt sinnvoll, bevor die
Tabelle als publikationsreif gilt.

**Legende**: ✓ bestätigt (Modul lief, Befund unauffällig/wie erwartet) ·
✓✓ bestätigt UND Kernbefund (Leak/Bug real gefunden) · ~ neutral/No-op
(lief, kein Effekt) · ✗ verworfen (getestet, negativ, nicht übernommen) ·
— nicht anwendbar · ? nicht verifiziert

| Projekt | Leak-Audit (015) | Adversarial Val. (115) | Split-Size-Sens. (022) | Learning-Curve (023) | Seed-Stabilität (092) | Generalisierungslücke (136) | Ensemble Selection (148/149) | Threshold-Tuning (130) | Multi-Label (021) |
|---|---|---|---|---|---|---|---|---|---|
| `health_condition` (Template-eigen) | ✓ (stress_level 42.9%, kein Determinismus) | ✓ (AUC 0.654, moderat, unschädlich) | ✓ | ✓ (noch steigend, klein) | ✓ | ✓ (engste bisher gemessene Lücke, +0.0025, SD 0.0032, unauffällig) | ✓✓ (3./6. Bestätigung, live s6e8 deployed) | ✓✓ (`class_multiplier_tuning.R`, kontinuierlicher Optimizer: OOF raw argmax 0.872→0.945 BAcc, +0.074 - größter Einzelhebel des Projekts, unabhängig vom Ensemble) | — |
| `CreditScoringChallenge` (Zindi) | ✓✓ (F1 0.88→0.41, echter Ex-post-Leak) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `PumpItUp` (DrivenData) | ✓ (2. Bestätigung, `ward` 28.5%, kein Leak) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `geoai-aquaculture...` (Zindi) | ✓ (3. Bestätigung, `re3_08` 27.5%, kein Leak) | ✓✓ (AUC 0.99998 roh / 0.978 Band-Mittel - echter, extremer Train/Test-Shift; ESS 2.6% -> Reweighting verworfen, Invarianz-Ansatz stattdessen) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `openml-satimage-multiclass` | — (kein `015` im Projekt) | — (kein `115` im Projekt) | ✓ (Faktor 1.26x, unauffällig) | ✓ (noch steigend bei 100%) | ✓ (Seed-Varianz 0.23x/Jitter 0.21x, unauffällig - aus README nachgetragen, KEINE Reproduzierbarkeits-Lücke wie bei Learning-Curve: `092_seed_stability.R` fehlt zwar im Ordner wie das `023`-Pendant, aber die Zahlen stehen mit SD-Werten im README dokumentiert, nicht nur als Prosa-Behauptung) | ✓ (2. Bestätigung, z=1.03/z=0.50, kleinere/engere Hintergrund-Lücke als steel-plates-fault, unauffällig) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `openml-steel-plates-fault` | ✓ (1 Determinismus-Fund dokumentiert, nicht als Leak entfernt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ✓ (1. Bestätigung, z=-1.63/z=-0.39, Hintergrund-Lücke -0.039 BAcc, beide Kandidaten innerhalb des Referenzbereichs) | — (kein `148`/`149` im Projekt) | ✓ (1/prior schlägt Grid: 0.840 vs. 0.832) | — |
| `openml-credit-g` | ✓ (unauffällig, Top-Feature `credit_amount` 26.9%, 0/68 Determinismus) | — (kein `115` im Projekt) | ✓ (Faktor 1.53x bei ratio=0.80, unauffällig) | ✓ (NOCH STEIGEND, 23.1% des IQR - **korrigiert 2026-08-15**: urspr. als "PLATEAU, 6.5% der vollen Spannweite" gemessen, aber ein Ausreisser bei n=20 hatte die Spannweite kuenstlich aufgeblaeht und den Trend verschleiert; robusterer IQR-Nenner zeigt denselben "noch steigend"-Trend wie `health_condition`/`satimage`/die Zeitreihen-Projekte) | ✓ (2 Checks, 17.3%/16.6% relativ, beide unauffällig) | ✓ (unauffällig, eigener 80/20-Split) | — (kein `148`/`149` im Projekt) | ✓ (binärer Nelder-Mead-Fix gefunden+behoben) | — |
| `openml-adult-income` | — (kein `015` im Projekt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `playground-series-s6e5` | — (kein `015` im Projekt) | ✓ (AUC 0.4996, kein Shift) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | ✗ (KEIN `148`/`149` im Projekt - stattdessen `140_stack_ensemble.R`, ein ANDERES Verfahren: Logits-Stacking-Meta-Learner, negativ getestet: +0.00016 AUC ggü. bestem Einzelmodell, unter dem Rausch-Band, bei ~19x Rechenaufwand - nicht übernommen) | — (kein `130` im Projekt) | — |
| `playground-series-s6e6` | — (kein `015` im Projekt) | ✓ (AUC ≈0.4996, kein Shift, widerlegt Kardinalitäts-Artefakt-Verdacht aus s6e5) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | ✓ (5. Bestätigung, Methodik-Test - lokal als `146_ensemble_selection.R` benannt, nicht `148`/`149`, aber dieselbe Greedy-Ensemble-Selection-Methodik; laut Roh-CSV gewinnt der Greedy-Ensemble hier NICHT gegen das beste Einzelmodell, BAcc 0.9633 vs. 0.9638 - Mechanismus lief korrekt, aber ohne Performance-Gewinn bei diesem Lauf) | — (kein `130` im Projekt) | — |
| `predictingsmartphoneAddiction_s6e8` | — (kein `015` im Projekt) | ✓ (AUC 0.565, moderat; ESS-Ratio 0.94, unschädlich) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | ✓✓ (6. Bestätigung, live Kaggle-Submission) | — (`130`/`146` im Ordner, aber strukturell übersprungen - AUC/LogLoss/PRAUC sind schwellenwertunabhängig, keine Artefakte vorhanden) | — |
| `drivendata_richter` | — (kein `015` im Projekt) | ✓ (AUC 0.5002, kein Shift) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `openml-yeast-multilabel` | — (kein `015` im Projekt) | — | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | ✓ (Binary Relevance, 1. Bestätigung) | ✓ (1. Bestätigung) |
| `openml-scene-multilabel` | — (kein `015` im Projekt) | — | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | ✓ (2. Bestätigung) | ✓ (2. Bestätigung) |
| `openml-birds-multilabel` | — (kein `015` im Projekt) | — | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | ✓ (3. Bestätigung) | ✓ (3. Bestätigung) |
| `health-condition-huyen-sanity-tests` | — | — | — | — | — | — | — | — | — |
| `FinancialStressPredictionChallenge` | — (kein `015` im Projekt) | ✓ (AUC 0.4971, kein Shift) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `openml-amazon-access` | — (kein `015` im Projekt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `openml-bank-marketing-ensemble-test` | — (kein `015` im Projekt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | ✓ (frühe Ensemble-Selection-Bestätigung, vor `health_condition`) | — (kein `130` im Projekt) | — |
| `openml-synthetic-control-timeseries` | ✓ (unauffällig) | — (kein `115` im Projekt) | ✓ (Faktor 1.25x, unauffällig) | ✓ (noch steigend, 45.4% des IQR - Zelle am 2026-08-17 korrigiert, stand veraltet als "17.5%" seit vor dem IQR-Fix) | ✓ (SD=0.000, vollständig deterministisch) | ✓ (beide unauffällig, z=0.05/-0.63) | — (kein `148`/`149`; stattdessen FT-Transformer-Dekorrelationstest `095`/`096` für Hebel-1-Kandidat, negativ: Kappa 0.976, kein Diversitätsgewinn) | ✓ (keine Verbesserung, exakt balancierte Klassen) | — |
| `playground-series-s5e12` (Kaggle) | — (kein `015` im Projekt) | ✓ (AUC 0.627, moderater aber echter Shift, Treiber `physical_activity_minutes_per_week`/`triglycerides`) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | ✗ (KEIN `148`/`149` im heutigen Sinn - lokal `148_select_submission_model.R`/`149_disagreement_check.R`, ZWEI ANDERE Verfahren: datengetriebene Modellwahl aus `experiments.db` bzw. Uneinigkeits-Vertrauenscheck, keine Greedy-Ensemble-Selection; drittes Projekt nach `s6e5`/`s6e6` mit diesem Namenskollisions-Muster) | ~ (`130_threshold_tuning.R` im Ordner, aber keine Artefakte - Zielmetrik AUC ist schwellenwertunabhaengig, `warn_if_threshold_step_low_value()` greift; dasselbe Muster wie `predictingsmartphoneAddiction_s6e8`) | — |
| `openml-eeg-eye-state-timeseries` | ✓ (unauffällig) | — (kein `115` im Projekt) | — (strukturell übersprungen, >5000 Zeilen) | ✓ (noch steigend, 31.0% des IQR - Zelle am 2026-08-17 korrigiert, stand veraltet als "14.7%" seit vor dem IQR-Fix) | ✓ (unauffällig, 0.23x/0.21x) | ✓ (beide unauffällig, aber bisher höchste z-Werte: z=1.67/1.27) | — (kein `148`/`149`; stattdessen FT-Transformer-Dekorrelationstest `095`/`096`, 2. Versuch nach `synthetic_control`: Kappa 0.581, DEKORRELIERT (anders als dort), aber FT-Transformer schwächer (BAcc 0.764 vs. Ranger 0.869 bei nur 15 Epochen/n=4500); `097_weighted_blend.R` (2026-08-17) hat den gewichteten Blend gebaut/getestet - Hebel 1 NICHT bestätigt, kein Blend (skalar 0.8403/per-Klasse 0.8378) schlägt Ranger allein (0.8439), Gewicht-Suche schaltete FT-Transformer fast ab) | ✓ (binärer `optimize()`/Brent-Pfad, modester Gewinn) | — |
| `wdbc-plateau-test`¹ | — (kein `015` im Projekt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | ✓✓ (gezielt gebauter PLATEAU-Fall, 7.5% des IQR nach Mindest-n-Fix - erster echter Plateau-Fund, siehe Fussnote) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `uci-parkinsons-voice-groupcv`² | — (kein `015` im Projekt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |

¹ `wdbc-plateau-test` ist KEIN regulaeres Kaggle/OpenML-Workflow-Projekt,
sondern ein gezielt gebauter Diagnose-Testfall (Wisconsin Breast Cancer via
`mlbench::BreastCancer`, klassisch "sehr sauber trennbar") - nur `020`/
`023`/`030` gelaufen, deshalb ueberwiegend `—`. Zweck: pruefen, ob die
Learning-Curve-PLATEAU-Klassifikation ueberhaupt je korrekt anschlaegt,
nachdem der einzige bisherige Plateau-Fund (`credit-g`) sich als
Methodik-Artefakt herausstellte (siehe TARGETS.md/Abschnitt unten).

² `uci-parkinsons-voice-groupcv` ist ebenfalls kein regulaeres Workflow-
Projekt, sondern der gezielt gebaute ZWEITE Klassifikations-Beleg fuer
Group-aware CV (nach `eeg-eye-state-timeseries`) - nur `020`/`021`
gelaufen (kein `022`-`149`, da nicht der Zweck), deshalb durchgehend `—`.
Ergebnis (Group-aware CV hat noch keine eigene Spalte): Random-CV BAcc
0.804 vs. Group-CV BAcc 0.568 (-23.6 Punkte), siehe Diskussion unten.

## Was diese erste Fassung zeigt

- **Ensemble Selection und die vier Brownlee-Checklisten-Module
  (Leak-Audit, Split-Size-Sensitivity, Learning-Curve, Seed-Stabilität,
  Generalisierungslücke) sind die am dichtesten belegten Komponenten** -
  konsistent mit `AGENTS.md`s Einschätzung, dass die Trust-/Diagnose-
  Schicht der stärkste Publikationskern ist.
- **Viele `?`-Zellen sind vermutlich echte Lücken, nicht nur fehlende
  Recherche** - z.B. wurde Adversarial Validation offenbar nur am
  Template-eigenen Projekt dokumentiert geprüft, nicht systematisch an
  den externen Projekten.
- **Multi-Label und Threshold-Tuning-binär sind strukturell nur auf eine
  Teilmenge der Projekte anwendbar** (— korrekt, keine Lücke).
- **Leak-Audit (015) aufgelöst (2026-08-15)**: von 13 zunächst offenen
  Projekten hatten nur `openml-credit-g` das Skript tatsächlich im
  Projektordner (verifiziert: unauffällig, Top-Feature 26.9%, 0/68
  Determinismus-Zeilen) - die übrigen 12 (`satimage`, `adult-income`,
  `s6e5`, `s6e6`, `s6e8`, `drivendata_richter`, die Multi-Label-Trio,
  `FinancialStressPredictionChallenge`, `amazon-access`, `bank-marketing-
  test`) haben kein `015` im Projektordner. Das ist eine echte Marker-Lücke
  (`015` wurde erst nach `CreditScoringChallenge`/`PumpItUp`/`geoai`
  eingeführt, viele der genannten Projekte sind älter oder wurden seither
  nicht nachgezogen) - für eine Publikationsnotiz wäre zu klären, ob
  eine nachträgliche Anwendung auf diese Projekte lohnend wäre, statt es
  als abgedeckt zu behandeln.
- **Adversarial Validation (115) aufgelöst (2026-08-15)**: von 14 zunächst
  offenen Projekten hatten 6 das Skript im Projektordner. Ergebnisse per
  README/TEMPLATE_FRICTION-Prosa (`geoai`, `s6e5`, `s6e6`,
  `FinancialStressPredictionChallenge`) bzw. direkt aus dem
  `_artifacts`-CSV gelesen, wo keine Prosa vorlag (`drivendata_richter`:
  `adversarial_validation_auc.csv`; `predictingsmartphoneAddiction_s6e8`:
  `adversarial_validation_results.csv`/`adversarial_staged_results.csv`).
  **Echter Befund, kein Nullergebnis**: `geoai-aquaculture` zeigt einen
  extremen Shift (AUC 0.99998 auf Rohfeatures, 0.978 selbst auf
  Monats-Band-Mitteln) - das war der Ausloeser fuer den gesamten
  Invarianz-statt-Reweighting-Ansatz in diesem Projekt (ESS kollabiert bei
  Reweighting auf 2.6%, siehe TEMPLATE_FRICTION.md). Alle anderen 5
  Projekte unauffaellig (AUC 0.4971-0.565, `s6e8`s 0.565 mit gesunder
  ESS-Ratio 0.94 als "moderat, unschaedlich" eingestuft - dieselbe
  Einordnung wie beim Template-eigenen `health_condition`, AUC 0.654). Die
  restlichen 8 Projekte (`CreditScoringChallenge`, `PumpItUp`, `satimage`,
  `steel-plates-fault`, `credit-g`, `adult-income`, `amazon-access`,
  `bank-marketing-test`) haben kein `115` im Projektordner - dieselbe
  Marker-Luecke wie beim Leak-Audit, keine Nullbefunde.
- **Split-Size-Sensitivity (022) / Learning-Curve (023) / Seed-Stabilitaet
  (092) aufgeloest (2026-08-15)**: alle drei Module wurden erst am
  2026-08-13 gebackportet (siehe TARGETS.md) - von den 16 offenen
  Projekten hat NUR `openml-credit-g` alle drei im Ordner (Workflow-
  Smoke-Test vom 2026-08-14). Werte direkt aus `_artifacts/split_
  sensitivity_results.csv`/`learning_curve_results.csv`/`seed_stability_
  results.csv` nachgerechnet (TARGETS.md dokumentierte fuer `credit-g`
  bisher nur "lief fehlerfrei durch", keine Zahlen): Split-Size-Sens.
  Faktor 1.53x bei `ratio=0.80` (Schwelle 2x, unauffaellig). Seed-
  Stabilitaet 17.3%/16.6% relativ (Schwelle 50%, beide unauffaellig).
  **Urspruenglich vermuteter differenzierender Befund bei Learning-Curve,
  NACHTRAEGLICH WIDERLEGT (2026-08-15, siehe eigener Abschnitt weiter
  unten)**: `credit-g` (1000 Zeilen) schien zunaechst als erstes Projekt
  ein PLATEAU zu zeigen (6.5% der vollen Score-Spannweite, unter der
  10%-Schwelle) - stellte sich bei der Suche nach einem zweiten Beleg als
  Methodik-Artefakt heraus (ein Ausreisser bei winzigem n blaehte die
  Spannweite auf). Mit einem robusteren IQR-Nenner zeigt `credit-g`
  denselben "noch steigend"-Trend (23.1%) wie alle anderen bisher
  getesteten Projekte, unabhaengig von der Groesse. Die restlichen 14
  Projekte haben keines der drei Module im Projektordner - Marker-Luecke,
  keine Nullbefunde.
- **Generalisierungslücke (136) aufgelöst (2026-08-15)**: von 15 offenen
  Projekten hat KEINES `136_generalization_gap.R` im Ordner - nur die
  bereits gefuellten vier (`health_condition`, `satimage`,
  `steel-plates-fault`, `credit-g`) haben es. Bestehende `✓`-Zellen um die
  konkreten z-Werte aus TARGETS.md ergaenzt statt als reines `✓` stehen zu
  lassen: `health_condition` z.B. mit der bisher ENGSTEN gemessenen
  Hintergrund-Luecke (+0.0025, SD 0.0032), `satimage`/`steel-plates-fault`
  mit z=1.03/0.50 bzw. z=-1.63/-0.39 - konsistent mit der erwarteten
  "Luecke schrumpft mit Datensatzgroesse"-Reihenfolge
  (steel-plates-fault 1941 Zeilen > satimage 6430 > health_condition
  690088). Alle vier bislang gemessenen Faelle unauffaellig - bisher KEIN
  einziger realer Beleg fuer Test-Harness-Optimismus durch die Suche
  gefunden (nur synthetisch nachgewiesen, siehe
  `REFERENZ_GENERALIZATION_GAP.md`).
- **Threshold-Tuning (130) aufgelöst (2026-08-15)**: `health_condition`
  selbst war trotz Template-eigenem Projekt bisher als `?` offen - dabei
  ist das dort der GRÖSSTE dokumentierte Einzelhebel überhaupt
  (`class_multiplier_tuning.R`: OOF raw argmax 0.872→0.945 BAcc, +0.074).
  Von den 12 verbleibenden Projekten hat nur `predictingsmartphoneAddiction_
  s6e8` die Skripte im Ordner (`130`/`146`/`class_multiplier_tuning.R`) -
  aber keine Artefakte vorhanden, weil `s6e8` AUC/LogLoss/PRAUC
  (schwellenwertunabhängige Metriken) nutzt und Threshold-Tuning laut
  Template-Konvention fuer diesen Fall strukturell übersprungen wird
  (dokumentiert in `TARGETS.md`, Uebertragungs-Checkliste Punkt 2) - kein
  Nullbefund, sondern korrektes "nicht anwendbar". Die uebrigen 11 Projekte
  haben keine der Skript-Varianten im Ordner. **Hinweis**: die drei
  Multi-Label-Projekte (`yeast`/`scene`/`birds`) hatten in dieser Spalte
  bereits vor dieser Session Eintraege ("Binary Relevance, n.
  Bestaetigung") - das bezieht sich auf die Accuracy-Threshold-Tuning-
  Komponente INNERHALB von `multilabel.R`, nicht auf `130_threshold_
  tuning.R` selbst (andere Implementierung, gleiches Konzept) - bewusst
  unveraendert gelassen, aber als Auslegungshinweis hier vermerkt.
- **Ensemble Selection (148/149) aufgelöst (2026-08-15)**: von 13 offenen
  Projekten hat KEINES `148`/`149` im Ordner - alle Bestätigungen laufen
  entweder ueber Standalone-Skript-Pools (bank-marketing/electricity, kein
  eigenes Projekt-Repo) oder ueber die spaeter direkt ins Template
  gebackporteten Projekte (`health_condition`/`s6e6`/`s6e8`), waehrend die
  meisten kleineren Kaggle/OpenML-Miniprojekte vor dem Backport
  (2026-08-11) entstanden. Alle 13 Zellen auf "kein 148/149 im Projekt"
  gesetzt - Marker-Luecke, kein Nullbefund.
- **Nachtrag: 4 uebersehene `?`-Zellen bei Adversarial Validation (115)
  nachtraeglich behoben (2026-08-15)** - beim finalen Durchgang
  festgestellt, dass `satimage`/`steel-plates-fault`/`credit-g`/
  `adult-income` bei der urspruenglichen 115-Spaltenaufloesung versehentlich
  nicht auf `—` gesetzt wurden, obwohl bereits damals bestaetigt war, dass
  keines der vier `115_adversarial_validation.R` im Ordner hat. Alle
  `?`-Zellen der Tabelle sind damit jetzt vollstaendig aufgeloest (0
  verbleibend, per `grep`).
- **Zwei neue Zeitreihen-Projekte ergaenzt (2026-08-15)**:
  `openml-synthetic-control-timeseries` und `openml-eeg-eye-state-
  timeseries` - erste Zeitreihen-Charakteristik im Oekosystem, bewusst als
  Kontrastpaar gewaehlt (unabhaengige Serien vs. durchgehende Aufzeichnung
  mit Zeit-Autokorrelation). Zwei echte Befunde, die KEINE der neun
  bestehenden Spalten abbildet, deshalb hier als Text vermerkt statt einer
  neuen Spalte (zu geringe Fallzahl fuer eine eigene Spalte, siehe Punkt 2
  unten):
  - **`group_resampling.R` (portiert aus `MLR3_Regression`) erste
    eigenstaendige Bestaetigung auf der Klassifikationsseite** bei
    `openml-eeg-eye-state-timeseries`: Random-CV BAcc 0.930 vs. Block-CV
    BAcc 0.717 (-21 Punkte) - der bisher dramatischste Group-aware-CV-Befund
    im gesamten Oekosystem (staerker als die beiden Regressions-
    Bestaetigungen `SubjektDatensatz`/`AStepAheadOfdrought`). Noch kein
    kanonisches Skript/keine Spaltennummer im Klassifikations-Template
    (`group_resampling.R` liegt bisher nur projekt-lokal kopiert), daher
    keine eigene Tabellenspalte.
  - **FT-Transformer (`mlr3torch`) als Ensemble-Diversitaets-Kandidat**
    (`per-Klassen-gewichteter Ensemble-Blend`-Backlog, Hebel 1) bei
    `openml-synthetic-control-timeseries` getestet: CPU-Machbarkeit
    bestaetigt (~11 Min. Produktions-Hochrechnung), aber negativ fuer
    Ensemble-Zwecke - Kappa 0.976 (stark korreliert mit Ranger) UND
    schwaecher (0.983 vs. 0.990 BAcc). Kein Bestandteil der Ensemble-
    Selection-Spalte (148/149), da ein anderes Verfahren/Backlog-Ziel.
- **Stichproben-Gegenprobe an Alt-Zellen (2026-08-15), kein neuer Fehler
  gefunden**: 7 Zellen aus der allerersten Entwurfsfassung (vor dem
  2026-08-15-Durchgang, quer ueber 6 Projekte/6 Spalten) direkt gegen
  Quelle nachgeprueft statt nur gegen TARGETS.md-Prosa - `health_condition`/
  `steel-plates-fault`-Leak-Audit, `credit-g`-Leak-Audit (`credit_amount`
  26.9% direkt aus `leak_audit_importance.csv` nachgerechnet: 0.2688,
  Determinismus 0/68 aus 68 Zeilen in `leak_audit_determinism.csv`
  bestaetigt - `credit-g` hat kein README, die Zahl stand bisher nirgends
  als Text, nur im Artefakt selbst), Multilabel-Trios
  Threshold-Tuning-Nummerierung (1./2./3., konsistent in allen drei
  READMEs), `bank-marketing-ensemble-test`s "fruehe Bestaetigung" und
  `satimage`s Split-Size-Faktor 1.26x. Alle sieben bestaetigt - nur die
  bereits behobene `s6e5`-Dopplung war fehlerhaft, keine weiteren Funde in
  dieser Stichprobe.
- **Zweiter Beleg fuer das Learning-Curve-Plateau gesucht (2026-08-15) -
  Methodik-Fehler gefunden statt Bestaetigung.** `openml-synthetic-
  control-timeseries` (600 Zeilen, KLEINER als `credit-g`s 1000) zeigte
  "noch steigend" statt Plateau - direkter Widerspruch zur "kleine
  Datensaetze plateauen"-Hypothese. Ursache gezielt untersucht: `learning_
  curve.R`s Klassifikation bewertet den Regressions-Zuwachs relativ zur
  VOLLEN Score-Spannweite (max-min ueber alle getesteten Fraktionen).
  Bei `credit-g` dominierte ein einzelner Ausreisser bei winzigem n=20
  (BAcc-Einbruch auf 0.475, trotz `repeats=5`-Mittelung - bei n=20/5-fach-
  CV bleiben nur ~4 Zeilen je Fold) die Spannweite (0.178) und liess den
  tatsaechlich noch klar steigenden Trend (0.598 bei n=100 -> 0.653 bei
  n=1000) faelschlich unter der 10%-Plateau-Schwelle erscheinen (6.5%).

  **Fix**: `learning_curve.R` auf IQR (Q3-Q1) statt volle Spannweite als
  Nenner umgestellt - robust gegen genau diesen Einzelausreisser-Fall,
  ohne einen neuen Schwellenwert einzufuehren. **Ergebnis**: `credit-g`
  kippt von PLATEAU (6.5%) zu NOCH STEIGEND (23.1%) - der "erste
  Plateau-Fall" war ein Artefakt, keine echte Sättigung.
  Regressionsgetestet gegen `ci_smoke_test` (keine Klassifikationsaenderung)
  und alle vier weiteren real getesteten Projekte
  (`health_condition` 44.3%, `satimage` 29.7-59.3% je nach Nenner,
  `synthetic_control` 45.4%, alle weiterhin "noch steigend", keine
  ungewollte Kippung). **Nebenbefund**: `satimage` hat gar kein
  `023_learning_curve.R` im Projektordner (nur das Modul `learning_curve.R`
  ohne aufrufendes Skript/Artefakt) - die in TARGETS.md zitierten Zahlen
  stammen aus einer nicht mehr reproduzierbaren Ad-hoc-Analyse, hier nur
  handgerechnet aus den 5 dokumentierten Punkten nachvollzogen (echte
  Reproduzierbarkeits-Luecke, siehe TARGETS.md-Backlog-Notiz).

  **Fuer die Publikationsnotiz**: die "Learning-Curve ist projektspezifisch"
  -These aus dem vorherigen Diskussions-Entwurf ist damit HINFAELLIG - siehe
  korrigierter Diskussions-Abschnitt oben. Stattdessen ein methodischer
  Lehrsatz, aber PRAEZISE eingegrenzt statt pauschalisiert: die konkrete
  Implementierung "relativ zur VOLLEN Spannweite (max-min)" war
  anfaellig gegen einen Einzelpunkt-Ausreisser. `split_size_sensitivity.R`
  (Faktor relativ zum MINIMUM ueber alle ratios, je Ratio ueber
  `repeats=20` gemittelt) und `generalization_gap.R` (echter z-Score,
  SD-basiert ueber mehrere Referenz-Algorithmen) nutzen zwar dieselbe
  "selbstkalibrierend relativ zu einer Referenz"-PHILOSOPHIE, aber
  technisch ANDERE, bereits robustere Mechanismen (Minimum-Referenz bzw.
  SD statt Spannweite) - gezielt nachgeprueft, KEINE identische
  Schwachstelle gefunden. Nur `learning_curve.R`s spezifische
  max-min-Implementierung war betroffen.
- **Zweite Stichproben-Runde an Alt-Zellen (2026-08-15), wieder kein neuer
  Fehler gefunden**: 6 weitere Zellen direkt gegen die rohen
  `_artifacts`-CSVs nachgerechnet statt gegen Prosa geglaubt -
  `CreditScoringChallenge`-Leak-Audit (F1 0.88→"Nested F1 ≈ 0.413" im
  README bestaetigt), `PumpItUp`-Leak-Audit (`ward`-Share 0.2849 ≈ 28.5%
  exakt aus `leak_audit_importance.csv`), `geoai-aquaculture`-Leak-Audit
  (`re3_08`-Share 0.2748 ≈ 27.5% exakt), `health_condition`s Adversarial-
  Validation-AUC (0.6535 ≈ 0.654 exakt aus
  `adversarial_validation_results.csv`) sowie die beiden bisher nur mit
  blossem `✓` (ohne Zahl) markierten Zellen `health_condition`s
  Split-Size-Sensitivity (Faktor ≈1.47x bei `ratio=0.80`, min. CV bei
  `ratio=0.6`) und Seed-Stabilitaet (0.24x/0.09x, beide `flagged=FALSE`).
  Alle sechs bestaetigt. Damit sind jetzt 13 von >150 Zellen stichproben-
  artig direkt gegen Quelle verifiziert (plus die vollstaendige
  Learning-Curve-Spalte durch den Bugfix oben) - weiterhin nicht
  erschoepfend, aber ein wachsender, durchgehend fehlerfreier Ausschnitt
  ausserhalb der bereits bekannten `s6e5`-Korrektur.
- **Dritte Stichproben-Runde an Alt-Zellen (2026-08-16), wieder kein neuer
  Fehler gefunden**: 8 weitere Zellen aus 6 Projekten/2 Spalten (Leak-Audit,
  Generalisierungslücke, Split-Size-Sensitivity, Seed-Stabilität,
  Adversarial Validation) direkt gegen die rohen `_artifacts`-CSVs
  nachgerechnet - `openml-steel-plates-fault`s Determinismus-Fund (`V14`
  bei Wert 300, `n_group=43`, `purity=1`, `flagged=TRUE` - exakt der eine
  dokumentierte Fund) und Generalisierungslücke (z=-1.6337/-0.3902 ≈
  -1.63/-0.39 exakt), `openml-satimage`s Generalisierungslücke
  (z=1.0292/0.4967 ≈ 1.03/0.50 exakt) und Split-Size-Sensitivity (Faktor
  0.0333/0.0264 = 1.259 ≈ 1.26x exakt, `chosen_ratio=0.8` gegen
  `min(cv)` bei `ratio=0.6`), `openml-credit-g`s Leak-Audit
  (`credit_amount`-Share 0.2688 ≈ 26.9% exakt, 0/68 Determinismus-Zeilen
  bestaetigt `flagged=TRUE`), Split-Size-Sensitivity (Faktor 0.0640/0.0419
  = 1.527 ≈ 1.53x exakt) und Seed-Stabilitaet (0.1734/0.1657 ≈
  17.3%/16.6% exakt), `playground-series-s6e5`s Adversarial-Validation-AUC
  (0.499637 ≈ 0.4996 exakt) sowie `predictingsmartphoneAddiction_s6e8`s
  Adversarial-Validation-AUC/ESS-Ratio (0.564925/0.940007 ≈ 0.565/0.94
  exakt aus `adversarial_staged_results.csv`). Alle acht bestaetigt. Damit
  sind jetzt 21 von >150 Zellen stichprobenartig direkt gegen Quelle
  verifiziert - weiterhin nicht erschoepfend, aber ein durchgehend
  fehlerfreier Ausschnitt ueber inzwischen 3 Runden, ausserhalb der
  bereits bekannten `s6e5`-`148`/`149`-Korrektur.
- **Vierte Stichproben-Runde an Alt-Zellen (2026-08-17), wieder kein neuer
  Fehler gefunden**: 8 weitere Zellen aus 8 Projekten/4 Spalten
  (Adversarial Validation, Ensemble Selection, Threshold-Tuning,
  Multi-Label) direkt gegen die rohen `_artifacts`-CSVs nachgerechnet -
  `drivendata_richter`s Adversarial-Validation-AUC (0.500227 ≈ 0.5002
  exakt), `FinancialStressPredictionChallenge`s AUC (0.49712 ≈ 0.4971
  exakt), `playground-series-s6e6`s AUC (0.499587 ≈ 0.4996 exakt),
  `playground-series-s5e12`s AUC (0.627223 ≈ 0.627 exakt - erstmals direkt
  gegen die Roh-CSV statt nur gegen die README-Tabelle, die diese Zeile
  erst kuerzlich ergaenzt hatte), `health_condition`s Ensemble-Selection
  (`ensemble_selection_results.csv`: equal_blend BAcc 0.9524 >
  best_single 0.9484, Ensemble-Gewinn bestaetigt), `eeg-eye-state`s
  Threshold-Tuning (bacc_plain 0.9271 -> bacc_tuned 0.9274, tatsaechlich
  modest wie in der Tabelle behauptet, nicht Null und nicht gross),
  `synthetic_control`s Threshold-Tuning (bacc_plain = bacc_tuned = 0.95
  exakt identisch - bestaetigt "keine Verbesserung, exakt balancierte
  Klassen" woertlich) sowie `openml-yeast-multilabel`s Binary-Relevance-/
  Threshold-Tuning-Artefakte (`binary_relevance_multilabel_summary.csv`/
  `threshold_tuning_multilabel_summary.csv`: reale, plausible Metriken -
  Accuracy-getunte Schwelle schlaegt Default auf 3 von 4 Metriken).
  Alle acht bestaetigt. Damit sind jetzt 29 von >150 Zellen
  stichprobenartig direkt gegen Quelle verifiziert - weiterhin nicht
  erschoepfend, aber ein durchgehend fehlerfreier Ausschnitt ueber
  inzwischen 4 Runden, ausserhalb der bereits bekannten
  `s6e5`-`148`/`149`-Korrektur.
- **Fünfte Stichproben-Runde an Alt-Zellen (2026-08-17), kein Tabellenfehler,
  aber eine dokumentierenswerte Nuance gefunden**: 9 weitere Zellen aus 6
  Projekten/5 Spalten (Seed-Stabilität, Generalisierungslücke, Ensemble
  Selection, Split-Size-Sensitivity, Multi-Label) direkt gegen die rohen
  `_artifacts`-CSVs nachgerechnet - `eeg-eye-state`s Seed-Stabilität
  (0.2328/0.2140 ≈ 0.23x/0.21x exakt) und Generalisierungslücke
  (z=1.6676/1.2718 ≈ 1.67/1.27 exakt), `synthetic_control`s Split-Size-
  Sensitivity (Faktor 0.0319/0.0254 = 1.255 ≈ 1.25x exakt, `min(cv)` bei
  `ratio=0.6`), Generalisierungslücke (z=0.0454/-0.6345 ≈ 0.05/-0.63
  exakt) und Seed-Stabilität (SD=0 exakt, beide Checks) sowie
  `openml-scene-multilabel`/`openml-birds-multilabel`s Binary-Relevance-
  Artefakte (reale, plausible Metriken - `scene` macro_f1 0.703 vs.
  `birds` macro_f1 0.188, letzteres plausibel schwaecher bei einer
  bioakustischen Aufgabe mit staerkerem Klassenungleichgewicht).
  `predictingsmartphoneAddiction_s6e8`s Ensemble-Selection bestaetigt
  (greedy_ensemble AUC 0.9560 > best_single 0.9556, passend zur `✓✓`-
  Zelle). **Nuance bei `playground-series-s6e6`s Ensemble-Selection**: die
  Roh-CSV (`ensemble_selection_results.csv`) zeigt best_single BAcc
  0.9638 > greedy_ensemble 0.9633 > equal_blend 0.9580 - der Greedy-
  Ensemble GEWINNT bei diesem konkreten Lauf NICHT gegen das beste
  Einzelmodell. Kein Tabellenfehler (die Zelle behauptet nur "Methodik-
  Test"/Mechanismus-Bestätigung, keinen Performance-Gewinn), aber ein
  Beleg dafuer, dass Ensemble Selection nicht immer gewinnt - konsistent
  mit der allgemeinen "schwache/korrelierte Mitglieder verwaessern das
  Ensemble"-Lehre aus dem FT-Transformer-Abschnitt, hier bisher nirgends
  explizit vermerkt. Alle neun Zellen inhaltlich bestaetigt (keine falsche
  Tabellenzahl gefunden). Damit sind jetzt 38 von >150 Zellen
  stichprobenartig direkt gegen Quelle verifiziert - weiterhin nicht
  erschoepfend, aber ein durchgehend fehlerfreier Ausschnitt ueber
  inzwischen 5 Runden, ausserhalb der bereits bekannten
  `s6e5`-`148`/`149`-Korrektur.
- **Sechste Stichproben-Runde an Alt-Zellen (2026-08-17), kein Tabellenfehler,
  aber eine echte, bisher unbekannte Reproduzierbarkeits-Luecke gefunden**:
  6 weitere Zellen aus 5 Projekten/4 Spalten (Threshold-Tuning, Leak-Audit,
  Seed-Stabilitaet, Ensemble Selection) direkt gegen Quelle nachgeprueft -
  `openml-steel-plates-fault`s Threshold-Tuning (`bacc_prior`=0.8402 vs.
  `bacc_grid`=0.8320 ≈ 0.840 vs. 0.832 exakt, "1/prior schlaegt Grid"
  woertlich bestaetigt), `openml-credit-g`s Threshold-Tuning (Existenz +
  plausible Verbesserung bacc_plain 0.6845 -> bacc_tuned 0.6964
  bestaetigt), `eeg-eye-state`s Leak-Audit (Top-Feature `V6` 14.0% Share,
  weit unter der 50%-Schwelle - "unauffaellig" bestaetigt),
  `synthetic_control`s Leak-Audit (Top-Feature `col_4` 14.2% Share,
  ebenfalls unauffaellig) sowie `openml-bank-marketing-ensemble-test`s
  Ensemble-Selection (Log-Datei statt CSV, da aelteres Projekt ohne
  `_artifacts`-Konvention: Greedy-Ensemble TEST-AUC 0.9348 > bestes
  Einzelmodell 0.9326 > Blend 0.9307 - echter Ensemble-Gewinn bestaetigt).

  **Fund**: `openml-satimage-multiclass`s Seed-Stabilitaets-Zelle stand
  bisher als bloßes `✓` ohne Zahl/Quelle in der Tabelle, ihre Zahlen
  (0.23x/0.21x) stammten nur aus einem TEMPLATE-Config-Kommentar
  (`000_config.R`, Zeile ~617). Der Projektordner hat KEIN
  `092_seed_stability.R` (nur das Modul `seed_stability.R`, wie beim
  bereits bekannten `023_learning_curve.R`-Nebenbefund) UND keine
  `seed_stability_results.csv` - dieselbe Reproduzierbarkeits-Luecken-
  Klasse wie bei der Lernkurve, bisher aber nirgends dokumentiert.
  Anders als befuerchtet KEIN Vertrauensproblem: `README.md` (Abschnitt
  "Seed-/Hyperparameter-Rausch-Stabilitaet", Zeile ~112-121) dokumentiert
  die Zahlen mit konkreten SD-Werten (SD=0.0025/0.23x, SD=0.0023/0.21x,
  Referenz-SD=0.0108) - die Behauptung ist also durch eine echte,
  spezifische Textquelle gedeckt, nur das ausfuehrbare Artefakt fehlt.
  Tabellenzelle entsprechend nachgetragen (Zahlen + Praezisierung, dass
  dies keine neue, ungeklaerte Luecke ist, sondern dieselbe bereits fuer
  Learning-Curve bekannte Kategorie). Damit sind jetzt 44 von >150 Zellen
  stichprobenartig direkt gegen Quelle verifiziert - weiterhin nicht
  erschoepfend, aber ein durchgehend inhaltlich fehlerfreier Ausschnitt
  ueber inzwischen 6 Runden, ausserhalb der bereits bekannten
  `s6e5`-`148`/`149`-Korrektur.
- **Siebte Stichproben-Runde an Alt-Zellen (2026-08-17) - ECHTER
  Tabellenfehler gefunden und korrigiert (zwei veraltete Learning-Curve-
  Zellen).** 4 Zellen aus 3 Projekten/2 Spalten (Adversarial Validation,
  Learning-Curve) direkt gegen Quelle nachgerechnet -
  `geoai-aquaculture-pond-identification-challenge`s beide Adversarial-
  Validation-Kennzahlen bestaetigt (roh 0.999981 ≈ 0.99998 exakt,
  Band-Mittel 0.977847 ≈ 0.978 exakt aus
  `adversarial_validation_aggregates_results.csv` - die wichtigste
  Einzelzelle der ganzen Tabelle, bisher noch nie direkt nachgerechnet,
  jetzt bestaetigt).

  **Fund**: `synthetic_control`s und `eeg-eye-state`s Learning-Curve-Zellen
  zeigten "17.5%" bzw. "14.7%" - beides die ALTE Max-Min-Spannweiten-
  Prozentzahl von VOR dem IQR-Fix (2026-08-15), nie aktualisiert, obwohl
  der Diskussions-Abschnitt oben (Zeile ~242) fuer `synthetic_control`
  bereits korrekt "45.4%" zitierte - ein interner Widerspruch zwischen
  Tabelle und Diskussion, der bisher unbemerkt blieb. Nachgerechnet mit
  der aktuellen IQR-Formel: `synthetic_control` 45.4% (statt 17.5%),
  `eeg-eye-state` 31.0% (statt 14.7%) - beide Klassifikationen bleiben
  "NOCH STEIGEND" (keine Kippung, nur die Prozentzahl war stale), auch mit
  dem `min_rows_per_fold`-Filter unveraendert (bei `eeg-eye-state` ohnehin
  kein Punkt unter der Schwelle, bei `synthetic_control` sogar noch
  klareres Signal: 78.0% gefiltert vs. 45.4% ungefiltert). Beide
  Tabellenzellen direkt korrigiert. **Lehre**: ein Bugfix an einem
  gemeinsam genutzten Modul (`learning_curve.R`) muss auch rueckwirkend
  in ALLEN bereits befuellten Tabellenzellen nachgezogen werden, nicht nur
  in neu hinzukommenden - dieser Fehler waere durch reines "neue Zeilen
  pruefen" nie gefunden worden. Damit sind jetzt 48 von >150 Zellen
  stichprobenartig direkt gegen Quelle verifiziert, davon 1 echter,
  korrigierter Tabellenfehler (2 betroffene Zellen) - der erste seit der
  `s6e5`-`148`/`149`-Korrektur.
- **Achte Stichproben-Runde an Alt-Zellen (2026-08-17) - ein falscher
  Verdacht ausgeraeumt, eine echte Nachvollziehbarkeits-Luecke gefunden.**
  4 Zellen aus 3 Projekten/3 Spalten (Learning-Curve, Generalisierungslücke,
  Threshold-Tuning, Split-Size-Sensitivity) geprueft.

  **Falscher Verdacht ausgeraeumt**: nach dem Fund in Runde 7 (veraltete
  Learning-Curve-Prozentzahlen) lag der Verdacht nahe, `credit-g`s "23.1%"
  koennte ebenfalls stale sein. Gezielt geprueft: `credit-g`s lokales
  `023_learning_curve.R` reicht `cv_folds` NICHT an `report_learning_curve()`
  durch (wie `eeg-eye-state`/`synthetic_control` vor der Korrektur) - der
  `min_rows_per_fold`-Filter ist dort also inaktiv, und "23.1%" IST die
  aktuell korrekte Zahl fuer das, was das Projekt-eigene Skript heute
  produzieren wuerde (ungefiltert 23.1%, gefiltert waere 45.9% - aber ohne
  `cv_folds`-Parameter kommt das Skript gar nicht dahin). Keine Korrektur
  noetig - explizit gegengeprueft statt nur angenommen.

  `openml-eeg-eye-state-timeseries`s Split-Size-Sensitivity-"strukturell
  uebersprungen, >5000 Zeilen"-Begruendung bestaetigt (`train.csv`: 14980
  Datenzeilen, klar ueber der `split_sensitivity_max_n`-Schwelle).

  **Nachvollziehbarkeits-Luecke gefunden** (kein klarer Fehler, aber nicht
  sauber belegt): `health_condition`s Threshold-Tuning-Zelle behauptet "OOF
  raw argmax 0.872 -> 0.945 BAcc, +0.074", zugeschrieben Commit `70745fb`.
  Weder `threshold_tuning_results.csv` noch `threshold_tuning_ranger_
  results.csv` enthalten dieses Zahlenpaar (die dortigen `bacc_plain`-Werte
  liegen bei 0.874-0.940, nicht 0.872, und kein `bacc_tuned`-Wert liegt bei
  0.945). Der zitierte Commit `70745fb` selbst nennt in seiner Commit-
  Message eine ANDERE Zahl ("+0.014 BAcc ueber dem Grid") - plausibel
  vereinbar (0.872->0.945 waere der GESAMTEFFEKT ggue. komplett
  ungetunter Vorhersage, +0.014 nur der INKREMENTELLE Gewinn des
  kontinuierlichen Optimierers ueber den bereits grid-korrigierten Wert
  hinaus - zwei verschiedene Baselines, kein Widerspruch), aber keine
  Quelle im Repo belegt die konkrete 0.872/0.945-Zahl direkt. Dieselbe
  Kategorie wie die `satimage`-Seed-Stabilitaets-Luecke aus Runde 6, hier
  aber OHNE README-Beleg - eine reine TARGETS.md-Prosa-Behauptung ohne
  auffindbares Artefakt. `health_condition`s Generalisierungsluecken-Zelle
  ("+0.0025, SD 0.0032") aehnlich: die Roh-CSV enthaelt nur die bereits
  fertigen `z_vs_reference`-Werte (-0.32/-0.05) der Kandidaten, nicht die
  Referenzverteilung selbst - eine Rueckrechnung (z = (gap-0.0025)/0.0032)
  ergibt fuer beide Kandidaten die richtige Groessenordnung/das richtige
  Vorzeichen, aber keine exakte Bestaetigung (Bootstrap-Rauschen in der
  eigentlichen z-Berechnung). Kein Tabellenfehler, aber ein Kandidat fuer
  eine kuenftige README-Ergaenzung bei `health_condition` selbst (Template-
  eigenes Projekt, hat noch kein eigenes README wie die `ML_Learning`-
  Projekte). Damit sind jetzt 52 von >150 Zellen stichprobenartig direkt
  gegen Quelle verifiziert.
- **Neunte Stichproben-Runde an Alt-Zellen (2026-08-17), kein neuer Fehler
  gefunden - diesmal Schwerpunkt auf bisher ungeprueften Zahlen UND auf
  der Legitimitaet der `—`-Zellen selbst.** 7 Zellen aus 6 Projekten/4
  Spalten (Adversarial Validation/ESS, Threshold-Tuning, Multi-Label) plus
  3 komplette `—`-Zeilen direkt gegen Quelle geprueft -
  `geoai-aquaculture`s ESS-Zahl (`importance_weight_ess.csv`,
  `index_means`-Repraesentation: `ESS_frac`=0.0259 ≈ 2.6% exakt, damit
  auch die letzte noch offene Zahl dieser wichtigsten Tabellenzeile
  bestaetigt), `predictingsmartphoneAddiction_s6e8`s Threshold-Tuning-
  "keine Artefakte vorhanden"-Behauptung (gezielte Suche nach
  `*threshold*`-Dateien im Projektordner: tatsaechlich leer, Abwesenheits-
  Behauptung bestaetigt statt nur angenommen) sowie `openml-scene-
  multilabel`s/`openml-birds-multilabel`s Threshold-Tuning-Artefakte
  (`threshold_tuning_multilabel_summary.csv`: reale, plausible Metriken -
  Accuracy-getunte Schwelle schlaegt Default bei beiden auf den meisten
  Metriken, wie schon bei `yeast` in Runde 4).

  **Legitimitaets-Check der `—`-Zeilen** (bisher nie systematisch
  gemacht - die Methodik-Notiz oben warnt zwar vor Fehlinterpretation der
  `—`-Zellen, aber niemand hatte bisher stichprobenartig verifiziert, dass
  die Zeilen tatsaechlich KEINE der 9 Spalten abdecken): `health-
  condition-huyen-sanity-tests` (komplett `—`) hat reale Skripte
  (Perturbation-/Invarianz-/Directional-Tests nach Huyen 2022) - deckt
  aber keine der 9 Tabellenspalten ab, sondern eine ganz andere
  diagnostische Dimension (Modell-Sanity-Checks), die noch keine eigene
  Spalte hat. `openml-adult-income` (Baseline/Tuning/Fehleranalyse-
  Skripte 020-147) und `openml-amazon-access` (nur 020/036/037) ebenfalls
  geprueft - beide haben echte Skripte, aber keins davon deckt eine der 9
  Spalten ab. Alle drei `—`-Zeilen also legitim, keine versehentlich
  unbearbeiteten Projekte. Damit sind jetzt 59 von >150 Zellen
  stichprobenartig direkt gegen Quelle verifiziert (plus 3 zusaetzlich
  auf Zeilen-Legitimitaet gepruefte `—`-Projekte), durchgehend
  fehlerfrei ueber die 9. Runde.
- **Zehnte Stichproben-Runde an Alt-Zellen (2026-08-17), kein neuer Fehler
  gefunden - Schwerpunkt auf bisher nur locker (README-Prosa statt
  Roh-Artefakt) bestaetigten Zellen.** 5 Zellen aus 4 Projekten/3 Spalten
  (Generalisierungslücke, Leak-Audit, Ensemble/Stacking) direkt gegen
  Roh-Artefakte nachgerechnet - `credit-g`s Generalisierungslücke
  (`generalization_gap_results.csv`: z=-0.0177/-0.4593, beide
  `flagged=FALSE` - "unauffällig" bestätigt, bisher nur als blosses `✓`
  ohne Zahl in der Tabelle), `health_condition`s Leak-Audit-Exaktwert
  (`stress_level`-Share 0.429144 ≈ 42.9% exakt) sowie `playground-series-
  s6e5`s Logits-Stacking-Negativbefund (`stacking_results.csv`: AUC-Delta
  0.941286-0.941121=0.000165 ≈ +0.00016 exakt, Rechenaufwand-Verhältnis
  1441.75s/74.79s=19.28x ≈ "~19x" exakt - beide Zahlen der urspruenglichen
  `s6e5`-Korrektur jetzt erstmals bis auf die Roh-CSV zurueckverfolgt).

  **Tiefste Nachpruefung bisher**: `CreditScoringChallenge`s Kernbefund
  (F1 0.88->0.41, der GROESSTE reale Leak-Fund des gesamten Oekosystems)
  war in Runde 2 nur gegen README-Prosa geprueft worden - jetzt bis auf
  die zugrundeliegenden Roh-CSVs verfolgt: `clean_baseline_results.csv`
  zeigt `full`-Feature-Set F1=0.8757 (≈0.88) vs. `minus_repay_and_funding`
  (das "ehrliche" Feature-Set) F1=0.418 (≈0.42), `threshold_tuning_
  summary.csv` zeigt `nested_f1_ehrlich`=0.4129 (≈0.413, die im README
  zitierte Zahl) - UND das README dokumentiert eine externe Bestätigung
  (Leaderboard-Score 0.4191, traf die nested-CV-Schätzung fast exakt). Der
  wichtigste Einzelfund der gesamten Tabelle ist damit jetzt vollständig,
  bis auf die Rohdaten UND eine externe Quelle zurückverfolgt bestätigt.
  Damit sind jetzt 64 von >150 Zellen stichprobenartig direkt gegen Quelle
  verifiziert, durchgehend fehlerfrei über zehn Runden.

## Diskussion für die Publikationsnotiz (2026-08-15)

Beantwortet Schritt 5 unten: welche Komponenten sind projekttyp-unabhängig
robust (der Mechanismus funktioniert zuverlässig, unabhängig von der
Domäne), welche sind projektspezifisch (die Ergebnisgröße/Relevanz hängt
an konkreten Dateneigenschaften)? Diese Unterscheidung ist fuer die
Publikationshypothese aus `AGENTS.md` ("Trust-/Diagnose-Schicht als
staerkster Kern") wichtiger als reine Trefferquoten.

### Projekttyp-unabhängig robust (Mechanismus haelt ueber sehr
unterschiedliche Domaenen/Aufgabentypen)

- **Leak-Audit (015)**: 8 Bestätigungen über Kaggle/Zindi/DrivenData/OpenML,
  binär/multiclass, Domänen von Gesundheit bis Kredit bis Infrastruktur bis
  Zeitreihen-Klassifikation. Genau **1 echter Fund** (`CreditScoringChallenge`,
  F1 0.88→0.41) bei **0 Fehlalarmen** über die restlichen 7 Projekte - exakt
  das erwartete Muster fuer einen funktionierenden Guard (selten ausloesen,
  aber wenn, dann berechtigt).
- **Generalisierungslücke (136)**: über alle 6 real getesteten Projekte
  unauffaellig, trotz enormer Groessenspanne (1941 bis 690.088 Zeilen).
  Bisher **kein einziger realer Beleg fuer Test-Harness-Optimismus** - ein
  konsistentes Negativergebnis, das indirekt bestaetigt, dass das
  `AutoTuner`-Design (verschachteltes Resampling) haelt, was es verspricht,
  unabhaengig vom Projekttyp.
- **Adversarial Validation (115)**: trennt zuverlaessig echten, extremen
  Shift (`geoai-aquaculture`, AUC 0.99998) von 5 strukturell sehr
  unterschiedlichen unauffaelligen Faellen (Zindi/Kaggle/OpenML, AUC
  0.4971-0.654) - funktioniert als Diskriminator unabhaengig von Domaene
  oder Datensatzgroesse.
- **Seed-/Hyperparameter-Stabilitaet (092)**: durchgehend niedrige relative
  Streuung (0.17x-0.24x der CV-Referenz) ueber 5 Projekte. Ausreisser:
  `synthetic_control` mit SD=0.000 (vollstaendig deterministisch) - eher ein
  Artefakt eines besonders sauber trennbaren synthetischen Datensatzes als
  ein generalisierbarer Befund, sollte in einer Publikationsnotiz nicht als
  typischer Wert zitiert werden.
- **Learning-Curve (023) - NOCH STEIGEND ueber alle 5 realen Projekte,
  unabhaengig von der Groesse (korrigiert 2026-08-15, praezisiert
  2026-08-17)**: `health_condition` (690k Zeilen), `satimage` (6430),
  `credit-g` (1000), `synthetic_control` (600) und `eeg-eye-state` (14980)
  zeigen alle "noch steigend" - die urspruenglich vermutete Groessen-
  Korrelation ("kleine Datensaetze plateauen") war ein Methodik-Artefakt
  (IQR-Nenner, siehe Abschnitt unten), kein echter Befund. **Wichtige
  Praezisierung (2026-08-17)**: die gezielte Suche nach einem Plateau-Fall
  (`wdbc-plateau-test`, ein klassisch "sehr sauber trennbarer" Datensatz)
  deckte einen ZWEITEN, verwandten Methodik-Fund auf - selbst mit dem
  IQR-Fix blieb dieser eindeutig saettigende Datensatz als "noch steigend"
  klassifiziert, weil winzige Anfangs-n-Punkte die Regression dominierten.
  Erst ein weiterer Fix (Mindest-n-Filter vor der Regression) liess ihn
  korrekt als PLATEAU erkennen - UND bestaetigte per Regressionstest, dass
  die 5 realen Projekte auch mit dem Fix "noch steigend" bleiben (teils
  klarer). Damit ist "NOCH STEIGEND ueberall" jetzt ein verlaesslicherer
  Nullbefund statt einer unbestaetigten Vermutung: der Mechanismus KANN
  nachweislich Plateaus erkennen (an einem gezielt gebauten Fall bestaetigt),
  tut es bei den bisher getesteten echten Kaggle/OpenML-Datensaetzen aber
  tatsaechlich nicht - "Ranger/LightGBM plateauen im getesteten
  Fraktionsbereich bei REALEN Projekten praktisch nie" ist damit ein
  belastbarerer Satz als vorher.

### Projektspezifisch (Effektgroesse/Relevanz haengt an konkreten
Dateneigenschaften, nicht nur "funktioniert der Mechanismus")

- **Threshold-Tuning (130), Effektgroesse**: reicht von einem GROESSTEN
  Einzelhebel des gesamten Templates (`health_condition`, +0.074 BAcc,
  unbalancierte 3 Klassen) bis zu GENAU NULL Wirkung
  (`synthetic_control`, exakt balancierte 6 Klassen - keine
  Multiplikator-Korrektur noetig). Der Mechanismus selbst bricht nie, aber
  sein NUTZEN haengt sichtbar an Klassenungleichgewicht - eine Aufgabe ohne
  Ungleichgewicht hat strukturell nichts zu gewinnen.
- **Group-aware CV** (noch keine eigene Spalte, siehe Abschnitt oben) -
  **ZWEITE unabhaengige Klassifikations-Bestaetigung (2026-08-17,
  ADR-003-Backport-Kriterium erfuellt)**: `eeg-eye-state-timeseries`
  (Zeit-Block-Nachbarschaft, -21.3 BAcc-Punkte) und
  `uci-parkinsons-voice-groupcv` (echte Entitaets-Wiederholung/wiederholte
  Aufnahmen desselben Probanden, -23.6 BAcc-Punkte) zeigen AEHNLICH grosse
  Luecken trotz STRUKTURELL VERSCHIEDENER Leck-Mechanismen - staerkere
  Evidenz als eine blosse Wiederholung desselben Mechanismus waere. Bei
  `uci-parkinsons-voice-groupcv` zusaetzlich ein No-Signal-Check bestanden
  (Featureless-Baseline bei Group-CV nahe Zufallsniveau, 0.469 - Rangers
  0.568 ist also echtes, wenn auch schwaches Signal). Bleibt trotzdem
  strukturell PROJEKTSPEZIFISCH relevant (nur wo echte Entitaets-/
  Zeitstruktur existiert - komplett irrelevant bei `synthetic_control`,
  i.i.d. Zeilen) - kein Mechanismus-Versagen dort, sondern schlicht nicht
  anwendbar. **Backport (2026-08-17) abgeschlossen**: `group_resampling.R`
  liegt jetzt im Template-Root, siehe
  [`REFERENZ_GROUP_AWARE_CV.md`](REFERENZ_GROUP_AWARE_CV.md).
- **FT-Transformer-Ensemble-Diversitaet**: CPU-Machbarkeit war projekt-
  unabhaengig **innerhalb** der getesteten Groessenspanne, aber selbst NICHT
  projekttyp-unabhaengig - der zweite Datenpunkt (`eeg-eye-state`, 14980
  Zeilen) ist bereits CPU-untragfaehig bei Produktionseinstellungen
  (adr/002-Zeilenschwelle liegt irgendwo zwischen 600 und 14980). Der
  Dekorrelations-BEFUND selbst dreht sich mit dem zweiten Datenpunkt: auf
  dem sauberen, kleinen `synthetic_control` (600 Zeilen, exakt trennbar)
  praktisch KEINE Dekorrelation (Kappa 0.976), auf dem rauschigeren,
  groesseren (aber subgesampelten) `eeg-eye-state` (n=4500) dagegen
  DEKORRELIERT (Kappa 0.581) - erste Evidenz, dass Datensatz-"Sauberkeit"
  (nicht nur Groesse) der eigentliche Treiber sein koennte, ob ein FT-
  Transformer andere Fehler macht als ein Baumensemble. Der tatsaechliche
  Blend-NUTZEN ist bei BEIDEN Projekten inzwischen negativ bestaetigt (nicht
  mehr offen): bei `synthetic_control` mangels Dekorrelation, bei
  `eeg-eye-state` (`097_weighted_blend.R`, 2026-08-17, einzelner Train/
  Tune/Eval-Split statt teurer CV) trotz ECHTER Dekorrelation - weder der
  skalare (0.8403) noch der per-Klassen-getunte Blend (0.8378) schlagen
  Ranger allein (0.8439), die Gewicht-Optimierung schaltete FT-Transformer
  fast komplett ab (~0.07-0.10 statt 0.5). **Hebel 1 ist damit 0/2 -
  aktuell KEIN Backport-Kandidat.** Mit einer methodischen Einschraenkung:
  der guenstige 1-Split-Test gab FT-Transformer weniger Trainingsdaten
  (2700 statt ~3600 Zeilen) und keine Fold-Mittelung als der urspruengliche
  `096`-CV-Test, ein staerker trainierter Kandidat koennte das Bild noch
  aendern - aber auf Basis der bisherigen 2 Projekte ist der Befund ein
  klares, wenn auch vorlaeufiges Negativergebnis, kein offener Faden mehr.

### Methodischer Hinweis fuer die Publikationsnotiz selbst

Die vielen `—`-Zellen (Marker-Luecken) duerfen NICHT als Abdeckungs-Fehler
in einer Publikation dargestellt werden - die meisten Module wurden erst
zu einem bestimmten Zeitpunkt der Projekt-Historie eingefuehrt
(`022`/`023`/`092` z.B. erst 2026-08-13, `148`/`149` erst 2026-08-11), die
betroffenen Projekte sind aelter. Eine ehrliche Publikationsnotiz sollte
das explizit als Limitation nennen (retrospektive Tabelle über eine
organisch gewachsene Projekt-Historie, keine von Anfang an einheitlich
instrumentierte Studie) statt Bestaetigungszahlen unkommentiert als
Abdeckungsquote zu praesentieren.

## Nächste Schritte für diese Tabelle

1. ~~`?`-Zellen gezielt auflösen~~ **ERLEDIGT (2026-08-15)**: alle 9 Spalten
   durchgearbeitet (Reihenfolge: Leak-Audit → Adversarial Validation →
   Split-Size-Sens./Learning-Curve/Seed-Stabilität → Generalisierungslücke
   → Threshold-Tuning → Ensemble Selection), 0 `?`-Zellen verbleibend.
2. ~~Fehlende Projekte ergänzen~~ **ERLEDIGT (2026-08-15)**: alle
   `ML_Learning`-Ordner gegen die Tabelle abgeglichen. Die meisten Luecken
   waren Regressionsprojekte (out of scope fuer dieses Klassifikations-
   Template: `AStepAheadOfdrought`, `SubjektDatensatz`, `WineQualityDataset`,
   `dataCar-exposure-offset-test`, `openml-diamonds-regression`,
   `openml-house-prices-regression`, `openml-bike-sharing-leak-test`,
   `playground-series-s5e9`, `tweet`) oder keine echten Workflow-Projekte
   (`niftis` = nur Rohdaten, `openml-drift-detection-test` = Ad-hoc-
   Feature-Testskripte ohne Kernworkflow). Ein echter Fund: `DAT_Parkinsons`
   (Klassifikation, `classif.*`-Metriken) hat bisher NUR `000_config.R`/
   `db_logging.R` - kein einziges Kernskript gelaufen, daher (noch) keine
   Tabellenzeile wert. `playground-series-s5e12` (Kaggle Diabetes,
   binaer/AUC) war der einzige echte fehlende Kandidat - ergaenzt, inkl.
   eines weiteren `148`/`149`-Namenskollisionsfalls (drittes Projekt nach
   `s6e5`/`s6e6` mit diesem Muster) und einer Korrektur unterwegs: die
   Threshold-Tuning-Zelle war zunaechst faelschlich als `✓` markiert, weil
   das Skript existiert - fehlende Artefakte + `warn_if_threshold_step_low_
   value()` zeigten aber, dass es strukturell uebersprungen wird (AUC ist
   schwellenwertunabhaengig, identisch zu `s6e8`s Muster), auf `~` korrigiert.
3. ~~Stichproben-Gegenprobe: die s6e5/s6e6-Dopplung klären~~ **ERLEDIGT
   (2026-08-15)**: echter Fehler bestätigt - `s6e5` hat gar kein `148`/
   `149` im Ordner, nur `140_stack_ensemble.R` (ein ANDERES Verfahren,
   Logits-Stacking-Meta-Learner, laut TARGETS.md negativ getestet).
   `s6e5`s Zelle von faelschlich `✓ (5. Bestätigung...)` auf `✗` (verworfen,
   falsches Verfahren) korrigiert. `s6e6`s `✓` bleibt korrekt, aber mit
   Klarstellung ergänzt: dort heisst das Skript lokal
   `146_ensemble_selection.R`, nicht `148`/`149` wie im aktuellen Template -
   **Lehre für weitere Stichproben**: `?`/`—`-Zellen wurden strikt per
   Dateiname geprüft (robust), bereits VORHANDENE `✓`-Zellen aus der
   allerersten Entwurfsfassung dagegen nicht - genau dort sass dieser
   Fehler.
4. ~~Weitere Stichproben unter bereits gefüllten Alt-Zellen~~ **ZEHN
   RUNDEN ERLEDIGT (2026-08-15/2026-08-17)**: 7+6+8+8+9+6+4+4+7+5 = 64
   Alt-Zellen aus insgesamt 22 Projekten/12 Spalten direkt gegen Quelle
   (Artefakt-CSV/README/Commit-Historie, nicht nur TARGETS.md-Prosa)
   nachgeprüft, plus 3 komplette `—`-Zeilen auf Legitimität geprüft (9.
   Runde). **Ein echter, korrigierter Tabellenfehler** (7. Runde):
   `synthetic_control`s/`eeg-eye-state`s Learning-Curve-Zellen zeigten
   veraltete Max-Min-Prozentzahlen von vor dem IQR-Fix (17.5%/14.7% statt
   korrekt 45.4%/31.0%). Drei weitere echte Nuancen/Lücken gefunden und
   nachgetragen statt als Fehler behandelt: `s6e6`s Ensemble-Selection
   (5. Runde), `satimage`s Seed-Stabilität (6. Runde) und
   `health_condition`s Threshold-Tuning-/Generalisierungslücken-Zahlen
   (8. Runde). `geoai-aquaculture`s komplette Adversarial-Validation-Zeile
   ist vollständig bestätigt (Runde 7/9). Ein ausgeräumter Verdacht bei
   `credit-g`s Learning-Curve (8. Runde). **Tiefste Nachprüfung** (10.
   Runde): `CreditScoringChallenge`s Kernbefund (F1 0.88->0.41, groesster
   realer Leak-Fund des Oekosystems) bis auf die Roh-CSVs UND eine
   externe Quelle (Leaderboard-Score 0.4191, bestätigt die nested-CV-
   Schätzung 0.4129) zurückverfolgt - vorher nur gegen README-Prosa
   geprüft. Siehe Detailauflistungen der 2.-10. Runde im Abschnitt "Was
   diese erste Fassung zeigt" oben. Nicht erschöpfend (die Tabelle hat
   >150 Zellen, ~43% bisher stichprobenartig geprüft), aber die Abdeckung
   ist jetzt breit und tief genug (fast jedes Projekt mindestens einmal,
   die wichtigsten Befunde bis auf Rohdaten/externe Quellen
   zurückverfolgt) - **weitere Runden werden hier eingestellt**, der
   Grenznutzen ist erschöpft, ohne einen dedizierten neuen Anlass (z.B.
   einen weiteren Modul-Bugfix, der rückwirkend geprüft werden müsste).
   **Lehre für künftige Modul-Bugfixes** (aus Runde 7/8): ein Fix an einem
   gemeinsam genutzten Modul reicht nicht mit reinem Regressionstest der
   Skripte - auch bereits befüllte Tabellenzellen, die auf dem alten
   Verhalten beruhen, müssen aktiv nachgezogen werden (aber NICHT blind -
   erst prüfen, ob das jeweilige Projekt-Skript den Fix überhaupt schon
   nutzt).
5. ~~Zusammenfassung/Diskussion für die Publikationsnotiz ableiten~~
   **ERLEDIGT (2026-08-15)**: siehe Abschnitt "Diskussion für die
   Publikationsnotiz" oben - vier robuste, projekttyp-unabhängige
   Komponenten (Leak-Audit, Generalisierungslücke, Adversarial Validation,
   Seed-Stabilität) und vier projektspezifische Befunde (Learning-Curve-
   Plateau, Threshold-Tuning-Effektgröße, Group-aware CV, FT-Transformer-
   Diversität) identifiziert, plus ein methodischer Hinweis zur
   Marker-Lücken-Interpretation für die Notiz selbst.
6. ~~Perspektivisch: zweiter Beleg für Group-aware-CV-Klassifikationsseite~~
   **ERLEDIGT (2026-08-17)**: `uci-parkinsons-voice-groupcv` (echte
   Entitaets-Wiederholung, -23.6 BAcc-Punkte) bestaetigt `eeg-eye-state`
   (Zeit-Block-Nachbarschaft, -21.3 Punkte) mit einem strukturell anderen
   Leck-Mechanismus - ADR-003-Backport-Kriterium erfuellt, siehe Diskussion
   oben/TARGETS.md. Backport von `group_resampling.R` als eigenstaendiges
   Klassifikations-Modul ins Template ebenfalls erledigt (2026-08-17),
   siehe `REFERENZ_GROUP_AWARE_CV.md`.
   ~~Learning-Curve-Plateau~~ **umformuliert statt bestaetigt
   (2026-08-17)**: der urspruengliche Punkt war durch den `credit-g`-
   IQR-Fix bereits obsolet (kein Plateau-Fund mehr, den man haette
   bestaetigen koennen). Stattdessen gezielt `wdbc-plateau-test` gebaut
   (klassisch "sehr sauber trennbarer" Datensatz) - deckte einen zweiten
   Methodik-Fund auf (Mindest-n-Filter noetig, winzige Anfangspunkte
   dominierten sonst die Regression) und bestaetigte danach: die
   PLATEAU-Klassifikation KANN korrekt anschlagen, tut es bei den 5 realen
   Projekten aber tatsaechlich nicht - siehe Diskussion oben und
   `TARGETS.md`.
   ~~FT-Transformer-Diversitaet~~ **zweiter Datenpunkt ERLEDIGT
   (2026-08-15, `eeg-eye-state`)**: Ergebnis aber uneindeutig statt
   bestaetigend - Dekorrelations-Befund dreht sich zwischen den beiden
   Projekten (0.976 vs. 0.581), CPU-Machbarkeitsschwelle liegt bereits
   INNERHALB der beiden Datenpunkte, Blend-Nutzen bei keinem der beiden
   klar positiv belegt. Bleibt ein offener Faden statt eines robusten
   Befunds, siehe Diskussion oben.
