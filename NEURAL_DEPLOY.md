# Neuronale Modelle: R-Entwicklung, Python-GPU-Export

Policy fuer neuronale Tabellen-Modelle (v. a. FT-Transformer) als Ensemble-
Diversitaet. **Dieses Repo bleibt R-only.** Python ist keine Abhaengigkeit,
sondern ein duenner, wegwerfbarer Deploy-Export ganz am Schluss.

## Grundregel

> Alles in R entwickeln und entscheiden (mlr3, mlr3torch, r-torch) - inklusive
> eines FT-Transformer-PROTOTYPS auf einem Sample zur Diversitaets-Pruefung.
> **Erst wenn** der R-Prototyp zeigt, dass das neuronale Modell von den GBMs
> **dekorreliert** ist (Korrelation ~0.9x statt ~0.99) **und** traegt, EIN
> self-contained Python-Script fuer Kaggle-GPU erzeugen - als Export, nicht ins
> Repo committet. Vorlage re-parametrisieren, nicht neu schreiben.

## Warum diese Trennung

- **R = Oekosystem und Entscheidungen.** Exploration, exact-value TE, CV,
  Modellwahl, Parameter-Suche und der FT-Prototyp (mlr3torch
  `classif.ft_transformer`, lokal/CPU auf einem Sample) laufen hier.
- **Python = nur der GPU-Lauf.** Der einzige Punkt, an dem R praktisch versagt,
  ist **Kaggle + GPU + neuronal**. Der R-Weg dort ist eine mehrfache Sackgasse
  (siehe unten). Python mit vorinstalliertem torch(+CUDA) ist der begehbare Weg.

## Ablauf

1. **In R (dieses Repo):** GBMs (LightGBM/XGBoost/CatBoost) tunen, TE/Features
   festlegen, per CV die Zielmetrik optimieren. Wenn die GBMs zu korreliert sind
   (Blend gibt kaum mehr her), einen FT-Transformer-Prototyp (`classif.ft_transformer`,
   Sample/CPU) bauen und die **Korrelation zu den GBMs** + AUC pruefen.
2. **Gate:** Nur weiter, wenn der Prototyp dekorreliert (~0.9x) UND konkurrenzfaehig
   genug ist. Sonst kein neuronales Modell - die GBMs sind dann ausgereizt.
3. **Export:** Das Python-Deploy-Template re-parametrisieren (Pfade, Spalten,
   positive Klasse, GBM-Params). Referenz-Vorlage:
   `ML_Learning\predictingsmartphoneAddiction_s6e8\s6e8_blend_ft_kaggle.py`
   (4-Modell-Blend LightGBM+XGBoost+CatBoost+FT-Transformer + exact-value TE +
   Rang-Average-Blend, `SAMPLE_FRAC`/Device-Auto-Detect).
4. **Kaggle:** Python-Notebook, GPU-Accelerator an, Daten anhaengen, erst mit
   `SAMPLE_FRAC=0.05` schnelltesten (laeuft in Minuten, `device=cuda` +
   Holdout-Diagnose pruefen), dann `SAMPLE_FRAC=1.0` fuer die echte Submission.

## Was 1:1 uebertraegt - und was nur ungefaehr

**Exakt** (R -> Python):
- **GBM-Parameter** - lightgbm/xgboost/catboost sind in R UND Python DIESELBEN
  Bibliotheken, die getunten Werte gelten unveraendert.
- TE-Config (Spalten, `alpha`), Feature-/Modell-/Blend-Entscheidungen, und das
  Urteil "lohnt sich ein neuronales Modell ueberhaupt?".

**Nur ungefaehr:**
- Die **FT-Transformer-Architektur/Hyperparameter**. mlr3torch-FT (R) und ein
  hand-gerollter PyTorch-FT (Python) sind NICHT dasselbe Modell - die in R
  "gefundenen" FT-Params sind ein Richtwert, kein Transfer. Deshalb muss die
  Python-FT beim Export SELBST kurz validiert werden: der Holdout-Block im Script
  gibt per-Modell-AUC + Blend3(GBM) vs. Blend4(+FT) + die FT-GBM-Korrelation aus,
  VOR der Submission.

## Kaggle-Umgebung (Python)

- Vorinstalliert auf GPU-Images: `torch`(+CUDA), `lightgbm`, `xgboost`,
  `catboost`, `pandas`, `numpy`, `scikit-learn` - **kein pip/Internet noetig**.
- Der FT-Transformer im Export ist self-contained (reines PyTorch, ~80 Zeilen),
  keine `rtdl`-Abhaengigkeit -> laeuft auch bei Internet-aus.
- Nur der FT-Transformer nutzt die GPU; die GBMs laufen auf CPU (robust, keine
  GPU-Parameter-Versionsfallen).

## Warum NICHT der R-Weg auf Kaggle (dokumentierte Sackgasse, s6e8)

Der Versuch, `mlr3torch`-FT direkt auf Kaggle+GPU zu fahren, scheiterte dreifach:
1. **Versionsskew**: Kaggles `mlr3misc` (0.16) zu alt fuer das neue
   `mlr3pipelines` (braucht >= 0.17). Fix nur mit ganzem mlr-Stack aus
   `mlr-org.r-universe.dev` + Kernel ZWEIMAL neu starten (alte geladene
   Namespaces kleben sonst).
2. **libtorch-Download 404**: `torch::install_torch()` waehlte fuer libtorch
   2.8.0 die Variante `cu117` - diesen Build gibt es nicht (404).
3. **GPU gar nicht an**: `nvidia-smi` fehlte, weil der Accelerator nicht
   eingeschaltet war.

Konsequenz: fuer neuronale Modelle auf Kaggle-GPU **Python nehmen**, nicht R.

## Ergebnis-Beleg (s6e8, AUC)

LightGBM+TE `0.96731` -> 3-GBM-Blend `0.96775` -> +FT-Transformer (Python/GPU)
`0.96810`. Der dekorrelierte FT holte `+0.00035`, was die zu 0.99 korrelierten
GBMs nicht konnten - die Diversitaets-These bestaetigt. Genau dafuer, und nur
dafuer, gibt es den Python-Export.

## Geprueft und verworfen: `nnet` als billigerer neuronaler Kandidat (s6e8, 2026-08-06)

`nnet` (Base-R-MLP, einlagig, IMMER CPU - kein GPU-Pfad im Paket) waere ein
Kandidat gewesen, der die ganze Python-GPU-Export-Kette ueberfluessig macht,
weil er klein genug ist, um direkt in R auf voller Groesse zu laufen. Getestet
auf demselben Holdout-Split wie die GBMs (20%-Sample, exact-value TE, One-Hot
+ skaliert fuer `nnet`, Skript `nnet_diversity_check.R` im Projektordner):

| Modell | AUC (Holdout) |
|---|---:|
| CatBoost | 0.9612 |
| XGBoost | 0.9609 |
| LightGBM | 0.9599 |
| ranger | 0.9577 |
| **nnet** | **0.9566** |

`nnet` ist das schwaechste der fuenf Modelle (auch unter ranger) UND mit
0.976 zu stark mit dem GBM-Mittel korreliert (GBMs untereinander: 0.988-0.991)
- Blend4(+nnet) `0.9617` vs. Blend3(GBM) `0.9616` ist Rauschen. Vermutete
Ursache: eine einzelne versteckte Schicht ohne Embeddings/Attention lernt
strukturell eine aehnliche Funktion wie die Baeume, statt eine andere Sicht
auf die Daten zu bekommen - anders als der FT-Transformer, dessen Embeddings/
Attention-Mechanismus genau das leisten. **Kein Diversitaetsgewinn, Kandidat
verworfen** - fuer neuronale Diversitaet bleibt der FT-Transformer-Weg
(oben) die richtige Wahl trotz des Python-Export-Aufwands.

**Nachtrag - `mlr3torch`-MLP/TabResNet als "billigerer Torch-Ersatz" geprueft
und ohne Testlauf verworfen**: `classif.mlp` und `classif.tab_resnet` (die
einzigen zwei weiteren fertigen Architekturen in `mlr3torch` neben
`classif.ft_transformer`) haben laut `feature_types` **beide KEIN natives
`factor`** - nur `integer`/`numeric`/`lazy_tensor`. Nur `classif.ft_transformer`
hat eingebaute Kategorie-Embeddings. Ein direkter `classif.mlp`-Einsatz mit
integer-kodierten Kategorien haette dieselbe strukturelle Schwaeche wie
`nnet` reproduziert; echte Embeddings gaebe es nur ueber eine selbstgebaute
Graph-Architektur (`po("torch_ingress_categ")` + `po("torch_ingress_num")`),
was den erhofften Vorteil ("billiger als FT-Transformer") wieder aufhebt.
Deshalb ohne Testlauf abgebrochen, bevor Rechenzeit investiert wurde.

**Korrektur (2026-08-10, Literaturbewertung `C:\Git\literatur\bewertung.md`,
mlr3torch-Paper arXiv 2604.18152)**: die obige Praemisse ("selbstgebaute
Graph-Architektur hebt den Kostenvorteil auf") war zu pessimistisch. Das
Paper zeigt ein dokumentiertes, ~5-zeiliges Multi-Input-Beispiel mit genau
dieser Architektur:
```r
path_num <- po("select_1", selector = selector_type("numeric")) %>>%
  po("torch_ingress_num") %>>% nn("tokenizer_num", d_token = 10)
path_categ <- po("select_2", selector = selector_type("factor")) %>>%
  po("torch_ingress_categ") %>>% nn("tokenizer_categ", d_token = 10)
graph <- list(path_num, path_categ) %>>% nn("merge_cat", dim = 2)
```
`nn("tokenizer_categ")` ist derselbe Tokenizer-Baustein aus Gorishniy et al.
2021 (FT-Transformer-Originalpaper), den `classif.ft_transformer` intern
nutzt - kein Eigenbau, sondern dokumentiertes Idiom. Ein "billiger" embedded-
MLP (Tokenizer+Concat+kleiner Head, OHNE Attention-Layer) waere damit
guenstig baubar. Aendert NICHTS an s6e8 selbst (dort funktioniert der
GPU-FT-Transformer bereits, LB 0.96810, kein Bedarf fuer eine CPU-
Alternative) - aber die "Kostenvorteil-hebt-sich-auf"-Begruendung fuer
KUENFTIGE GPU-lose Projekte mit Neural-Diversity-Bedarf gilt so nicht mehr.
Bewusst NICHT prototypisiert (kein aktuelles Projekt braucht es) - nur die
Praemisse korrigiert, damit eine kuenftige Session nicht wieder davon
ausgeht, dass echte Embeddings zwingend teuren Eigenbau brauchen.

## Geprueft: TabPFN als echtes Blend-Mitglied (nicht nur Fehleranalyse, s6e8, 2026-08-06)

Anderer Lernansatz als `nnet`/GBMs (vortrainiertes In-Context-Learning statt
additive Baeume) - Skript `tabpfn_diversity_check.R` im Projektordner, gleicher
Holdout-Split, aber bewusst kleine Eval-Stichprobe (n=2000) und ein
klassenstratifizierter Kontext von 999 Zeilen (Konvention aus `095_tabpfn_
benchmark.R`/`147_error_analysis_ranger_tabpfn.R`), da TabPFN kontextlimitiert
ist und ueber den gehosteten TabPFN-Dienst laeuft (bestehender lokaler
Auth-Token unter `~/.cache/tabpfn/auth_token`, kein neuer Login noetig).

| Modell | AUC (n=2000) |
|---|---:|
| XGBoost | 0.9649 |
| CatBoost | 0.9646 |
| LightGBM | 0.9636 |
| **TabPFN** | **0.9352** |
| Blend3 (GBM) | 0.9652 |
| Blend4 (+TabPFN) | 0.9634 |

**Korrelation TabPFN-GBM-Mittel: 0.899** - echte Dekorrelation, genau im
Zielbereich "~0.9x statt ~0.99" (GBMs untereinander: 0.989-0.992). Die
Diversitaets-These bestaetigt sich hier tatsaechlich, anders als bei `nnet`.
**Aber**: TabPFN ist mit AUC 0.9352 spuerbar schwaecher (~0.03 unter den
GBMs) - erwartbar, da es nur 999 statt der ~78k GBM-Trainingszeilen sah.
Im **gleichgewichteten** Blend4 ueberwiegt die Schwaeche den Dekorrelations-
vorteil: Blend4 (0.9634) < Blend3 (0.9652) - das bekannte Muster "ein
schwaecheres Modell verwaessert einen gleichgewichteten Blend".
**Nicht weiterverfolgt** (Nutzer-Entscheidung 2026-08-06), aber zwei
plausible Hebel fuer eine spaetere Session, falls das Signal doch genutzt
werden soll: (a) gewichtsoptimierter statt gleichgewichteter Blend (TabPFN
niedrig gewichten, analog zur SLSQP-Blend-Lehre aus s6e7-4th-place), (b)
groesserer Kontext als 999 Zeilen, falls der Dienst das zulaesst - wuerde
die Luecke zu den GBMs vermutlich verkleinern, kostet aber mehr API-Zeit.

## Gewichtsoptimierter Blend statt Gleichgewichtung getestet, UND CPU-Laufzeit-Beleg gegen Voll-Training (s6e8, 2026-08-08)

Hebel (a) aus dem TabPFN-Abschnitt oben, aber auf den FT-Transformer
angewendet: Skript `ft_blend_weight_optimization.R`/`_step2.R` im
Projektordner. Softmax-Reparametrisierung + Nelder-Mead (kein neues Paket,
gleiches Muster wie `class_multiplier_tuning.R`) statt SLSQP, optimiert
direkt auf Holdout-AUC.

**Schritt 1** (GBMs UND FT beide auf 20%-Stichprobe, gleicher Split):

| Modell | AUC |
|---|---:|
| CatBoost | 0.9612 |
| XGBoost | 0.9609 |
| LightGBM | 0.9599 |
| FT-Transformer (15 Epochen, d_token=64) | 0.9578 |
| Blend4 gleichgewichtet | 0.9614 |
| Blend4 gewichtsoptimiert | 0.9617 (FT-Gewicht 0.009) |

FT-GBM-Korrelation 0.986 - deutlich hoeher als beim vollskalierten
Kaggle-FT (dort implizit dekorreliert genug fuer +0.00035) und auch hoeher
als TabPFNs 0.899. Bei reduzierter Kapazitaet (wenige Epochen, kleines
`d_token`) konvergiert der FT-Transformer offenbar zu einer generischeren,
den GBMs aehnlicheren Loesung statt einer eigenstaendigen Repraesentation -
weniger Training heisst hier nicht nur schwaecher, sondern auch weniger
dekorreliert.

**Schritt 2** (GBMs auf ~95% der Daten neu trainiert/95.0%, 656.801 Zeilen;
FT-Vorhersagen aus Schritt 1 unveraendert wiederverwendet - kein Leakage,
da der Holdout `iva` in beiden Schritten identisch bleibt):

| Modell | AUC Schritt 1 (20%) | AUC Schritt 2 (~95%) |
|---|---:|---:|
| LightGBM | 0.9599 | 0.9648 |
| XGBoost | 0.9609 | 0.9649 |
| CatBoost | 0.9612 | 0.9640 |
| FT (unveraendert) | 0.9578 | 0.9578 |
| Blend4 gleichgewichtet | 0.9614 | 0.9642 |
| **FT-Gewicht optimiert** | 0.009 | **0.0004 (praktisch 0)** |
| Blend4 gewichtsoptimiert | 0.9617 | 0.9651 (nur +0.0002 ueber bestem Einzelmodell) |

Bestaetigt die Erwartung exakt: mit staerkeren GBMs (mehr Daten) waechst
der Abstand zum (unveraenderten) 20%-FT, der Optimierer draengt FT auf
praktisch null zurueck. Der optimierte Blend schlaegt das beste
Einzelmodell nur noch um Rauschen.

**Laufzeit-Beleg gegen CPU-Volltraining**: GBMs skalieren fast linear
(657k Zeilen: 366.9s vs. 104k Zeilen: 63.1s, Faktor ~5.8x bei ~6.3x mehr
Zeilen). Der FT-Transformer brauchte fuer nur **15 Epochen, d_token=64,
auf 20% der Daten bereits 1994.8s (~33 Minuten)** - schon ueber der unten
festgehaltenen 30-Minuten-Schwelle, und das bei weitem nicht auf
Kaggle-Produktionsniveau (40-80 Epochen, `d_token=128`, 100% Daten). Eine
Hochrechnung auf Produktionseinstellungen liegt im Bereich mehrerer
Stunden - handfeste Bestaetigung, warum der Python-GPU-Export-Weg (oben)
fuer den FT-Transformer bei diesem Projekt der richtige bleibt, kein
Alternativweg ueber laengeres CPU-Training.

**Faustregel (siehe auch `adr/002-r-only-python-gpu-export.md`)**: liegt
die hochgerechnete CPU-Laufzeit eines neuronalen Modells bei
Produktionseinstellungen ueber ca. 30 Minuten, gilt CPU-Training fuer
dieses Projekt als nicht praktikabel - Python-GPU-Export nutzen oder das
neuronale Modell fuer dieses Projekt verwerfen. Immer den Ziel-Algorithmus
SELBST an ein bis zwei kleinen Stichprobengroessen timen, um die
Skalierung zu extrapolieren - ein anderer, billigerer Algorithmus (rpart/
LDA) ist dafuer KEIN verlaesslicher Proxy (andere Skalierungscharakteristik,
bei neuronalen Netzen zusaetzlich ein fixer Overhead pro Epoche, der nicht
mit der Zeilenzahl schrumpft).
