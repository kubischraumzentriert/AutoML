# Evaluations-Ebenen: was "der Workflow generalisiert" tatsaechlich bedeutet

P0 aus der 2026-08-29-Bewertung (`AutoML_Bewertung_und_Verbesserungsvorschlaege_2026-08-29.md`,
`~/Downloads`): der bisherige Phase-C-Kernbefund ("der Workflow
generalisiert MIT einer zur Zielmetrik passenden Korrekturkette") war
PRAEZISE in seinem eigenen Ergebnis, aber UNPRAEZISE in seiner
sprachlichen Reichweite - "der Workflow" klingt nach dem KOMPLETTEN
AutoML-Entscheidungsprozess, gemessen wurde aber nur ein einzelner
Baustein davon. Diese Datei legt fest, welche Ebene womit gemeint ist,
und macht das fuer alle bisherigen und kuenftigen Aussagen explizit.

## Die 3 Ebenen

### Level 1 - Component Workflow

```text
gewichteter Ranger + ggf. Multiplier-/Threshold-Korrektur
```

Das ist EXAKT das, was `outer_workflow_evaluation_template.R`
(`BENCHMARK_PROTOCOL.md` Version 1) bisher misst - der
`workflow_ranger`-Arm gegen `ranger_default`/`lightgbm_default`. Nicht
Teil davon: Leak-Audit, Feature Engineering, vollstaendige Modellwahl,
Ranger-/LightGBM-Tuning, Ensemble Candidate Pool, Greedy Ensemble
Selection, Final Model Selection, weitere Trust-Gates - all das laeuft
im echten Projekt-Workflow, aber NICHT innerhalb der bisherigen Outer-CV-
Schleife.

**Bislang durchgefuehrt**: P1.1-Prototyp (`health_condition`) + Phase C
(alle 7 Datensaetze) + die Multiplier-Korrektur-Nachpruefung
(`CreditScoringChallenge`/`PumpItUp`) sind AUSSCHLIESSLICH Level 1.

### Level 2 - Model-Selection Workflow

```text
Innerhalb jedes Outer-Train-Splits:
Ranger, LightGBM, Tuning, Threshold/Multiplier, Model Selection, ggf. Ensemble
```

Modellwahl UND Hyperparameter-Tuning selbst werden innerhalb jedes
Outer-Train-Splits neu durchgefuehrt (nicht nur ein einzelner
vorentschiedener Lernalgorithmus).

**Prototyp durchgefuehrt (2026-08-29, P2, 2 von 6 externen Datensaetzen)**:
[`outer_workflow_evaluation_v3_level2.R`](outer_workflow_evaluation_v3_level2.R)
(Protokoll v3) - Ergebnis GEGENLAEUFIG je nach Datensatzgroesse/-balance:
auf `ilpd` (klein, stark unausgeglichen) unterbietet Level 2 (0.6473) den
einfacheren Level-1-`workflow_ranger` (0.6840) klar; auf `optdigits`
(gross, balanciert) liefert Level 2 (0.9859) das bislang beste Ergebnis
ueberhaupt fuer diesen Datensatz (vor v1 workflow_ranger 0.9810 und v2
tuned_lightgbm 0.9840). Arbeitshypothese: bei kleinen Datensaetzen ist der
zusaetzliche Inner-Train/Inner-Tune-Split fuer eine stabile Modellwahl zu
datenarm (hohe Streuung, sd_score=0.051 bei ilpd), waehrend bei
groesseren Datensaetzen genug Daten fuer eine robuste Inner-Modellwahl
vorhanden sind und die zusaetzliche Komplexitaet sich auszahlt. Noch
NICHT auf allen 6 Datensaetzen geprueft, siehe `BACKLOG.md`.

### Level 3 - Full Trust-centered AutoML Decision Process

```text
Innerhalb jedes Outer-Train-Splits:
Trust Gates + Feature-/Data Decisions + Model Selection + Tuning +
Threshold/Multiplier + Ensemble + Final Selection
```

Der VOLLSTAENDIGE, im echten Projekt gelebte Entscheidungsprozess
innerhalb jedes Outer-Train-Splits - inklusive Leak-Audit/Drift-Checks
als aktive Entscheidungspunkte, nicht nur als nachtraeglich dokumentierte
Befunde. Bislang NICHT umgesetzt und aktuell auch nicht konkret geplant
(rechnerisch sehr aufwendig - jeder Outer-Fold wuerde eine komplette
Kopie des gesamten Projekt-Workflows durchlaufen).

## Sprachregel fuer alle kuenftigen Aussagen

**Nie mehr unqualifiziert "der Workflow generalisiert" schreiben.**
Stattdessen immer die Ebene explizit nennen: "der Level-1-Component-
Workflow (gewichtetes Training + Korrektur) generalisiert MIT einer zur
Zielmetrik passenden Korrekturkette" - das ist eine WAHRE, belastbare
Aussage. "Der komplette AutoML-Workflow generalisiert" waere dagegen eine
Aussage, fuer die bislang KEINE Evidenz vorliegt (weder positiv noch
negativ - Level 2/3 wurden schlicht noch nicht getestet).

## Betroffene bestehende Dokumente (Korrektur-Status)

- `BACKLOG.md` (Phase-C-Status, Multiplier-Nachpruefung): Aussagen
  praezisiert - siehe dortige Aenderungen vom 2026-08-29.
- `BENCHMARK_PROTOCOL.md`: Kopf um einen expliziten "Level 1"-Hinweis
  ergaenzt.
- `AGENTS.md` (Paper-Story): "der Workflow generalisiert" durch "der
  Level-1-Component-Workflow generalisiert" ersetzt, mit einem klaren
  Hinweis, dass Level 2/3 noch offen sind (P2 der neuen Roadmap).
- `ABLATION_STUDIES_PLAN.md`/die 2 ausgearbeiteten Ablations-Dokumente
  (A2/A3): NICHT geaendert - diese behandeln einzelne Diagnose-Module,
  nicht die "Workflow generalisiert"-Aussage, die Level-Frage betrifft
  sie nicht direkt.

## Bezug zur neuen Roadmap (2026-08-29-Bewertung)

- **P0** (diese Datei): Begriffe trennen. **ERLEDIGT.**
- **P1**: externes, vorab festgelegtes Benchmark-Set + faire getunte
  Baselines (Tuned Ranger/LightGBM, Best Single Tuned Model) - bleibt
  Level 1, aber mit staerkeren Baselines und ohne Benchmark-Selection-
  Bias-Risiko. Noch offen.
- **P2**: Level-2-Outer-Evaluation prototypisieren. Noch offen, deutlich
  teurer als P1.
- **P3**: `finalize_run_provenance()`, Paper-Rohentwurf. Noch offen.
