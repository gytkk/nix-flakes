# Codex-specific rules

These instructions extend the shared global agent rules with Codex-specific
behavior.

## Exploration and tool use

- Use sequential reads only when the next file cannot be identified until the
  prior result is known.
- Use `apply_patch` for manual file edits. Formatting commands and generated
  outputs do not require `apply_patch`.

## Codex skills

- When creating or updating repository-managed skills, use Codex's built-in
  `$skill-creator` as a scaffold when it is available.
- Store the canonical shared skill under `agent-core/skills/` and declare its
  runtime exposure in `agent-core/manifest.toml`.
- Express required capabilities in the shared skill. Keep Codex packages,
  settings, plugins, and optional UI metadata in `modules/codex/`.
- Trim unused scaffold files, keep the skill focused, and align it with
  repository conventions before committing.
- Use the repository-managed `parallel-research-merge` skill when a task needs
  bounded parallel investigation before one main agent produces the final
  implementation.
- Do not rely on always-loaded instructions alone for multi-worker
  orchestration. When delegation matters, use a skill with an explicit worker
  contract and merge checklist.

## Model routing

- At the start of substantive work, dispatch bounded, independent exploration, research, implementation, or verification as soon as its inputs are available. Look for delegation opportunities before broad codebase reads or implementation, and reassess when new independent work appears. The main agent owns user interaction, requirements, decisions, integration, and final validation while workers handle the delegated units.
- Keep short answers and one-step low-risk edits in the main agent. Spawn a worker only for a concrete unit that can run alongside useful main-agent work; keep dependent work sequential and give writing workers disjoint file ownership.
- Use native `spawn_agent` calls with explicit `model` and `reasoning_effort` values selected for the unit in the table below. Treat the table's effort as a starting point, not a requirement to use every model on every task.

| Model | Delegated work | Starting effort |
| --- | --- | --- |
| `gpt-5.6-luna` | Narrow, clear, repeatable tasks such as locating symbols, running a known check, or applying a mechanical edit | `low` |
| `gpt-5.6-terra` | Read-heavy exploration, broad scans, log triage, and supporting-document analysis that return concise evidence | `medium` |
| `gpt-5.6-sol` | Normal implementation, testing, research synthesis, and multi-step analysis with a defined scope | `medium` |
| `gpt-6-astra` | Ambiguous work, complex design, deep debugging, security-sensitive review, and decisions with costly failures | `high` |

- Use `low` for direct lookups and deterministic checks, `medium` for ordinary reasoning, and `high` for tracing complex logic, checking assumptions, or analyzing edge cases. Reserve `xhigh` or higher supported efforts for especially difficult unresolved reasoning. A higher effort does not replace selecting a model suited to the task's ambiguity and failure cost.
- Escalate when a worker reports unresolved assumptions, conflicting evidence, or a failed validation it cannot explain. Route wider evidence gathering to terra, implementation or analysis beyond a narrow task to sol, and unresolved design or correctness questions to astra. Pass the evidence and failed approaches to the next worker so it can continue the investigation.
- A model or effort override requires `fork_turns = "none"` or a bounded positive turn count. Include the relevant user requirements, constraints, owned paths, and acceptance criteria in the worker task. Use a full-history fork only when the inherited context is required, and accept the inherited parent model and effort in that case.
- Inspect worker evidence and changed files before integration. Resolve conflicting results and run the relevant checks before reporting completion. If a requested model or effort is unavailable, select a supported alternative suited to the unit and report the fallback.

## Sandbox awareness

- Codex runs with `sandbox_mode = "danger-full-access"` in this setup.
- Exercise caution because commands have full filesystem and network access.
- Do not use destructive commands unless explicitly approved.

## Exec mode

- Assume non-interactive execution by default, for example `codex exec ...`.
- Make steps reproducible and deterministic.
- Prefer explicit command flags and stable output formats.
- Validate each major step with command output, file diffs, or checks.

## Structured output

- When `--output-schema` is provided, return strictly valid JSON that matches
  the schema.
- Do not add Markdown or prose outside the required structured output.
- Keep fields complete, accurate, and machine-readable.
