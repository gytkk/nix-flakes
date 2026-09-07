#!/usr/bin/env bash

set -euo pipefail

test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

fail() {
  printf 'runtime smoke regression test failed: %s\n' "$1" >&2
  exit 1
}

make_runtime() {
  local runtime_dir="$1"
  local skill_source="$runtime_dir/source-SKILL.md"

  mkdir -p "$runtime_dir/skills/example"
  printf '%s\n' '---' 'name: example' '---' >"$skill_source"
  ln "$skill_source" "$runtime_dir/skills/example/SKILL.md"
  printf '%s\n' 'rendered instructions' >"$runtime_dir/AGENTS.core.md"
}

make_openclaw() {
  local bin_dir="$1"
  local mode="$2"

  mkdir -p "$bin_dir"
  cat >"$bin_dir/openclaw" <<EOF
#!$BASH
set -euo pipefail
case "\$1 \$2 \${3:-}" in
  "plugins inspect agent-core-context")
    if [[ "$mode" == "inspect-failure" ]]; then
      printf '%s\\n' 'plugin inspection transport failed' >&2
      exit 17
    fi
    printf '%s\\n' '{"plugin":{"enabled":true,"status":"loaded"},"typedHooks":[{"name":"before_prompt_build"}],"diagnostics":[]}'
    ;;
  "plugins doctor ")
    printf '%s\\n' 'Plugin discovery, module loading, compatibility, and configuration checks passed.'
    ;;
  "agents list --json")
    printf '%s\\n' '[{"id":"main"}]'
    ;;
  "skills list --agent")
    printf '%s\\n' '{"workspaceDir":"/workspace/main","skills":[{"name":"example","source":"openclaw-extra"}]}'
    ;;
  *)
    printf 'unexpected OpenClaw invocation: %s %s %s\\n' "\$1" "\$2" "\${3:-}" >&2
    exit 64
    ;;
esac
EOF
  chmod +x "$bin_dir/openclaw"
}

assert_smoke_failure() {
  local description="$1"
  local expected_message="$2"
  shift 2
  local output status

  set +e
  output="$("$@" 2>&1)"
  status=$?
  set -e

  (( status != 0 )) || fail "$description unexpectedly passed"
  [[ "$output" == *"$expected_message"* ]] ||
    fail "$description did not report '$expected_message': $output"
}

runtime_dir="$test_dir/runtime"
make_runtime "$runtime_dir"

hardlink_bin_dir="$test_dir/hardlink-bin"
make_openclaw "$hardlink_bin_dir" "success"
assert_smoke_failure \
  "hardlinked managed skill" \
  "must not be hardlinked" \
  env \
  OPENCLAW_BIN="$hardlink_bin_dir/openclaw" \
  AGENT_CORE_OPENCLAW_INSTRUCTIONS="$runtime_dir/AGENTS.core.md" \
  AGENT_CORE_OPENCLAW_SKILLS="$runtime_dir/skills" \
  bash \
  "$(dirname "$0")/runtime-smoke.sh"

inspect_failure_bin_dir="$test_dir/inspect-failure-bin"
make_openclaw "$inspect_failure_bin_dir" "inspect-failure"
assert_smoke_failure \
  "plugin inspection failure" \
  "could not inspect agent-core-context" \
  env \
  OPENCLAW_BIN="$inspect_failure_bin_dir/openclaw" \
  AGENT_CORE_OPENCLAW_INSTRUCTIONS="$runtime_dir/AGENTS.core.md" \
  AGENT_CORE_OPENCLAW_SKILLS="$runtime_dir/skills" \
  bash \
  "$(dirname "$0")/runtime-smoke.sh"

printf '%s\n' 'runtime smoke regression tests passed'
