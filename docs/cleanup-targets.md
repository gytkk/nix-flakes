# Repository Clean-up Targets

Audit of files, modules, overlays, packages, scripts, themes, apps, and docs that
are defined but not actively referenced/imported/used anywhere in the repo.

- **Date:** 2026-06-17
- **Scope:** whole repository (`nix-flakes`)
- **Method:** two independent passes — an advisory review (manual `rg` reference
  tracing) and a Codex pass. Findings reconciled below.

> Nothing has been removed. This is a decision document; act on targets only after
> confirming the medium/low-confidence items.

Current unresolved cleanup targets outside the structure refactor:

- `modules/vscode/`
- `modules/hermes-agent/README.md`
- `docs/superpowers/plans/*.md`
- uninstalled one-shot helper scripts
- stale or unlinked README files

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

- `themes/` + its Python generator — produces `themes/exports`, consumed by the zed
  module and `lib/themes.nix`.
- `packages/` — `notion-cli`, `qmd` are each `callPackage`'d.
- All sub-`.nix` files — `modules/codex/system.nix`,
  `modules/openclaw/{nginx-proxy,state-sync}.nix`, and the pylv-onyx host files are
  properly imported.

---

## Codex pass (verbatim)

> The first Codex run terminated mid-investigation without emitting a report; this is
> the output of a clean re-run. Reproduced verbatim; reconciliation follows below.

# Dead Code Audit — nix-flakes

## Files/Modules

| Path | Evidence |
|---|---|
| `hosts/pylv-sepia/hardware-configuration.nix` | `hosts/pylv-sepia/configuration.nix` imports `./disk-config.nix`, `./obsidian-headless.nix`, `./obsidian-maintenance`, and `../../modules/nixos` — but not `./hardware-configuration.nix`. Nothing else imports it. |
| `modules/vscode/default.nix` | `base/default.nix` does not import `../modules/vscode`; no other `.nix` file does either. Project docs also mark VSCode as disabled. |
| `secrets/secrets.nix` | No `.nix` file imports it. Live configs reference encrypted files directly via `age.secrets.*.file`. Not on the flake evaluation path (may still be useful for the `agenix` CLI, but it is not live configuration). |

## Overlays

No dead code found in this category.

## Packages

| Path | Evidence |
|---|---|
| `modules/vscode/default.nix` (local derivations) | The `oneHalfLightTheme` derivation and extension lists are defined only inside the dead VSCode module. They never reach a live environment or flake package output. |

## Scripts/Apps

| Path | Evidence |
|---|---|
| `update-flake-stores.sh` | Not referenced by `flake.nix`, not exposed under `apps`, not packaged, not read by any module. Only reference found is `docs/cleanup-targets.md`. |
| `modules/agent-session-record/files/claude-upload-all-history-once.sh` | The parent module installs other scripts but never symlinks or packages this one. |
| `modules/agent-session-record/files/codex-upload-all-history-once.sh` | Same: parent module never wires this script in. |
| `modules/tmux/files/tmux-session-manager-test.sh` | Not exposed via a flake check, app, package, or module activation path. Only `tmux-session-manager.sh` is wired. |

## Themes

No dead code found in this category.

## Static Config Files

| Path | Evidence |
|---|---|
| `modules/agent-session-record/files/claude-upload-all-history-once.sh` | Not sourced or symlinked by `modules/agent-session-record/default.nix`. |
| `modules/agent-session-record/files/codex-upload-all-history-once.sh` | Not sourced or symlinked by `modules/agent-session-record/default.nix`. |
| `modules/tmux/files/tmux-session-manager-test.sh` | `modules/tmux/default.nix` only uses `tmux.conf`, `keybindings.conf`, `statusline.conf`, and `tmux-session-manager.sh`. |
| `modules/vim/files/onelight.lua` | The vim module symlinks `files/config` and generated themes; `init.lua` loads themes from `~/.config/nvim/themes/<theme>.lua`, not this file. |

## Module Options

| Path | Evidence |
|---|---|
| `modules/vscode/default.nix` | Declares `options.modules.vscode.enable` but the module is never imported — no live config can set or evaluate this option. |

## Docs

| Path | Evidence |
|---|---|
| `docs/cleanup-targets.md` | Standalone audit document; no README or config file references it. |
| `docs/superpowers/plans/2026-06-08-fzf-tmux-session-manager.md` | Not in the live README/config chain; only referenced by `docs/cleanup-targets.md`. The described implementation already exists in `modules/tmux`. |
| `docs/superpowers/plans/2026-06-08-tmux-number-rail-statusline.md` | Same: not linked from live docs; the generated statusline artifacts already exist under `themes/exports/tmux`. |
| `modules/hermes-agent/README.md` | `modules/hermes-agent/` has only this README and no `default.nix`. Live Hermes wiring is in `hosts/pylv-onyx/hermes-dashboard.nix`, which does not reference this file. |
| `modules/vscode/README.md` | Docs for the dead VSCode module; not linked from the live README/config chain. |
| `hosts/pylv-sepia/README.md` | Not referenced by the root README or config chain. Also documents stale structure entries (`openclaw.nix`, `hardware-configuration.nix`) that are not imported by the live config. |

## Summary

| Category | Findings |
|---|---:|
| Files/Modules | 5 |
| Overlays | 0 |
| Packages | 1 (inside dead VSCode module) |
| Scripts/Apps | 4 |
| Themes | 0 |
| Static Config Files | 4 |
| Module Options | 1 (inside dead VSCode module) |
| Docs | 6 |

Overall: the main dead areas are disabled VSCode leftovers, an unwired `pylv-sepia` hardware config, uninstalled helper and test scripts, and orphaned documentation. Overlay wiring and all package derivations outside the dead VSCode module appear live.

---

### Resolved

- `hosts/devsisters-macbook/configuration.nix` and
  `hosts/devsisters-macstudio/configuration.nix` were removed with the unused
  nix-darwin input.

---

## Reconciliation (advisory ↔ Codex)

I verified Codex's new claims with `rg` before recording them here.

### Both passes agree
- `modules/vscode/` (incl. `README.md`, `one-half-light-theme/`, the local theme
  derivation, and the `options.modules.vscode.enable` option) — dead.
- `modules/hermes-agent/README.md` — orphaned (README-only dir).
- `update-flake-stores.sh` — unreferenced by any `.nix`.
- `docs/superpowers/plans/*.md` — completed-plan artifacts.

### New, confirmed by Codex (advisory pass missed these)
- **`hosts/pylv-sepia/hardware-configuration.nix`** — confirmed not imported by
  `hosts/pylv-sepia/configuration.nix` (contrast: pylv-onyx imports its own).
  *Note: verify this is vestigial and not a latent missing-import bug before removing.*
- **`modules/agent-session-record/files/{claude,codex}-upload-all-history-once.sh`** —
  confirmed not symlinked by the module (only 4 of 6 scripts are wired). Look like
  one-time migration scripts; remove if the migration is done.
- **`modules/tmux/files/tmux-session-manager-test.sh`** — confirmed unwired test file.
- Stale READMEs: `modules/vscode/README.md`, `hosts/pylv-sepia/README.md`.

### Divergences / corrections
- **`secrets/secrets.nix` — NOT a cleanup target (Codex false positive).** It is
  required by the `agenix` CLI (defines age files + recipient keys for
  `agenix -e secrets/<name>.age`); it is intentionally not flake-imported. Keep.
- **`modules/vim/files/onelight.lua` — needs confirmation, do not blind-delete.**
  Codex found it unwired, but `CLAUDE.md` lists it as a key vim file. Confirm the
  active colorscheme path before acting.
- `docs/cleanup-targets.md` self-listing is expected (it's this file).
