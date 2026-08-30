# 009: Evidence Registry und `SYSTEMATIC_EVALUATION.md` bewusst als zwei getrennte Quellen, keine vollstaendige Migration

Status: Accepted
Datum: 2026-08-30 (Entscheidung getroffen 2026-08-29 im Rahmen von P2,
2. Haelfte - "Evidence Registry finalisieren", hier erstmals als
eigenstaendige ADR fixiert)

## Kontext

`SYSTEMATIC_EVALUATION.md` ist eine handgepflegte Projekt-x-Modul-
Ergebnistabelle fuer die 9 urspruenglichen Trust-/Diagnose-Module
(Leak-Audit, Adversarial Validation, Split-Size-Sensitivity, ...) mit
dichtem redaktionellem Material (Fussnoten, Korrekturvermerke,
Spaltenaufloesungs-Historie, ca. 770 Zeilen). Die Evidence Registry
(`evidence_registry.R` + `generate_systematic_evaluation.R`) kann seit
Phase D (2026-08-28) eine AEHNLICHE Tabelle automatisch aus einer
strukturierten `evidence`-DB-Tabelle erzeugen
(`SYSTEMATIC_EVALUATION_GENERATED.md`). Der urspruengliche Plan (aus
einer externen Bewertung) sah vor, die manuelle Pflege langfristig
komplett durch die generierte Tabelle zu ersetzen. Ein kuenftiger Agent
koennte diese "Migration abschliessen" wollen, sobald beide Tabellen
inhaltlich aehnlich aussehen.

## Entscheidung

Die beiden Quellen bleiben DAUERHAFT getrennt, mit fester
Arbeitsteilung statt vollstaendiger Migration:

- Die 9 urspruenglichen Trust-/Diagnose-Module bleiben MASSGEBLICH in
  `SYSTEMATIC_EVALUATION.md` (handgepflegt).
- Alles rund um `outer_workflow_evaluation` (Phase C, externes
  Benchmark-Set, faire Baselines, Level-2-Prototyp und alle
  Research-Aspect-Nachtraege) wird AUSSCHLIESSLICH ueber die generierte
  `SYSTEMATIC_EVALUATION_GENERATED.md` gepflegt, NICHT zusaetzlich
  manuell in `SYSTEMATIC_EVALUATION.md` nachgetragen.

## Begruendung

- **Der redaktionelle Mehrwert von `SYSTEMATIC_EVALUATION.md` ist nicht
  verlustfrei automatisierbar**: die vollstaendige Herleitung jeder
  Spaltenaufloesung (z.B. warum eine `?`-Zelle am 2026-08-15 auf `—`
  gesetzt wurde, mit Fallzahlen/Ausschlussgruenden), Korrekturvermerke
  (z.B. die IQR-Nenner-Korrektur), und eine "Was diese erste Fassung
  zeigt"-Diskussion passen strukturell nicht in eine reine
  Projekt-x-Modul-Pivot-Tabelle, wie sie die Evidence Registry erzeugt.
  Eine erzwungene Migration in `evid_notes`-Freitextfelder waere entweder
  unpraktikabel lang oder wuerde den Mehrwert kappen.
- **Fuer neue, schnell wachsende Inhalte (Outer-Evaluation) ist die
  generierte Tabelle dagegen klar ueberlegen**: sie war zum Zeitpunkt
  dieser Entscheidung bereits AKTUELLER als die manuelle Datei (Phase-C-
  Funde fehlten dort), und jede neue P1/P2/Research-Aspect-Erkenntnis
  kommt automatisch hinzu, sobald sie per `db_log_evidence()` geloggt
  wird - keine doppelte manuelle Pflege noetig.
- **Explizit als Kompromiss dokumentiert** (siehe `BACKLOG.md`, "P2 -
  Status (2. Haelfte)"): weder "sofort abschaffen" (haette
  redaktionelles Material vernichtet) noch "fuer immer doppelt pflegen"
  (unnoetiger Mehraufwand fuer die neuen, schnell wachsenden
  Outer-Evaluation-Ergebnisse).

## Alternativen erwogen

- **Vollstaendige Migration des redaktionellen Materials in
  `evid_notes`-Freitextfelder, dann `SYSTEMATIC_EVALUATION.md`
  loeschen** - verworfen: hoher einmaliger Aufwand, tatsaechlicher
  Informationsverlust bei laengeren Diskussionsabschnitten, die keine
  einzelne Zelle sind.
- **Weiter beide Tabellen manuell UND generiert parallel pflegen ohne
  klare Arbeitsteilung** - verworfen: fuehrt unweigerlich zu Drift
  zwischen beiden (genau das Muster, das die 2026-08-30-Bewertung als
  "Dokumentationsdrift" kritisierte, bevor diese Klarstellung erfolgte).
