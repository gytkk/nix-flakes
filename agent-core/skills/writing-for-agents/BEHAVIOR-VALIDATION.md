# Validate discovery and behavior

Read this reference when creating a skill, changing its description or scope, or changing instructions that existing examples or evaluations rely on. Text and frontmatter validation establish structural correctness; they do not establish that a runtime discovers the skill or that the agent follows it.

## Discovery cases

Start with a small case set covering these branches, then expand only where failures or ambiguity justify it:

- Positive requests: an explicit request and a natural paraphrase that require the skill.
- Near misses: requests with overlapping vocabulary that belong to an adjacent workflow or do not need this skill.
- A boundary case: a request whose keywords point to the skill but whose explicit scope changes the correct routing.

Record the expected routing and its reason before testing. Test automatic discovery without naming the target skill in the user request. An explicit invocation checks loading and execution, not whether the description triggers correctly. Several skills may be appropriate for one request; inspect the whole relevant selection sequence rather than only the first selected skill.

Use the target runtime's actual discovery and loading mechanism when a safe, authorized test environment is available. Distinguish these outcomes:

| Outcome | Required evidence |
| --- | --- |
| Loaded | The runtime confirms successful loading, or its trace shows that the skill body entered the agent context |
| Requested but not loaded | Selection was attempted but loading failed or lacked confirmation |
| Not selected | A completed, valid observation of the selection stage contains no target selection |
| Unobserved | Authentication, setup, timeout, trace visibility, or another failure prevented a valid observation |

A tool argument or an agent's claim that it used a skill does not establish successful loading. Count an unobserved case separately from a correct negative. Runtime-specific launch strings, trace parsers, credentials, and cutoff mechanisms belong to the runtime integration, not shared guidance.

When runtime testing is unavailable, review the case set against the description and report that discovery is unverified. Keep evaluation bounded: use fixtures or read-only resources and stop at selection when that is the property under test. Do not execute live queries, writes, or billable workflows just to prove a trigger.

## Behavior and change impact

For a substantive workflow change, give an independent evaluator the instruction, a realistic request, and the minimum raw artifacts needed to perform it. Keep expected answers and author conclusions out of the evaluator's input. Explicit invocation is appropriate here because this pass tests behavior after loading. Compare the actual result and artifacts with the task's acceptance criteria, not headings or wording.

Review relevant existing examples and evaluations against the changed rule, including maintained cases outside the current diff. Classify any discrepancy:

- Still valid: the case exercises supported behavior and its expected result still holds.
- Routing risk: the case remains answerable, but the changed pointer may select the wrong workflow or omit a required one.
- Broken by the change: a referenced path, definition, capability, or expected behavior is no longer valid.
- Pre-existing: the mismatch also exists under the baseline instructions.

Correct new regressions or explain an intentional contract change. Preserve the strength of existing checks; update expected outputs only when the new behavior is justified. Report structural checks, discovery evidence, and behavioral evidence separately so a passing format check does not imply a tested workflow.
