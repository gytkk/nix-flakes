#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

FLAKE_LOCK="flake.lock"
INPUT_NAME="flake-stores"

# 현재 상태 저장
old_rev=$(jq -r ".nodes.\"${INPUT_NAME}\".locked.rev" "$FLAKE_LOCK")
old_modified=$(jq -r ".nodes.\"${INPUT_NAME}\".locked.lastModified" "$FLAKE_LOCK")

# flake-stores 업데이트
echo "Updating ${INPUT_NAME}..."
nix flake update "$INPUT_NAME"

# 업데이트 후 상태
new_rev=$(jq -r ".nodes.\"${INPUT_NAME}\".locked.rev" "$FLAKE_LOCK")
new_modified=$(jq -r ".nodes.\"${INPUT_NAME}\".locked.lastModified" "$FLAKE_LOCK")

# 변경 없으면 종료
if [[ "$old_rev" == "$new_rev" ]]; then
  echo "No updates available for ${INPUT_NAME}."
  exit 0
fi

# 날짜 포맷 (macOS date -r, Linux date -d 순서로 시도)
format_date() {
  date -r "$1" "+%Y-%m-%d" 2>/dev/null || date -d "@$1" "+%Y-%m-%d" 2>/dev/null || echo "$1"
}

old_date=$(format_date "$old_modified")
new_date=$(format_date "$new_modified")
old_short="${old_rev:0:12}"
new_short="${new_rev:0:12}"

# 변경 내역 출력
echo ""
echo "=== ${INPUT_NAME} updated ==="
echo "  rev:  ${old_short} -> ${new_short}"
echo "  date: ${old_date} -> ${new_date}"
echo "  https://github.com/gytkk/flake-stores/compare/${old_short}...${new_short}"
echo ""

# 커밋
commit_msg="chore(flake): update ${INPUT_NAME}

${old_short} -> ${new_short} (${old_date} -> ${new_date})
https://github.com/gytkk/flake-stores/compare/${old_short}...${new_short}"

git add "$FLAKE_LOCK"
git commit -m "$commit_msg"
