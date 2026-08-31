#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"

RELEASE_JSON=$(curl -fsSL https://api.github.com/repos/MoonshotAI/kimi-code/releases/latest)
TAG=$(jq -r '.tag_name' <<< "$RELEASE_JSON")
LATEST="${TAG##*@}"

if [ -z "$LATEST" ] || [ "$LATEST" = "null" ] || [ "$LATEST" = "$TAG" ]; then
  echo "ERROR: Failed to fetch latest version from GitHub API"
  exit 1
fi

CURRENT=$(rg 'version = ' "$PACKAGE_NIX" | head -1 | sed 's/.*"\(.*\)".*/\1/')

if [ "$LATEST" = "$CURRENT" ]; then
  echo "Already at latest version: $LATEST"
  exit 0
fi

echo "Updating $CURRENT -> $LATEST"

SYSTEMS=(
  "aarch64-darwin"
  "x86_64-darwin"
  "x86_64-linux"
  "aarch64-linux"
)
PLATFORM_SUFFIXES=(
  "darwin-arm64"
  "darwin-x64"
  "linux-x64"
  "linux-arm64"
)
HASHES=()

for index in "${!SYSTEMS[@]}"; do
  system="${SYSTEMS[$index]}"
  suffix="${PLATFORM_SUFFIXES[$index]}"
  asset="kimi-code-${suffix}.zip"

  digest=$(jq -er --arg asset "$asset" '.assets[] | select(.name == $asset) | .digest' <<< "$RELEASE_JSON") || {
    echo "ERROR: No release asset digest found for $asset"
    exit 1
  }

  sri_hash=$(nix hash convert --to sri "$digest")
  HASHES[index]="$sri_hash"
  echo "  $system: $sri_hash"
done

sed -i.bak "s/version = \"$CURRENT\"/version = \"$LATEST\"/" "$PACKAGE_NIX"

for index in "${!SYSTEMS[@]}"; do
  system="${SYSTEMS[$index]}"
  old_hash=$(rg -A3 "\"$system\"" "$PACKAGE_NIX" | rg 'hash = ' | sed 's/.*"\(.*\)".*/\1/')
  new_hash="${HASHES[$index]}"
  if [ -n "$old_hash" ] && [ -n "$new_hash" ]; then
    sed -i.bak "s|$old_hash|$new_hash|" "$PACKAGE_NIX"
  fi
done

rm -f "$PACKAGE_NIX.bak"

echo "Updated package.nix to version $LATEST"
