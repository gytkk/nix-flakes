set +x
set -euo pipefail

if [[ $# -eq 0 ]]; then
  echo "Usage: with-jev COMMAND [ARG...]" >&2
  exit 2
fi
if [[ "$1" == --help ]]; then
  echo "Usage: with-jev COMMAND [ARG...]"
  echo "Run a command with TYPESAFE_API_KEY loaded from agenix."
  exit 0
fi

key_file=@secretPath@
if [[ ! -r "$key_file" ]]; then
  echo "with-jev: cannot read $key_file; activate agenix for this environment first." >&2
  exit 1
fi
if ! TYPESAFE_API_KEY=$(cat -- "$key_file"); then
  echo "with-jev: failed to read $key_file." >&2
  exit 1
fi
if [[ -z "$TYPESAFE_API_KEY" || "$TYPESAFE_API_KEY" == *[$'\r\n']* ]]; then
  echo "with-jev: the agenix secret must contain a single nonempty API key." >&2
  exit 1
fi
export TYPESAFE_API_KEY
exec "$@"
