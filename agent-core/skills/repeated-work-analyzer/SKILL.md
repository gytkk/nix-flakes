---
name: repeated-work-analyzer
description: Detect repeated tasks, classify the best reusable form, and shape justified skill candidates from concrete evidence.
---

## When to use

Use for retrospective analysis of recent sessions, files, or reports when you need to find repeated work worth formalizing. Do not use it to author the final artifact unless the user also asks for implementation.

## References

- Classification and evidence rules: `references/classification.md`
- Output format: `references/output-format.md`
- Skill candidate shape: `references/skill-candidates.md`

## Core rules

1. Focus on patterns that appeared at least twice, or once with strong signs they will recur.
2. For each candidate, capture the repeated task, evidence, best packaging form (`skill`, `automation`, `template`, or `runbook`), and priority.
3. Prefer concrete observations over vague impressions. Cite files, sessions, or user requests when available.
4. Distinguish orchestration work from reusable analysis work. Recommend `automation` for time-based workflows and `skill` for reusable procedures.
5. When `skill` is the best form, shape the smallest useful first version using `references/skill-candidates.md`.
6. Keep the result compact and decision-oriented. Do not draft the final artifact unless explicitly asked.
