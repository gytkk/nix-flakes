#!/usr/bin/env bash

set -euo pipefail

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
smoke="$(dirname "$0")/runtime-smoke.sh"
deployed="$(dirname "$0")/deployed-skills.test.sh"
export FIXTURE_ROOT="$test_dir"
export OPENCLAW_BIN="$test_dir/bin/openclaw"
export AGENT_CORE_BIN="$test_dir/bin/agent-core"
export AGENT_CORE_OPENCLAW_INSTRUCTIONS="$test_dir/AGENTS.core.md"
export AGENT_CORE_OPENCLAW_SKILLS="$test_dir/skills"
export AGENT_CORE_OPENCLAW_EXTENSIONS="$test_dir/extensions"
export AGENT_CORE_OPENCLAW_DROP_IN="$test_dir/20-nix-runtime.conf"
export FIXTURE_MODE=success

fail() { printf 'runtime smoke regression test failed: %s\n' "$1" >&2; exit 1; }

mkdir -p "$test_dir/bin" "$test_dir/skills/example" "$test_dir/skills/find-skills" "$test_dir/workspace/skills/example"
printf '%s\n' 'rendered instructions' >"$AGENT_CORE_OPENCLAW_INSTRUCTIONS"
printf '%s\n' 'example' >"$test_dir/skills/example/SKILL.md"
printf '%s\n' 'find-skills' >"$test_dir/skills/find-skills/SKILL.md"
printf '%s\n' 'workspace override' >"$test_dir/workspace/skills/example/SKILL.md"
printf 'UnsetEnvironment=CLAWDBOT_CONFIG_PATH CLAWDBOT_STATE_DIR\nEnvironment="LD_LIBRARY_PATH=/nix/store/example/lib"\nEnvironment="AGENT_CORE_OPENCLAW_INSTRUCTIONS=%s"\n' \
  "$AGENT_CORE_OPENCLAW_INSTRUCTIONS" >"$AGENT_CORE_OPENCLAW_DROP_IN"
for extension in agent-core-context agent-session-record; do
  mkdir -p "$test_dir/extensions/$extension"
  printf '{}\n' >"$test_dir/extensions/$extension/openclaw.plugin.json"
done

cat >"$AGENT_CORE_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == 'skill-plan --target openclaw' ]] || exit 64
printf '%s\n' '{"target":"openclaw","sources":[{"skills":{"example":"example","find-skills":"find-skills"}}]}'
EOF
cat >"$OPENCLAW_BIN" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$1 $2 ${3:-}" in
  'plugins inspect agent-core-context')
    if [[ "$FIXTURE_MODE" == inspect-failure ]]; then
      printf '%s\n' 'plugin inspection transport failed' >&2
      exit 17
    fi
    printf '%s\n' '{"plugin":{"enabled":true,"status":"loaded"},"typedHooks":[{"name":"before_prompt_build"}],"diagnostics":[]}'
    ;;
  'plugins inspect agent-session-record')
    if [[ "$FIXTURE_MODE" == recorder-failure ]]; then
      printf '%s\n' '{"plugin":{"enabled":true,"status":"error"},"typedHooks":[],"diagnostics":["failed"]}'
    else
      printf '%s\n' '{"plugin":{"enabled":true,"status":"loaded"},"typedHooks":[{"name":"session_end"}],"diagnostics":[]}'
    fi
    ;;
  'plugins doctor ')
    printf '%s\n' 'Plugin discovery, module loading, compatibility, and configuration checks passed.'
    ;;
  'agents list --json') printf '%s\n' '[{"id":"main"}]' ;;
  'skills list --agent')
    source=openclaw-extra
    [[ "$FIXTURE_MODE" != workspace ]] || source=openclaw-workspace
    jq -n --arg dir "$FIXTURE_ROOT/workspace" --arg source "$source" \
      --arg mode "$FIXTURE_MODE" \
      '{workspaceDir:$dir,skills:[{name:"example",source:$source},{name:"find-skills",source:"openclaw-extra"},{name:"personal",source:"openclaw-workspace"}]}
       | if $mode == "missing-discovery" then .skills |= map(select(.name != "find-skills"))
         elif $mode == "duplicate-discovery" then .skills += [{name:"example",source:"openclaw-extra"}] else . end'
    ;;
  'skills info --agent')
    name="$5"
    source=openclaw-extra
    path="$AGENT_CORE_OPENCLAW_SKILLS/$name/SKILL.md"
    if [[ "$FIXTURE_MODE" == workspace && "$name" == example ]]; then
      source=openclaw-workspace
      path="$FIXTURE_ROOT/workspace/skills/example/SKILL.md"
    fi
    [[ "$FIXTURE_MODE" != wrong-path ]] || path="$FIXTURE_ROOT/wrong/SKILL.md"
    jq -n --arg source "$source" --arg path "$path" --arg name "$name" \
      '{name:$name,description:"Fixture skill",source:$source,filePath:$path}'
    ;;
  *) printf 'unexpected OpenClaw invocation: %s\n' "$*" >&2; exit 64 ;;
esac
EOF
chmod +x "$OPENCLAW_BIN" "$AGENT_CORE_BIN"

assert_failure() {
  local expected="$1"
  shift
  local output status
  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e
  (( status != 0 )) || fail "expected failure: $expected"
  [[ "$output" == *"$expected"* ]] || fail "missing '$expected': $output"
}

bash "$smoke"
bash "$deployed"
mkdir -p "$test_dir/personal-source" "$test_dir/skills/personal-hardlink"
printf '%s\n' 'personal skill' >"$test_dir/personal-source/SKILL.md"
ln -s "$test_dir/personal-source" "$test_dir/skills/personal-symlink"
ln "$test_dir/personal-source/SKILL.md" "$test_dir/skills/personal-hardlink/SKILL.md"
bash "$smoke"
bash "$deployed"
export FIXTURE_MODE=workspace
bash "$smoke"
export FIXTURE_MODE=wrong-path
assert_failure 'wrong managed skill path' bash "$smoke"
export FIXTURE_MODE=missing-discovery
assert_failure 'expected one discovered entry for main:find-skills' bash "$smoke"
export FIXTURE_MODE=duplicate-discovery
assert_failure 'expected one discovered entry for main:example' bash "$smoke"
export FIXTURE_MODE=recorder-failure
assert_failure 'agent-session-record is not loaded cleanly' bash "$smoke"
export FIXTURE_MODE=inspect-failure
assert_failure 'could not inspect agent-core-context' bash "$smoke"
export FIXTURE_MODE=success
mv "$test_dir/skills/find-skills/SKILL.md" "$test_dir/find-skills.backup"
assert_failure 'managed skill is not a regular file' bash "$smoke"
assert_failure 'declared skill is missing: find-skills' bash "$deployed"
mv "$test_dir/find-skills.backup" "$test_dir/skills/find-skills/SKILL.md"
ln "$test_dir/skills/example/SKILL.md" "$test_dir/hardlink"
assert_failure 'must not be hardlinked' bash "$smoke"
assert_failure 'must not be hardlinked' bash "$deployed"
rm "$test_dir/hardlink"
mv "$AGENT_CORE_OPENCLAW_DROP_IN" "$test_dir/drop-in.backup"
assert_failure 'service environment drop-in is missing' bash "$smoke"
printf '%s\n' 'runtime smoke regression tests passed'
