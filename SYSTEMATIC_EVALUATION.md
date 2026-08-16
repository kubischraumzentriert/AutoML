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
| `openml-satimage-multiclass` | — (kein `015` im Projekt) | — (kein `115` im Projekt) | ✓ (Faktor 1.26x, unauffällig) | ✓ (noch steigend bei 100%) | ✓ | ✓ (2. Bestätigung, z=1.03/z=0.50, kleinere/engere Hintergrund-Lücke als steel-plates-fault, unauffällig) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `openml-steel-plates-fault` | ✓ (1 Determinismus-Fund dokumentiert, nicht als Leak entfernt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ✓ (1. Bestätigung, z=-1.63/z=-0.39, Hintergrund-Lücke -0.039 BAcc, beide Kandidaten innerhalb des Referenzbereichs) | — (kein `148`/`149` im Projekt) | ✓ (1/prior schlägt Grid: 0.840 vs. 0.832) | — |
| `openml-credit-g` | ✓ (unauffällig, Top-Feature `credit_amount` 26.9%, 0/68 Determinismus) | — (kein `115` im Projekt) | ✓ (Faktor 1.53x bei ratio=0.80, unauffällig) | ✓ (PLATEAU, 6.5% der Score-Spannweite/Verdopplung - unter 10%-Schwelle, ERSTES Plateau-Ergebnis ggü. `health_condition`/`satimage`, die beide "noch steigend" waren) | ✓ (2 Checks, 17.3%/16.6% relativ, beide unauffällig) | ✓ (unauffällig, eigener 80/20-Split) | — (kein `148`/`149` im Projekt) | ✓ (binärer Nelder-Mead-Fix gefunden+behoben) | — |
| `openml-adult-income` | — (kein `015` im Projekt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `playground-series-s6e5` | — (kein `015` im Projekt) | ✓ (AUC 0.4996, kein Shift) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | ✗ (KEIN `148`/`149` im Projekt - stattdessen `140_stack_ensemble.R`, ein ANDERES Verfahren: Logits-Stacking-Meta-Learner, negativ getestet: +0.00016 AUC ggü. bestem Einzelmodell, unter dem Rausch-Band, bei ~19x Rechenaufwand - nicht übernommen) | — (kein `130` im Projekt) | — |
| `playground-series-s6e6` | — (kein `015` im Projekt) | ✓ (AUC ≈0.4996, kein Shift, widerlegt Kardinalitäts-Artefakt-Verdacht aus s6e5) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | ✓ (5. Bestätigung, Methodik-Test - lokal als `146_ensemble_selection.R` benannt, nicht `148`/`149`, aber dieselbe Greedy-Ensemble-Selection-Methodik) | — (kein `130` im Projekt) | — |
| `predictingsmartphoneAddiction_s6e8` | — (kein `015` im Projekt) | ✓ (AUC 0.565, moderat; ESS-Ratio 0.94, unschädlich) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | ✓✓ (6. Bestätigung, live Kaggle-Submission) | — (`130`/`146` im Ordner, aber strukturell übersprungen - AUC/LogLoss/PRAUC sind schwellenwertunabhängig, keine Artefakte vorhanden) | — |
| `drivendata_richter` | — (kein `015` im Projekt) | ✓ (AUC 0.5002, kein Shift) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `openml-yeast-multilabel` | — (kein `015` im Projekt) | — | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | ✓ (Binary Relevance, 1. Bestätigung) | ✓ (1. Bestätigung) |
| `openml-scene-multilabel` | — (kein `015` im Projekt) | — | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | ✓ (2. Bestätigung) | ✓ (2. Bestätigung) |
| `openml-birds-multilabel` | — (kein `015` im Projekt) | — | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | ✓ (3. Bestätigung) | ✓ (3. Bestätigung) |
| `health-condition-huyen-sanity-tests` | — | — | — | — | — | — | — | — | — |
| `FinancialStressPredictionChallenge` | — (kein `015` im Projekt) | ✓ (AUC 0.4971, kein Shift) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `openml-amazon-access` | — (kein `015` im Projekt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | — (kein `148`/`149` im Projekt) | — (kein `130` im Projekt) | — |
| `openml-bank-marketing-ensemble-test` | — (kein `015` im Projekt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | — (kein `136` im Projekt) | ✓ (frühe Ensemble-Selection-Bestätigung, vor `health_condition`) | — (kein `130` im Projekt) | — |
| `openml-synthetic-control-timeseries` | ✓ (unauffällig) | — (kein `115` im Projekt) | ✓ (Faktor 1.25x, unauffällig) | ✓ (noch steigend, 17.5%) | ✓ (SD=0.000, vollständig deterministisch) | ✓ (beide unauffällig, z=0.05/-0.63) | — (kein `148`/`149`; stattdessen FT-Transformer-Dekorrelationstest `095`/`096` für Hebel-1-Kandidat, negativ: Kappa 0.976, kein Diversitätsgewinn) | ✓ (keine Verbesserung, exakt balancierte Klassen) | — |
| `openml-eeg-eye-state-timeseries` | ✓ (unauffällig) | — (kein `115` im Projekt) | — (strukturell übersprungen, >5000 Zeilen) | ✓ (noch steigend, 14.7%) | ✓ (unauffällig, 0.23x/0.21x) | ✓ (beide unauffällig, aber bisher höchste z-Werte: z=1.67/1.27) | — (kein `148`/`149` im Projekt) | ✓ (binärer `optimize()`/Brent-Pfad, modester Gewinn) | — |

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
  **Echter differenzierender Befund bei Learning-Curve**: `credit-g`
  (1000 Zeilen) zeigt als ERSTES Projekt ueberhaupt ein PLATEAU (6.5% der
  Score-Spannweite pro Verdopplung, unter der 10%-Schwelle) - im
  Gegensatz zu `health_condition` (690k Zeilen) und `satimage` (6430
  Zeilen), die beide trotz sehr unterschiedlicher Groesse "noch
  steigend" waren. Passt qualitativ zur Erwartung "Plateau eher bei
  kleinen, einfachen Datensaetzen", ist aber bisher nur 1 Projekt-Beleg.
  Die restlichen 14 Projekte haben keines der drei Module im
  Projektordner - Marker-Luecke, keine Nullbefunde.
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

## Nächste Schritte für diese Tabelle

1. ~~`?`-Zellen gezielt auflösen~~ **ERLEDIGT (2026-08-15)**: alle 9 Spalten
   durchgearbeitet (Reihenfolge: Leak-Audit → Adversarial Validation →
   Split-Size-Sens./Learning-Curve/Seed-Stabilität → Generalisierungslücke
   → Threshold-Tuning → Ensemble Selection), 0 `?`-Zellen verbleibend.
2. Fehlende Projekte ergänzen, falls `ML_Learning/README.md` weitere
   relevante Kandidaten zeigt, die hier noch nicht aufgenommen sind.
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
4. ~~Weitere Stichproben unter bereits gefüllten Alt-Zellen~~ **ERSTE
   RUNDE ERLEDIGT (2026-08-15)**: 7 zusätzliche Alt-Zellen aus 6
   Projekten/Spalten direkt gegen Quelle (Artefakt-CSV oder README, nicht
   nur TARGETS.md-Prosa) nachgeprüft - alle bestätigt, kein neuer Fehler.
   Nicht erschöpfend (die Tabelle hat >150 Zellen, nur ein kleiner Teil
   wurde bisher stichprobenartig geprüft) - eine zweite Runde an anderen
   Zellen bleibt sinnvoll, ist aber kein akuter Blocker mehr.
5. Sobald belastbar: Zusammenfassung/Diskussion für die Publikationsnotiz
   ableiten (welche Komponenten sind projekttyp-unabhängig robust,
   welche projektspezifisch).
