---
title: "Reproducibility-Checkliste (Publikationsbenchmark)"
status: draft
note: "Lebendes Dokument - wird bei jedem Fortschritt aktualisiert, anders als die eingefrorenen EXTERNAL_BENCHMARK_SET.md/BENCHMARK_PROTOCOL.md, auf die es verweist."
---

# Reproducibility-Checkliste (Publikationsbenchmark)

Konkretisierung des dritten, bislang unspezifizierten P3-Punkts aus
ChatGPTs urspruenglichem Bewertungsdokument ("Publikationsbenchmark
standardisieren") - siehe `BACKLOG.md` P3-Status. Nutzerhinweis
(2026-09-14): "eventuell hat es was mit dem geplanten JOSS-Publication
zu tun oder AutoML-Conference" - Recherche ergab einen konkreten,
zitierfaehigen Anforderungskatalog: der **AutoML-Conference ABCD-Track**
("Applications, Benchmarks, Challenges, Datasets"), Kategorie
**Applications** (passt inhaltlich auf dieses Projekt - ein Open-Source-
AutoML-Workflow, keine neue Methode).

## Quelle

AutoML-Conference ABCD-Track, Kategorie "Applications" (Stand 2026-09-14,
Zitat aus der offiziellen CfP-Seite, siehe unten fuer die genaue
Formulierung):

> "For the Applications category within the ABCD track, all benchmarking
> data and tools must be easily accessible, and all benchmarking results
> must be easily reproducible, with all necessary datasets, code, and
> evaluation procedures accessible and well-documented."

Zusaetzlich: alle Einreichungen durchlaufen einen **dedizierten
Reproducibility-Review** (mind. 1 Reproducibility-Reviewer zusaetzlich
zu den regulaeren Gutachtern) und muessen eine **Reproducibility-
Checklist** im Manuskript fuehren (bei Einreichung UND Camera-Ready).

Referenzen: [Details on ABCD Track (AutoML24)](https://2024.automl.cc/?page_id=625),
[Call for Papers - AutoML 2026](https://2026.automl.cc/call-for-papers/).
Die exakte Formulierung fuer einen kuenftigen AutoML-Conf-2027-Zyklus
ist zum jetzigen Zeitpunkt (2026-09-14) noch nicht veroeffentlicht - vor
einer tatsaechlichen Einreichung gegen die dann aktuelle CfP-Seite
gegenpruefen, nicht blind auf dieser Version aufbauen.

## Status je Anforderung

| Anforderung | Status | Beleg |
|---|---|---|
| Datensaetze zugaenglich, dokumentiert | ✅ erfuellt | [`EXTERNAL_BENCHMARK_SET.md`](EXTERNAL_BENCHMARK_SET.md) - 6 OpenML-CC18-Datensaetze mit OpenML-DID, deterministischer, dokumentierter Auswahlmechanismus (`set.seed(20260829)`), eingefroren |
| Evaluationsverfahren dokumentiert | ✅ erfuellt | [`BENCHMARK_PROTOCOL.md`](BENCHMARK_PROTOCOL.md) - 3 versionierte, eingefrorene Protokollstufen (v1/v2/v3), Vergleichs-Arme/Metrik/Split explizit fixiert |
| Code oeffentlich zugaenglich | ✅ erfuellt | `outer_workflow_evaluation_template.R` + `_v2_fair_baselines.R` + `_v3_level2.R` im oeffentlichen `MLR3_Classifikation`-Repo (GitHub) |
| Ergebnisse UNABHAENGIG (ohne privaten Zugriff) reproduzierbar | ❌ **offen** | Die 6 tatsaechlichen Datensatz-Laeufe fanden in `ML_Learning`-Projektordnern statt - **dieses Repo hat KEIN Git-Remote, ist rein lokal**. Jemand ausserhalb koennte die in `BACKLOG.md`/`PAPER_DRAFT.md` berichteten Zahlen NICHT nachvollziehen, ohne Zugriff auf ein privates Verzeichnis. Das ist die Luecke, die ein Reproducibility-Review aufdecken wuerde. |
| Formale Reproducibility-Checklist im Manuskript | ⏸ noch nicht faellig | Erst bei tatsaechlicher ABCD-Einreichung noetig (Format variiert je Zyklus) - dieses Dokument ist die Vorstufe/interne Fassung, keine Manuskript-Checkliste |
| Broader-Impact-Statement | ⏸ noch nicht faellig | JOSS-Einreichung hat bereits ein "AI Usage Disclosure" (siehe `joss/paper.md`) - ABCD-Format pruefen, sobald eine Einreichung konkret ansteht (nicht identisch mit JOSS' Abschnitt) |

## Der eine echte Luecke: unabhaengige Reproduzierbarkeit

**Naechster Schritt (auf Nutzerwunsch bewusst NICHT jetzt umgesetzt,
sondern vorgemerkt)**: ein eigenstaendiges Reproduktions-Skript
IM `MLR3_Classifikation`-Repo selbst, das ohne jede Abhaengigkeit von
`ML_Learning`:

1. Die 6 eingefrorenen OpenML-DIDs (23, 28, 38, 458, 1464, 1480, siehe
   `EXTERNAL_BENCHMARK_SET.md`) per `mlr3oml` direkt laedt.
2. `outer_workflow_evaluation_v2_fair_baselines.R` (oder die zum
   Zeitpunkt der Einreichung aktuelle Protokollversion) je Datensatz
   end-to-end durchlaeuft.
3. Eine Ergebnistabelle erzeugt, die sich direkt mit den in
   `BACKLOG.md`/`PAPER_DRAFT.md` berichteten Zahlen vergleichen laesst.

Damit koennte ein Reproducibility-Reviewer (oder jede interessierte
dritte Person) `git clone` + ein Skript ausfuehren, statt auf
Vertrauen angewiesen zu sein. Umfang/Laufzeit (6 Datensaetze x
mehrere Vergleichs-Arme x 3 Outer-Folds) noch nicht abgeschaetzt -
folgt als eigener Arbeitsschritt.

## Einordnung

Diese Checkliste schliesst den P3-Punkt "Publikationsbenchmark
standardisieren" NICHT vollstaendig ab - sie macht den vagen
Checklistenpunkt konkret PRUEFBAR und zeigt, dass 3 von 4 inhaltlichen
Anforderungen bereits erfuellt sind (dank der bereits vorhandenen
`EXTERNAL_BENCHMARK_SET.md`/`BENCHMARK_PROTOCOL.md`-Arbeit), waehrend
die vierte (unabhaengige Reproduzierbarkeit) eine echte, bisher nicht
erkannte Luecke ist. Diese Luecke ist NICHT dringend (keine
AutoML-Conf-Einreichung aktuell geplant, JOSS bleibt bis ~Nov 2026
pausiert) - aber jetzt explizit dokumentiert statt implizit anzunehmen,
dass "die Zahlen schon stimmen werden".
