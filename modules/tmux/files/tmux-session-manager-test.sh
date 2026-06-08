#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SUBJECT="${SCRIPT_DIR}/tmux-session-manager.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/tmux-session-manager-test.XXXXXX")"
FAKE_TMUX="${TEST_ROOT}/tmux"
FAKE_FZF="${TEST_ROOT}/fzf"
TMUX_LOG="${TEST_ROOT}/tmux.log"
FZF_INPUT="${TEST_ROOT}/fzf-input"
FZF_USED="${TEST_ROOT}/fzf-used"
SESSIONS_FILE="${TEST_ROOT}/sessions"

trap 'rm -rf "${TEST_ROOT}"' EXIT

cat >"${FAKE_TMUX}" <<'FAKE_TMUX'
#!/usr/bin/env bash

set -euo pipefail

: "${TMUX_TEST_LOG:?}"
: "${TMUX_TEST_SESSIONS:?}"

printf 'args:%s\n' "$*" >>"${TMUX_TEST_LOG}"

case "${1:-} ${2:-}" in
  'list-sessions -F')
    expected_format=$'#{session_id}\t#{session_name}\t#{session_windows} windows'
    if [ "${3:-}" != "${expected_format}" ]; then
      printf 'unexpected tmux list format: %s\n' "${3:-}" >&2
      exit 2
    fi

    if [ -s "${TMUX_TEST_SESSIONS}" ]; then
      cat "${TMUX_TEST_SESSIONS}"
    else
      exit 1
    fi
    ;;
  'attach-session -t')
    printf 'attached:%s\n' "${3:-}" >>"${TMUX_TEST_LOG}"
    ;;
  'new-session -s')
    printf 'new:%s\n' "${3:-}" >>"${TMUX_TEST_LOG}"
    ;;
  'rename-session -t')
    printf 'renamed:%s:%s\n' "${3:-}" "${4:-}" >>"${TMUX_TEST_LOG}"
    ;;
  'kill-session -t')
    printf 'killed:%s\n' "${3:-}" >>"${TMUX_TEST_LOG}"
    ;;
  *)
    printf 'unexpected tmux args: %s\n' "$*" >&2
    exit 2
    ;;
esac
FAKE_TMUX

cat >"${FAKE_FZF}" <<'FAKE_FZF'
#!/usr/bin/env bash

set -euo pipefail

: "${TMUX_TEST_FZF_INPUT:?}"
: "${TMUX_TEST_FZF_OUTPUT:?}"
: "${TMUX_TEST_FZF_USED:?}"

has_arg() {
  local expected="${1}"
  local arg

  shift
  for arg in "$@"; do
    if [ "${arg}" = "${expected}" ]; then
      return 0
    fi
  done

  return 1
}

has_delimiter_arg() {
  local args=("$@")
  local index

  for index in "${!args[@]}"; do
    case "${args[${index}]}" in
      $'--delimiter=\t')
        return 0
        ;;
      '--delimiter')
        if [ "${args[$((index + 1))]:-}" = $'\t' ]; then
          return 0
        fi
        ;;
    esac
  done

  return 1
}

if ! has_arg '--expect=enter,ctrl-n,ctrl-r,ctrl-d' "$@"; then
  printf 'missing required fzf arg: --expect=enter,ctrl-n,ctrl-r,ctrl-d\n' >&2
  exit 2
fi

if ! has_delimiter_arg "$@"; then
  printf 'missing required fzf tab delimiter\n' >&2
  exit 2
fi

if ! has_arg '--with-nth=2,3' "$@"; then
  printf 'missing required fzf arg: --with-nth=2,3\n' >&2
  exit 2
fi

cat >"${TMUX_TEST_FZF_INPUT}"

if [ -e "${TMUX_TEST_FZF_USED}" ]; then
  exit 130
fi

: >"${TMUX_TEST_FZF_USED}"
printf '%s' "${TMUX_TEST_FZF_OUTPUT}"
FAKE_FZF

chmod +x "${FAKE_TMUX}" "${FAKE_FZF}"

reset_files() {
  : >"${TMUX_LOG}"
  : >"${FZF_INPUT}"
  : >"${SESSIONS_FILE}"
  rm -f "${FZF_USED}"
}

run_manager() {
  local stdin="${1:-}"
  local fzf_output="${2:-}"

  TMUX_TEST_LOG="${TMUX_LOG}" \
    TMUX_TEST_SESSIONS="${SESSIONS_FILE}" \
    TMUX_TEST_FZF_INPUT="${FZF_INPUT}" \
    TMUX_TEST_FZF_USED="${FZF_USED}" \
    TMUX_TEST_FZF_OUTPUT="${fzf_output}" \
    bash "${SUBJECT}" "${FAKE_TMUX}" "${FAKE_FZF}" <<<"${stdin}"
}

assert_log_equals() {
  local expected="${1}"
  local actual

  actual="$(cat "${TMUX_LOG}")"
  if [ "${actual}" = "${expected}" ]; then
    return 0
  fi

  printf 'Unexpected tmux log\n' >&2
  printf 'Expected log:\n%s\n' "${expected}" >&2
  printf 'Actual log:\n' >&2
  cat "${TMUX_LOG}" >&2
  return 1
}

assert_file_equals() {
  local file="${1}"
  local expected="${2}"
  local actual

  actual="$(cat "${file}")"
  if [ "${actual}" != "${expected}" ]; then
    printf 'Unexpected file content for %s\n' "${file}" >&2
    printf 'Expected:\n%s\n' "${expected}" >&2
    printf 'Actual:\n%s\n' "${actual}" >&2
    return 1
  fi
}

test_attach_selected_session() {
  reset_files
  printf '@1\twork\t2 windows\n@2\tops\t1 windows\n' >"${SESSIONS_FILE}"

  run_manager '' $'enter\n@2\tops\t1 windows\n'

  assert_log_equals $'args:list-sessions -F #{session_id}\t#{session_name}\t#{session_windows} windows\nargs:attach-session -t @2\nattached:@2'
  assert_file_equals "${FZF_INPUT}" $'@1\twork\t2 windows\n@2\tops\t1 windows'
}

test_rename_selected_session() {
  reset_files
  printf '@1\twork\t2 windows\n' >"${SESSIONS_FILE}"

  run_manager $'renamed\n' $'ctrl-r\n@1\twork\t2 windows\n'

  assert_log_equals $'args:list-sessions -F #{session_id}\t#{session_name}\t#{session_windows} windows\nargs:rename-session -t @1 renamed\nrenamed:@1:renamed\nargs:list-sessions -F #{session_id}\t#{session_name}\t#{session_windows} windows'
}

test_delete_selected_session() {
  reset_files
  printf '@1\twork\t2 windows\n' >"${SESSIONS_FILE}"

  run_manager $'y\n' $'ctrl-d\n@1\twork\t2 windows\n'

  assert_log_equals $'args:list-sessions -F #{session_id}\t#{session_name}\t#{session_windows} windows\nargs:kill-session -t @1\nkilled:@1\nargs:list-sessions -F #{session_id}\t#{session_name}\t#{session_windows} windows'
}

test_ctrl_n_creates_session() {
  reset_files
  printf '@1\twork\t2 windows\n' >"${SESSIONS_FILE}"

  run_manager $'fresh\n' $'ctrl-n\n'

  assert_log_equals $'args:list-sessions -F #{session_id}\t#{session_name}\t#{session_windows} windows\nargs:new-session -s fresh\nnew:fresh'
}

test_no_sessions_prompts_for_new_session() {
  reset_files

  run_manager $'fresh\n' ''

  assert_log_equals $'args:list-sessions -F #{session_id}\t#{session_name}\t#{session_windows} windows\nargs:new-session -s fresh\nnew:fresh'
  assert_file_equals "${FZF_INPUT}" ''
}

run_test() {
  local name="${1}"

  printf 'running %s\n' "${name}"
  "${name}"
}

run_test test_attach_selected_session
run_test test_rename_selected_session
run_test test_delete_selected_session
run_test test_ctrl_n_creates_session
run_test test_no_sessions_prompts_for_new_session

printf 'tmux-session-manager tests passed\n'
