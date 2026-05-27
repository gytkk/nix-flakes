# Hermes Migration Plan for `nix-flakes`

## Goal

Migrate the `pylv-onyx` personal-agent stack from an OpenClaw-first setup to a
Hermes-first setup without breaking Discord access, Open WebUI access on
`openwebui.pylv.dev`, current model routing, or rollback to the known-good
OpenClaw path.

## Current Repo Coupling

- [`modules/openclaw/default.nix`](./modules/openclaw/default.nix) seeds the
  current OpenClaw bootstrap, wrapper CLI, gateway defaults, browser path, and
  state path under `~/.openclaw`.
- [`hosts/pylv-onyx/configuration.nix`](./hosts/pylv-onyx/configuration.nix)
  imports the OpenClaw module and already carries a temporary Hermes-related
  user-systemd environment workaround.
- [`hosts/pylv-onyx/open-webui.nix`](./hosts/pylv-onyx/open-webui.nix) points
  Open WebUI at `http://127.0.0.1:18790/v1` and exposes `openclaw/main` and
  `openclaw/pro`.
- [`README.md`](./README.md) documents the current OpenClaw dashboard and Open
  WebUI access path for `pylv-onyx`.

A safe migration is therefore a staged infrastructure migration, not just a
package swap.

## Strategy

Use four phases:

1. Inventory and freeze the current OpenClaw behavior.
2. Bring up Hermes in parallel on the same host.
3. Validate Hermes behind non-production entry points.
4. Cut over one surface at a time, keeping OpenClaw rollback-ready.

Do not replace the Open WebUI proxy path until Hermes has already passed direct
CLI and messaging smoke tests.

## Phase 1: Inventory and Freeze

Tasks:

1. Capture current OpenClaw runtime state from `~/.openclaw/`, including
   config, env, cron, and auth/profile files.
2. Record the current Open WebUI contract: `http://127.0.0.1:18790/v1`,
   `openclaw/main`, and `openclaw/pro`.
3. Record which message surfaces are actually in use, especially Discord.
4. Snapshot the current git revision and the current successful
   `nixos-rebuild` generation on `pylv-onyx`.

Exit criteria:

- A human-readable note exists with active channels, models, secrets, and UI
  assumptions.
- OpenClaw can be restored from the recorded state without reverse-engineering.

## Phase 2: Parallel Hermes Bring-Up

Tasks:

1. Install Hermes on `pylv-onyx` as a user-level path first.
2. Run `hermes claw migrate`.
3. Review imported providers, memories, skills, and API keys.
4. Manually fix unsupported secret cases, especially file- or exec-based
   indirection.
5. Keep Hermes off the production Open WebUI route and use Hermes CLI directly
   first.

Repo follow-up:

- Add `modules/hermes/default.nix` instead of overloading `modules/openclaw`
  immediately.
- Add optional host wiring in
  [`hosts/pylv-onyx/configuration.nix`](./hosts/pylv-onyx/configuration.nix).
- Do not delete `modules/openclaw` in this phase.

Exit criteria:

- Hermes runs locally on `pylv-onyx`.
- Imported config is understandable.
- No production route or service depends on Hermes yet.

## Phase 3: Hermes Smoke Tests

Required smoke tests:

1. CLI interaction: start a session, choose the intended model, verify tool
   usage.
2. File and shell execution: confirm local tool execution and approval
   behavior.
3. Memory and persistence: store a fact in one session and recover it in
   another.
4. Messaging: connect Discord in a non-critical path first, then verify inbound
   and outbound handling.
5. Browser/web workflows: validate the workflows that matter for actual usage.
6. Background work: test cron or scheduled behavior if it matters to the
   workload.

Evaluation questions:

- Is time-to-first-response actually better here?
- Are approvals clearer and faster?
- Does Hermes reduce maintenance effort or just move it elsewhere?
- Which OpenClaw workflows still have no acceptable Hermes replacement?

Exit criteria:

- Hermes passes the workflows that matter.
- Missing features are documented as acceptable gaps or blockers.

## Phase 4: Controlled Surface Cutover

Cutover order:

1. CLI first.
2. Messaging second.
3. Open WebUI last.

Open WebUI cutover plan:

1. Parameterize the provider endpoint and default model in
   [`hosts/pylv-onyx/open-webui.nix`](./hosts/pylv-onyx/open-webui.nix) instead
   of assuming OpenClaw-only names.
2. Add a Hermes-backed local endpoint in parallel.
3. Expose Hermes model ids beside the OpenClaw ones during transition.
4. Switch the default model only after successful UI smoke tests.
5. Remove OpenClaw model ids from the default list only after a stable soak
   period.

Exit criteria:

- Hermes is the default path for the selected surface.
- OpenClaw still exists as a rollback target.

## Rollback Plan

Rollback triggers:

- Hermes fails a must-have workflow during smoke testing.
- Discord behavior regresses in a way that affects daily usage.
- Open WebUI integration becomes unstable.
- Provider auth or tool execution is less reliable than the current OpenClaw
  path.

Rollback actions:

1. Keep the OpenClaw Nix module and runtime state untouched until after the soak
   period.
2. Revert any Open WebUI endpoint or model changes that were introduced.
3. Route active usage back to OpenClaw.
4. Keep Hermes installed for later retries, but remove it from primary paths.

## Repo Implementation Plan

1. Add `modules/hermes/default.nix` with minimal package/runtime and
   environment glue.
2. Import Hermes alongside OpenClaw in
   [`hosts/pylv-onyx/configuration.nix`](./hosts/pylv-onyx/configuration.nix)
   during transition.
3. Leave [`hosts/pylv-onyx/open-webui.nix`](./hosts/pylv-onyx/open-webui.nix)
   unchanged until Hermes passes direct smoke tests.
4. Update [`README.md`](./README.md) only after the Hermes path is real.

## Decision Gates

- Gate 1: Import quality. Proceed only if Hermes imports most useful OpenClaw
  context and missing items are limited and understandable.
- Gate 2: Workflow quality. Proceed only if Hermes is at least as good on the
  workflows that triggered migration and no critical OpenClaw-only feature is
  silently lost.
- Gate 3: UI quality. Proceed only if Open WebUI works against Hermes without
  broken auth or confusing model metadata.
- Gate 4: Soak period. Proceed to OpenClaw retirement only if Hermes survives
  real usage for several days without requiring rollback.

## Recommended First Execution Slice

1. Create an inventory note for current OpenClaw usage on `pylv-onyx`.
2. Install Hermes on `pylv-onyx`.
3. Run `hermes claw migrate`.
4. Test Hermes directly in CLI only.
5. Do not touch Open WebUI or Discord routing yet.

## Suggested Next Task

> Audit `pylv-onyx`'s current OpenClaw runtime state and produce a migration
> inventory note with exact channels, models, secrets, and cutover blockers.
