# JOSS submission materials

**Status (2026-08-30): submission deliberately PAUSED, not abandoned.**
Draft itself is complete (see checklist below) - two real, independently
verified risks led to pausing rather than submitting:

1. **Hard, objective, currently blocking**: JOSS requires >=6 months of
   public repo history with active development before submission. This
   repo's first commit was 2026-07-07 - earliest eligible submission
   date is ~2027-01-07.
2. **Soft, substantive, does not resolve by waiting**: JOSS's "Scope and
   Significance" criterion defines "research software" narrowly
   (scientific-domain modeling tools, research instruments, knowledge
   extraction from large datasets) and explicitly excludes "pre-trained
   machine learning models and notebooks". A competition-methodology
   template (Kaggle/Zindi/OpenML) is inherently closer to an engineering-
   practice tool than a scientific-domain-modeling tool - a genuine
   scope-fit risk independent of the age gate.

**Decision**: keep JOSS as the target venue, revisit ~November 2026 (a
few months before the age gate closes anyway) once a real "research
aspect" contribution exists - see `BACKLOG.md` ("JOSS-Einreichung
pausiert (2026-08-30)") for the full reasoning and the suggested
direction (explaining the P2 Level-2 win/loss pattern instead of leaving
it as an unexplained negative result). **AutoML-Conf's ABCD track**
("Applications, Benchmarks, Challenges, Datasets") was noted as a
parallel alternative venue around the same time - its scope
(benchmark protocols, honest negative results) may fit this project
better than JOSS's narrow "research software" definition; 2027 is the
next reachable cycle (2026's deadline already passed). Both can be
pursued in parallel, no conflict with the JOSS timeline.

- [`paper.md`](paper.md) — the actual JOSS submission text (750-1750
  words: Summary, Statement of need, Comparison to existing software,
  Acknowledgements). JOSS reviews the **software**, not a full empirical
  study — the detailed evaluation (Level 1/2 results, ablations,
  limitations) deliberately lives in [`../PAPER_DRAFT.md`](../docs/research/PAPER_DRAFT.md)
  instead, which `paper.md` points to as the extended technical report.
- [`paper.bib`](paper.bib) — BibTeX references cited from `paper.md`
  (a small subset of the 14 sources gathered in `PAPER_DRAFT.md`'s
  Related Work — JOSS papers cite sparingly, they are not a literature
  review).

## Before this can actually be submitted

1. ~~Fill in author name/affiliation/ORCID in `paper.md`~~ **DONE
   (2026-08-29)**: Andre Endress, Independent Researcher, no ORCID —
   confirmed by the author, no longer placeholders. The
   Acknowledgements section is still an open `TODO` (deliberately —
   nothing was inferred).
2. **Repository readiness, checked against JOSS's actual review
   checklist (2026-08-29, verified via joss.readthedocs.io and the
   openjournals/joss repo docs)**:

   | Item | Status |
   |---|---|
   | Source repository publicly reachable | ✅ done |
   | ~~LICENSE file (OSI-approved)~~ | ✅ **DONE (2026-08-29)**: MIT, `../LICENSE` |
   | ~~Community guidelines (contributing/issues/support)~~ | ✅ **DONE (2026-08-29)**: `../CONTRIBUTING.md` + `.github/ISSUE_TEMPLATE/` |
   | Installation instructions | ✅ done (`README.md`/`README_DETAILS.md`) |
   | Example usage | ✅ done |
   | Functionality/API documentation | ✅ done (85+ scripts documented) |
   | Automated tests | ✅ done (`testthat` + CI smoke test) |

   All 7 checklist items now satisfied.
3. ~~`paper.md` structure~~ **UPDATED (2026-08-29)**: JOSS's paper
   format now requires 6 sections, not the 4 this draft originally had
   — Summary, Statement of need, State of the field, **Software
   design**, **Research impact statement**, and **AI usage disclosure**
   are all mandatory (verified directly against JOSS's docs, not
   assumed). All 6 are now present; word count 1342 (within the
   750-1750 limit).
4. ~~Set up a way to compile the draft to verify formatting~~ **DONE
   (2026-08-29)**: [`.github/workflows/draft-pdf.yml`](../.github/workflows/draft-pdf.yml)
   builds a draft PDF via `openjournals/openjournals-draft-action`
   (same `inara` tool JOSS itself uses) on every change to `paper.md`/
   `paper.bib`, uploaded as a GitHub Actions artifact — check the
   Actions tab after a push for the `paper` artifact. This is a
   formatting/citation check only, **not** a submission.
5. Submit via https://joss.theoj.org/papers/new (a GitHub repository URL
   plus this `paper.md` path).

Step 5 (the actual submission) is the only remaining checklist item, but
is intentionally NOT being done yet — see the pause decision at the top
of this file. Re-check ~November 2026.
