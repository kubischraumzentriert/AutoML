# Referenz: Caruana Greedy Ensemble Selection

Theoretischer Hintergrund zu `148_ensemble_candidate_pool.R` +
`149_ensemble_selection.R` (Klassifikation) bzw. `127_ensemble_candidate_
pool.R` + `129_ensemble_selection.R` (Regression). Der Code dokumentiert das
WAS; diese Referenz erklaert das WARUM. Quelle: Caruana, Niculescu-Mizil,
Crew, Ksikes (2004), *"Ensemble Selection from Libraries of Models"*, ICML
- dieselbe Methode, die spaeter in Auto-sklearn (Feurer et al.) eingesetzt
wurde. Verifiziert an 2 unabhaengigen OpenML-Datensaetzen (bank-marketing,
electricity) und gegen beide Template-eigenen Projekte regressionsgetestet,
siehe TARGETS.md/BACKLOG.md fuer die vollen Zahlen.

---

## 1. Welches Problem loest das?

Nach dem Training mehrerer Modelle (verschiedene Algorithmen, verschiedene
Hyperparameter) gibt es normalerweise zwei Standardoptionen:

1. **Ein Einzelmodell waehlen** (das mit der besten Validierungs-Metrik) -
   verschenkt Information aus allen anderen Modellen.
2. **Alle (oder eine Handvoll) gleichgewichtet mischen** - ein schwaches
   Modell im Pool verwaessert das Ergebnis (mehrfach in diesem Template
   beobachtet, siehe `project_mlr3_automl_template`-Memory: "ein schwaecheres
   Modell verwaessert einen gleichgewichteten Blend").

Ensemble Selection ist ein dritter Weg: aus einem **Pool** bereits
trainierter Modelle wird eine **Teilmenge mit Wiederholung** automatisch so
zusammengestellt, dass der resultierende (gleichgewichtete) Durchschnitt
dieser Teilmenge die Zielmetrik auf einer Validierungsmenge maximiert. Das
Verfahren entscheidet selbst, wie viele und welche Modelle beitragen sollen
- inklusive der Moeglichkeit, ein einzelnes starkes Modell effektiv hoeher zu
gewichten, indem es mehrfach in die Teilmenge aufgenommen wird.

## 2. Der Algorithmus (Greedy Forward Selection mit Wiederholung)

```text
1. Start: leeres Ensemble.
2. Wiederhole bis zur maximalen Ensemblegroesse (Rundenzahl):
   a. Fuer JEDEN Kandidaten im Pool: probiere ihn testweise zum aktuellen
      Ensemble hinzuzufuegen, berechne die Validierungsmetrik des
      resultierenden (gleichgewichteten) Durchschnitts.
   b. Nimm den Kandidaten mit der besten Validierungsmetrik dauerhaft ins
      Ensemble auf (auch wenn er schon drin ist - Wiederholung erlaubt).
   c. Merke dir den Ensemble-Stand mit der bisher besten Validierungsmetrik.
3. Finales Ensemble = der beste gemerkte Stand (nicht zwingend der letzte).
```

**Warum "greedy" (gierig)**: in jeder Runde wird die Entscheidung getroffen,
die IM MOMENT am besten aussieht - ohne zurueckzuschauen (kein Entfernen
bereits gewaehlter Modelle) und ohne vorauszuplanen (keine Suche nach der
global besten Kombination). Das ist eine bewusste Naeherung: die wirklich
optimale Teilmenge+Gewichtung aus einem Pool von N Modellen exakt zu finden,
ist kombinatorisch nicht handhabbar (2^N Teilmengen, dazu kontinuierliche
Gewichte). Greedy kostet nur "probiere alle N Kandidaten einmal pro Runde"
(linear in der Poolgroesse je Runde) und kommt in der Praxis meist nah ans
Optimum - ohne Garantie. Dasselbe Prinzip wie bei der Splitwahl in einem
einzelnen Decision-Tree-Knoten (lokal optimal, nicht global garantiert).

**Warum Wiederholung erlaubt ist**: ohne Wiederholung koennte jedes Modell
nur einmal gewaehlt werden, was einer Einzelgewichtung von `1/Ensemblegroesse`
entspraeche. Mit Wiederholung kann ein besonders starkes Modell mehrfach
gewaehlt werden - das entspricht einer hoeheren effektiven Gewichtung im
Durchschnitt, ohne dass der Algorithmus explizit Gewichte optimieren muss
(einfacher, robuster gegen Overfitting der Gewichte selbst als eine direkte
Gewichtsoptimierung waere).

**Kein CV-OOF-Stacking**: eine naheliegende Verwechslung ist, dass die
Kandidaten per Cross-Validation trainiert werden und ihre Out-of-Fold-
Vorhersagen (die zusammen den GESAMTEN Trainingsdatensatz abdecken) fuer
die Selektion genutzt werden - das ist die klassische Stacking-Variante.
Diese Implementierung macht das NICHT: jeder Kandidat wird EINMAL auf
einem festen Trainings-Split trainiert und nur auf dem dazugehoerigen,
separaten Eval-/Holdout-Split bewertet (aus `147`/`120`/`140` je nach
Projekt) - einfacher und guenstiger als OOF, aber dateneffizienter waere
OOF gewesen (jede Zeile trueg zur Bewertung bei, nicht nur der
Eval-Anteil). Bewusste Vereinfachung, kein Versehen - konsistent mit dem
Rest des Templates, das ebenfalls feste Holdout-Splits statt OOF nutzt.

## 3. Warum ein separater Selektions-/Bestaetigungs-Split noetig ist

Die Selektion selbst ist ein Suchprozess mit vielen Freiheitsgraden (bei 24
Kandidaten und 50 Runden werden potenziell tausende Zwischenstaende
verglichen) - wird sie auf derselben Menge bewertet, auf der sie am Ende
berichtet wird, ueberpasst sich die Selektion an diese Menge, aehnlich wie
Hyperparameter-Tuning auf dem falschen Split optimistisch verzerrt waere
(siehe auch den mlr-org-Tutorial-Befund zu `instance$result_y` in
`project_mlr3_automl_template`-Memory). Deshalb: der bereits vom Training
getrennte Eval-/Holdout-Split (aus `147`/`120`) wird NOCHMAL geteilt -
Selektionsmenge (steuert die gierige Auswahl) und Bestaetigungsmenge
(bewertet ausschliesslich das fertige Ergebnis, sieht die Selektion nie).

## 4. Empirische Ergebnisse

**Ground-Truth-Verifikation** (2 unabhaengige OpenML-Datensaetze, Standalone-
Skripte in `ML_Learning/openml-bank-marketing-ensemble-test/`, binaere AUC,
Pool aus 45 Modellen/4 Familien):

| Datensatz | bestes Einzelmodell | Blend gleichgewichtet | Greedy-Ensemble |
|---|---:|---:|---:|
| bank-marketing (stark unbalanciert) | 0.9326 | 0.9307 | **0.9348** |
| electricity (balanciert) | 0.9740 | 0.9515 | **0.9743** |

**Template-Projekte und weitere Anwendungen** (24er-Grid-Pool aus 3 Familien,
ausser wo anders vermerkt):

| Projekt | Metrik | bestes Einzelmodell | Blend gleichgewichtet | Greedy-Ensemble |
|---|---|---:|---:|---:|
| health_condition (Klassifikation, **korrigiert**, siehe unten) | BAcc | 0.9484 | **0.9524** | 0.9484 |
| road-accident-risk (Regression) | RMSE | 0.0565 | 0.0572 | **0.0564** |
| s6e6 (Methodik-Test, geschlossene Episode, **korrigiert**, siehe unten) | BAcc | **0.9638** | 0.9580 | 0.9633 |
| s6e8 (24er-Grid-Pool, rohe Features, **korrigiert**, siehe unten) | AUC | 0.9556 | 0.9433 | **0.9560** |
| **s6e8 (3 bereits abgestimmte GBMs + TE)** | AUC | 0.9650 | **0.9654** | 0.9654 (=Blend) |

Nach Korrektur des Gewichtungsbugs (s.u.) in vier von sieben Faellen (inkl.
der 2 Ground-Truth-Datensaetze) Greedy-Ensemble klar vorn: bank-marketing,
electricity, road-accident-risk, s6e8-Grid-Pool. Bei electricity dominierte
ein einzelnes LightGBM-Modell (27 von 34 Wahlen). In zwei Faellen
(health_condition korrigiert, s6e8 mit abgestimmten GBMs) liegt der einfache
Blend gleichauf oder vorn - weil der Pool nach einer Korrektur/schon von
Haus aus aus wenigen, starken, AEHNLICHEN Kandidaten bestand statt aus einem
echt diversen Feld mit klaren Staerkeunterschieden. **Neu bei s6e6
(korrigiert)**: das beste Einzelmodell liegt hauchduenn vorn (0.9638 vs.
0.9633 Greedy, Differenz 0.0005 - bei ~11.5k Bestaetigungszeilen
(SE ~ 0.0018) statistisches Rauschen, praktisch ein Gleichstand). Kein
Widerspruch zur Kernthese, sondern eine dritte Variante desselben Musters:
je staerker/homogener der (korrekt gewichtete) Pool, desto naeher ruecken
Greedy und bestes Einzelmodell zusammen - der Blend faellt dabei am
deutlichsten zurueck (0.9580), weil er die schwachen Kandidaten nicht
herausfiltert.

**Gegenprobe s6e8 (24er-Grid-Pool, 2026-08-12)**: derselbe Weighted-Fix
(`149_ensemble_selection.R` im s6e8-Projekt hatte den Gewichtsschritt
urspruenglich komplett ausgelassen, nicht nur teilweise wie bei s6e6)
angewendet und explizit neu gelaufen statt nur die alte AUC-Unempfindlichkeits-
Annahme fortzuschreiben. Ergebnis bestaetigt die Annahme statt sie zu
widerlegen: greedy 0.9560 / single 0.9556 / blend 0.9433 - praktisch
identisch zu den ungewichteten Vorwerten (0.9559/0.9557/0.9430), Rangfolge
unveraendert. Guter Kontrast zu health_condition/s6e6 (BAcc, dort hat der
Fix die Rangfolge veraendert): bestaetigt nochmal empirisch statt nur
theoretisch, dass AUC als rangbasierte Metrik gegenueber Klassengewichtung
weitgehend unempfindlich ist - der Fix war hier trotzdem richtig (keine
schweigend fehlerhafte Grundlage mehr), hat aber wie erwartet kein
Ergebnis veraendert.

**Echter Bug + Korrektur: health_condition (2026-08-12)**, aufgedeckt durch
eine tatsaechliche Kaggle-Einreichung, nicht durch lokale Diagnostik: der
Nutzer submittete das Greedy-Ensemble (LB 0.87504) und verglich es mit einer
frueheren Einzelmodell-Submission (LB 0.94740) - eine Luecke von ~0.072,
weit ausserhalb jeder plausiblen Stichprobenvarianz. Ursache: der 24er-
Kandidaten-Pool (`148_ensemble_candidate_pool.R`) liess beim Bauen des
Trainings-Tasks die Gewichtsspalte aus dem `147`-Artefakt versehentlich weg
- der GESAMTE Pool trainierte dadurch ungewichtet, waehrend das etablierte
Einzelmodell-Deployment mit `class_weight_power=1.5` gewichtet (laut Memory
der groesste BAcc-Hebel dieses Projekts). Nach dem Fix (`148`/`156` nutzen
jetzt denselben `add_balanced_class_weights()`-Helfer wie `150`) sprangen
alle lokalen Zahlen von ~0.87-0.88 auf ~0.94-0.95 - nah am bekannten
LB-Referenzwert. **Und die Rangfolge kehrte sich um**: mit korrekter
Gewichtung gewinnt der Blend (0.9524) knapp vor Greedy (0.9484, gleichauf
mit dem besten Einzelmodell). Die urspruengliche Tabellenzeile ("Greedy
0.8822 > Einzel 0.8806 > Blend 0.8680") war korrekt GERECHNET, aber auf
einem fehlerhaft aufgebauten (ungewichteten) Pool - eine Lehre fuer sich:
eine Methode kann intern konsistent und korrekt implementiert sein UND
trotzdem auf einer schlechten Datengrundlage falsche Schlussfolgerungen
liefern. **Praktische Lehre**: wo verfuegbar, einen echten externen
Referenzwert (hier: eine tatsaechliche Leaderboard-Submission) nutzen, um
lokale Holdout-Zahlen zu pruefen - ein stillschweigend weggelassener,
etablierter Preprocessing-Schritt erzeugt keinen Fehler, nur eine leise,
systematisch falsche Zahl.

**LB-Bestaetigung nach dem Fix**: die korrigierte Greedy-Ensemble-Submission
erzielte **LB 0.94884** - schlaegt den bekannten Einzelmodell-Referenzwert
(0.94740) um +0.00144, und liegt nah an der lokalen Schaetzung (0.9484,
Abweichung nur +0.0004). Trotz des lokal knapp vorn liegenden Blends
(0.9524) hat sich der Nutzer bewusst fuer das guenstigere Greedy-Ensemble
entschieden (4 statt 24 Modelle neu zu trainieren) - und das zahlt sich auf
dem echten Leaderboard aus. Sauberer Doppelbeleg: (1) der Bug-Fix war
korrekt (Score-Sprung von 0.875 auf 0.949, wie erwartet), (2) Greedy-
Ensemble-Selection liefert hier einen echten, wenn auch kleinen,
LB-bestaetigten Gewinn ueber das beste Einzelmodell.

**Negativer/neutraler Fall: s6e8 mit den bereits abgestimmten Modellen**
(2026-08-11, `149b_ensemble_selection_tuned_gbms.R`, Standalone-Skript im
Projekt) - hier KEIN Gewinn ueber den bestehenden Equal-Weight-Blend
(Differenz 0.00001, reines Rauschen), obwohl Greedy weiterhin das beste
Einzelmodell schlaegt. Direkter Beleg fuer die Grenze in Abschnitt 5: nur 3
Kandidaten, alle bereits stark abgestimmt und hoch korreliert (~0.99, siehe
NEURAL_DEPLOY.md-Analog dieses Projekts) - die impliziten Greedy-Gewichte
(40% LightGBM/35% XGBoost/25% CatBoost) liegen nah genug an Gleichgewichtung
(33/33/33), dass kein messbarer Unterschied entsteht. Bestaetigt: Greedy
braucht einen GROSSEN, DIVERSEN Pool, um sein Potenzial zu zeigen - bei
wenigen, bereits optimierten, aehnlichen Modellen reduziert es sich auf
etwa das, was ein einfacher Blend ohnehin liefert.

**LB-Bestaetigung s6e8, 24er-Grid-Pool (2026-08-12)**: das Greedy-Ensemble
aus dem rohen 24er-Pool (Abschnitt 4, korrigierte Zeile, lokale
Bestaetigungs-AUC 0.9560) wurde tatsaechlich eingereicht - erster echter
End-to-End-Deploy fuer s6e8 (neue `149c_train_full_ensemble.R`/`149d_predict_
ensemble_submission.R`, analog zu `156`/`157`, **bewusst OHNE** das
exact-value Target-Encoding der bestehenden Submissions, weil die Selektion
selbst nie mit TE validiert wurde - dieselbe "kein stillschweigender
Pipeline-Unterschied zwischen Validierung und Deploy"-Lehre wie beim
health_condition-Bug). Ergebnis: **LB 0.96266**. Zwei Referenzpunkte zur
Einordnung:

1. **Lokal-zu-LB-Sprung erwartungsgemaess positiv** (0.9560 -> 0.96266,
   +0.0067) - passt zum bereits in `000_config.R` dokumentierten Muster
   dieses Projekts, dass ein Voll-Training auf 100% der Daten (statt der
   20%-`subset_fraction`, auf der `147`/`149` validieren) den Score deutlich
   ueber die kleine Holdout-Schaetzung hebt (dort: LB 0.9635 vs. 10%-CV
   0.952 fuers Einzelmodell, +0.0115 in dieselbe Richtung).
2. **Vergleich zum TE-Blend**: der Nutzer submittete zum Vergleich auch
   `157_blend_submission.R` (die 3 bereits abgestimmten, TE-erweiterten
   GBMs aus Abschnitt 4/`149b`) - **LB 0.96775**. Luecke zum rohen Ensemble:
   **+0.0051**, sehr nah am dokumentierten TE-Effekt (`exact_value_te.R`:
   +0.0044 AUC lokal). Sauber erklaerte, kleine Luecke - kein Bug-Signal wie
   beim health_condition-Fall (dort ~0.072, weit ausserhalb jeder
   plausiblen Erklaerung).

**7. Datenpunkt, andere Metrikklasse: `tweet` (Poisson-/Tweedie-Devianz +
Exposure-Offset, 2026-08-12)** - erste Anwendung ausserhalb von BAcc/AUC/
RMSE. Eigene Theoriedoku mit Literaturherleitung:
`ML_Learning/tweet/REFERENZ_ENSEMBLE_SELECTION_TWEEDIE.md` (kein Git-Repo,
daher hier nur die Kurzfassung). Kernfrage: traegt der Algorithmus mit
Devianz statt RMSE/BAcc? Ja, unveraendert - Devianz ist wie RMSE ein
zeilenweiser Mittelwert (additiv zerlegbar), im Gegensatz zu QWK
(`project_nondecomposable_metric`-Memory). Vollmodell-Deploy auf dem
externen, literaturvergleichbaren Holdout (135.603 Zeilen, French Motor
freMTPL2):

| Familie | GLM (voll) | Referenz-LightGBM | **Greedy-Ensemble** |
|---|---:|---:|---:|
| Poisson-Devianz | 0.3208 (D²=0.032) | 0.3045 (D²=0.081) | **0.2931 (D²=0.115)** |
| Tweedie-Devianz (p_eval=1.5) | 60.09 (D²=0.051) | 59.52 (D²=0.060) | **56.10 (D²=0.114)** |

Achtes/neuntes Datenpunkt-Paar, beide klar Greedy > bestes Einzelmodell >
Blend, auf vollen Daten (nicht nur Subset) verifiziert. Zusaetzlich eine
neue methodische Lehre, die in den bisherigen Anwendungen so nicht auftrat:
ein Kandidat mit schlechter EINZEL-Metrik (LightGBM bei extremem Tweedie-
Power p=1.9, Solo-Devianz 1148 - Rang 15 von 16) trug trotzdem 9/29 Gewicht
im besten Ensemble bei. Ursache (siehe Tweedie-Doku Abschnitt 5b): 97%
seiner Solo-Devianz kamen aus dem obersten 1% der Zeilen (grosse Schaeden,
wo er fast immer ~0 vorhersagt), waehrend er auf der dominanten 96%-
Nullmasse das BESTE Modell im Pool war - wirkt im Ensemble als impliziter
Shrinkage-Effekt. **Wichtiger Vorbehalt**: das Ensemble gewinnt aggregiert,
ist aber bei den seltenen, praktisch wichtigen Schadenhoehen selbst
konservativer (mean_mu=90) als GLM allein (mean_mu=165, wahr: 1826) - ein
echter Trade-off zwischen aggregierter Metrik und Tail-Genauigkeit, den
eine Metrik-Zerlegung (Nullmasse vs. positiv) aufdeckt, die die
Gesamtzahl allein verschleiert haette.

**Einordnung**: kein Widerspruch zur Methode, sondern eine Bestaetigung
ihrer eigenen Grenze (Abschnitt 5) auf echten LB-Daten statt nur lokal -
Feature-Engineering (TE) dominiert hier die Wahl der Aggregationsmethode
(Greedy vs. Blend). Die bestehende TE-Blend-Submission bleibt die bessere
Wahl fuer diesen Wettbewerb; `submission_ensemble.csv` ersetzt sie nicht.

## 5. Grenzen der Methode

- **Kein globales Optimum garantiert** (siehe Abschnitt 2) - ein anderer
  Startpunkt oder eine andere Rundenreihenfolge koennte zu einer anderen,
  moeglicherweise besseren Teilmenge fuehren. In der Praxis meist nah genug
  am Optimum, um den Aufwand nicht zu rechtfertigen.
- **Braucht eine ausreichend grosse Selektionsmenge** - bei einem kleinen
  Datensatz kann sich die Selektion an eine zu kleine Validierungsmenge
  ueberanpassen (deshalb der separate Bestaetigungs-Split, Abschnitt 3, statt
  nur der Selektionsmenge zu vertrauen).
- **Setzt einen diversen, bereits guten Pool voraus** - die Methode kann nur
  aus dem waehlen, was im Pool vorhanden ist. Ein Pool aus lauter aehnlichen/
  schwachen Modellen bringt keinen Ensemble-Gewinn (vgl. die generelle
  Lehre "generische Diversitaets-Hebel bringen bei niedrigem Shift/hoher
  Korrelation wenig", `project_covariate_shift_reweighting`-Memory). **Empirisch
  belegt** (s6e8, Abschnitt 4): bei nur 3 bereits stark abgestimmten, hoch
  korrelierten Kandidaten liefert Greedy praktisch dasselbe Ergebnis wie ein
  einfacher Equal-Weight-Blend (Differenz 0.00001) - der Nutzen kommt aus der
  Poolgroesse/-diversitaet, nicht aus dem Algorithmus selbst.
- **Rechenkosten skalieren mit Poolgroesse x Rundenzahl x Klassenzahl** - bei
  diesem Template noch handhabbar (18.7 Min. fuer 24 Kandidaten,
  Klassifikation), waechst aber mit groesseren Pools/mehr Runden linear.

## 6. Entscheidungsregel

- Lohnt sich, wenn bereits ein **diverser Pool** trainierter Modelle
  existiert (verschiedene Algorithmen und/oder Hyperparameter) und ein
  einfacher Gleichgewichts-Blend bisher schlechter war als das beste
  Einzelmodell (das Verwaesserungs-Symptom).
- Immer mit **getrenntem Selektions-/Bestaetigungs-Split** verifizieren, nie
  nur die Selektionsmenge berichten.
- Ergebnis (Verteilung der gewaehlten Modelle) selbst ist diagnostisch
  wertvoll: eine starke Konzentration auf 1-2 Modelle bestaetigt oft eine
  bereits bekannte "staerkste Familie"; eine breite Streuung deutet auf
  echte, komplementaere Diversitaet im Pool hin.
- **Datensatzgroesse als Faustregel (2026-09-05, 2 unabhaengige
  Bestaetigungen)**: bei kleinen/mittleren Datensaetzen (~500-1000
  Zeilen, `openml-cc18-ilpd`/`openml-cc18-blood-transfusion`) brachte
  das Ensemble konsistent einen echten Gewinn gegenueber dem besten
  Einzelmodell (+0.71/+1.76 BAcc-Prozentpunkte). Bei einem sehr grossen
  Datensatz (`PredictingElectricVehiclePurchases-s6e9`, 668.665 Zeilen)
  dagegen KEIN messbarer Gewinn (Greedy-Ensemble/Stacking blieben
  durchgehend unter dem besten Einzelmodell, auch mit LDA als
  zusaetzlichem diversem Kandidaten - siehe BACKLOG.md, 2026-09-02/03/04).
  Plausible Erklaerung: bei viel Trainingsdaten ist die Einzelmodell-
  Varianz gering, es gibt fuer Diversitaet wenig zu gewinnen. **Faustregel**:
  den Ensemble-Pool bei kleinen/mittleren Datensaetzen routinemaessig
  pruefen, bei sehr grossen (>~500k Zeilen) eher nicht - der Aufwand
  rechtfertigt dort selten den (wenn ueberhaupt vorhandenen) Gewinn.
