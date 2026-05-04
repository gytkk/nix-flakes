---
name: parallel-research-merge
description: Coordinate bounded parallel research workers, reconcile conflicting findings, and implement one verified result for complex code changes.
---

# Parallel Research Merge

## When to Use

Use this skill when a code task benefits from parallel investigation before one agent produces the final implementation.

Typical triggers:
- the user explicitly asks for subagents, delegation, parallel research, or worker agents
- the task has 2 or more independent research axes, options, or risk surfaces
- the main agent can keep final design and implementation ownership while delegating sidecar investigation

Do not use this skill for simple single-file edits, purely sequential blockers, or tasks where worker scopes cannot be separated cleanly.

## Core Rules

1. Keep one owner. The main agent owns scope, sequencing, merge decisions, implementation, verification, and the final commit.
2. Delegate only separable work. Split by question, subsystem, or risk area. Do not send multiple workers to do the same broad task unless the goal is explicit adversarial comparison.
3. Bound every worker. Give each worker a narrow objective, owned paths, forbidden paths, expected output shape, and a verification target when relevant.
4. Prefer research over edits first. Workers should usually gather evidence and recommend a path before the main agent changes files.
5. Reconcile before coding. Compare worker findings, discard unsupported claims, and choose the smallest viable implementation before editing.
6. Verify claims locally. Treat worker output as input, not truth. Re-read referenced files, inspect diffs, and run checks before accepting recommendations.
7. Keep the final diff coherent. The main agent should merge or reimplement results into one intentional change set instead of stitching together unreviewed worker output.

## Workflow

1. Decide whether the task is truly parallelizable.
2. Choose 2 to 3 workers with disjoint scopes.
3. Send each worker a bounded contract from `references/contracts.md`.
4. Collect findings and compare evidence, not confidence.
5. Choose one implementation direction and explain rejected alternatives.
6. Implement the final change in the main thread.
7. Run relevant verification and only then commit.

## Quick Reference

- Worker and main-agent contracts: `references/contracts.md`
