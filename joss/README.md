# JOSS submission materials

**Status (2026-08-29): first draft, not submitted.** Target venue chosen
by the user on 2026-08-29 (see `BACKLOG.md`, P3 status).

- [`paper.md`](paper.md) — the actual JOSS submission text (750-1750
  words: Summary, Statement of need, Comparison to existing software,
  Acknowledgements). JOSS reviews the **software**, not a full empirical
  study — the detailed evaluation (Level 1/2 results, ablations,
  limitations) deliberately lives in [`../PAPER_DRAFT.md`](../PAPER_DRAFT.md)
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
2. **Repository readiness**, per JOSS's own review checklist (not yet
   verified against this repo specifically): a clear installation
   procedure, example usage, community guidelines (contributing/support/
   how to report issues), an OSI-approved license file, and a version
   number/release process. `README.md`/`README_DETAILS.md` cover usage;
   license and contribution-guideline files have not been checked
   against JOSS's checklist yet as part of this pass.
3. **Compile locally to verify formatting** before submitting — JOSS
   provides a Docker-based `whedon`/`inara` preview tool and a GitHub
   Action; neither has been run against this draft yet.
4. Submit via https://joss.theoj.org/papers/new (a GitHub repository URL
   plus this `paper.md` path).

Steps 2-4 were not done as part of this pass.
