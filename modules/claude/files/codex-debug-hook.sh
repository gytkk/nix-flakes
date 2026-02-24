#!/usr/bin/env bash
# Codex MCP debug hook — concise tool call logging
# Usage: <stdin json> | codex-debug-hook.sh <pre|post>

LOG="$HOME/.claude/codex-debug.log"
MODE="${1:-post}"
IN=$(cat)
TS=$(date +"%H:%M:%S")
TOOL=$(echo "$IN" | jq -r '.tool_name // "unknown"' 2>/dev/null)

if [ "$MODE" = "pre" ]; then
  if [ "$TOOL" = "mcp__codex__codex-reply" ]; then
    # Reply: show truncated follow-up prompt (this IS the actual request)
    THREAD=$(echo "$IN" | jq -r '.tool_input.threadId // .tool_input.conversationId // empty' 2>/dev/null)
    PROMPT=$(echo "$IN" | jq -r '.tool_input.prompt // empty' 2>/dev/null | cut -c1-200)
    echo "[$TS] >>> $TOOL (${THREAD:0:8})" >> "$LOG"
    [ -n "$PROMPT" ] && echo "  ${PROMPT}" >> "$LOG"
  else
    # Initial call: show only non-prompt parameters (cwd, model, sandbox, etc.)
    PARAMS=$(echo "$IN" | jq -c '
      .tool_input | del(.prompt, .["developer-instructions"], .["base-instructions"], .["compact-prompt"])
    ' 2>/dev/null)
    echo "[$TS] >>> $TOOL ${PARAMS:-{}}" >> "$LOG"
  fi
else
  # Extract threadId and content from MCP response
  RESULT_JSON=$(echo "$IN" | jq -r '.tool_result // empty' 2>/dev/null)
  THREAD=$(echo "$RESULT_JSON" | jq -r 'fromjson? | .threadId // empty' 2>/dev/null)
  CONTENT=$(echo "$RESULT_JSON" | jq -r 'fromjson? | .content // empty' 2>/dev/null)

  # Try parsing content as JSON to extract verdict/status/summary
  BRIEF=$(echo "$CONTENT" | jq -r '
    fromjson? |
    if .verdict then "[\(.verdict)] score:\(.score) \(.summary[:150])"
    elif .status then "[\(.status)] \(.summary[:150])"
    else empty end
  ' 2>/dev/null)

  # Fallback: truncate raw content
  [ -z "$BRIEF" ] && BRIEF=$(echo "$CONTENT" | cut -c1-200)

  {
    echo "[$TS] <<< $TOOL (${THREAD:0:8})"
    echo "  $BRIEF" | head -3
  } >> "$LOG"
fi
