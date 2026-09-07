#!/usr/bin/env bash

set -euo pipefail

materializer="${1:-$(dirname "$0")/../files/materialize-runtime-tree.sh}"
test_root="$(mktemp -d)"
trap 'chmod -R u+w "$test_root" 2>/dev/null || true; rm -rf "$test_root"' EXIT

fail() {
  printf 'openclaw runtime materializer test failed: %s\n' "$1" >&2
  exit 1
}

source_v1="$test_root/source-v1"
source_v2="$test_root/source-v2"
target_parent="$test_root/runtime"
target_tree="$target_parent/skills"
old_tree="$test_root/old-skills"

mkdir -p "$source_v1/example" "$source_v2/example" "$target_parent" "$old_tree"
printf '%s\n' 'version one' >"$source_v1/example/SKILL.md"
ln "$source_v1/example/SKILL.md" "$test_root/source-hardlink"
printf '%s\n' 'version two' >"$source_v2/example/SKILL.md"
printf '%s\n' 'stale' >"$old_tree/STALE.md"
ln -s "$old_tree" "$target_tree"

bash "$materializer" "$source_v1" "$target_tree"
[[ -d "$target_tree" && ! -L "$target_tree" ]] || fail "first deployment did not replace the target symlink"
[[ "$(<"$target_tree/example/SKILL.md")" == "version one" ]] || fail "first deployment copied the wrong content"
[[ "$(stat --format=%h -- "$target_tree/example/SKILL.md")" == 1 ]] || fail "first deployment preserved a hardlink"
[[ ! -e "$target_tree/STALE.md" ]] || fail "first deployment retained stale content"

bash "$materializer" "$source_v2" "$target_tree"
[[ "$(<"$target_tree/example/SKILL.md")" == "version two" ]] || fail "replacement deployment copied the wrong content"
[[ "$(stat --format=%h -- "$target_tree/example/SKILL.md")" == 1 ]] || fail "replacement deployment created a hardlink"
[[ ! -w "$target_tree/example/SKILL.md" ]] || fail "deployed file is writable"

if bash "$materializer" "$source_v2" "$target_parent/unexpected" >/dev/null 2>&1; then
  fail "unexpected target name was accepted"
fi

printf '%s\n' 'openclaw runtime materializer tests passed'
