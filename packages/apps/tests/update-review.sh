#!/usr/bin/env bash
set -euo pipefail

SOURCE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(cd "$(mktemp -d)" && pwd -P)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pass() {
  printf 'PASS: %s\n' "$1"
}

assert_equals() {
  local description="$1"
  local expected="$2"
  local actual="$3"

  if [ "$actual" != "$expected" ]; then
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' \
      "$description" "$expected" "$actual" >&2
    exit 1
  fi
  pass "$description"
}

assert_file_contains() {
  local description="$1"
  local path="$2"
  local pattern="$3"

  rg -q -- "$pattern" "$path" || fail "$description"
  pass "$description"
}

assert_missing() {
  local description="$1"
  local path="$2"

  [ ! -e "$path" ] || fail "$description"
  pass "$description"
}

commit() {
  local repo="$1"
  local message="$2"

  git -C "$repo" add -A
  git -C "$repo" \
    -c commit.gpgsign=false \
    -c core.hooksPath=/dev/null \
    -c user.name='App review test' \
    -c user.email='app-review-test@example.invalid' \
    commit -q -m "$message"
}

make_fixture() {
  local name="$1"

  FIXTURE="$TEST_ROOT/$name"
  REPO="$FIXTURE/repo"
  ORIGIN="$FIXTURE/origin.git"
  BIN="$FIXTURE/bin"
  GH_LOG="$FIXTURE/gh.log"
  UPDATE_LOG="$FIXTURE/update.log"

  mkdir -p "$REPO/packages/apps/scripts" \
    "$REPO/packages/apps/review-app" \
    "$REPO/packages/apps/direct-app" \
    "$BIN"
  cp "$SOURCE_ROOT/scripts/update-review.sh" "$REPO/packages/apps/scripts/update-review.sh"
  cp "$SOURCE_ROOT/scripts/update-all.sh" "$REPO/packages/apps/scripts/update-all.sh"
  cp "$SOURCE_ROOT/scripts/sync-readme-versions.sh" "$REPO/packages/apps/scripts/sync-readme-versions.sh"
  chmod +x "$REPO/packages/apps/scripts/"*.sh

  cat > "$REPO/packages/apps/settings.json" <<'EOF'
{
  "update": {
    "deny": [],
    "review": ["review-app"]
  }
}
EOF
  printf '{ version = "1.0.0"; }\n' > "$REPO/packages/apps/review-app/package.nix"
  printf '{ version = "1.0.0"; }\n' > "$REPO/packages/apps/direct-app/package.nix"
  printf '# Fixture app catalog\n' > "$REPO/packages/apps/README.md"

  for app in review-app direct-app; do
    cat > "$REPO/packages/apps/$app/update.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
printf '%s\n' "$(basename "$app_dir")" >> "$UPDATE_LOG"
if [ "${FAKE_UPDATE_CHANGES:-1}" = 1 ]; then
  printf '# updated\n' >> "$app_dir/package.nix"
fi
EOF
    chmod +x "$REPO/packages/apps/$app/update.sh"
  done

  cat > "$BIN/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$FAKE_GH_LOG"
case "${1:-} ${2:-}" in
  'pr list')
    [ -z "${FAKE_PENDING_URL:-}" ] || printf '%s\n' "$FAKE_PENDING_URL"
    ;;
  'pr create')
    git --git-dir="$FAKE_ORIGIN" rev-parse --verify \
      "refs/heads/$FAKE_EXPECT_BRANCH" >/dev/null
    printf 'https://example.invalid/pull/1\n'
    ;;
  'workflow run')
    [ "${FAKE_DISPATCH_FAIL:-0}" != 1 ]
    ;;
  *)
    printf 'Unexpected gh invocation: %s\n' "$*" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$BIN/gh"

  git init -q --bare "$ORIGIN"
  git -C "$REPO" init -q -b main
  git -C "$REPO" remote add origin "$ORIGIN"
  commit "$REPO" 'initial fixture'
  git -C "$REPO" push -q -u origin main
  BASE_SHA="$(git -C "$REPO" rev-parse HEAD)"
}

run_review() {
  local run_id="$1"
  local attempt="$2"
  shift 2

  env \
    PATH="$BIN:$PATH" \
    FAKE_GH_LOG="$GH_LOG" \
    FAKE_ORIGIN="$ORIGIN" \
    FAKE_EXPECT_BRANCH="automation/app-review-$run_id-$attempt" \
    UPDATE_LOG="$UPDATE_LOG" \
    GITHUB_REPOSITORY='example/repository' \
    GITHUB_RUN_ID="$run_id" \
    GITHUB_RUN_ATTEMPT="$attempt" \
    "$@" \
    bash "$REPO/packages/apps/scripts/update-review.sh"
}

make_fixture pending
git -C "$REPO" switch -q -c automation/app-review-human
printf '# human fix\n' >> "$REPO/packages/apps/review-app/package.nix"
commit "$REPO" 'preserve human fix'
git -C "$REPO" push -q -u origin automation/app-review-human
HUMAN_SHA="$(git --git-dir="$ORIGIN" rev-parse refs/heads/automation/app-review-human)"
git -C "$REPO" switch -q main
run_review 100 1 FAKE_PENDING_URL='https://example.invalid/pull/7'
assert_missing "an open review PR prevents updater invocation" "$UPDATE_LOG"
assert_equals "an open review PR leaves its human branch untouched" \
  "$HUMAN_SHA" \
  "$(git --git-dir="$ORIGIN" rev-parse refs/heads/automation/app-review-human)"
assert_equals "the pending check is the only GitHub operation" \
  'pr list --repo example/repository --state open --base main --limit 1000 --json headRefName,url --jq .[] | select(.headRefName | startswith("automation/app-review-")) | .url' \
  "$(<"$GH_LOG")"

make_fixture no-change
run_review 200 1 FAKE_UPDATE_CHANGES=0
assert_equals "a no-change run invokes only review updaters" \
  'review-app' "$(<"$UPDATE_LOG")"
assert_equals "a no-change run does not publish a branch" \
  '' "$(git --git-dir="$ORIGIN" for-each-ref --format='%(refname:short)' 'refs/heads/automation/*')"
assert_equals "a no-change run does not create or dispatch a PR" \
  'pr list --repo example/repository --state open --base main --limit 1000 --json headRefName,url --jq .[] | select(.headRefName | startswith("automation/app-review-")) | .url' \
  "$(<"$GH_LOG")"

make_fixture success
SUCCESS_BRANCH='automation/app-review-300-2'
run_review 300 2 FAKE_UPDATE_CHANGES=1
assert_equals "candidate generation invokes only review updaters" \
  'review-app' "$(<"$UPDATE_LOG")"
assert_equals "the candidate contains only review app changes" \
  'packages/apps/review-app/package.nix' \
  "$(git --git-dir="$ORIGIN" diff --name-only refs/heads/main "refs/heads/$SUCCESS_BRANCH")"
success_second_call="$(sed -n '2p' "$GH_LOG")"
success_third_call="$(sed -n '3p' "$GH_LOG")"
assert_file_contains "the PR is created after its branch is pushed" \
  "$GH_LOG" "^pr create .*--head $SUCCESS_BRANCH "
assert_equals "the PR is created before candidate CI is dispatched" \
  'pr create' "${success_second_call%% --*}"
assert_equals "candidate CI is dispatched with the original base SHA" \
  "workflow run apps-ci.yml --repo example/repository --ref $SUCCESS_BRANCH -f base_sha=$BASE_SHA" \
  "$success_third_call"

make_fixture dispatch-failure
FAILURE_BRANCH='automation/app-review-400-1'
set +e
run_review 400 1 FAKE_UPDATE_CHANGES=1 FAKE_DISPATCH_FAIL=1 \
  > "$FIXTURE/stdout" 2> "$FIXTURE/stderr"
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "a dispatch failure returns nonzero"
pass "a dispatch failure returns nonzero"
git --git-dir="$ORIGIN" rev-parse --verify "refs/heads/$FAILURE_BRANCH" >/dev/null \
  || fail "a dispatch failure preserves the candidate branch"
pass "a dispatch failure preserves the candidate branch"
failure_third_call="$(sed -n '3p' "$GH_LOG")"
assert_file_contains "a dispatch failure happens after PR creation" \
  "$GH_LOG" "^pr create .*--head $FAILURE_BRANCH "
assert_equals "the failing dispatch targets the preserved branch" \
  "workflow run apps-ci.yml --repo example/repository --ref $FAILURE_BRANCH -f base_sha=$BASE_SHA" \
  "$failure_third_call"
assert_file_contains "a dispatch failure explains how to rerun CI" \
  "$FIXTURE/stderr" "Candidate PR exists, but CI dispatch failed.*$FAILURE_BRANCH.*base_sha=$BASE_SHA"
