#!/usr/bin/env bash

set -euo pipefail

openclaw_bin="${OPENCLAW_BIN:-openclaw}"
instruction_file="${AGENT_CORE_OPENCLAW_INSTRUCTIONS:-${HOME}/.local/share/openclaw/agent-core/AGENTS.core.md}"
managed_skills_dir="${AGENT_CORE_OPENCLAW_SKILLS:-${HOME}/.local/share/openclaw/agent-core/skills}"
drop_in="${AGENT_CORE_OPENCLAW_DROP_IN:-${HOME}/.config/systemd/user/openclaw-gateway.service.d/20-nix-runtime.conf}"

fail() {
  printf 'openclaw agent-core smoke failed: %s\n' "$1" >&2
  exit 1
}

command -v "$openclaw_bin" >/dev/null || fail "OpenClaw CLI is unavailable"
command -v jq >/dev/null || fail "jq is unavailable"
command -v rg >/dev/null || fail "ripgrep is unavailable"
test -s "$instruction_file" || fail "rendered instructions are missing or empty: $instruction_file"
test -d "$managed_skills_dir" || fail "managed skill directory is missing: $managed_skills_dir"
[[ ! -L "$managed_skills_dir" ]] || fail "managed skill directory must not be a symbolic link: $managed_skills_dir"
[[ -f "$drop_in" && ! -L "$drop_in" ]] || fail "service environment drop-in is missing or symlinked: $drop_in"
rg -q '^Environment="LD_LIBRARY_PATH=' "$drop_in" || fail "service drop-in lacks library path"
rg -Fqx 'UnsetEnvironment=CLAWDBOT_CONFIG_PATH CLAWDBOT_STATE_DIR' "$drop_in" || fail "service drop-in lacks legacy environment cleanup"
rg -Fqx "Environment=\"AGENT_CORE_OPENCLAW_INSTRUCTIONS=$instruction_file\"" "$drop_in" || fail "service drop-in lacks instruction path"

if ! plugin_json="$($openclaw_bin plugins inspect agent-core-context --runtime --json 2>&1)"; then
  fail "could not inspect agent-core-context: ${plugin_json:-OpenClaw returned no diagnostic}"
fi
jq -e '
  .plugin.enabled == true
  and .plugin.status == "loaded"
  and ([.typedHooks[]?.name] | map(select(. == "before_prompt_build")) | length == 1)
  and (.diagnostics | length == 0)
' >/dev/null <<<"$plugin_json" || fail "agent-core-context is not loaded cleanly with one before_prompt_build hook"

if ! recorder_json="$("$openclaw_bin" plugins inspect agent-session-record --runtime --json 2>&1)"; then
  fail "could not inspect agent-session-record: $recorder_json"
fi
jq -e '.plugin.enabled == true and .plugin.status == "loaded" and (.diagnostics | length == 0)
  and ([.typedHooks[]?.name] | map(select(. == "session_end")) | length == 1)' \
  >/dev/null <<<"$recorder_json" || fail "agent-session-record is not loaded cleanly with one session_end hook"

if ! doctor_output="$($openclaw_bin plugins doctor 2>&1)"; then
  fail "could not run plugin diagnostics: ${doctor_output:-OpenClaw returned no diagnostic}"
fi
[[ "$doctor_output" == *"Plugin discovery, module loading, compatibility, and configuration checks passed."* ]] ||
  fail "OpenClaw reports plugin issues"

if ! expected_names="$(bash "$(dirname "$0")/expected-skill-names.sh")"; then
  fail "could not determine declared skills"
fi
expected_skills=()
while IFS= read -r skill_name; do expected_skills+=("$skill_name"); done <<<"$expected_names"
for skill_name in "${expected_skills[@]}"; do
  skill_document="$managed_skills_dir/$skill_name/SKILL.md"
  [[ ! -L "$managed_skills_dir/$skill_name" ]] || fail "managed skill directory is symlinked: $skill_name"
  [[ -f "$skill_document" ]] || fail "managed skill is not a regular file: $skill_document"
  [[ ! -L "$skill_document" ]] || fail "managed skill must not be a symbolic link: $skill_document"
  link_count="$(stat --format=%h -- "$skill_document")" || fail "could not read managed skill link count: $skill_document"
  [[ "$link_count" == 1 ]] || fail "managed skill must not be hardlinked (link count $link_count): $skill_document"
done

if ! agents_json="$($openclaw_bin agents list --json 2>&1)"; then
  fail "could not list agents: ${agents_json:-OpenClaw returned no diagnostic}"
fi
agent_ids=()
agent_names="$(jq -er 'select(type == "array" and length > 0) | .[].id | select(type == "string" and length > 0)' <<<"$agents_json")" || fail "OpenClaw reports no valid agents"
while IFS= read -r agent_id; do agent_ids+=("$agent_id"); done <<<"$agent_names"
(( ${#agent_ids[@]} > 0 )) || fail "OpenClaw reports no agents"

workspaces=()
for agent_id in "${agent_ids[@]}"; do
  if ! skills_json="$($openclaw_bin skills list --agent "$agent_id" --json 2>&1)"; then
    fail "could not list skills for $agent_id: ${skills_json:-OpenClaw returned no diagnostic}"
  fi
  workspace_dir="$(jq -r '.workspaceDir' <<<"$skills_json")"
  [[ "$workspace_dir" == /* ]] || fail "invalid workspace path for $agent_id"
  workspaces+=("$workspace_dir")

  for skill_name in "${expected_skills[@]}"; do
    jq -e --arg name "$skill_name" '[.skills[] | select(.name == $name)] | length == 1' \
      >/dev/null <<<"$skills_json" || fail "expected one discovered entry for $agent_id:$skill_name"
    source_name="$(
      jq -r --arg name "$skill_name" '.skills[] | select(.name == $name) | .source' <<<"$skills_json"
    )"
    if ! skill_info="$("$openclaw_bin" skills info --agent "$agent_id" "$skill_name" --json 2>&1)"; then
      fail "could not inspect skill for $agent_id:$skill_name"
    fi
    jq -e --arg name "$skill_name" '.name == $name and (.description | type == "string" and length > 0)' \
      >/dev/null <<<"$skill_info" || fail "invalid skill discovery metadata for $agent_id:$skill_name"
    resolved_source="$(jq -er '.source' <<<"$skill_info")" || fail "missing skill source for $agent_id:$skill_name"
    resolved_path="$(jq -er '.filePath' <<<"$skill_info")" || fail "missing skill path for $agent_id:$skill_name"
    [[ "$resolved_source" == "$source_name" ]] || fail "inconsistent skill source for $agent_id:$skill_name"
    case "$source_name" in
      openclaw-extra)
        [[ "$resolved_path" == "$managed_skills_dir/$skill_name/SKILL.md" ]] || fail "wrong managed skill path for $agent_id:$skill_name: $resolved_path"
        ;;
      openclaw-workspace)
        [[ "$resolved_path" == "$workspace_dir/skills/$skill_name/SKILL.md" && -f "$resolved_path" ]] || fail "wrong workspace override path for $agent_id:$skill_name: $resolved_path"
        printf 'openclaw agent-core smoke: workspace override verified for %s:%s at %s\n' "$agent_id" "$skill_name" "$resolved_path"
        ;;
      *)
        fail "managed skill is not discoverable for $agent_id:$skill_name"
        ;;
    esac
  done
done

workspace_count="$(printf '%s\n' "${workspaces[@]}" | sort -u | wc -l | tr -d ' ')"
if (( workspace_count < 2 )); then
  printf 'openclaw agent-core smoke: multi-workspace check skipped; all agents use %s\n' "${workspaces[0]}"
fi
printf 'openclaw agent-core smoke passed for %d agent(s)\n' "${#agent_ids[@]}"
