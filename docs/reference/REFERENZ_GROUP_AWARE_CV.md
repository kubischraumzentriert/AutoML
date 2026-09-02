# Referenz: Group-aware Resampling auf der Klassifikationsseite

Theoretischer Hintergrund zu `group_resampling.R`: warum Standard-k-fold-CV
bei geclusterten/hierarchischen Daten (mehrere Zeilen pro Entitaet - Patient,
Proband, Ort, Geraet, Zeitabschnitt ...) die Generalisierungsfaehigkeit
systematisch ueberschaetzt, wie mlr3 das strukturell loest, und was die
Klassifikationsseite dieses Templates dazu konkret beitraegt.

**Fuer die vollstaendige Theorie (i.i.d.-Verletzung, mlr3-Gruppenrolle,
Permutationstest-Herleitung, Quellen) siehe das Regressions-Pendant**
[`REFERENZ_GROUP_AWARE_CV.md`](../MLR3_Regression/REFERENZ_GROUP_AWARE_CV.md)
im `MLR3_Regression`-Template - `set_group_role()`/`diagnose_group_cv()`
sind identischer, generischer Code (urspruenglich byte-identisch
uebernommen), keine Duplikation der Herleitung hier.
`test_group_significance()`/`scan_group_candidates()` weichen seit
2026-08-17 leicht ab (Klassifikationsseite erkennt kategoriale Zielwerte
automatisch und nutzt Cramer's V statt eta^2, siehe Abschnitt 4) - der
Regressions-Code bleibt unveraendert, da dort der Zielwert immer
numerisch ist. Dieses Dokument ergaenzt, was auf der Klassifikationsseite
EIGENSTAENDIG bestaetigt werden musste (ADR-003: eine Bestaetigung in
einem Template zaehlt nicht automatisch fuers andere).

---

## 1. Warum eine eigene Bestaetigung noetig war

`group_resampling.R`s `set_group_role()`/`diagnose_group_cv()` sind
Measure-basiert und damit auf dem Papier bereits generisch (funktionieren
technisch unveraendert fuer `TaskClassif`). Trotzdem: ob der MECHANISMUS
(random-CV ueberschaetzt bei Gruppenstruktur) tatsaechlich in echten
Klassifikations-Projekten eine relevante Groessenordnung erreicht - statt
nur theoretisch moeglich zu sein - war vor 2026-08-15 eigenstaendig
unbestaetigt. Erst reale Anwendung an zwei unabhaengigen Projekten mit
STRUKTURELL VERSCHIEDENEN Leck-Mechanismen zeigt, dass der Befund kein
Artefakt eines einzelnen Datensatz-Typs ist.

## 2. Reale Anwendung (2 Projekte, ADR-003 erfuellt)

| Projekt | Domaene | Zeilen | Gruppenspalte | Leck-Mechanismus | Random-CV | Group-CV | Luecke |
|---|---|---:|---|---|---:|---:|---:|
| `openml-eeg-eye-state-timeseries` | EEG/Neuro | 14980 | `time_block` (150-Zeilen-Zeitbloecke) | Zeitliche Naehe (benachbarte Millisekunden fast identischer Augenzustand) | BAcc 0.930 | BAcc 0.717 | **-0.213** |
| `uci-parkinsons-voice-groupcv` | Medizin/Sprache | 195 | `subject` (32 Probanden, ~6-7 Aufnahmen je Proband) | Echte Entitaets-Wiederholung (individuelle Stimm-Signatur wiedererkannt statt Diagnose gelernt) | BAcc 0.804 | BAcc 0.568 | **-0.236** |

Beide Luecken in derselben Groessenordnung (-21 bis -24 BAcc-Punkte), aber
aus zwei STRUKTURELL VERSCHIEDENEN Ursachen (zeitliche Naehe vs. Entitaets-
Wiederholung) - staerkere Evidenz als eine blosse Wiederholung desselben
Mechanismus. Beide Projekte sind binaere Klassifikationsaufgaben mit
`classif.ranger` (Default-Hyperparameter, 200 Baeume, identische Folds
zwischen Random- und Group-Variante).

**No-Signal-Check** (Lehre aus der Regressionsseite: eine grosse Random-vs-
Group-Luecke allein beweist nicht, dass unter Group-CV noch echtes Signal
uebrig bleibt - bei sehr wenigen Gruppen in der Minderheitsklasse koennte
das Group-CV-Ergebnis auch reines Rauschen sein): `uci-parkinsons-voice-
groupcv` hat nur 8 gesunde Probanden (von 32) - `classif.featureless`
(gewichtete Klassenvorhersage) liegt unter Group-CV bei BAcc 0.469
(Zufallsniveau), Rangers 0.568 liegt SPUERBAR darueber. Bestaetigt: echtes,
wenn auch deutlich schwaecheres Signal fuer neue Probanden, kein reines
Artefakt der wenigen Gruppen.

## 3. Deployment-Frage entscheidet, welche Zahl die richtige ist

Bei beiden Projekten identisch (siehe Regressions-REFERENZ Abschnitt 6 fuer
die allgemeine Formulierung): soll das Modell auf eine NEUE, bisher nicht
gesehene Entitaet generalisieren (neue EEG-Sitzung, neuer Patient) -> die
Group-CV-Zahl ist die ehrliche Schaetzung. Soll es stattdessen innerhalb
DERSELBEN, bereits gesehenen Entitaet arbeiten (an derselben laufenden
EEG-Aufzeichnung interpolieren, einen bereits diagnostizierten Patienten
verlaufskontrollieren) -> Random-CV waere fuer DIESE andere Frage
tatsaechlich die richtige Schaetzung. Fuer den jeweils realistischeren
Einsatzfall (neue Sitzung/neuer Patient) ist Group-CV bei beiden Projekten
die relevante Zahl.

## 4. Permutationstest fuer kategoriale Zielwerte (Cramer's V)

`test_group_significance()`/`scan_group_candidates()` rechneten urspruenglich
nur mit eta^2 (Varianzzerlegung, setzt NUMERISCHEN Zielwert voraus) - fuer
einen kategorialen Klassifikations-Zielwert nicht direkt nutzbar. **Ergaenzt
(2026-08-17)**: `test_group_significance()` erkennt jetzt automatisch, ob
`target` numerisch (eta^2, Regressionsseite unveraendert) oder kategorial
(Cramer's V - normierte Effektgroesse aus dem Chi-Quadrat-Unabhaengigkeitstest
zwischen `target` und `group`, `V = sqrt(chi2 / (n * min(r-1,c-1)))`, dieselbe
`[0,1]`-Skala wie eta^2) ist - dieselbe Permutationslogik (Nullverteilung
durch tatsaechliches Mischen der Gruppenzuordnung, +1/+1-korrigierter
p-Wert), nur andere Teststatistik.

**An 2 unabhaengigen Klassifikationsprojekten bestaetigt** (deren
Group-CV-Luecken oben bereits unabhaengig ueber `diagnose_group_cv()`
bestaetigt waren - der Permutationstest bestaetigt hier zusaetzlich, dass
die jeweilige Gruppenspalte auch statistisch von einer Zufallsaufteilung
unterscheidbar ist):

| Projekt | Gruppenspalte | Cramer's V | p-Wert |
|---|---|---:|---:|
| `openml-eeg-eye-state-timeseries` | `time_block` vs. `class` | 0.9298 | 0.002 |
| `uci-parkinsons-voice-groupcv` | `subject` vs. `status` | **1.0000** | 0.002 |
| Negativkontrolle (kuenstliche Zufallsgruppe, eeg-eye-state) | - | 0.0905 | 0.942 |

`uci-parkinsons`s Cramer's V von exakt 1.0 ist kein Fehler, sondern
mathematisch korrekt: `status` ist eine PER-PROBAND-DIAGNOSE, also
innerhalb jedes Probanden ueber alle Aufnahmen hinweg konstant (0
Probanden mit gemischtem Status, siehe Projekt-README) - `subject`
determiniert `status` deterministisch, die perfekte Assoziation spiegelt
das exakt wider. Die Zufallskontrolle (kuenstliche 100er-Bloecke auf
`eeg-eye-state`) zeigt trotz kleiner Stichprobenverzerrung (V=0.09, nicht
exakt 0) korrekt `p=0.942` - der Permutationstest unterscheidet auch bei
verrauschtem Rohwert zuverlaessig "keine echte Struktur" von "echte
Struktur".

Beide Test-Skripte (`verify_group_significance_classif.R`-Stil, direkt
gegen `train.csv` der jeweiligen Projekte) sind nicht als eigene
nummerierte Projektskripte angelegt (reine Ad-hoc-Verifikation fuer diesen
Backport) - die Zahlen oben sind die vollstaendige Dokumentation.

## 5. Status

**Backportiert (2026-08-17)** als `group_resampling.R` (`set_group_role()`/
`diagnose_group_cv()` weiterhin identischer Code zur Regressionsseite).
Kein numeriertes Treiber-Skript im Template selbst (wie auf der
Regressionsseite auch) - die Gruppenspalte ist immer projektspezifisch,
`set_group_role()`/`diagnose_group_cv()` werden direkt aus einem
projekteigenen Skript aufgerufen (siehe `openml-eeg-eye-state-timeseries/
021_block_cv_comparison.R` bzw. `uci-parkinsons-voice-groupcv/
021_group_cv_comparison.R` als Vorlagen). Keine `000_config.R`-Aenderung
noetig (kein Default-Config-Wert, opt-in).

**Cramer's-V-Erweiterung (2026-08-17)**: `test_group_significance()`
erkennt jetzt automatisch numerische vs. kategoriale Zielwerte (siehe
Abschnitt 4) - an 2 unabhaengigen Klassifikationsprojekten bestaetigt
(`eeg-eye-state`/`uci-parkinsons-voice-groupcv`), ADR-003-Kriterium
erfuellt. Rueckgabefeldnamen von `test_group_significance()` dabei
generalisiert (`eta2_observed`->`statistic_observed`,
`eta2_null`->`statistic_null`, neu `statistic_name`) - betrifft nur die
Klassifikationsseite, kein bisheriger Aufrufer (weder Template noch
`ML_Learning`-Projekt) hatte diese Funktion bereits genutzt, daher keine
Rueckwirkungs-Pruefung noetig. `scan_group_candidates()`s Ausgabespalte
`eta2` entsprechend zu `statistic`/`statistic_name` umbenannt.

## 6. Quellen

- Roberts, D.R., Bahn, V., Ciuti, S. et al. (2017). "Cross-validation
  strategies for data with temporal, spatial, hierarchical, or
  phylogenetic structure." *Ecography*, 40(8), 913-929.
- `MLR3_Regression/REFERENZ_GROUP_AWARE_CV.md` - vollstaendige Theorie,
  Regressionsseite-Bestaetigung (`SubjektDatensatz`/`AStepAheadOfdrought`),
  Permutationstest-Herleitung.
- `ML_Learning/openml-eeg-eye-state-timeseries/README.md`,
  `021_block_cv_comparison.R` - erste Classif-Bestaetigung.
- `ML_Learning/uci-parkinsons-voice-groupcv/README.md`,
  `021_group_cv_comparison.R` - zweite, unabhaengige Classif-Bestaetigung.
