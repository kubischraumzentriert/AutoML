# Ablationsstudien-Plan (definiert, NICHT durchgefuehrt)

Phase E, Punkt 17 aus dem 2026-08-28-Bewertungsdokument: "Ablations-
studien definieren" - explizit NUR definieren, nicht ausfuehren (Punkt
17 im Bewertungsdokument steht bewusst getrennt von der eigentlichen
Ausfuehrung, die als "spaeter" markiert ist, siehe Abschnitt 13 dort:
"Erst nach der breiteren Outer Evaluation" - diese Bedingung ist mit
Phase C jetzt erfuellt, die Ausfuehrung selbst bleibt aber ein
eigenstaendiger, spaeter zu beauftragender Schritt).

## Ziel laut Bewertungsdokument

> Ziel ist nicht zu zeigen, dass jeder Baustein immer Score bringt. Ziel
> ist: Welche Bausteine verbessern Score, welche verbessern Vertrauen und
> welche verhindern Fehlentscheidungen?

Jede Ablation unten definiert die 8 Punkte aus
[`MODEL_HYPOTHESIS_CRITERIA.md`](MODEL_HYPOTHESIS_CRITERIA.md) (dieselbe
Disziplin wie fuer einen neuen Modellkandidaten), plus explizit, in
welche der 3 Rollen (Score/Trust/Fehlervermeidung) der erwartete Effekt
faellt.

## Geplante Ablationen

### A1: Full Workflow vs. ohne klassengewichtetes Training + Multiplier-Tuning

- **Hypothese**: der Score-Effekt der Gewichtungs-/Multiplier-Kette ist
  metrik-abhaengig (siehe Phase-C-Kernbefund) - erwartet WIRD ein
  Score-Gewinn bei BAcc-primaeren Aufgaben, ein Score-Verlust bei
  Accuracy-/F-beta-primaeren Aufgaben OHNE Korrektur-Schritt.
- **Datensatztyp**: alle 7 Phase-C-Datensaetze (bereits vorhandene
  Rohdaten aus `workflow_ranger` vs. `ranger_default` - diese Ablation
  ist TEILWEISE BEREITS BEANTWORTET durch Phase C selbst, siehe
  `BACKLOG.md`).
- **Baseline**: `ranger_default` (bereits vorhanden).
- **Primaermetrik**: je Projekt eigene (wie im eingefrorenen Protokoll).
- **Diversitaetsmetrik**: entfaellt (kein Ensemble-Kandidat).
- **Laufzeitbudget**: kein zusaetzlicher Lauf noetig - Re-Analyse
  bestehender Phase-C-Ergebnisse.
- **Abbruchkriterium**: bereits erreicht (Phase-C-Kernbefund gilt als
  Antwort).
- **Rolle**: Score (gemischt, metrik-abhaengig) + Fehlervermeidung
  (verhindert falsches Vertrauen in "Gewichtung hilft immer").
- **Status**: **de facto bereits durchgefuehrt** (Phase C liefert die
  Antwort ohne einen eigenen Ablations-Lauf). **Erweitert (2026-08-28,
  Nachpruefung auf Nutzeranfrage)**: zusaetzlicher 4. Arm
  `workflow_ranger_multiplier` fuer die beiden negativen Phase-C-Faelle
  (`CreditScoringChallenge`, `PumpItUp`), Multiplier-Korrektur gegen die
  ECHTE Primaermetrik (F-beta/Accuracy) statt BAcc optimiert. Ergebnis:
  Multiplier-Korrektur hilft in BEIDEN Faellen deutlich, aber
  unterschiedlich stark - `PumpItUp` (~7% Minderheit) erholt sich fast
  vollstaendig (0.7428 -> 0.8047, nahe an den Baselines 0.8039/0.8111),
  `CreditScoringChallenge` (~1.8%, extremer) nur teilweise (0.1088 ->
  0.2832, weiterhin klar unter 0.3628/0.3953). Praezisiert den
  Kernbefund: die Korrekturkette FUNKTIONIERT, ihre Wirksamkeit haengt
  aber selbst vom Grad der Klassenschieflage ab. Details/Skripte:
  `ML_Learning/CreditScoringChallenge/multiplier_correction_check.R`,
  `ML_Learning/PumpItUp/multiplier_correction_check.R`, Ergebnisse in
  `BACKLOG.md`/Phase-C-Status.

### A2: Full Workflow vs. ohne Leak-Audit (015)

- **Hypothese**: Leak-Audit hat KEINEN Score-Effekt auf saubere
  Datensaetze (Erwartung: unauffaellig), aber verhindert katastrophale
  Fehlentscheidungen auf geleakten Datensaetzen (Beleg bereits
  vorhanden: `CreditScoringChallenge`, F1 0.88 -> 0.41 nach Entfernen des
  Leaks).
- **Datensatztyp**: mindestens 1 Projekt MIT bekanntem historischen Leak
  (`CreditScoringChallenge`) + mindestens 1 sauberes Projekt
  (`health_condition`).
- **Baseline**: der jeweilige Full-Workflow-Score MIT Leak-Audit
  (nachtraeglich entfernter Leak vs. Score, WENN der Leak nicht entdeckt
  worden waere - kontrafaktische Rekonstruktion, teils bereits in
  `TARGETS.md`/`SYSTEMATIC_EVALUATION.md` dokumentiert).
- **Primaermetrik**: je Projekt eigene.
- **Diversitaetsmetrik**: entfaellt.
- **Laufzeitbudget**: gering (kein neues Modelltraining, nur eine
  kontrafaktische Nacherzaehlung bereits vorhandener Befunde plus ggf.
  1-2 neue Bestaetigungslaeufe).
- **Abbruchkriterium**: sobald mindestens 1 "Leak gefunden und Score
  waere sonst falsch gewesen"-Fall UND mindestens 1 "kein Leak, Audit
  war zurecht still"-Fall dokumentiert sind.
- **Rolle**: Fehlervermeidung (Kern-Trust-Gate-Rolle), NICHT Score.

### A3: Full Workflow vs. ohne Drift-/Stabilitaets-Checks (115/022/023/092/136)

- **Hypothese**: diese Module haben in der Regel KEINEN Score-Effekt
  (sie AENDERN das trainierte Modell nicht), sondern liefern
  Vertrauens-/Warnsignale (z.B. Adversarial-Validation-AUC, Split-Size-
  Sensitivitaet). Ablation testet NICHT "Score mit/ohne", sondern "haette
  ein Nutzer OHNE dieses Signal eine falsche Schlussfolgerung gezogen?".
- **Datensatztyp**: Projekte mit dokumentiertem AUFFAELLIGEM Befund
  (z.B. `geoai-aquaculture` fuer Adversarial Validation/Covariate Shift,
  `credit-g` fuer die urspruengliche Learning-Curve-Fehlmessung vor dem
  IQR-Fix).
- **Baseline**: "Was haette man ohne dieses Diagnose-Modul geglaubt?"
  (retrospektive Rekonstruktion aus bereits dokumentierten Befunden).
- **Primaermetrik**: keine (dies ist eine Trust-, keine Score-Ablation).
- **Diversitaetsmetrik**: entfaellt.
- **Laufzeitbudget**: gering, ueberwiegend Dokumentations-Nacharbeit.
- **Abbruchkriterium**: mindestens 2-3 illustrative Faelle je
  Diagnose-Modul-Gruppe dokumentiert.
- **Rolle**: Vertrauen (Trust-Gate) - explizit KEIN Score-Effekt
  erwartet, das ist Teil der Aussage selbst.

### A4: Full Workflow vs. ohne Ensemble Selection (148/149)

- **Hypothese**: Ensemble Selection bringt einen KLEINEN, aber
  konsistenten Score-Gewinn ggue. dem besten Einzelmodell, ist aber NICHT
  in jedem Projekt der groesste Hebel (bereits teilweise widerlegt/
  bestaetigt je nach Projekt, siehe `SYSTEMATIC_EVALUATION.md`s
  gemischte Befunde: `s6e6` z.B. KEIN Score-Gewinn trotz korrekt
  laufendem Mechanismus).
- **Datensatztyp**: Projekte mit bereits vorhandenem Ensemble-Selection-
  Ergebnis (`health_condition`, `s6e6`, `s6e8`, `openml-bank-marketing-
  ensemble-test`).
- **Baseline**: bestes Einzelmodell im jeweiligen Kandidatenpool
  (bereits geloggt).
- **Primaermetrik**: je Projekt eigene.
- **Diversitaetsmetrik**: Korrelation/Uebereinstimmung der
  Kandidatenpool-Mitglieder (bereits Teil der bestehenden Pipeline).
- **Laufzeitbudget**: kein neuer Lauf noetig, Re-Analyse.
- **Abbruchkriterium**: bereits erreicht (gemischte Evidenz ist die
  Antwort - "hilft manchmal, nicht garantiert").
- **Rolle**: Score (gemischt, projektabhaengig).
- **Status**: **de facto bereits beantwortet** durch bestehende
  Projekt-Historie, keine neue Ausfuehrung noetig.

## Zusammenfassung: was noch AUSGEFUEHRT werden muesste

Von den 4 definierten Ablationen sind A1 und A4 durch bereits vorhandene
Ergebnisse **de facto beantwortet** (keine neuen Laeufe noetig, nur
Re-Analyse/Zusammenfassung fuer die Publikation). A2 und A3 sind
ueberwiegend **dokumentarische Nacharbeit** (bereits vorhandene Befunde
in eine "mit/ohne"-Erzaehlung uebersetzen), mit hoechstens 1-2 kleinen
neuen Bestaetigungslaeufen. **Keine dieser 4 Ablationen erfordert ein
neues, grosses Rechenbudget** wie Phase C - das war eine bewusste
Prioritaet bei der Definition (siehe Bewertungsdokument: "Ziel ist NICHT
zu zeigen, dass jeder Baustein immer Score bringt" - die meisten
Antworten liegen bereits vor, sie muessen nur noch als Ablations-
Erzaehlung zusammengestellt werden statt neu erhoben).

**Nicht Teil dieses Plans**: die tatsaechliche Durchfuehrung/das
Zusammenstellen dieser 4 Ablationen zu einem Publikations-Abschnitt -
das ist ein eigener, spaeter zu beauftragender Schritt.
