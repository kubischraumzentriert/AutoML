# Session Handoff (Stand 2026-08-10, Abend) - Statusanker

Dies ist der committete, zeitgestempelte Zwilling der lokalen Arbeitskopie
unter `C:\Users\HP\Downloads\SESSION_HANDOFF.md`. Die lokale Kopie wird bei
jeder Session überschrieben (keine Dauerdokumentation); dieser Statusanker
bleibt als Verlaufs-Schnappschuss im Repo stehen, ein neuer kommt pro Session
mit eigenem Datum hinzu (`statusanker/SESSION_HANDOFF_<Datum>.md`).

## Repo-Zustand

Beide Templates sauber, nichts uncommittet, alles gepusht:
- `MLR3_Classifikation` (C:\Users\HP\OneDrive\Dokumente\R_Workspace\MLR3_Classifikation)
  @ `05e2c27` "Document lightgbm_tuning_evals budget ablation; correct mlr3torch embedding premise"
- `MLR3_Regression` (C:\Users\HP\OneDrive\Dokumente\R_Workspace\MLR3_Regression)
  @ `b2c2f18` "Add split-conformal prediction intervals module"

## Was in dieser Session passiert ist

**1. Huyen-Sanity-Checks (Perturbation/Invarianz/Directional Expectation)
fertig gebackportet.** Waren beim Sessionstart noch 0-Projekt-Kandidaten
("eher pro-Projekt-Muster als generisches Modul" - diese Einschätzung war zu
vorsichtig). Prototypisiert (Standalone in
`ML_Learning\health-condition-huyen-sanity-tests\`), an Ground-Truth
verifiziert (bewusst kaputte vs. saubere Modelle, Sensitivität+Spezifität
sauber getrennt), an 2 realen Projekten bestätigt (health_condition +
PumpItUp - beide zeigen dasselbe Muster: Directional-Expectation-Test findet
zuverlässig 3-5% substanzielle Richtungs-Verletzungen, Perturbation/Invarianz
bleiben unauffällig). Gebackportet: `sanity_checks.R` +
`147_error_analysis_ranger_sanity_checks.R` (Klassifikation, default-inert),
plus `REFERENZ_MODEL_SANITY_CHECKS.md` (theoretischer Hintergrund, auf
Nutzeranfrage nachgezogen). Committet+gepusht (`87c4751`).
**Noch NICHT in die Regression übertragen** (siehe offene Punkte).

**2. Literaturliste "Traceability & KI in der Produktion" abgearbeitet.**
Nutzer brachte eine vorformulierte Anweisung zu 13 Quellen (Produktions-
Datensatz-Reviews, arXiv/PMC-Papers, mlr3/AutoML-Tooling-Docs) mit, Ziel:
Ideen für den Workflow sammeln. Statt 13 Einzelrunden: Batch-Vorab-Triage,
dann 8 vom Nutzer bestätigte Titel per Volltext bewertet. Alles in
`C:\Git\literatur\bewertung.md` (+ Volltexte/Extrakte dort), durables in
`project_literatur_review_produktion_ki.md` (Memory). Zwei Downloads
scheiterten zunächst (Bot-Blocker) - Jourdan et al. per echtem Browser-Tool
gefunden (direkter Bitstream-Link), Krauß et al. per Browser bestätigt
GENUIN paywalled (kein Open-Access-Fund trotz Listen-Annahme, bewusst nicht
über Drittanbieter-Mirrors umgangen).

**3. Drei konkrete Funde direkt umgesetzt:**
- **Conformal Prediction Intervals** (aus dem MLOps/UQ-Semiconductor-Paper):
  neues, verifiziertes Modul `conformal_prediction.R` +
  `128_conformal_prediction_intervals.R` im **Regressions**-Template
  (default-inert, baut auf `120_full_holdout_confirmation.R` auf, kein
  Retraining). Ground-Truth: Coverage hält homo- UND heteroskedastisch,
  bricht sichtbar bei simuliertem Distribution-Shift. Gegen road-accident-
  risk bestätigt (Coverage 0.901 vs. Ziel 0.900). Kein zweites Projekt nötig
  (mathematisch verteilungsfrei-gültig, nicht heuristisch). Committet+
  gepusht (`b2c2f18`).
- **mlr3torch-Prämisse korrigiert** (NEURAL_DEPLOY.md, Klassifikation):
  `po("torch_ingress_categ")` + `nn("tokenizer_categ")` ist fertiges,
  dokumentiertes Idiom (selber Tokenizer wie FT-Transformer), kein
  Eigenbau wie beim s6e8-Verwerfen von `classif.mlp`/`classif.tab_resnet`
  angenommen. NICHT prototypisiert (kein aktuelles Projekt braucht es) -
  nur die Prämisse für künftige GPU-lose Projekte korrigiert.
- **`lightgbm_tuning_evals`-Budget-Ablation** (25 vs. 45, aus der
  mlr3mbo-Paper-Lektüre): gemessen, Ergebnis gemischt (mehr Budget = mehr
  echte BO-Verfeinerung, aber kleiner/uneinheitlicher Metrik-Effekt, beide
  getunten Varianten bleiben unter dem ungetunten Default - bestätigt die
  längst bekannte "Tuning bringt marginale Gewinne"-Lehre erneut). Template-
  Default bleibt bei 25. Beide Punkte dokumentiert in TARGETS.md,
  committet+gepusht zusammen mit der mlr3torch-Korrektur (`05e2c27`).

## Offene Punkte für die nächste Session

1. **Ensemble Selection backporten** (weiterhin der größte offene Punkt,
   unverändert seit letzter Session). Verifiziert (2 Datensätze), aber nicht
   integriert. Blocker laut TARGETS.md: Benchmark-Skripte loggen nur die
   finale Metrik je Kandidat, nicht die Vorhersagen jedes Kandidaten auf
   einem gemeinsamen Holdout - das müsste zuerst ergänzt werden.
2. **Huyen-Sanity-Checks noch nicht in die Regression übertragen.** Nur in
   Klassifikation gebackportet. Regression hat jetzt eine Asymmetrie: 3
   Module (Perturbation/Invarianz/Directional), die dort fehlen - kein
   expliziter Auftrag bisher, das zu spiegeln.
3. Regression-Template hat weiterhin mehrere 0-Projekt-Kandidaten offen aus
   der Klassifikationsseite (Meta-Learning-Warmstart, Successive Halving -
   beide dort negativ/verworfen, müssten bei Bedarf unabhängig getestet
   werden, nicht einfach übernommen).
4. **5 Literatur-Titel nicht tiefer bewertet** (niedrige Priorität, siehe
   `C:\Git\literatur\bewertung.md`): Additive-Manufacturing-Datensatz-Review
   (bildbasiert, off-tabellarisch), Sparse-Attention-Digital-Twin-Paper
   (Deep-Learning-spezifisch), Food-Industry-QC-Review (Hintergrundniveau),
   mlr3book (bereits gut bekannt), 2 Traceability/BOM-Papers (gehören eher
   zu `C:\Git\traceability`, dem separaten MES-Projekt, nicht zu den
   AutoML-Templates).
5. **Neue Datensatz-Kandidaten aus der Literatur, noch nicht zu Projekten
   gemacht**: Steel Plates Faults (klein, 7-Klassen, real - Klassifikation),
   APS Failure at Scania Trucks (binär, real, bekanntes Imbalance-Benchmark -
   Klassifikation), Mining Process / Quality Prediction (Regression, 737k
   Zeilen). Details + Quellen in `C:\Git\literatur\bewertung.md` bzw.
   `jourdan2021.txt` dort.
6. Kein neues Buch für die nächste Runde vorgemerkt - falls die nächste
   Session mit neuem Material startet, gleiche Methodik (Ideen extrahieren,
   einzeln verifizieren, erst danach backporten).

## Wichtige Konventionen (falls die nächste Session sie noch nicht kennt)

- Commit und Push sind zwei separate, jeweils explizit vom User bestätigte
  Schritte - nie automatisch pushen.
- Vor jedem heuristischen Backport (Guards/Tests, nicht mathematisch
  beweisbare Methoden wie Conformal Prediction): auf ≥2 unabhängigen
  Datensätzen mit Ground-Truth-Design verifizieren (ADR-003).
- Ein neues, per-se optionales Modul folgt dem `segment_metric_cols`-Muster:
  Config-Default leer/`NA` -> Skript überspringt sich selbst, kein Eingriff
  ins bestehende Logging. Beim Regressionstest gegen das Template-eigene
  Projekt Config NUR temporär befüllen, danach wieder auf den leeren
  Default zurücksetzen, bevor committet wird.
- PDF-Arbeit auf dieser Maschine: `WebFetch` auf arXiv-PDFs scheitert oft an
  der Volltext-Extraktion, speichert aber die Roh-PDF in einen Temp-Pfad -
  von dort kopieren und mit R `pdftools::pdf_text()` extrahieren (installiert,
  `Read`-Tool kann PDFs hier nicht rendern, kein poppler). Manche
  Publisher-Seiten blocken einfache HTTP-Clients (Bot-Challenge) - ueber das
  echte Browser-Tool (`mcp__Claude_Browser__*`) geht es oft trotzdem.
- Vollständiger Kontext / Details zu jedem einzelnen Fund: `TARGETS.md`
  (Klassifikation) bzw. `BACKLOG.md` (Regression), `C:\Git\literatur\
  bewertung.md` (Literaturbewertung), sowie das persistente Gedächtnis
  (`project_mlr3_automl_template.md` + `project_literatur_review_
  produktion_ki.md`, Claude-Memory, automatisch geladen).

## Empfohlener erster Schritt der nächsten Session

Diese Datei vorlesen lassen ("lies C:\Users\HP\Downloads\SESSION_HANDOFF.md"),
dann entscheiden: Ensemble-Selection-Backport angehen (Punkt 1, größter
offener Posten seit mehreren Sessions), Huyen-Checks in die Regression
spiegeln (Punkt 2), oder eine der neuen Datensatz-Kandidaten (Punkt 5) als
Projekt aufsetzen?
