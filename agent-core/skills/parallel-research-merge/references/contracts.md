# Worker contract and integration

## Before dispatch

Split by evidence that can be investigated independently, such as runtime installation state versus session usage, or backend behavior versus a separately specified client contract. Keep dependent questions sequential. The main agent retains a useful task and final decision ownership; a second worker is optional.

Give each worker this compact contract, adapting the form to the task:

```text
Question and decision served: <what to establish and what its answer enables>
Evidence scope: <files, subsystem, dataset, or primary sources>
Allowed edits: <none by default, otherwise exclusive owned paths>
Constraints: <relevant user requirements and other workers' boundaries>
Investigation bound: <a finite source set, sample, check, or time limit>
Stop when: <question answered, bound reached, or blocking evidence identified>
Return: <a short conclusion, decisive path:line/source evidence, checks and uncertainty>
Result budget: <length appropriate to the question; link large artifacts only if requested>
```

Choose a concrete bound that can be checked. For example, inspect the two named runtime adapters and installed skill manifests, or sample the last 14 complete days from the named repository's root sessions. On a blocker, return the missing evidence and the smallest useful next step. Expand the scope only after the main agent decides the unanswered question still matters.

Workers report what they verified and separate evidence from inference. Include changed files only when edits were allowed. Workers do not delegate further or commit unless the main agent explicitly assigns that responsibility.

## Editing and interruption

Permit worker edits only for a bounded change with exclusive file ownership and checks the main agent can review. Otherwise request findings and let the main agent implement. Reassign shared files sequentially when dependencies emerge.

Cancel or redirect work that duplicates verified findings, depends on unavailable upstream results, or no longer affects the decision. Reconcile any partial edits and worker status before finishing; a timeout is an unresolved result, not evidence that nothing was found.

## Integrating evidence

Verify claims that affect the conclusion, scope, or implementation. When workers disagree, compare the referenced versions, conditions, and checks; run the smallest discriminating check before choosing an answer. If the conflict cannot be resolved, preserve the uncertainty in the result.

Keep a short contribution note, using prose or a table as appropriate:

| Evidence | Disposition and reason | Effect on the task |
| --- | --- | --- |
| Source or check supporting a worker finding | Accepted, rejected, or unresolved, with the verification basis | Decision changed, check added, risk retained, or no additional value |

The note belongs in the existing working summary or final response, not a new repository report. Merge overlapping findings once. Inspect the final diff for authorized implementation, complete relevant checks, and account for every worker as completed, blocked, or cancelled.
