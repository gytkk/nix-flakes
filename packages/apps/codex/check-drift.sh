#!/usr/bin/env bash
# Detect drift between the official codex-package bundle and the binaries this
# flake installs.
#
# package.nix deliberately fetches only the bare `codex` and
# `codex-code-mode-host` release assets instead of the all-in-one
# codex-package bundle (which also vendors rg/zsh/bwrap that nixpkgs already
# provides). The risk of hand-picking is missing a NEW binary if a future
# codex release splits one out — exactly what happened with
# codex-code-mode-host. This check compares the bundle's bin/ against what
# package.nix installs and fails if the bundle ships anything extra, so we get
# told to decide whether to ship it too.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

# The bin/ set is platform-invariant for codex — platform-specific helpers
# (e.g. bwrap on Linux) live under codex-resources/, not bin/ — so one
# reference target is enough to enumerate it.
TARGET="x86_64-unknown-linux-musl"

VERSION=$(rg 'version = "' "$PACKAGE_NIX" | head -1 | sed 's/.*"\(.*\)".*/\1/')
if [ -z "$VERSION" ]; then
  echo "ERROR: could not read version from $PACKAGE_NIX" >&2
  exit 2
fi

# Binaries package.nix installs into $out/bin: the final names on the
# `mv $out/bin/... $out/bin/<name>` lines of installPhase.
INSTALLED=$(rg -o 'mv \$out/bin/\S+ \$out/bin/(\S+)' -r '$1' "$PACKAGE_NIX" | sort -u)

URL="https://github.com/openai/codex/releases/download/rust-v${VERSION}/codex-package-${TARGET}.tar.gz"
echo "Listing bin/ of codex-package ${VERSION} (${TARGET})..."
BUNDLE=$(curl -fsSL "$URL" | tar -tzf - 2>/dev/null | rg '^bin/.+' | sed 's|^bin/||' | sort -u)
if [ -z "$BUNDLE" ]; then
  echo "ERROR: could not read bin/ from bundle at $URL" >&2
  exit 2
fi

echo "installed by package.nix: $(echo "$INSTALLED" | paste -sd' ' -)"
echo "codex-package bin/:       $(echo "$BUNDLE" | paste -sd' ' -)"

# Bundle bin/ entries we do NOT install are drift.
MISSING=$(comm -23 <(echo "$BUNDLE") <(echo "$INSTALLED"))

if [ -n "$MISSING" ]; then
  echo ""
  echo "DRIFT: codex-package ${VERSION} ships bin/ binaries not installed by package.nix:"
  echo "$MISSING" | while IFS= read -r b; do echo "  - $b"; done
  echo ""
  echo "Add them to packages/apps/codex/package.nix (and update.sh hashes) or confirm they are intentionally omitted."
  exit 1
fi

echo "OK: package.nix installs every codex-package bin/ binary."
