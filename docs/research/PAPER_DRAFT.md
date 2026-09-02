# A Reproducible, Trust-Centered AutoML Workflow for Tabular Classification in R/mlr3

**Status: DRAFT (2026-08-29, first full pass; Related Work/Section 3
updated 2026-08-29 with a first literature pass). Not submitted
anywhere. Written in English, even though the underlying repository is
documented in German — see "How to use this draft" at the end for what
still needs human decision-making before this is submission-ready.**

**Target venue chosen (2026-08-29): JOSS (Journal of Open Source
Software).** JOSS reviews the software itself via a short (750-1750
word) paper, not a full empirical study — so this document is no longer
*the* submission text. It now serves as the **extended technical
report** that the actual JOSS submission (
[`joss/paper.md`](joss/paper.md), [`joss/paper.bib`](joss/paper.bib))
points readers to for the full evaluation (Sections 4-8 below). Sections
1-3 and 9 of this document remain useful background/framing but are not
what gets submitted anywhere as-is.

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
bounds, rather than inflates, the workflow's claimed value. Two further
trust-layer extensions test whether Level 2's inner decisions can be
trusted at all: a decision-stability check finds that its model-
selection step is unstable under small seed perturbations in most cases,
yet this instability does not predict Level-2 success or failure across
three independent extensions of the external benchmark set (n = 6, 10,
15) — an initially suggestive small-sample correlation that we explicitly
retract after re-testing; and a structurally harder, cluster-based
train/test split flags a real extrapolation risk on a majority of
datasets, with a documented caveat for multi-class tasks where the split
can conflate that risk with simple class exclusion. We argue this
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
on demand. This deliberately coexists with, rather than replaces, a
curated, hand-maintained results table for the original nine trust-layer
modules (footnotes, correction history, and discussion the generated
table cannot reproduce); newer outer-evaluation claims (Sections 5-6)
are tracked exclusively through the generated, evidence-registry-backed
table instead. Both are traceable to a concrete logged source rather
than memory or prose alone — see `BACKLOG.md`'s "P2 - Status (2. Haelfte)"
for the explicit division-of-labor decision.

## 3. Related Work

**Status note (2026-08-29): first literature pass, no longer a bare
placeholder** — sources below were located and their claims checked via
web search rather than recalled from memory, but citation details
(page numbers, exact venue formatting) are not yet normalized to a
reference manager/BibTeX, and coverage is deliberately scoped to the
handful of areas this paper actually touches, not a exhaustive AutoML
survey. Treat this as "good enough to argue the paper's positioning
against," not as submission-ready related work.

**AutoML systems.** Auto-sklearn (Feurer et al., 2015, *"Efficient and
Robust Automated Machine Learning,"* NeurIPS) combines Bayesian
hyperparameter optimization with meta-learning warm-starting and
post-hoc ensemble construction over a fixed pipeline search space —
methodologically the closest prior system to our Level-2 prototype
(Section 6), which performs a much smaller-scale version of the same
idea (tune a small set of learners, then pick/ensemble by inner score)
inside each outer-CV fold rather than once globally. AutoGluon-Tabular
(Erickson et al., 2020, arXiv:2003.06505) instead argues that
*multi-layer stacked ensembling* of many models, rather than searching
for a single best model/hyperparameter configuration, is a better use of
a fixed compute budget on tabular data — a claim in tension with our
Level-2 finding that adding model selection and tuning *inside* the
outer loop did not reliably pay for itself; reconciling the two (e.g., is
AutoGluon's advantage specific to its multi-layer stacking depth, which
our single-layer probability-average ensemble does not attempt?) is a
concrete question for future work rather than one this paper resolves.
The broader field is surveyed in Hutter, Kotthoff, and Vanschoren (eds.,
2019), *Automated Machine Learning: Methods, Systems, Challenges*
(Springer) — our system does not compete on the same axis as the
systems that book catalogs (hyperparameter optimization, neural
architecture search, meta-learning); its contribution is closer to
process/trust engineering *around* a much simpler search space.

**Benchmarking methodology.** Our external-benchmark-set design
(Section 5.3) follows the spirit of Bischl et al. (2021), *"OpenML
Benchmarking Suites,"* NeurIPS Datasets and Benchmarks Track, which
argues for standardized, curated, reusable benchmark suites (of which
OpenML-CC18, the 72-dataset suite we drew our 6 external datasets from,
is one instance) specifically to prevent the kind of ad hoc,
after-the-fact dataset selection that makes AutoML claims hard to trust
across papers. Gijsbers et al. (2019), *"An Open Source AutoML
Benchmark,"* (6th ICML AutoML Workshop) make a closely related point
about comparing AutoML *systems* rather than datasets: that
apples-to-apples AutoML comparisons are "hard and often done
incorrectly," and propose an open, versioned benchmark framework for
exactly that reason. Our own frozen `BENCHMARK_PROTOCOL.md` (fixed arms,
fixed outer-fold seed, versioned rather than silently changed) is a
much smaller-scale, single-team instance of the same underlying concern.
For the actual statistical comparison *within* such a benchmark set, we
follow Demšar (2006), *"Statistical Comparisons of Classifiers over
Multiple Data Sets,"* JMLR — the standard reference for exactly the
paired-Wilcoxon/Friedman-plus-post-hoc procedure we apply in Section 6,
also packaged as the Python tool Autorank (Herbold, 2020, JOSS); we
apply the same underlying test natively in R rather than adopting the
Python package, consistent with this project's R-only policy.

**Data leakage and dataset shift.** Kaufman, Rosset, and Perlich (2011),
*"Leakage in Data Mining: Formulation, Detection, and Avoidance,"* KDD —
later published in *ACM TKDD* (2012) — frame leakage as "one of the top
ten data-mining mistakes" and formalize it as illegitimate information
about the target entering the model, including subtler cases where the
i.i.d. assumption itself is violated; our leak-audit module (Section
2.2, evaluated in Section 7.1) is a lightweight, automated, always-on
instance of exactly the detection problem they formalize, including its
documented incompleteness (our correlation-spread blind spot in Section
7.1 is a concrete instance of the harder, non-i.i.d.-adjacent cases they
discuss). The dataset-shift problem our adversarial-validation check
targets is treated formally by Quiñonero-Candela, Sugiyama,
Schwaighofer, and Lawrence (eds., 2009), *Dataset Shift in Machine
Learning* (MIT Press), which distinguishes covariate shift (only the
input distribution changes) from the more general dataset-shift case; the
specific *adversarial validation* technique itself (train a classifier
to distinguish train from test rows) is best documented as a
practitioner technique that spread through Kaggle competitions (e.g., an
early public application in the Santander Customer Satisfaction
competition) rather than a single peer-reviewed origin paper — we flag
this honestly rather than inventing an academic citation for what is, in
its current widespread form, community/blog-documented practice.

**Reproducibility and testing of ML systems.** Pineau et al. (2021),
*"Improving Reproducibility in Machine Learning Research,"* JMLR (a
report from the NeurIPS 2019 Reproducibility Program), and Gundersen and
Kjensmo (2018), *"State of the Art: Reproducibility in Artificial
Intelligence,"* AAAI, both document — from different angles (a
community intervention program vs. a survey of top-conference papers) —
that reproducibility in empirical ML research is the exception rather
than the norm; our per-run experiment database and provenance-capture
mechanism (Section 2.1, 2.4) are a practitioner-side, single-repository
response to the same underlying problem, at a far smaller scale than
either paper's scope. On the software-engineering side, Breck et al.
(2017), *"The ML Test Score: A Rubric for ML Production Readiness and
Technical Debt Reduction,"* (Google, IEEE Big Data) and Zhang, Harman,
Ma, and Liu (2020), *"Machine Learning Testing: Survey, Landscapes and
Horizons,"* IEEE TSE, both argue that ML systems need testing
disciplines beyond a single held-out score — our CI-verified `testthat`
suite plus the trust-layer's diagnostic modules (Section 2.2, 2.4) are
one concrete instantiation of that argument for a tabular-classification
AutoML template specifically, rather than ML systems in general.

**Class imbalance.** He and García (2009), *"Learning from Imbalanced
Data,"* IEEE TKDE, survey the broader problem our class-weighting-plus-
multiplier-correction chain (Section 5) is one specific, metric-
conditional instance of; we do not attempt a comparison against the
resampling-based techniques (e.g., SMOTE-family methods) that dominate
that literature, since our approach operates entirely at the
loss-weighting/post-hoc-threshold level rather than the data level — a
scoping choice worth stating explicitly rather than leaving implicit.

**Software this work builds on.** The workflow itself is implemented on
top of `mlr3` (Lang et al., 2019, *"mlr3: A Modern Object-Oriented
Machine Learning Framework in R,"* Journal of Open Source Software), and
the ensemble-selection component follows Caruana, Niculescu-Mizil, Crew,
and Ksikes (2004), *"Ensemble Selection from Libraries of Models,"*
ICML — the same greedy-selection-from-a-model-library approach later
adopted in Auto-sklearn.

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

**A formal significance check makes this even more precise than the
"3 wins, 3 losses" framing suggests.** Following the standard procedure
for comparing two methods across multiple datasets [@Demsar2006] (as
implemented, for example, in the Autorank package [@Herbold2020]), we
ran a paired two-sided Wilcoxon signed-rank test on the per-dataset
Level-2-vs-best-prior deltas (one aggregated score per dataset, not per
fold, since folds within a dataset are not independent). Result:
V = 8, p = 0.6875 — nowhere near significance at any conventional
threshold. This is not surprising on its own (Demšar's own guidance is
that the Wilcoxon test needs on the order of 8-10 datasets to have
reasonable power, and we have 6), but it sharpens the honest conclusion:
we cannot statistically distinguish the observed pattern from a
zero-effect, mean-preserving mix of wins and losses. We report the exact
test result rather than only the informal win/loss count specifically
because a small, cherry-pickable set of deltas can look more like a
"pattern" to a reader than the data actually support.

**We then tested the most obvious candidate explanation for the mixed
pattern directly — the tuning budget — and ruled it out.** The Level-2
prototype above uses 10 tuning evaluations per arm per outer fold, a
small budget chosen for compute reasons; if the mixed result were
simply an artifact of under-tuning, a larger budget should shift it in
a consistent direction. We re-ran all 6 datasets with 30 evaluations
per arm (3x) and compared paired, per-dataset, against the original
10-evaluation run with the same Wilcoxon procedure: V = 11, p = 1 — as
close to a null result as a test can produce. Individual datasets moved
in both directions with no consistent pattern (`ilpd` improved by 4.5
points, flipping from a loss to a win; `optdigits` worsened by 0.4
points, flipping from a win to a loss; `blood-transfusion` worsened by
1.6 points while remaining a win; `analcatdata-authorship` improved by
0.9 points while remaining a loss). Tripling the tuning budget changed
*which* datasets won, not *whether* Level 2 wins on net — the aggregate
comparison against the best prior result stayed statistically
indistinguishable from zero at the larger budget too (V = 8, p = 0.6875,
identical statistic to the 10-evaluation run). We consider the tuning-
budget hypothesis for the mixed P2 pattern ruled out by this test,
rather than merely untested — a concrete example of a negative result
that narrows the explanation space instead of leaving it open. The
reproducible code for both comparisons is in
`p2_level2_significance_test.R`.

**We also checked whether simple dataset meta-features explain the
pattern, and found none that do.** Beyond dataset size and class
imbalance (already ruled out informally in the original rollout) and
tuning budget (ruled out above), we tested three further candidates: the
number of minority-class rows available to the *inner* model-selection
step specifically (25% of the outer-train split, not the full dataset —
the actual sample the Level-2 decision is based on), the across-fold
standard deviation of the Level-2 score itself (a proxy for how noisy/
unstable that inner decision is), and how close the best prior result is
to a performance ceiling (a saturation proxy, motivated by the
near-perfect-tie case observed for `analcatdata-authorship`). None of
the five candidates (dataset size, class imbalance, inner-tune minority
count, score-instability proxy, ceiling proximity) shows more than a
weak Spearman correlation with the win/loss delta (|ρ| ≤ 0.37, p ≥ 0.49
for all five, n = 6 — reproducible in
`p2_level2_metafeature_analysis.R`). We read this as a genuine,
if unsatisfying, conclusion rather than a methodological failure: having
now ruled out four natural univariate explanations (size, imbalance,
tuning budget, and three further meta-features), the mixed Level-2
result on this benchmark set does not appear to be explained by any
single simple property of the datasets we tested — either the true
mechanism is a higher-order interaction between these factors that a
sample of 6 datasets cannot resolve, or the pattern is closer to
irreducible per-dataset noise than to a systematic effect. Distinguishing
between those two possibilities would require a substantially larger
external benchmark set than the 6 datasets used here, which is beyond
the scope of this paper. (A related, differently-scoped question — not
this metafeature question itself, but whether the Level-2 model-
selection step's *decision stability* predicts its success — was later
tested on exactly such an extended set, up to n = 15; see Section 7.3.)

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

### 7.3 Decision stability of the Level-2 model-selection step

Motivated by the PCS (predictability-computability-stability) framework
underlying VeridicalFlow [@Duncan2022VeridicalFlow], a further question was
asked of the Level-2 workflow (Section 6): is its inner model-selection
decision (which of ranger/lightgbm/ensemble wins on the inner tune
split) *stable* under small, arbitrary perturbations of that split, or
would a differently-seeded inner split just as plausibly have picked a
different winner? For a fixed outer-train fold, the inner split seed was
varied across 10 repeats and the resulting majority choice and its
frequency recorded (implementation: `decision_stability.R`, applied via
`decision_stability_level2_prototype.R`).

Across all outer folds and all datasets available at the time, the
majority choice held in under 70% of repeats more often than not (71%
of 45 dataset-fold measurements at n = 15, see below) — decision
instability at this tuning budget is closer to the norm than the
exception. The natural follow-up question — does this instability
*predict* whether the Level-2 workflow wins or loses against the best
prior baseline (Section 6)? — was tested at three successively larger
sample sizes as the external benchmark set was extended for this
purpose: an initial, fold-1-only reading at n = 6 was suggestive
(Spearman ρ = -0.28), but did **not** survive re-testing on the mean
stability across all 3 outer folds of the same 6 datasets
(ρ = -0.086, p = 0.92), nor two independent extensions of the dataset
sample to n = 10 (ρ = -0.134, p = 0.71) and n = 15 (ρ = -0.147,
p = 0.60). We report the initial suggestive reading and its retraction
explicitly, as an example of a small-sample artifact caught by directly
re-testing rather than treated as a finding: **decision-selection
instability, at least as measured here, does not predict Level-2
success or failure.** No corresponding pipeline change was made — a
generic, reusable stability-reporting module remains available, but the
specific application to Level-2 model selection yields no actionable
guidance and was not promoted into the default workflow.

### 7.4 A structurally harder train/test split (extrapolation risk)

Standard cross-validation, and the bootstrap-based generalization-gap
check in Section 7.2, both test whether a model generalizes within the
same data distribution it was trained on — interpolation. Motivated by
astartes' rational, distance-based dataset splitting for chemistry data
[@Burns2023astartes], a complementary check asks a structurally
different question: does the model still perform when the test set is a
*distinct region* of feature space it never saw during training —
extrapolation? A native, simpler re-implementation of the same idea
(rather than adopting the chemistry-specific astartes package itself)
splits a task by k-means clustering on its numeric features, holding out
the smallest cluster as test data, and compares the resulting score
against a reference distribution built from ordinary random holdouts of
the same size (`hard_split_stress_test.R`).

Applied to the 6 external benchmark datasets plus this project's own
template dataset (7 confirmations total, exceeding the ≥2-project bar
for backporting a trust module into the numbered pipeline), 5 of 7 were
flagged (|z| from 19 to 158) — a structurally harder split degrades
performance far more than ordinary CV variance would suggest, in a
majority of cases. A follow-up root-cause check on the two most extreme
cases, however, revealed an important caveat: for multi-class tasks
whose classes are well separated in feature space (e.g. a 10-class
handwritten-digit task), the cluster-based split can degenerate into a
*near class-holdout* — the held-out cluster consists almost entirely of
1-3 classes rarely seen during training, so the score drop partly
reflects the already-well-understood problem of missing training
examples for excluded classes rather than genuine same-class
extrapolation failure. The module was extended in response with an
automatic class-proportion-shift diagnostic that flags this distinction
directly in its output, rather than leaving the two mechanisms
conflated in a single z-score.

## 8. Limitations

- **R-only, single-team codebase.** All 15+ hardening projects were run
  by the same practitioner using the same template; independent-team
  replication has not been attempted.
- **External benchmark is curated, not blind.** The 6 OpenML-CC18
  datasets were selected before performance was observed, which
  addresses selection-*after*-seeing-results bias, but the inclusion
  criteria (instance/feature/class-count bounds) were still chosen by
  the same team that built the workflow.
- **Formal significance testing is now applied only to the Level 1-vs-2
  comparison** (Section 6, a paired Wilcoxon signed-rank test following
  [@Demsar2006]) — the other per-dataset deltas throughout Sections 5
  and 7 are still reported as point estimates without a matching formal
  test or a multiple-comparisons correction. With only 6-7 datasets per
  comparison, any such test would have limited power regardless
  ([@Demsar2006] recommends on the order of 8-10 datasets for the
  Wilcoxon test used here); this is a real constraint of the sample
  size, not a gap that more careful statistics alone would close.
- **Level 2's default tuning budget is small** (10 evaluations per arm
  per outer fold) for compute reasons; unlike in an earlier version of
  this manuscript, this is no longer an untested gap — Section 6 reports
  a direct 3x-budget re-run showing no detectable systematic effect
  (p = 1). We did not test budgets beyond 30 evaluations, so a much
  larger budget (e.g. 100+) remains genuinely untested, though the null
  result at 3x gives no particular reason to expect a different picture.
- **Level 3 is entirely unevaluated.** The paper's title claim
  ("trust-centered AutoML workflow") is best read as applying to the
  *system as used in practice* (Level 3, informally), while the
  *quantitative* generalization evidence in Sections 5-6 covers only
  Levels 1-2. We consider conflating these two senses the single most
  important thing this paper must not do.
- **Related work (Section 3) has a first pass now**, but citation
  details are not normalized to a reference manager/BibTeX, and coverage
  is scoped narrowly to the areas this paper touches rather than an
  exhaustive AutoML survey — see the status note at the top of Section 3.

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
research-track claim would additionally need a Level-3 evaluation and
ideally a second, independent implementation team.

## References *(not yet normalized to a citation style/BibTeX)*

- Breck, E., Cai, S., Nielsen, E., Salib, M., & Sculley, D. (2017). The
  ML test score: A rubric for ML production readiness and technical debt
  reduction. *IEEE Big Data*. https://research.google/pubs/the-ml-test-score-a-rubric-for-ml-production-readiness-and-technical-debt-reduction/
- Burns, J. D., Spiekermann, K. A., Bhattacharjee, H., Vlachos, D. G., &
  Green, W. H. (2023). Machine learning validation via rational dataset
  sampling with astartes. *Journal of Open Source Software*, 8(91),
  5996. https://doi.org/10.21105/joss.05996
- Caruana, R., Niculescu-Mizil, A., Crew, G., & Ksikes, A. (2004).
  Ensemble selection from libraries of models. *ICML*.
- Demšar, J. (2006). Statistical comparisons of classifiers over
  multiple data sets. *Journal of Machine Learning Research*, 7,
  1-30.
- Duncan, J., Kapoor, R., Agarwal, A., Singh, C., & Yu, B. (2022).
  VeridicalFlow: A Python package for building trustworthy data science
  pipelines with PCS. *Journal of Open Source Software*, 7(69), 3895.
  https://doi.org/10.21105/joss.03895
- Erickson, N., Mueller, J., Shirkov, A., Zhang, H., Larroy, P., Li, M.,
  & Smola, A. (2020). AutoGluon-Tabular: Robust and accurate AutoML for
  structured data. arXiv:2003.06505. https://arxiv.org/abs/2003.06505
- Feurer, M., Klein, A., Eggensperger, K., Springenberg, J., Blum, M., &
  Hutter, F. (2015). Efficient and robust automated machine learning.
  *NeurIPS 28*. https://papers.neurips.cc/paper/5872-efficient-and-robust-automated-machine-learning.pdf
- Gijsbers, P., LeDell, E., Thomas, J., Poirier, S., Bischl, B., &
  Vanschoren, J. (2019). An open source AutoML benchmark. *6th ICML
  Workshop on Automated Machine Learning*. arXiv:1907.00909.
  https://arxiv.org/abs/1907.00909
- Gundersen, O. E., & Kjensmo, S. (2018). State of the art:
  Reproducibility in artificial intelligence. *AAAI*.
  https://ojs.aaai.org/index.php/AAAI/article/view/11503
- He, H., & García, E. A. (2009). Learning from imbalanced data. *IEEE
  Transactions on Knowledge and Data Engineering*, 21(9), 1263-1284.
- Herbold, S. (2020). Autorank: A Python package for automated ranking
  of classifiers. *Journal of Open Source Software*, 5(48), 2173.
  https://doi.org/10.21105/joss.02173
- Hutter, F., Kotthoff, L., & Vanschoren, J. (Eds.). (2019). *Automated
  Machine Learning: Methods, Systems, Challenges*. Springer.
  https://www.automl.org/book/
- Kaufman, S., Rosset, S., & Perlich, C. (2011). Leakage in data mining:
  Formulation, detection, and avoidance. *KDD 2011*; extended version in
  *ACM Transactions on Knowledge Discovery from Data*, 6(4), 2012.
- Lang, M., Binder, M., Richter, J., Schratz, P., Pfisterer, F., Coors,
  S., Au, Q., Casalicchio, G., Kotthoff, L., & Bischl, B. (2019). mlr3:
  A modern object-oriented machine learning framework in R. *Journal of
  Open Source Software*, 4(44), 1903. https://joss.theoj.org/papers/10.21105/joss.01903
- Pineau, J., Vincent-Lamarre, P., Sinha, K., Larivière, V.,
  Beygelzimer, A., d'Alché-Buc, F., Fox, E., & Larochelle, H. (2021).
  Improving reproducibility in machine learning research (a report from
  the NeurIPS 2019 reproducibility program). *JMLR*, 22.
  https://jmlr.org/papers/volume22/20-303/20-303.pdf
- Quiñonero-Candela, J., Sugiyama, M., Schwaighofer, A., & Lawrence, N.
  D. (Eds.). (2009). *Dataset Shift in Machine Learning*. MIT Press.
- Bischl, B., Casalicchio, G., Feurer, M., Gijsbers, P., Hutter, F.,
  Lang, M., et al. (2021). OpenML benchmarking suites. *NeurIPS Datasets
  and Benchmarks Track*.
- Zhang, J. M., Harman, M., Ma, L., & Liu, Y. (2020). Machine learning
  testing: Survey, landscapes and horizons. *IEEE Transactions on
  Software Engineering*, 48(1). arXiv:1906.10742.
  https://arxiv.org/abs/1906.10742

*Adversarial validation itself (the specific train-vs-test classifier
technique used in Section 2.2/7.2) is deliberately NOT given an academic
citation above — in its current widely-used form it is best documented
as a practitioner technique that spread through Kaggle competitions
(e.g., an early public write-up in the context of the Santander Customer
Satisfaction competition) rather than a single peer-reviewed origin. If
a stronger academic anchor is wanted for a submission, the closest
adjacent peer-reviewed treatments are Bickel, Brückner, & Scheffer's
work on covariate shift via discriminative reweighting (in the
Quiñonero-Candela et al. volume above) — this still needs a deliberate
decision, not an automatic substitution.*

---

## How to use this draft

This is a first full pass, not a finished manuscript. Before it is
submission-ready, the following need a human decision, not just more
writing:

1. **Target venue: DECIDED (2026-08-29) — JOSS.** The actual submission
   text now lives in [`joss/paper.md`](joss/paper.md) (short,
   750-1750 words, reviews the software not a full study); this
   document serves as JOSS's expected "extended report" that the short
   paper points to. See [`joss/README.md`](joss/README.md) for what
   still needs doing before an actual JOSS submission (author/
   affiliation placeholders, JOSS's repository-readiness checklist,
   compiling the paper locally, the submission itself).
2. **Section 3 (Related Work) now has a first real literature pass**
   (2026-08-29, 14 sources located and their claims checked via web
   search) covering AutoML systems, benchmarking methodology, leakage/
   dataset shift, ML reproducibility/testing, and class imbalance — but
   citations are not yet normalized to a reference manager/BibTeX, page
   numbers/venue formatting are informal, and coverage is deliberately
   scoped to what this paper touches rather than exhaustive. One
   deliberate open decision is flagged inline: adversarial validation
   (Section 2.2/7.2) has no clean academic origin citation and is
   currently described as a practitioner/Kaggle technique rather than
   given a possibly-inaccurate formal citation — decide before
   submission whether that is acceptable or whether the adjacent
   Bickel/Brückner/Scheffer covariate-shift-reweighting work should
   anchor it instead.
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
   this draft needs a matching pass, it will not update itself. The same
   applies to Section 3/References: they reflect one search pass on
   2026-08-29, not an ongoing literature watch.
