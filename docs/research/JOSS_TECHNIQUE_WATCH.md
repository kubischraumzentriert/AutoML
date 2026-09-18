# JOSS Technique Watch

**Stand: 2026-08-30.** P1 aus der 2026-08-30-Bewertung
(`AutoML_Bewertung_Naechste_Schritte_JOSS_Technique_Watch_2026-08-30.md`,
`~/Downloads`): den JOSS-Paper-Korpus (aktuell ~3242 Papers, ~2875
veroeffentlicht, https://joss.theoj.org/papers/) systematisch nach
Techniken durchsuchen, die Trust, Reproduzierbarkeit, Experimentdesign,
Evaluation oder Wartbarkeit verbessern - NICHT nach neuen Modellfamilien
oder generischem Feature-Zuwachs.

## Regel fuer JOSS-Ideen (aus dem Bewertungsdokument, verbindlich)

Keine JOSS-Technik wird direkt uebernommen. Jede Idee durchlaeuft:

```text
JOSS Paper
-> Problem im eigenen Template vorhanden?
-> konkrete Hypothese
-> Komplexitaetskosten
-> kleiner Prototyp
-> synthetischer Test
-> 1-2 reale Projekte
-> Backport-Regel (ADR-003)
```

[`adr/003-backport-after-confirmation.md`](../../adr/003-backport-after-confirmation.md)
bleibt massgeblich: kein Backport ohne >=2-Projekt-Bestaetigung oder
Null-Ergebnis-Beleg. Default fuer jeden Kandidaten unten: **NO BACKPORT
bis Evidenz vorhanden.**

## Alle 7 DOIs/Autoren/Jahre unabhaengig verifiziert (2026-08-30)

Jeder Eintrag unten wurde direkt gegen `joss.theoj.org/papers/<DOI>`
geprueft (nicht aus dem Bewertungsdokument uebernommen ohne Gegenpruefung)
- alle 7 stimmten exakt mit den dort genannten Angaben ueberein.

---

## 1. VeridicalFlow (PCS-Decision-Stability)

- **Titel**: VeridicalFlow: a Python package for building trustworthy
  data science pipelines with PCS
- **Autoren/Jahr**: Duncan, Kapoor, Agarwal, Singh, Yu (2022)
- **DOI**: [10.21105/joss.03895](https://doi.org/10.21105/joss.03895)
- **Welches Problem loest es?** PCS (Predictability, Computability,
  Stability) als Rahmenwerk: zeigt, welche Analyse-/Modellwahl-
  Entscheidungen sich aendern, wenn Seeds, Splits, Preprocessing-Varianten
  oder Modellwahl leicht variiert werden - eine uebergeordnete
  Stabilitaetssicht statt Einzelchecks.
- **Welcher Teil ist uebertragbar?** Die Kernidee (nicht der Python-Code):
  ein "Decision Stability Report", der zeigt, ob Endentscheidungen
  (welches Modell, welcher Threshold, welches Ensemble-Mitglied) robust
  gegenueber kleinen, plausiblen Variationen sind.
- **Haben wir dieses Problem?** Teilweise abgedeckt durch Einzelchecks
  (Seed-Stability, Split-Size-Sensitivity, Generalisierungsluecke) - aber
  KEIN uebergeordneter Report, der zeigt, ob die END-Entscheidung
  (Modellwahl/Ensemble-Mitgliedschaft/Threshold) selbst stabil ist.
- **Hypothese**: ein Meta-Report ueber die Stabilitaet von Modell-/
  Workflow-Entscheidungen (nicht nur einzelner Scores) liefert
  zusaetzliche Trust-Information ueber die bestehenden Einzelchecks
  hinaus.
- **Erwarteter Nutzen**: staerkt die Trust-Story direkt (Kernthema
  dieses Templates) - koennte die bestehenden Einzelchecks (Seed-
  Stability etc.) zu einer kohaerenten uebergeordneten Aussage verbinden.
- **Komplexitaetskosten**: mittel-hoch - braucht mehrfache Wiederholung
  des gesamten Modellwahl-/Ensemble-Prozesses unter kleinen Variationen,
  nicht nur einen einzelnen zusaetzlichen Check.
- **Prototype**: JA (Stand 2026-09-18, Eintrag war veraltet) - als
  `decision_stability.R`/`decision_stability_level2_prototype.R`
  umgesetzt, synthetisch verifiziert und an 15 externen CC18-
  Datensaetzen real angewendet (n=6 -> 10 -> 15 erweitert).
- **Backport**: JA - im Template (`modules/decision_stability.R`).
  Zentraler Befund: die urspruenglich suggestive Fold-1-Korrelation
  zwischen Modell-Stabilitaet und Level-2-Vorteil (rho=-0.28, n=6) haelt
  der Erweiterung auf n=15 NICHT stand (rho=-0.147) - als widerlegt
  dokumentiert, siehe `statusanker/SESSION_HANDOFF_2026-08-29.md`.

## 2. astartes (schwierige/extrapolationsorientierte Splits)

- **Titel**: Machine Learning Validation via Rational Dataset Sampling
  with astartes
- **Autoren/Jahr**: Burns, Spiekermann, Bhattacharjee, Vlachos, Green
  (2023)
- **DOI**: [10.21105/joss.05996](https://doi.org/10.21105/joss.05996)
- **Welches Problem loest es?** Zufaellige Train/Test-Splits messen vor
  allem Interpolationsleistung. Aehnlichkeits-/distanzbasierte Splits
  pruefen gezielt Extrapolationsleistung - ein Modell, das nur bei
  zufaelligen Splits stabil ist, aber bei strukturell schwierigeren
  Splits stark einbricht, hat ein hoeheres Generalisierungsrisiko als der
  Standard-CV-Score allein zeigt.
- **Welcher Teil ist uebertragbar?** Die Grundidee (schwierige Splits als
  Stresstest), nicht die Cheminformatik-spezifische Implementierung -
  Uebertragung auf generische tabellarische Daten muesste getestet
  werden.
- **Haben wir dieses Problem?** Bislang nur zufaellige CV-Splits (plus
  Group-aware-CV fuer echte Gruppenstruktur, wo vorhanden) - kein
  systematischer "wie schwer ist dieser Split wirklich"-Check bei
  generischen (nicht Gruppen-)Datensaetzen.
- **Hypothese**: ein Modell, dessen Performance nur bei zufaelligen
  Splits stabil ist, aber bei strukturell schwierigeren (distanz-
  basierten) Splits stark einbricht, besitzt ein hoeheres
  Generalisierungsrisiko als der Standard-CV-Score allein erkennen
  laesst.
- **Erwarteter Nutzen**: neuer Generalisierungs-Stresstest, ergaenzt die
  bestehende Group-aware-CV-Diagnostik um Faelle ohne explizite
  Gruppenstruktur.
- **Komplexitaetskosten**: moderat - ein zusaetzlicher Split-Modus +
  Vergleichsmetrik, keine Aenderung am Trainingsprozess selbst.
- **Prototype**: JA (Stand 2026-09-18, Eintrag war veraltet) - als
  `hard_split_stress_test.R` (k-means-Cluster-Split) umgesetzt.
- **Backport**: JA - im Template (`modules/hard_split_stress_test.R`,
  von `137_hard_split_stress_test.R` genutzt), ADR-003-Schwelle erfuellt
  (7/7 Projekt-Bestaetigungen). Echter Zusatzfund bei der Anwendung:
  ein harter Cluster-Split kann ein VERDECKTER Class-Holdout sein statt
  echter Extrapolation - `class_proportion_shift()`/
  `class_holdout_suspected`-Flag ergaenzt.

## 3. Autorank (Cross-Dataset-Statistik)

- **Titel**: Autorank: A Python package for automated ranking of
  classifiers
- **Autor/Jahr**: Herbold (2020)
- **DOI**: [10.21105/joss.02173](https://doi.org/10.21105/joss.02173)
- **Welches Problem loest es?** Formale, statistisch abgesicherte
  Vergleiche mehrerer Verfahren ueber mehrere Datensaetze (Demsar 2006:
  Wilcoxon Signed-Rank bei 2 Verfahren, Friedman+Nemenyi bei mehr,
  automatische Testauswahl je nach Normalitaet/Anzahl).
- **Welcher Teil ist uebertragbar?** Die Methodik (Demsar 2006), nicht
  das Python-Paket selbst - **bereits nativ in R umgesetzt** statt
  uebernommen (R-only-Policy).
- **Haben wir dieses Problem?** War der Ausloeser fuer den
  Research-Aspect-Weg (2026-08-30, siehe `BACKLOG.md`): das gepaarte
  Wilcoxon-Verfahren wird bereits in
  [`analysis/p2_level2_significance_test.R`](../../analysis/p2_level2_significance_test.R)
  verwendet.
- **Status**: **TEILWEISE BEREITS UMGESETZT** (kein reiner Watch-Punkt
  mehr) - die Wilcoxon-Signed-Rank-Methodik laeuft produktiv fuer den
  Level-1-vs-2-Vergleich. Noch NICHT uebernommen: eine allgemeine,
  wiederverwendbare `benchmark_statistics_report()`-Funktion (paired
  differences, Median, MAD, Mean Rank, bei genuegend Datensaetzen
  Friedman-Test, Nemenyi-Post-hoc, Critical-Difference-Diagramm,
  Effect-Size-Tabelle) - bislang nur als Einzelskript fuer P2.
- **Hypothese**: eine wiederverwendbare Statistik-Report-Funktion wuerde
  kuenftige Mehrfach-Datensatz-Vergleiche (nicht nur P2) konsistent
  absichern.
- **Komplexitaetskosten**: gering - im Kern base-R (`stats::friedman.
  test`), Nemenyi-kritische-Differenz per Standard-Formel + den in
  Demsar (2006) Tabelle 5(b) veroeffentlichten q_alpha-Werten selbst
  nachgebaut (KEINE `scmamp`-Abhaengigkeit noetig, R-only-Policy).
- **Prototype**: JA (Stand 2026-09-18) - `modules/benchmark_statistics_
  report.R`: `paired_wilcoxon_report()` (k=2), `friedman_nemenyi_
  report()` (k>=3, Friedman-Omnibus + Nemenyi-Post-hoc), `benchmark_
  statistics_report()` (waehlt automatisch). 25 synthetische Checks
  gruen, inkl. eines deterministischen Falls, der die Nemenyi-Schwelle
  selbst demonstriert (Rangdifferenz 2 signifikant, Rangdifferenz 1
  nicht, bei identischer zugrunde liegender Rangfolge).
- **Backport**: JA - im Template (`modules/benchmark_statistics_
  report.R`, `162_benchmark_statistics_report.R`).
  **Erste Realprojekt-Anwendung** (auf bereits vorhandene Protokoll-v2-
  Ergebnisse der 6 externen CC18-Datensaetze, kein neuer Lauf noetig):
  `workflow_ranger` hat den besten mittleren Rang (2.17 von 6 Armen),
  aber bei n=6 Datensaetzen haelt KEIN Paar der Nemenyi-Schwelle stand
  (Friedman p=0.477, kritische Differenz 3.08) - **bestaetigt exakt die
  eigene Vorhersage dieses Eintrags** ("erst bei mehr Datensaetzen
  aussagekraeftig"), ein ehrliches, informatives Nullergebnis statt
  einer unbelegten Behauptung.

## 4. PyExperimenter (geplante Experimente/Skalierung)

- **Titel**: PyExperimenter: Easily distribute experiments and track
  results
- **Autoren/Jahr**: Tornede, Tornede, Fehring, Gehring, Graf, Hanselle,
  Mohr, Wever (2023)
- **DOI**: [10.21105/joss.05149](https://doi.org/10.21105/joss.05149)
- **Welches Problem loest es?** Definition/Ausfuehrung/Wiederaufnahme
  vieler geplanter Experiment-Varianten + Datenbanksteuerung +
  Ergebnisaggregation.
- **Welcher Teil ist uebertragbar?** Die Idee einer `planned_experiment`-
  Tabelle (Status/Dataset/Methode/Budget/Seed/Prioritaet/Ergebnis-Run-ID)
  als Erweiterung der bestehenden Experiment-DB.
- **Haben wir dieses Problem?** Aktuell nein in relevantem Ausmass - die
  6 externen Laeufe wurden manuell/skriptgesteuert nacheinander
  gefahren, ohne formale Planungs-/Wiederaufnahme-Infrastruktur. Wuerde
  erst relevant, wenn der Benchmark auf 10-15+ Datensaetze waechst.
- **Hypothese**: bei einer groesseren Anzahl geplanter Laeufe (Research-
  Benchmark-Erweiterung) wuerde eine formale Planungstabelle Fehler
  (vergessene/doppelte Laeufe) reduzieren.
- **Komplexitaetskosten**: mittel - neue DB-Tabelle + einfache
  Ausfuehrungs-/Status-Logik.
- **Prototype**: nein.
- **Backport**: nein. **Prioritaet laut Bewertungsdokument: mittel** -
  vor allem relevant, WENN der Benchmark waechst.

## 5. ReciPies (Feature-Transformation-Provenienz)

- **Titel**: ReciPies: A Lightweight Data Transformation Pipeline for
  Reproducible ML
- **Autoren/Jahr**: van de Water, Schmidt, Rockenschaub (2026)
- **DOI**: [10.21105/joss.09261](https://doi.org/10.21105/joss.09261)
- **Welches Problem loest es?** Reproduzierbare, konfigurations-basierte
  Feature-Preprocessing-Pipelines mit Provenienz (welche Transformation,
  welche Eingabespalten, welcher Config-Hash).
- **Welcher Teil ist uebertragbar?** Die Idee einer expliziten
  `feature_recipe_id`/`function_hashes`/`config_hash`-Provenienz fuer
  Feature-Transformationen.
- **Haben wir dieses Problem?** VERMUTLICH SCHON GROESSTENTEILS
  ABGEDECKT durch `targets` (Cache-Invalidierung bei Code-/Daten-
  Aenderung) + Git-Commit-Logging + Feature-Set-Hash in
  `provenance.R`/`finalize_run_provenance()` - muesste explizit
  gegengeprueft werden, bevor irgendetwas Neues gebaut wird.
- **Hypothese**: falls eine Luecke existiert, waere sie schmal (z.B.
  Hashes einzelner Transformationsfunktionen statt nur des gesamten
  Feature-Sets).
- **Komplexitaetskosten**: gering, falls ueberhaupt noetig - eher eine
  Pruef- als eine Bauaufgabe.
- **Prototype**: nein.
- **Backport**: nein. **Prioritaet laut Bewertungsdokument: mittel** -
  erst pruefen, ob `targets` + Git + Feature-Set-Hash das bereits
  ausreichend abdecken.

## 6. ImageMLResearch (Experiment-Organisation, nicht die Bildmethoden)

- **Titel**: ImageMLResearch: A Python Toolkit for Reproducible
  Image-Based ML Experiments
- **Autoren/Jahr**: Kraker, Schappacher-Tilp (2026)
- **DOI**: [10.21105/joss.10130](https://doi.org/10.21105/joss.10130)
- **Welches Problem loest es?** Reproduzierbare Bild-ML-Experimente -
  fuer dieses Template NICHT die Bildmethoden relevant, sondern die
  Experiment-Ordnerstruktur/Report-Generierung/Artefakt-Konventionen/
  Nutzer-Onboarding-Muster.
- **Welcher Teil ist uebertragbar?** Ggf. Konventionen fuer Onboarding-
  Dokumentation/Artefakt-Organisation - noch nicht im Detail geprueft.
- **Haben wir dieses Problem?** Nicht dringend - `README.md`/
  `README_DETAILS.md`/`CONTRIBUTING.md` decken Onboarding bereits ab.
- **Hypothese**: keine konkrete formuliert (niedrige Prioritaet).
- **Komplexitaetskosten**: nicht bewertet.
- **Prototype**: nein.
- **Backport**: nein. **Prioritaet laut Bewertungsdokument:
  niedrig-mittel.**

## 7. mlr3extralearners (Learner-Integrationsvertrag)

- **Titel**: mlr3extralearners: Expanding the mlr3 Ecosystem with
  Community-Driven Learner Integration
- **Autoren/Jahr**: Fischer et al. (26 Autoren, mlr-org-Kernteam) (2025)
- **DOI**: [10.21105/joss.08331](https://doi.org/10.21105/joss.08331)
- **Welches Problem loest es?** Formaler Integrationsvertrag fuer neue
  Learner ins mlr3-Oekosystem (predict_type, weights, multiclass,
  missing values, probability output, Laufzeit, reproduzierbarer Seed,
  CI-Installierbarkeit).
- **Welcher Teil ist uebertragbar?** Die Checkliste selbst, FALLS
  spaeter neue Learner ins Template kommen.
- **Haben wir dieses Problem?** Nein, aktuell nicht - Modellbreite ist
  bewusst keine Prioritaet (Ranger + LightGBM, siehe `PAPER_DRAFT.md`
  Section "Software design": Komplexitaetsbudget bewusst in die
  Trust-Schicht statt in Modellvielfalt investiert).
- **Hypothese**: keine (nicht aktuell relevant).
- **Komplexitaetskosten**: nicht bewertet.
- **Prototype**: nein.
- **Backport**: nein. **Prioritaet laut Bewertungsdokument: niedrig.**

---

## 8. stacks / negative Stacking-Gewichte (Ensemble-Korrektur)

**Herkunft dieses Kandidaten**: NICHT aus dem urspruenglichen
Bewertungsdokument, sondern aus einem Kaggle-Write-up (7th-Place-
Loesung, `playground-series-s6e8`, "Way Too Many Models, One Simple
Stack") - dort ein Befund berichtet: das Abziehen von 25%/10% eines
schwaecheren Sub-Blends vom Hauptblend (negative Gewichte) verbesserte
das OOF-Ergebnis (0.970820 -> 0.970849), weil der schwaechere Blend
eine vom Hauptblend "ueberbenutzte" Fehlerrichtung repraesentierte.
Eigene Recherche im JOSS-Korpus danach ergab einen direkt passenden,
bereits publizierten R-Beleg fuer dieselbe Idee (siehe unten) - der
Kaggle-Befund ist damit keine Einzelanekdote, sondern deckt sich mit
einer bewusst eingebauten, dokumentierten Option in einem
begutachteten R-Paket.

- **Titel**: stacks: Stacked Ensemble Modeling with Tidy Data
  Principles
- **Autoren/Jahr**: Couch, Kuhn (2022)
- **DOI**: [10.21105/joss.04471](https://doi.org/10.21105/joss.04471)
- **Welches Problem loest es?** Tidy-Data-prinzipientreues Ensemble-
  Stacking in R: ein regularisierter linearer Meta-Learner (`glmnet`)
  bestimmt die Gewichte der Ensemble-Mitglieder. Verifiziert (nicht nur
  aus dem Paper-Abstract, sondern aus der tatsaechlichen Funktions-
  dokumentation): `blend_predictions()` hat ein `non_negative`-Argument
  (Default `TRUE` - Gewichte auf `lower.limits = 0` in
  `glmnet::glmnet()` beschraenkt), das bei `FALSE` explizit `-Inf`
  erlaubt, also NEGATIVE Stacking-Gewichte zulaesst.
- **Welcher Teil ist uebertragbar?** NICHT das Paket selbst (wir
  bleiben bei unserer eigenen Caruana-Greedy-Ensemble-Selection, siehe
  `../reference/REFERENZ_ENSEMBLE_SELECTION.md`), sondern die KONKRETE Idee: unsere
  `ensemble_selection.R` erlaubt aktuell NUR nicht-negative Gewichte
  (Greedy-Selection mit Zuruecklegen, klassisches Caruana-Verfahren) -
  ein zusaetzlicher, alternativer linearer Stacking-Modus mit erlaubten
  negativen Koeffizienten (analog `non_negative = FALSE`) koennte
  Faelle abdecken, in denen ein schwaecheres/redundantes Kandidatenmodell
  eine vom Hauptensemble ueberbenutzte Fehlerrichtung korrigieren
  koennte.
- **Haben wir dieses Problem?** Bisher nicht explizit untersucht -
  unsere Ensemble-Kandidatenpools sind bislang kleiner (typischerweise
  Ranger/LightGBM/Ensemble, nicht 500+ Streams wie im Kaggle-Beispiel),
  daher ist unklar, ob die "ueberbenutzte Fehlerrichtung"-Situation bei
  unserer Pool-Groesse ueberhaupt relevant auftritt.
- **Hypothese**: bei einem Ensemble-Kandidatenpool mit mehreren
  aehnlichen/korrelierten Modellen verbessert das Zulassen negativer
  Stacking-Gewichte (via regularisierter linearer Meta-Learner statt
  Greedy-Selection) das OOF-Ergebnis gegenueber der aktuellen
  nicht-negativen Greedy-Selection.
- **Erwarteter Nutzen**: potenziell ein kleiner, aber echter Score-
  Hebel bei Projekten mit einem groesseren/redundanteren Kandidatenpool
  - direkte Analogie zum gemessenen Kaggle-Befund.
- **Komplexitaetskosten**: mittel - braucht einen ALTERNATIVEN
  Stacking-Modus (nicht Ersatz fuer die bestehende Greedy-Selection,
  siehe ADR fuer die Ensemble-Selection-Entscheidung), UND sorgfaeltige
  OOF-/Nested-CV-Disziplin (dieselbe wie bei
  `nested_cv_class_multiplier_tuning.R`), da unbeschraenkte/negative
  Gewichte deutlich anfaelliger fuer Overfitting auf Rauschen sind als
  nicht-negative Greedy-Selection.
- **Prototype**: JA (2026-09-03) - `163_stacking_negative_weights.R` in
  `PredictingElectricVehiclePurchases-s6e9` (24-Modelle-Pool aus
  `148_ensemble_candidate_pool.R`: 8 Ranger/8 LightGBM/8 CatBoost).
  `glmnet::cv.glmnet(family="binomial", lower.limits=0 vs. -Inf)` als
  direkter Mechanik-Nachbau von `stacks::blend_predictions()`s
  `non_negative`-Argument. **Ergebnis: Nullbefund.** Der Meta-Learner
  waehlte selbst mit erlaubten negativen Gewichten 0 von 24 negative
  Koeffizienten - die Hypothese ("ueberbenutzte Fehlerrichtung
  korrigieren") griff hier nicht, beide Varianten identisch (AUC
  0.9416 auf der Bestaetigungsmenge). Bemerkenswert: das beste
  Einzelmodell im Pool (AUC 0.9427) schlug SOGAR beide Stacking-
  Varianten UND den gleichgewichteten Blend - konsistent mit dem
  durchgehenden Nullbefund-Muster dieses Projekts (Feature Engineering,
  Klassengewichtung, CatBoost-Einzelmodell, AUC-Blend - siehe
  BACKLOG.md, 2026-09-02/03). **Einordnung (damals)**: n=1-Bestaetigung,
  ADR-003-Schwelle (>=2 unabhaengige Projektbestaetigungen) noch nicht
  erreicht.
- **2. Test (2026-09-14, `MLR3_Regression`-BACKLOG Kandidat 29)**:
  `electricity-load-panel/035_negative_stacking_weights.R` - erste
  Anwendung in einem REGRESSIONS-Projekt (RMSE statt AUC), 15-Modelle-
  Pool (5 Ranger/5 LightGBM/5 CatBoost, analog `127_ensemble_candidate_
  pool.R`). **Ergebnis: erneuter Nullbefund, identisches Muster** - 0
  von 15 negative Koeffizienten trotz erlaubter negativer Gewichte,
  beide Stacking-Varianten identisch (RMSE 122,53), UND das beste
  Einzelmodell im Pool (`lightgbm_9`, RMSE 120,20) schlug wieder BEIDE
  Stacking-Varianten. **ADR-003-Schwelle jetzt erreicht: 2 unabhaengige
  Projekte (Klassifikation UND Regression), beide negativ, beide mit
  demselben "bestes Einzelmodell schlaegt Stacking"-Muster.** Kein
  Backport - negative Stacking-Gewichte helfen bei unseren
  Kandidatenpool-Groessen (15-25 Modelle) offenbar grundsaetzlich nicht,
  unabhaengig von Aufgabentyp.
- **Backport**: nein - nach 2 unabhaengigen negativen Bestaetigungen
  (Klassifikation + Regression) ADR-003-reif als GESCHLOSSENER
  Negativbefund, nicht als "noch zu bestaetigende Hypothese". Prioritaet
  auf **niedrig** final gesetzt - kein weiterer Prototyp geplant, ausser
  ein zukuenftiges Projekt hat einen deutlich groesseren/staerker
  korrelierten Kandidatenpool als die bisher getesteten 15-25 Modelle
  (dort koennte die "ueberbenutzte Fehlerrichtung"-Situation aus dem
  Kaggle-Befund eher auftreten).

---

## Zusaetzlicher Hinweis: mlr3 selbst als laufender Check (kein Kandidat, sondern Erinnerung)

- **Titel**: mlr3: A modern object-oriented machine learning framework
  in R
- **Autoren/Jahr**: Lang, Binder, Richter, Schratz, Pfisterer, Coors,
  Au, Casalicchio, Kotthoff, Bischl (2019)
- **DOI**: [10.21105/joss.01903](https://doi.org/10.21105/joss.01903)
  (bereits die Basis dieses Templates, siehe `PAPER_DRAFT.md`
  Related Work)
- **Empfehlung aus dem Bewertungsdokument**: vor jeder neuen eigenen
  Infrastruktur regelmaessig pruefen, ob das mlr3-Oekosystem das
  Problem inzwischen bereits sauber loest, statt es selbst zu bauen.
  Kein Prototyp/Backport-Eintrag, sondern eine wiederkehrende
  Pruefpflicht bei kuenftigen Infrastruktur-Entscheidungen.

## Priorisierung (aus dem Bewertungsdokument uebernommen)

| Idee | Potenzieller Nutzen | Prioritaet |
|---|---|---|
| VeridicalFlow / Decision-Stability | staerkt Trust-Story direkt | **hoch** |
| astartes / schwierige Splits | neuer Generalisierungs-Stresstest | **hoch** |
| Autorank / Benchmark-Statistik | staerkt Research-Evaluation, TEILWEISE bereits umgesetzt | **hoch, sobald n groesser** |
| PyExperimenter / geplante Studien | skaliert Benchmark-Ausfuehrung | mittel |
| ReciPies / Transformation-Provenienz | Reproduzierbarkeit, evtl. schon abgedeckt | mittel |
| mlr3 (laufender Check) | Eigenentwicklungen vermeiden | mittel |
| ImageMLResearch | Experiment-/Report-Organisation | niedrig-mittel |
| mlr3extralearners | Learner-Integrationsstandard | niedrig |
| stacks / negative Stacking-Gewichte | evtl. kleiner Score-Hebel bei groesseren Kandidatenpools (Kaggle-Befund + JOSS-Beleg) | mittel |

## Warnung: kein Feature Creep

```text
interessantes Paper -> interessante Funktion -> sofort implementieren
```

ist fuer den jetzigen Reifegrad falsch. Stattdessen:

```text
interessantes Paper -> eigenes Problem identifizieren -> Hypothese
formulieren -> Nutzen > Komplexitaet? -> erst dann Prototype
```

Default bleibt **NO BACKPORT bis Evidenz vorhanden**.
