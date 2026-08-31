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
- Store the canonical portable skill under `agent-core/skills/` and declare its
  runtime exposure in `agent-core/manifest.toml`. Do not add a runtime-local
  copy.
- Trim unused scaffold files, keep the skill focused, and align it with
  repository conventions before committing.
- Use the repository-managed `parallel-research-merge` skill when a task needs
  bounded parallel investigation before one main agent produces the final
  implementation.
- Do not rely on always-loaded instructions alone for multi-worker
  orchestration. When delegation matters, use a skill with an explicit worker
  contract and merge checklist.

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
