#!/data/data/com.termux/files/usr/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_file="$script_dir/termux-packages.txt"

if ! command -v pkg >/dev/null 2>&1; then
  echo "This script must run in the regular Termux app." >&2
  exit 1
fi

packages=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$package_file")

pkg update
# shellcheck disable=SC2086
pkg install -y $packages
