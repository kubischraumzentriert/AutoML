# Environment-Referenzpfad

P2.3 aus ChatGPTs korrigiertem Plan: "mindestens einen belastbaren
Referenzpfad dokumentieren ... keine erzwungene vollstaendige
Windows-`renv`-Migration." Diese Datei dokumentiert den bereits
BESTEHENDEN, funktionierenden Referenzpfad - `.github/workflows/
ci-smoke-test.yml` - der genau das leistet, was der Plan beispielhaft
skizziert (`Ubuntu / R-Version X / restore aus einem Manifest / Unit
Tests / synthetic smoke fixture`), nur mit `DESCRIPTION` + `pak`
(via `r-lib/actions/setup-r-dependencies`) statt `renv::restore()`. Es
wurde bewusst NICHTS an CI oder Skripten geaendert - reine
Dokumentation eines bereits laufenden, verifizierten Pfads.

## Der belastbare Referenzpfad (verifiziert, siehe Nachweis unten)

| Schritt | Konkret |
|---|---|
| Betriebssystem | `ubuntu-latest` (GitHub-Actions-Runner-Image `ubuntu-24.04`) |
| R-Version | `r-version: release` (r-lib/actions/setup-r@v2) - zum Zeitpunkt der letzten verifizierten Ausfuehrung R 4.6.1 (2026-06-24). **Bewusst nicht auf eine feste Versionsnummer gepinnt** (siehe Abschnitt "Warum `release` statt einer festen Version" unten) |
| Abhaengigkeiten | `r-lib/actions/setup-r-dependencies@v2`, liest `DESCRIPTION`s `Imports:`-Liste + `Additional_repositories: https://mlr-org.r-universe.dev` (fuer `mlr3extralearners`, nicht auf CRAN). Funktional aequivalent zu `renv::restore()` - deklarativ, aus einem versionierten Manifest, nicht ad hoc `install.packages()` |
| Unit Tests | `Rscript tests/testthat.R` (eigener Runner, siehe Kopfkommentar dort - `testthat::test_check()` funktioniert nicht, da dieses Repo kein installierbares Paket ist) |
| Synthetic Smoke Fixture | `ci_smoke_test/generate_fixture.R` erzeugt einen kleinen synthetischen Datensatz, gegen den die numerierten Kernskripte (015-136, siehe `ci-smoke-test.yml`) end-to-end durchlaufen - kein Korrektheitstest (keine Score-Schwellenwerte), nur "laeuft es noch fehlerfrei durch" |

Beide Jobs (`unit-tests`, `smoke-test`) laufen bei JEDEM Push, der
`**.R`/`DESCRIPTION`/`.Rprofile`/die Workflow-Datei selbst beruehrt (siehe
`ci-smoke-test.yml`s `on.push.paths`) - der Pfad wird also nicht nur
einmalig dokumentiert, sondern laufend tatsaechlich ausgefuehrt und
verifiziert (z.B. `gh run list --repo kubischraumzentriert/AutoML`).

## Warum `release` statt einer festen Version

Eine feste R-Versionsnummer (z.B. `4.5.2`) waere zwar noch etwas
belastbarer im strengen Sinn ("exakt reproduzierbar"), wuerde aber
bedeuten, dass die CI irgendwann gegen eine veraltete R-Version laeuft,
waehrend `r-lib/actions/setup-r-dependencies` seinerseits gegen aktuelle
CRAN-Binaries aufloest - ein zunehmendes Risiko fuer Inkompatibilitaeten
zwischen einer eingefrorenen R-Version und sich weiterentwickelnden
Paketen (das Gegenteil von "belastbar"). `release` haelt CI und
Paketversionen synchron zueinander, auf Kosten einer 100%igen
Bit-fuer-Bit-Reproduzierbarkeit ueber die Zeit. Fuer dieses Repo (ein
AutoML-TEMPLATE, kein zu einem festen Zeitpunkt eingefrorenes
Produktionsartefakt) ist das der sinnvollere Kompromiss.

## Warum `DESCRIPTION`+`pak` statt `renv::restore()`

Der Plan nennt `renv::restore()` nur als BEISPIEL fuer "aus einem
versionierten Manifest installieren", nicht als zwingende Vorgabe. Dieses
Repo hat bereits ein funktionierendes Aequivalent: `DESCRIPTION`s
`Imports:`-Liste (siehe Datei-Kopfkommentar: "existiert ausschliesslich,
damit r-lib/actions/setup-r-dependencies die benoetigten Pakete
installieren und cachen kann"). Eine `renv`-Migration wuerde eine
zusaetzliche Lockfile-Pflege-Last einfuehren, ohne einen Referenzpfad zu
schaffen, den es nicht bereits gibt - der Plan schliesst genau das
("keine erzwungene vollstaendige Windows-`renv`-Migration") explizit aus.

## Was dieser Referenzpfad NICHT ist

Der taegliche Windows-Arbeitsplatz dieses Projekts (`Rscript.exe` unter
`C:\Users\HP\Programme\R\R-4.5.2\bin\`, siehe Claude-Memory
`project_r_windows_env.md`) bleibt bewusst UNGEPINNT und ausserhalb dieses
Referenzpfads - der Plan verlangt ausdruecklich KEINE vollstaendige
Windows-`renv`-Migration. Der Ubuntu-CI-Pfad ist der eine dokumentierte,
belastbare Referenzpunkt ("funktioniert dieses Repo unabhaengig von
diesem einen Windows-Rechner mit dieser einen R-Installation?"), nicht
ein Ersatz fuer die lokale Windows-Entwicklungsumgebung.

## Nachweis (verifiziert 2026-08-27)

CI-Lauf `33044016901` (P2.1-Push), beide Jobs `success`:
- `unit-tests`: `Rscript tests/testthat.R` - alle 15 Testdateien gruen.
- `smoke-test`: `ubuntu-24.04`, R 4.6.1 (2026-06-24), alle 15 Skript-
  Schritte (015 bis 136) erfolgreich gegen die synthetische Fixture.
