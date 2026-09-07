#!/usr/bin/env bash

set -euo pipefail

if (( $# != 2 )); then
  printf 'usage: %s <source-tree> <target-tree>\n' "$0" >&2
  exit 64
fi

source_tree="$1"
target_tree="$2"

if [[ ! -d "$source_tree" ]]; then
  printf 'openclaw runtime source tree is missing: %s\n' "$source_tree" >&2
  exit 1
fi

if [[ "$target_tree" != /* || "$target_tree" == "/" ]]; then
  printf 'openclaw runtime target must be an absolute non-root path: %s\n' "$target_tree" >&2
  exit 64
fi

target_name="$(basename -- "$target_tree")"
case "$target_name" in
  skills | agent-core-context | agent-session-record)
    ;;
  *)
    printf 'refusing to replace an unexpected OpenClaw runtime target: %s\n' "$target_tree" >&2
    exit 64
    ;;
esac

target_parent="$(dirname -- "$target_tree")"
mkdir -p -- "$target_parent"

staging_tree="$(mktemp -d "$target_parent/.${target_name}.new.XXXXXX")"
backup_tree=""

remove_tree() {
  local tree="$1"

  if [[ -d "$tree" && ! -L "$tree" ]]; then
    chmod -R u+w -- "$tree"
  fi
  rm -rf -- "$tree"
}

cleanup() {
  if [[ -n "$staging_tree" && ( -e "$staging_tree" || -L "$staging_tree" ) ]]; then
    remove_tree "$staging_tree"
  fi
}
trap cleanup EXIT

cp -R --no-preserve=links --reflink=never -- "$source_tree/." "$staging_tree/"

if find -P "$staging_tree" -type l -print -quit | read -r unexpected_link; then
  printf 'openclaw runtime source contains a symbolic link: %s\n' "$unexpected_link" >&2
  exit 1
fi

while IFS= read -r -d '' deployed_file; do
  link_count="$(stat --format=%h -- "$deployed_file")"
  if [[ "$link_count" != 1 ]]; then
    printf 'openclaw runtime file is still hardlinked: %s\n' "$deployed_file" >&2
    exit 1
  fi
done < <(find -P "$staging_tree" -type f -print0)

chmod -R a-w -- "$staging_tree"

if [[ -e "$target_tree" || -L "$target_tree" ]]; then
  backup_tree="$(mktemp -d "$target_parent/.${target_name}.old.XXXXXX")"
  rmdir -- "$backup_tree"
  mv -T -- "$target_tree" "$backup_tree"
fi

if ! mv -T -- "$staging_tree" "$target_tree"; then
  if [[ -n "$backup_tree" && ( -e "$backup_tree" || -L "$backup_tree" ) ]]; then
    mv -T -- "$backup_tree" "$target_tree"
  fi
  exit 1
fi
staging_tree=""

if [[ -n "$backup_tree" && ( -e "$backup_tree" || -L "$backup_tree" ) ]]; then
  remove_tree "$backup_tree"
fi

trap - EXIT
