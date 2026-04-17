#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

FLAKE_LOCK="flake.lock"
INPUT_NAME="flake-stores"
GITHUB_REPO="gytkk/flake-stores"
GITHUB_URL="https://github.com/${GITHUB_REPO}.git"
REMOTE_REF="refs/heads/main"

ensure_nix_ssl_cert_file() {
  if [[ -n "${NIX_SSL_CERT_FILE:-}" && -r "${NIX_SSL_CERT_FILE}" ]]; then
    return 0
  fi

  if [[ -n "${SSL_CERT_FILE:-}" && -r "${SSL_CERT_FILE}" ]]; then
    export NIX_SSL_CERT_FILE="${SSL_CERT_FILE}"
    return 0
  fi

  local candidate=""
  for candidate in \
    /nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt \
    /etc/ssl/certs/ca-bundle.crt \
    /etc/ssl/certs/ca-certificates.crt
  do
    if [[ -r "$candidate" ]]; then
      export NIX_SSL_CERT_FILE="$candidate"
      return 0
    fi
  done

  local cacert_out=""
  cacert_out="$(NIX_SSL_CERT_FILE= SSL_CERT_FILE= nix eval --raw nixpkgs#cacert.outPath 2>/dev/null || true)"
  if [[ -n "$cacert_out" && -r "${cacert_out}/etc/ssl/certs/ca-bundle.crt" ]]; then
    export NIX_SSL_CERT_FILE="${cacert_out}/etc/ssl/certs/ca-bundle.crt"
    return 0
  fi

  echo "Failed to determine a usable CA bundle for Nix HTTPS fetches." >&2
  exit 1
}

get_remote_head_rev() {
  git ls-remote "$GITHUB_URL" "$REMOTE_REF" | awk '{ print $1 }'
}

ensure_nix_ssl_cert_file
remote_head_rev="$(get_remote_head_rev)"

if [[ -z "$remote_head_rev" ]]; then
  echo "Failed to resolve ${GITHUB_REPO} ${REMOTE_REF}." >&2
  exit 1
fi

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

if [[ "$new_rev" != "$remote_head_rev" ]]; then
  echo "Expected ${INPUT_NAME} to update to ${remote_head_rev}, but flake.lock now points to ${new_rev}." >&2
  echo "This usually means Nix could not refresh the remote input state." >&2
  exit 1
fi

if [[ "$old_rev" == "$new_rev" ]]; then
  echo "No updates available for ${INPUT_NAME}."
  echo ""
  echo "Current package versions:"
  while IFS='=' read -r pkg full_name; do
    [[ -z "$pkg" ]] && continue
    ver="${full_name#"${pkg}-"}"
    echo "  - ${pkg}: ${ver}"
  done <<< "$old_packages"
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
  old_full_name=$(echo "$old_packages" | rg "^${pkg}=" | head -1 | cut -d= -f2- || true)
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
