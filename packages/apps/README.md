# App packages

Self-contained non-nixpkgs app packages used by the parent `nix-flakes` repository. The nested flake keeps package CI independent from the parent flake's private inputs.

## Layout

```
.
├── agent-browser/
├── claude-code/
├── codex/
├── herdr/
├── kimi-code/
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
| agent-browser | 0.35.1 |
| claude-code | 2.1.251 |
| codex | 0.151.0 |
| herdr | 0.8.2 |
| kimi-code | 0.39.1 |
| opencode | 1.18.25 |
| pi | 0.84.4 |

## Build entrypoints

- `nix build ./packages/apps#packages.<system>.opencode`
- `nix build ./packages/apps#packages.<system>.default` (same as first app)
- `nix run ./packages/apps#apps.<system>.opencode`

## Adding new apps

To add a new app package:

1. Create `packages/apps/<app-name>/package.nix`.
2. Use `callPackage` arguments available from nixpkgs (`stdenvNoCC`, `fetchzip`, etc.).
3. Ensure the package path creates a `meta.mainProgram` if the package should be run via `nix run`.
4. Add `packages/apps/<app-name>/update.sh` if the package should support the manual aggregate updater.
5. Add the package to `packages/apps/default.nix` so the nested flake, parent outputs, and overlay expose it.

To disable aggregate updates for an app, add its name to the `update.deny` list in `settings.json`.

The package catalog in `default.nix` is the single source of truth for exported apps.

## Updates and CI

- Run `packages/apps/scripts/update-all.sh` from the parent repository to update every enabled package, then review and commit the result normally.
- Read-only GitHub Actions evaluate the nested flake, build changed packages, and check Codex release-bundle drift.
- The parent configuration overlay intentionally keeps nixpkgs `opencode`; the local package remains available through the nested and parent package outputs.
