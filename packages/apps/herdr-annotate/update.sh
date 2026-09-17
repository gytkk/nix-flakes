#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_NIX="$SCRIPT_DIR/package.nix"
SOURCES_JSON="$SCRIPT_DIR/sources.json"
REPOSITORY="plannotator/herdr-annotate"
PLANNOTATOR_REPOSITORY="plannotator/plannotator-tui"

tmp_dir="$(mktemp -d)"
cleanup() {
  find "$tmp_dir" -type f -delete
  rmdir "$tmp_dir"
}
trap cleanup EXIT

github_api() {
  curl -fsSL --retry 3 \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "$1"
}

main_commit=$(github_api "https://api.github.com/repos/$REPOSITORY/commits/main")
revision=$(jq -er '.sha' <<<"$main_commit")
revision_date=$(jq -er '.commit.committer.date | split("T")[0]' <<<"$main_commit")

raw_base="https://raw.githubusercontent.com/$REPOSITORY/$revision"
plugin_version=$(curl -fsSL --retry 3 "$raw_base/herdr-plugin.toml" | rg -m1 '^version = ' | sed 's/.*"\(.*\)".*/\1/')
herdr_annotate_version=$(curl -fsSL --retry 3 "$raw_base/herdr-annotate.version" | tr -d '[:space:]')
plannotator_tui_version=$(curl -fsSL --retry 3 "$raw_base/plannotator-tui.version" | tr -d '[:space:]')

for value in "$plugin_version" "$herdr_annotate_version" "$plannotator_tui_version"; do
  if [ -z "$value" ]; then
    echo "ERROR: Upstream version metadata is incomplete" >&2
    exit 1
  fi
done

package_version=$(rg -m1 'version = ' "$PACKAGE_NIX" | sed 's/.*"\(.*\)".*/\1/')
source_url="https://github.com/$REPOSITORY/archive/$revision.tar.gz"
source_hash_base32=$(nix-prefetch-url --unpack "$source_url")
source_hash=$(nix hash convert --hash-algo sha256 --to sri "$source_hash_base32")

targets=(
  aarch64-apple-darwin
  x86_64-apple-darwin
  x86_64-unknown-linux-gnu
  aarch64-unknown-linux-gnu
)

herdr_sums=$(curl -fsSL --retry 3 "https://github.com/$REPOSITORY/releases/download/rust-lite-v$herdr_annotate_version/SHA256SUMS")
plannotator_sums=$(curl -fsSL --retry 3 "https://github.com/$PLANNOTATOR_REPOSITORY/releases/download/v$plannotator_tui_version/SHA256SUMS")

release_hash() {
  local sums="$1"
  local asset="$2"
  local hex
  hex=$(rg " $asset\$" <<<"$sums" | awk '{print $1}' || true)
  if [ -z "$hex" ]; then
    echo "ERROR: Release checksums do not list $asset" >&2
    exit 1
  fi
  nix hash convert --hash-algo sha256 --to sri "$hex"
}

herdr_aarch64_darwin=$(release_hash "$herdr_sums" "herdr-annotate-${targets[0]}")
herdr_x8664_darwin=$(release_hash "$herdr_sums" "herdr-annotate-${targets[1]}")
herdr_x8664_linux=$(release_hash "$herdr_sums" "herdr-annotate-${targets[2]}")
herdr_aarch64_linux=$(release_hash "$herdr_sums" "herdr-annotate-${targets[3]}")
plannotator_aarch64_darwin=$(release_hash "$plannotator_sums" "plannotator-tui-${targets[0]}")
plannotator_x8664_darwin=$(release_hash "$plannotator_sums" "plannotator-tui-${targets[1]}")
plannotator_x8664_linux=$(release_hash "$plannotator_sums" "plannotator-tui-${targets[2]}")
plannotator_aarch64_linux=$(release_hash "$plannotator_sums" "plannotator-tui-${targets[3]}")

jq -n \
  --arg revision "$revision" \
  --arg revisionDate "$revision_date" \
  --arg sourceHash "$source_hash" \
  --arg herdrVersion "$herdr_annotate_version" \
  --arg plannotatorVersion "$plannotator_tui_version" \
  --arg herdrAarch64Darwin "$herdr_aarch64_darwin" \
  --arg herdrX8664Darwin "$herdr_x8664_darwin" \
  --arg herdrX8664Linux "$herdr_x8664_linux" \
  --arg herdrAarch64Linux "$herdr_aarch64_linux" \
  --arg plannotatorAarch64Darwin "$plannotator_aarch64_darwin" \
  --arg plannotatorX8664Darwin "$plannotator_x8664_darwin" \
  --arg plannotatorX8664Linux "$plannotator_x8664_linux" \
  --arg plannotatorAarch64Linux "$plannotator_aarch64_linux" \
  '{
    revision: $revision,
    revisionDate: $revisionDate,
    sourceHash: $sourceHash,
    herdrAnnotate: {
      version: $herdrVersion,
      hashes: {
        "aarch64-apple-darwin": $herdrAarch64Darwin,
        "x86_64-apple-darwin": $herdrX8664Darwin,
        "x86_64-unknown-linux-gnu": $herdrX8664Linux,
        "aarch64-unknown-linux-gnu": $herdrAarch64Linux
      }
    },
    plannotatorTui: {
      version: $plannotatorVersion,
      hashes: {
        "aarch64-apple-darwin": $plannotatorAarch64Darwin,
        "x86_64-apple-darwin": $plannotatorX8664Darwin,
        "x86_64-unknown-linux-gnu": $plannotatorX8664Linux,
        "aarch64-unknown-linux-gnu": $plannotatorAarch64Linux
      }
    }
  }' > "$tmp_dir/sources.json"

if cmp -s "$tmp_dir/sources.json" "$SOURCES_JSON" && [ "$plugin_version" = "$package_version" ]; then
  echo "Already current: plugin $plugin_version at $revision"
  exit 0
fi

cp "$PACKAGE_NIX" "$tmp_dir/package.nix"
if [ "$plugin_version" != "$package_version" ]; then
  OLD="$package_version" NEW="$plugin_version" perl -0pi -e 's/version = "\Q$ENV{OLD}\E"/version = "$ENV{NEW}"/' "$tmp_dir/package.nix"
fi

mv "$tmp_dir/package.nix" "$PACKAGE_NIX"
mv "$tmp_dir/sources.json" "$SOURCES_JSON"
echo "Updated plugin $plugin_version to $revision ($revision_date)"
echo "  herdr-annotate: $herdr_annotate_version"
echo "  plannotator-tui: $plannotator_tui_version"
