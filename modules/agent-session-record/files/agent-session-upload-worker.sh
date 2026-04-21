#!/usr/bin/env bash
set -uo pipefail

CONFIG_FILE="${HOME}/.config/agent-session-record/config.sh"
if [ -r "$CONFIG_FILE" ]; then
  # shellcheck disable=SC1090
  . "$CONFIG_FILE"
fi

: "${AGENT_SESSION_RECORD_REMOTE_HOST:=pylv-onyx}"
: "${AGENT_SESSION_RECORD_REMOTE_USER:=gytkk}"
: "${AGENT_SESSION_RECORD_REMOTE_BASE_PATH:=/home/gytkk/agent-sessions}"
: "${AGENT_SESSION_RECORD_LOCAL_SHORT_CIRCUIT_HOST:=pylv-onyx}"
: "${AGENT_SESSION_RECORD_STATE_DIR:=${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-record}"
: "${AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR:=${HOME}/.codex/sessions}"
: "${AGENT_SESSION_RECORD_COREUTILS_BIN:=/usr/bin}"
: "${AGENT_SESSION_RECORD_FINDUTILS_BIN:=/usr/bin}"
: "${AGENT_SESSION_RECORD_JQ_BIN:=/usr/bin}"
: "${AGENT_SESSION_RECORD_SSH_BIN:=/usr/bin}"
: "${AGENT_SESSION_RECORD_RSYNC_BIN:=/usr/bin}"

COREUTILS_BIN="$AGENT_SESSION_RECORD_COREUTILS_BIN"
FINDUTILS_BIN="$AGENT_SESSION_RECORD_FINDUTILS_BIN"
JQ_BIN="$AGENT_SESSION_RECORD_JQ_BIN"
SSH_BIN="$AGENT_SESSION_RECORD_SSH_BIN"
RSYNC_BIN="$AGENT_SESSION_RECORD_RSYNC_BIN"

MKDIR="${COREUTILS_BIN}/mkdir"
RM="${COREUTILS_BIN}/rm"
INSTALL="${COREUTILS_BIN}/install"
MV="${COREUTILS_BIN}/mv"
HEAD="${COREUTILS_BIN}/head"
DATE="${COREUTILS_BIN}/date"
CUT="${COREUTILS_BIN}/cut"
SHA256SUM="${COREUTILS_BIN}/sha256sum"
PRINTF="${COREUTILS_BIN}/printf"
MKTEMP="${COREUTILS_BIN}/mktemp"
SORT="${COREUTILS_BIN}/sort"
SLEEP="${COREUTILS_BIN}/sleep"
TR="${COREUTILS_BIN}/tr"
FIND="${FINDUTILS_BIN}/find"
JQ="${JQ_BIN}/jq"
SSH="${SSH_BIN}/ssh"
RSYNC="${RSYNC_BIN}/rsync"

QUEUE_DIR="${AGENT_SESSION_RECORD_STATE_DIR}/queue"
LOCK_DIR="${AGENT_SESSION_RECORD_STATE_DIR}/locks"
SESSION_STATE_DIR="${AGENT_SESSION_RECORD_STATE_DIR}/sessions"
TMP_DIR="${AGENT_SESSION_RECORD_STATE_DIR}/tmp"
WARN_LOG="${AGENT_SESSION_RECORD_STATE_DIR}/warnings.log"

MODE="payload"
AGENT=""
PAYLOAD_FILE=""

warn() {
  local timestamp
  timestamp="$("$DATE" -Is 2>/dev/null || date)"
  "$MKDIR" -p "${WARN_LOG%/*}" 2>/dev/null || true
  "$PRINTF" '%s agent-session-upload-worker: %s\n' \
    "$timestamp" "$*" >>"$WARN_LOG" 2>/dev/null || true
  "$PRINTF" '%s agent-session-upload-worker: %s\n' \
    "$timestamp" "$*" >&2 2>/dev/null || true
}

ensure_dirs() {
  "$MKDIR" -p "$QUEUE_DIR" "$LOCK_DIR" "$SESSION_STATE_DIR" "$TMP_DIR" 2>/dev/null || true
}

usage() {
  warn "invalid arguments"
  exit 1
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode)
      MODE="${2:-}"
      shift 2
      ;;
    --agent)
      AGENT="${2:-}"
      shift 2
      ;;
    --payload-file)
      PAYLOAD_FILE="${2:-}"
      shift 2
      ;;
    *)
      usage
      ;;
  esac
done

if [ -z "$AGENT" ]; then
  usage
fi

if [ "$MODE" = "payload" ] && [ -z "$PAYLOAD_FILE" ]; then
  usage
fi

ensure_dirs

cleanup() {
  if [ -n "${PAYLOAD_FILE:-}" ] && [ -f "$PAYLOAD_FILE" ]; then
    "$RM" -f "$PAYLOAD_FILE" 2>/dev/null || true
  fi
}

trap cleanup EXIT

current_host="$(hostname -s 2>/dev/null || hostname || echo unknown)"

file_mtime_ns() {
  local path="$1"
  local raw=""
  local seconds=""
  local fraction=""
  raw="$("$FIND" "$path" -maxdepth 0 -type f -printf '%T@\n' 2>/dev/null | "$HEAD" -n 1)"
  if [ -z "$raw" ]; then
    return 1
  fi

  seconds="${raw%%.*}"
  fraction="${raw#*.}"

  if [ "$fraction" = "$raw" ]; then
    fraction="0"
  fi

  fraction="$("$PRINTF" '%-9.9s' "$fraction" | "$TR" ' ' '0')"
  "$PRINTF" '%s%s' "$seconds" "$fraction"
}

file_year_month() {
  local mtime_ns="$1"
  local seconds="${mtime_ns%?????????}"

  if [ -z "$seconds" ]; then
    seconds=0
  fi

  "$DATE" -u -d "@${seconds}" '+%Y-%m'
}

file_fingerprint() {
  local path="$1"
  "$SHA256SUM" "$path" 2>/dev/null | "$CUT" -d ' ' -f 1
}

read_json_field() {
  local file="$1"
  local expr="$2"
  "$JQ" -r "$expr" "$file" 2>/dev/null
}

read_first_line() {
  local file="$1"
  "$HEAD" -n 1 "$file" 2>/dev/null || true
}

codex_rollout_session_id() {
  local transcript="$1"
  read_first_line "$transcript" | "$JQ" -r '
    if .type == "session_meta" then
      .payload.id // empty
    else
      empty
    end
  ' 2>/dev/null
}

codex_rollout_cwd() {
  local transcript="$1"
  read_first_line "$transcript" | "$JQ" -r '
    if .type == "session_meta" then
      .payload.cwd // empty
    else
      empty
    end
  ' 2>/dev/null
}

session_state_file() {
  local agent="$1"
  local session_id="$2"
  "$PRINTF" '%s/%s-%s.json' "$SESSION_STATE_DIR" "$agent" "$session_id"
}

lock_dir_path() {
  local agent="$1"
  local session_id="$2"
  "$PRINTF" '%s/%s-%s.lock' "$LOCK_DIR" "$agent" "$session_id"
}

acquire_session_lock() {
  local lock_dir="$1"
  local waited_seconds=0
  local max_wait_seconds=15
  local stale_after_seconds=300
  local now_epoch=""
  local created_epoch=""
  local owner_pid=""

  while ! "$MKDIR" "$lock_dir" 2>/dev/null; do
    owner_pid="$("$HEAD" -n 1 "${lock_dir}/pid" 2>/dev/null || true)"
    created_epoch="$("$HEAD" -n 1 "${lock_dir}/created_epoch" 2>/dev/null || true)"
    now_epoch="$("$DATE" +%s 2>/dev/null || date +%s)"

    if [ -n "$owner_pid" ] && ! kill -0 "$owner_pid" 2>/dev/null; then
      "$RM" -rf "$lock_dir" 2>/dev/null || true
      continue
    fi

    if [ -n "$created_epoch" ] && [ "$((now_epoch - created_epoch))" -gt "$stale_after_seconds" ] 2>/dev/null; then
      "$RM" -rf "$lock_dir" 2>/dev/null || true
      continue
    fi

    if [ "$waited_seconds" -ge "$max_wait_seconds" ]; then
      return 1
    fi

    "$SLEEP" 1 2>/dev/null || sleep 1
    waited_seconds=$((waited_seconds + 1))
  done

  "$PRINTF" '%s\n' "$$" >"${lock_dir}/pid" 2>/dev/null || true
  "$DATE" +%s >"${lock_dir}/created_epoch" 2>/dev/null || true
}

release_session_lock() {
  local lock_dir="$1"
  "$RM" -rf "$lock_dir" 2>/dev/null || true
}

load_session_state_field() {
  local agent="$1"
  local session_id="$2"
  local expr="$3"
  local file
  file="$(session_state_file "$agent" "$session_id")"

  if [ ! -f "$file" ]; then
    return 1
  fi

  read_json_field "$file" "$expr"
}

write_session_state() {
  local agent="$1"
  local session_id="$2"
  local mtime_ns="$3"
  local fingerprint="$4"
  local uploaded_at="$5"
  local target_dir="$6"
  local state_file
  local tmp_file

  state_file="$(session_state_file "$agent" "$session_id")"
  tmp_file="$("$MKTEMP" "${TMP_DIR}/session-state.XXXXXX")" || return 1

  if ! "$JQ" -n \
    --arg session_id "$session_id" \
    --arg snapshot_mtime_ns "$mtime_ns" \
    --arg snapshot_fingerprint "$fingerprint" \
    --arg uploaded_at "$uploaded_at" \
    --arg target_dir "$target_dir" \
    '{
      session_id: $session_id,
      snapshot_mtime_ns: $snapshot_mtime_ns,
      snapshot_fingerprint: $snapshot_fingerprint,
      uploaded_at: $uploaded_at,
      target_dir: $target_dir
    }' >"$tmp_file"; then
    "$RM" -f "$tmp_file" 2>/dev/null || true
    return 1
  fi

  "$INSTALL" -m 0600 "$tmp_file" "$state_file"
  "$RM" -f "$tmp_file" 2>/dev/null || true
}

is_stale_snapshot() {
  local agent="$1"
  local session_id="$2"
  local mtime_ns="$3"
  local fingerprint="$4"
  local latest_mtime_ns=""
  local latest_fingerprint=""

  latest_mtime_ns="$(load_session_state_field "$agent" "$session_id" '.snapshot_mtime_ns // empty' || true)"
  latest_fingerprint="$(load_session_state_field "$agent" "$session_id" '.snapshot_fingerprint // empty' || true)"

  if [ -z "$latest_mtime_ns" ]; then
    return 1
  fi

  if [ "$fingerprint" = "$latest_fingerprint" ]; then
    return 0
  fi

  if [ "$mtime_ns" -lt "$latest_mtime_ns" ] 2>/dev/null; then
    return 0
  fi

  return 1
}

build_manifest() {
  local output="$1"
  local agent="$2"
  local session_id="$3"
  local hostname="$4"
  local cwd="$5"
  local hook_event_name="$6"
  local transcript_path="$7"
  local source="$8"
  local snapshot_mtime_ns="$9"
  local snapshot_fingerprint="${10}"
  local end_reason="${11}"
  local turn_id="${12}"
  local stop_hook_active="${13}"
  local last_assistant_message="${14}"

  "$JQ" -n \
    --arg agent "$agent" \
    --arg session_id "$session_id" \
    --arg hostname "$hostname" \
    --arg cwd "$cwd" \
    --arg hook_event_name "$hook_event_name" \
    --arg transcript_path "$transcript_path" \
    --arg source "$source" \
    --arg snapshot_mtime_ns "$snapshot_mtime_ns" \
    --arg snapshot_fingerprint "$snapshot_fingerprint" \
    --arg end_reason "$end_reason" \
    --arg turn_id "$turn_id" \
    --argjson stop_hook_active "$stop_hook_active" \
    --arg last_assistant_message "$last_assistant_message" \
    '
      {
        agent: $agent,
        session_id: $session_id,
        hostname: $hostname,
        cwd: $cwd,
        hook_event_name: $hook_event_name,
        transcript_path: $transcript_path,
        source: $source,
        snapshot_mtime_ns: $snapshot_mtime_ns,
        snapshot_fingerprint: $snapshot_fingerprint
      }
      + if $agent == "claude" then
          { end_reason: $end_reason }
        else
          {
            turn_id: (if $turn_id == "" then null else $turn_id end),
            stop_hook_active: $stop_hook_active,
            last_assistant_message: (
              if $last_assistant_message == "" then
                null
              else
                $last_assistant_message
              end
            )
          }
        end
    ' >"$output"
}

queue_item_dir() {
  local agent="$1"
  local session_id="$2"
  local fingerprint="$3"
  "$PRINTF" '%s/%s-%s-%s' "$QUEUE_DIR" "$agent" "$session_id" "$fingerprint"
}

queue_snapshot() {
  local manifest_file="$1"
  local transcript_path="$2"
  local agent="$3"
  local session_id="$4"
  local fingerprint="$5"
  local item_dir
  local transcript_copy
  local manifest_copy

  item_dir="$(queue_item_dir "$agent" "$session_id" "$fingerprint")"
  transcript_copy="${item_dir}/transcript.jsonl"
  manifest_copy="${item_dir}/manifest.json"

  if [ -d "$item_dir" ]; then
    return 0
  fi

  if ! "$MKDIR" -p "$item_dir"; then
    warn "failed to create queue directory for ${agent}/${session_id}"
    return 1
  fi

  if ! "$INSTALL" -m 0600 "$manifest_file" "$manifest_copy"; then
    warn "failed to queue manifest for ${agent}/${session_id}"
    "$RM" -rf "$item_dir" 2>/dev/null || true
    return 1
  fi

  if ! "$INSTALL" -m 0600 "$transcript_path" "$transcript_copy"; then
    warn "failed to queue transcript for ${agent}/${session_id}"
    "$RM" -rf "$item_dir" 2>/dev/null || true
    return 1
  fi

  return 0
}

render_meta_file() {
  local manifest_file="$1"
  local output="$2"
  local uploaded_at="$3"

  "$JQ" --arg uploaded_at "$uploaded_at" '. + { uploaded_at: $uploaded_at }' \
    "$manifest_file" >"$output"
}

upload_local_files() {
  local transcript_path="$1"
  local meta_path="$2"
  local target_dir="$3"
  local session_id="$4"
  local fingerprint="$5"
  local transcript_tmp="${target_dir}/${session_id}.${fingerprint}.jsonl.tmp"
  local meta_tmp="${target_dir}/${session_id}.${fingerprint}.meta.json.tmp"
  local transcript_target="${target_dir}/${session_id}.jsonl"
  local meta_target="${target_dir}/${session_id}.meta.json"

  "$MKDIR" -p "$target_dir" || return 1
  "$INSTALL" -m 0600 "$transcript_path" "$transcript_tmp" || return 1
  "$INSTALL" -m 0600 "$meta_path" "$meta_tmp" || return 1
  "$MV" "$transcript_tmp" "$transcript_target" || return 1
  "$MV" "$meta_tmp" "$meta_target" || return 1
}

upload_remote_files() {
  local transcript_path="$1"
  local meta_path="$2"
  local target_dir="$3"
  local session_id="$4"
  local fingerprint="$5"
  local remote_prefix="${AGENT_SESSION_RECORD_REMOTE_USER}@${AGENT_SESSION_RECORD_REMOTE_HOST}"
  local transcript_tmp="${target_dir}/${session_id}.${fingerprint}.jsonl.tmp"
  local meta_tmp="${target_dir}/${session_id}.${fingerprint}.meta.json.tmp"
  local transcript_target="${target_dir}/${session_id}.jsonl"
  local meta_target="${target_dir}/${session_id}.meta.json"

  "$SSH" -o BatchMode=yes -o ConnectTimeout=10 "$remote_prefix" \
    "mkdir -p '$target_dir'" || return 1
  "$RSYNC" -az "$transcript_path" "${remote_prefix}:${transcript_tmp}" || return 1
  "$RSYNC" -az "$meta_path" "${remote_prefix}:${meta_tmp}" || return 1
  "$SSH" -o BatchMode=yes -o ConnectTimeout=10 "$remote_prefix" \
    "mv '$transcript_tmp' '$transcript_target' && mv '$meta_tmp' '$meta_target'" || return 1
}

upload_snapshot() {
  local manifest_file="$1"
  local transcript_path="$2"
  local agent="$3"
  local session_id="$4"
  local hostname="$5"
  local mtime_ns="$6"
  local fingerprint="$7"
  local year_month
  local target_dir
  local uploaded_at
  local meta_file

  year_month="$(file_year_month "$mtime_ns")"
  target_dir="${AGENT_SESSION_RECORD_REMOTE_BASE_PATH}/${agent}/${hostname}/${year_month}"
  uploaded_at="$("$DATE" -u -Is)"
  meta_file="$("$MKTEMP" "${TMP_DIR}/meta.XXXXXX")" || return 1

  if ! render_meta_file "$manifest_file" "$meta_file" "$uploaded_at"; then
    "$RM" -f "$meta_file" 2>/dev/null || true
    return 1
  fi

  if [ "$current_host" = "$AGENT_SESSION_RECORD_LOCAL_SHORT_CIRCUIT_HOST" ]; then
    if ! upload_local_files "$transcript_path" "$meta_file" "$target_dir" "$session_id" "$fingerprint"; then
      "$RM" -f "$meta_file" 2>/dev/null || true
      return 1
    fi
  else
    if ! upload_remote_files "$transcript_path" "$meta_file" "$target_dir" "$session_id" "$fingerprint"; then
      "$RM" -f "$meta_file" 2>/dev/null || true
      return 1
    fi
  fi

  write_session_state "$agent" "$session_id" "$mtime_ns" "$fingerprint" "$uploaded_at" "$target_dir" || true
  "$RM" -f "$meta_file" 2>/dev/null || true
}

process_manifest_with_lock() {
  local manifest_file="$1"
  local transcript_path="$2"
  local cleanup_queue_dir="${3:-}"
  local agent
  local session_id
  local mtime_ns
  local fingerprint
  local lock_dir

  agent="$(read_json_field "$manifest_file" '.agent // empty')"
  session_id="$(read_json_field "$manifest_file" '.session_id // empty')"
  mtime_ns="$(read_json_field "$manifest_file" '.snapshot_mtime_ns // empty')"
  fingerprint="$(read_json_field "$manifest_file" '.snapshot_fingerprint // empty')"

  if [ -z "$agent" ] || [ -z "$session_id" ] || [ -z "$mtime_ns" ] || [ -z "$fingerprint" ]; then
    warn "manifest missing required fields"
    return 1
  fi

  lock_dir="$(lock_dir_path "$agent" "$session_id")"

  (
    if ! acquire_session_lock "$lock_dir"; then
      exit 1
    fi
    trap 'release_session_lock "$lock_dir"' EXIT

    if is_stale_snapshot "$agent" "$session_id" "$mtime_ns" "$fingerprint"; then
      if [ -n "$cleanup_queue_dir" ]; then
        "$RM" -rf "$cleanup_queue_dir" 2>/dev/null || true
      fi
      exit 0
    fi

    if upload_snapshot \
      "$manifest_file" \
      "$transcript_path" \
      "$agent" \
      "$session_id" \
      "$(read_json_field "$manifest_file" '.hostname // "unknown"')" \
      "$mtime_ns" \
      "$fingerprint"; then
      if [ -n "$cleanup_queue_dir" ]; then
        "$RM" -rf "$cleanup_queue_dir" 2>/dev/null || true
      fi
      exit 0
    fi

    exit 1
  )
}

replay_queue() {
  [ -d "$QUEUE_DIR" ] || return 0

  "$FIND" "$QUEUE_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null | \
    while IFS= read -r -d '' item_dir; do
      local manifest_file="${item_dir}/manifest.json"
      local transcript_path="${item_dir}/transcript.jsonl"

      if [ ! -f "$manifest_file" ] || [ ! -f "$transcript_path" ]; then
        warn "queue item is incomplete: ${item_dir}"
        continue
      fi

      if ! process_manifest_with_lock "$manifest_file" "$transcript_path" "$item_dir"; then
        warn "queue replay failed for ${item_dir##*/}"
      fi
    done
}

build_claude_manifest_from_payload() {
  local payload_file="$1"
  local manifest_file="$2"
  local session_id
  local transcript_path
  local cwd
  local hook_event_name
  local end_reason
  local snapshot_mtime_ns
  local snapshot_fingerprint

  session_id="$(read_json_field "$payload_file" '.session_id // empty')"
  transcript_path="$(read_json_field "$payload_file" '.transcript_path // empty')"
  cwd="$(read_json_field "$payload_file" '.cwd // empty')"
  hook_event_name="$(read_json_field "$payload_file" '.hook_event_name // "SessionEnd"')"
  end_reason="$(read_json_field "$payload_file" '.reason // empty')"

  if [ -z "$session_id" ] || [ -z "$transcript_path" ]; then
    warn "Claude payload missing session_id or transcript_path"
    return 1
  fi

  if [ ! -s "$transcript_path" ]; then
    warn "Claude transcript missing or empty: ${transcript_path}"
    return 1
  fi

  snapshot_mtime_ns="$(file_mtime_ns "$transcript_path" || true)"
  snapshot_fingerprint="$(file_fingerprint "$transcript_path" || true)"

  if [ -z "$snapshot_mtime_ns" ] || [ -z "$snapshot_fingerprint" ]; then
    warn "failed to fingerprint Claude transcript: ${transcript_path}"
    return 1
  fi

  build_manifest \
    "$manifest_file" \
    "claude" \
    "$session_id" \
    "$current_host" \
    "$cwd" \
    "$hook_event_name" \
    "$transcript_path" \
    "session-end" \
    "$snapshot_mtime_ns" \
    "$snapshot_fingerprint" \
    "$end_reason" \
    "" \
    "false" \
    ""
}

find_latest_codex_rollout_for_session() {
  local session_id="$1"
  local newest_path=""
  local newest_mtime_ns="0"

  if [ ! -d "$AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR" ]; then
    return 1
  fi

  "$FIND" "$AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR" -type f \
    -name "rollout-*-${session_id}.jsonl" -print0 2>/dev/null | \
    while IFS= read -r -d '' transcript_path; do
      local mtime_ns
      mtime_ns="$(file_mtime_ns "$transcript_path" || true)"
      if [ -n "$mtime_ns" ] && [ "$mtime_ns" -gt "$newest_mtime_ns" ] 2>/dev/null; then
        newest_mtime_ns="$mtime_ns"
        newest_path="$transcript_path"
      fi
      "$PRINTF" '%s\t%s\n' "$mtime_ns" "$transcript_path"
    done | "$SORT" -nr 2>/dev/null | "$HEAD" -n 1 | "$CUT" -f 2-
}

build_codex_manifest_from_payload() {
  local payload_file="$1"
  local manifest_file="$2"
  local session_id
  local transcript_path
  local cwd
  local hook_event_name
  local turn_id
  local stop_hook_active
  local last_assistant_message
  local snapshot_mtime_ns
  local snapshot_fingerprint

  session_id="$(read_json_field "$payload_file" '.session_id // empty')"
  transcript_path="$(read_json_field "$payload_file" '.transcript_path // empty')"
  cwd="$(read_json_field "$payload_file" '.cwd // empty')"
  hook_event_name="$(read_json_field "$payload_file" '.hook_event_name // "Stop"')"
  turn_id="$(read_json_field "$payload_file" '.turn_id // empty')"
  stop_hook_active="$(read_json_field "$payload_file" '.stop_hook_active // false')"
  last_assistant_message="$(read_json_field "$payload_file" '.last_assistant_message // empty')"

  if [ -z "$session_id" ]; then
    warn "Codex payload missing session_id"
    return 1
  fi

  if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    transcript_path="$(find_latest_codex_rollout_for_session "$session_id" || true)"
  fi

  if [ -z "$transcript_path" ] || [ ! -s "$transcript_path" ]; then
    warn "Codex transcript missing or empty for session ${session_id}"
    return 1
  fi

  snapshot_mtime_ns="$(file_mtime_ns "$transcript_path" || true)"
  snapshot_fingerprint="$(file_fingerprint "$transcript_path" || true)"

  if [ -z "$snapshot_mtime_ns" ] || [ -z "$snapshot_fingerprint" ]; then
    warn "failed to fingerprint Codex transcript: ${transcript_path}"
    return 1
  fi

  build_manifest \
    "$manifest_file" \
    "codex" \
    "$session_id" \
    "$current_host" \
    "$cwd" \
    "$hook_event_name" \
    "$transcript_path" \
    "stop" \
    "$snapshot_mtime_ns" \
    "$snapshot_fingerprint" \
    "" \
    "$turn_id" \
    "$stop_hook_active" \
    "$last_assistant_message"
}

process_current_payload() {
  local payload_file="$1"
  local manifest_file
  local transcript_path
  local agent_name="$AGENT"
  local session_id
  local fingerprint

  manifest_file="$("$MKTEMP" "${TMP_DIR}/manifest.XXXXXX")" || return 1

  if [ "$agent_name" = "claude" ]; then
    if ! build_claude_manifest_from_payload "$payload_file" "$manifest_file"; then
      "$RM" -f "$manifest_file" 2>/dev/null || true
      return 1
    fi
  else
    if ! build_codex_manifest_from_payload "$payload_file" "$manifest_file"; then
      "$RM" -f "$manifest_file" 2>/dev/null || true
      return 1
    fi
  fi

  transcript_path="$(read_json_field "$manifest_file" '.transcript_path // empty')"
  session_id="$(read_json_field "$manifest_file" '.session_id // empty')"
  fingerprint="$(read_json_field "$manifest_file" '.snapshot_fingerprint // empty')"

  if ! process_manifest_with_lock "$manifest_file" "$transcript_path"; then
    warn "live upload failed for ${agent_name}/${session_id}; queueing snapshot"
    queue_snapshot "$manifest_file" "$transcript_path" "$agent_name" "$session_id" "$fingerprint" || true
  fi

  "$RM" -f "$manifest_file" 2>/dev/null || true
}

scan_codex_rollouts() {
  [ -d "$AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR" ] || return 0

  "$FIND" "$AGENT_SESSION_RECORD_CODEX_SESSIONS_DIR" -type f -name 'rollout-*.jsonl' -print0 2>/dev/null | \
    while IFS= read -r -d '' transcript_path; do
      local session_id
      local cwd
      local mtime_ns
      local latest_mtime_ns
      local fingerprint
      local manifest_file

      if [ ! -s "$transcript_path" ]; then
        continue
      fi

      session_id="$(codex_rollout_session_id "$transcript_path" || true)"
      if [ -z "$session_id" ]; then
        continue
      fi

      mtime_ns="$(file_mtime_ns "$transcript_path" || true)"
      if [ -z "$mtime_ns" ]; then
        continue
      fi

      latest_mtime_ns="$(load_session_state_field "codex" "$session_id" '.snapshot_mtime_ns // empty' || true)"
      if [ -n "$latest_mtime_ns" ] && [ "$mtime_ns" -lt "$latest_mtime_ns" ] 2>/dev/null; then
        continue
      fi

      fingerprint="$(file_fingerprint "$transcript_path" || true)"
      if [ -z "$fingerprint" ] || is_stale_snapshot "codex" "$session_id" "$mtime_ns" "$fingerprint"; then
        continue
      fi

      cwd="$(codex_rollout_cwd "$transcript_path" || true)"
      manifest_file="$("$MKTEMP" "${TMP_DIR}/manifest-sweep.XXXXXX")" || continue

      if ! build_manifest \
        "$manifest_file" \
        "codex" \
        "$session_id" \
        "$current_host" \
        "$cwd" \
        "SessionStart" \
        "$transcript_path" \
        "session-start-sweep" \
        "$mtime_ns" \
        "$fingerprint" \
        "" \
        "" \
        "false" \
        ""; then
        "$RM" -f "$manifest_file" 2>/dev/null || true
        continue
      fi

      if ! process_manifest_with_lock "$manifest_file" "$transcript_path"; then
        warn "session-start sweep failed for codex/${session_id}; queueing snapshot"
        queue_snapshot "$manifest_file" "$transcript_path" "codex" "$session_id" "$fingerprint" || true
      fi

      "$RM" -f "$manifest_file" 2>/dev/null || true
    done
}

case "$MODE" in
  payload)
    process_current_payload "$PAYLOAD_FILE"
    replay_queue
    ;;
  session-start-sweep)
    scan_codex_rollouts
    replay_queue
    ;;
  *)
    usage
    ;;
esac
