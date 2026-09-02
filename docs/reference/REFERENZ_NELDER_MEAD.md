# Referenz: Nelder-Mead in `class_multiplier_tuning.R`

Theoretischer Hintergrund zum kontinuierlichen Optimizer, der die
metrik-optimalen Klassen-Multiplikatoren fuer Balanced Accuracy (und
andere schwellenwert-abhaengige Multiklassen-Metriken) sucht - warum
Nelder-Mead, was die Optimierung eigentlich tut, und der dokumentierte
1D-Grenzfall bei binaeren Aufgaben.

---

## 1. Herkunft

`class_multiplier_tuning.R` entstand, weil die frueher in `130` fest
verdrahtete Grid-Suche (`seq(0.5, 6, by = 0.5)`) bei stark unbalancierten
Zielen regelmaessig an ihrer Obergrenze scheiterte (Minderheitsklassen
wollen Multiplikatoren weit jenseits von 6). Ein kontinuierlicher
Optimizer skaliert dagegen mit der Klassenzahl statt mit der Gitterfeinheit
und findet echte Optima statt Gitterpunkte. Bestaetigt an
`s6e7`/`health_condition` (3-Klassen/BAcc, OOF): raw argmax 0.872 -> Grid
0.936 -> Prior-Korrektur `1/prior` 0.943 -> kontinuierlich 0.945 - der
grosse Sprung kommt vom Metrik-aligned Entscheidungsschritt an sich, der
Optimizer holt nur noch die letzten +0.002 heraus (siehe Kopfkommentar der
Datei fuer den vollen Vergleich mit dem 2nd-/4th-Place-Ansatz von `s6e7`).

## 2. Das Problem: Klassen-Multiplikatoren fuer eine nicht-differenzierbare Metrik

Ein Klassifikator liefert Wahrscheinlichkeiten `P(Klasse | x)` je Zeile.
Die Standard-Entscheidungsregel ist `argmax` ueber diese Wahrscheinlich-
keiten. Bei unbalancierten Klassen und einer Metrik wie Balanced Accuracy
(Makro-Mittel der Recall-Werte je Klasse) ist das oft suboptimal: die
Mehrheitsklasse dominiert den rohen `argmax`, Minderheitsklassen werden
systematisch unterrepraesentiert vorhergesagt.

`tune_class_multipliers()` skaliert die Wahrscheinlichkeiten mit
klassenweisen Faktoren, BEVOR argmax entscheidet:
`argmax_k(P(k | x) * multiplier_k)`. Die Referenzklasse (die haeufigste)
bleibt bei Faktor 1 fixiert - nur die VERHAELTNISSE der Multiplikatoren
zaehlen fuer `argmax`, ein globaler Skalierungsfaktor auf allen Klassen
wuerde nichts aendern. Gesucht wird der Multiplikator-Vektor, der Balanced
Accuracy auf einem separaten Tune-Split maximiert.

**Warum kein Gradientenverfahren**: Balanced Accuracy ist stueckweise
konstant in den Multiplikatoren (jede kleine Aenderung, die keine
einzige `argmax`-Entscheidung kippt, aendert die Metrik nicht) - die
Zielfunktion ist nicht differenzierbar. Gradientenbasierte Optimierer
(Newton, Gradient Descent) brauchen aber eine wohldefinierte Ableitung.

## 3. Mechanismus: Nelder-Mead-Simplex

Nelder-Mead (Nelder & Mead 1965) ist ein **ableitungsfreier** Optimierer
fuer genau diesen Fall. Kernidee:

1. Halte einen "Simplex" aus `n + 1` Testpunkten im `n`-dimensionalen
   Parameterraum (bei `n` freien Multiplikatoren also `n + 1` Vektoren).
2. Bewerte die Zielfunktion an jedem Eckpunkt.
3. Ersetze iterativ den SCHLECHTESTEN Punkt durch eine Transformation in
   Richtung der besseren Punkte - typischerweise eine Spiegelung durch
   den Schwerpunkt der uebrigen Punkte, ggf. gefolgt von einer Streckung
   (wenn die Spiegelung sehr gut war) oder einer Stauchung (wenn sie
   schlechter war als erwartet).
4. Wiederholen, bis der Simplex auf ein Optimum konvergiert (oder das
   Iterationslimit erreicht ist).

Kein Gradient noetig - nur Funktionsauswertungen. Das macht Nelder-Mead
robust gegenueber nicht-differenzierbaren oder verrauschten Zielfunktionen,
aber ohne Konvergenzgarantie (kann in einem lokalen Optimum haengen
bleiben) - deshalb startet `tune_class_multipliers()` von MEHREREN
Startpunkten (Grid-Optimum, Prior-Korrektur, optionale `extra_starts`) und
behaelt das beste gefundene Ergebnis.

**Parametrisierung**: optimiert wird nicht direkt auf den Multiplikatoren
`mult`, sondern auf `theta = log(mult)` (`obj <- function(theta) { m[others]
<- exp(theta); -score(m) }`) - das erzwingt `mult > 0` ohne Box-Constraints
im Optimierer selbst angeben zu muessen (Nelder-Mead in R ist unbeschraenkt).

## 4. Der dokumentierte 1D-Grenzfall

Bei binaeren Aufgaben (2 Klassen) gibt es nur EINEN freien Multiplikator
(die zweite Klasse bleibt bei Faktor 1 fixiert) - `length(others) == 1`.
Nelder-Mead ist fuer MEHRDIMENSIONALE Probleme konzipiert; auf einer
einzigen Dimension warnt `optim(method = "Nelder-Mead")` in R selbst:
"eindimensionale Optimierung mit Nelder-Mead ist unzuverlaessig - nutze
direkt Brent oder optimize()".

Aufgefallen 2026-08-14 an `openml-credit-g` (erstes binaeres Projekt nach
dem Threshold-Tuning-Backport - alle bisherigen Bestaetigungen waren
>=3-Klassen-Aufgaben). Kein Absturz, plausible Ergebnisse, aber eine echte,
bisher unbeobachtete Warnung. **Behoben**: Fallunterscheidung in
`tune_class_multipliers()` - `length(others) == 1` nutzt `optimize()`
(Brent-Verfahren, fuer 1D-Optimierung auf einem Intervall gebaut, siehe
`class_multiplier_tuning.R` Zeile 108-122) statt Nelder-Mead, `length(others)
>= 2` bleibt bei Nelder-Mead mit mehreren Startpunkten. `optimize()` braucht
keinen Start-Loop - es durchsucht das gesamte Intervall (`c(log(1e-4),
log(1e4))`) direkt, unabhaengig vom Startwert. Regressionsgetestet gegen
`openml-credit-g`: keine Warnung mehr, UND ein besseres Optimum gefunden
(LightGBM ungewichtet: BAcc 0.730 statt vorher 0.713 mit Nelder-Mead) -
`optimize()` ist fuer den 1D-Fall nicht nur sauberer, sondern findet hier
auch das tatsaechliche Optimum zuverlaessiger.

## 5. Einsatz im Template

`tune_class_multipliers()` wird von `130_threshold_tuning.R` fuer >=3-
Klassen-Multiklassen-Projekte aufgerufen (binaere Projekte nutzen den
gewoehnlichen einzelnen Schwellenwert-Mechanismus aus `130` selbst, nicht
diese Datei - siehe Uebertragungs-Checkliste Punkt 2 in `TARGETS.md`).
Bisher an `health_condition` (3 Klassen), `openml-steel-plates-fault`
(7 Klassen), `openml-credit-g` (binaer, 1D-Pfad) und
`openml-eeg-eye-state-timeseries` (binaer, 1D-Pfad, regressionsgetestet
ohne Warnung) angewendet.
