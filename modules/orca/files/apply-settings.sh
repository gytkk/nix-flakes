#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: apply-settings.sh PATCH DATA_FILE_OR_DIRECTORY MERGE_FILTER" >&2
  exit 2
fi

patch=$1
data=$2
merge_filter=$3

require_stopped() {
  local status=0
  pgrep -x 'Orca|orcad' >/dev/null || status=$?
  case "$status" in
    0) echo "Quit Orca before applying settings." >&2; exit 1 ;;
    1) return ;;
    *) echo "Cannot determine whether Orca is running (pgrep exit $status)." >&2; exit 1 ;;
  esac
}

require_stopped
profile_index=""
profile_hash=""
if [ -d "$data" ]; then
  if [ -e "$data/orca-profile-index.json" ]; then
    profile_index="$data/orca-profile-index.json"
    profile_hash=$(sha256sum "$profile_index")
    if ! profile=$(jq -e -r -s '
      if length == 1 and (.[0].activeProfileId | type) == "string"
         and (.[0].activeProfileId | test("^[A-Za-z0-9_-]+$"))
      then .[0].activeProfileId
      else error("Expected a safe activeProfileId in the Orca profile index") end
    ' "$profile_index"); then
      echo "Cannot resolve the active Orca profile from $profile_index." >&2
      exit 1
    fi
    data="$data/profiles/$profile/orca-data.json"
  else
    data="$data/orca-data.json"
  fi
fi
if [ ! -f "$data" ] || [ -L "$data" ]; then
  echo "Expected a regular Orca data file at $data. Open Orca once, then quit it." >&2
  exit 1
fi

umask 077
original_hash=$(sha256sum "$data")
temporary=$(mktemp "$data.nix-tmp.XXXXXX")
trap 'rm -f "$temporary"' EXIT

if ! jq -e -s --slurpfile patch "$patch" -f "$merge_filter" "$data" > "$temporary"; then
  echo "Failed to merge Orca appearance settings; the data file was not changed." >&2
  exit 1
fi
if cmp -s "$data" "$temporary"; then
  echo "Orca appearance settings are already applied."
  exit 0
fi

require_stopped
if [ -n "$profile_index" ] && [ "$profile_hash" != "$(sha256sum "$profile_index")" ]; then
  echo "The active Orca profile changed during the merge. Quit Orca and retry." >&2
  exit 1
fi
if [ "$original_hash" != "$(sha256sum "$data")" ]; then
  echo "Orca data changed during the merge. Quit Orca and retry." >&2
  exit 1
fi
backup=$(mktemp "$data.nix-backup.XXXXXX")
cp "$data" "$backup"
chmod --reference="$data" "$temporary"
mv "$temporary" "$data"
echo "Applied Orca appearance settings. Backup: $backup"
