#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

LATEST=$(curl -s https://api.github.com/repos/anomalyco/opencode/releases/latest \
  | jq -r '.tag_name' | sed 's/^v//')

if [ -z "$LATEST" ] || [ "$LATEST" = "null" ]; then
  echo "ERROR: Failed to fetch latest version from GitHub API"
  exit 1
fi

CURRENT=$(rg -m 1 'version = ' "$PACKAGE_NIX" | sed 's/.*"\(.*\)".*/\1/')

if [ "$LATEST" = "$CURRENT" ]; then
  echo "Already at latest version: $LATEST"
  exit 0
fi

echo "Updating $CURRENT -> $LATEST"

declare -A PLATFORM_SUFFIX=(
  ["aarch64-darwin"]="darwin-arm64"
  ["x86_64-darwin"]="darwin-x64"
  ["x86_64-linux"]="linux-x64"
  ["aarch64-linux"]="linux-arm64"
)

declare -A PLATFORM_EXT=(
  ["aarch64-darwin"]="zip"
  ["x86_64-darwin"]="zip"
  ["x86_64-linux"]="tar.gz"
  ["aarch64-linux"]="tar.gz"
)

declare -A HASHES
for system in aarch64-darwin x86_64-darwin x86_64-linux aarch64-linux; do
  suffix="${PLATFORM_SUFFIX[$system]}"
  ext="${PLATFORM_EXT[$system]}"
  url="https://github.com/anomalyco/opencode/releases/download/v${LATEST}/opencode-${suffix}.${ext}"

  echo "Fetching hash for $system..."
  nix_output=$(nix build --impure --no-link --expr "
    (builtins.getFlake \"nixpkgs\").legacyPackages.x86_64-linux.fetchzip {
      url = \"$url\";
      hash = \"sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=\";
      stripRoot = false;
    }
  " 2>&1 || true)

  sri_hash=$(echo "$nix_output" | sed -n 's/.*got: *\(sha256-[A-Za-z0-9+/]*=*\).*/\1/p')

  if [ -z "$sri_hash" ]; then
    echo "ERROR: Failed to fetch hash for $system"
    echo "$nix_output"
    exit 1
  fi

  HASHES[$system]="$sri_hash"
  echo "  $system: $sri_hash"
done

sed -i "s/version = \"$CURRENT\"/version = \"$LATEST\"/" "$PACKAGE_NIX"

for system in aarch64-darwin x86_64-darwin x86_64-linux aarch64-linux; do
  old_hash=$(rg -A3 "\"$system\"" "$PACKAGE_NIX" | rg 'hash = ' | sed 's/.*"\(.*\)".*/\1/')
  new_hash="${HASHES[$system]}"
  if [ -n "$old_hash" ] && [ -n "$new_hash" ]; then
    sed -i "s|$old_hash|$new_hash|" "$PACKAGE_NIX"
  fi
done

echo "Updated package.nix to version $LATEST"
