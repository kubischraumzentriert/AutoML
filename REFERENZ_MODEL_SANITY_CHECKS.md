# Referenz: Modell-Sanity-Checks (Perturbation/Invarianz/Directional Expectation)

Theoretischer Hintergrund zu den drei Behavioral-Testing-Checks aus Huyen
(2022) "Designing Machine Learning Systems", Kap. 6 "Model Evaluation
Methods". Implementiert in `sanity_checks.R` +
`147_error_analysis_ranger_sanity_checks.R` (siehe README.md,
WorkflowDescription.md Phase 11). Diese Referenz erklaert das WARUM; der
Code dokumentiert nur das WAS. Entstanden aus der Buch-Review-Session
2026-08-10 (siehe TARGETS.md fuer die vollstaendige Herleitung inkl.
Rohzahlen).

---

## 0. Welche Luecke fuellen diese Tests?

Eine einzelne Holdout-Metrik (BAcc/AUC/...) ist ein **Aggregat** ueber alle
Zeilen. Sie kann echte Verhaltensprobleme verstecken, die erst sichtbar
werden, wenn man das Modell gezielt unter leicht veraenderten Bedingungen
befragt statt nur den Gesamtwert abzulesen.

Huyen zieht die Analogie zu **Behavioral Testing** aus dem Software- bzw.
NLP-Testing (Ribeiro et al. 2020, "CheckList"): klassisches ML-Testing prueft
nur "stimmt die Zahl auf dem Holdout" - ein einziger Integrationstest.
Behavioral Testing prueft stattdessen gezielt EIGENSCHAFTEN des gelernten
Verhaltens (Robustheit, Invarianz, Richtung) - naeher an Unit-Tests fuer ein
Modell als an einer End-to-End-Metrik.

Das ergaenzt die bereits vorhandenen Trust-Bausteine im Template:

| Baustein | Prueft |
|---|---|
| `015_target_leak_audit.R` | Haengt das Modell an etwas, das es zur Vorhersagezeit gar nicht haben duerfte? |
| `115_adversarial_validation.R` | Unterscheiden sich Train und Test systematisch? |
| `147_error_analysis_ranger_segments.R` | Versteckt die Aggregatmetrik eine schwache Untergruppe (Simpson-Paradoxon)? |
| `147_error_analysis_ranger_sanity_checks.R` (neu) | Ist das Modell robust gegen kleines Rauschen, unabhaengig von irrelevanten Spalten, und plausibel in der gelernten RICHTUNG? |

**Wichtig, gemeinsam mit allen vier Bausteinen: das sind Trust-/Diagnose-
Werkzeuge, kein Metrik-Hebel.** BAcc/AUC aendern sich durch das Ausfuehren
dieser Tests nicht - anders als z.B. Target-Encoding oder Klassengewichtung.

---

## 1. Perturbation Test

**Frage**: Funktioniert das Modell nur auf exakt sauberen Trainingsdaten,
oder uebersteht es kleine, realistische Stoerungen mit aehnlicher Metrik?

**Mechanik** (`run_perturbation_test()`): Gaussian-Rauschen proportional zur
Spalten-SD (`perturbation_noise_sd_frac`, Default 5%) auf jede konfigurierte
numerische Spalte, mehrfach wiederholt (`n_reps`), Zielmetrik vorher/nachher
vergleichen.

**Praxisbezug**: Kaggle-Test-Daten koennen leicht andere Erhebungsartefakte
haben als Train (Rundung, Messfehler). Ein Modell, das nur bei exakten
Werten funktioniert, ist ein Overfitting-Signal - konkret die eigene
exact-value-Target-Encoding-Falle des Templates (siehe TARGETS.md/README):
ein TE-Lookup ohne Smoothing kollabiert auf perturbierte Werte fast auf den
globalen Fallback-Mittelwert.

**Nebenbedingung** (aus der PumpItUp-Verifikation gelernt): nur dbl-
typisierte Spalten verwenden. mlr3s `predict_newdata()`-Typcheck verweigert
`numeric -> integer` mit Nachkommastellen (z.B. `gps_height`, `population`),
also keine int-codierten Spalten (Codes/Zaehler) in
`perturbation_test_cols` aufnehmen.

**Entscheidungsregel**: `drop > perturbation_warn_drop` (Default 0.05) =>
Warnung. Erste Vermutung bei einer Warnung: ein Feature, das faktisch als
Lookup/Memorisierung statt als glatte Funktion wirkt.

---

## 2. Invarianz Test

**Frage**: Reagiert das Modell auf eine Spalte, die fachlich KEINE kausale
Bedeutung fuer die Zielgroesse haben sollte?

**Mechanik** (`run_invariance_test()`): die konfigurierte Spalte ueber alle
Zeilen mischen (Shuffle, erhaelt die Randverteilung), Vorhersage vorher/
nachher vergleichen, Flip-Rate = Anteil geaenderter Vorhersagen.

**Praxisbezug**: gezielter (pro Feature) als die vorhandene Adversarial
Validation, die nur Train/Test insgesamt trennt, nicht die Abhaengigkeit
von einer einzelnen Spalte misst.

**Wichtige Einschraenkung**: der Test prueft nur statistische ABHAENGIGKEIT
der Vorhersage von der Spalte, keine KAUSALITAET. "Diese Spalte sollte
irrelevant sein" ist eine fachliche Annahme, die das Modell/der Code nicht
verifizieren kann - der Test liefert nur ein Kandidaten-Signal (siehe
health_condition/`gender`, PumpItUp/`public_meeting`), keine endgueltige
Aussage.

**Entscheidungsregel**: `flip_rate > invariance_warn_flip_rate` (Default
0.05) => Warnung.

---

## 3. Directional Expectation Test

**Frage**: Bewegt sich die Vorhersage in die erwartete Richtung, wenn ein
Feature mit bekannter monotoner Domainbeziehung gezielt verschoben wird? Geht
ueber reine Feature-Importance hinaus (WAS wichtig ist) und prueft die
gelernte RICHTUNG.

**Mechanik** (`run_directional_test()` + `build_ordinal_shift_fn()`): das
Feature um `delta` (numerisch) oder eine Stufe (ordinal, ueber
`level_order`) in die als "positiv" deklarierte Richtung verschieben,
`P(favorable_class)` vorher/nachher vergleichen. `direction="increasing"`
heisst: P darf bei der Verschiebung nicht SINKEN; `"decreasing"`: P darf
nicht STEIGEN.

**Zentraler empirischer Befund (2 unabhaengige Projekte, siehe TARGETS.md)**:
Tree-Ensembles (hier: Ranger) erzwingen **keine globale Monotonie**. Ein
Modell kann im Aggregat die richtige Richtung lernen (`mean_diff` korrekt
vorzeichenbehaftet) und trotzdem bei einer nicht-trivialen Minderheit der
Zeilen (hier: 3-5% aller Zeilen mit einer Verletzung >0.05
Wahrscheinlichkeitspunkte) das Gegenteil vorhersagen - plausibel durch
Feature-Interaktionen, die ein Baum lokal anders gewichtet. **Das ist
normales Tree-Ensemble-Verhalten, kein Bug** - der Test macht es nur
sichtbar, wo eine Holdout-Metrik es verdeckt.

Falls echte Monotonie fachlich zwingend ist (z.B. eine regulatorische
Anforderung im Kredit-Scoring, "mehr Einkommen darf das Risiko nie
erhoehen"), ist das **kein** Skalierungsfall fuer diesen Sanity-Check,
sondern braucht ein Modell mit expliziten Monotonie-Constraints (z.B.
LightGBM/XGBoost `monotone_constraints`) - bislang nicht Teil des Templates,
moeglicher Kandidat fuer ein Projekt mit echtem Bedarf.

**Entscheidungsregel**: `violation_rate > directional_warn_violation_rate`
(Default 0.30) ODER Anteil substanzieller Verletzungen
(`|diff| > directional_effect_threshold`, Default 0.05) an ALLEN Zeilen
`> directional_warn_effect_share` (Default 0.05) => Warnung. Bewusst zwei
Schwellen: `violation_rate` allein waere irrefuehrend, weil viele
Verletzungen rauschartig-klein sein koennen (siehe `physical_activity_level`/
`smoking_alcohol`-Befund unten) - erst die Kombination mit der
Effektgroesse trennt "irrelevantes Rauschen" von "substanzieller Reversal".

---

## 4. Ground-Truth-Verifikationsmethodik

Wie beim Leak-Audit-Guard und den Segmentmetriken: jeder Test wurde erst an
einem SELBST KONSTRUIERTEN Paar aus bewusst kaputtem und sauberem Modell
verifiziert (Sensitivitaet + Spezifitaet), bevor er als vertrauenswuerdig
galt (`010_verify_ground_truth.R` in
`ML_Learning\health-condition-huyen-sanity-tests\`):

| Test | Kaputtes Modell | Sauberes Modell | Trennung |
|---|---|---|---|
| Perturbation | Exact-value-TE-Lookup (kein Smoothing) | glm auf glattem Feature | Drop 0.355 vs. 0.000 |
| Invarianz | Modell trainiert MIT injiziertem Leak-Proxy | identische Formel OHNE den Proxy | flip_rate 0.502 vs. 0.000 |
| Directional | Modell auf vorzeichen-invertiertem Feature trainiert | korrekt trainiertes Modell | violation_rate 1.000 vs. 0.000 |

Danach zweifach real angewendet (health_condition, drivendata-pump-it-up,
siehe TARGETS.md fuer die vollen Zahlen und die Konsistenzargumentation nach
ADR-003).

---

## 5. Wann nutzen, wann nicht?

- **Kein Metrik-Hebel.** BAcc/AUC/LB-Score aendern sich durch diese Tests
  nicht - anders einordnen als Feature-Engineering oder Tuning.
- **Sinnvoll als Trust-/Deploy-Gate** bei Projekten mit echten Konsequenzen
  (Kredit-Scoring, Wartungsentscheidungen wie PumpItUp, o.ae.), wo "das
  Modell widerspricht in x% der Faelle offensichtlichem Fachwissen" ein
  legitimer Befund vor dem produktiven Einsatz ist.
- **Weniger relevant bei reinen Kaggle-Leaderboard-Projekten** ohne echte
  Einsatzkonsequenz - dort primaer methodische Sorgfalt/Dokumentation statt
  Score-Wirkung.
- **Eine Warnung heisst nicht automatisch "Modell kaputt"** - erst pruefen,
  ob die betroffene Verletzung fachlich relevant ist (analog zur
  Segmentmetriken-Warnung: ein Hinweis zum Nachschauen, keine automatische
  Handlungsaufforderung).
- Config bleibt bewusst projektspezifisch (welche Spalten, welche Richtung/
  Stufenordnung) - Template-Default ist leer/inert (`000_config.R`).
