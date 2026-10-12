#!/usr/bin/env bash

set -euo pipefail

agent_core_bin="${AGENT_CORE_BIN:-agent-core}"
if ! plan_json="$("$agent_core_bin" skill-plan --target openclaw)"; then
  printf '%s\n' 'could not read the OpenClaw skill installation plan' >&2
  exit 1
fi
jq -er '
  select(.target == "openclaw")
  | [.sources[].skills | keys[]]
  | select(length > 0 and length == (unique | length))
  | sort[]
' <<<"$plan_json"
