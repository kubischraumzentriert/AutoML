# Referenz: Tabular Foundation Models als Ensemble-Diversitaets-Kandidaten

Herkunft, Nutzung und alle bisherigen Testergebnisse fuer TabICLv2 (und,
als Anlassuntersuchung, MotherNet) als Diversitaets-Kandidaten (analog
Hebel 1/FT-Transformer, SVM/Naive Bayes/LDA - siehe `TARGETS.md` und
`openml-steel-plates-fault/README.md`), aber mit tabular foundation
models statt klassischer ML.

---

## 1. Herkunft/Quelle

- **Paper**: Qu, Holzmuller, Varoquaux, Le Morvan. "TabICLv2: A better,
  faster, scalable, and open tabular foundation model." arXiv:2602.11139
  [cs.LG], 11. Februar 2026 (INRIA Saclay, SODA-Team).
- **Code/Gewichte**: https://github.com/soda-inria/tabicl (Inference-Code +
  vortrainierte Gewichte bereits offen, Pretraining-Code angekuendigt).
  Minimal-Reimplementierung zu Lehrzwecken: `soda-inria/nanotabicl`.
- **PyPI-Paket**: `tabicl` (nutzt `TabICLClassifier`, sklearn-kompatible
  API - `fit()`/`predict()`).
- Anlass: Nutzer teilte das Paper (2026-08-18) direkt nach Abschluss der
  Suche nach klassischen CPU-guenstigen Diversitaetsmodellen (SVM/NB/LDA/
  QDA - durchweg negativ, siehe TARGETS.md). Frage: schlaegt ein
  speziell gegen Baum-Ensembles trainiertes Foundation-Model die Sache
  besser als klassische Modelle?

## 2. Was ist TabICLv2 (Kurzfassung)

In-Context-Learning-Modell (kein Gradienten-Training auf dem eigenen
Datensatz noetig - ein Forward-Pass reicht): Trainings- + Testdaten gehen
gemeinsam in einen Transformer, der direkt die Testlabels vorhersagt.
Architektur: spaltenweises Set-Transformer-Embedding -> zeilenweise
Aggregation -> datensatzweites In-Context-Learning (Test-Zeilen "sehen"
Trainings-Zeilen als Kontext). Zentrale Neuerung QASSMax (query-aware
scalable softmax) gegen "Attention Fading" bei grossen Trainingsmengen.
Laut Paper auf TabArena/TALENT ungetuned staerker als getuntes, ensembled
RealTabPFN-2.5, bei 10-12x schnellerer Inferenz. Skaliert bis zu
1M Zeilen / 500 Features (Disk-Offloading, <24GB CPU/<50GB GPU).

## 3. Nutzung im eigenen Workflow: Python-Export statt reticulate

**Keine native R/mlr3-Anbindung** - `mlr3extralearners` hat (Stand
2026-08-18) keinen Wrapper, das Paper ist zu neu. Zwei denkbare Wege:

1. **`reticulate`** - wuerde `tabicl` direkt aus R aufrufbar machen, zieht
   aber eine schwere Laufzeit-Abhaengigkeit (PyTorch + tabicl) in jedes
   Projekt, das es nutzt, und wuerde die etablierte Trennung R-Workflow /
   Python-Export aufweichen.
2. **Duenner Python-Export** (gewaehlter Weg) - R exportiert die Daten als
   CSV, ein eigenstaendiges Python-Skript (eigenes venv) ruft TabICLv2
   auf, Ergebnis fliesst als Text/CSV zurueck. Passt zur etablierten
   Konvention "R-only Repos, Python nur als duenner, wegwerfbarer Export"
   (bisher fuer den FT-Transformer-Kaggle-GPU-Export genutzt, hier
   erstmals fuer einen reinen Inferenz-Test OHNE Training - kein
   Kaggle-Umweg noetig, laeuft lokal auf der CPU).

**Setup** (einmalig pro Maschine, kurzer Pfad noetig - Windows-
Pfadlaengenlimit bei `torch`s tief verschachtelten Metadaten-Ordnern):
```
python -m venv C:\Users\<user>\tabicl_venv
C:\Users\<user>\tabicl_venv\Scripts\pip.exe install tabicl pandas scikit-learn lightgbm
```
Testskript je Projekt in `<projekt>/python_export/`, laedt `train.csv`,
nutzt `TabICLClassifier()` (sklearn-API), vergleicht im SELBEN Skript
gegen `RandomForestClassifier`/`lgb.LGBMClassifier` auf identischem Split
- bewusst NICHT gegen R-Zahlen, um keine Hyperparameter-Default-
Unterschiede (R/mlr3 vs. Python/sklearn) als Modellunterschied
misszuverstehen (dieser Fehler passierte im ersten Testlauf und wurde
korrigiert, siehe unten).

## 4. Testergebnisse (2026-08-18, 5 Projekte)

Alle Vergleiche: identischer 80/20-Stratified-Holdout (seed=42), TabICLv2/
RandomForest/LightGBM im selben Python-Skript trainiert (fairer Vergleich).

| Projekt | Zeilen | Klassen | TabICLv2 BAcc | Bestes Referenzmodell | Kappa (TabICLv2 vs. LightGBM) | Mehrheits-Blend |
|---|---:|---:|---:|---:|---:|---:|
| `uci-parkinsons-voice-groupcv` | 196 | 2 | **0.9828** | RF/LightGBM 0.8828 | 0.87 | 0.8828 (kein Gewinn - Blend verwaessert TabICLv2s Vorsprung) |
| `openml-synthetic-control-timeseries` | 600 | 6 | 1.0000 | RandomForest 1.0000 | 0.98 (fast identisch) | 1.0000 |
| `wdbc-plateau-test` | 683 | 2 | 0.9671 | RandomForest 0.9671 | 0.98 (fast identisch) | 0.9671 |
| `openml-credit-g` | 1000 | 2 | 0.6500 | LightGBM 0.6833 | 0.60 (staerkste Dekorrelation) | 0.6679 (kein Gewinn) |
| `openml-steel-plates-fault` | 1941 | 7 | 0.8562 | LightGBM 0.8746 | 0.83 | 0.8708 (kein Gewinn) |

**Muster**: klarer Sieg auf dem kleinsten Datensatz (`parkinsons`, 196
Zeilen), Gleichstand auf zwei nahezu perfekt trennbaren Datensaetzen
(`synthetic-control`, `wdbc-plateau-test` - beide Kappa~1.0, praktisch
identische Vorhersagen wie RandomForest, Deckeneffekt), knapp unterlegen
bzw. schwaechstes Modell auf den beiden groesseren/schwereren Projekten.
Kein konsistenter Zusammenhang mit Datensatzgroesse allein erkennbar
(683 vs. 1000 Zeilen zeigen entgegengesetzte Ergebnisse).

**Wichtige methodische Lehre (`parkinsons`)**: der naive Mehrheits-Blend
kann einen echten Staerkevorteil eines einzelnen Modells ZUNICHTE machen,
wenn die anderen beiden Kandidaten es 2-zu-1 ueberstimmen (hier: RF+
LightGBM beide bei 0.8828, TabICLv2 bei 0.9828 - der Blend faellt auf
0.8828 zurueck). Das ist ein starkes Argument fuer die produktiv genutzte
GEWICHTETE Caruana-Greedy-Selektion (`149_ensemble_selection.R`) statt
eines starren Mehrheitsvotums - ein guter Kandidat auf einer Instanz kann
dort tatsaechlich hoeher gewichtet werden, statt einfach ueberstimmt zu
werden.

## 4b. Echte Greedy-Selektion statt naivem Blend (`predictingsmartphoneAddiction_s6e8`, 5000-Zeilen-Stichprobe)

`s6e8` hat 691.370 Zeilen - viel zu gross fuer TabICLv2 auf der CPU (bei
1552 Trainingszeilen bereits ~60-80s, quadratische Architektur-Komplexitaet).
Nutzer-Entscheidung nach expliziter Nachfrage: 5000-Zeilen-Stichprobe als
groessenbeschraenkter Machbarkeits-Test (KEIN Test auf den vollen Daten),
gezielt um zu pruefen, ob die ECHTE, gewichtete Caruana-Greedy-Selektion
(identischer Algorithmus wie `149_ensemble_selection.R`, hier in Python
nachgebaut) TabICLv2 anders behandelt als der naive Mehrheits-Blend bei
`parkinsons` (der TabICLv2s Vorsprung dort zunichte machte).

Pool: RandomForest x2, LightGBM x2, CatBoost x2 (Referenz) + TabICLv2 x1,
3-Wege-Split 60/20/20 (Train/Selektion/Bestaetigung).

| Modell | BAcc (Bestaetigung) |
|---|---:|
| catboost_6 (bestes Einzelmodell) | 0.8382 |
| catboost_8 | 0.8362 |
| **tabiclv2** | **0.8360** |
| lgb_31_0.1 | 0.8344 |
| rf_200_None | 0.8282 |
| rf_200_10 | 0.8276 |
| lgb_63_0.05 | 0.8260 |

Alle sieben Kandidaten eng beieinander (0.826-0.838). Greedy-Selektion
(50 Runden, beste Ensemblegroesse 22): **TabICLv2 am HAEUFIGSTEN gezogen**
(9x, vor `rf_200_None` 4x, `catboost_6`/`catboost_8` je 2-3x,
`lgb_31_0.1` 2x, `rf_200_10` 2x) - Greedy-Ensemble-Bestaetigungs-BAcc
**0.8411**, ein kleiner aber echter Gewinn ueber das beste Einzelmodell
(+0.0029) UND ueber TabICLv2 allein (+0.0051).

**Einordnung**: anders als bei `parkinsons` (naiver Blend zerstoert
TabICLv2s Vorsprung) wird TabICLv2 hier von der gewichteten Selektion
tatsaechlich bevorzugt gezogen, mit einem kleinen echten Ensemble-Gewinn.
Der Effekt ist klein genug, dass er im Rauschen einer ~1000-zeiligen
Bestaetigungsmenge liegen koennte - kein belastbarer Beweis, aber ein
ermutigendes Signal fuer einen kuenftigen GPU-gestuetzten Test auf den
VOLLEN 691K Zeilen (aktuell nicht durchgefuehrt, siehe Restriktion oben).

## 5. Fazit/Einordnung

Kein robuster, konsistenter Gewinner ueber alle fuenf Projekte - aber DER
erste Kandidat in der gesamten Diversitaets-Testreihe dieser Session
(nnet/ExtraTrees/kNN/SVM/NaiveBayes/LDA/QDA), der auf mindestens einem
Projekt klar und deutlich (+0.10 BAcc) vor beiden Baum-Referenzen liegt.
Kein Backport-Kandidat fuer den naiven Blend-Mechanismus (der wuerde den
Vorteil dort, wo er auftritt, sogar zunichtemachen, siehe `parkinsons`) -
aber mit der ECHTEN gewichteten Greedy-Selektion getestet (Abschnitt 4b,
`s6e8`-Stichprobe): TabICLv2 wird dort am haeufigsten von allen 7
Kandidaten gezogen, mit einem kleinen echten Ensemble-Gewinn (+0.003 ueber
das beste Einzelmodell). Kein zuverlaessiges Muster erkennbar, WANN
TabICLv2 gewinnt/verliert (kleinster Datensatz gewinnt klar, aber Groesse
allein erklaert das Restmuster nicht). **Naechster sinnvoller Schritt,
falls fortgesetzt**: derselbe Greedy-Pool-Test auf den VOLLEN Daten eines
Projekts (GPU noetig fuer akzeptable Laufzeit bei TabICLv2 - bisher nur
CPU-Machbarkeitstests mit Stichproben/kleinen Projekten durchgefuehrt).

## 6. MotherNet - aktuell NICHT testbar (2026-08-19)

### Herkunft

- **Paper**: Muller, Curino, Ramakrishnan (Microsoft Gray Systems Lab).
  "MotherNet: Fast Training and Inference via Hyper-Network
  Transformers." arXiv:2312.08598v2 [cs.LG], ICLR 2025 (Camera-Ready
  9. Mai 2025).
- **Code**: https://github.com/microsoft/ticl (PyPI-Paket `ticl` NICHT
  verfuegbar, Installation nur via `pip install git+https://github.com/microsoft/ticl.git`).
- Anlass: Nutzer teilte das Paper direkt nach den TabICLv2-Tests. Idee:
  MotherNet erzeugt in EINEM Forward-Pass die Gewichte eines kleinen,
  eigenstaendigen MLPs (statt bei jeder Vorhersage ueber den vollen
  Trainings-Kontext zu attendieren wie TabPFN/TabICLv2) - genau das haette
  unser Problem bei `s6e8` geloest (10+h CPU-Schaetzung fuer 296K
  Testzeilen mit TabICLv2, weil JEDE Vorhersage teuer bleibt). MotherNet:
  einmal teuer (ein Forward-Pass, ~0.14s laut Paper), danach beliebig
  viele Testzeilen guenstig wie ein normales MLP.
- Klarstellung vorab (Nutzerfrage): TorchScript-Export (`torch.jit.trace`/
  `script()` in Python, `torch::jit_load()` in R) haette hier NICHT
  geholfen - loest weder das eigentliche Rechenzeit-Problem (aendert nur
  die Aufruf-Sprache, nicht die zugrundeliegenden LibTorch-FLOPs) noch ist
  die Architektur sauber traceable (dynamische, datensatzabhaengige
  Logik: Mixed-Radix-Ensembling, zirkulaere Permutationen etc. liegen
  ausserhalb des reinen Forward-Pass-Graphen).

### Setup-Versuch und Befund

Installation im selben `tabicl_venv` (siehe Abschnitt 3) via
`pip install git+https://github.com/microsoft/ticl.git`. Das Paket ist
schlecht fuer reine Inferenz verpackt - `ticl/__init__.py` importiert
eager die GESAMTE Trainings-/Auswertungs-Abhaengigkeitskette, auch fuer
einen simplen `MotherNetClassifier`-Import. Nacheinander fehlende
Pakete nachinstalliert: `wandb`, `mlflow`, `gpytorch`, `tqdm`,
`configspace`, `interpret`, `einops`. Zusaetzlich ein echter
Versions-Bug gefunden und lokal gepatcht: `ticl/models/layer.py`
importierte `Optional`/`Dropout`/`LayerNorm`/`Linear`/`Module` aus
`torch.nn.modules.transformer` - diese Re-Exports existieren in
aktuellen PyTorch-Versionen (hier 2.13.0) nicht mehr. Gepatcht auf
direkte Imports aus `typing`/`torch`/`torch.nn`.

Nach all dem laesst sich `MotherNetClassifier` erfolgreich importieren
UND instanziieren startet - **scheitert aber am Checkpoint-Download**:

```
Downloading model from https://amuellermothernet.blob.core.windows.net/models/...
socket.gaierror: [Errno 11001] getaddrinfo failed
```

`nslookup amuellermothernet.blob.core.windows.net` bestaetigt: **die
Domain existiert nicht mehr** ("Non-existent domain", NXDOMAIN) - kein
Problem auf unserer Seite. Bestaetigt durch das offene, unbeantwortete
GitHub-Issue microsoft/ticl#27 ("TabFlex and MotherNet checkpoints
unavailable - Azure host returns NXDOMAIN"), das exakt dasselbe Problem
beschreibt. Der dort genannte HuggingFace-Spiegel (`microsoft/mothernet`)
enthaelt NUR `tabpfn_07_24_2023_epoch1650.cpkt` (ein alter TabPFN-
Referenz-Checkpoint) - NICHT den fuer `MotherNetClassifier` benoetigten
`mn_Dclass_average_03_25_2024_17_14_32_epoch_3970.cpkt`. Direkt per API
gegengeprueft (`huggingface.co/api/models/microsoft/mothernet`), Befund
bestaetigt.

### Fazit

**MotherNet ist aktuell nicht nutzbar** - nicht wegen eines Setup-
Fehlers, sondern weil der Modell-Herausgeber selbst den einzigen
offiziellen Checkpoint-Host abgeschaltet hat, ohne Ersatz bereitzustellen
(GitHub Issue seit Erstellung unbeantwortet). Einzige verbleibende
Option waere ein Eigentraining (~4 Wochen auf einer A100-GPU laut Paper)
- unpraktikabel. Kein aktiver Test moeglich, daher kein Eintrag in der
Ergebnistabelle unter Abschnitt 4. **Falls spaeter erneut relevant**:
zuerst pruefen, ob microsoft/ticl#27 inzwischen geschlossen wurde bzw.
ob ein neuer Checkpoint-Host verfuegbar ist, bevor der Setup-Aufwand
(Abhaengigkeitskette + `layer.py`-Patch, siehe oben) wiederholt wird.
