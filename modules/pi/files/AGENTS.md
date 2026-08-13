# Pi-specific rules

These instructions extend the shared global agent rules with Pi-specific
behavior.

## Skill routing

- For every request that writes, reviews, or refactors code, read and apply the
  `karpathy-guidelines` skill before proceeding.
- Use `parallel-research-merge` for bounded multi-axis investigation when the
  task benefits from independent research scopes.
- Use parallel workers only when the session exposes an executable worker or
  subagent tool. Otherwise, run the same scopes sequentially.

## Repository tools

- Use `read` to inspect files and `edit` for precise manual changes.
- Formatting commands and generated outputs do not require `edit`.

## Runtime safety

- Pi is not sandboxed by default. Tools, extensions, and commands run with the
  current user's filesystem and network permissions.

## Pi skills

- Follow Pi's Agent Skills format: a focused `SKILL.md` with valid `name` and
  `description` frontmatter.
- Store repository-managed Pi skills under `modules/pi/skills/` so Home Manager
  exposes them at `~/.pi/agent/skills/`.
- Keep skills focused, trim unused files, and align them with repository
  conventions.

## Subagent context

- Default delegated runs to fresh context and pass a compact task contract with
  the required files, decisions, constraints, and validation.
- Use forked context only when the parent transcript is essential and cannot be
  summarized safely.
- When a child persists a substantial output artifact, prefer `file-only`
  output and read only the needed portions. Use inline output for short results
  or when no output path is available.
