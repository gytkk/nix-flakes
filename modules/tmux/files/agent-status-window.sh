#!/usr/bin/env bash

set -u

window_id="${1:-}"
cache_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/tmux-agent-status"
status_file="${cache_dir}/${window_id}"

[ -n "${window_id}" ] || exit 0
[ -r "${status_file}" ] || exit 0

IFS=$'\t' read -r state agent updated label < "${status_file}" || exit 0

case "${updated}" in
  '' | *[!0-9]*) exit 0 ;;
esac

now="$(date +%s)"
age=$((now - updated))

case "${state}" in
  running | waiting)
    ttl=$((12 * 60 * 60))
    ;;
  done)
    ttl=$((30 * 60))
    ;;
  failed)
    ttl=$((2 * 60 * 60))
    ;;
  *)
    exit 0
    ;;
esac

if [ "${age}" -gt "${ttl}" ]; then
  rm -f "${status_file}" 2>/dev/null || true
  exit 0
fi

case "${state}" in
  running)
    printf '#[fg=colour75]●#[default]'
    ;;
  waiting)
    printf '#[fg=colour220]?#[default]'
    ;;
  done)
    printf '#[fg=colour114]✓#[default]'
    ;;
  failed)
    printf '#[fg=colour203]×#[default]'
    ;;
esac
