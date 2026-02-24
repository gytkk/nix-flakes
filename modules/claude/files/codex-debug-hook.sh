#!/usr/bin/env bash
# Codex MCP debug hook — logs tool calls to ~/.claude/codex-debug.log
# Usage: <stdin json> | codex-debug-hook.sh <pre|post>

LOG="$HOME/.claude/codex-debug.log"
MODE="${1:-post}"
IN=$(cat)
TS=$(date +"%H:%M:%S")
TOOL=$(echo "$IN" | jq -r '.tool_name // "unknown"' 2>/dev/null)

if [ "$MODE" = "pre" ]; then
  {
    echo "=== [$TS] >>> $TOOL ==="
    # Log parameters except prompt (too verbose with agent persona)
    echo "$IN" | jq -r '
      .tool_input | to_entries
      | map(select(.key != "prompt" and .key != "developer-instructions" and .key != "base-instructions"))
      | from_entries
    ' 2>/dev/null
    echo ""
  } >> "$LOG"
else
  {
    echo "=== [$TS] <<< $TOOL ==="
    echo "$IN" | jq -r '.tool_result // empty' 2>/dev/null
    echo ""
  } >> "$LOG"
fi
