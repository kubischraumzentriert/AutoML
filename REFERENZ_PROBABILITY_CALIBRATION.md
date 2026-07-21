# Referenz: Probability Calibration fuer LogLoss-/AUC-Challenges

Playbook fuer Klassifikationswettbewerbe, bei denen die Submission
Wahrscheinlichkeiten erwartet und die Metrik LogLoss, Brier oder eine
Multi-Metric-Kombination mit LogLoss enthaelt.

Entstanden aus dem `FinancialStressPredictionChallenge`-Projekt (Zindi, 2026-07).
Dort war die Aufgabe binaere probabilistische Klassifikation:
`Target = P(liquidity_stress_next_30d = 1)`, Leaderboard-Metrik =
LogLoss (60%) + ROC-AUC (40%).

Dies ist eine **Referenz**, keine Template-Code-Aenderung.

---

## 1. Wann ist Kalibrierung sinnvoll?

Kalibrierung ist relevant, wenn die **Wahrscheinlichkeitsform** zaehlt, nicht nur
das Ranking:

- LogLoss ist Zielmetrik oder Teil der Zielmetrik.
- Brier Score ist Zielmetrik oder Diagnosemetrik.
- Die Submission erwartet Wahrscheinlichkeiten statt harter Klassenlabels.
- AUC ist gut, aber LogLoss/Brier bleiben hinter der Erwartung zurueck.
- Die mittlere vorhergesagte Wahrscheinlichkeit driftet deutlich von der
  Train-Basisrate weg, ohne dass Adversarial Validation einen harten Shift zeigt.

Kalibrierung ist weniger relevant, wenn nur Ranking zaehlt (reine ROC-AUC) oder
wenn harte Klassenlabels bewertet werden.

---

## 2. Platt-Kalibrierung

Platt-Kalibrierung ist nach **John Platt** benannt. Er machte diese
sigmoid/logistische Nachkalibrierung fuer SVM-Scores populaer.

Die Idee:

1. Ein Modell liefert rohe Scores oder Wahrscheinlichkeiten.
2. Diese werden auf eine lineare Score-Skala gebracht.
3. Darauf wird eine logistische Regression gefittet.
4. Die kalibrierten Werte werden wieder als Wahrscheinlichkeit ausgegeben.

Fuer rohe Wahrscheinlichkeiten `p_raw` kann man schreiben:

```text
logit(p) = log(p / (1 - p))
sigmoid(x) = 1 / (1 + exp(-x))

p_cal = sigmoid(a + b * logit(p_raw))
```

**Logit und Sigmoid sind nicht dasselbe.** Sie sind Umkehrfunktionen:

- `logit(p)` bringt eine Wahrscheinlichkeit `p in (0, 1)` auf die reelle Skala
  `(-Inf, +Inf)`.
- `sigmoid(x)` bringt einen reellen Score wieder auf die Wahrscheinlichkeitsskala
  `(0, 1)`.

Platt nutzt beide: erst `p_raw -> logit(p_raw)`, dann lineare Korrektur
`a + b * ...`, dann zurueck mit `sigmoid(...)`.

---

## 3. Warum bleibt AUC stabil?

Platt-Kalibrierung ist monoton, solange `b > 0`.

Das bedeutet: Die Reihenfolge der Vorhersagen bleibt gleich. Dadurch bleibt
ROC-AUC praktisch unveraendert, waehrend LogLoss/Brier besser werden koennen,
weil die Wahrscheinlichkeiten besser geformt sind.

Bei `b < 0` wuerde sich das Ranking umkehren; das ist normalerweise ein Warnsignal
fuer ein Problem in Daten, Zielklassenzuordnung oder Kalibrierungssplit.

---

## 4. Wichtig: Kalibrierung ehrlich evaluieren

Kalibrierung darf **nicht** auf denselben Zeilen bewertet werden, auf denen sie
gefittet wurde. Sonst sieht LogLoss fast immer zu gut aus.

Saubere Varianten:

1. **Holdout-Calib/Eval-Split**
   - Modell auf Train-Split trainieren.
   - Vorhersagen auf Holdout erzeugen.
   - Holdout in Calibration- und Eval-Haelfte teilen.
   - Kalibrierung auf Calibration fitten, auf Eval bewerten.

2. **Out-of-Fold-Kalibrierung (besser)**
   - OOF-Vorhersagen ueber K folds erzeugen.
   - Kalibrierung auf allen OOF-Vorhersagen fitten.
   - Koeffizienten danach auf die Test-Submission anwenden.

OOF ist stabiler, weil alle Trainingszeilen einmal ehrlich vorhergesagt wurden.

---

## 5. Was lokal tracken?

Immer getrennt berichten:

- LogLoss
- ROC-AUC
- Brier Score
- Mean predicted probability
- Positivrate bei `p >= 0.5` als Diagnose, nicht als Zielmetrik

Bei Zindi-Multi-Metric-Scores den Leaderboard-Wert nicht naiv rekonstruieren.
Zindi normalisiert Multi-Metric-Scores vor der Anzeige. Ein lokaler Proxy wie

```text
0.6 * (1 - logloss) + 0.4 * auc
```

kann zum Sortieren helfen, ist aber keine exakte Leaderboard-Rekonstruktion.

---

## 6. Financial-Stress-Befund

Im Financial-Stress-Projekt war der beste unkalibrierte Stand:

```text
LightGBM iter175 ens7: Public LB 0.694770588
```

Ein erster Holdout-Calib/Eval-Check fand:

| Kalibrierung | LogLoss | AUC | Mean Prob |
|---|---:|---:|---:|
| Platt GLM | 0.270064 | 0.887693 | 0.148863 |
| Logit Shift | 0.270412 | 0.887693 | 0.149125 |
| Raw | 0.270820 | 0.887693 | 0.141627 |

Die Platt-kalibrierte Submission verbesserte den Public LB:

```text
0.694770588 -> 0.696459341
```

Danach wurde die Kalibrierung stabiler ueber OOF-Vorhersagen geschaetzt:

| Kalibrierung | LogLoss | AUC | Mean Prob |
|---|---:|---:|---:|
| OOF Platt | 0.267171 | 0.890448 | 0.150000 |
| Raw OOF | 0.269464 | 0.890448 | 0.136605 |

OOF-Platt-Koeffizienten:

```text
intercept = 0.33452567
slope     = 1.12842835
```

Lehre: Bei Probability-Challenges mit LogLoss-Anteil kann monotone
Kalibrierung ein sauberer, leaderboard-bestaetigter Hebel sein.

Ein spaeter kleiner Regularisierungsschritt (`lambda_l2 = 5`) wurde zuerst lokal
gegen das bestehende Ensemble gescreent und danach mit eigener OOF-Platt-
Kalibrierung gerechnet:

| Kalibrierung | LogLoss | AUC | Mean Prob |
|---|---:|---:|---:|
| OOF Platt l2=5 | 0.266443 | 0.891031 | 0.150000 |
| Raw OOF l2=5 | 0.268277 | 0.891031 | 0.139626 |
| bisheriger OOF Platt | 0.267171 | 0.890448 | 0.150000 |

Leaderboard-Bestaetigung:

```text
OOF Platt ohne l2: 0.696598220
OOF Platt mit l2=5: 0.697156440
```

Wichtig ist die Reihenfolge: erst lokale/OOF-Evidenz, dann eine begruendete
Submission. Nach der Bestaetigung wurde bewusst gestoppt, statt weitere
Nachbarschaftswerte (`lambda_l2 = 3/8/10`) oder minimale Clipping-/Temperatur-
Varianten ans Leaderboard zu schicken.

---

## 7. Entscheidungsregel

Kalibrierung als Submission-Kandidat nur verwenden, wenn:

- LogLoss auf Eval/OOF sinkt.
- Brier Score sinkt oder zumindest nicht deutlich steigt.
- AUC stabil bleibt.
- Die Kalibrierung monotone Koeffizienten hat (`slope > 0`).
- Der Effekt groesser ist als reines Rundungsrauschen.

Nicht mehrere kleine Kalibrierungsvarianten ans Leaderboard schicken. Erst lokal
OOF entscheiden, dann eine begruendete Submission.

Wenn ein lokal validierter Kandidat auf dem Leaderboard bestaetigt wurde, ist
ein expliziter Stopp fairer als eine Serie sehr aehnlicher Nachtests. Weitere
Submissions brauchen eine neue methodische Idee, nicht nur einen Nachbarwert
eines bereits bestaetigten Reglers.
