#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT
mkdir -p "$TEST_ROOT/scripts"
cp "$SOURCE_ROOT/scripts/update-all.sh" "$TEST_ROOT/scripts/"
export TEST_LOG="$TEST_ROOT/calls"
export FAIL_APP=""

for app in alpha beta herdr manual; do
  mkdir -p "$TEST_ROOT/$app"
  printf '{ }\n' > "$TEST_ROOT/$app/package.nix"
  [ "$app" != manual ] || continue
  cat > "$TEST_ROOT/$app/update.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
app=$(basename "$(dirname "$0")")
echo "$app" >> "$TEST_LOG"
if [ "$app" = "$FAIL_APP" ]; then
  exit 17
fi
EOF
  chmod +x "$TEST_ROOT/$app/update.sh"
done

printf '{"update":{"deny":[],"review":["herdr"]}}\n' > "$TEST_ROOT/settings.json"

assert_calls() {
  local expected="$1"
  if [ "$(cat "$TEST_LOG")" != "$expected" ]; then
    echo "FAIL: Expected calls '$expected', got '$(cat "$TEST_LOG")'" >&2
    exit 1
  fi
}

: > "$TEST_LOG"
FAIL_APP=herdr bash "$TEST_ROOT/scripts/update-all.sh" direct
assert_calls $'alpha\nbeta'
echo 'PASS: direct updates exclude the failing reviewed app'

: > "$TEST_LOG"
if FAIL_APP=herdr bash "$TEST_ROOT/scripts/update-all.sh" review; then
  echo 'FAIL: reviewed updater failure was hidden' >&2
  exit 1
fi
assert_calls herdr
echo 'PASS: reviewed failures remain visible and do not run direct updaters'

: > "$TEST_LOG"
bash "$TEST_ROOT/scripts/update-all.sh"
assert_calls $'alpha\nbeta\nherdr'
echo 'PASS: manual default still updates both channels'

printf '{"update":{"deny":["herdr"],"review":["herdr"]}}\n' > "$TEST_ROOT/settings.json"
: > "$TEST_LOG"
bash "$TEST_ROOT/scripts/update-all.sh" review
assert_calls ''
echo 'PASS: deny list also applies to reviewed apps'

printf '{ invalid json\n' > "$TEST_ROOT/settings.json"
: > "$TEST_LOG"
if bash "$TEST_ROOT/scripts/update-all.sh" direct > "$TEST_ROOT/error" 2>&1; then
  echo 'FAIL: malformed settings were ignored' >&2
  exit 1
fi
assert_calls ''
echo 'PASS: malformed policy stops before running any updater'

if bash "$TEST_ROOT/scripts/update-all.sh" typo > "$TEST_ROOT/error" 2>&1; then
  echo 'FAIL: unknown update channel was accepted' >&2
  exit 1
fi
echo 'PASS: unknown update channel is rejected'
