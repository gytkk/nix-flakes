# App packages

Self-contained non-nixpkgs app packages used by the parent `nix-flakes` repository. The nested flake keeps package CI independent from the parent flake's private inputs.

## Layout

```
.
├── agent-browser/
├── claude-code/
├── codex/
├── codexbar/
├── herdr/
├── opencode/
├── pi/
├── default.nix
├── flake.nix
├── scripts
│   ├── sync-readme-versions.sh
│   └── update-all.sh
├── settings.json
└── README.md
```

## App versions

| App | Version |
|-----|---------|
| agent-browser | 0.36.0 |
| claude-code | 2.1.261 |
| codex | 0.153.3 |
| codexbar | 0.56.5 |
| herdr | 0.8.2 |
| opencode | 1.18.28 |
| pi | 0.85.0 |

## Build entrypoints

- `nix build ./packages/apps#packages.<system>.opencode`
- `nix build ./packages/apps#packages.<system>.default` (same as first app)
- `nix run ./packages/apps#apps.<system>.opencode`

## Adding new apps

To add a new app package:

1. Create `packages/apps/<app-name>/package.nix`.
2. Use `callPackage` arguments available from nixpkgs (`stdenvNoCC`, `fetchzip`, etc.).
3. Ensure the package path creates a `meta.mainProgram` if the package should be run via `nix run`.
4. Add `packages/apps/<app-name>/update.sh` if the package should support aggregate updates.
5. Add the package to `packages/apps/default.nix` so the nested flake, parent outputs, and overlay expose it.

To disable aggregate updates for an app, add its name to the `update.deny` list in `settings.json`.

The package catalog in `default.nix` is the single source of truth for exported apps.

## Updates and CI

- Run `packages/apps/scripts/update-all.sh` from the parent repository to update every enabled package manually.
- `Update App Versions` checks for updates every three hours, verifies changed packages, and commits successful updates to `main`.
- `App Packages CI` evaluates the nested flake, builds changed packages, and checks Codex release-bundle drift.
- The parent configuration overlay intentionally keeps nixpkgs `opencode`; the local package remains available through the nested and parent package outputs.
