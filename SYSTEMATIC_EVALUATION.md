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
| `CreditScoringChallenge` (Zindi) | ✓✓ (F1 0.88→0.41, echter Ex-post-Leak) | ? | ? | ? | ? | ? | ? | ? | — |
| `PumpItUp` (DrivenData) | ✓ (2. Bestätigung, `ward` 28.5%, kein Leak) | ? | ? | ? | ? | ? | ? | ? | — |
| `geoai-aquaculture...` (Zindi) | ✓ (3. Bestätigung, `re3_08` 27.5%, kein Leak) | ? | ? | ? | ? | ? | ? | ? | — |
| `openml-satimage-multiclass` | ? | ? | ✓ (Faktor 1.26x, unauffällig) | ✓ (noch steigend bei 100%) | ✓ | ✓ (2. Bestätigung, unauffällig) | ? | ? | — |
| `openml-steel-plates-fault` | ✓ (1 Determinismus-Fund dokumentiert, nicht als Leak entfernt) | ? | ? | ? | ? | ✓ (1. Bestätigung, unauffällig) | ? | ✓ (1/prior schlägt Grid: 0.840 vs. 0.832) | — |
| `openml-credit-g` | ? | ? | ? | ? | ? | ✓ (unauffällig, eigener 80/20-Split) | ? | ✓ (binärer Nelder-Mead-Fix gefunden+behoben) | — |
| `openml-adult-income` | ? | ? | ? | ? | ? | ? | ? | ? | — |
| `playground-series-s6e5` | ? | ? | ? | ? | ? | ? | ✓ (5. Bestätigung, Methodik-Test) | ? | — |
| `playground-series-s6e6` | ? | ? | ? | ? | ? | ? | ✓ (5. Bestätigung, Methodik-Test) | ? | — |
| `predictingsmartphoneAddiction_s6e8` | ? | ? | ? | ? | ? | ? | ✓✓ (6. Bestätigung, live Kaggle-Submission) | ? | — |
| `drivendata_richter` | ? | ? | ? | ? | ? | ? | ? | ? | — |
| `openml-yeast-multilabel` | ? | — | ? | ? | ? | ? | ? | ✓ (Binary Relevance, 1. Bestätigung) | ✓ (1. Bestätigung) |
| `openml-scene-multilabel` | ? | — | ? | ? | ? | ? | ? | ✓ (2. Bestätigung) | ✓ (2. Bestätigung) |
| `openml-birds-multilabel` | ? | — | ? | ? | ? | ? | ? | ✓ (3. Bestätigung) | ✓ (3. Bestätigung) |
| `health-condition-huyen-sanity-tests` | — | — | — | — | — | — | — | — | — |
| `FinancialStressPredictionChallenge` | ? | ? | ? | ? | ? | ? | ? | ? | — |
| `openml-amazon-access` | ? | ? | ? | ? | ? | ? | ? | ? | — |
| `openml-bank-marketing-ensemble-test` | ? | ? | ? | ? | ? | ? | ✓ (frühe Ensemble-Selection-Bestätigung, vor `health_condition`) | ? | — |

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
