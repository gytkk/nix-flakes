---
name: parallel-research-merge
description: Coordinate bounded research scopes, using parallel workers when available and sequential execution otherwise, then reconcile findings and implement one verified result for complex code changes.
---

# Parallel Research Merge

## When to Use

Use this skill when a code task benefits from multiple bounded investigation axes before one agent produces the final implementation.

Typical triggers:
- the user explicitly asks for subagents, delegation, parallel research, or worker agents
- the task has 2 or more independent research axes, options, or risk surfaces
- the main agent can keep final design and implementation ownership while delegating sidecar investigation

Do not use this skill for simple single-file edits, purely sequential blockers, or tasks where research scopes cannot be separated cleanly.

## Core Rules

1. Keep one owner. The main agent owns scope, sequencing, merge decisions, implementation, verification, and the final commit.
2. Check capabilities first. Use parallel workers only when a worker or subagent mechanism exists; otherwise execute the same bounded scopes sequentially.
3. Delegate only separable work. Split by question, subsystem, or risk area. Do not send multiple workers to do the same broad task unless the goal is explicit adversarial comparison.
4. Bound every worker or sequential pass. Give each worker a narrow objective, owned paths, forbidden paths, expected output shape, and a verification target when relevant.
5. Prefer research over edits first. Workers should usually gather evidence and recommend a path before the main agent changes files.
6. Reconcile before coding. Compare worker findings, discard unsupported claims, and choose the smallest viable implementation before editing.
7. Verify claims locally. Treat worker output as input, not truth. Re-read referenced files, inspect diffs, and run checks before accepting recommendations.
8. Keep the final diff coherent. The main agent should merge or reimplement results into one intentional change set instead of stitching together unreviewed worker output.

## Workflow

1. Decide whether the task benefits from multiple independent research axes.
2. Check whether a worker or subagent mechanism is available.
3. Define 2 to 3 disjoint scopes using `references/contracts.md`.
4. Dispatch the scopes in parallel when the mechanism exists; otherwise execute them sequentially in the main thread.
5. Collect findings and compare evidence, not confidence.
6. Choose one implementation direction and explain rejected alternatives.
7. Implement the final change in the main thread.
8. Run relevant verification and only then commit.

## Quick Reference

- Parallel-worker, sequential-pass, and main-agent contracts: `references/contracts.md`
