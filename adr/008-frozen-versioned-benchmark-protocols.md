# 008: Benchmark-Protokolle werden eingefroren und versioniert, nie in-place veraendert

Status: Accepted
Datum: 2026-08-30 (gelebte Praxis seit Protokoll v1, 2026-08-28, hier
erstmals als eigenstaendige Entscheidung fixiert)

## Kontext

`BENCHMARK_PROTOCOL.md` definiert die exakten Vergleichsarme, Seeds und
Outer-Fold-Zahlen fuer die Outer-Evaluation des Templates (Protokoll
v1: Default-Baselines + `workflow_ranger`; v2: + faire getunte
Baselines; v3: + Level-2-Modellwahl). Jede Version wurde auf mehreren
Datensaetzen ausgefuehrt, und die daraus berichteten Deltas (z.B. "+4.9
BAcc-Punkte gegenueber Default" fuer `openml-credit-g`) stehen in
`BACKLOG.md`, `PAPER_DRAFT.md` und `joss/paper.md` als feste Zahlen.
Ein Skript wie `outer_workflow_evaluation_template.R` (Protokoll v1)
"aufzuraeumen" oder "zu verbessern" ist eine plausible, gut gemeinte
Aenderung - genau das wuerde aber alle bereits berichteten
v1-Ergebnisse im Nachhinein unvergleichbar bzw. falsch machen, ohne
dass das an den Zahlen selbst sichtbar waere.

## Entscheidung

Ein Benchmark-Protokoll (Arme, Seeds, Fold-Zahl, Suchraeume) wird
NIEMALS nachtraeglich in der bestehenden Version veraendert, sobald
mindestens ein Ergebnis damit berichtet wurde. Eine Verbesserung/
Erweiterung bekommt IMMER eine neue Versionsnummer (`_v2`, `_v3`, ...,
eigene Datei, eigener Abschnitt in `BENCHMARK_PROTOCOL.md`). Die alte
Version bleibt unveraendert lauffaehig und referenzierbar.

## Begruendung

- **Vergleichbarkeit ueber Datensaetze/Sessions hinweg** ist der
  explizit genannte Zweck von `BENCHMARK_PROTOCOL.md` selbst - ohne
  Versionierung wuerde jede stille Aenderung die Vergleichbarkeit
  bereits berichteter Zahlen zerstoeren, ohne dass das an der Zahl
  selbst erkennbar waere (der Datensatz-Score aendert sich nicht durch
  die Skript-Aenderung, aber seine BEDEUTUNG/Vergleichsgrundlage tut es).
- **Gelebte Praxis, jetzt formalisiert**: die Session, die Protokoll v2
  einfuehrte, hat bewusst `outer_workflow_evaluation_v2_fair_baselines.R`
  als NEUE Datei angelegt statt `outer_workflow_evaluation_template.R`
  zu editieren - genauso beim Uebergang zu v3
  (`outer_workflow_evaluation_v3_level2.R`). Diese ADR macht das
  Muster explizit statt es nur implizit fortzusetzen.
- **Ausnahme, bereits gelebt**: ein reiner Bugfix, der KEINE
  Ergebnisse aendert (z.B. die `LEVEL2_TUNING_EVALS`-Env-Var-
  Parametrisierung in v3, Default bleibt 10 - identisch zum
  eingefrorenen Verhalten), darf die bestehende Datei in-place aendern,
  SOLANGE das Default-Verhalten nachweislich unveraendert bleibt (siehe
  Commit-Historie/Tests dieser Aenderung als Beleg-Muster).

## Alternativen erwogen

- **Protokolle als "living documents" fortlaufend verbessern** -
  verworfen: macht jede berichtete Zahl implizit zeitabhaengig von
  "welcher Stand des Skripts zum Zeitpunkt X" - genau die Unklarheit,
  die `BENCHMARK_PROTOCOL.md` selbst verhindern soll.
- **Alte Protokoll-Versionen nach Ablauf loeschen/archivieren** -
  verworfen: wuerde die Nachvollziehbarkeit bereits berichteter
  Ergebnisse (z.B. Phase C, ausschliesslich Protokoll v1) im Nachhinein
  erschweren. Alte Versionen bleiben aktiv im Repo, auch wenn neuere
  Versionen existieren.
