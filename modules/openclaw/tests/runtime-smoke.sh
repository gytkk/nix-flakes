#!/usr/bin/env bash

set -euo pipefail

openclaw_bin="${OPENCLAW_BIN:-openclaw}"
state_dir="${OPENCLAW_STATE_DIR:-${HOME}/.openclaw}"
instruction_file="${AGENT_CORE_OPENCLAW_INSTRUCTIONS:-${state_dir}/managed/agent-core/AGENTS.core.md}"
managed_skills_dir="${AGENT_CORE_OPENCLAW_SKILLS:-${HOME}/.local/share/openclaw/agent-core/skills}"

fail() {
  printf 'openclaw agent-core smoke failed: %s\n' "$1" >&2
  exit 1
}

command -v "$openclaw_bin" >/dev/null || fail "OpenClaw CLI is unavailable"
command -v jq >/dev/null || fail "jq is unavailable"
test -s "$instruction_file" || fail "rendered instructions are missing or empty: $instruction_file"
test -d "$managed_skills_dir" || fail "managed skill directory is missing: $managed_skills_dir"

plugin_json="$($openclaw_bin plugins inspect agent-core-context --runtime --json)"
jq -e '
  .plugin.enabled == true
  and .plugin.status == "loaded"
  and ([.typedHooks[]?.name] | map(select(. == "before_prompt_build")) | length == 1)
  and (.diagnostics | length == 0)
' >/dev/null <<<"$plugin_json" || fail "agent-core-context is not loaded cleanly with one before_prompt_build hook"

doctor_output="$($openclaw_bin plugins doctor)"
[[ "$doctor_output" == *"Plugin discovery, module loading, compatibility, and configuration checks passed."* ]] ||
  fail "OpenClaw reports plugin issues"

shopt -s nullglob
skill_documents=("$managed_skills_dir"/*/SKILL.md)
(( ${#skill_documents[@]} > 0 )) || fail "managed skill directory contains no skills"

agents_json="$($openclaw_bin agents list --json)"
mapfile -t agent_ids < <(jq -r '.[].id' <<<"$agents_json")
(( ${#agent_ids[@]} > 0 )) || fail "OpenClaw reports no agents"

declare -A workspaces=()
for agent_id in "${agent_ids[@]}"; do
  skills_json="$($openclaw_bin skills list --agent "$agent_id" --json)"
  workspace_dir="$(jq -r '.workspaceDir' <<<"$skills_json")"
  workspaces["$workspace_dir"]=1

  for skill_document in "${skill_documents[@]}"; do
    skill_name="$(basename "$(dirname "$skill_document")")"
    source_name="$(
      jq -r --arg name "$skill_name" '.skills[] | select(.name == $name) | .source' <<<"$skills_json"
    )"
    case "$source_name" in
      openclaw-extra)
        ;;
      openclaw-workspace)
        resolved_source="$($openclaw_bin skills info --agent "$agent_id" "$skill_name" --json | jq -r '.source')"
        [[ "$resolved_source" == "openclaw-workspace" ]] || fail "workspace override did not win for $agent_id:$skill_name"
        ;;
      *)
        fail "managed skill is not discoverable for $agent_id:$skill_name"
        ;;
    esac
  done
done

if (( ${#workspaces[@]} < 2 )); then
  printf 'openclaw agent-core smoke: multi-workspace check skipped; all agents use %s\n' "${!workspaces[*]}"
fi
printf 'openclaw agent-core smoke passed for %d agent(s)\n' "${#agent_ids[@]}"
