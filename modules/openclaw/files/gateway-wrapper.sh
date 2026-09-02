#!/usr/bin/env bash

set -euo pipefail

if (( $# < 2 )); then
  printf 'usage: gateway-wrapper OPENCLAW_BIN DISCORD_TOKEN_FILE [ARG ...]\n' >&2
  exit 64
fi

openclaw_bin="$1"
discord_token_file="$2"
shift 2

if [[ ! -x "$openclaw_bin" ]]; then
  printf 'openclaw gateway wrapper: executable is unavailable: %s\n' "$openclaw_bin" >&2
  exit 69
fi

if [[ ! -r "$discord_token_file" || ! -s "$discord_token_file" ]]; then
  printf 'openclaw gateway wrapper: Discord token file is unavailable or empty: %s\n' "$discord_token_file" >&2
  exit 78
fi

IFS= read -r discord_bot_token < "$discord_token_file" || true
if [[ -z "$discord_bot_token" ]]; then
  printf 'openclaw gateway wrapper: Discord token file has no first line: %s\n' "$discord_token_file" >&2
  exit 78
fi

export DISCORD_BOT_TOKEN="$discord_bot_token"
unset discord_bot_token

exec "$openclaw_bin" "$@"
