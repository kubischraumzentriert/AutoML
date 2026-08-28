# Kriterien fuer neue Modellfamilien: nur hypothesengetrieben

P3 aus ChatGPTs korrigiertem Plan (siehe `BACKLOG.md`): "keine neue
Modellfamilie nur mit 'koennte vielleicht besser sein'". Diese Datei
kodifiziert eine Regel, die dieses Projekt in der Praxis bereits befolgt
(siehe Beispiele unten) - neu ist nur, dass sie jetzt explizit
aufgeschrieben ist, statt implizit im Kopf der jeweiligen Session zu
leben.

## Die Regel

Bevor eine neue Modellfamilie/ein neuer Optimierer/eine neue
Stacking-Variante getestet wird, muessen die folgenden Punkte VOR dem
ersten Testlauf definiert sein - nicht nachtraeglich zur Rechtfertigung
eines bereits gelaufenen Experiments:

1. **Konkrete Hypothese** - WAS genau soll besser werden, und WARUM
   (Mechanismus, nicht nur "koennte helfen")? Beispiel: "TabM
   dekorreliert von GBM-Baselines, weil es eine andere Funktionsklasse
   approximiert" - nicht "TabM ist neu und wird oft empfohlen".
2. **Geeigneter Datensatztyp** - fuer welche Art von Daten/Aufgabe ist
   die Hypothese ueberhaupt plausibel (Datensatzgroesse, Rauschanteil,
   Feature-Typen)? Ein Kandidat, der auf kleinen, sauberen Datensaetzen
   glaenzt, muss nicht zwingend auf einem grossen, verrauschten Kaggle-
   Datensatz getestet werden.
3. **Vergleichsbaseline** - wogegen wird verglichen (bestehendes
   Ensemble, bestes Einzelmodell, Default-Hyperparameter)?
4. **Primaermetrik** - die tatsaechliche Zielmetrik des Projekts
   (`baseline_measure_ids[1]`), nicht eine bequemere Ersatzmetrik.
5. **Diversitaetsmetrik, falls relevant** - bei einem Ensemble-
   Kandidaten: WIE wird Dekorrelation gemessen (z.B.
   Wahrscheinlichkeits-Korrelation, Cohen's Kappa) und WELCHE Schwelle
   gilt als "ausreichend dekorreliert" (in diesem Projekt etabliert:
   Korrelation < 0.95, siehe `NEURAL_DEPLOY.md`)?
6. **Laufzeitbudget** - eine grobe Vorab-Schaetzung, ob Minuten oder
   Stunden zu erwarten sind (siehe Claude-Memory
   `feedback_runtime_cost_awareness.md`: SVM-Timing auf 1 Item lässt sich
   NICHT linear auf N extrapolieren) - bei einem selbstgebauten Kandidaten
   (z.B. ein eigenes `torch`-`nn_module`) zusaetzlich: ein winziger
   synthetischer Smoke-Test VOR dem vollen Lauf (Shapes/Forward/Backward),
   nicht erst beim echten, teuren Lauf entdecken, dass die Architektur
   einen trivialen Fehler hat.
7. **Abbruchkriterium** - ab wann gilt der Test als abgeschlossen
   (negativ oder positiv), ohne dass man ihn "noch ein bisschen"
   weiterverfolgt? Ein klar quantifiziertes negatives Ergebnis ist ein
   GUELTIGER, ENDGUELTIGER Befund, kein offener Punkt (siehe Claude-Memory
   `feedback_collaboration_style.md`: "negative Ergebnisse sind valide").
8. **Backport-Kriterium** - bei einem POSITIVEN Ergebnis: das bestehende
   `adr/003-backport-after-confirmation.md` gilt unveraendert (Backport
   erst nach Bestaetigung an >=2 unabhaengigen Projekten ODER
   nachgewiesenem No-op). Diese Datei ersetzt ADR-003 nicht, sondern geht
   ihr zeitlich voraus (ADR-003 entscheidet ueber das NACHHER, diese
   Checkliste ueber das VORHER).

Explizit **kein** Fokus vorerst auf weitere GBM-Varianten, Foundation
Models, Stacking-Varianten oder Optimierer OHNE eine der obigen acht
Antworten.

## Bereits gelebte Beispiele (retroactiv zugeordnet, nicht neu getestet)

Diese Regel wurde bereits mehrfach informell befolgt - zur Orientierung,
wie ausgefuellte Kriterien aussehen (siehe `TARGETS.md`/Claude-Memory
`project_mlr3_automl_template.md` fuer die vollen Befunde):

| Kandidat | Hypothese | Baseline | Diversitaetsmetrik/Schwelle | Ergebnis |
|---|---|---|---|---|
| TabPFN (selektiv, Greedy Selection) | Foundation-Model-Kontext dekorreliert von GBM-Baselines trotz schwaecherer Einzelleistung | 6 GBM-Varianten, Caruana Greedy Ensemble Selection | Selektions-Haeufigkeit ueber 7 Zuege | Negativ - 0/7 Zuege gewaehlt, vollstaendig ausgeschlossen |
| TabM (BatchEnsemble) | Effizientes MLP-Ensemble (geteiltes Backbone) dekorreliert guenstiger als FT-Transformer | GBM-Ensemble (CatBoost/XGBoost/LightGBM) | Wahrscheinlichkeits-Korrelation < 0.95 | Negativ - Korrelation 0.975, effizient aber nicht dekorreliert |
| Hyperband (mehrere Brackets) | Multi-Fidelity-Budgetallokation schlaegt Random Search bei gleichem Gesamtbudget | Matched-Budget Random Search, 2 Seeds | - (kein Diversitaets-, sondern ein Effizienzvergleich) | Negativ/uneindeutig - Differenz im Rauschband, gegensaetzliche Richtung je Seed |
| Multi-Layer Stacking | Ein zweites Meta-Learner-Layer nutzt Struktur, die ein einzelnes Layer nicht erfasst | Single-Layer-Stacking, gleiche Kandidatenpools | - | Positiv in 3/4 Projekt-Bestaetigungen (ADR-003-Schwelle erreicht) |

## Wo diese Checkliste ansetzt

Beim naechsten Mal, wenn ein neuer Modellkandidat vorgeschlagen wird (vom
Nutzer, aus der Literatur, oder als KI-Vorschlag) - VOR dem ersten
`library(...)`-Aufruf die 8 Punkte oben kurz durchgehen (muendlich/im
Chat reicht, keine eigene Datei pro Kandidat noetig) und bei fehlender
Antwort auf Punkt 1 (Hypothese) den Test gar nicht erst starten.
