#!/usr/bin/env bash

set -u

tmux_bin="${1:-}"
fzf_bin="${2:-}"
selected_session_id=''

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

prompt_session_name() {
  local prompt="${1}"
  local name

  while true; do
    if ! read -r -p "${prompt}" name; then
      return 1
    fi

    if [ -z "${name}" ]; then
      printf 'Name cannot be empty.\n' >&2
      continue
    fi

    if [[ "${name}" == *:* ]]; then
      printf 'Name cannot contain ":".\n' >&2
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

choose_action() {
  local rows="${1}"

  printf '%s\n' "${rows}" | "${fzf_bin}" \
    --height=80% \
    --layout=reverse \
    --border \
    --prompt='tmux> ' \
    $'--delimiter=\t' \
    --with-nth=2,3 \
    --header='enter: attach | ctrl-n: new | ctrl-r: rename | ctrl-d: delete' \
    --expect=enter,ctrl-n,ctrl-r,ctrl-d
}

create_session() {
  local name

  if ! name="$(prompt_session_name 'New session name: ')"; then
    return 0
  fi

  exec "${tmux_bin}" new-session -s "${name}"
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

  if ! choice="$(choose_action "${rows}")"; then
    exit 0
  fi

  key="${choice%%$'\n'*}"
  if [ "${choice}" = "${key}" ]; then
    row=''
  else
    row="${choice#*$'\n'}"
  fi

  case "${key}" in
    ctrl-n)
      create_session
      ;;
    enter | '')
      if parse_selected_row "${row}"; then
        attach_session "${selected_session_id}"
      fi
      ;;
    ctrl-r)
      if parse_selected_row "${row}"; then
        rename_session "${selected_session_id}"
      fi
      ;;
    ctrl-d)
      if parse_selected_row "${row}"; then
        delete_session "${selected_session_id}"
      fi
      ;;
  esac
done
