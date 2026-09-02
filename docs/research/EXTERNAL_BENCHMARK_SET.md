# Externes Benchmark-Set (eingefroren, Stand 2026-08-29)

P1 aus der 2026-08-29-Bewertung: "Datensaetze vorab festlegen -&gt;
Auswahlregeln dokumentieren -&gt; Benchmark einfrieren -&gt; erst danach
Ergebnisse berechnen", explizit um **Benchmark Selection Bias**
auszuschliessen - die bisherigen 7 Phase-C-Datensaetze stammen aus
bereits erkundeten Projekten dieses Templates, bei denen Imbalance/
Leaks/Modellverhalten schon bekannt waren. Dieses Dokument fixiert ein
Set, das VOR jeder Ergebnisberechnung feststeht, ausschliesslich anhand
oeffentlicher Metadaten ausgewaehlt.

**Status (aktualisiert 2026-08-30): AUSGEFUEHRT.** Dieses Dokument
deckt urspruenglich nur die Auswahl ab (P1, Teil "externer Benchmark").
Die eigentlichen Laeufe sind laengst abgeschlossen: Level-1-Outer-
Evaluation (Protokoll v1) + faire getunte Baselines (Protokoll v2,
`BENCHMARK_PROTOCOL.md` Version 2) + Level-2-Prototyp auf allen 6
Datensaetzen (Protokoll v3, `EVALUATION_LEVELS.md`) + ein 3-schrittiger
Research-Aspect-Nachtrag (Signifikanztest, Tuning-Budget-Test,
Metafeature-Analyse). Volle Ergebnisse in `BACKLOG.md`/P1- und
P2-Status, `PAPER_DRAFT.md` Abschnitt 5-6.

## Quelle: OpenML-CC18

[OpenML-CC18](https://www.openml.org/search?type=study&study_type=task&id=99)
(Studien-ID 99) - eine von OpenML selbst kuratierte, oeffentlich
zitierfaehige Sammlung von 72 Klassifikations-Benchmark-Datensaetzen.
Bewusst eine EXTERNE, bereits vor dieser Session existierende Kuration
gewaehlt statt einer eigenen Auswahl - die Kuration selbst liegt
ausserhalb der Kontrolle dieses Projekts.

## Einschlusskriterien (VOR jeder Auswahl festgelegt)

- **500 <= Instanzen <= 20.000** - praktikable lokale Laufzeit fuer 3
  Outer Folds x mehrere Vergleichs-Arme (siehe `BENCHMARK_PROTOCOL.md`),
  schliesst u.a. `mnist_784`, `adult`, `bank-marketing`, `CIFAR_10`,
  `Fashion-MNIST`, `connect-4`, `numerai28.6`, `Devnagari-Script`,
  `jungle_chess...`, `electricity`, `nomao` aus.
- **Features <= 100** - haelt Ranger-/LightGBM-Trainingszeit moderat,
  schliesst u.a. `isolet` (618), `cnae-9` (857), `har` (562), `madelon`
  (501), `Bioresponse` (1777), `Internet-Advertisements` (1559),
  `semeion` (257), `mfeat-pixel` (241), `mfeat-factors` (217) aus.
- **2 <= Klassen <= 10** - deckt sich mit den bisherigen Kategorien
  A-C aus Phase C, schliesst `letter`/`isolet` (26), `vowel` (11),
  `Devnagari-Script` (46) aus.
- **NICHT bereits in diesem Template verwendet** - sonst waere die
  Auswahl nicht mehr "extern/unbekannt im Verhalten". Ausgeschlossen:
  `credit-g` (-&gt; `openml-credit-g`), `satimage` (-&gt;
  `openml-satimage-multiclass`), `steel-plates-fault` (-&gt;
  `openml-steel-plates-fault`), `bank-marketing` (-&gt;
  `openml-bank-marketing-ensemble-test`), `adult` (-&gt;
  `openml-adult-income`), `diabetes`/Pima (-&gt;
  `validate_portfolio_warmstart_pima.R`), `wdbc` (-&gt;
  `wdbc-plateau-test`).

Nach diesen Kriterien: **43 von 72** CC18-Datensaetzen bleiben zulaessig
(volle Liste im Auswahl-Skript, siehe unten).

## Auswahlmechanismus (deterministisch, nachvollziehbar)

Aus dem zulaessigen Pool wurden per `set.seed(20260829)` (Datum der
Bewertung - fest, nachvollziehbar, nicht nachtraeglich veraenderbar)
**3 binaere + 3 multiclass Datensaetze** zufaellig gezogen (`sample()`
je Teilmenge) - eine leichte Strukturierung nach Klassenzahl, aber KEINE
manuelle Auswahl einzelner Datensaetze. Es wurde zu KEINEM Zeitpunkt vor
dieser Ziehung irgendeine Performance-Kennzahl fuer einen der Kandidaten
eingesehen - die Auswahl basiert ausschliesslich auf den 3 Metadaten-
Spalten (Instanzen/Features/Klassen).

## Eingefrorenes Set (6 Datensaetze)

| OpenML DID | Name | Instanzen | Features | Klassen | Typ |
|---|---|---|---|---|---|
| 23 | `cmc` (Contraceptive Method Choice) | 1473 | 10 | 3 | multiclass |
| 28 | `optdigits` | 5620 | 65 | 10 | multiclass |
| 38 | `sick` | 3772 | 30 | 2 | binaer |
| 458 | `analcatdata_authorship` | 841 | 71 | 4 | multiclass |
| 1464 | `blood-transfusion-service-center` | 748 | 5 | 2 | binaer |
| 1480 | `ilpd` (Indian Liver Patient Dataset) | 583 | 11 | 2 | binaer |

## Bewusste Einschraenkung: keine Covariate-Shift-/Group-Temporal-Kategorien

Die Phase-C-Kategorien F (Covariate Shift) und G (Group-/Time-Struktur)
lassen sich mit einer generischen i.i.d.-Benchmark-Suite wie CC18 NICHT
reproduzieren, ohne selbst wieder eine Auswahl-Entscheidung zu treffen
(z.B. "welcher CC18-Datensatz hat bekannten Shift" waere bereits
Wissen ueber Modellverhalten). Dieses externe Set deckt bewusst NUR
binaer/multiclass/Groessen-Diversitaet ab - Covariate-Shift-/Group-
Erkenntnisse bleiben auf die Phase-C-Datensaetze (`geoai-aquaculture`,
`openml-eeg-eye-state-timeseries`) beschraenkt, wo sie ehrlich als
"aus bereits bekannten Projekten" gekennzeichnet sind.

## Ausgefuehrt (nicht mehr Teil dieses Dokuments - siehe dortige Quellen)

Fuer jeden der 6 Datensaetze wurde eine Task-Vorbereitung angelegt
(`ML_Learning/openml-cc18-*`, analog zu bestehenden `openml-*`-
Projekten) + `BENCHMARK_PROTOCOL.md` in den Versionen 1-3 angewendet.
Volle Ergebnisse: `BACKLOG.md`/P1- und P2-Status,
`EVALUATION_LEVELS.md`, `PAPER_DRAFT.md`.

## "Weg B"-Erweiterung: 4 neue Datensaetze (eingefroren 2026-08-31, VOR jeder Ergebnisberechnung)

Nutzerentscheidung nach dem 3-Outer-Fold-Rollout ("Weg A", siehe
`BACKLOG.md`): das urspruengliche n=6-Set fuer die Decision-Stability-
Forschungsfrage um 4 weitere, bisher unbekannte CC18-Datensaetze
erweitern (Ziel n=10 insgesamt). Selektionsskript:
[`select_weg_b_extension.R`](select_weg_b_extension.R) - repliziert
EXAKT dieselben Einschlusskriterien wie oben (500-20000 Instanzen,
<=100 Features, 2-10 Klassen), zusaetzlich ausgeschlossen: alle bereits
verwendeten 13 Namen (7 Template-Projekte + die bestehenden 6
externen Datensaetze). Zulaessiger Pool nach Ausschluss: **37
Datensaetze** (43 minus die bereits verwendeten 6 - stimmt exakt).

Deterministisch per `set.seed(20260831)` (Datum dieser Ziehung - EIN
NEUER Seed, nicht der urspruengliche `20260829`: derselbe Seed auf dem
um 6 Kandidaten reduzierten Pool wuerde NICHT dieselbe Fortsetzung der
urspruenglichen Ziehung reproduzieren, sondern ein anderes, vom
reduzierten Pool abhaengiges Ergebnis - ein neuer, klar dokumentierter
Seed ist ehrlicher als der Anschein einer Fortsetzung). Wieder 2 binaer
+ 2 multiclass (dieselbe leichte Strukturierung wie beim Original,
diesmal aus einem Pool von 21 binaer/16 multiclass). Metadaten
ausschliesslich ueber OpenMLs eigene vorberechnete "qualities"
abgerufen (kein Datendownload, keine Performance-Kennzahl vor der
Ziehung eingesehen).

| OpenML DID | Name | Instanzen | Features | Klassen | Typ |
|---|---|---|---|---|---|
| 4534 | `PhishingWebsites` | 11055 | 30 | 2 | binaer |
| 1494 | `qsar-biodeg` | 1055 | 41 | 2 | binaer |
| 16 | `mfeat-karhunen` | 2000 | 64 | 10 | multiclass |
| 188 | `eucalyptus` | 736 | 19 | 5 | multiclass |

**Status: ERLEDIGT.** Level-2-Prototyp + Decision-Stability fuer alle 4
durchgefuehrt, Korrelationsanalyse bestaetigt den n=6-Nullbefund erneut
(rho=-0.134, p=0.712) - siehe `BACKLOG.md`.

## "Weg B", 2. Tranche: n=10 -> n=15 (eingefroren 2026-09-01, VOR jeder Ergebnisberechnung)

Nutzeranweisung "n=10 auf n=15 erweitern" - die Obergrenze der
urspruenglichen Vormerkung ("n=10-15"). Selektionsskript:
[`select_n15_extension.R`](select_n15_extension.R) - identische Methodik,
diesmal ausgeschlossen: alle bereits verwendeten 17 Namen (7
Template-Projekte + die bestehenden 10 externen Datensaetze). Zulaessiger
Pool: **33 Datensaetze** (37 minus die 4 Weg-B-Datensaetze - stimmt
exakt). Metadaten aus der bereits vorhandenen CC18-Abfrage
wiederverwendet (kein erneuter Download noetig).

Deterministisch per `set.seed(20260901)` (Datum dieser Ziehung, wieder
ein NEUER Seed aus demselben Grund wie bei der 1. Tranche). Diesmal 3
binaer + 2 multiclass (aus einem Pool von 19 binaer/14 multiclass) - der
Gesamt-Datensatz bleibt damit nach dieser Ziehung bei 8 binaer/7
multiclass, weiterhin nah an 50/50.

| OpenML DID | Name | Instanzen | Features | Klassen | Typ |
|---|---|---|---|---|---|
| 1487 | `ozone-level-8hr` | 2534 | 72 | 2 | binaer |
| 23381 | `dresses-sales` | 500 | 12 | 2 | binaer |
| 1053 | `jm1` | 10885 | 21 | 2 | binaer |
| 40966 | `MiceProtein` | 1080 | 81 | 8 | multiclass |
| 18 | `mfeat-morphological` | 2000 | 6 | 10 | multiclass |

**Status: EINGEFROREN, noch NICHT ausgefuehrt.**

Vollstaendige Metadaten aller 72 CC18-Datensaetze (fuer Nachvollziehbarkeit
der Poolgroesse):
[`_artifacts/cc18_full_metadata.csv`](_artifacts/cc18_full_metadata.csv)
(nicht versioniert, lokal reproduzierbar). Die 4 gezogenen Datensaetze
selbst: [`_artifacts/weg_b_extension_selection.csv`](_artifacts/weg_b_extension_selection.csv).

**Status: EINGEFROREN, noch NICHT ausgefuehrt.** Naechster Schritt:
Task-Vorbereitung analog zu den bestehenden 6 (`ML_Learning/openml-cc18-*`),
dann `BENCHMARK_PROTOCOL.md` v3 (Level-2-Prototyp) + Decision-Stability
ueber alle 3 Outer-Folds - derselbe Ablauf wie bei den ersten 6, NICHT
vorher an Performance-Zahlen angepasst.
