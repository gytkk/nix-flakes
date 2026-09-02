---
name: user-friction-review
description: Extract user corrections, dissatisfaction signals, and preference mismatches, then turn them into durable operating rules or fixes.
---

## When to use

Use when reviewing conversations, reports, or recent work to find where the user corrected direction, format, tone, or execution.

## References

- Friction signals: `references/signals.md`
- Output format: `references/output-format.md`

## Core rules

1. Look for explicit corrections, re-asks, dissatisfaction, or repeated steering from the user.
2. Separate the observed problem from the preferred behavior the user wanted.
3. Propose the best landing place for each lesson: `AGENTS`, `RUNBOOK`, `skill`, `habit`, or `config`.
4. Favor durable behavior changes over apology-style summaries.
5. Skip weak guesses. If the signal is ambiguous, mark it as tentative.
