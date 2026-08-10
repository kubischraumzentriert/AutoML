# Session Handoff (Stand 2026-08-10, spät abends) - Statusanker

Dies ist der committete, zeitgestempelte Zwilling der lokalen Arbeitskopie
unter `C:\Users\HP\Downloads\SESSION_HANDOFF.md`. Die lokale Kopie wird bei
jeder Session überschrieben (keine Dauerdokumentation); dieser Statusanker
bleibt als Verlaufs-Schnappschuss im Repo stehen. Innerhalb desselben
Session-Tages wird dieser Anker aktualisiert (wie jetzt, zweite Aktualisierung
2026-08-10); ein neuer Tag bekommt eine neue Datei
(`statusanker/SESSION_HANDOFF_<Datum>.md`).

## Repo-Zustand

Beide Templates sauber, nichts uncommittet, alles gepusht:
- `MLR3_Classifikation` (C:\Users\HP\OneDrive\Dokumente\R_Workspace\MLR3_Classifikation)
  @ `c3ffb4a` "Generalize sanity_checks.R to be task-type-independent (cross-template port prep)"
- `MLR3_Regression` (C:\Users\HP\OneDrive\Dokumente\R_Workspace\MLR3_Regression)
  @ `7dc49dd` "Port Huyen sanity checks (perturbation/invariance/directional) from classification"

## Was in dieser Session passiert ist

**1. Huyen-Sanity-Checks (Perturbation/Invarianz/Directional Expectation) -
in BEIDEN Templates fertig.** Waren beim Sessionstart noch 0-Projekt-
Kandidaten. Prototypisiert, an Ground-Truth verifiziert (bewusst kaputte vs.
saubere Modelle, Sensitivität+Spezifität sauber getrennt), an 3 realen
Projekten bestätigt: health_condition + PumpItUp (Klassifikation), dann
road-accident-risk (Regression, Port am Sessionende). Alle drei zeigen
dasselbe Muster: Directional-Expectation-Test findet zuverlässig eine
substanzielle Richtungs-Verletzungs-Minderheit (3-10% der Zeilen), obwohl
die Aggregat-Richtung stimmt; Perturbation/Invarianz bleiben unauffällig.

- Klassifikation: `sanity_checks.R` + `147_error_analysis_ranger_
  sanity_checks.R`, `REFERENZ_MODEL_SANITY_CHECKS.md` (theoretischer
  Hintergrund). Committet+gepusht (`87c4751`).
- **Cross-Template-Port (Regression), separater Auftrag, Sessionende**:
  `sanity_checks.R` dabei aufgabentyp-unabhängig generalisiert
  (`higher_is_better`-Flag, numerische/kategoriale Invarianz-Erkennung,
  `build_numeric_shift_fn()` mit Integer-Erhalt) und identisch übernommen
  (wie `univariate_drift.R`). Musste `120_full_holdout_confirmation.R`
  erweitern, um Learner-Objekte zu speichern (bisher nur Vorhersagen) -
  additiv, bestehende Outputs unverändert. Neues `126_sanity_checks.R`.
  **Echter Design-Fund unterwegs**: bei einer numerischen Response
  (Regression) ist die reine `flip_rate` des Invarianz-Tests bei einem
  großen Boosting-Ensemble irreführend hoch (schon ein einzelner Split
  ändert jede Vorhersage minimal) - `road-accident-risk`/`public_road`
  zeigte flip_rate=0.499 bei mean_abs_change=0.0009 (verschwindend klein).
  Neues `invariance_warn_magnitude_threshold` gated zusätzlich auf die
  Änderungsgröße. Committet+gepusht (`c3ffb4a` Klassifikation, `7dc49dd`
  Regression).

**2. Literaturliste "Traceability & KI in der Produktion" abgearbeitet.**
Nutzer brachte eine vorformulierte Anweisung zu 13 Quellen mit, Ziel: Ideen
für den Workflow sammeln. Statt 13 Einzelrunden: Batch-Vorab-Triage, dann 8
vom Nutzer bestätigte Titel per Volltext bewertet. Alles in
`C:\Git\literatur\bewertung.md` (+ Volltexte/Extrakte dort), durables in
`project_literatur_review_produktion_ki.md` (Memory). Zwei Downloads
scheiterten zunächst (Bot-Blocker) - Jourdan et al. per echtem Browser-Tool
gefunden (direkter Bitstream-Link), Krauß et al. per Browser bestätigt
GENUIN paywalled (bewusst nicht über Drittanbieter-Mirrors umgangen).

**3. Drei weitere konkrete Funde direkt umgesetzt:**
- **Conformal Prediction Intervals** (Regression, aus dem MLOps/UQ-Paper):
  `conformal_prediction.R` + `128_conformal_prediction_intervals.R`,
  Ground-Truth-verifiziert (Coverage hält homo-/heteroskedastisch, bricht
  bei Distribution-Shift), gegen road-accident-risk bestätigt (Coverage
  0.901 vs. Ziel 0.900). Committet+gepusht (`b2c2f18`).
- **mlr3torch-Prämisse korrigiert** (NEURAL_DEPLOY.md, Klassifikation):
  `po("torch_ingress_categ")` + `nn("tokenizer_categ")` ist fertiges Idiom,
  kein Eigenbau wie beim s6e8-Verwerfen angenommen. NICHT prototypisiert
  (kein aktuelles Projekt braucht es).
- **`lightgbm_tuning_evals`-Budget-Ablation** (25 vs. 45): gemessen,
  gemischtes Ergebnis, Template-Default bleibt bei 25 (beide getunten
  Varianten bleiben unter dem ungetunten Default - bestätigt die "Tuning
  bringt marginale Gewinne"-Lehre erneut).

## Offene Punkte für die nächste Session

1. **Ensemble Selection backporten** (weiterhin der größte offene Punkt,
   unverändert seit mehreren Sessions). Verifiziert (2 Datensätze), aber
   nicht integriert. Blocker laut TARGETS.md: Benchmark-Skripte loggen nur
   die finale Metrik je Kandidat, nicht die Vorhersagen jedes Kandidaten auf
   einem gemeinsamen Holdout - das müsste zuerst ergänzt werden.
2. Regression-Template hat weiterhin mehrere 0-Projekt-Kandidaten offen aus
   der Klassifikationsseite (Meta-Learning-Warmstart, Successive Halving -
   beide dort negativ/verworfen, müssten bei Bedarf unabhängig getestet
   werden, nicht einfach übernommen).
3. **5 Literatur-Titel nicht tiefer bewertet** (niedrige Priorität, siehe
   `C:\Git\literatur\bewertung.md`): Additive-Manufacturing-Datensatz-Review,
   Sparse-Attention-Digital-Twin-Paper, Food-Industry-QC-Review, mlr3book,
   2 Traceability/BOM-Papers (gehören eher zu `C:\Git\traceability`).
4. **Neue Datensatz-Kandidaten aus der Literatur, noch nicht zu Projekten
   gemacht**: Steel Plates Faults (klein, 7-Klassen, real - Klassifikation),
   APS Failure at Scania Trucks (binär, real, bekanntes Imbalance-Benchmark -
   Klassifikation), Mining Process / Quality Prediction (Regression, 737k
   Zeilen). Details + Quellen in `C:\Git\literatur\bewertung.md` bzw.
   `jourdan2021.txt` dort.
5. Kein neues Buch für die nächste Runde vorgemerkt - falls die nächste
   Session mit neuem Material startet, gleiche Methodik (Ideen extrahieren,
   einzeln verifizieren, erst danach backporten).

## Wichtige Konventionen (falls die nächste Session sie noch nicht kennt)

- Commit und Push sind zwei separate, jeweils explizit vom User bestätigte
  Schritte - nie automatisch pushen.
- Vor jedem heuristischen Backport (Guards/Tests, nicht mathematisch
  beweisbare Methoden wie Conformal Prediction): auf ≥2 unabhängigen
  Datensätzen mit Ground-Truth-Design verifizieren (ADR-003).
- Ein neues, optionales Modul folgt dem `segment_metric_cols`-Muster:
  Config-Default leer/`NA` -> Skript überspringt sich selbst. Beim
  Regressionstest gegen das Template-eigene Projekt Config NUR temporär
  befüllen, danach wieder auf den leeren Default zurücksetzen.
- Aufgabentyp-unabhängige Module (funktionieren fuer Klassifikation UND
  Regression) werden identisch in beide Templates uebernommen, wie
  `univariate_drift.R` und jetzt `sanity_checks.R`.
- PDF-Arbeit auf dieser Maschine: `WebFetch` auf arXiv-PDFs scheitert oft an
  der Volltext-Extraktion, speichert aber die Roh-PDF in einen Temp-Pfad -
  von dort kopieren und mit R `pdftools::pdf_text()` extrahieren. Manche
  Publisher-Seiten blocken einfache HTTP-Clients - über das echte
  Browser-Tool (`mcp__Claude_Browser__*`) geht es oft trotzdem.
- Vollständiger Kontext: `TARGETS.md` (Klassifikation) bzw. `BACKLOG.md`
  (Regression), `C:\Git\literatur\bewertung.md`, sowie das persistente
  Gedächtnis (`project_mlr3_automl_template.md` + `project_literatur_
  review_produktion_ki.md`, Claude-Memory, automatisch geladen).

## Empfohlener erster Schritt der nächsten Session

Diese Datei vorlesen lassen ("lies C:\Users\HP\Downloads\SESSION_HANDOFF.md"),
dann entscheiden: Ensemble-Selection-Backport angehen (Punkt 1, größter
offener Posten seit mehreren Sessions), oder eine der neuen
Datensatz-Kandidaten (Punkt 4) als Projekt aufsetzen?
