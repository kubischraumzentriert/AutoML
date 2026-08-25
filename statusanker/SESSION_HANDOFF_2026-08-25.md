# Session Handoff (Stand 2026-08-25) - Statusanker

Vorheriger dauerhafter Anker: `statusanker/SESSION_HANDOFF_2026-08-24.md`
(Literatur-/Portfolio-Warmstart-Sprint, Roadmap-Start).

## Repo-Zustand am Ende dieser Session

Alle drei Repos sauber, nichts uncommittet:
- `MLR3_Classifikation` (`C:\Users\HP\OneDrive\Dokumente\R_Workspace\MLR3_Classifikation`)
  @ `ee37f98` "Extend multi-layer stacking test to 3 more projects, close the question" - gepusht.
- `MLR3_Regression` (`C:\Users\HP\OneDrive\Dokumente\R_Workspace\MLR3_Regression`)
  @ `645d6f5` "Document multi-layer stacking negative finding in BACKLOG.md" - gepusht.
- `ML_Learning` (`C:\Users\HP\ML_Learning`, rein lokal, kein Remote)
  @ `e49e787` "Add multi-layer stacking test confirmations (s6e6, s6e8)".

## Was in dieser Session passiert ist

**Ausgangspunkt**: Fortsetzung der Literatur-Roadmap vom 24.08. Auf Nutzer-
frage "was ist vernuenftig als naechstes" wurde entschieden, weitere
Literatur-Tabellen-Importe (sinkender Ertrag) zurueckzustellen und
stattdessen Roadmap-Punkt 2 (AutoGluon-Idee: Multi-Layer-/OOF-Stacking)
anzugehen - aber erst Vorarbeit gegenpruefen, nicht blind neu testen.

**1. Vorarbeit-Check ergab wichtigen Kontext**: einlagiges Logits-Stacking
war bereits 2026-07-16 auf `s6e5` getestet worden - negativ/neutral
(+0.00016 AUC, 19x teurer). Auch der per-Klassen-gewichtete Blend zeigte
denselben Befund (Payoff an der Rauschgrenze mit korrelierten Baum-
Basismodellen). Der noch offene Teil der AutoGluon-These war spezifisch
MEHRSCHICHTIGES (nicht nur einlagiges) Stacking - dafuer wurde der Test
gezielt zugeschnitten.

**2. Erster Test gegen `health_condition`** (`multilayer_stack_test.R`,
baut auf dem bestehenden `148_ensemble_candidate_pool.R`-Pool auf, kein
neues Training): 3-Wege-Split, Layer-1 (multinom/ranger/lightgbm) lernt aus
Basis-Wahrscheinlichkeiten, Layer-2 (multinom) NUR aus Layer-1-Vorhersagen.

**Wichtiger Zwischenfund**: der erste (ungewichtete) Lauf zeigte ein
irrefuehrend starkes Negativ (mehrschichtig 0.857, schlechter als einlagig
UND alle Baselines). Diagnose: reines Kalibrierungsartefakt, kein Stacking-
Befund - bei `health_condition`s starker Klassenunbalance (~72/5/7%)
faellt ein UNGEWICHTETER Meta-Learner beim argmax Richtung Mehrheitsklasse
zurueck und verliert die Kalibrierung, die die Basismodelle durch ihr
gewichtetes Training (`class_weight_power`) schon hatten (glmnet
ungewichtet 0.8956 -> gewichtet 0.9562). **Reusable Lehre**: jeder
kuenftige Stacking-Test auf einer BAcc-optimierten unbalancierten Aufgabe
braucht denselben Meta-Learner-Gewichtungs-Fix, sonst ist "Stacking bringt
nichts" nicht von einem Kalibrierungsbug zu unterscheiden.

Nach dem Fix (beide Stacking-Stufen gewichtet): `equal_blend` 0.9575 >
`greedy_ensemble` 0.9573 > `best_single` 0.9561 > `multilayer_stack` 0.9493
> `single_layer_stack` 0.9376 - Mehrschichten schlaegt einlagig klar
(+0.0117), bleibt aber unter den bestehenden einfachen Methoden.

**3. Auf Nutzerwunsch fuer ein belastbareres Fundament auf 3 weitere,
strukturell verschiedene Projekte ausgeweitet** (alle nutzen bereits
vorhandene Ensemble-Pools, kein neues Basis-Training):

| Projekt | Metrik | best_single | blend | greedy | einlagig | mehrschichtig |
|---|---|---|---|---|---|---|
| health_condition (3-Klassen, unbalanciert) | BAcc | 0.9561 | **0.9575** | 0.9573 | 0.9376 | 0.9493 |
| s6e6 stellar-class (3-Klassen) | BAcc | 0.9655 | 0.9650 | 0.9664 | 0.9619 | **0.9668** |
| s6e8 Smartphone-Addiction (binaer) | AUC | 0.9587 | 0.9466 | 0.9590 | **0.9593** | 0.9579 |
| MLR3_Regression-Eigenprojekt (accident_risk) | RMSE (niedriger=besser) | 0.05624 | 0.05690 | **0.05615** | 0.05703 | 0.05693 |

**Zwei klare Befunde ueber alle 4 Laeufe**:
1. Mehrschichten schlaegt einlagiges Stacking in 3 von 4 Projekten (einzige
   Ausnahme: s6e8, binaer/AUC) - die AutoGluon-These "mehr Schichten
   helfen" haelt sich robust.
2. Stacking (egal welche Variante) schlaegt die bestehende Greedy Ensemble
   Selection aber nur in 1 von 4 Projekten (s6e6, +0.0004, Rauschmarge).

**Endgueltiges Urteil: NICHT ins Template zurueckgefuehrt, Frage als
beantwortet betrachtet** (nicht als "noch nicht genug Evidenz" offen
gelassen) - korrelierte Baumkandidaten limitieren den Nutzen jeder
Kombinationsmethode, egal wie ausgefeilt. Die Kalibrierungs-Lehre bleibt
der wichtigste eigenstaendige Fund, unabhaengig vom Multi-Layer-Ergebnis.

**4. Dokumentation und Commits**:
- `MLR3_Classifikation/TARGETS.md`: volle Herleitung + 4-Projekt-Tabelle
  am bestehenden Logits-Stacking-Backlog-Eintrag ergaenzt. Committet+gepusht
  in 2 Schritten (erster Test, dann die Ausweitung).
- `MLR3_Regression/BACKLOG.md`: neuer Eintrag (Nr. 24), Querverweis auf die
  Klassifikations-Tabelle. Committet+gepusht.
- `ML_Learning`: beide neuen Skripte (`playground-series-s6e6/`,
  `predictingsmartphoneAddiction_s6e8/`) in einem Commit, lokal (kein
  Remote in diesem Repo).
- Skripte bleiben in allen 4 Projekten liegen (`multilayer_stack_test.R`,
  projektspezifisch angepasst) als wiederverwendbare Vorlage fuer einen
  spaeteren Diversitaets-Test (z.B. mit FT-Transformer im Pool).

**Nebenbefund**: `ML_Learning` ist entgegen einer aelteren Notiz doch ein
Git-Repo auf oberster Ebene (nur ohne Remote) - korrigiert im Memory.

## Offene Punkte fuer die naechste Session

1. **Keine dringenden.** Multi-Layer-Stacking-Frage ist geschlossen.
2. Literatur-Roadmap (siehe `TARGETS.md`/Handoff vom 24.08.) bleibt der
   naechste natuerliche Einstiegspunkt, falls kein anderer Auftrag kommt:
   weitere Literatur-Tabellen-Importe gezielt nur fuer OpenML-ID'te
   Datensaetze mit klarer Metrik/Split-Beschreibung, oder ein Blick auf
   Roadmap-Punkt 4 (BOHB/Hyperband/Auto-sklearn-2.0-Budgetierung) bzw.
   Punkt 5 (TabM) als naechster ungetesteter Hebel.
3. Ein echter naechster Test der Stacking-Idee waere erst sinnvoll, sobald
   ein diversifizierendes Mitglied (FT-Transformer) im Kandidaten-Pool ist -
   bislang nur fuer den simplen Blend geprueft (s6e8), nicht fuer Stacking.

## Wichtige Konventionen (falls die naechste Session sie noch nicht kennt)

- Commit und Push sind zwei separate, jeweils explizit vom User bestaetigte
  Schritte - nie automatisch pushen.
- Bei Stacking-/Meta-Learner-Tests auf einer schwellenwertabhaengigen,
  unbalancierten Metrik (BAcc): Meta-Learner MUSS dieselbe Klassen-
  gewichtung/Prior-Korrektur bekommen wie die Basismodelle, sonst ist ein
  Negativbefund nicht von einem Kalibrierungsbug zu unterscheiden (NEU
  diese Session, siehe oben).
- Ein negatives/uneindeutiges Ergebnis nach ausreichend breiter Evidenz
  (hier: 4 strukturell verschiedene Projekte, beide Aufgabentypen, alle 3
  Metrikklassen) darf als ENDGUELTIG beantwortet dokumentiert werden, nicht
  nur als "vorerst offen" - Unterscheidung ist wichtig fuer kuenftige
  Sessions, die sonst dieselbe Frage nochmal aufrollen wuerden.
- Vollstaendiger Kontext: `TARGETS.md` (Klassifikation) bzw. `BACKLOG.md`
  (Regression), sowie das persistente Gedaechtnis
  (`project_mlr3_automl_template.md`, Claude-Memory, automatisch geladen).

## Empfohlener erster Schritt der naechsten Session

Kein zwingender Einstiegspunkt. Falls der Nutzer nichts Konkretes
mitbringt: bei der Literatur-Roadmap weitermachen (Punkt 2 oben) oder
`TARGETS.md`/Memory kurz auf neue Ideen durchsehen.
