# Trading agent package

This package function builds the Rust `trade-engine` and `trade-admin` binaries and installs the web administration bundle as ordinary files under `$out/share/trading-agent/web`. Callers supply an immutable source tree, a version, and its revision. The source is not published or registered in the package catalog.

```nix
pkgs.callPackage ./packages/apps/trading-agent/package.nix {
  src = tradingAgentSource;
  version = "0.1.0-55ae1ef";
  revision = "55ae1ef19a9264b727b145e61ccaf8addab134e8";
}
```

Use an explicitly pinned source containing `Cargo.lock`, `web-admin/package.json`, and `web-admin/bun.lock`. For local validation, export a committed revision with `git archive` into a temporary directory. Do not pass an unfiltered checkout containing credentials, runtime state, caches, or unrelated work.

The dependency hash was measured and reproduced for source revision `55ae1ef19a9264b727b145e61ccaf8addab134e8` on x86_64 Linux with Bun 1.3.13. The root flake's nixpkgs revision `b3da656039dc7a6240f27b2ef8cc6a3ef3bccae7` provides that Bun version, Node 24.14.1, and Rust 1.94.1. Dependency fetching and the offline frontend build were verified with that package set. The complete Rust package has not been built with Rust 1.94.1. The standalone `packages/flake.nix` uses a different nixpkgs pin and is not validated for this package. Other platforms are not supported.

Bun installs development dependencies from the frozen lockfile with lifecycle scripts disabled and an isolated cache. The fixed-output dependency derivation receives only the two frontend manifest files. The frontend build copies these dependencies into a writable directory, patches executable shebangs and glibc native addons, runs TypeScript checking, and builds Vite without network access. Musl variants are unused on the supported glibc platform. Neither Bun nor Node is needed by the installed static bundle.

When the frontend manifests change, measure a new recursive dependency hash by evaluating `bun-deps.nix` with the intended source and `hash = pkgs.lib.fakeHash`, then building that derivation. The expected hash mismatch reports the actual hash. Supply it as `frontendDepsHash` to `package.nix`, and run the dependency build again with `--rebuild` to verify reproducibility. Verify the frontend independently through the package's `frontend` passthru before a full Rust build. Changing Bun requires revalidating the installer contract and updating the explicit version assertion.

The package does not enable a service, publish a source revision, configure credentials, or change live trading policy. Service configuration must explicitly select `$out/share/trading-agent/web` as its static asset directory.
