# Ablation A2: Full Workflow vs. ohne Leak-Audit (015)

Ausfuehrung der in [`ABLATION_STUDIES_PLAN.md`](ABLATION_STUDIES_PLAN.md)
definierten Ablation A2 - wie dort geplant, ueberwiegend
Dokumentations-Zusammenstellung bereits vorhandener Befunde (keine neuen
Modell-Laeufe), da der Leak-Audit per Definition KEIN Score-Hebel ist
(er aendert kein trainiertes Modell), sondern ein Trust-/Fehlervermeidungs-
Baustein. Die Frage ist deshalb nicht "wie viel Score bringt es", sondern
**"haette der Workflow ohne dieses Modul eine falsche Schlussfolgerung
gezogen - und wo hat es selbst versagt?"**

## Hypothese (aus dem Plan)

> Leak-Audit hat KEINEN Score-Effekt auf saubere Datensaetze, aber
> verhindert katastrophale Fehlentscheidungen auf geleakten Datensaetzen.

**Ergebnis vorweg**: die Hypothese ist im Kern bestaetigt, aber mit einer
wichtigen Einschraenkung - der Guard ist NICHT unfehlbar. Es gibt einen
dokumentierten, bewusst akzeptierten blinden Fleck (siehe Kategorie 4
unten). Eine ehrliche Ablation muss das mit zeigen, nicht nur die
Erfolgsfaelle.

## Kategorie 1: Echter Treffer (Leak gefunden, Score waere sonst falsch gewesen)

**`CreditScoringChallenge` (Zindi)** - der klarste Fall in der gesamten
Projekt-Historie. Ein erstes Modell erreichte **F1 0.88**, nutzte dabei
aber ein Feature, das zum Zeitpunkt der Kreditvergabe noch gar nicht
existierte (Strafgebuehren, die erst NACH einem Zahlungsausfall
entstehen - ein Ex-post-Leak). Das automatisierte Leak-Audit deckte das
auf. Nach Entfernen des Leak-Features: **F1 ≈ 0.41** - der ehrliche Wert.
**Extern bestaetigt**: das Zindi-Leaderboard zeigte fuer das bereinigte
Modell **0.4191**, fast exakt der intern berechnete Wert (siehe
`README.md`, "Ein paar bestaetigte Ergebnisse"). Ohne das Leak-Audit
waere die F1-0.88-Zahl unentdeckt geblieben - ein Score, der bei der
tatsaechlichen Anwendung (kein Zugriff auf zukuenftige Strafgebuehren)
NIE erreichbar gewesen waere.

**Konsequenz ohne Leak-Audit**: falsches Vertrauen in ein Modell, das in
der Praxis um ~47 F1-Punkte schlechter abgeschnitten haette - der genaue
Fehlentscheidungs-Fall, den die Hypothese vorhersagt.

## Kategorie 2: Korrekt still (sauberer Datensatz, Audit findet nichts)

Mehrere unabhaengige Bestaetigungen, dass der Guard bei sauberen Daten
NICHT faelschlich Alarm schlaegt (kein False-Positive-Problem):

| Projekt | Top-Feature-Gain | Determinismus-Funde | Befund |
|---|---|---|---|
| `health_condition` (Template-eigen) | `stress_level` 42.9% | 0 | unauffaellig |
| `openml-credit-g` | `credit_amount` 26.9% | 0/68 | unauffaellig |
| `predictingsmartphoneAddiction_s6e8` | `daily_screen_time_hours` 49.3% | 0 | unauffaellig, plausibles Ex-ante-Signal |
| `openml-synthetic-control-timeseries` | - | - | unauffaellig |
| `openml-eeg-eye-state-timeseries` | - | - | unauffaellig |
| `PumpItUp` | `ward` 28.5% | 0 | unauffaellig (2. Bestaetigung) |
| `geoai-aquaculture-pond-identification-challenge` | `re3_08` 27.5% | 0 | unauffaellig (3. Bestaetigung) |

7 unabhaengige "korrekt still"-Faelle - der Guard erzeugt keine
Ermuedung durch falsche Alarme, was seine tatsaechliche Nutzung in der
Praxis erst praktikabel macht (ein Guard, der staendig faelschlich warnt,
wird irgendwann ignoriert).

## Kategorie 3: Ambivalenter Fund, korrekt eingeordnet (kein blinder Automatismus)

**`openml-steel-plates-fault`**: 1 Determinismus-Fund wurde dokumentiert,
aber NICHT automatisch als Leak entfernt - der Fund wurde inhaltlich
geprueft und als unbedenklich eingestuft. Zeigt: der Guard trifft keine
automatischen Entscheidungen, er flaggt Verdachtsfaelle zur menschlichen
Pruefung. Das ist ein bewusstes Design (kein "Auto-Remove"), das
Kategorie-1-False-Positives (ein legitimes Feature faelschlich als Leak
entfernt) verhindert.

## Kategorie 4: Bekannter blinder Fleck (Leak vorhanden, Guard still) - EHRLICHE GRENZE

**`Lending Club`** (2026-08-21, `lending-club-leak-test`, 1.3 Mio.
Zeilen): 10 bekannte Post-Outcome-Felder (`total_pymnt`, `recoveries`,
`last_pymnt_amnt`, ...) fuehren zu einem ehrlichen BAcc-Einbruch von
**0.9983 auf 0.5317** (praktisch Zufallsniveau) - der GROESSTE je in
diesem Template gemessene Leak-Effekt. **Der Standard-Guard (Schritt 1,
Einzelfeature-Gain-Konzentration) haette ihn NICHT gefunden**: staerkstes
Einzelfeature nur 18.9% Gain, die 30/50%-Einzelschwelle bleibt still. Die
10 Leak-Features tragen zusammen nur ~31% Gain - ueber viele redundante
Felder verteilt, kein einzelner starker Verdaechtiger. Ursache:
LightGBM-Gain-Importance summiert ueber alle Splits - ein Feature, das
nur in wenigen, aber sehr entscheidenden fruehen Splits genutzt wird,
sammelt weniger kumulierten Gain an als legitime, oft wiederverwendete
Features (bekanntes Problem der Split-/Gain-basierten Importance in der
Literatur).

**Guard-Verbesserung (Schritt 1b, Korrelations-Cluster-Zerlegung)
implementiert, aber NUR Teilerfolg**: findet am Lending-Club-Fall selbst
immerhin ein informatives 7.9-Punkte-Signal (vorher: nichts sichtbar),
ueberschreitet die Warnschwelle bei diesem EXTREMEN Redundanzfall
(paarweise Korrelation nahe 1.0) aber nicht. **Funktioniert dagegen
nachweislich bei einem weniger extremen synthetischen Fall**
(`synth-redundant-leak-test`, kontrollierte Korrelation 0.55-0.56): dort
loest Schritt 1b korrekt aus (29.8-Punkte-Abfall, klar ueber der
15-Punkte-Schwelle), obwohl auch hier das staerkste Einzelfeature mit
30.7% unter der Warnschwelle liegt.

**Ehrliche Einordnung**: der Guard hat eine dokumentierte, akzeptierte
Grenze - er erkennt einen ueber viele Features verteilten Leak zuverlaessig,
wenn die Redundanz MODERAT ist (Korrelation ~0.5-0.6), aber NICHT
zuverlaessig bei FAST-PERFEKTER Redundanz (~1.0, wie bei Lending Club).
Diese Grenze ist bewusst als solche stehen gelassen (siehe
`README_DETAILS.md`, "Target-Leakage-Audit" Schritt 1b), nicht
verschwiegen.

## Antwort auf die Ablations-Frage

**Score-Effekt**: praktisch null bei sauberen Daten (Kategorie 2, 7
Bestaetigungen) - der Leak-Audit selbst aendert kein Modell.

**Fehlervermeidungs-Effekt**: gross und real bestaetigt (Kategorie 1,
extern via Zindi-Leaderboard validiert) - OHNE den Guard waere
`CreditScoringChallenge` mit einem um ~47 F1-Punkte zu optimistischen
Modell "erfolgreich" gewesen.

**Vertrauens-Effekt UND ehrliche Grenze zugleich**: Kategorie 3 zeigt,
dass der Guard Augenmass behaelt (keine Autopilot-Entfernung); Kategorie
4 zeigt, dass er nicht allmaechtig ist - ein extrem redundanter,
diffuser Leak kann ihn passieren. Fuer die Publikations-Story ist das
KEIN Makel, sondern ein Staerke-Argument: ein Trust-System, das seine
eigenen Grenzen kennt und dokumentiert, ist glaubwuerdiger als eines, das
Perfektion behauptet.

## Abbruchkriterium (aus dem Plan) - erreicht

> mindestens 1 "Leak gefunden und Score waere sonst falsch gewesen"-Fall
> UND mindestens 1 "kein Leak, Audit war zurecht still"-Fall dokumentiert

Beides mehrfach uebererfuellt (1 Volltreffer extern validiert, 7 korrekt
stille Faelle, 1 Graubereich-Fall, 1 dokumentierter blinder Fleck mit
Gegenbeispiel). Diese Ablation gilt damit als abgeschlossen.
