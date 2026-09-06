# 003: Template-Aenderungen erst nach ≥2-Projekt-Bestaetigung oder Null-Ergebnis-Beleg backporten

Status: Accepted
Datum: 2026-08-08 (gelebte Praxis seit den ersten Konfirmationsprojekten,
hier erstmals als eigenstaendige Entscheidung fixiert)

## Kontext

Reibung, die beim Anwenden des Templates auf ein neues Projekt auftritt, ist
ein Signal, das Template zu verbessern - aber nicht jede projektspezifische
Loesung ist automatisch ein gutes generisches Template-Feature. Ohne eine
klare Regel droht das Template, sich an die Eigenheiten eines einzelnen
Projekts anzupassen (Overfitting des Templates selbst).

## Entscheidung

Eine Aenderung/ein neues Modul wird erst dann ins Template zurueckgefuehrt
(backported), wenn eine der beiden Bedingungen erfuellt ist:

1. **An mindestens ZWEI unabhaengigen Projekten bestaetigt** (nicht nur
   einmal angewendet, sondern der Nutzen/das Verhalten an einem zweiten,
   andersartigen Projekt reproduziert oder zumindest ueberprueft).
2. **Nachweislich ein No-op** - regressionsgetestet gegen das
   Template-eigene Projekt, keine Verschlechterung, aber auch kein
   Nachweis noetig, weil die Aenderung strukturell/defensiv ist (z.B. ein
   Guard, der bei sauberen Daten korrekt still bleibt).

## Begruendung

- Verhindert, dass Zufallsbefunde eines einzelnen, moeglicherweise
  untypischen Projekts als generische Wahrheit ins Template einsickern.
- Ein Kandidat, der nur an einem Projekt belegt ist, wandert stattdessen
  als offener Punkt in `BACKLOG.md`/`TARGETS.md` und wartet auf die zweite
  Bestaetigung, statt verworfen oder blind uebernommen zu werden.

## Konsequenz: gilt NICHT automatisch templateuebergreifend

Klassifikations- und Regressions-Template sind zwei unabhaengige Repos.
Eine Bestaetigung in EINEM Template zaehlt nicht automatisch als
Bestaetigung fuers ANDERE, selbst wenn der zugrundeliegende Mechanismus
identisch erscheint (Beispiel: die Kaggle-R-GPU-Sackgasse aus ADR 002 ist
mechanismus-identisch fuer beide Aufgabentypen, aber die Regressionsseite
hat trotzdem noch keine eigene, unabhaengige Bestaetigung und weist das in
`NEURAL_DEPLOY.md` explizit so aus statt es stillschweigend zu unterstellen).

Wiederkehrende Frage bei Aenderungen: **"Was uebertragen wir von einem
Template zum anderen, bezueglich ihrer Gemeinsamkeit?"** - Antwort dieser
ADR: der MECHANISMUS/die BEGRUENDUNG darf sofort als Hypothese uebernommen
werden (spart Doppelarbeit beim Nachdenken), aber die KONKRETE BESTAETIGUNG
(Zahlen, Testlauf) muss je Template eigenstaendig erfolgen, bevor eine
Aenderung dort als "Accepted"/erledigt gilt.

## Erweiterung: gilt auch fuer didaktische Dokumentation (DIDAKTIK_*.md)

Seit 2026-08-14 gilt dieselbe Regel auch fuer Theorie-/Didaktik-Dokumente,
nicht nur Code. Konvention (etabliert in `ML_Learning\SubjektDatensatz\
DIDAKTIK_GROUP_CV.md`, einem separaten, rein lokalen Repo ausserhalb der
beiden Templates - nicht zu verwechseln mit `REFERENZ_*.md` hier im
Template): pro **neuer Technik/Theorie** (nicht pro Projekt) entsteht im
jeweiligen `ML_Learning`-Projekt eine eigene `DIDAKTIK_<THEMA>.md` mit
einem Status-Vermerk ("1 Projekt, noch nicht verallgemeinert"). Erst wenn
eine zweite, unabhaengige `DIDAKTIK_*.md` auf dieselbe zugrundeliegende
Theorie trifft, wird die Schnittmenge extrahiert und als
`REFERENZ_*.md` in das jeweilige Template zurueckgefuehrt - die
projektgebundenen `DIDAKTIK_*.md`-Dokumente bleiben als konkrete Beispiele
lokal stehen, werden nicht geloescht.

## Erweiterung: Eskalationsklausel bei uneinheitlichem Befund (2026-09-06)

Anlass: ein Ensemble-Pool-Diversitaets-Pilot (siehe `BACKLOG.md`,
2026-09-05/06) zeigte an den ersten 2 kleinen Testprojekten einen
konsistent POSITIVEN Effekt (+0.71/+1.76 BAcc-Prozentpunkte) - das
erfuellte formal die ADR-003-Mindestschwelle, fuehrte aber zu einer
voreiligen Faustregel ("Ensemble hilft bei kleinen Datensaetzen"). Bei
Erweiterung auf 4 Projekte kippte das Bild auf 2 positiv/2 negativ; erst
bei 10 Projekten ergab sich ein stabiles Bild (3 positiv/3 negativ/4
kein Unterschied = kein systematischer Effekt). **Selbst n=4 war hier
noch nicht ausreichend fuer eine verlaessliche Aussage.**

**Ergaenzende Regel**: die 2-Projekte-Mindestschwelle aus obiger
Entscheidung bleibt die FORMALE Untergrenze, ABER sie ist nur dann
ausreichend, wenn die 2 Bestaetigungen KONSISTENT sind (gleiches
Vorzeichen, vergleichbare Groessenordnung) UND die zugrundeliegende
Groesse nicht offensichtlich rausch-/streuungsanfaellig ist (kleine
Stichproben, Benchmark-Deltas mit bekannt hoher Varianz). Ist eines
davon nicht gegeben - insbesondere bei einem knappen/uneindeutigen
Ergebnis oder wenn die Fragestellung selbst eine Rausch-anfaellige
Messung ist (z.B. ein Score-Unterschied auf einem kleinen Bestaetigungs-
Split) - gilt NICHT automatisch "Schwelle erfuellt", sondern es wird auf
n>=4 (und im Zweifel weiter, bis das Ergebnis stabil bleibt oder als
"kein verlaesslicher Effekt" erkennbar wird) erweitert, BEVOR eine
Faustregel/ein Backport formuliert wird. Es gibt bewusst keine feste
Ziel-Zahl (kein starres "n=4 reicht immer") - massgeblich ist die
STABILITAET des Befundes ueber wiederholte Erweiterung hinweg, nicht
eine bestimmte Projektanzahl.

**Rueckwirkende Pruefung (2026-09-06)**: BACKLOG.md wurde nach allen
bisherigen "ADR-003"/"2 Projekte"/"2 unabhaengige"-Eintraegen durchsucht.
Ergebnis: keine weiteren Faelle gefunden, die eine Nachpruefung
brauchen - Decision-Stability (n=2, widerspruechlicher Befund) wurde
korrekt NICHT backported und explizit als noch offen markiert (spaeter
auf n=6->10->15 erweitert, Nullbefund bestaetigt); Hard-Split-Stresstest
(n=2 zunaechst) wurde ebenfalls korrekt erst bei n=7 als Pipeline-Skript
backported, nicht schon bei n=2. Der Ensemble-Pool-Fehltritt scheint ein
Einzelfall zu sein, kein systematisches Muster in der bisherigen
Historie.

## Alternativen erwogen

- **Sofortiges Backporten nach jedem einzelnen Erfolg** - verworfen, hoechstes
  Overfitting-Risiko.
- **Backporten erst nach sehr vielen (z.B. 5+) Projekten** - verworfen, zu
  langsam, wuerde echte Verbesserungen unnoetig lange zurueckhalten. Zwei
  Projekte sind der dokumentierte, in der Praxis bewaehrte Kompromiss.
