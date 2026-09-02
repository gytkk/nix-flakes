#!/usr/bin/env bash

set -euo pipefail

wrapper="${1:?usage: gateway-wrapper.test.sh WRAPPER}"
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT

fake_openclaw="$test_dir/openclaw"
token_file="$test_dir/discord-token"

# Keep the environment and argument expressions literal for the generated fixture.
# shellcheck disable=SC2016
printf '#!%s\nset -euo pipefail\n[[ "${DISCORD_BOT_TOKEN:-}" == "fixture-token" ]]\n[[ "$*" == "gateway --port 18789" ]]\n' \
  "$(command -v bash)" > "$fake_openclaw"
chmod 700 "$fake_openclaw"
printf 'fixture-token\n' > "$token_file"
chmod 400 "$token_file"

bash "$wrapper" "$fake_openclaw" "$token_file" gateway --port 18789

chmod 600 "$token_file"
: > "$token_file"
if output="$(bash "$wrapper" "$fake_openclaw" "$token_file" gateway 2>&1)"; then
  printf 'gateway wrapper accepted an empty token file\n' >&2
  exit 1
fi
[[ "$output" != *"fixture-token"* ]]

printf 'openclaw gateway wrapper tests passed\n'
