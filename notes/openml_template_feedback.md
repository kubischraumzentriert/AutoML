# OpenML Template Feedback

This note summarizes the most useful learnings from the `openml-adult-income` workflow run and the changes that are worth feeding back into the main `AutoML` template.

## Short version

The strongest reusable ideas are:

1. Add a standard binary-task helper that sets the positive class at task creation time.
2. Normalize character columns before task construction so `mlr3` never sees unsupported `character` features.
3. Make `ranger` tuning a first-class optional step in the template, not a one-off project tweak.
4. Keep an encoding pipeline for linear / boosting learners as an explicit alternate path.
5. Document the model-selection rule clearly, especially when AUC and LogLoss disagree a little.

## What we observed

- The first end-to-end OpenML workflow run failed because raw `character` columns were passed into an `mlr3` classification task.
- After converting characters to factors up front, the workflow became stable.
- `classif.ranger` was the strongest baseline.
- `classif.ranger_tuned` improved AUC slightly and became the selected model.
- `classif.glmnet` and `classif.xgboost` worked well enough to remain useful alternates, but they did not beat the tuned Ranger on this dataset.
- AUC and LogLoss did not always move together, so the selection rule should stay explicit.

## Proposed template changes

### 1. Add a binary task helper with positive-class support

Create or standardize a helper like:

```r
make_task <- function(data, task_id, target_col, positive_class = NULL) {
  ...
}
```

Why this helps:

- Binary workflows no longer need ad hoc positive-class handling later.
- AUC-based evaluation becomes less fragile and more readable.
- The same helper can still support multiclass tasks by keeping `positive_class = NULL`.

### 2. Normalize `character` columns before task creation

The template should convert all character columns to factors before building the `mlr3` task.

Why this helps:

- Prevents the common `unsupported feature types: character` error.
- Makes the workflow more deterministic.
- Keeps the task construction function in one known-good shape.

### 3. Add a reusable tuned-Ranger candidate

The template should include a candidate like `classif.ranger_tuned` that wraps:

- `mtry.ratio`
- `min.node.size`
- `sample.fraction`

with a small, conservative tuning budget.

Why this helps:

- Ranger is a strong default for tabular OpenML tasks.
- Tuning often gives a real improvement over the untuned baseline.
- The template can expose the tuning step as an option, not a hard requirement.

### 4. Keep the encoding path explicit for linear and boosting learners

The `encode + scale` route for learners like `glmnet` and `xgboost` should remain available as a separate path.

Why this helps:

- Some datasets are still better served by linear or boosted models.
- The template gains a clean alternative without making the default pipeline more complex.

### 5. Make model selection rules explicit

The template should say clearly how ties or near-ties are handled.

Suggested rule:

1. Optimize AUC first.
2. Use LogLoss as a secondary signal.
3. Use Accuracy only as a tie-breaker or sanity check.

Why this helps:

- Avoids ambiguity when different metrics disagree slightly.
- Makes the workflow easier to explain to another reviewer.
- Keeps the selection rule stable across projects.

## Suggested backport order

If this gets merged into the main template, I would do it in this order:

1. Character-to-factor normalization.
2. Positive-class-aware task helper.
3. Optional tuned Ranger branch.
4. Documentation update in `WorkflowDescription.md`.
5. Optional review of the candidate list for future OpenML projects.

## Review questions for Claude

1. Is the positive-class helper generic enough for both binary and multiclass projects?
2. Should tuned Ranger be a default candidate or an opt-in branch?
3. Do we want the template to keep the encoding path in the main workflow, or only as a documented fallback?
4. Is the AUC-first selection rule the right default for this template family?

