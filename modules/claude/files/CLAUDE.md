# CLAUDE.md

## Skill Discovery

- Explore available skills first — look for built-in, installed, or repo-provided skills that match the user's request before improvising.
- Use the best-fit skill when one exists, and follow its workflow.
- If no skill fits, proceed normally and state that choice when it matters.

## Inquiry Protocol

- If missing context cannot be recovered locally and guessing would be risky, ask the user immediately.
- If the answer is likely available from the repo, local files, logs, or adjacent workspace context, inspect those first and come back with a narrower question only if a real blocker remains.

## Git & Commit Workflow

1. Complete one logical change
2. Commit immediately
3. One logical change per commit

**Commit rules**:

- [Conventional Commits](https://www.conventionalcommits.org/) format (e.g., `feat:`, `fix:`, `docs:`)
- Reference git commit history to maintain consistent message style
- Imperative mood (e.g., "Add feature" not "Added feature")
- Do NOT push unless explicitly requested
- Treat `finish it`, `wrap this up`, `handle the rest`, PR preparation, test success, or local commits as insufficient for push permission. Push only when the current conversation explicitly asks for remote push.

**PR sync after push** (mandatory whenever a push is performed):

- Immediately after a successful push, check the branch for an open PR with `gh pr view --json number,title,body,state` (omit the number — it resolves from the current branch).
- If a PR exists, judge whether the pushed change made the current title or body stale or inaccurate: scope changes (renamed files, dropped/added features, switched approach, new follow-ups), invalidated test plan items, broken file/link references, or a now-misleading summary all count as stale.
- When stale, update via `gh pr edit --title "..." --body "$(cat <<'EOF' ... EOF)"` in the same turn as the push. Preserve any prior sections that are still accurate; rewrite only the parts that diverged.
- When the push is purely additive and the existing title/body still describes the branch correctly (e.g., follow-up fix matching the existing scope, typo-only commit), leave the PR alone and say so in one line.
- This sync is part of the authorized push action — no separate confirmation needed. If no PR exists, skip silently.

## Planning & Approval

**Simple changes** (1–2 file simple edits, low risk):

- Apply immediately → Confirm with diff and verification results

**Complex changes** (3+ files, new feature/module, public interface changes, etc.):

- Use `EnterPlanMode` to design the approach, then `ExitPlanMode` to submit for user approval
- If the user provides feedback, revise the plan accordingly
- If plan mode tools are unavailable: Present the plan as text and request user approval

## Worktree Workflow

By default, work on the current branch. Only use git worktree when the user explicitly requests it.
Individual projects may override this policy (e.g., banning worktree entirely). Project-level CLAUDE.md rules take precedence.

**Worktree agent permissions:** Prefer the normal permission flow or `acceptEdits` in repo-local worktrees. Only use `bypassPermissions` in genuinely isolated environments such as containers or VMs.

- Before editing in parallel agent or worktree flows, verify the current worktree path and branch first. If you are not in the intended isolated checkout, stop before making changes, restore any accidental edits, and report the contamination clearly.

## Looping Plugins

- When using Ralph Loop or any self-repeating plugin, always set a bounded stop condition such as `--max-iterations`, an explicit `--completion-promise`, or both.
- Do not start an unbounded loop with no exit condition. If a loop becomes stuck, stop and clear the loop state instead of asking the user to keep fighting the hook.

## Critical Rules

- First, deeply understand and think about what you want to achieve with your code.
- Always follow existing code patterns and module structure in your working directory.
- Be concise. Commit small, frequent changes for readable diffs.
- Proactively use web search if there is any uncertainty or lack of knowledge.
- Always use `rg` (ripgrep) instead of `grep`. This applies to all contexts: shell commands, scripts, and Nix expressions.
- Never commit secrets, credentials, or API keys.

## Notion

- Use the `ntn` CLI for Notion-related actions (`ntn pages`, `ntn datasources`, `ntn api`, etc.).
- Do not use, add, or depend on a Notion MCP server.

## Writing Code

- Prefer to write docstring and unit tests first (TDD approach).
- No 'any' type hints, use specific types.

## Scope Discipline

- Don't add features, refactor, or introduce abstractions beyond what the task requires. A bug fix doesn't need surrounding cleanup, and a one-shot operation usually doesn't need a helper.
- Don't design for hypothetical future requirements — do the simplest thing that works well. Avoid premature abstraction, but avoid half-finished implementations too.
- Don't add error handling, fallbacks, or validation for scenarios that cannot happen. Trust internal code and framework guarantees; validate only at system boundaries (user input, external APIs).
- Don't use feature flags or backwards-compatibility shims when you can just change the code.

## Subagent Delegation

- Delegate independent subtasks to sub-agents and keep working while they run; prefer asynchronous/background sub-agents over spawn-and-block.
- Intervene if a sub-agent goes off track or is missing relevant context.
- For long-running builds, verify with fresh-context sub-agents on a cadence rather than relying on self-critique.

## Python

- Always use `uv run` instead of `python` or `python3` when executing Python scripts or commands.
- If dependency errors occur, run `uv sync` first to install project dependencies.
- Examples:
  - Use `uv run script.py` instead of `python script.py`
  - Use `uv run -m pytest` instead of `python -m pytest`
  - Use `uv run -m pip install` instead of `pip install`

## Security

- Never commit secrets, credentials, or API keys.
- Use environment variables or secret management tools for sensitive data.
- Review dependency changes for known vulnerabilities before committing.

## Testing

- Write tests for new features before or alongside implementation.
- Run existing tests before committing when the project has a test suite (e.g., `uv run -m pytest`, `npm test`).
- For Nix-only projects, defer to project-specific build/test rules.
- Cover edge cases and error scenarios in tests.

## Code Review

- Focus on: readability, maintainability, security, and performance.
- Suggest improvements constructively with clear explanations.
- Check for edge cases and proper error handling.
- Verify that changes align with existing code patterns.

## Documentation

- Update README.md when adding new features or changing behavior.
- Add docstrings/comments for complex logic only when necessary.
- Keep documentation in sync with code changes.
- Do NOT create one-off or temporary documentation files.

## Prompts & Skills Authoring

- When writing or updating prompts, skills, or agent instructions, state the goal and constraints rather than enumerating step-by-step procedures — over-prescriptive scaffolding reduces output quality on current models.
- When migrating an existing prompt or skill to a newer model, prefer removing old step-by-step scaffolding and comparing results before adding new instructions.
- Give the reason behind a request, not just the request, when dispatching sub-agents or writing reusable prompts (what the larger task is, who it is for, what the output enables).

## Error Handling

- Always handle errors gracefully; avoid silent failures.
- Use specific error types when possible.
- Log errors with enough context for debugging.
- Provide meaningful error messages to users.

## Discovery and Reporting

- Before reporting progress, audit each claim against a tool result from this session. Only report work you can point to evidence for; if something is not yet verified, say so explicitly.
- Report outcomes faithfully: if tests fail, say so with the output; if a step was skipped, say that; when something is done and verified, state it plainly without hedging.
- During discovery, diagnosis, or question-driven planning, do not claim the work is complete or that all needed information has been gathered until you have actually finished collecting it.
- Avoid premature final-report phrasing after partial reads, intermediate tool output, or user answers that still leave open decisions.
- If the task is still exploratory, keep the response explicitly in-progress and continue the questioning or investigation flow instead of switching into a wrapped-up summary voice.
