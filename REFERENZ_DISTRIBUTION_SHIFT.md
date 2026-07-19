# Referenz: Umgang mit Train/Test-Distribution-Shift

Playbook für Wettbewerbe/Projekte, in denen sich Train und Test systematisch
unterscheiden (**Covariate-Shift**). Entstanden aus dem GeoAI-Aquaculture-Projekt
(Zindi, 2026-07); dort steht die volle Herleitung in
`../geoai-aquaculture-pond-identification-challenge/{README,TEMPLATE_FRICTION}.md`.

Dies ist eine **Referenz**, keine Template-Code-Änderung. Die hier genutzten
Bausteine (`masking.R`, ESS-Check) leben bislang nur im Aquaculture-Projekt und
sind Rückführungs-Kandidaten, sobald ein **zweiter** Shift-Fall auftritt.

---

## 0. Wann greift dieses Playbook?

Verdachtssignale auf einen Shift:
- Die Wettbewerbsseite/Discussion erwähnt einen „neuen Testset", ein Leak-Fix,
  andere Region/Zeit für Test.
- Train und Test haben sichtbar andere Missingness- oder Werteverteilungen.
- Public-LB liegt weit unter dem CV-Score (nachdem triviale Fehler ausgeschlossen).

Wenn ja: **erst diagnostizieren, dann handeln.** Nicht sofort Modelle tunen.

---

## 1. Diagnose — gestufte Adversarial Validation

Ein Klassifikator, der `is_test` (Train=0/Test=1) trennt. AUC ~0.5 = kein Shift;
AUC ≫ 0.5 = Shift. Gestuft, um die Ursache zu **zerlegen** (Vorlage: Aquaculture
`115`–`117`):

1. **Roh, inkl. Missingness** → sagt nur „irgendein Shift".
2. **Missing-robuste Aggregate** (z. B. Mittel je Feature-Gruppe über vorhandene
   Teile) → trennt Missingness von Werte-Shift.
3. **Gleiche Achse, kein Missingness** (im Aquaculture-Fall: pro Monat, nur
   beobachtete Zeilen) → isoliert einen *echten* Werte-Shift von Kompositions-
   effekten. Bleibt der AUC hier hoch, ist es ein harter Covariate-Shift.

**Label-freies Frühwarnsignal**: die vorhergesagte Positiv-Rate auf dem
*ungelabelten* Test von der Train-Basisrate weg = Shift-Symptom, vor jeder
Submission prüfbar.

---

## 2. Entscheidung — lohnt Importance-Weighting? (ESS-Gate)

Der Standard-Reflex ist Reweighting: Adversarial-`p = P(test-artig)` →
`w = p/(1−p)` → in die Verlustfunktion (`Σ w·loss`; in mlr3 Task-Spaltenrolle
`weights_learner`; LightGBM/ranger/glmnet/xgboost tragen es nativ).

**Aber nur bei Überlappung.** Vorher die **effektive Stichprobengröße** messen
(OOF-Gewichte): `ESS = (Σw)² / Σ(w²)`. Ist `ESS/n` klein (≈ < 0.1), kollabieren
die Gewichte auf wenige Zeilen → Reweighting hochvariabel/nutzlos.

> **Ein nahezu perfekter Adversarial-AUC (~0.95+) ist das Lehrbuch-Signal, dass
> Reweighting NICHT hilft** — Train und Test sind fast disjunkt, es gibt keinen
> gemeinsamen Träger, auf den man umgewichten könnte. (Aquaculture: ESS 2.6 %.)

**Falls man doch gewichtet — der Balance-Check (Classifier Two-Sample Test).**
Nach dem Gewichten die Adversarial Validation erneut fahren, jetzt auf dem
**gewichteten** Train vs. Test: `AUC → 0.5` (bzw. gewichtete standardisierte
Mittelwertdifferenzen → 0) bestätigt, dass die Gewichtung die Verteilungen
angeglichen hat. Das ist ein **Classifier Two-Sample Test (C2ST)** bzw. die
**Covariate-Balance-Diagnostik** aus der Propensity-Score-/IPW-Methodik
(`P(test|x)` ist ein Propensity-Score; Adversarial Validation *ist* ein C2ST).

**Aber: Balance ≠ Präzision — zwei verschiedene Diagnosen.**

| Diagnose | prüft | Ergebnis bei uns |
|---|---|---|
| **ESS** | Varianz / Überlappung | 2.6 % → zu wenig effektive Daten |
| **Balance-Check (C2ST)** | Bias / Matching | nur *nach* Gewichtung sinnvoll |

Selbst ein perfekter Balance-AUC von 0.5 lässt das ESS-Problem bestehen: man wäre
**„balanciert, aber nutzlos"** (Verteilungen angeglichen, aber auf ~47 effektive
Punkte gestützt → riesige Varianz). Und bei fast fehlender Überlappung erreicht
der Check die 0.5 gar nicht (gewichtetes Train = wenige Spitzen ≠ breite
Test-Verteilung). → **ESS ist der billigere Vorab-Filter; sie entscheidet den
Fall schon, bevor man die Gewichtungs-+Balance-Schleife durchläuft.**

---

## 3. Handeln — Invarianz statt Korrektur

Wenn Reweighting ausfällt: die **Repräsentation robust gegen den Shift** machen,
statt ihn zu korrigieren.

- **Gain-invariante Features**: normierte Differenzen `(a−b)/(a+b)` und
  Verhältnisse/Log-Verhältnisse kürzen einen gemeinsamen multiplikativen Faktor
  (Beleuchtung/Sensor/Skalierung) heraus. Absolute Werte tun das nicht. (Im
  Aquaculture-Fall: Spektral-Indizes statt Rohbänder.)
- **Vorsicht bei Linearkombinationen mit festen Koeffizienten** (z. B. AWEI):
  NICHT gain-invariant, auch wenn sie physikalisch stark sind — sie tragen den
  Shift wieder herein.
- **Robuste Aggregate** über die shift-/lücken-behaftete Achse (Mittel/Median/
  Range statt einzelner Positionen).

---

## 4. Validieren — die maskierungs-bewusste CV UND ihre Grenze

Bildet die Test-Bedingung (z. B. Lücken) beim Training und in der Validierung nach
(Vorlage: `masking.R`, `PipeOpMonthMask` mit getrennten Flags `mask_on_train` /
`mask_on_predict`; Aggregate laufen NACH der Maskierung, sonst Leak).

**Kardinale Grenze — unbedingt merken:**

> **Eine aus Train gebaute CV kann Shift-Robustheit NICHT bewerten.** Sie
> validiert auf Train-*Werten*; den Werte-Shift sieht sie nie. Sie ist eine obere
> Schranke, kein Leaderboard-Ersatz.

Konsequenz: Ein signal-stärkeres, aber shift-fragiles Feature-Set schlägt auf der
CV ein invarianteres — und dieses Ranking **kann sich am Leaderboard umkehren**.
(Aquaculture-Beweis: CV setzte `raw` > `indices`; LB gab `indices` 0.721 ≫ `raw`
0.573.) → **Feature-Set-Wahl unter Shift auf einem shift-exponierten Set
(Leaderboard) entscheiden, nicht auf der CV.**

---

## 5. Aufhören — Leaderboard-Overfitting vermeiden

Weil die CV den Shift nicht sieht, ist der Public-LB oft das *einzige* verlässliche
Signal. Es zum Auswählen vieler kleiner Varianten zu benutzen, **fittet den
Public-Split** (adaptives/Leaderboard-Overfitting) und kann den verdeckten
Private-LB verschlechtern. Faustregeln:
- Nur **begründete, qualitativ verschiedene** Hebel testen, keine Micro-Varianten.
- Neue Hebel **erst an der maskierten CV screenen**, bevor ein Submission-Slot
  draufgeht (spart Slots und schützt das LB-Signal).
- Bei halbierenden Zuwächsen und erschöpften begründeten Hebeln: **bewusst
  stoppen.** Eine prinzipiengeleitete Lösung hält eher auf dem Private-LB.

---

## 6. Checkliste (Kurzform)

1. Shift vermutet? → gestufte Adversarial Validation (roh → aggregat → gleiche Achse).
2. Positiv-Rate auf ungelabeltem Test vs. Train-Basisrate prüfen.
3. Reweighting nur nach ESS-Check (`ESS/n` groß genug?); falls gewichtet, mit
   Balance-Check (C2ST, AUC→0.5) verifizieren — aber Balance ≠ Präzision.
4. Sonst: gain-invariante Repräsentation + robuste Aggregate.
5. Maskierungs-bewusste CV bauen — aber wissen, dass sie Shift-Robustheit nicht misst.
6. Feature-Set-Entscheidung auf den Leaderboard verlagern.
7. Begründete Hebel screenen, bei Plateau bewusst stoppen (Overfitting-Schutz).
