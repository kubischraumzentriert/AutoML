---
name: setup-r-ci-tests
description: Richtet GitHub-Actions-CI fuer ein mlr3-basiertes R-Projekt ein (r-lib/actions/setup-r-dependencies), oder debuggt einen fehlschlagenden/haengenden CI-Lauf desselben. Nutzen, wenn der Nutzer "CI einrichten"/"Tests automatisieren"/"GitHub Action fuer Tests" sagt, oder wenn ein bestehender r-lib/actions/setup-r-dependencies-Workflow mit "Can't find package"/"Can't install dependency" fehlschlaegt oder in der Dependency-Installation haengt.
---

# R-CI mit mlr3extralearners einrichten/debuggen

Entstanden aus einem 5-Iterationen-Debugging in `MLR3_Regression`
(2026-09-16, `65c111f`..`57549d3`) beim Nachbau der bereits laufenden
CI aus `MLR3_Classifikation`. Alle 5 Fallstricke unten wurden dabei
NACHEINANDER echt getroffen, nicht vorab antizipiert - dieser Skill
soll das beim naechsten Mal auf einen Durchlauf verkuerzen.

## Checkliste VOR dem ersten Push (spart alle 5 Runden unten)

1. **`DESCRIPTION`** als reines CI-Dependency-Manifest anlegen (kein
   echtes Paket - `Package:`/`Title:`/`Version:`/`License:` reichen),
   `Imports:` mit allen tatsaechlich gebrauchten Paketen.
2. **`.Rprofile`** mit `options(repos = c(mlrorg = "https://mlr-org.r-universe.dev", CRAN = ...))`
   anlegen, wenn `mlr3extralearners` gebraucht wird (siehe Stolperstein 1).
   Bereits vorhandenes Muster: `MLR3_Classifikation/.Rprofile` - 1:1
   kopierbar.
3. Im Workflow-`dependencies`-Input NICHT den Action-Default ("all")
   lassen, sondern `dependencies: 'c("Depends", "Imports", "LinkingTo")'`
   setzen, sobald `mlr3extralearners` oder ein anderes Paket mit grosser
   Suggests-Liste beteiligt ist (siehe Stolperstein 2+3).
4. **Vor** dem Festlegen der `extra-packages`-Liste alle `test_*.R`/
   Kern-Skripte nach `lrn("regr\.[a-z]+"` / `lrn("classif\.[a-z]+"`
   durchsuchen (`grep -hoE 'lrn\("[a-z0-9_.]+"' *.R | sort -u`) - jede
   dort referenzierte Lerner-ID braucht ihr Backend-Paket explizit in
   `extra-packages` (z.B. `regr.lightgbm` -> `lightgbm`, `regr.ranger`
   -> `ranger`), auch wenn keine Datei ein explizites `library(...)`
   dafuer hat (siehe Stolperstein 4).
5. `paths:`-Trigger des Workflows um `DESCRIPTION` UND `.Rprofile`
   ergaenzen, nicht nur `**.R` - sonst greift die Action bei einer
   reinen Dependency-Aenderung nicht.

## Die 5 Stolpersteine (falls die Checkliste nicht vorab beachtet wurde)

1. **`Additional_repositories` in `DESCRIPTION` wird von `pak` NICHT
   automatisch gelesen**, obwohl das die per Doku "richtige" Stelle
   waere. `mlr3extralearners` liegt nicht auf CRAN, nur im mlr-org
   R-Universe - ohne Fix schlaegt die Installation fehl mit
   `Can't find package called mlr3extralearners`, UND `pak::repo_status()`
   listet das r-universe-Repo dann nachweislich NICHT (pruefbar im
   CI-Log unter "Repo status"). Fix: `.Rprofile` (Punkt 2 oben) - pak
   liest `getOption("repos")`, und `r-lib/actions/setup-r-dependencies@v2`
   startet dieselbe R-Session im Repo-Root, liest `.Rprofile` also
   automatisch mit ein (gilt genauso fuer lokale `Rscript`-Laeufe).
2. **Der Action-Default `dependencies: "all"` zieht ALLE `Suggests`**,
   nicht nur `Imports`/`Depends`. `mlr3extralearners`s Suggests-Liste
   deckt dutzende optionale Lerner-Backends ab (catboost, xgboost,
   keras, ...) - selbst wenn keine Zeile im Repo sie braucht, installiert
   die Action sie alle mit. Symptom: die Dependency-Installation haengt
   scheinbar fest (>10-15 Minuten ohne Fehler und ohne Fortschritt in
   der Log-Ausgabe). NICHT vorschnell als "haengt/kaputt" werten - erst
   `dependencies` einschraenken (Punkt 3 oben), dann neu versuchen.
3. **Syntax-Falle bei der `dependencies`-Eingabe**: die Action generiert
   intern `dependencies = c(needs, (<dein Wert>))` - ein roher
   Komma-String wie `'"Depends", "Imports"'` ergibt dann ungueltiges R
   (`c(needs, ("Depends", "Imports"))`, Parse-Fehler "unexpected ','").
   Richtig: den Wert selbst schon als `c(...)`-Ausdruck uebergeben,
   also `dependencies: 'c("Depends", "Imports", "LinkingTo")'`.
4. **Implizite Lerner-Backend-Pakete werden von keinem `library()`-Grep
   erfasst** - `mlr3::lrn("regr.lightgbm")` etc. laedt das Backend-Paket
   erst zur Laufzeit ueber die `mlr3extralearners`-Registrierung, nicht
   ueber eine sichtbare `library(lightgbm)`-Zeile im Testcode. Ein Grep
   nach `library(...)` allein reicht deshalb NICHT, um die vollstaendige
   `extra-packages`-Liste zu ermitteln - immer zusaetzlich nach
   `lrn("...")`-Aufrufen suchen (Punkt 4 der Checkliste oben).
5. **Ein erster, kalter CI-Lauf OHNE Cache-Treffer kann legitim
   10-15 Minuten dauern** (Paketkompilierung, kein Haenger) - erst nach
   deutlich laengerer Wartezeit als bei einem warmen Cache von einem
   echten Problem ausgehen. Bei echtem Verdacht: `gh run view <id> --log`
   NACH Abschluss (waehrend des Laufs liefert `--log` keine Ausgabe,
   `gh run view --job <id>` zeigt aber den aktuellen Schritt) statt
   den Lauf vorschnell abzubrechen.

## Verifikation

`gh run list --repo <owner>/<repo> --limit 1` nach jedem Push, dann
`gh run view <id> --repo ... --json status,conclusion` pollen (kein
`--log` waehrend `in_progress`). Bei `failure`: `gh run view <id> --log
> /tmp/log.txt` und gezielt nach `Error:`/`Can't find`/`Can't install`
grep-en statt das komplette Log zu lesen.
