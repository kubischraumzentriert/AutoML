# Externes Benchmark-Set (eingefroren, Stand 2026-08-29)

P1 aus der 2026-08-29-Bewertung: "Datensaetze vorab festlegen -&gt;
Auswahlregeln dokumentieren -&gt; Benchmark einfrieren -&gt; erst danach
Ergebnisse berechnen", explizit um **Benchmark Selection Bias**
auszuschliessen - die bisherigen 7 Phase-C-Datensaetze stammen aus
bereits erkundeten Projekten dieses Templates, bei denen Imbalance/
Leaks/Modellverhalten schon bekannt waren. Dieses Dokument fixiert ein
Set, das VOR jeder Ergebnisberechnung feststeht, ausschliesslich anhand
oeffentlicher Metadaten ausgewaehlt.

**Noch NICHT ausgefuehrt** - dieses Dokument deckt nur die Auswahl ab
(P1, Teil "externer Benchmark"). Die eigentlichen Laeufe (inkl. der
in P1 ebenfalls geforderten fairen getunten Baselines) sind ein
separater, noch nicht gestarteter Schritt.

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

## Naechster Schritt (nicht Teil dieses Dokuments)

Sobald ausgefuehrt: fuer jeden der 6 Datensaetze eine Task-Vorbereitung
(analog zu bestehenden `openml-*`-Projekten) + Anwendung von
`BENCHMARK_PROTOCOL.md` (ggf. Version 2, falls die "faire Baselines"-
Erweiterung aus P1 - Tuned Ranger/LightGBM, Best Single Tuned Model - das
Protokoll selbst aendert).
