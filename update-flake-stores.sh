#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

FLAKE_LOCK="flake.lock"
INPUT_NAME="flake-stores"
GITHUB_REPO="gytkk/flake-stores"

old_rev=$(jq -r ".nodes.\"${INPUT_NAME}\".locked.rev" "$FLAKE_LOCK")
old_modified=$(jq -r ".nodes.\"${INPUT_NAME}\".locked.lastModified" "$FLAKE_LOCK")

echo "Updating ${INPUT_NAME}..."
nix flake update "$INPUT_NAME"

new_rev=$(jq -r ".nodes.\"${INPUT_NAME}\".locked.rev" "$FLAKE_LOCK")
new_modified=$(jq -r ".nodes.\"${INPUT_NAME}\".locked.lastModified" "$FLAKE_LOCK")

if [[ "$old_rev" == "$new_rev" ]]; then
  echo "No updates available for ${INPUT_NAME}."
  exit 0
fi

format_date() {
  date -r "$1" "+%Y-%m-%d" 2>/dev/null || date -d "@$1" "+%Y-%m-%d" 2>/dev/null || echo "$1"
}

old_date=$(format_date "$old_modified")
new_date=$(format_date "$new_modified")
old_short="${old_rev:0:12}"
new_short="${new_rev:0:12}"

echo ""
echo "Fetching package changes..."

fetch_commit_info() {
  local rev="$1"
  curl -s "https://api.github.com/repos/${GITHUB_REPO}/commits/${rev}" \
    -H "Accept: application/vnd.github.v3+json" 2>/dev/null | \
    jq -r '.commit.message // empty' 2>/dev/null || echo ""
}

fetch_commits_between() {
  local old="$1"
  local new="$2"
  curl -s "https://api.github.com/repos/${GITHUB_REPO}/compare/${old}...${new}" \
    -H "Accept: application/vnd.github.v3+json" 2>/dev/null | \
    jq -r '.commits[] | select(.commit.message | test("^(Update|Add|Remove|Bump|Upgrade|Downgrade)"; "i")) | "  - " + (.commit.message | split("\n")[0])' 2>/dev/null || echo ""
}

package_changes=$(fetch_commits_between "$old_rev" "$new_rev")

echo ""
echo "=== ${INPUT_NAME} updated ==="
echo "  rev:  ${old_short} -> ${new_short}"
echo "  date: ${old_date} -> ${new_date}"
echo "  https://github.com/${GITHUB_REPO}/compare/${old_short}...${new_short}"

if [[ -n "$package_changes" ]]; then
  echo ""
  echo "Package changes:"
  echo "$package_changes"
else
  new_commit_msg=$(fetch_commit_info "$new_rev")
  if [[ -n "$new_commit_msg" ]]; then
    echo ""
    echo "Latest commit:"
    echo "  $(echo "$new_commit_msg" | head -1)"
  fi
fi

echo ""

commit_msg="chore(flake): update ${INPUT_NAME}

${old_short} -> ${new_short} (${old_date} -> ${new_date})
https://github.com/${GITHUB_REPO}/compare/${old_short}...${new_short}"

if [[ -n "$package_changes" ]]; then
  commit_msg="${commit_msg}

Package changes:
${package_changes}"
fi

git add "$FLAKE_LOCK"
git commit -m "$commit_msg"

echo "Committed changes."
