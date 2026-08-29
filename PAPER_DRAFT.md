# A Reproducible, Trust-Centered AutoML Workflow for Tabular Classification in R/mlr3

**Status: DRAFT (2026-08-29), first full pass. Not submitted anywhere.
Written in English (standard for the target venues below), even though
the underlying repository is documented in German — see "How to use this
draft" at the end for what still needs human decision-making before this
is submission-ready.**

## Abstract

Most public machine-learning competition repositories report a single
score and little else. We present a template-driven, reproducible AutoML
workflow for tabular classification, built on `mlr3` in R and hardened
across more than 15 independent Kaggle/Zindi/DrivenData/OpenML projects.
The system's central design commitment is not a novel learning algorithm
but a **trust layer**: automated leak audits, adversarial-validation
drift checks, and model sanity checks that run on every project and are
logged to a queryable experiment database together with a lightweight
evidence registry. A disciplined template-evolution rule (backport a new
module only after confirmation on ≥2 independent projects, or a proven
no-op) keeps this trust layer from overfitting to any single dataset.

We evaluate the workflow's core weighted-training-plus-correction
component ("Level 1") on 7 internally-encountered datasets and, to guard
against benchmark selection bias, on 6 additional datasets drawn from
OpenML-CC18 by a criterion fixed *before* any performance was observed.
Against default baselines the component wins or ties on nearly every
dataset; against **fairly tuned** baselines (matched compute budget) its
advantage survives only on the more class-imbalanced datasets and
disappears on larger, already-balanced ones — a precise, falsifiable
boundary condition rather than a blanket "the workflow is better" claim.
A further prototype ("Level 2": model selection, tuning, and ensembling
performed *inside* each outer-CV fold) shows a mixed, on-average slightly
negative result relative to Level 1 across the same 6 external datasets,
at 5-30x the compute cost — a negative finding we report because it
bounds, rather than inflates, the workflow's claimed value. We argue this
combination of a mature trust layer, an externally-validated but bounded
performance claim, and openly reported negative results makes the system
a credible candidate for a workshop/experience/software paper, while
flagging what is still missing for a stronger research-track claim.

## 1. Introduction

Kaggle-style competition code is usually optimized for a leaderboard
score and rarely built to be trusted, reused, or audited. Two failure
modes are common and rarely discussed in public repositories: (a) a
model looks strong in cross-validation because of a target leak or a
train/test shift that was never checked for, and (b) a workflow
component that helped on the one dataset it was built for is silently
assumed to generalize, without ever being tested elsewhere.

This paper describes a template — not a single project — built
specifically against both failure modes. Its contribution is not a new
learning algorithm but a **process**: a small set of automated trust
checks that run on every new project before any score is trusted, a
database that makes every training run, hyperparameter, and diagnostic
result queryable after the fact, and a governance rule that only
backports a new module into the shared template once it has been
independently confirmed at least twice.

We make the following contributions:

1. **A trust-centered AutoML workflow** for tabular classification
   (target-leak audit, adversarial-validation drift check, split-size
   sensitivity, learning-curve plateau detection, seed-stability check,
   generalization-gap check, model sanity checks), implemented as a
   reusable `mlr3` template and hardened across 15+ independent projects.
2. **An explicit vocabulary for what "the workflow" means** when its
   performance is evaluated — we distinguish a *Component Workflow*
   (Level 1: weighted training + correction), a *Model-Selection
   Workflow* (Level 2: adds tuning/model choice/ensembling inside each
   outer fold), and a full *Trust-Centered AutoML Decision Process*
   (Level 3, not yet evaluated) — and report results under each label
   honestly rather than conflating them (Section 4).
3. **An externally-anchored Level-1 evaluation**: 7 internally-encountered
   datasets plus 6 datasets from OpenML-CC18 selected by a criterion
   fixed before any performance was observed, evaluated against both
   default and *fairly tuned* baselines under a frozen protocol
   (Section 5). We report the precise conditions under which the
   workflow's advantage holds and where it does not.
4. **A negative/mixed result for Level 2** (Section 6): more process
   complexity does not reliably outperform the simpler Level-1 workflow,
   even at markedly higher compute cost — reported deliberately, because
   a system's evaluation is only as trustworthy as its willingness to
   publish results that complicate its own story.
5. **Two ablation studies of the trust layer itself** (Section 7),
   showing concrete cases where leak audits and drift checks prevented a
   wrong conclusion, alongside one documented blind spot the guard did
   not catch.

## 2. System Description

### 2.1 Architecture

The template is a flat collection of numbered R scripts (currently 99),
not an R package — a deliberate choice recorded as an architecture
decision (see `adr/` in the repository) to keep the barrier to copying
and adapting a script for a new competition low. A `targets`-based
pipeline provides caching and reproducibility for the production path
(data → features → baseline → tuning → ensemble), while every run —
production or diagnostic — is additionally logged to a per-project
SQLite experiment database (`experiments.db`): projects, workflows, runs,
model configurations, hyperparameters, resampling strategies, and metric
results, all keyed so that "what changed between run A and run B" is an
answerable query, not a memory exercise.

### 2.2 The trust layer

Six diagnostic modules run on (a subset of) every new project before its
results are trusted:

- **Target-leak audit**: feature importance + a determinism check for
  suspiciously perfect single-feature predictors, catching leaks that
  correlation checks alone would miss on their own but are not exhaustive
  (Section 7.1 documents a case they miss).
- **Adversarial validation**: trains a classifier to distinguish train
  from test rows; a near-perfect AUC signals covariate shift that would
  silently invalidate a standard CV estimate.
- **Split-size sensitivity / learning-curve plateau detection**: checks
  whether the validation split size and the amount of training data are
  adequate for a stable estimate, rather than assuming a fixed 80/20
  split is always appropriate.
- **Seed stability**: quantifies how much of the measured score variance
  is training-seed noise versus genuine model-selection signal.
- **Generalization-gap check**: compares cross-validation against an
  independent bootstrap estimate to catch a workflow that has overfit to
  its own test-harness rather than the data.
- **Model sanity checks**: perturbation, invariance, and directional-
  expectation tests on the fitted model itself (e.g., does the model's
  prediction move in the theoretically expected direction when a known
  driver feature is perturbed).

None of these modules is intended to move a leaderboard score — their
job is to prevent a wrong conclusion or catch a measurement artifact
before it is trusted. Section 7 evaluates them on exactly that basis.

### 2.3 Governed template evolution

A new diagnostic module or workflow change is only backported into the
shared template once it satisfies one of two conditions: confirmation on
**at least two independent projects**, or a demonstrated **no-op**
(regression-tested against the template's own reference project, with no
degradation). This rule exists specifically to prevent the template from
overfitting to the idiosyncrasies of whichever single project motivated
a change — a failure mode we consider at least as important to guard
against as leakage in any one dataset.

### 2.4 Automated verification

Two independent CI jobs run on every push: a `testthat` suite (16 test
files, 150+ test cases covering the diagnostic modules, database logging,
provenance capture, and the evidence registry) and an end-to-end smoke
test that runs the core pipeline against a synthetic fixture. Findings
that are not (yet) code-verifiable are logged as structured evidence
entries (project, module, role — trust-gate / score-lever / workflow-
automation / documentation —, status, and free-text notes) in an
"evidence registry" that can regenerate a project × module results table
on demand, rather than relying solely on hand-maintained prose.

## 3. Related Work *(placeholder — needs a proper literature pass before submission)*

The ensemble-selection component follows Caruana, Niculescu-Mizil, Crew,
and Ksikes (2004), *"Ensemble Selection from Libraries of Models,"* ICML
— the same greedy-selection-from-a-model-library approach later adopted
in Auto-sklearn. We have not yet done a systematic literature review
against the broader AutoML-trustworthiness and benchmark-methodology
literature (e.g., work on AutoML benchmarking suites, leakage detection,
and reproducibility in ML competitions); this section is a placeholder
flagging that gap rather than a real related-work section, and should
not be treated as complete.

## 4. What Does "The Workflow" Mean? Three Evaluation Levels

An early version of this work's central claim — "the workflow
generalizes across datasets" — was imprecise about *what* had actually
been measured. We now distinguish three levels explicitly, and report
every result under the correct one:

- **Level 1 — Component Workflow**: a single, fixed learning algorithm
  (Ranger) with class-balanced weighting and, where applicable, a
  post-hoc class-multiplier correction tuned to the target metric. No
  model selection, no hyperparameter tuning, no ensembling happens
  inside the outer-CV loop.
- **Level 2 — Model-Selection Workflow**: within each outer-train split,
  a Ranger and a LightGBM model are independently tuned (via
  `AutoTuner`), a small probability-average ensemble is formed, and the
  winner is chosen by an *inner* validation score before being refit on
  the full outer-train split and scored once on the held-out outer test.
- **Level 3 — Full Trust-Centered AutoML Decision Process**: the
  complete decision process used in a real project — including the
  trust-layer checks themselves as active in-loop decisions, not just
  post-hoc documentation. Not yet evaluated; computationally, each outer
  fold would require a full copy of the project workflow.

Section 5 reports Level 1 results; Section 6 reports a Level 2
prototype. No Level 3 evidence exists yet, positive or negative, and we
say so explicitly rather than letting the Level-1 result imply more than
it does.

## 5. Level 1 Evaluation

### 5.1 Protocol

Three arms are compared under 3-fold outer cross-validation, holding the
resampling seed and outer-fold assignment fixed within a dataset:
`ranger_default`, `lightgbm_default`, and `workflow_ranger` (class-
balanced weighting, power = 1.5, plus a class-multiplier correction
tuned on an inner holdout split when the target metric benefits from it).
A second protocol version adds *fairly tuned* competitors —
`tuned_ranger` and `tuned_lightgbm` (via `AutoTuner`, matched inner-
holdout budget, 15 tuning evaluations per outer fold) and
`best_single_tuned_model` (selected by inner score, not outer score) —
specifically to test whether the workflow's advantage merely reflects
"tuned beats untuned" rather than a real effect of the correction chain.

### 5.2 Internal datasets (Phase C)

7 datasets encountered through ordinary project work were evaluated:
binary balanced/imbalanced, multiclass, small/large, one with a real
covariate shift, and one with group/time structure. On the 4
balanced-accuracy-primary tasks, `workflow_ranger` wins or ties the
baselines (up to +8.5 points). On the 2 accuracy-/F-beta-primary tasks
**without** an accompanying correction step, it drops sharply (up to
-28.7 points) — because those metrics reward majority-/positive-class
performance, the opposite of what the class weighting alone optimizes
for. This is the origin of the paper's central, metric-conditional
claim: *the weighting-plus-correction chain generalizes when the
correction target matches the evaluation metric; weighting alone does
not.*

### 5.3 External benchmark set

Internally-encountered datasets carry an obvious risk: they were, by
construction, ones the workflow already worked reasonably well on. To
guard against this, 6 additional datasets were drawn from OpenML-CC18 (a
curated, external 72-dataset classification suite) under inclusion
criteria fixed *before* any performance number was observed (500-20,000
instances, ≤100 features, 2-10 classes, not already used in the
template), then selected deterministically by a fixed random seed: 3
binary + 3 multiclass tasks (`ilpd`, `sick`, `blood-transfusion`, `cmc`,
`analcatdata-authorship`, `optdigits`).

Against **default** baselines, `workflow_ranger` reproduces the internal
finding on genuinely unseen data: it wins clearly on 4 of 6 datasets
(+1.6 to +6.7 balanced-accuracy points) and is close to neutral on the
remaining 2, with no case of a severe regression.

Against **fairly tuned** baselines, the advantage narrows to exactly the
boundary the metric-conditional story predicts: it persists clearly on
the 3 smaller, more class-imbalanced datasets (`ilpd` +11.9,
`sick` +4.0, `blood-transfusion` +0.8 points) and effectively
disappears — reversing narrowly on 2 of 3 — on the 3 larger, better-
balanced ones (`cmc` -0.9, `analcatdata-authorship` -0.6,
`optdigits` -0.3 points). We read this as the strongest, most precisely
bounded version of the claim available: **the weighting-plus-correction
chain adds value beyond pure hyperparameter tuning specifically where
class imbalance is the dominant problem; on already-balanced, larger
tasks, tuning alone matches or exceeds it.**

## 6. Level 2 Prototype: A Negative Result

To test whether adding model selection and tuning *inside* the outer-CV
loop (rather than as a fixed, matched-budget competitor arm) changes the
picture, a Level-2 prototype was run on all 6 external datasets: per
outer fold, Ranger and LightGBM are each tuned on an inner train/tune
split (10 evaluations per arm), a probability-average ensemble is also
scored, and the winner (by inner score) is refit on the full outer-train
split and evaluated once on the outer test.

The result is mixed and, on average, slightly negative relative to the
best Level-1/tuned-baseline result per dataset: 3 wins
(`sick` +0.1, `blood-transfusion` +3.0, `optdigits` +0.2 points), 3
losses (`ilpd` -3.7, `cmc` -2.6, `analcatdata-authorship` -1.9 points),
mean delta ≈ -0.7 points, at 5-30x the compute cost of the Level-1/v2
protocols. An initial hypothesis after only 2 datasets — that Level 2
helps on large/balanced and hurts on small/imbalanced datasets — did
**not** survive the full rollout: `blood-transfusion` is both small and
imbalanced and wins clearly, while `ilpd` shares both properties and
loses. Neither dataset size nor class imbalance alone explains the
pattern. One partial explanation was found for one of the three losses:
`analcatdata-authorship` sits near a performance ceiling where all three
inner candidates tie at a perfect inner score in most folds, making the
final model-selection step effectively arbitrary.

We report this as a genuine negative/mixed result rather than omitting
it or reframing it as a qualified success. More process complexity is
not automatically better, and at this tuning budget, Level 2 does not
earn its substantially higher compute cost. We consider this finding
itself part of the paper's contribution: an honest evaluation of an
AutoML workflow should report where added sophistication *fails* to
help, not only where it succeeds.

## 7. Trust-Layer Ablations

Because the trust-layer modules are not score levers (they do not change
a trained model), their evaluation asks a different question than
Sections 5-6: *would a user without this signal have reached a wrong
conclusion?*

### 7.1 Leak audit

**Confirmed catch**: `CreditScoringChallenge` (Zindi) — an initial model
scored F1 0.88 using a feature (post-default penalty fees) that could
not have existed at prediction time. The leak audit flagged it; after
removal, the honest score (F1 ≈ 0.41) was later confirmed almost exactly
by the external leaderboard (0.4191) — evidence the internal check was
correct, not merely cautious.

**Documented blind spot**: the leak audit is not infallible. On a
separate, deliberately constructed test case, a leak spread redundantly
across many correlated features evaded gain-importance-based detection
entirely (honest performance collapsed from 0.998 to 0.53 balanced
accuracy with the guard silent). A correlation-cluster check was added
in response but only partially closes the gap. We report this
deliberately: a trust layer that claims perfect coverage without
evidence would itself be a trust violation.

### 7.2 Drift and stability checks

**Confirmed catch**: adversarial validation on
`geoai-aquaculture-pond-identification-challenge` found an extreme
train/test covariate shift (AUC 0.99998 raw, 0.978 on monthly-band
means) — without this check, a standard CV estimate would have silently
overstated deployment performance. The finding drove a switch from
reweighting (effective sample size collapsed to 2.6% under the shift) to
an invariance-based modeling approach instead.

**Self-correction case**: the learning-curve plateau check itself
produced a false positive on `openml-credit-g` (a spurious PLATEAU
verdict caused by a single outlier at very small `n` inflating the
measured score range); a more robust IQR-based denominator later
corrected the same dataset to the expected "still increasing" trend, in
line with all other datasets tested. We view a documented, corrected
methodological artifact in the tool used to build the trust layer as
evidence *for*, not against, the layer's overall reliability — it shows
the process catches its own mistakes, not only the data's.

## 8. Limitations

- **R-only, single-team codebase.** All 15+ hardening projects were run
  by the same practitioner using the same template; independent-team
  replication has not been attempted.
- **External benchmark is curated, not blind.** The 6 OpenML-CC18
  datasets were selected before performance was observed, which
  addresses selection-*after*-seeing-results bias, but the inclusion
  criteria (instance/feature/class-count bounds) were still chosen by
  the same team that built the workflow.
- **No formal significance testing.** Results are reported as point
  estimates and deltas across a small number of datasets (6-7); no
  correction for multiple comparisons or formal hypothesis test accompanies
  the per-dataset deltas.
- **Level 2 tuning budget was small** (10 evaluations per arm per outer
  fold) for compute reasons; whether a larger budget changes the mixed
  result in Section 6 is untested.
- **Level 3 is entirely unevaluated.** The paper's title claim
  ("trust-centered AutoML workflow") is best read as applying to the
  *system as used in practice* (Level 3, informally), while the
  *quantitative* generalization evidence in Sections 5-6 covers only
  Levels 1-2. We consider conflating these two senses the single most
  important thing this paper must not do.
- **No related-work section yet** (Section 3) — a genuine gap, not a
  stylistic placeholder.

## 9. Conclusion

We presented a trust-centered AutoML workflow for tabular classification
whose main contribution is process, not algorithm: automated leak and
drift audits, a governed template-evolution rule, and an experiment/
evidence-logging infrastructure that make every claim in this paper
independently re-derivable from the underlying database rather than
taken on faith. Its core performance claim is deliberately narrow and
metric-conditional, validated against an externally-anchored benchmark
set and fairly tuned baselines rather than defaults alone, and a
follow-up experiment that could have strengthened the claim further
(Level 2) instead produced a negative/mixed result that we report
in full. We believe this combination — a mature trust layer, a bounded
and externally-tested performance claim, and openly published negative
results — is a stronger and more honest contribution than a higher,
less-scrutinized leaderboard number would have been, and is sufficient
for a workshop/experience/software-paper submission; a stronger
research-track claim would additionally need the related-work pass
(Section 3), a Level-3 evaluation, and ideally a second, independent
implementation team.

---

## How to use this draft

This is a first full pass, not a finished manuscript. Before it is
submission-ready, the following need a human decision, not just more
writing:

1. **Target venue.** The structure above assumes a workshop/experience/
   software-paper track (per the internal self-assessment this repo's
   documentation already carries — see `AGENTS.md`, "Mittelfristiges
   Ziel"). A specific venue will dictate the page limit, citation style,
   and how much of Sections 2/7/8 to compress or expand.
2. **Section 3 (Related Work) is a placeholder**, not a real section — it
   needs an actual literature search against the AutoML-benchmarking and
   ML-trustworthiness literature before this draft can be shown to
   anyone outside this project.
3. **Author list / acknowledgments / anonymization** are untouched —
   deliberately, since that is a decision for you, not something to
   infer.
4. **Figures/tables**: the numeric results above are given as prose with
   inline deltas, mirroring `BACKLOG.md`'s style; a real submission would
   want at least one table (the 6-dataset external-benchmark comparison)
   and possibly a diagram of the workflow architecture
   (`WorkflowDescription.md` already has a Mermaid version that could be
   adapted).
5. Every specific number in this draft was taken directly from
   `BACKLOG.md`, `AGENTS.md`, `EVALUATION_LEVELS.md`,
   `BENCHMARK_PROTOCOL.md`, `EXTERNAL_BENCHMARK_SET.md`, and the two
   ablation documents — if any of those get corrected or extended later,
   this draft needs a matching pass, it will not update itself.
