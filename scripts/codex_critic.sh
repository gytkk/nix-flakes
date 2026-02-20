#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# codex_critic.sh - Codex CLI를 사용한 코드/계획 검증 스크립트
#
# Usage: bash scripts/codex_critic.sh "<original_user_prompt>"
#
# Environment:
#   OPENAI_API_KEY       - Required. OpenAI API key
#   CRITIC_MAX_ITER      - Max refinement iterations (default: 5)
#   CRITIC_MAX_DIFF_LINES - Max diff lines to include (default: 500)
#   CRITIC_SANDBOX       - Sandbox mode (default: read-only)
# =============================================================================

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
OUTPUT_DIR="${REPO_ROOT}/.ai"
SCHEMA_FILE="${REPO_ROOT}/.ai/schemas/critic.schema.json"
OUTPUT_FILE="${OUTPUT_DIR}/critic-result.json"
LOG_FILE="${OUTPUT_DIR}/critic.log"
MAX_ITERATIONS="${CRITIC_MAX_ITER:-5}"
MAX_DIFF_LINES="${CRITIC_MAX_DIFF_LINES:-500}"
SANDBOX="${CRITIC_SANDBOX:-read-only}"

# --- Prerequisite checks ---

if ! command -v codex &>/dev/null; then
  cat >&2 <<'ERRMSG'
[ERROR] codex CLI not found.

Install Codex CLI:
  # Via nix (if using this repo's flake)
  nix run .#codex

  # Via npm
  npm install -g @openai/codex

Ensure 'codex' is in your PATH.
ERRMSG
  exit 1
fi

if [ -z "${OPENAI_API_KEY:-}" ]; then
  cat >&2 <<'ERRMSG'
[ERROR] OPENAI_API_KEY is not set.

Set your API key:
  export OPENAI_API_KEY="sk-..."

Or use ChatGPT authentication:
  codex login
ERRMSG
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "[ERROR] jq is required but not found." >&2
  exit 1
fi

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "[ERROR] Schema file not found: $SCHEMA_FILE" >&2
  exit 1
fi

# --- Argument parsing ---

USER_PROMPT="${1:-}"
if [ -z "$USER_PROMPT" ]; then
  echo "[ERROR] Usage: bash scripts/codex_critic.sh \"<original_user_prompt>\"" >&2
  exit 1
fi

# --- Collect diff ---

DIFF="$(git diff --staged 2>/dev/null || true)"
if [ -z "$DIFF" ]; then
  DIFF="$(git diff 2>/dev/null || true)"
fi

if [ -z "$DIFF" ]; then
  echo "[WARN] No diff found. Attempting to use last commit diff." >&2
  DIFF="$(git diff HEAD~1 HEAD 2>/dev/null || true)"
fi

if [ -z "$DIFF" ]; then
  echo "[ERROR] No changes found to review." >&2
  exit 1
fi

# Truncate long diffs
DIFF_LINE_COUNT="$(echo "$DIFF" | wc -l | tr -d ' ')"
if [ "$DIFF_LINE_COUNT" -gt "$MAX_DIFF_LINES" ]; then
  DIFF="$(echo "$DIFF" | head -n "$MAX_DIFF_LINES")"
  DIFF="${DIFF}

[... truncated: showing first ${MAX_DIFF_LINES} of ${DIFF_LINE_COUNT} lines ...]"
fi

# --- Setup output directory ---

mkdir -p "$OUTPUT_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log "=== Codex Critic started ==="
log "User prompt: $USER_PROMPT"
log "Diff lines: $DIFF_LINE_COUNT (max: $MAX_DIFF_LINES)"
log "Max iterations: $MAX_ITERATIONS"

# --- Iteration loop ---

ITERATION=0
PREV_RESULT=""

while [ "$ITERATION" -lt "$MAX_ITERATIONS" ]; do
  ITERATION=$((ITERATION + 1))
  log "--- Iteration $ITERATION ---"

  # Build prompt
  PROMPT_FILE="$(mktemp)"
  trap 'rm -f "$PROMPT_FILE"' EXIT

  if [ -z "$PREV_RESULT" ]; then
    # First iteration: fresh analysis
    cat > "$PROMPT_FILE" <<PROMPT_EOF
You are a meticulous code reviewer and critic. Your task is to evaluate whether the code changes (diff) correctly and completely fulfill the original user request.

## Original User Request
${USER_PROMPT}

## Code Changes (Diff)
\`\`\`diff
${DIFF}
\`\`\`

## Instructions
1. Analyze the diff against the original request.
2. Check for: correctness, completeness, security, style consistency, edge cases, and potential bugs.
3. Produce a structured JSON review.

## Output Requirements
Respond with ONLY valid JSON matching this structure:
{
  "verdict": "pass" | "warn" | "fail",
  "score": <0-10>,
  "summary": "<one paragraph summary>",
  "issues": [
    {
      "severity": "critical" | "major" | "minor" | "info",
      "category": "<category>",
      "file": "<file path if applicable>",
      "line": <line number if applicable>,
      "description": "<what the issue is>",
      "suggestion": "<how to fix>"
    }
  ],
  "checklist": [
    {
      "item": "<what was checked>",
      "passed": true | false,
      "note": "<additional context>"
    }
  ],
  "iteration": ${ITERATION}
}

Be thorough but fair. Only flag real issues, not stylistic preferences unless they violate project conventions.
Output ONLY the JSON object, no markdown fences, no explanation before or after.
PROMPT_EOF
  else
    # Refinement iteration: improve based on previous result
    cat > "$PROMPT_FILE" <<PROMPT_EOF
You are refining a previous code review. Review your prior analysis, identify any missed issues or false positives, and produce an improved version.

## Original User Request
${USER_PROMPT}

## Code Changes (Diff)
\`\`\`diff
${DIFF}
\`\`\`

## Previous Analysis (Iteration $((ITERATION - 1)))
${PREV_RESULT}

## Refinement Instructions
1. Re-examine each issue: remove false positives, add missed problems.
2. Recalibrate the score based on your refined understanding.
3. Ensure the checklist is comprehensive.
4. If your previous analysis was already thorough and accurate, you may keep it largely unchanged but update the iteration number.

## Output Requirements
Respond with ONLY valid JSON (same schema as before).
Set "iteration" to ${ITERATION}.
Output ONLY the JSON object, no markdown fences, no explanation before or after.
PROMPT_EOF
  fi

  # Run codex exec
  log "Running codex exec (sandbox: $SANDBOX)..."
  ITER_OUTPUT_FILE="${OUTPUT_DIR}/critic-iter-${ITERATION}.json"

  if codex exec \
    --sandbox "$SANDBOX" \
    --output-schema "$SCHEMA_FILE" \
    --output-last-message "$ITER_OUTPUT_FILE" \
    - < "$PROMPT_FILE" >> "$LOG_FILE" 2>&1; then
    log "codex exec succeeded"
  else
    EXIT_CODE=$?
    log "codex exec failed with exit code $EXIT_CODE"
    echo "[ERROR] codex exec failed (iteration $ITERATION). See $LOG_FILE for details." >&2
    rm -f "$PROMPT_FILE"
    # If we have a previous result, use it as final
    if [ -n "$PREV_RESULT" ]; then
      echo "$PREV_RESULT" > "$OUTPUT_FILE"
      log "Using previous iteration result as final"
      break
    fi
    exit 1
  fi

  rm -f "$PROMPT_FILE"

  # Read and validate result
  if [ ! -f "$ITER_OUTPUT_FILE" ]; then
    log "Output file not created: $ITER_OUTPUT_FILE"
    echo "[ERROR] codex did not produce output file." >&2
    if [ -n "$PREV_RESULT" ]; then
      echo "$PREV_RESULT" > "$OUTPUT_FILE"
      break
    fi
    exit 1
  fi

  CURRENT_RESULT="$(cat "$ITER_OUTPUT_FILE")"

  # Try to extract JSON if output contains non-JSON text
  if ! echo "$CURRENT_RESULT" | jq . >/dev/null 2>&1; then
    # Attempt to extract JSON object from the output
    EXTRACTED="$(echo "$CURRENT_RESULT" | sed -n '/^{/,/^}/p' | head -200)"
    if echo "$EXTRACTED" | jq . >/dev/null 2>&1; then
      CURRENT_RESULT="$EXTRACTED"
      echo "$CURRENT_RESULT" > "$ITER_OUTPUT_FILE"
      log "Extracted valid JSON from output"
    else
      log "WARNING: Could not parse output as JSON"
      if [ -n "$PREV_RESULT" ]; then
        echo "$PREV_RESULT" > "$OUTPUT_FILE"
        break
      fi
      echo "[ERROR] codex output is not valid JSON. Raw output saved to $ITER_OUTPUT_FILE" >&2
      exit 1
    fi
  fi

  # Check if refinement is needed
  VERDICT="$(echo "$CURRENT_RESULT" | jq -r '.verdict // "unknown"')"
  SCORE="$(echo "$CURRENT_RESULT" | jq -r '.score // 0' | cut -d. -f1)"
  log "Iteration $ITERATION: verdict=$VERDICT, score=$SCORE"

  # Save as final result
  cp "$ITER_OUTPUT_FILE" "$OUTPUT_FILE"
  PREV_RESULT="$CURRENT_RESULT"

  # Stop if analysis is confident enough
  if [ "$VERDICT" = "pass" ] || [ "${SCORE:-0}" -ge 8 ]; then
    log "Confident result reached at iteration $ITERATION"
    break
  fi

  if [ "$ITERATION" -ge "$MAX_ITERATIONS" ]; then
    log "Max iterations reached"
  fi
done

log "=== Codex Critic finished (iterations: $ITERATION) ==="
echo "$OUTPUT_FILE"
