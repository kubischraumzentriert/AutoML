# Referenz: Tuning-Ziel-Mismatch — warum "die Metrik verbessern" die falsche Metrik meinen kann

Generalisierte, jetzt 3-fach bestätigte Lehre: ein Tuning-Schritt (Klassen-
gewichtung, Schwellenwert-Suche, Modellauswahl) optimiert immer EINE
konkrete Zielgröße. Wird diese Zielgröße nicht bewusst gewählt — sondern
stillschweigend eine "verwandte", bequeme Ersatzmetrik verwendet — kann der
Tuning-Schritt die tatsächliche Bewertungsmetrik VERSCHLECHTERN, obwohl die
Ersatzmetrik klar besser wird. Kein Bug, keine Fehlkonfiguration im
üblichen Sinn — ein struktureller Mismatch zwischen zwei unterschiedlichen
Gütekriterien.

---

## 1. Das Muster, dreifach bestätigt in völlig verschiedenen Domänen

| Projekt | Aufgabentyp | Tuning-Ziel (Proxy) | Tatsächliche Metrik | Befund |
|---|---|---|---|---|
| `health_condition` | 3-Klassen/BAcc | Klassengewichtung/Multiplikator auf BAcc | MCC | BAcc↔MCC-Trade-off: BAcc-Optimum ist NICHT das MCC-Optimum, Klassengewichtung + Prior-Korrektur NICHT stapeln |
| `tweet` (Poisson/Tweedie) | Regression, Nullmasse | RMSE als Bewertungsgröße angenommen | Poisson-/Tweedie-Devianz | RMSE-Spanne über Prädiktoren <1%, Devianz-Spanne >100% (Tweedie: +15497%) - RMSE trennt kaum, waere sogar das bessere Modell verworfen |
| `openml-yeast-multilabel` + `openml-scene-multilabel` + `openml-birds-multilabel` | Multi-Label | Schwellenwert je Label auf BAcc getunt | Hamming Loss / Subset Accuracy | 3/3 unabhängige Datensätze: Accuracy-getunte Schwelle gewinnt in allen vier Multi-Label-Metriken (Hamming Loss, Subset Accuracy, Makro-/Mikro-F1); BAcc-getunt verschlechtert Hamming Loss/Subset Accuracy trotz besserer BAcc, teils sogar trotz besserer Makro-/Mikro-F1 (birds) |

Alle drei Fälle sind strukturell derselbe Fehler: **eine Metrik A wird
verbessert, in der Annahme, das verbessere auch Metrik B — aber A und B
messen unterschiedliche Dinge.**

## 2. Warum das passiert: balancierte vs. rohe Gütemaße

Der Kern-Mechanismus, der in allen drei Fällen wiederkehrt:

- **Balancierte Metriken** (BAcc, Makro-F1, Makro-averaged-Devianz-Analoga)
  gewichten JEDE Klasse/JEDES Label GLEICH, unabhängig von ihrer Häufigkeit.
  Ein Tuning-Schritt, der eine balancierte Metrik optimiert, verschiebt
  Entscheidungsgrenzen zugunsten der SELTENEN Klasse/des seltenen Labels -
  das erhöht zwangsläufig die Zahl falsch-positiver Vorhersagen für die
  Mehrheitsklasse.
- **Rohe/unbalancierte Metriken** (Accuracy, Hamming Loss, RMSE bei
  Nullmasse) werden von der HÄUFIGEN Klasse/dem häufigen Fall dominiert -
  mehr falsch-positive Vorhersagen für die Mehrheitsklasse schlagen hier
  direkt negativ zu Buche, unabhängig davon, wie sehr sich die balancierte
  Sicht verbessert hat.

Bei Imbalance (Klassen ungleich häufig, Nullmasse, seltene Labels) laufen
diese beiden Zielrichtungen zwangsläufig auseinander. Ohne Imbalance
(annähernd gleich häufige Ausprägungen) fällt der Unterschied kaum auf -
das erklärt, warum das Problem in der Praxis oft unbemerkt bleibt, bis ein
Projekt mit deutlicher Schiefe es sichtbar macht.

## 3. Konkretes Beispiel (Multi-Label, am ausführlichsten dokumentiert)

`openml-yeast-multilabel`/`openml-scene-multilabel`: 14 bzw. 6 unabhängige
Binärklassifikatoren (Binary Relevance), Schwellenwert je Label gesucht.

- **BAcc-optimale Schwelle** fuer ein Label mit 6% Basisrate lag bei 0.06
  (statt 0.5) - das balanciert Sensitivität/Spezifität, produziert aber
  massiv mehr falsch-positive Vorhersagen fuer die haeufige Negativklasse.
- **Accuracy-optimale Schwelle** blieb naeher an konservativeren Werten,
  die die ROHE Fehlerrate minimieren - und verbesserte Hamming Loss UND
  Subset Accuracy UND beide F1-Werte gegenueber der ungetunten 0.5-
  Schwelle, in BEIDEN unabhaengigen Projekten.

Volle Zahlen: `ML_Learning/openml-yeast-multilabel/README.md`,
`ML_Learning/openml-scene-multilabel/README.md` und
`ML_Learning/openml-birds-multilabel/README.md` (alle drei Standalone,
kein Git). Drittes Projekt (`birds`, 19 Labels, Bioakustik) lieferte den
sauberten Beleg: Accuracy-getunte Schwelle gewann dort in ALLEN VIER
Multi-Label-Metriken gleichzeitig gegenueber Default UND BAcc-Tuning.

**Zusatz-Randbedingung aus `birds`**: bei extrem seltenen Labels (dort:
6-9 positive Zeilen im GESAMTEN Datensatz von 645) brachte JEDES
Threshold-Tuning nichts oder war sogar leicht negativ - zu wenige
Beispiele im Tune-Split fuer eine verlaessliche Schwellensuche. Kein
Widerspruch zur Regel, aber eine praktische Grenze: Per-Label-Threshold-
Tuning braucht eine Mindestanzahl positiver Beispiele im Tune-Split
(Faustregel aus diesem Fall: einstellige Anzahl ist zu wenig), sonst
bleibt die Default-Schwelle die vernuenftigere Wahl fuer dieses konkrete
Label.

## 4. Praktische Regel

Vor jedem Tuning-Schritt (Threshold-Suche, Klassengewichtung,
Modellauswahl per CV-Metrik) explizit beantworten:

1. **Welche Metrik optimiert dieser Schritt konkret?** (nicht "verbessert
   die Ergebnisse", sondern die exakte Formel/Zielgröße.)
2. **Ist das dieselbe Metrik, an der das Projekt am Ende bewertet wird?**
   Falls nein: entweder den Tuning-Schritt auf die RICHTIGE Metrik
   umstellen, oder explizit begründen, warum die Ersatzmetrik als Proxy
   ausreicht (z.B. wenn beide Metriken auf diesem konkreten Datensatz
   empirisch stark korrelieren - selbst pruefen, nicht annehmen).
3. **Bei Imbalance/Nullmasse besonders wachsam sein** — genau dort laufen
   balancierte und rohe Metriken am staerksten auseinander (Abschnitt 2).

Diese Regel ist bewusst KEIN Code-Helfer (der richtige Fix ist immer
metrik-/projektspezifisch), sondern ein Denk-Schritt, der vor jedem neuen
Tuning-Baustein durchlaufen werden sollte - aehnlich wie die "trage die
Verfuegbarkeit zur Entscheidungszeit"-Frage beim Target-Leak-Audit.

## 5. Quellen der drei Bestätigungen

- `health_condition`: `TARGETS.md`, Abschnitt Multiklassen-BAcc-
  Multiplikator-Tuning.
- `tweet`: `MLR3_Regression/DEVIANCE_MEASURES.md` Abschnitt 1/7.
- `openml-yeast-multilabel` + `openml-scene-multilabel` +
  `openml-birds-multilabel`: siehe deren READMEs (`ML_Learning/`, alle
  drei Standalone-Projekte ohne Git).
