---
title: 'A Reproducible, Trust-Centered AutoML Workflow for Tabular Classification in R/mlr3'
tags:
  - R
  - machine learning
  - AutoML
  - tabular data
  - reproducibility
  - data leakage
authors:
  - name: Andre Endress
    affiliation: 1
affiliations:
  - name: Independent Researcher
    index: 1
date: 29 August 2026
bibliography: paper.bib
---

<!--
STATUS (2026-08-29): DRAFT, first JOSS-format pass. Author name (Andre
Endress) and affiliation (Independent Researcher, no ORCID) confirmed by
the author on 2026-08-29 — no longer placeholders. Structure updated
2026-08-29 to match JOSS's current required sections (Summary,
Statement of need, State of the field, Software design, Research impact
statement, AI usage disclosure, Acknowledgements, References) — verified
directly against joss.readthedocs.io/en/latest/paper.html and the
openjournals/joss repository docs rather than assumed from memory. Word
count target for JOSS is 750-1750 words; this draft currently sits
within that range but has not been trimmed by an editor pass yet.
-->

# Summary

Competition code for tabular machine learning — Kaggle, Zindi,
DrivenData, OpenML — is usually optimized for a single leaderboard score
and rarely built to be trusted, reused, or audited. This is a
reusable, `mlr3`-based [@Lang2019] AutoML template for tabular
classification in R that takes the opposite stance: its central design
commitment is not a novel learning algorithm but an always-on **trust
layer** — automated target-leak audits, adversarial-validation
covariate-shift checks, split-size/learning-curve/seed-stability
diagnostics, a generalization-gap check, and model sanity checks — that
runs on every new project before any score is trusted. Every diagnostic
result, training run, hyperparameter, and resampling strategy is logged
to a per-project SQLite experiment database. Claims about the original
nine trust-layer modules are tracked in a curated, hand-maintained
results table with editorial detail (footnotes, correction history);
newer claims about the outer-evaluation workflow (Sections 5-6 of the
extended report) are additionally backed by a structured, queryable
evidence-registry entry that can regenerate its own results table on
demand — in both cases traceable to a concrete source rather than
memory or prose alone. The template has been hardened across 15+
independent Kaggle/Zindi/
DrivenData/OpenML projects under a governance rule (backport a new
module only after confirmation on ≥2 independent projects, or a proven
no-op) that is designed specifically to prevent the template from
overfitting to any single project's idiosyncrasies. Two independent
continuous-integration jobs run on every change: a unit-test suite
covering the diagnostic modules, database logging, and provenance
capture, and an end-to-end smoke test that runs the core pipeline
against a synthetic fixture, so that the claims above are automatically
re-checked rather than only documented once and trusted thereafter.

# Statement of need

Two failure modes are common in public competition repositories and
rarely discussed openly: a model can look strong in cross-validation
because of an undetected target leak or train/test distribution shift,
and a workflow component that helped on the one dataset it was built for
is often silently assumed to generalize without ever being tested
elsewhere. Existing general-purpose AutoML systems for tabular data —
Auto-sklearn [@Feurer2015] and AutoGluon-Tabular [@Erickson2020] among
others — are built to search a large space of models/pipelines
automatically and are evaluated primarily on predictive performance;
they are not designed around, nor evaluated against, the leakage- and
shift-detection problem this template targets, and using them does not
by itself answer whether a given cross-validation estimate can be
trusted in the first place. Established leakage-detection methodology
[@Kaufman2011] and dataset-shift theory exist in the literature, but are
rarely packaged as an always-on, automated part of a practitioner's
day-to-day tabular-classification workflow, run identically across many
independent projects with the same benchmark protocol.

This template fills that gap for R users: it is not a competitor to
Auto-sklearn or AutoGluon on raw predictive performance, but a
complementary, lighter-weight process layer that a practitioner can run
*alongside* any model-fitting approach to catch leakage and shift before
trusting a result, and that logs every run so "what changed between run
A and run B" is an answerable database query rather than a memory
exercise. Its core performance-relevant component — class-balanced
training with a metric-matched correction step — was evaluated not only
on internally-encountered datasets but also on 6 datasets from the
external, curated OpenML-CC18 suite [@Bischl2021], selected by a
criterion fixed before any performance was observed, and benchmarked
against both default and *fairly tuned* competing baselines: the
resulting, metric-conditional finding (the correction chain helps
specifically where class imbalance dominates, and is matched or beaten
by plain tuning on larger, balanced tasks) — together with a further,
openly reported negative/mixed result for a more complex model-selection
prototype — is documented in full in the project's extended technical
report rather than in this short paper, in keeping with JOSS's focus on
the software itself rather than a full empirical study. The
greedy-ensemble-selection component follows the method of
@Caruana2004, adapted to this template's per-project experiment
database.

# State of the field

`mlr3` [@Lang2019] itself provides the underlying machine-learning
building blocks (tasks, learners, resamplings, measures) but no
AutoML-level workflow or trust layer on top of them; this template is
built on `mlr3`, not a replacement for it. Compared to general-purpose
tabular AutoML systems such as Auto-sklearn [@Feurer2015] and
AutoGluon-Tabular [@Erickson2020], this template deliberately keeps its
model-search space small and fixed (Ranger and LightGBM, with optional
tuning) and instead invests its complexity budget in the diagnostic
trust layer and in an experiment-logging/evidence-registry
infrastructure that make every claim about the workflow's behavior
independently re-derivable from a queryable database — a design
trade-off aimed at reproducibility and auditability on tabular
classification specifically, rather than at maximizing coverage of
model families or search-space breadth. Within the R ecosystem
specifically, this fills a gap that neither `mlr3` nor its extension
packages address directly: none of them ship an always-on leakage/shift
trust layer, a governed cross-project template-evolution process, or a
per-project experiment/evidence database as a first-class, reusable
component, all of which this template provides as its primary
contribution rather than as an incidental add-on.

# Software design

This template is deliberately a flat collection of numbered R scripts
(currently 99), not an R package with a formal API — a trade-off made
explicitly to keep the barrier to copying and adapting a single script
for a new, time-pressured competition low, at the cost of the
discoverability an installable package/API would give. Each project
gets its own local SQLite experiment database rather than a shared,
live one, so a project can be worked on, copied, or archived
independently without touching a central service; a separate merge
script aggregates finished projects into one queryable database for
cross-project analysis when needed, rather than requiring
always-on connectivity. The template is R-only by policy — a
GPU-only neural-model variant is exported to a disposable Python script
only at the very end of a project, if a prototype in R shows it is
worth the extra complexity, rather than maintaining a parallel Python
codebase throughout. Finally, a new diagnostic module or workflow
change is only merged into the shared template once it is confirmed on
at least two independent projects (or proven to be a no-op) — a
governance rule chosen specifically to prevent the template from
overfitting to the idiosyncrasies of whichever single project motivated
the change.

# Research impact statement

The template has been applied, largely by a single practitioner so far,
across 15+ independent Kaggle, Zindi, DrivenData, and OpenML
classification projects. Three concrete, externally checkable results:
(1) on a Zindi credit-scoring competition, the leak-audit module flagged
a feature that could not have existed at prediction time; the resulting
honest score (F1 ≈ 0.41) was independently confirmed almost exactly by
the competition's real leaderboard (0.4191), evidence the internal
diagnostic was correct rather than merely cautious; (2) on an ongoing
Kaggle competition (a smartphone-addiction prediction task), the
template's greedy ensemble-selection component produced a measured
leaderboard improvement, not only a cross-validation improvement; (3) on
the template's own reference Kaggle dataset, the resulting model reached
Balanced Accuracy 0.9482 on the full, never-seen test set with a simple,
explainable random-forest model rather than a black-box ensemble. Beyond
single-project results, the template's core class-weighting-plus-
correction claim was independently re-tested on 6 datasets from the
external OpenML-CC18 suite [@Bischl2021], selected before any
performance was observed specifically to guard against benchmark
selection bias — full results in the project's extended technical
report. The template has not yet been adopted by other teams or cited in
third-party publications; its realized impact so far is within the
author's own competition practice, stated here plainly rather than
overstated.

# AI usage disclosure

A substantial portion of this software's diagnostic modules, database/
provenance infrastructure, documentation, and this paper itself
(including its literature search) were developed through extensive,
directed sessions with Claude (Anthropic), an AI coding assistant, working
under the author's continuous direction and review. Every code change
was additionally subject to the template's own verification discipline
before being trusted: automated unit tests and an end-to-end smoke test
run in continuous integration, and — per the template's own governance
rule (see Software design) — a new module is only adopted once confirmed
on at least two independent projects. The author directed all design
decisions, reviewed and empirically verified all generated code and
claims, and takes full responsibility for the software's and this
paper's correctness. Git commit history in the source repository records
AI co-authorship transparently on the individual commits where it
applies.

# Acknowledgements

TODO — acknowledgements, if any, go here (left blank deliberately; not
inferred).

# References
