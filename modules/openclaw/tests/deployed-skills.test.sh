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

verify_ordinary_tree "managed skill directory" "$managed_skills_dir"
shopt -s nullglob
skill_documents=("$managed_skills_dir"/*/SKILL.md)
(( ${#skill_documents[@]} > 0 )) || fail "managed skill directory contains no skills"

for extension_name in agent-core-context agent-session-record; do
  extension_dir="$extensions_dir/$extension_name"
  verify_ordinary_tree "managed extension $extension_name" "$extension_dir"
  manifest="$extension_dir/openclaw.plugin.json"
  [[ -f "$manifest" && ! -L "$manifest" ]] ||
    fail "managed extension $extension_name has no ordinary plugin manifest: $manifest"
done

printf 'openclaw deployed resource test passed for %d skill(s) and 2 extension(s)\n' "${#skill_documents[@]}"
