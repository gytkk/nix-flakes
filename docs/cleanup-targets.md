# Repository Clean-up Targets

Audit of files, modules, overlays, packages, scripts, themes, apps, and docs that
are defined but not actively referenced/imported/used anywhere in the repo.

- **Date:** 2026-06-17
- **Scope:** whole repository (`nix-flakes`)
- **Method:** two independent passes — an advisory review (manual `rg` reference
  tracing) and a Codex pass. Findings reconciled below.

> Nothing has been removed. This is a decision document; act on targets only after
> confirming the medium/low-confidence items.

---

## Advisory review findings

Each finding lists the evidence (where it *should* be referenced but isn't).

### High confidence

**1. `modules/vscode/` — entire module is dead**

- Not in the `imports` list of `base/default.nix` (lines 15–29); no other `.nix`
  imports it. Every `vscode` match is a self-reference inside
  `modules/vscode/default.nix`.
- Includes `default.nix`, `README.md`, and `one-half-light-theme/`.
- `CLAUDE.md` already marks it **DISABLED** and says to confirm before
  reactivating — a known orphan. Confirm before removal.

### Medium confidence

**2. `modules/hermes-agent/` — README-only "module"**

- Contains *only* `README.md` (manual Hermes Agent install notes); no `default.nix`,
  never imported. Misplaced under `modules/` (reserved for real modules).
- Distinct from `hosts/pylv-onyx/hermes-dashboard.nix`, which is live.
- → Move the notes to `docs/`, or remove if the manual install is gone.

**3. `docs/superpowers/plans/*.md` — completed implementation plans**

- `2026-06-08-fzf-tmux-session-manager.md` and
  `2026-06-08-tmux-number-rail-statusline.md` are both already implemented:
  `modules/tmux/` has `tmux-session-manager.sh` (+ test) and fzf wiring.
- → Finished-plan artifacts; archive or delete.

**4. `update-flake-stores.sh` — unreferenced helper script**

- No `.nix` file references it; not present in `flake.nix` / `inventory.nix`.
  Standalone maintenance script for the `flake-stores` input.
- → A manually-run script can be "unused by code" yet still useful. Confirm whether
  it is still part of the manual update workflow before removing.

### Low confidence / your call

**5. `README.md` → `### Codex LSP MCP Implementation Plan` (lines 73–202, ~130 lines)**

- A large speculative roadmap embedded in the main README. If not actively pursued,
  it is doc bloat in the primary entry-point doc.
- → Consider moving to `docs/` or removing. Keep if it is a living roadmap.

**6. `result` symlink**

- Stale local build artifact. Already gitignored, so harmless; just working-tree noise.

---

## Verified NOT dead (false-positive guard)

- `apps/openclaw-cron-dashboard` — used by `hosts/pylv-onyx/openclaw-cron-dashboard.nix`
  (`appRoot`) and `packages/openclaw-cron-dashboard-frontend/package.nix` (`src`).
- `themes/` + its Python generator — produces `themes/exports`, consumed by the zed
  module and `lib/themes.nix`.
- `packages/` — `notion-cli`, `obsidian-headless`, `qmd`,
  `openclaw-cron-dashboard-frontend` are each `callPackage`'d.
- All sub-`.nix` files — `modules/codex/system.nix`,
  `modules/openclaw/{nginx-proxy,state-sync}.nix`, and the pylv-onyx host files are
  properly imported.

---

## Codex pass

_Pending — Codex's independent audit is still running. Its verbatim output will be
appended here, followed by a note on where the two passes agree or diverge._
