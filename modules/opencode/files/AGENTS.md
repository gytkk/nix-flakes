# AGENTS.md

## Critical Rules

- First, deeply understand and think about what you want to achieve with your code.
- Always follow existing code patterns and module structure in your working directory.
- Be concise. Commit small, frequent changes for readable diffs.
- Proactively use web search if there is any uncertainity or lack of knowledge.

## Writing Code
- Prefer to write docstring and unit tests first (TDD approach).
- No 'any' type hints, use specific types.

## Python

- Always use `uv run` instead of `python` or `python3` when executing Python scripts or commands.
- If dependency errors occur, run `uv sync` first to install project dependencies.
- Examples:
  - Use `uv run script.py` instead of `python script.py`
  - Use `uv run -m pytest` instead of `python -m pytest`
  - Use `uv run -m pip install` instead of `pip install`

## Git

> **IMPORTANT**: After completing each self-contained, logical change, immediately
> commit it locally using `/git-commit`. Do NOT batch multiple unrelated changes.

- Commit often with small, focused changes.
- Write clear, descriptive commit messages.
- Prefer [Conventional Commits](https://www.conventionalcommits.org/) format (e.g., `feat:`, `fix:`, `docs:`).
- Also check git commit history for examples of good commit messages.
- Write commit messages in imperative mood (e.g., "Add feature" not "Added feature").
- Keep commits atomic: one logical change per commit.
- Do NOT push unless explicitly requested.

## Security

- Never commit secrets, credentials, or API keys.
- Use environment variables or secret management tools for sensitive data.

## Testing

- Write tests for new features before or alongside implementation.
- Run existing tests before committing (e.g., `uv run -m pytest`, `npm test`).
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

## Error Handling

- Always handle errors gracefully; avoid silent failures.
- Use specific error types when possible.
- Log errors with enough context for debugging.
- Provide meaningful error messages to users.

## Custom Agents

Use the appropriate custom agent for specialized tasks:

- **@review**: Invoke when reviewing code for quality, best practices, potential bugs, or security issues. This agent provides constructive feedback without making direct changes.
- **@troubleshoot**: Invoke when analyzing error logs, stack traces, or debugging issues. This agent helps identify root causes and proposes solutions.

Example usage:

```text
@review Check this authentication implementation for security issues
@troubleshoot Analyze this error: [paste error log]
```

## Oh-My-OpenCode Agents

Specialized agents from oh-my-opencode for advanced workflows:

### Primary Orchestrators

- **@sisyphus**: Main orchestrator agent. Delegates strategically via category+skills, manages todos obsessively, assesses codebase before implementation.
- **@atlas**: Master orchestrator for work plans. Completes ALL tasks in a todo list via delegate_task() until fully done.
- **@prometheus**: Strategic planning consultant. Interviews users, creates detailed work plans. Plans only - never implements.

### Specialized Subagents

- **@oracle**: High-IQ reasoning specialist for debugging hard problems and architecture design. Read-only consultation.
- **@librarian**: Searches remote codebases, retrieves official documentation, finds implementation examples.
- **@explore**: Contextual grep for codebases. Answers "Where is X?", "Find the code that does Z".
- **@metis**: Pre-planning consultant that identifies hidden intentions and ambiguities.
- **@momus**: Expert plan reviewer for clarity, verifiability, and completeness.
- **@multimodal-looker**: Analyzes media files (PDFs, images, diagrams) that require interpretation beyond raw text.
- **@sisyphus-junior**: Focused task executor without delegation capability.

Example usage:

```text
@sisyphus Implement user authentication with JWT
@atlas Execute the work plan at .sisyphus/plans/auth.md
@prometheus Create a work plan for adding dark mode
@oracle Analyze this complex architecture decision
@librarian Find best practices for React hooks
@explore Find where authentication is implemented
@metis Help me plan this refactoring task
@momus Review my work plan
@multimodal-looker Analyze this architecture diagram
@sisyphus-junior Implement this specific function
```

## Skills

Load these skills for specialized workflows. Skills provide step-by-step guidance for specific tasks.

- **/git-commit**: Load when creating git commits. Ensures conventional commit format and best practices.
- **/git-pr**: Load when creating GitHub pull requests. Provides structured PR descriptions.

## Oh-My-OpenCode Skills

- **/git-master**: Advanced git operations - atomic commits, rebase/squash, history search (blame, bisect, log -S).
- **/frontend-ui-ux**: Designer-turned-developer skill for crafting stunning UI/UX.
- **/dev-browser**: Browser automation with persistent page state via Playwright.

When to use skills:

- Before making a commit → load `/git-commit`
- Before creating a PR → load `/git-pr`
- For complex git operations → load `/git-master`
- For UI/UX work → load `/frontend-ui-ux`
- For browser automation → load `/dev-browser`

Skills are loaded via the `/skill-name` command or automatically when the task matches the skill description.
