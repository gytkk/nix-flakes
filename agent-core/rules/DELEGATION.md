# Delegated execution

- Delegate a bounded unit when its result can change a decision or verification and the parent can make useful progress concurrently. Weigh that benefit against dispatch, context gathering, and review; keep routine edits, dependent lookups, and already-resolved questions in the parent. One worker is sufficient when there is one independent question.
- Run only non-overlapping units in parallel. Assign explicit file ownership to writing workers, keep conflicting edits sequential, wait for results, inspect their evidence, then integrate and validate before reporting completion. Finish only when every delegated unit is completed, blocked with a concrete reason, or intentionally cancelled because it is no longer needed.
