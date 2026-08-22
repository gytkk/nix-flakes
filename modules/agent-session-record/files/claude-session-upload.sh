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
DEBUG_LOG="${AGENT_SESSION_RECORD_STATE_DIR}/debug.log"
MKTEMP="${COREUTILS_BIN}/mktemp"
MKDIR="${COREUTILS_BIN}/mkdir"
RM="${COREUTILS_BIN}/rm"
DATE="${COREUTILS_BIN}/date"
NOHUP="${COREUTILS_BIN}/nohup"

warn() {
  "$MKDIR" -p "${WARN_LOG%/*}" 2>/dev/null || true
  printf '%s claude-session-upload: %s\n' \
    "$("$DATE" -Is 2>/dev/null || date)" "$*" >>"$WARN_LOG" 2>/dev/null || true
}

worker_cmd="${HOME}/.local/bin/agent-session-upload-worker"
if [ ! -r "$worker_cmd" ]; then
  warn "worker command missing"
  exit 0
fi

payload_file=""
if ! payload_file="$("$MKTEMP" "${TMPDIR:-/tmp}/claude-session-upload.XXXXXX")"; then
  warn "mktemp failed"
  exit 0
fi

if ! cat >"$payload_file"; then
  warn "failed to persist SessionEnd payload"
  "$RM" -f "$payload_file" 2>/dev/null || true
  exit 0
fi

stderr_sink="/dev/null"
if "$MKDIR" -p "${DEBUG_LOG%/*}" 2>/dev/null && : >>"$DEBUG_LOG" 2>/dev/null; then
  stderr_sink="$DEBUG_LOG"
fi

"$NOHUP" "${BASH:-bash}" "$worker_cmd" \
  --mode payload \
  --agent claude \
  --payload-file "$payload_file" \
  >/dev/null 2>>"$stderr_sink" &

disown || true
exit 0
