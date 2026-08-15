# Systematische Evaluation: Workflow-Komponenten über Projekte

Konsolidierte Ergebnistabelle für das mittelfristige Publikationsziel
(siehe `AGENTS.md`, "Mittelfristiges Ziel"). Beantwortet: welche
Workflow-Komponente wurde auf welchem Projekt bestätigt, war neutral/
No-op, oder wurde verworfen?

**Status: erster Entwurf (2026-08-15).** Methodik: jede Zelle stützt sich
auf einen konkreten Textbeleg in `TARGETS.md`/`README_DETAILS.md` - keine
Zelle wurde aus Erinnerung geraten. `?` heißt "noch nicht verifiziert/
nicht in den gelesenen Abschnitten belegt", nicht "negativ". Diese Tabelle
braucht vermutlich mehrere Korrekturdurchgänge, bevor sie belastbar ist.

**Legende**: ✓ bestätigt (Modul lief, Befund unauffällig/wie erwartet) ·
✓✓ bestätigt UND Kernbefund (Leak/Bug real gefunden) · ~ neutral/No-op
(lief, kein Effekt) · ✗ verworfen (getestet, negativ, nicht übernommen) ·
— nicht anwendbar · ? nicht verifiziert

| Projekt | Leak-Audit (015) | Adversarial Val. (115) | Split-Size-Sens. (022) | Learning-Curve (023) | Seed-Stabilität (092) | Generalisierungslücke (136) | Ensemble Selection (148/149) | Threshold-Tuning (130) | Multi-Label (021) |
|---|---|---|---|---|---|---|---|---|---|
| `health_condition` (Template-eigen) | ✓ (stress_level 42.9%, kein Determinismus) | ✓ (AUC 0.654, moderat, unschädlich) | ✓ | ✓ (noch steigend, klein) | ✓ | ✓ | ✓✓ (3./6. Bestätigung, live s6e8 deployed) | ? | — |
| `CreditScoringChallenge` (Zindi) | ✓✓ (F1 0.88→0.41, echter Ex-post-Leak) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ? | ? | — |
| `PumpItUp` (DrivenData) | ✓ (2. Bestätigung, `ward` 28.5%, kein Leak) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ? | ? | — |
| `geoai-aquaculture...` (Zindi) | ✓ (3. Bestätigung, `re3_08` 27.5%, kein Leak) | ✓✓ (AUC 0.99998 roh / 0.978 Band-Mittel - echter, extremer Train/Test-Shift; ESS 2.6% -> Reweighting verworfen, Invarianz-Ansatz stattdessen) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ? | ? | — |
| `openml-satimage-multiclass` | — (kein `015` im Projekt) | ? | ✓ (Faktor 1.26x, unauffällig) | ✓ (noch steigend bei 100%) | ✓ | ✓ (2. Bestätigung, unauffällig) | ? | ? | — |
| `openml-steel-plates-fault` | ✓ (1 Determinismus-Fund dokumentiert, nicht als Leak entfernt) | ? | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ✓ (1. Bestätigung, unauffällig) | ? | ✓ (1/prior schlägt Grid: 0.840 vs. 0.832) | — |
| `openml-credit-g` | ✓ (unauffällig, Top-Feature `credit_amount` 26.9%, 0/68 Determinismus) | ? | ✓ (Faktor 1.53x bei ratio=0.80, unauffällig) | ✓ (PLATEAU, 6.5% der Score-Spannweite/Verdopplung - unter 10%-Schwelle, ERSTES Plateau-Ergebnis ggü. `health_condition`/`satimage`, die beide "noch steigend" waren) | ✓ (2 Checks, 17.3%/16.6% relativ, beide unauffällig) | ✓ (unauffällig, eigener 80/20-Split) | ? | ✓ (binärer Nelder-Mead-Fix gefunden+behoben) | — |
| `openml-adult-income` | — (kein `015` im Projekt) | ? | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ? | ? | — |
| `playground-series-s6e5` | — (kein `015` im Projekt) | ✓ (AUC 0.4996, kein Shift) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ✓ (5. Bestätigung, Methodik-Test) | ? | — |
| `playground-series-s6e6` | — (kein `015` im Projekt) | ✓ (AUC ≈0.4996, kein Shift, widerlegt Kardinalitäts-Artefakt-Verdacht aus s6e5) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ✓ (5. Bestätigung, Methodik-Test) | ? | — |
| `predictingsmartphoneAddiction_s6e8` | — (kein `015` im Projekt) | ✓ (AUC 0.565, moderat; ESS-Ratio 0.94, unschädlich) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ✓✓ (6. Bestätigung, live Kaggle-Submission) | ? | — |
| `drivendata_richter` | — (kein `015` im Projekt) | ✓ (AUC 0.5002, kein Shift) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ? | ? | — |
| `openml-yeast-multilabel` | — (kein `015` im Projekt) | — | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ? | ✓ (Binary Relevance, 1. Bestätigung) | ✓ (1. Bestätigung) |
| `openml-scene-multilabel` | — (kein `015` im Projekt) | — | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ? | ✓ (2. Bestätigung) | ✓ (2. Bestätigung) |
| `openml-birds-multilabel` | — (kein `015` im Projekt) | — | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ? | ✓ (3. Bestätigung) | ✓ (3. Bestätigung) |
| `health-condition-huyen-sanity-tests` | — | — | — | — | — | — | — | — | — |
| `FinancialStressPredictionChallenge` | — (kein `015` im Projekt) | ✓ (AUC 0.4971, kein Shift) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ? | ? | — |
| `openml-amazon-access` | — (kein `015` im Projekt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ? | ? | — |
| `openml-bank-marketing-ensemble-test` | — (kein `015` im Projekt) | — (kein `115` im Projekt) | — (kein `022` im Projekt) | — (kein `023` im Projekt) | — (kein `092` im Projekt) | ? | ✓ (frühe Ensemble-Selection-Bestätigung, vor `health_condition`) | ? | — |

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

## Nächste Schritte für diese Tabelle

1. `?`-Zellen gezielt durch Lesen der jeweiligen Projekt-READMEs/
   `TEMPLATE_FRICTION.md`-Dateien auflösen (nicht alle auf einmal - nach
   Priorität, z.B. zuerst Leak-Audit und Adversarial Validation, weil
   das der "Trust-Layer"-Kern der Publikationshypothese ist).
2. Fehlende Projekte ergänzen, falls `ML_Learning/README.md` weitere
   relevante Kandidaten zeigt, die hier noch nicht aufgenommen sind.
3. Sobald belastbar: Zusammenfassung/Diskussion für die Publikationsnotiz
   ableiten (welche Komponenten sind projekttyp-unabhängig robust,
   welche projektspezifisch).
