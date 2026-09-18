#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TEST_ROOT"' EXIT

REPO="$TEST_ROOT/repo"
APP_ROOT="$REPO/packages/apps"
DETECT="$APP_ROOT/scripts/detect-changed-apps.sh"

commit() {
  git -C "$REPO" add -A
  git -C "$REPO" \
    -c commit.gpgsign=false \
    -c core.hooksPath=/dev/null \
    -c user.name="App package test" \
    -c user.email="app-package-test@example.invalid" \
    commit -q -m "$1"
  git -C "$REPO" rev-parse HEAD
}

assert_apps() {
  local description="$1"
  local expected="$2"
  local base_sha="$3"
  local head_sha="${4:-HEAD}"
  local actual

  actual="$("$DETECT" "$base_sha" "$head_sha")"
  if ! jq -e --argjson expected "$expected" '. == $expected' <<<"$actual" >/dev/null; then
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$description" "$expected" "$actual" >&2
    exit 1
  fi
  printf 'PASS: %s\n' "$description"
}

mkdir -p "$APP_ROOT"/{alpha,beta,lib,scripts}
cp "$SOURCE_ROOT/scripts/detect-changed-apps.sh" "$DETECT"
chmod +x "$DETECT"
printf '{ }\n' > "$APP_ROOT/alpha/package.nix"
printf '{ }\n' > "$APP_ROOT/beta/package.nix"
printf '{ }\n' > "$APP_ROOT/default.nix"
printf '{ }\n' > "$APP_ROOT/flake.nix"
printf '# fixtures\n' > "$APP_ROOT/README.md"
printf '{ value = 1; }\n' > "$APP_ROOT/lib/helper.nix"

git -C "$REPO" init -q
initial_sha="$(commit 'initial fixtures')"

printf '{ changed = true; }\n' > "$APP_ROOT/alpha/package.nix"
alpha_sha="$(commit 'change alpha')"
assert_apps "one app change selects that app" '["alpha"]' "$initial_sha" "$alpha_sha"

printf '{ value = 2; }\n' > "$APP_ROOT/lib/helper.nix"
lib_sha="$(commit 'change shared helper')"
assert_apps "shared helper change rebuilds every app" '["alpha","beta"]' "$alpha_sha" "$lib_sha"

printf '{ catalog = true; }\n' > "$APP_ROOT/default.nix"
catalog_sha="$(commit 'change catalog')"
assert_apps "catalog change rebuilds every app" '["alpha","beta"]' "$lib_sha" "$catalog_sha"

printf '# documentation only\n' >> "$APP_ROOT/README.md"
readme_sha="$(commit 'change readme')"
assert_apps "README-only change selects no apps" '[]' "$catalog_sha" "$readme_sha"

assert_apps "missing baseline rebuilds every app" '["alpha","beta"]' ""
assert_apps "invalid baseline rebuilds every app" '["alpha","beta"]' "not-a-commit"

rm "$APP_ROOT/alpha/package.nix"
deleted_sha="$(commit 'delete alpha')"
assert_apps "deleted package rebuilds all remaining apps" '["beta"]' "$readme_sha" "$deleted_sha"
