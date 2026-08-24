# Session Handoff (Stand 2026-08-23, spaeter Abend, 2. Update) - Statusanker

Dies ist der committete, zeitgestempelte Zwilling der lokalen Arbeitskopie
unter `C:\Users\HP\Downloads\SESSION_HANDOFF.md`. Die lokale Kopie wird bei
jeder Session überschrieben (keine Dauerdokumentation); dieser Statusanker
bleibt als Verlaufs-Schnappschuss im Repo stehen. Innerhalb desselben
Session-Tages wird dieser Anker aktualisiert (wie jetzt, 2. Aktualisierung
2026-08-23); ein neuer Tag bekommt eine neue Datei.

## Repo-Zustand

Alle drei Repos sauber, nichts uncommittet, Templates gepusht:
- `MLR3_Classifikation` (`C:\Users\HP\OneDrive\Dokumente\R_Workspace\MLR3_Classifikation`)
  @ `4c55ff5` "TARGETS.md: SOM/LLE-Einschaetzung ergaenzt, Cluster-/Struktur-Feature-Ideenlinie abgeschlossen"
- `MLR3_Regression` (`C:\Users\HP\OneDrive\Dokumente\R_Workspace\MLR3_Regression`)
  @ `5dde371` "BACKLOG.md: Nummernkollision behoben" (unveraendert seit dem 1. Update heute)
- `ML_Learning` (`C:\Users\HP\ML_Learning`, rein lokal, kein Remote)
  @ `771125b` "bbbp-classification: SOM/LLE-Einschaetzung dokumentiert"
- **GitHub Actions CI (Klassifikation) ist gruen** (`smoke-test` + `unit-tests`,
  Lauf `32658179935`) - war 3 Commits lang rot, siehe unten. Regressions-Repo
  hat keine CI eingerichtet.

## Was in dieser (sehr langen) Session passiert ist

**1. Ensemble Selection gehaertet**: aus Skriptlogik in `149_ensemble_
selection.R` eine echte, testbare Funktion extrahiert (`ensemble_selection.R`,
`greedy_ensemble_selection()`), erste `testthat`-Unit-Tests des Repos
(`tests/testthat/test-ensemble_selection.R`, 5/5 gruen). Anlass: externes
Review.

**2. Suche nach der 2. Bestaetigung fuer das kumulative Leak-PAAR-Muster
(SBA-analog `ChgOffDate`+`ChgOffPrinGr`) - NICHT gefunden, Suche
eingestellt.** Vier Versuche: AER Credit Card (2-stufige Substitutionskette),
Give Me Some Credit (gar kein echter Leak), Lending Club (siehe Punkt 3),
fremtpl2-claim-leak-test (konstruiert, Partner bekam 0% Gain). Mechanismus
verstanden, aber nicht reproduzierbar konstruierbar: SBAs Paar behielt trotz
Korrelation genug UNABHAENGIGE Information, dass LightGBM beide nutzte -
alle 4 Kandidaten waren stattdessen entweder fast perfekt redundant oder zu
diffus verteilt. Mit Nutzer abgestimmt: Suche eingestellt, bleibt offen ohne
aktiven Auftrag.

**3. Dabei WICHTIGERER Fund: Lending Club zeigte einen massiven Leak
(BAcc 0.9983->0.5317), den der Guard komplett uebersah** (10 Post-Outcome-
Felder trugen zusammen nur ~31% Gain, kein Einzelfeature ueber 30%). Fuehrte
zu einer echten Guard-Verbesserung: **neuer Schritt 1b in
`015_target_leak_audit.R`** (Korrelations-Cluster-Zerlegung - numerische
Features nach Korrelation clustern, groessten Cluster per Retraining testen,
nur bei substanziellem Score-Effekt als Verdacht flaggen). Kostenkontrolle:
hoechstens 1 zusaetzliches Retraining, nur bei Vorfilter-Trigger. **Bekannte
Grenze**: faengt den Lending-Club-Extremfall selbst NICHT vollstaendig
(informatives Signal, aber unter der Warnschwelle) - trotzdem behalten, echte
Teilverbesserung. **5 reale Spezifitaetstests bestanden** (health_condition,
sba-loan-default, aer-creditcard-leak-test, bbbp-classification,
geoai-aquaculture - letzteres mit einem 36-Feature/56.3%-Gain-Cluster, dem
bisher groessten, korrekt nicht geflaggt) + 1 synthetischer Positivtest.
**Nach Regression cross-template portiert** (`MLR3_Regression/013_target_
leak_audit.R`, metrikrichtungs-agnostisch via `abs()`, No-op gegen
road-accident-risk verifiziert).

**4. Multi-Label Per-Label-NA-Maskierung generalisiert und ins Template
zurueckgefuehrt.** Anlass: `tox21-multilabel` (neues Chemie-Projekt, siehe
Punkt 5) war das erste Multi-Label-Projekt mit ECHTEN fehlenden Labels.
`binary_relevance_pool()`/`021_multilabel_workflow.R` filtern jetzt generisch
pro Label auf nicht-NA-Zeilen, geben nach row_id benannte Wahrscheinlichkeits-
Vektoren zurueck. No-op-getestet gegen yeast (byte-identisch) und scene,
positiv bestaetigt gegen tox21.

**5. Zwei neue Chemie-Projekte** (User-Idee: neue Domaene fuers Template
testen): `tox21-multilabel` (Toxikologie, 12 Assays, molekulare Fingerprints
via `rcdk`+SMILES, R-only bestaetigt - ADR-002 haelt auch hier) und
`bbbp-classification` (Blut-Hirn-Schranke, binaer). SVM-Hypothese des
Nutzers getestet ("SVM immer als Kandidat bei wenig-Zeilen/viele-Features-
Chemie/Biologie-Daten"): gemischtes Ergebnis (SVM-radial gewinnt BAcc auf
12/12 Tox21-Labels, aber Ranger gewinnt AUC auf 8/12; 45x langsamer) - kein
klares "immer mitnehmen", aber ein echter BAcc-Kandidat. **Eigener
Zeitschaetzungsfehler dabei**: Einzel-Label-SVM-Timing (137s) auf "15-25 Min"
fuer 12 Labels hochgerechnet, real 6,3 Stunden - als Lehre ins Memory
aufgenommen (SVM-Konvergenzzeit ist nicht verlaesslich extrapolierbar).

**6. Sentinel-Handling-Backlog-Punkt abgeschlossen mit echtem Negativbefund.**
`pima-diabetes-sentinel-test` (klassischer Lehrbuch-Sentinel-Fall): korrekte
spaltenspezifische Sentinel-Behandlung zeigt WEDER bei Ranger NOCH bei
logistischer Regression einen klaren Vorteil (Repeated CV). 1 positiver
(aquaculture) + 1 negativer/neutraler (Pima) Datenpunkt - Nutzen ist
projektspezifisch. Architektur-Fund nebenbei: `sentinel_to_na()` hat kein
Spalten-Scoping (waere bei Pima aktiv schaedlich gewesen), dokumentiert,
nicht umgesetzt.

**7. Backlog-Bestandsaufnahme ueber alle lokalen `TEMPLATE_FRICTION.md`-
Dateien.** Die meisten "noch nicht zurueckgefuehrt"-Eintraege waren bereits
erledigt, nur die Docs nie nachgezogen (gleiches Muster wie unten bei
`AGENTS.md`). EIN echter Fund: `error_analysis_uncertainty_threshold=0.5`
war bei binaeren Aufgaben strukturell entartet (aus `s6e5`s Friction-Doc von
Juli, nie zurueckgefuehrt) - gefixt: bei `n_classes<=2` wird der Fehler-
Median als adaptive Grenze genutzt statt eines Fixwerts. Byte-identisch
gegen `health_condition` regressionsgetestet.

**8. `AGENTS.md`s Publikations-Roadmap war veraltet** ("Ergebnistabelle noch
nicht begonnen", obwohl `SYSTEMATIC_EVALUATION.md` laengst fertig war) -
korrigiert.

**9. CI-Ausfall gefunden und behoben.** Beim Hinzufuegen von Schritt 1b
(Punkt 3) wurde `ci_smoke_test/000_config.R` (separate, von der CI genutzte
Fixture-Config) nicht mitgepflegt - 3 Commits lang rot (unbemerkt, bis der
Nutzer auf GitHub nachsah), da lokale Tests gegen echte Projekte mit eigenen
Configs das nicht faengen konnten. Gefixt, CI jetzt gruen. Als Prozess-Lehre
im Memory festgehalten: nach Pushes, die CI-abgedeckte Skripte aendern,
aktiv `gh run list` pruefen.

**10. Cluster-/Struktur-Feature-Engineering-Ideenlinie (Nutzeridee, NACH
dem ersten Handoff-Update heute) - vollstaendig durchgespielt.** Frage:
kann man Clustering/Dimensionsreduktion als zusaetzliche Features nutzen,
und welcher Algorithmus zuerst? Vier Methoden fold-sicher getestet
(Fitten IMMER nur auf Trainingsdaten, wie Target-Encoding):
- **K-Means** (`health-condition-kmeans-feature-test`, additive Cluster-
  ID+Distanz-Features): modellabhaengig - schadet Ranger (Rauschen,
  Baeume finden Cluster-Struktur selbst), hilft linearem Modell
  (Multinom +0.009 BAcc bei k=8).
- **PCA** (`bbbp-classification/032`, ERSETZT die 750/1024 rohen
  Fingerprint-Bits): hilft LogReg stark (+0.087 BAcc, loest Quasi-
  Separation), schadet SVM-RBF deutlich, Ranger neutral. Differenziertes
  Bild: bei SVM zaehlt der KERNEL, nicht nur "linear vs. Baum".
- **Autoencoder** (ANN2, `033`, wegen ~6 Min./Fit reduzierter Umfang -
  3 statt 5 Folds, 1 Komponentenzahl): LogReg-Gewinn fast identisch zu
  PCA (+0.059), aber schadet zusaetzlich Ranger (-0.035, PCA neutral) -
  ungetunter/verrauschter als PCAs exakte Loesung.
- **UMAP** (`uwot`, `034`, schnell genug fuer vollen Umfang): klarer,
  ROBUSTER Negativbefund - alle 4 Lerner, alle Komponentenzahlen
  schlechter als roh. Metrik-Hypothese (euklidisch unpassend fuer
  Bit-Vektoren) durch Hamming-Distanz-Nachtest GEPRUEFT UND VERWORFEN -
  kein Metrik-Artefakt, echter struktureller Nachteil (UMAP erhaelt
  lokale Nachbarschaft, nicht Klassentrennung).
- **SOM/LLE**: bewusst NICHT getestet, begruendete Einschaetzung
  dokumentiert statt Test (beide UMAP-Familie, LLE zusaetzlich keine
  saubere Fold-sichere Out-of-Sample-Projektion in R verfuegbar).

**Gesamtfazit**: PCA ist der klare Gewinner im Methoden-Vergleich -
schnell (Sekunden), robust, substanzieller Nutzen fuer schwache lineare
Baselines, schadet niemandem stark. Gutes Beispiel dafuer, Methoden
empirisch statt nach Reputation zu waehlen (UMAP "modern" != besser).
Kein Backport-Kandidat fuers Template (das primaer auf GBM/Ranger setzt),
aber ein wiederverwendbares Muster fuer kuenftige hochdimensionale
duennbesetzte Projekte mit linearen Modellen als Kandidaten.
Alles dokumentiert in `bbbp-classification/README.md` +
`health-condition-kmeans-feature-test/README.md` + `TARGETS.md`.

## Offene Punkte fuer die naechste Session

1. **Keine dringenden.** Backlog ist leer im Sinne von "alles bearbeitet und
   ehrlich dokumentiert" - auch wenn nicht alles "geloest" ist (Sentinel-
   Nutzen negativ, Leak-Paar-Muster nicht gefunden). Beides bewusst
   abgeschlossen, kein aktiver Auftrag mehr.
2. **SVM als Kandidat**: bei zukuenftigen Chemie-/Biologie-Projekten mit
   hochdimensionalen Fingerprint-/Deskriptor-Features lohnt sich ein
   SVM-Test (radial), aber NICHT ungetunt/unueberwacht laufen lassen -
   Laufzeit kann massiv explodieren (Konvergenzprobleme bei Default-
   Parametern), Einzel-Label-Zeitschaetzung nicht auf N Labels
   extrapolieren.
3. **Multi-Label NA-Maskierung**: nur an 1 Projekt (tox21) mit echten NAs
   bestaetigt, aber No-op-Regressionstest + strukturelles Argument wurden
   als ADR-003-ausreichend gewertet (bereits umgesetzt, kein offener Punkt,
   nur zur Einordnung).
4. Falls weitere Chemie-/Biologie-Projekte kommen: Fingerprint-Pipeline
   (`build_fingerprints.R` in tox21-multilabel/bbbp-classification) ist
   wiederverwendbar, `JAVA_HOME` muss weiterhin explizit gesetzt werden
   (`C:/Users/HP/Programme/Java/jdk-25.0.1`, siehe Memory
   `project_r_windows_env`).

## Wichtige Konventionen (falls die naechste Session sie noch nicht kennt)

- Commit und Push sind zwei separate, jeweils explizit vom User bestaetigte
  Schritte - nie automatisch pushen.
- Vor jedem heuristischen Backport (Guards, nicht mathematisch beweisbare
  Methoden): auf >=2 unabhaengigen Datensaetzen verifizieren (ADR-003) ODER
  No-op + 1 positive Bestaetigung, wenn ein 2. Datensatz unverhaeltnismaessig
  aufwaendig zu finden ist (diese Session mehrfach so gehandhabt).
- **NEU diese Session**: `ci_smoke_test/000_config.R` ist eine SEPARATE,
  eigenstaendig zu pflegende Config-Datei - neue `leak_audit_*`/sonstige
  Config-Variablen dort IMMER mitziehen, wenn ein CI-abgedecktes Skript
  (`.github/workflows/ci-smoke-test.yml`) davon abhaengt. Nach jedem Push
  `gh run list` pruefen statt nur lokal zu testen.
- **NEU diese Session**: bei "was ist noch offen"-Fragen lokale
  `TEMPLATE_FRICTION.md`-Status-Angaben NICHT blind vertrauen - meist schon
  erledigt, nur Doku nicht nachgezogen. Gegen den aktuellen Templatestand
  verifizieren.
- **NEU diese Session**: SVM-Laufzeitschaetzungen NIE von einem Item auf N
  extrapolieren (Konvergenz, nicht nur Datengroesse, treibt die Zeit).
- **NEU diese Session**: unbeaufsichtigte Feature-Engineering-Schritte
  (Clustering/Dimensionsreduktion als Features) MUESSEN fold-sicher sein -
  IMMER nur auf Trainingsdaten fitten, auf Test/Validierung nur
  transformieren (wie Target-Encoding). PCA/`uwot::umap_transform()`
  unterstuetzen das sauber, klassisches `lle` NICHT (kein Out-of-Sample-
  Transform) - vor einer Methode kurz pruefen, ob eine echte Fit/Transform-
  Trennung existiert.
- **NEU diese Session**: bei Methodenvergleichen (welcher Algorithmus
  zuerst?) empirisch statt nach Reputation urteilen - UMAP schlug hier
  trotz "modernerer" nichtlinearer Technik klar schlechter als PCA.
  Ebenso gilt: nicht jede plausible Erklaerung (Metrik falsch?) sofort
  glauben - gezielt gegenpruefen (Hamming-Nachtest bei UMAP), bevor ein
  Negativbefund als robust gilt.
- Aufgabentyp-unabhaengige Module werden identisch in beide Templates
  uebernommen (`univariate_drift.R`, `sanity_checks.R`, jetzt auch Schritt
  1b des Leak-Audits).
- Vollstaendiger Kontext: `TARGETS.md` (Klassifikation) bzw. `BACKLOG.md`
  (Regression), sowie das persistente Gedaechtnis
  (`project_mlr3_automl_template.md`, `project_target_leak_audit.md`,
  `feedback_runtime_cost_awareness.md`, Claude-Memory, automatisch geladen).

## Empfohlener erster Schritt der naechsten Session

Kein zwingender Einstiegspunkt - Backlog ist leer. Falls der Nutzer nichts
Konkretes mitbringt: `TARGETS.md`/Memory kurz auf neue Ideen durchsehen,
oder ein weiteres Chemie-/Biologie-Projekt als 3. Domaenen-Bestaetigung
(nach Tox21/BBBP) aufsetzen, falls die "SVM als Kandidat"-Frage (Punkt 2
oben) weiter untersucht werden soll.
