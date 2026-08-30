# 007: Flaches Skript-Template statt eines installierbaren R-Pakets

Status: Accepted
Datum: 2026-08-30 (gelebte Praxis seit Projektbeginn 2026-07-07, hier
erstmals als eigenstaendige Entscheidung fixiert - Anlass: explizit
formuliert waehrend der JOSS-Einreichungsvorbereitung, `joss/paper.md`
Abschnitt "Software Design")

## Kontext

Das Template besteht aus 99 nummerierten R-Skripten im Repo-Root (z.B.
`015_target_leak_audit.R`, `090_ranger_tuning.R`), nicht aus einem
installierbaren R-Paket mit `DESCRIPTION`/`NAMESPACE`/exportierten
Funktionen. Fuer ein Projekt, das inzwischen JOSS-Reife anstrebt und
dessen Code-Basis stetig waechst, ist das eine ungewoehnliche, auf den
ersten Blick "unfertig" wirkende Struktur - ein Refactoring zu einem
echten R-Paket waere eine plausible, gut gemeinte "Aufraeum"-Aktion
fuer einen kuenftigen Agenten oder Mitwirkenden.

## Entscheidung

Das Template bleibt bewusst eine flache Sammlung nummerierter Skripte.
KEIN Umbau zu einem installierbaren R-Paket (kein `DESCRIPTION`, keine
`NAMESPACE`/`R/`-Paketstruktur, keine `devtools::install()`-Nutzung als
primaerer Distributionsweg).

## Begruendung

- **Kernzweck ist Kopieren+Anpassen fuer einen neuen, zeitkritischen
  Wettbewerb** (Kaggle/Zindi/DrivenData/OpenML), nicht Installation als
  Abhaengigkeit in fremden Projekten. Ein Nutzer soll ein einzelnes
  Skript (z.B. `015_target_leak_audit.R`) kopieren und in einer neuen
  Projektstruktur direkt lauffaehig anpassen koennen, ohne zuerst ein
  Paket zu bauen/installieren/laden.
- **Numerierung als Ablaufreihenfolge** (`005`-`157`) ist selbsterklaerend
  und dokumentiert implizit die Skript-Abhaengigkeiten - eine formale
  Paketstruktur wuerde diese Ordnung durch Namespace-Exporte verdecken.
- **Explizit im Software-Design-Abschnitt der JOSS-Einreichung
  begruendet** (`joss/paper.md`): "a trade-off made explicitly to keep
  the barrier to copying and adapting a single script for a new,
  time-pressured competition low, at the cost of the discoverability an
  installable package/API would give."

## Bewusst in Kauf genommener Nachteil

Keine automatische API-Dokumentation (`?function_name`), keine
`R CMD check`-Garantien, keine einfache `install.packages()`-
Distribution. Das ist ein akzeptierter Trade-off, kein uebersehener
Mangel - siehe "Alternativen erwogen" unten.

## Alternativen erwogen

- **Vollstaendiger Umbau zu einem R-Paket** - verworfen: wuerde den
  "ein Skript kopieren und sofort anpassen"-Workflow durch einen
  "Paket installieren, Funktion importieren, dann anpassen"-Workflow
  ersetzen - fuer den Kaggle-/Zindi-Anwendungsfall (schneller,
  wettbewerbsspezifischer Umbau) ein Nachteil, kein Vorteil.
- **Hybrid: Kernfunktionen als Paket, Orchestrierungs-Skripte flach** -
  verworfen als verfrueht: wuerde eine staerkere API-Stabilitaets-
  Verpflichtung (Paket-Versionierung, Breaking-Change-Disziplin)
  einfuehren, die dem aktuellen, noch schnell iterierenden Reifegrad
  des Templates nicht entspricht. Bleibt eine moegliche spaetere
  Option, falls externe Adoption (P3 der 2026-08-30-Bewertung) das
  rechtfertigt - siehe `JOSS_TECHNIQUE_WATCH.md`.
