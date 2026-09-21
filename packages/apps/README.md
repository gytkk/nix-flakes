# App packages

Self-contained non-nixpkgs app packages used by the parent `nix-flakes` repository. The nested flake keeps package CI independent from the parent flake's private inputs.

## Layout

```
.
├── agent-browser/
├── claude-code/
├── codex/
├── codexbar/
├── databricks-cli/
├── herdr/
├── herdr-annotate/
├── herdr-auto-title/
├── notion-cli/
├── opencode/
├── pi/
├── pup/
├── lib/
│   └── mk-tarball-cli.nix
├── default.nix
├── flake.nix
├── scripts
│   ├── sync-readme-versions.sh
│   └── update-all.sh
├── tests/
│   └── detect-changed-apps.sh
├── settings.json
└── README.md
```

## App versions

| App | Version |
|-----|---------|
| agent-browser | 0.38.1 |
| claude-code | 2.1.274 |
| codex | 0.154.0 |
| codexbar | 0.60.4 |
| databricks-cli | 1.7.0 |
| herdr | 0.9.1 |
| herdr-annotate | 0.4.0 |
| herdr-auto-title | 0.6.2 |
| notion-cli | 0.22.8 |
| opencode | 1.18.31 |
| pi | 0.85.1 |
| pup | 1.4.0 |

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

The package catalog in `default.nix` is the single source of truth for exported apps and aliases. Register each package there once; the parent package outputs, configuration overlay, and nested flake consume the same catalog. App-specific settings still belong in `modules/<app>/`, and enabling a package in a profile remains a separate choice.

`ntn` is an alias of `notion-cli` in the catalog. Both attributes provide the same derivation and the `ntn` executable. Aliases need no package directory or updater and do not add duplicate rows to the version table.

## Reusing the tarball CLI builder

The catalog supplies `mkTarballCli` to package functions that request it. Use it for a release tarball containing one executable with optional documentation files. [Databricks CLI](databricks-cli/package.nix) shows the basic case; [Notion CLI](notion-cli/package.nix) shows a nested archive directory and additional installed files.

| Argument | Meaning |
| --- | --- |
| `pname`, `version` | Package identity, kept in the app's `package.nix`. |
| `platforms` | Attribute set keyed by Nix system. Each entry contains `hash` and any fields needed to construct the URL. |
| `url` | Function from the selected platform entry to the archive URL. |
| `meta` | Normal Nix metadata, including the required `mainProgram`. The executable in the archive must have that name. |
| `sourceRoot` | Optional function from the platform entry to the unpacked directory. Defaults to `_: "."`. |
| `extraInstall` | Optional shell commands after installing the executable and before `postInstall`, for example README and license installation. |

The helper selects the host platform, fetches the pinned archive, disables configure/build phases, installs the executable, runs install hooks, and derives `meta.platforms`. URL conventions, hashes, licenses, and archive-specific facts remain in the app file. Packages with multiple archives, binary patching, wrappers, or source builds continue to use their own `callPackage` expressions.

## Updates and CI

- Run `packages/apps/scripts/update-all.sh` from the parent repository to update every enabled package manually.
- `Update App Versions` checks for updates every three hours, verifies changed packages, and commits successful updates to `main`.
- `herdr` tracks stable releases and builds from Rust and Zig sources with a plugin palette snapshot patch. Cargo dependencies come from the source's `Cargo.lock`; Zig dependencies use its vendored Nix manifest. The hash-pinned source is fetched during evaluation so `nix flake check --no-build` can read both files without building a source derivation first. Older nixpkgs inputs use the pinned Zig 0.16 build tool in `herdr/zig.nix`. Its updater pins the source hash and checks the patch and Zig requirement before changing the package.
- `herdr-annotate` tracks the plugin's `main` commit and the versions it declares. Its updater records source hashes, release checksums for `herdr-annotate`, and the source and Cargo dependency hashes for the Rust-built `plannotator-tui` in `herdr-annotate/sources.json`, so changes are detected even when the manifest version stays the same. Local reviewer patches inherit Herdr's palette and retain per-field color overrides.
- `herdr-auto-title` tracks stable GitHub releases and builds from source. Its updater pins the source and vendored Go dependency hashes using Go from the nested flake's locked nixpkgs input.
- `App Packages CI` evaluates the nested flake, builds changed packages, and checks Codex release-bundle drift.
- `databricks-cli`, `notion-cli`, and `pup` are manually updated. They have no `update.sh`, so aggregate updates skip them. Moving a package into this catalog does not enable automatic updates.
- Changes under `lib/` rebuild all catalog package directories. A package-local change rebuilds that package. The changed-app detector is checked with `bash packages/apps/tests/detect-changed-apps.sh`.
- The parent configuration overlay intentionally keeps nixpkgs `opencode`; the local package remains available through the nested and parent package outputs.
