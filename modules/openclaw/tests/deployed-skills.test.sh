#!/usr/bin/env bash

set -euo pipefail

managed_skills_dir="${AGENT_CORE_OPENCLAW_SKILLS:-${HOME}/.local/share/openclaw/agent-core/skills}"
extensions_dir="${AGENT_CORE_OPENCLAW_EXTENSIONS:-${HOME}/.local/share/openclaw/extensions}"

fail() {
  printf 'openclaw deployed skill test failed: %s\n' "$1" >&2
  exit 1
}

verify_ordinary_tree() {
  local label="$1"
  local tree="$2"
  local file link_count
  local -a files=()

  test -d "$tree" || fail "$label is missing: $tree"
  [[ ! -L "$tree" ]] || fail "$label must be an ordinary directory, not a symbolic link: $tree"
  while IFS= read -r -d '' file; do
    files+=("$file")
  done < <(find -P "$tree" -type f -print0)
  (( ${#files[@]} > 0 )) || fail "$label contains no files: $tree"

  while IFS= read -r -d '' file; do
    fail "$label must not contain symbolic links: $file"
  done < <(find -P "$tree" -type l -print0)

  for file in "${files[@]}"; do
    [[ ! -L "$file" ]] || fail "$label file must not be a symbolic link: $file"
    link_count="$(stat --format=%h -- "$file")" || fail "could not read link count: $file"
    [[ "$link_count" == 1 ]] || fail "$label file must not be hardlinked (link count $link_count): $file"
  done
}

test -d "$managed_skills_dir" || fail "managed skill directory is missing: $managed_skills_dir"
[[ ! -L "$managed_skills_dir" ]] || fail "managed skill directory must be an ordinary directory, not a symbolic link: $managed_skills_dir"
expected_names="$(bash "$(dirname "$0")/expected-skill-names.sh")" || fail "could not determine declared skills"
skill_count=0
while IFS= read -r skill_name; do
  [[ -f "$managed_skills_dir/$skill_name/SKILL.md" ]] || fail "declared skill is missing: $skill_name"
  verify_ordinary_tree "declared skill $skill_name" "$managed_skills_dir/$skill_name"
  skill_count=$((skill_count + 1))
done <<<"$expected_names"

for extension_name in agent-core-context agent-session-record; do
  extension_dir="$extensions_dir/$extension_name"
  verify_ordinary_tree "managed extension $extension_name" "$extension_dir"
  manifest="$extension_dir/openclaw.plugin.json"
  [[ -f "$manifest" && ! -L "$manifest" ]] ||
    fail "managed extension $extension_name has no ordinary plugin manifest: $manifest"
done

printf 'openclaw deployed resource test passed for %d declared skill(s) and 2 extension(s)\n' "$skill_count"
