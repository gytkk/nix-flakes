# Agent Session Feedback Daily Runbook

이 워크플로우는 `~/agent-sessions`에 모인 Claude / Codex 세션 기록을 바탕으로
매일 피드백 루프를 돌려, 요약과 분석 리포트를 갱신하고 low-risk 규칙 개선은
바로 반영하기 위한 것이다.

## Core Rules

- `AGENTS.md`는 **Codex 운영 규칙**으로 취급한다.
- `CLAUDE.md`는 **Claude 운영 규칙**으로 취급한다.
- 공통 패턴은 억지로 둘 중 하나에 넣지 말고, skill / runbook / proposal 후보로 분리한다.
- 당일 세션은 Claude + Codex를 함께 보고 비교한다.
- low-risk, evidence-backed 변경만 바로 반영한다.
- 커밋은 해도 되지만 **push는 하지 않는다**.
- 파괴적 정리나 과도한 규칙 증식은 피한다.

## Inputs

- Session root: `~/agent-sessions`
- Repo root: `~/development/nix-flakes`
- Workspace skills: `~/.openclaw/workspace/skills`
- Context helper: `~/.openclaw/workspace/automation/agent-session-feedback/build_context.mjs`

## Daily Steps

1. Run the context helper first.
   - `node ~/.openclaw/workspace/automation/agent-session-feedback/build_context.mjs`
2. Read the generated context bundle under `~/agent-sessions/review/context/YYYY-MM-DD.{json,md}`.
3. Update `~/agent-sessions/review/summaries/daily/YYYY-MM-DD.md`.
   - Summarize the current day sessions.
   - Compare them against the latest prior summaries listed in the context bundle.
4. Write `~/agent-sessions/review/analysis/YYYY-MM-DD.md`.
   - Repeated work
   - User dissatisfaction / correction patterns
   - Codex-specific rule candidates
   - Claude-specific rule candidates
   - Common patterns that should become skills / runbooks instead
5. Write `~/agent-sessions/review/proposals/YYYY-MM-DD.md`.
   - Separate `apply-now` vs `review-needed` items.
6. Write `~/agent-sessions/review/reports/YYYY-MM-DD.md`.
   - Keep it user-facing and decision-oriented.
7. Inspect the current rule targets.
   - `~/development/nix-flakes/AGENTS.md`
   - `~/development/nix-flakes/CLAUDE.md`
   - `~/development/nix-flakes/modules/codex/files/AGENTS.md`
   - `~/development/nix-flakes/modules/claude/files/CLAUDE.md`
   - relevant workspace skills under `~/.openclaw/workspace/skills`
8. Apply only bounded changes when all of the following are true.
   - The pattern is supported by concrete evidence from the current sessions or prior summaries.
   - The change is small and rollbackable.
   - The target file is clearly the right home for the rule.
9. If you apply changes in `~/development/nix-flakes`, make a local git commit with a clear conventional commit message.
10. Send the final Korean report to the configured Discord channel, then end with `NO_REPLY`.

## Classification Rules

### Update `AGENTS.md` when

- the pattern is Codex-specific
- it changes how Codex should operate in this repo
- it is not just a reusable procedure

### Update `CLAUDE.md` when

- the pattern is Claude-specific
- it changes how Claude should operate in this repo
- it is not just a reusable procedure

### Update module defaults when

- the pattern belongs in Codex / Claude global defaults rather than only this repo
- the right targets are:
  - `modules/codex/files/AGENTS.md`
  - `modules/claude/files/CLAUDE.md`

### Create or revise a skill when

- the same procedure repeats across contexts
- the value is procedural guidance, not a repo-local rule
- it would be reused by either Claude, Codex, or OpenClaw again

## Safety Guardrails

Do not auto-apply when:

- evidence is weak or one-off
- the rule would materially widen external side effects
- the change would trigger large prompt churn or contradictory instructions
- the right target file is ambiguous
- the change really belongs in a human-reviewed proposal

In those cases, keep the item in `proposals/YYYY-MM-DD.md` and mention it in the report.
