#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"
LOCKFILE="$SCRIPT_DIR/npm-shrinkwrap.json"
PACKAGE_NAME="@earendil-works/pi-coding-agent"
GITHUB_REPOSITORY="earendil-works/pi"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: missing required command: $1" >&2
    exit 1
  }
}

for cmd in curl npm jq nix perl rg mktemp tar; do
  require_cmd "$cmd"
done

RELEASE_JSON=$(curl -fsSL "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/latest")
TAG=$(echo "$RELEASE_JSON" | jq -r '.tag_name')
LATEST="${TAG#v}"

if [ -z "$LATEST" ] || [ "$LATEST" = "null" ] || [ "$TAG" != "v$LATEST" ]; then
  echo "ERROR: failed to fetch the latest release from $GITHUB_REPOSITORY" >&2
  exit 1
fi

CURRENT=$(rg -m 1 -o 'version = "([^"]+)";' --replace '$1' "$PACKAGE_NIX")
CURRENT_SRC_HASH=$(rg -m 1 -o 'hash = "([^"]+)";' --replace '$1' "$PACKAGE_NIX")
CURRENT_NPM_HASH=$(rg -m 1 -o 'npmDepsHash = "([^"]+)";' --replace '$1' "$PACKAGE_NIX")

if [ -z "$CURRENT" ] || [ -z "$CURRENT_SRC_HASH" ] || [ -z "$CURRENT_NPM_HASH" ]; then
  echo "ERROR: failed to read current values from $PACKAGE_NIX" >&2
  exit 1
fi

if [ "$LATEST" = "$CURRENT" ]; then
  echo "Already at latest GitHub release: $LATEST"
  exit 0
fi

PACKAGE_JSON=$(npm view "$PACKAGE_NAME@$LATEST" version dist.integrity --json)
PUBLISHED_VERSION=$(echo "$PACKAGE_JSON" | jq -r '.version')
INTEGRITY=$(echo "$PACKAGE_JSON" | jq -r '."dist.integrity"')

if [ "$PUBLISHED_VERSION" != "$LATEST" ] || [ -z "$INTEGRITY" ] || [ "$INTEGRITY" = "null" ]; then
  echo "ERROR: npm package $PACKAGE_NAME@$LATEST is unavailable or incomplete" >&2
  exit 1
fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

cd "$WORKDIR"
PKG=$(npm pack --silent "$PACKAGE_NAME@$LATEST")
tar xzf "$PKG"
cd package
npm install --omit=dev --package-lock-only --ignore-scripts --no-audit --no-fund >/dev/null
if [ -f npm-shrinkwrap.json ]; then
  cp npm-shrinkwrap.json "$LOCKFILE"
elif [ -f package-lock.json ]; then
  cp package-lock.json "$LOCKFILE"
else
  echo "ERROR: npm did not generate a lockfile for $PACKAGE_NAME@$LATEST" >&2
  exit 1
fi

missing_internal_integrity=$(jq -r '
  .packages
  | to_entries[]
  | select(.key | startswith("node_modules/@earendil-works/"))
  | select((.value.resolved // "") != "" and (.value.integrity // "") == "")
  | [.key, .value.version]
  | @tsv
' "$LOCKFILE")

while IFS=$'\t' read -r package_key package_version; do
  [ -n "$package_key" ] || continue
  internal_package=${package_key#node_modules/}
  internal_integrity=$(npm view "$internal_package@$package_version" dist.integrity --json | jq -r '.')
  if [ -z "$internal_integrity" ] || [ "$internal_integrity" = "null" ]; then
    echo "ERROR: failed to fetch npm integrity for $internal_package@$package_version" >&2
    exit 1
  fi

  tmp_lockfile=$(mktemp)
  jq \
    --arg key "$package_key" \
    --arg integrity "$internal_integrity" \
    '.packages[$key].integrity = $integrity' \
    "$LOCKFILE" > "$tmp_lockfile"
  mv "$tmp_lockfile" "$LOCKFILE"
done <<< "$missing_internal_integrity"

missing_integrity=$(jq -r '.packages | to_entries[] | select((.value.resolved // "") != "" and (.value.integrity // "") == "") | .key' "$LOCKFILE")
if [ -n "$missing_integrity" ]; then
  echo "ERROR: lockfile has packages with resolved URLs but no integrity:" >&2
  echo "$missing_integrity" >&2
  exit 1
fi

NEW_NPM_HASH=$(nix shell --inputs-from "$REPO_ROOT" nixpkgs#prefetch-npm-deps -c prefetch-npm-deps "$LOCKFILE")

echo "Updating $CURRENT -> $LATEST"
CURRENT="$CURRENT" \
LATEST="$LATEST" \
CURRENT_SRC_HASH="$CURRENT_SRC_HASH" \
INTEGRITY="$INTEGRITY" \
CURRENT_NPM_HASH="$CURRENT_NPM_HASH" \
NEW_NPM_HASH="$NEW_NPM_HASH" \
perl -0pi -e '
  s/version = "\Q$ENV{CURRENT}\E";/version = "$ENV{LATEST}";/;
  s/hash = "\Q$ENV{CURRENT_SRC_HASH}\E";/hash = "$ENV{INTEGRITY}";/;
  s/npmDepsHash = "\Q$ENV{CURRENT_NPM_HASH}\E";/npmDepsHash = "$ENV{NEW_NPM_HASH}";/;
' "$PACKAGE_NIX"

rg -n 'version = |hash = |npmDepsHash = ' "$PACKAGE_NIX" >/dev/null

echo "Updated package.nix to version $LATEST"
echo "Updated npm-shrinkwrap.json"
