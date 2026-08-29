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
4. **Compile locally to verify formatting** before submitting — JOSS
   provides a Docker-based `whedon`/`inara` preview tool and a GitHub
   Action; neither has been run against this draft yet.
5. Submit via https://joss.theoj.org/papers/new (a GitHub repository URL
   plus this `paper.md` path).

Steps 4-5 were not done as part of this pass — everything else on the
"before submission" list is now done.
