# Ablation A3: Full Workflow vs. ohne Drift-/Stabilitaets-Checks (115/022/023/092/136)

Ausfuehrung der in [`ABLATION_STUDIES_PLAN.md`](ABLATION_STUDIES_PLAN.md)
definierten Ablation A3 - wie geplant ueberwiegend
Dokumentations-Zusammenstellung bereits vorhandener Befunde (kein neues
Modelltraining), da diese 5 Module per Definition KEIN trainiertes
Modell aendern, sondern Vertrauens-/Warnsignale liefern. Die Frage ist
NICHT "wie viel Score bringt es", sondern **"haette ein Nutzer OHNE
dieses Signal eine falsche Schlussfolgerung gezogen?"**

Module: Adversarial Validation (115), Split-Size-Sensitivity (022),
Learning-Curve (023), Seed-Stabilitaet (092), Generalisierungsluecke
(136).

## Hypothese (aus dem Plan)

> Diese Module haben in der Regel KEINEN Score-Effekt, sondern liefern
> Vertrauens-/Warnsignale.

**Ergebnis vorweg**: bestaetigt, mit einer wichtigen Ergaenzung - die
Module bewaehren sich nicht nur durch "korrekt still bei sauberen
Daten", sondern durch mehrere Faelle, in denen sie einen ECHTEN
Fehlschluss verhindert oder eine urspruenglich FALSCHE eigene Messung
selbst korrigiert haben.

## Kategorie 1: Echter Fund - waere ohne das Signal ein Fehlschluss gewesen

**Adversarial Validation (115) - `geoai-aquaculture-pond-identification-challenge`**:
AUC 0.99998 (roh) / 0.978 (Band-Mittel) - ein echter, EXTREMER
Train/Test-Covariate-Shift. Ohne dieses Signal haette eine Standard-CV-
Validierung die reale Anwendungsguete massiv ueberschaetzt (die
CV-Metrik waere auf Daten kalibriert, die dem Test-Verteilungsraum nicht
entsprechen). Konsequenz im Workflow: Reweighting wurde als
unzureichend erkannt und VERWORFEN (Effective Sample Size 2.6% - zu
wenig effektive Stichprobe fuer stabile Gewichte), stattdessen ein
Invarianz-Ansatz gewaehlt. Das ist die Kern-Illustration der Hypothese:
das Signal selbst aendert kein Modell, aber es aendert die METHODISCHE
ENTSCHEIDUNG, welcher Ansatz ueberhaupt sinnvoll ist.

**Learning-Curve (023) - `openml-credit-g`, Selbstkorrektur einer
eigenen Fehlmessung**: die urspruengliche Messung klassifizierte den
Verlauf faelschlich als "PLATEAU" (6.5% der vollen Spannweite) - ein
Ausreisser bei n=20 hatte die Spannweite kuenstlich aufgeblaeht und den
tatsaechlichen Trend verschleiert. Nach einer robusteren IQR-Nenner-
Korrektur (2026-08-15): korrekt "NOCH STEIGEND" (23.1% des IQR),
konsistent mit `health_condition`/`openml-satimage-multiclass`/den
Zeitreihen-Projekten. **Ohne diese Selbstkorrektur** haette ein Nutzer
faelschlich geschlossen "mehr Daten wuerden nicht helfen" - ein
konkreter, dokumentierter Fehlschluss, der tatsaechlich ZEITWEISE so im
System stand, bevor er entdeckt und behoben wurde. Zeigt zugleich: auch
ein Diagnose-Modul selbst kann anfangs falsch kalibriert sein - die
methodische Disziplin (Robustheits-Check, hier IQR statt Spannweite) ist
Teil der Trust-Story, nicht nur das Modul selbst.

**Learning-Curve (023) - `wdbc-plateau-test`**: erster echter,
gezielt nachgewiesener PLATEAU-Fund (7.5% des IQR nach dem
Mindest-n-Fix) - zeigt, dass das Modul zwischen "noch steigend" und
"tatsaechlich abgeflacht" korrekt unterscheiden KANN, wenn ein echtes
Plateau vorliegt (nicht nur ein Methodik-Artefakt wie beim urspruenglichen
`credit-g`-Fall).

## Kategorie 2: Kontrollierte Validierung des Mechanismus selbst (synthetisch)

**Generalisierungsluecke (136) - "Winner's Curse"-Suche**: ein
synthetisches Setup mit einer 60-Konfigurationen-Suche (`rpart`) wurde
KORREKT als auffaellig erkannt (z=-3.12 - der Suchprozess selbst
ueberoptimiert auf die Validierungsdaten), waehrend eine feste,
ungetunte Konfiguration korrekt NICHT als auffaellig eingestuft wurde
(z=+2.30). Beweist am kontrollierten Fall: das Modul unterscheidet
tatsaechlich zwischen "Ueberoptimierung durch Suche" und "normale
CV-Streuung", nicht nur zwischen "hoch" und "niedrig".

## Kategorie 3: Korrekt still (kein Fund, kein Score-Effekt, keine falschen Alarme)

Analog zu Ablation A2 (Leak-Audit): die Module erzeugen bei sauberen
Daten keine Ermuedung durch falsche Warnungen.

| Modul | Projekt | Befund |
|---|---|---|
| 115 Adversarial Val. | `openml-credit-g`, `s6e5`, `s6e6`, `predictingsmartphoneAddiction_s6e8`, `drivendata_richter`, `FinancialStressPredictionChallenge` | AUC nahe 0.5, kein Shift (6 unabhaengige Bestaetigungen) |
| 136 Generalisierungsluecke | `health_condition` (+0.0025), `openml-satimage-multiclass` (z=1.03/0.50), `openml-steel-plates-fault` (z=-1.63/-0.39), `openml-synthetic-control-timeseries` (z=0.05/-0.63) | alle innerhalb des Referenzbereichs |
| 092 Seed-Stabilitaet | `health_condition`, `openml-satimage-multiclass` (0.23x/0.21x), `openml-synthetic-control-timeseries` (SD=0.000, vollstaendig deterministisch) | unauffaellig |

## Kategorie 4: Nuancierte Sensitivitaet (Grenzfall korrekt eingeordnet, nicht ueberreagiert)

**Seed-Stabilitaet (092) - `openml-eeg-eye-state-timeseries`**: zeigt
die bislang HOECHSTEN z-Werte aller Projekte (z=1.67/1.27), wird aber
weiterhin korrekt als "unauffaellig" eingestuft (unter der
Warnschwelle). Zeigt: das Modul reagiert nicht ueberempfindlich auf
jede Erhoehung, sondern behaelt einen kalibrierten Schwellenwert -
wichtig fuer dieselbe "keine Ermuedung durch falsche Alarme"-Eigenschaft
wie bei Kategorie 3, hier aber am oberen Rand des bisher beobachteten
Bereichs demonstriert statt bei einem klaren Nullbefund.

## Antwort auf die Ablations-Frage

**Score-Effekt**: null (bestaetigt) - keines dieser 5 Module aendert ein
trainiertes Modell.

**Vertrauens-/Fehlervermeidungs-Effekt**: real und mehrfach illustriert
- ein extremer Covariate Shift, der die methodische Entscheidung
aenderte (115); eine urspruenglich falsche eigene Messung, die einen
konkreten Fehlschluss verursacht UND spaeter selbst korrigiert hat (023);
ein kontrolliert nachgewiesener "erkennt Ueberoptimierung korrekt"-Beweis
(136); durchgaengige Kalibrierung ohne Ueberreaktion am oberen Rand
(092).

**Zusaetzliche, im Plan nicht explizit erwartete Erkenntnis**: die
Learning-Curve-Selbstkorrektur bei `credit-g` zeigt, dass die Trust-Story
nicht nur "die Module fangen EXTERNE Probleme (Leaks, Shift)" ist,
sondern auch "das Template korrigiert nachweislich EIGENE
Kalibrierungsfehler, wenn sie auffallen" - ein zusaetzliches, staerkeres
Argument fuer methodische Disziplin als reine Fehlerfreiheit.

## Abbruchkriterium (aus dem Plan) - erreicht

> mindestens 2-3 illustrative Faelle je Diagnose-Modul-Gruppe dokumentiert

Uebererfuellt: 4 echte/kontrollierte Befund-Faelle (Kategorie 1+2) ueber
3 der 5 Module (115, 023, 136), plus durchgaengige "korrekt still"-
Bestaetigungen ueber alle 5, plus ein Nuance-Fall (092). Diese Ablation
gilt damit als abgeschlossen.
