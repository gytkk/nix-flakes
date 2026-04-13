#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

FLAKE_LOCK="flake.lock"
INPUT_NAME="flake-stores"
GITHUB_REPO="gytkk/flake-stores"

old_rev=$(jq -r ".nodes.\"${INPUT_NAME}\".locked.rev" "$FLAKE_LOCK")
old_modified=$(jq -r ".nodes.\"${INPUT_NAME}\".locked.lastModified" "$FLAKE_LOCK")

# Capture package versions from current (old) flake-stores
echo "Capturing current package versions..."
old_packages=$(nix flake show "github:${GITHUB_REPO}/${old_rev}" --json 2>/dev/null \
  | jq -r '.packages["aarch64-darwin"] // {} | to_entries[] | select(.key != "default") | "\(.key)=\(.value.name // "")"')

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

# Capture package versions from new flake-stores
echo "Capturing new package versions..."
new_packages=$(nix flake show "github:${GITHUB_REPO}/${new_rev}" --json 2>/dev/null \
  | jq -r '.packages["aarch64-darwin"] // {} | to_entries[] | select(.key != "default") | "\(.key)=\(.value.name // "")"')

# Compare old vs new package versions and build change summary
package_changes=""
while IFS='=' read -r pkg new_full_name; do
  [[ -z "$pkg" ]] && continue
  old_full_name=$(echo "$old_packages" | rg "^${pkg}=" | head -1 | cut -d= -f2-)
  # Extract version: strip package name prefix (handle names with hyphens)
  new_ver="${new_full_name#"${pkg}-"}"
  old_ver="${old_full_name#"${pkg}-"}"
  if [[ "$old_ver" != "$new_ver" ]]; then
    if [[ -z "$old_ver" ]]; then
      package_changes+="  - ${pkg}: (new) ${new_ver}"$'\n'
    else
      package_changes+="  - ${pkg}: ${old_ver} -> ${new_ver}"$'\n'
    fi
  fi
done <<< "$new_packages"

# Check for removed packages
while IFS='=' read -r pkg old_full_name; do
  [[ -z "$pkg" ]] && continue
  if ! echo "$new_packages" | rg -q "^${pkg}="; then
    old_ver="${old_full_name#"${pkg}-"}"
    package_changes+="  - ${pkg}: ${old_ver} (removed)"$'\n'
  fi
done <<< "$old_packages"

# Remove trailing newline
package_changes="${package_changes%$'\n'}"

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
  echo ""
  echo "No package version changes."
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
