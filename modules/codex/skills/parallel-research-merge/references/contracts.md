# Contracts for `parallel-research-merge`

## Worker Selection Rules

Use 2 workers by default. Use 3 only when the task clearly has three disjoint concerns.

Good splits:
- codebase survey vs implementation option comparison
- backend behavior trace vs frontend impact trace
- root-cause investigation vs test and verification design
- current config audit vs migration plan

Bad splits:
- three workers all exploring the full repo
- workers editing the same files without explicit ownership
- delegating the critical path while the main agent waits passively

## Worker Prompt Template

Use this structure and fill every field.

```text
You are a research worker supporting a main coding agent.

Objective:
- <one narrow question to answer>

Scope:
- Read focus: <directories/files>
- Allowed edits: <usually none, or an explicit bounded set>
- Forbidden paths: <paths owned by main or other workers>

Deliverable:
Return exactly these sections:
Summary:
Evidence:
- path:line -> finding
Recommendation:
Changed files:
Verification:
Risks / uncertainty:

Rules:
- Do not broaden scope beyond the objective.
- Do not revert or rewrite unrelated work.
- If evidence is weak or conflicting, say so plainly.
- Prefer concrete file evidence over speculation.
```

## When Workers May Edit

Default to read-only investigation first.

Allow worker edits only when all of these are true:
- the owned files are disjoint from other workers
- the expected change is mechanically local
- the main agent still plans to re-read and integrate the result before final verification

When allowing edits, add these lines to the worker prompt:

```text
Allowed edits are limited to: <owned paths>
Do not touch any other file.
Do not commit.
```

## Main-Agent Merge Checklist

Before implementing:
- verify every important claim against the cited file paths
- identify conflicts between workers explicitly
- choose one path and record why the alternatives were rejected
- collapse overlapping recommendations into one small design decision

During implementation:
- keep the final diff authored or re-reviewed by the main agent
- prefer reimplementation over blind copy-paste from workers
- preserve repo rules, file ownership boundaries, and existing patterns

Before finishing:
- inspect the final diff end to end
- run the relevant checks for the chosen implementation path
- mention unresolved risk if a check could not run

## Escalation Rules

Stop using this pattern and return to single-agent work when:
- the task turns out to be sequential after all
- worker findings converge on the same answer with no extra value from more delegation
- conflicting edits or hidden dependencies make ownership unclear
- the remaining work is just local implementation and verification

## Example Split

Task: add a new Codex behavior rule without bloating always-on guidance.

- Worker A: inspect current Codex skill layout and repo-managed deployment path
- Worker B: inspect existing agent instruction files and identify what should stay global versus move into a skill
- Main agent: choose final skill structure, author files, wire discovery guidance, validate, and commit
