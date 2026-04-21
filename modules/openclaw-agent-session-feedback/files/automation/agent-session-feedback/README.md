# Agent Session Feedback Automation

OpenClaw daily automation for reviewing `~/agent-sessions` and feeding repeated patterns back into Codex / Claude operating rules.

## What it does

- Reads the current day's Claude + Codex session records together.
- Pulls in previously written daily summaries for comparison.
- Updates daily summary, analysis, proposal, and report files under `~/agent-sessions/review/`.
- Reviews `~/development/nix-flakes/AGENTS.md` and `~/development/nix-flakes/CLAUDE.md` as the Codex / Claude operating-rule targets.
- Checks `~/development/nix-flakes/modules/codex/files/AGENTS.md` and `~/development/nix-flakes/modules/claude/files/CLAUDE.md` when the pattern belongs in global agent defaults.
- Allows bounded local commits when a low-risk, evidence-backed improvement is actually applied.
- Does not push automatically.

## Installed paths

Home Manager links this directory into:

- `~/.openclaw/workspace/automation/agent-session-feedback/`

## Output layout

The workflow writes into `~/agent-sessions/review/`:

- `context/YYYY-MM-DD.json`
- `context/YYYY-MM-DD.md`
- `summaries/daily/YYYY-MM-DD.md`
- `analysis/YYYY-MM-DD.md`
- `proposals/YYYY-MM-DD.md`
- `reports/YYYY-MM-DD.md`

## Cron ownership

The declarative cron definition lives in `modules/openclaw-agent-session-feedback/default.nix`.
`openclaw-sync-agent-session-feedback-cron` reconciles the real OpenClaw cron job with that declaration on `pylv-onyx`.
