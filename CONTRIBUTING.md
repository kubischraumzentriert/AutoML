# Contributing

Thanks for your interest in this project. This is primarily a
single-maintainer research/competition template — the guidance below
describes how contributions, bug reports, and support requests actually
get handled in practice, not a generic corporate process.

## Reporting a bug or problem

Please [open a GitHub issue](https://github.com/kubischraumzentriert/AutoML/issues/new)
and include:

- Which script(s) or module(s) are affected (e.g. `015_target_leak_audit.R`).
- Your R version and the output of `sessionInfo()` if the problem looks
  environment-related.
- A minimal reproduction if possible — ideally against the synthetic CI
  fixture (`generate_fixture.R`) rather than your own private data, so
  the problem can actually be reproduced by someone else.
- What you expected to happen vs. what actually happened.

There is no dedicated security-disclosure process at this time; a
security-relevant bug can be reported the same way as any other issue.

## Seeking support / asking a question

GitHub Issues is the only support channel for this project — please
open an issue with your question rather than emailing directly. Since
this is maintained by a single person alongside other work, there is no
guaranteed response time, but issues are read.

## Proposing a change or new module

Pull requests are welcome, with one important caveat specific to how
this template evolves: a new diagnostic module or workflow change is
only merged into the shared, reusable part of the template once it has
been confirmed on **at least two independent projects** (or shown to be
a provable no-op — see [`adr/003-backport-after-confirmation.md`](adr/003-backport-after-confirmation.md)
for the full reasoning). This exists specifically to prevent the
template from overfitting to the idiosyncrasies of whichever single
project motivated the change, and applies to the maintainer's own
changes just as much as to external contributions. In practice this
means: a PR that adds something genuinely new to the shared template
(rather than fixing an existing bug, improving documentation, or fixing
CI) is more likely to be discussed and iterated on than merged
immediately — that is expected, not a rejection.

Before opening a PR that touches R code:

1. Read the relevant section(s) of [`AGENTS.md`](AGENTS.md) and
   [`BACKLOG.md`](BACKLOG.md) for context on current direction and
   open work.
2. Run the full test suite (`Rscript tests/testthat.R`) and make sure it
   is green — the CI pipeline (badge in [`README.md`](README.md)) runs
   the same suite plus an end-to-end smoke test against a synthetic
   fixture on every push/PR, and both must pass.
3. Add or update tests for any new/changed behavior in
   `tests/testthat/` — untested behavior is treated as unverified, not
   as trusted.
4. Keep commits focused; a PR that mixes an unrelated refactor with the
   actual change is harder to review and more likely to be asked to
   split.

## Documentation-only contributions

Fixes to documentation (typos, unclear explanations, broken links) do
not need the two-project-confirmation process above and are generally
welcome as direct PRs.
