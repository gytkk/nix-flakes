#!/usr/bin/env bash

set -u

tmux_bin="${1:-}"

if [ -z "${tmux_bin}" ] || [ ! -x "${tmux_bin}" ]; then
  printf 'tmux session manager: real tmux binary is missing or not executable\n' >&2
  exit 1
fi

sessions=()
selected_session=''
session_name=''

load_sessions() {
  local output session

  sessions=()
  if ! output="$("${tmux_bin}" list-sessions -F '#{session_name}' 2>/dev/null)"; then
    return 0
  fi

  while IFS= read -r session; do
    if [ -n "${session}" ]; then
      sessions+=("${session}")
    fi
  done <<<"${output}"
}

is_number() {
  local value="${1:-}"
  [[ "${value}" =~ ^[0-9]+$ ]]
}

print_menu() {
  local index

  printf '\nTmux sessions\n'
  if [ "${#sessions[@]}" -eq 0 ]; then
    printf '  (none)\n'
  else
    for index in "${!sessions[@]}"; do
      printf '  %d) %s\n' "$((index + 1))" "${sessions[${index}]}"
    done
  fi

  printf '\n'
  if [ "${#sessions[@]}" -gt 0 ]; then
    printf 'Enter a number to attach, c to create, r to rename, d to delete, q to quit.\n'
  else
    printf 'Enter c to create a named session or q to quit.\n'
  fi
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

    session_name="${name}"
    return 0
  done
}

session_by_number() {
  local choice="${1:-}"
  local index

  if ! is_number "${choice}"; then
    printf 'Enter a session number.\n' >&2
    return 1
  fi

  index=$((choice - 1))
  if [ "${index}" -lt 0 ] || [ "${index}" -ge "${#sessions[@]}" ]; then
    printf 'No session for number %s.\n' "${choice}" >&2
    return 1
  fi

  selected_session="${sessions[${index}]}"
}

create_session() {
  if ! prompt_session_name 'New session name: '; then
    return 0
  fi

  exec "${tmux_bin}" new-session -s "${session_name}"
}

rename_session() {
  local choice old_name new_name

  if [ "${#sessions[@]}" -eq 0 ]; then
    printf 'No sessions to rename.\n'
    return 0
  fi

  if ! read -r -p 'Session number to rename: ' choice; then
    return 0
  fi

  if ! session_by_number "${choice}"; then
    return 0
  fi
  old_name="${selected_session}"

  if ! prompt_session_name 'New session name: '; then
    return 0
  fi
  new_name="${session_name}"

  if "${tmux_bin}" rename-session -t "${old_name}" "${new_name}"; then
    printf 'Renamed "%s" to "%s".\n' "${old_name}" "${new_name}"
  else
    printf 'Could not rename "%s".\n' "${old_name}" >&2
  fi
}

delete_session() {
  local choice name confirm

  if [ "${#sessions[@]}" -eq 0 ]; then
    printf 'No sessions to delete.\n'
    return 0
  fi

  if ! read -r -p 'Session number to delete: ' choice; then
    return 0
  fi

  if ! session_by_number "${choice}"; then
    return 0
  fi
  name="${selected_session}"

  if ! read -r -p "Delete \"${name}\"? [y/N] " confirm; then
    return 0
  fi

  case "${confirm}" in
    y | Y | yes | YES)
      if "${tmux_bin}" kill-session -t "${name}"; then
        printf 'Deleted "%s".\n' "${name}"
      else
        printf 'Could not delete "%s".\n' "${name}" >&2
      fi
      ;;
    *)
      printf 'Delete cancelled.\n'
      ;;
  esac
}

attach_session() {
  local choice="${1:-}"
  local name

  if ! session_by_number "${choice}"; then
    return 0
  fi
  name="${selected_session}"

  exec "${tmux_bin}" attach-session -t "${name}"
}

while true; do
  load_sessions
  print_menu

  if ! read -r -p 'Choice: ' choice; then
    printf '\n'
    exit 0
  fi

  case "${choice}" in
    q | Q)
      exit 0
      ;;
    c | C)
      create_session
      ;;
    r | R)
      rename_session
      ;;
    d | D)
      delete_session
      ;;
    *)
      attach_session "${choice}"
      ;;
  esac
done
