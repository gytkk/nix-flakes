# Review Rubrics

Use these criteria for the devil's advocate multi-pass review.

## Standards Discovery

Extract standards from:

- `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`: coding standards,
  architecture rules, conventions.
- ADR files: active decisions and rationale.
- Dominant patterns: five or more local instances following one convention.
- Boundary markers: barrel exports, API clients, repositories, services,
  package boundaries.

Deviations from discovered standards are findings, even when the code is
correct in isolation.

## Pass 1: Architecture And Design Fitness

Check:

- Dependency direction and circular dependencies.
- Abstraction level: YAGNI, copy-paste, speculative generality.
- Pattern consistency with this codebase.
- Module boundary violations.
- Public API contract changes.
- Separation of concerns.
- Compliance with discovered conventions and ADRs.

Minimum findings: 2 in full mode, 1 in quick mode. Re-examine once if fewer are
found.

## Pass 2: Future Maintainability And Tech Debt

Check:

- Six-month readability for a new maintainer.
- Coupling and cohesion.
- How many files change when requirements move.
- Open-closed behavior.
- Implicit assumptions.
- Magic values and weak domain modeling.
- Debuggability of errors and logs.

Minimum findings: 2. Re-examine once if fewer are found.

## Pass 3: Hidden Assumptions And Edge Cases

Check:

- Implicit contracts not enforced by types, assertions, or validation.
- Unhandled errors and partial failures.
- Concurrency, deadlocks, stale state, and ordering assumptions.
- Input validation for empty, null, malformed, and maximum-size inputs.
- External failures: network, filesystem, database, service dependency.
- Resource leaks: files, connections, locks, transactions.
- Boundary conditions: off-by-one, empty collections, maximum limits.

Completion target: identify at least 1 edge-case finding when defensible.
Re-examine once if none is found. If no edge-case finding is defensible, report
that the pass did not produce material findings and list the concrete
edge-case areas that remain unverified rather than inventing one.

## Verdict Criteria

Use:

- `approve`: findings are all minor or info, average confidence is at least 8,
  and all passes were completed. A completed pass may have no findings only when
  the report states the re-check and remaining unverified areas.
- `needs_work`: default; use for any major finding, confidence below 8,
  incomplete context, or missed pass target.
- `reject`: any high-confidence critical finding or fundamental design flaw.

The reviewer must argue for approval with evidence. Approval is not the default.
