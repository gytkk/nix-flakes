#!/usr/bin/env bash
set -u

CONFIG_FILE="${HOME}/.config/agent-session-record/config.sh"
if [ -r "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi

: "${AGENT_SESSION_RECORD_STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-record}"
: "${AGENT_SESSION_RECORD_COREUTILS_BIN:=/usr/bin}"

COREUTILS_BIN="$AGENT_SESSION_RECORD_COREUTILS_BIN"
WARN_LOG="${AGENT_SESSION_RECORD_STATE_DIR}/warnings.log"
MKTEMP="${COREUTILS_BIN}/mktemp"
MKDIR="${COREUTILS_BIN}/mkdir"
RM="${COREUTILS_BIN}/rm"
DATE="${COREUTILS_BIN}/date"
NOHUP="${COREUTILS_BIN}/nohup"

warn() {
  "$MKDIR" -p "${WARN_LOG%/*}" 2>/dev/null || true
  printf '%s codex-stop-upload: %s\n' \
    "$("$DATE" -Is 2>/dev/null || date)" "$*" >>"$WARN_LOG" 2>/dev/null || true
}

continue_json() {
  printf '{"continue":true}\n'
}

worker_cmd="${HOME}/.local/bin/agent-session-upload-worker"
if [ ! -r "$worker_cmd" ]; then
  warn "worker command missing"
  continue_json
  exit 0
fi

payload_file=""
if ! payload_file="$("$MKTEMP" "${TMPDIR:-/tmp}/codex-stop-upload.XXXXXX")"; then
  warn "mktemp failed"
  continue_json
  exit 0
fi

if ! cat >"$payload_file"; then
  warn "failed to persist Stop payload"
  "$RM" -f "$payload_file" 2>/dev/null || true
  continue_json
  exit 0
fi

"$NOHUP" "${BASH:-bash}" "$worker_cmd" \
  --mode payload \
  --agent codex \
  --payload-file "$payload_file" \
  >/dev/null 2>&1 &

disown || true
continue_json
exit 0
