#!/usr/bin/env bash

set -u

tmux_bin="${1:-}"
fzf_bin="${2:-}"
selected_session_id=''
selected_query=''
selected_key=''
selected_row=''

if [ -z "${tmux_bin}" ] || [ ! -x "${tmux_bin}" ]; then
  printf 'tmux session manager: tmux binary is missing or not executable\n' >&2
  exit 1
fi

if [ -z "${fzf_bin}" ] || [ ! -x "${fzf_bin}" ]; then
  printf 'tmux session manager: fzf binary is missing or not executable\n' >&2
  exit 1
fi

list_session_rows() {
  "${tmux_bin}" list-sessions -F $'#{session_id}\t#{session_name}\t#{session_windows} windows' 2>/dev/null
}

validate_session_name() {
  local name="${1}"

  if [ -z "${name}" ]; then
    printf 'Name cannot be empty.\n' >&2
    return 1
  fi

  if [[ "${name}" == *:* ]]; then
    printf 'Name cannot contain ":".\n' >&2
    return 1
  fi

  return 0
}

prompt_session_name() {
  local prompt="${1}"
  local name

  while true; do
    if ! read -r -p "${prompt}" name; then
      return 1
    fi

    if ! validate_session_name "${name}"; then
      continue
    fi

    printf '%s\n' "${name}"
    return 0
  done
}

parse_selected_row() {
  local row="${1:-}"

  if [ -z "${row}" ]; then
    return 1
  fi

  selected_session_id="${row%%$'\t'*}"
  [ -n "${selected_session_id}" ]
}

parse_choice() {
  local choice="${1:-}"
  local rest

  selected_query="${choice%%$'\n'*}"
  if [ "${choice}" = "${selected_query}" ]; then
    selected_key=''
    selected_row=''
    return 0
  fi

  rest="${choice#*$'\n'}"
  selected_key="${rest%%$'\n'*}"
  if [ "${rest}" = "${selected_key}" ]; then
    selected_row=''
    return 0
  fi

  selected_row="${rest#*$'\n'}"
}

choose_action() {
  local rows="${1}"

  printf '%s\n' "${rows}" | "${fzf_bin}" \
    --height=80% \
    --layout=reverse \
    --border \
    --prompt='tmux> ' \
    $'--delimiter=\t' \
    --with-nth=2,3 \
    --print-query \
    --header='enter: attach | type new name + enter: create | ctrl-n: prompt new | ctrl-r: rename | ctrl-d: delete' \
    --expect=ctrl-n,ctrl-r,ctrl-d
}

create_session_with_name() {
  local name="${1}"

  if ! validate_session_name "${name}"; then
    return 0
  fi

  exec "${tmux_bin}" new-session -s "${name}"
}

create_session() {
  local name

  if ! name="$(prompt_session_name 'New session name: ')"; then
    return 0
  fi

  create_session_with_name "${name}"
}

rename_session() {
  local session_id="${1}"
  local name

  if ! name="$(prompt_session_name 'New session name: ')"; then
    return 0
  fi

  "${tmux_bin}" rename-session -t "${session_id}" "${name}" >/dev/null
}

delete_session() {
  local session_id="${1}"
  local confirm

  if ! read -r -p "Delete \"${session_id}\"? [y/N] " confirm; then
    return 0
  fi

  case "${confirm}" in
    y | Y | yes | YES)
      "${tmux_bin}" kill-session -t "${session_id}" >/dev/null
      ;;
  esac
}

attach_session() {
  local session_id="${1}"

  exec "${tmux_bin}" attach-session -t "${session_id}"
}

while true; do
  rows="$(list_session_rows || true)"

  if [ -z "${rows}" ]; then
    create_session
    exit 0
  fi

  choice="$(choose_action "${rows}")"
  choice_status=$?

  case "${choice_status}" in
    0)
      ;;
    1)
      [ -n "${choice}" ] || exit 0
      ;;
    *)
      exit 0
      ;;
  esac

  parse_choice "${choice}"

  case "${selected_key}" in
    ctrl-n)
      create_session
      ;;
    enter | '')
      if parse_selected_row "${selected_row}"; then
        attach_session "${selected_session_id}"
      elif [ -n "${selected_query}" ]; then
        create_session_with_name "${selected_query}"
      fi
      ;;
    ctrl-r)
      if parse_selected_row "${selected_row}"; then
        rename_session "${selected_session_id}"
      fi
      ;;
    ctrl-d)
      if parse_selected_row "${selected_row}"; then
        delete_session "${selected_session_id}"
      fi
      ;;
  esac
done
