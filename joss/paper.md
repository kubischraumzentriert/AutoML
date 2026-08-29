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
  - name: TODO Author Name
    orcid: 0000-0000-0000-0000
    affiliation: 1
affiliations:
  - name: TODO Affiliation
    index: 1
date: 29 August 2026
bibliography: paper.bib
---

<!--
STATUS (2026-08-29): DRAFT, first JOSS-format pass. Author name,
affiliation, and ORCID above are placeholders — fill in before
submission, this was deliberately left for a human decision (see
`PAPER_DRAFT.md`'s "How to use this draft" for the same point applied to
the longer report). Word count target for JOSS is 750-1750 words; this
draft currently sits within that range but has not been trimmed by an
editor pass yet.
-->

# Summary

Competition code for tabular machine learning — Kaggle, Zindi,
DrivenData, OpenML — is usually optimized for a single leaderboard score
and rarely built to be trusted, reused, or audited. This package is a
reusable, `mlr3`-based [@Lang2019] AutoML template for tabular
classification in R that takes the opposite stance: its central design
commitment is not a novel learning algorithm but an always-on **trust
layer** — automated target-leak audits, adversarial-validation
covariate-shift checks, split-size/learning-curve/seed-stability
diagnostics, a generalization-gap check, and model sanity checks — that
runs on every new project before any score is trusted. Every diagnostic
result, training run, hyperparameter, and resampling strategy is logged
to a per-project SQLite experiment database, and every claim the
template's documentation makes about "what works" is backed by a
structured evidence-registry entry rather than by memory or prose alone.
The template has been hardened across 15+ independent Kaggle/Zindi/
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
shift-detection problem this package targets, and using them does not
by itself answer whether a given cross-validation estimate can be
trusted in the first place. Established leakage-detection methodology
[@Kaufman2011] and dataset-shift theory exist in the literature, but are
rarely packaged as an always-on, automated part of a practitioner's
day-to-day tabular-classification workflow, run identically across many
independent projects with the same benchmark protocol.

This package fills that gap for R users: it is not a competitor to
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

# Comparison to existing software

`mlr3` [@Lang2019] itself provides the underlying machine-learning
building blocks (tasks, learners, resamplings, measures) but no
AutoML-level workflow or trust layer on top of them; this package is
built on `mlr3`, not a replacement for it. Compared to general-purpose
tabular AutoML systems such as Auto-sklearn [@Feurer2015] and
AutoGluon-Tabular [@Erickson2020], this package deliberately keeps its
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
component, all of which this package provides as its primary
contribution rather than as an incidental add-on.

# Acknowledgements

TODO — acknowledgements, if any, go here (left blank deliberately; not
inferred).

# References
