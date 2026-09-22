#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK_PATCHES="$SOURCE_ROOT/scripts/check-nix-patches.sh"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

check_patches() {
  bash "$CHECK_PATCHES" "$@"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_same() {
  local description="$1"
  local actual="$2"
  local expected="$3"

  cmp -s "$actual" "$expected" || fail "$description"
  printf 'PASS: %s\n' "$description"
}

assert_fails() {
  local description="$1"
  shift

  if "$@"; then
    fail "$description"
  fi
  printf 'PASS: %s\n' "$description"
}

assert_missing() {
  local description="$1"
  local path="$2"

  [ ! -e "$path" ] || fail "$description"
  printf 'PASS: %s\n' "$description"
}

write_manifest() {
  local path="$1"
  shift

  {
    printf '[\n'
    for patch_path in "$@"; do
      printf '  ./%s\n' "$(basename "$patch_path")"
    done
    printf ']\n'
  } > "$path"
}

FIXTURES="$TEST_ROOT/fixtures"
mkdir -p "$FIXTURES/source" "$FIXTURES/final-source"
printf 'first\nsecond\nthird\n' > "$FIXTURES/source/story.txt"
printf 'final\nsecond\nthird\n' > "$FIXTURES/final-source/story.txt"
cp "$FIXTURES/source/story.txt" "$FIXTURES/original-story.txt"
cp "$FIXTURES/final-source/story.txt" "$FIXTURES/original-final-story.txt"

write_manifest "$FIXTURES/empty-patches.nix"
check_patches "$FIXTURES/source" "$FIXTURES/empty-patches.nix"
assert_same "an empty patch list leaves the fetched source unchanged" \
  "$FIXTURES/source/story.txt" "$FIXTURES/original-story.txt"

cat > "$FIXTURES/first.patch" <<'EOF'
--- a/story.txt
+++ b/story.txt
@@ -1,3 +1,3 @@
-first
+intermediate
 second
 third
EOF

cat > "$FIXTURES/second.patch" <<'EOF'
--- a/story.txt
+++ b/story.txt
@@ -1,3 +1,3 @@
-intermediate
+final
 second
 third
EOF

cat > "$FIXTURES/failing-third.patch" <<'EOF'
--- a/story.txt
+++ b/story.txt
@@ -1,3 +1,3 @@
-missing
+never-written
 second
 third
EOF

write_manifest "$FIXTURES/ordered-patches.nix" \
  "$FIXTURES/first.patch" \
  "$FIXTURES/second.patch"
check_patches "$FIXTURES/source" "$FIXTURES/ordered-patches.nix"
assert_same "sequential patches leave the fetched source unchanged" \
  "$FIXTURES/source/story.txt" "$FIXTURES/original-story.txt"

write_manifest "$FIXTURES/reversed-patches.nix" \
  "$FIXTURES/second.patch" \
  "$FIXTURES/first.patch"
assert_fails "dependent patches fail in reverse order" \
  check_patches "$FIXTURES/source" "$FIXTURES/reversed-patches.nix"
assert_same "a reverse-order failure leaves the fetched source unchanged" \
  "$FIXTURES/source/story.txt" "$FIXTURES/original-story.txt"

write_manifest "$FIXTURES/failing-patches.nix" \
  "$FIXTURES/first.patch" \
  "$FIXTURES/second.patch" \
  "$FIXTURES/failing-third.patch"
assert_fails "a failed later patch is reported" \
  check_patches "$FIXTURES/source" "$FIXTURES/failing-patches.nix"
assert_same "a later-patch failure leaves the fetched source unchanged" \
  "$FIXTURES/source/story.txt" "$FIXTURES/original-story.txt"

assert_fails "already-applied patches are not reversed" \
  check_patches "$FIXTURES/final-source" "$FIXTURES/ordered-patches.nix"
assert_same "a reverse-application rejection leaves the fetched source unchanged" \
  "$FIXTURES/final-source/story.txt" "$FIXTURES/original-final-story.txt"

mkdir -p "$FIXTURES/fuzzy-source"
printf 'different heading\nshared context\nold value\ntrailing context\n' > "$FIXTURES/fuzzy-source/fuzzy.txt"
cp "$FIXTURES/fuzzy-source/fuzzy.txt" "$FIXTURES/original-fuzzy.txt"
cat > "$FIXTURES/fuzzy.patch" <<'EOF'
--- a/fuzzy.txt
+++ b/fuzzy.txt
@@ -1,4 +1,4 @@
 expected heading
 shared context
-old value
+new value
 trailing context
EOF
write_manifest "$FIXTURES/fuzzy-patches.nix" "$FIXTURES/fuzzy.patch"
check_patches "$FIXTURES/fuzzy-source" "$FIXTURES/fuzzy-patches.nix"
assert_same "default patch fuzz leaves the fetched source unchanged" \
  "$FIXTURES/fuzzy-source/fuzzy.txt" "$FIXTURES/original-fuzzy.txt"

ANNOTATE_ROOT="$TEST_ROOT/annotate-updater"
MOCK_BIN="$ANNOTATE_ROOT/mock-bin"
ANNOTATE_APP="$ANNOTATE_ROOT/apps/herdr-annotate"
mkdir -p "$MOCK_BIN" "$ANNOTATE_ROOT/apps/scripts" "$ANNOTATE_APP" "$ANNOTATE_ROOT/plannotator-source"
cp "$SOURCE_ROOT/scripts/check-nix-patches.sh" "$ANNOTATE_ROOT/apps/scripts/check-nix-patches.sh"
for file in update.sh package.nix sources.json patches.nix selection-background.patch inherit-herdr-theme.patch; do
  cp "$SOURCE_ROOT/herdr-annotate/$file" "$ANNOTATE_APP/$file"
done
cp "$ANNOTATE_APP/package.nix" "$ANNOTATE_ROOT/original-package.nix"
cp "$ANNOTATE_APP/sources.json" "$ANNOTATE_ROOT/original-sources.json"

cat > "$MOCK_BIN/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

url="${!#}"
case "$url" in
  */commits/main)
    printf '%s\n' '{"sha":"fixture-revision","commit":{"committer":{"date":"2026-09-22T00:00:00Z"}}}'
    ;;
  */herdr-plugin.toml)
    printf '%s\n' 'version = "9.9.9"'
    ;;
  */herdr-annotate.version)
    printf '%s\n' '9.9.9'
    ;;
  */plannotator-tui.version)
    printf '%s\n' '9.9.9'
    ;;
  *)
    printf 'unexpected curl URL: %s\n' "$url" >&2
    exit 1
    ;;
esac
EOF

cat > "$MOCK_BIN/nix-prefetch-url" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' '0fixturehash'
EOF

cat > "$MOCK_BIN/nix" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$1 $2" in
  "hash convert")
    printf '%s\n' 'sha256-fixture-source'
    ;;
  "store prefetch-file")
    jq -n --arg path "$MOCK_FIXTURE_SOURCE" '{ hash: "sha256-fixture-plannotator", storePath: $path }'
    ;;
  "build "*)
    : > "$MOCK_NIX_BUILD_MARKER"
    printf 'Cargo hash build must not run after patch preflight failure\n' >&2
    exit 1
    ;;
  *)
    printf 'unexpected nix arguments: %s\n' "$*" >&2
    exit 1
    ;;
esac
EOF
chmod +x "$MOCK_BIN/curl" "$MOCK_BIN/nix-prefetch-url" "$MOCK_BIN/nix"

run_annotate_update() {
  env \
    PATH="$MOCK_BIN:$PATH" \
    MOCK_FIXTURE_SOURCE="$ANNOTATE_ROOT/plannotator-source" \
    MOCK_NIX_BUILD_MARKER="$ANNOTATE_ROOT/cargo-build-called" \
    bash "$ANNOTATE_APP/update.sh" > "$ANNOTATE_ROOT/update.log" 2>&1
}

assert_fails "Annotate updater stops at patch preflight failure" \
  run_annotate_update
rg -q 'ERROR: .*selection-background.patch does not apply' "$ANNOTATE_ROOT/update.log" \
  || fail "Annotate must fail at the actual patch preflight"
assert_same "Annotate preflight failure leaves package metadata unchanged" \
  "$ANNOTATE_APP/package.nix" "$ANNOTATE_ROOT/original-package.nix"
assert_same "Annotate preflight failure leaves source metadata unchanged" \
  "$ANNOTATE_APP/sources.json" "$ANNOTATE_ROOT/original-sources.json"
assert_missing "Annotate preflight failure skips Cargo hash discovery" \
  "$ANNOTATE_ROOT/cargo-build-called"
