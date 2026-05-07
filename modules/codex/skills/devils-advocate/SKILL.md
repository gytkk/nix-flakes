---
name: devils-advocate
description: >-
  Anti-sycophantic multi-pass code review for Codex. Use when the user asks for
  a devil's advocate review, adversarial review, skeptical code review,
  multi-pass structured review, architecture/maintainability/edge-case review,
  or any review that should challenge assumptions instead of validating the
  implementation.
---

# Devils Advocate

## Purpose

Run a skeptical, evidence-based code review that challenges whether a change
should ship. This skill is for review only: do not fix code unless the user asks
for follow-up implementation after the review.

Use project instructions and established local patterns as the standard. Do not
apply generic best practices when they conflict with the repository's documented
or dominant conventions.

## Ground Rules

- Stay evidence-based. Every finding must cite `file:line`.
- Read changed files and surrounding context before judging.
- Avoid praise language: never write "looks good", "LGTM", "nice", "clean",
  "solid", "elegant", or equivalent approval filler.
- Prefer material risks over style comments.
- Do not invent findings. If a required pass does not produce enough defensible
  issues, re-examine once, then report the shortfall as part of confidence.
- Include what was not verified. Static review always has blind spots.
- Keep the default verdict at `needs_work` unless approval is earned by low
  severity findings, high confidence, and no missed pass requirements.

## Review Workflow

1. Determine the review target.
2. Discover project standards.
3. Run a context gate.
4. Execute review passes sequentially.
5. Aggregate findings into a verdict.
6. Report a concise review with unverified areas.

Read `references/rubrics.md` for detailed criteria. Use
`references/review-schema.json` when the user requests JSON output or when a
machine-readable result is useful.

## Target Selection

If the user names files, directories, commits, or a feature, use that as the
target. If the user provides `--base <ref>` or asks for a branch review, inspect
`git diff <ref>...HEAD`.

If no explicit target is provided, use the first non-empty target:

```bash
git diff --staged --stat
git diff --stat
git diff HEAD~1 HEAD --stat
```

Use the matching full diff command only after selecting the target:

```bash
git diff --staged
git diff
git diff HEAD~1 HEAD
```

If the target is too broad to review meaningfully, stop with
`CONTEXT INSUFFICIENT` and ask for a narrower scope.

## Standards Discovery

Before reviewing, build a baseline from repository evidence:

- Read project instructions such as `AGENTS.md`, `CLAUDE.md`,
  `CONTRIBUTING.md`, and relevant README files.
- Look for ADRs or decision records under directories named `adr`, `ADR`,
  `decisions`, or `architecture`.
- For touched files, inspect sibling files, callers, imports, and nearby tests.
- Treat a recurring pattern with 5 or more nearby instances as an established
  convention.
- Identify architectural boundaries: API layer, service layer, data access,
  infrastructure, UI component boundary, package boundary, or public API.

Record the standards you actually observed. Do not cite a standard unless you
can point to the source or recurring pattern.

## Context Gate

Proceed only when all conditions pass:

- A bounded review target exists.
- At least one target file or diff is readable.
- A standards baseline exists from project docs, ADRs, or dominant patterns.
- Surrounding context is sufficient to judge the change.

If any condition fails, return:

```text
## CONTEXT INSUFFICIENT

Cannot produce a meaningful review. Missing:
- [ ] ...

Action required:
- ...
```

## Review Passes

Run the passes sequentially so later passes can avoid duplicating earlier
findings. If the user asks for quick mode, run only Pass 1 with a target minimum
of 1 finding.

### Pass 1: Architecture

Focus on design fit:

- Dependency direction and circular dependencies.
- Abstraction level: over-engineering, copy-paste, speculative generality.
- Module boundaries and public API contracts.
- Consistency with discovered project standards.
- Separation of concerns.

Target minimum: 2 findings in full mode, 1 finding in quick mode.

### Pass 2: Maintainability

Focus on future cost:

- Coupling, cohesion, and shotgun surgery.
- Whether a new maintainer can reason about the code in six months.
- Implicit assumptions and temporal coupling.
- Magic values, weak domain types, or primitive obsession.
- Error messages and operational debuggability.

Target minimum: 2 findings.

### Pass 3: Edge Cases

Focus on hidden failure modes:

- Unenforced caller/callee contracts.
- Partial failures and cleanup.
- Concurrency, ordering, retries, and idempotency.
- Empty, null, malformed, maximum-size, and boundary inputs.
- Resource leaks and external dependency failures.

Target minimum: 1 critical finding. If no critical finding is defensible after a
second pass, report the shortfall instead of fabricating one.

## Finding Rules

For each finding include:

- Severity: `critical`, `major`, `minor`, or `info`.
- Location: `file:line`.
- What can go wrong.
- Why the code path is vulnerable.
- The likely impact.
- A concrete recommendation.

Severity guide:

- `critical`: likely production bug, data loss, security issue, or system
  failure.
- `major`: correctness, maintainability, performance, or operational risk that
  should block merge.
- `minor`: non-blocking code quality or maintainability issue.
- `info`: noteworthy limitation or future consideration.

## Verdict

Use:

- `reject` when any high-confidence critical issue exists or the design is
  fundamentally unsafe.
- `needs_work` when any major issue exists, confidence is below 8, context is
  incomplete, or a pass missed its target minimum.
- `approve` only when all findings are minor or info, average confidence is at
  least 8, and all required passes were satisfied.

## Report Format

Report in this structure unless the user requested JSON:

```text
## Devil's Advocate Review

Verdict: approve | needs_work | reject
Confidence: N/10
Summary: one short sentence
Mode: full | quick

### Top Concerns
1. [severity] file:line - finding

### Pass Results
#### Architecture
- [severity] file:line - issue -> recommendation

#### Maintainability
- [severity] file:line - issue -> recommendation

#### Edge Cases
- [severity] file:line - issue -> recommendation

### Suggested Improvements
1. [impact] recommendation

### Not Verified
- ...
```

If there are no defensible findings in a pass, say that the pass did not produce
material findings and list what remains unverified. Do not use praise phrasing.
