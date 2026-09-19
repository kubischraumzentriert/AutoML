# statusanker/

Session-Handoff-Dateien ("Statusanker") - fassen am Ende/während einer
Arbeitssession zusammen, was seit dem letzten Anker passiert ist, damit
eine neue Session (anderes Kontextfenster, anderer Agent) dort anknüpfen
kann, ohne den vollen Git-Verlauf/die Commit-Historie selbst
rekonstruieren zu müssen.

## Welche Datei ist aktuell?

**Die mit dem jüngsten Datum im Dateinamen** (`SESSION_HANDOFF_YYYY-MM-DD.md`).
Alle anderen sind Archiv - bewusst unverändert liegen gelassen, nicht
gelöscht (jede Datei bleibt die vollständige, in sich konsistente
Historie ihres Zeitraums).

## Warum mehrere Dateien statt einer durchgehenden?

**Rotation bei ~7-20 Tagen bzw. wenn eine Datei unhandlich gross wird**
(z.B. wuchs `SESSION_HANDOFF_2026-08-29.md` auf 20 Tage/181 KB/66
Aktualisierungs-Einträge, bevor die Rotation zum aktuellen Anker
erfolgte - 8-25x grösser als jede vorherige Datei und dadurch selbst
schwer navigierbar). Eine neue Anker-Datei beginnt jeweils mit einer
KOMPRIMIERTEN Zusammenfassung des Endstands der vorherigen Datei
("Zusammenfassung des alten Ankers"), bevor sie mit eigenen, neuen,
vollständig ausformulierten Aktualisierungs-Einträgen weitermacht - so
bleibt die Kette lückenlos nachvollziehbar, ohne dass jede neue Datei bei
Null anfängt.

## Format einer Aktualisierung

Jeder Eintrag ("N. Aktualisierung") beschreibt: die auslösende
Nutzeranfrage, den Fund/die Änderung, was verifiziert wurde (Tests/CI),
und den resultierenden Commit-Hash. Ziel ist Nachvollziehbarkeit, nicht
Kürze - ein Eintrag darf so lang sein, wie er braucht, um eine spätere
Session ohne Rückfragen weiterarbeiten zu lassen.

## Verwandt

- `BACKLOG.md` (Repo-Root) - der inhaltliche Fortschritt je Backlog-Punkt,
  eher fachlich/dauerhaft als chronologisch/session-bezogen wie hier.
- `docs/research/`, `docs/reference/` - vertiefende Dokumentation, auf die
  einzelne Statusanker-Einträge oft verweisen, statt Inhalte zu duplizieren.
