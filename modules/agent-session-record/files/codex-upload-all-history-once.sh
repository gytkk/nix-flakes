#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.config/agent-session-record/config.sh"
if [ -r "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi

: "${AGENT_SESSION_RECORD_STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-record}"
: "${AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR:=${HOME}/.codex/sessions}"
: "${AGENT_SESSION_RECORD_COREUTILS_BIN:=/usr/bin}"
: "${AGENT_SESSION_RECORD_FINDUTILS_BIN:=/usr/bin}"
: "${AGENT_SESSION_RECORD_JQ_BIN:=/usr/bin}"
: "${AGENT_SESSION_RECORD_SSH_BIN:=/usr/bin}"

COREUTILS_BIN="$AGENT_SESSION_RECORD_COREUTILS_BIN"
FINDUTILS_BIN="$AGENT_SESSION_RECORD_FINDUTILS_BIN"
JQ_BIN="$AGENT_SESSION_RECORD_JQ_BIN"
SSH_BIN="$AGENT_SESSION_RECORD_SSH_BIN"

DATE="${COREUTILS_BIN}/date"
HEAD="${COREUTILS_BIN}/head"
MKDIR="${COREUTILS_BIN}/mkdir"
MKTEMP="${COREUTILS_BIN}/mktemp"
PRINTF="${COREUTILS_BIN}/printf"
RM="${COREUTILS_BIN}/rm"
SORT="${COREUTILS_BIN}/sort"
TR="${COREUTILS_BIN}/tr"
WC="${COREUTILS_BIN}/wc"
FIND="${FINDUTILS_BIN}/find"
JQ="${JQ_BIN}/jq"
SSH="${SSH_BIN}/ssh"

WORKER_CMD="${HOME}/.local/bin/agent-session-upload-worker"
SESSION_STATE_DIR="${AGENT_SESSION_RECORD_STATE_DIR}/sessions"
TMP_DIR="${AGENT_SESSION_RECORD_STATE_DIR}/tmp"

if [ ! -r "$WORKER_CMD" ]; then
  "$PRINTF" 'worker command missing: %s\n' "$WORKER_CMD" >&2
  exit 1
fi

if [ ! -d "$AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR" ]; then
  "$PRINTF" 'codex sessions directory missing: %s\n' "$AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR" >&2
  exit 1
fi

"$MKDIR" -p "$SESSION_STATE_DIR" "$TMP_DIR"

remote_prefix="${AGENT_SESSION_RECORD_REMOTE_USER}@${AGENT_SESSION_RECORD_REMOTE_HOST}"
remote_codex_dir="${AGENT_SESSION_RECORD_REMOTE_BASE_PATH}/codex"

payload_file=""
rollouts_file=""

cleanup() {
  if [ -n "$payload_file" ] && [ -f "$payload_file" ]; then
    "$RM" -f "$payload_file"
  fi
  if [ -n "$rollouts_file" ] && [ -f "$rollouts_file" ]; then
    "$RM" -f "$rollouts_file"
  fi
}

trap cleanup EXIT

rollouts_file="$("$MKTEMP" "${TMP_DIR}/codex-upload-rollouts.XXXXXX")"
"$FIND" "$AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR" -type f -name 'rollout-*.jsonl' -print | "$SORT" >"$rollouts_file"

total_rollouts="$("$WC" -l <"$rollouts_file" | "$TR" -d ' ')"
if [ "${total_rollouts:-0}" -eq 0 ]; then
  "$PRINTF" 'No Codex rollout files found under %s\n' "$AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR"
  exit 0
fi

uploaded_count=0
failed_count=0

while IFS= read -r transcript_path <&3; do
  [ -n "$transcript_path" ] || continue

  session_id="$("$HEAD" -n 1 "$transcript_path" | "$JQ" -r '
    if .type == "session_meta" then
      .payload.id // empty
    else
      empty
    end
  ')"
  cwd="$("$HEAD" -n 1 "$transcript_path" | "$JQ" -r '
    if .type == "session_meta" then
      .payload.cwd // empty
    else
      empty
    end
  ')"

  if [ -z "$session_id" ]; then
    "$PRINTF" 'skip (missing session id): %s\n' "$transcript_path" >&2
    failed_count=$((failed_count + 1))
    continue
  fi

  "$RM" -f "${SESSION_STATE_DIR}/codex-${session_id}.json"

  payload_file="$("$MKTEMP" "${TMP_DIR}/codex-upload-payload.XXXXXX")"
  "$JQ" -n \
    --arg session_id "$session_id" \
    --arg transcript_path "$transcript_path" \
    --arg cwd "$cwd" \
    --arg hook_event_name "ManualReplay" \
    --arg turn_id "" \
    --arg last_assistant_message "" \
    '{
      session_id: $session_id,
      transcript_path: $transcript_path,
      cwd: $cwd,
      hook_event_name: $hook_event_name,
      turn_id: $turn_id,
      stop_hook_active: false,
      last_assistant_message: $last_assistant_message
    }' >"$payload_file"

  if "${BASH:-bash}" "$WORKER_CMD" --mode payload --agent codex --payload-file "$payload_file" </dev/null; then
    if [ -f "${SESSION_STATE_DIR}/codex-${session_id}.json" ]; then
      "$PRINTF" 'uploaded: %s\n' "$session_id"
      uploaded_count=$((uploaded_count + 1))
    else
      "$PRINTF" 'upload not confirmed (queued or failed): %s\n' "$session_id" >&2
      failed_count=$((failed_count + 1))
    fi
  else
    "$PRINTF" 'worker failed: %s\n' "$session_id" >&2
    failed_count=$((failed_count + 1))
  fi

  "$RM" -f "$payload_file"
  payload_file=""
done 3<"$rollouts_file"

remote_count="$("$SSH" -o BatchMode=yes -o ConnectTimeout=10 "$remote_prefix" \
  "find '$remote_codex_dir' -type f -name '*.jsonl' 2>/dev/null | wc -l" </dev/null || true)"

"$PRINTF" '\nprocessed: %s\nuploaded: %s\nfailed: %s\n' \
  "$total_rollouts" "$uploaded_count" "$failed_count"

if [ -n "$remote_count" ]; then
  "$PRINTF" 'remote jsonl count: %s\n' "$remote_count"
else
  "$PRINTF" 'remote jsonl count: unavailable\n'
fi

"$PRINTF" 'completed at: %s\n' "$("$DATE" -Is 2>/dev/null || date)"
