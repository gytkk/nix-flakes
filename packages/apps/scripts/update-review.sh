#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_REPOSITORY:?Run this script from the app update workflow}"
: "${GITHUB_RUN_ID:?Missing workflow run ID}"
: "${GITHUB_RUN_ATTEMPT:?Missing workflow run attempt}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
BRANCH_PREFIX="automation/app-review-"

pending=$(gh pr list --repo "$GITHUB_REPOSITORY" --state open --base main \
  --limit 1000 --json headRefName,url \
  --jq '.[] | select(.headRefName | startswith("automation/app-review-")) | .url')
if [ -n "$pending" ]; then
  printf 'Review candidate already exists; preserving its branch:\n%s\n' "$pending"
  exit 0
fi

if [ -n "$(git -C "$REPO_ROOT" status --porcelain)" ]; then
  echo "ERROR: Candidate generation requires a clean checkout" >&2
  exit 1
fi

base_sha=$(git -C "$REPO_ROOT" rev-parse HEAD)
bash "$SCRIPT_DIR/update-all.sh" review
bash "$SCRIPT_DIR/sync-readme-versions.sh"
if git -C "$REPO_ROOT" diff --quiet -- packages/apps; then
  echo "No reviewed package updates"
  exit 0
fi

branch="${BRANCH_PREFIX}${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}"
git -C "$REPO_ROOT" switch -c "$branch"
git -C "$REPO_ROOT" add packages/apps
git -C "$REPO_ROOT" \
  -c user.name='github-actions[bot]' \
  -c user.email='github-actions[bot]@users.noreply.github.com' \
  commit -m 'chore(apps): update reviewed app versions'
git -C "$REPO_ROOT" push origin "HEAD:refs/heads/$branch"

body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT
cat > "$body_file" <<EOF
Update the app packages assigned to review in packages/apps/settings.json.

All declared local patches passed preflight. App Packages CI is dispatched separately on this candidate branch to evaluate and build the changed packages. Merge only after that run succeeds.

The updater preserves this branch while the PR is open, including any manual fixes. Close or merge this PR before requesting a newer candidate.
EOF

gh pr create --repo "$GITHUB_REPOSITORY" --base main --head "$branch" \
  --title 'chore(apps): update reviewed app versions' --body-file "$body_file"

# Explicit dispatch runs CI even when GITHUB_TOKEN-created PR events need approval.
if ! gh workflow run apps-ci.yml --repo "$GITHUB_REPOSITORY" --ref "$branch" \
  -f "base_sha=$base_sha"; then
  echo "ERROR: Candidate PR exists, but CI dispatch failed. Run App Packages CI on $branch with base_sha=$base_sha." >&2
  exit 1
fi
