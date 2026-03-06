#!/usr/bin/env bash
# Claude Code status line script

input=$(cat)

# Extract fields from JSON input
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "?"')
model=$(echo "$input" | jq -r '.model.display_name // "?"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
input_tokens=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
output_tokens=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
lines_added=$(echo "$input" | jq -r '.cost.total_lines_added // empty')
lines_removed=$(echo "$input" | jq -r '.cost.total_lines_removed // empty')

# Active LSP servers (cached to avoid frequent process scans)
LSP_CACHE_FILE="/tmp/claude-statusline-lsp-cache"
LSP_CACHE_MAX_AGE=10

lsp_cache_is_stale() {
  [ ! -f "$LSP_CACHE_FILE" ] && return 0
  local file_age
  if file_age=$(stat -c %Y "$LSP_CACHE_FILE" 2>/dev/null); then
    [ $(($(date +%s) - file_age)) -gt $LSP_CACHE_MAX_AGE ]
  elif file_age=$(stat -f %m "$LSP_CACHE_FILE" 2>/dev/null); then
    [ $(($(date +%s) - file_age)) -gt $LSP_CACHE_MAX_AGE ]
  else
    return 0
  fi
}

# Check if a process is a descendant of Claude Code ($PPID)
is_claude_descendant() {
  local current
  current=$(ps -o ppid= -p "$1" 2>/dev/null | tr -d ' ')
  while [ -n "$current" ] && [ "$current" != "0" ] && [ "$current" != "1" ]; do
    [ "$current" = "$PPID" ] && return 0
    current=$(ps -o ppid= -p "$current" 2>/dev/null | tr -d ' ')
  done
  return 1
}

if lsp_cache_is_stale; then
  active_lsps=""
  for lsp_entry in "gopls:gopls" "rust-analyzer:rust" "typescript-language-server:ts" "nixd:nixd" "terraform-ls:tf" "metals:metals" "pyright:pyright" "ty-server:ty"; do
    lsp_proc="${lsp_entry%%:*}"
    lsp_short="${lsp_entry#*:}"
    for pid in $(pgrep -f "$lsp_proc" 2>/dev/null); do
      if is_claude_descendant "$pid"; then
        active_lsps="${active_lsps:+$active_lsps,}$lsp_short"
        break
      fi
    done
  done
  echo "$active_lsps" > "$LSP_CACHE_FILE"
else
  active_lsps=$(cat "$LSP_CACHE_FILE")
fi

# ANSI colors
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
DIM='\033[2m'
RESET='\033[0m'
BOLD_BLUE='\033[1;34m'
BRIGHT_ORANGE='\033[1;38;5;214m'

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/~}"

# Git branch (cached to avoid slowness in large repos)
CACHE_FILE="/tmp/claude-statusline-git-cache"
CACHE_MAX_AGE=5
git_branch=""

cache_is_stale() {
  [ ! -f "$CACHE_FILE" ] && return 0
  local file_age
  # Try GNU stat first, then BSD stat
  if file_age=$(stat -c %Y "$CACHE_FILE" 2>/dev/null); then
    [ $(($(date +%s) - file_age)) -gt $CACHE_MAX_AGE ]
  elif file_age=$(stat -f %m "$CACHE_FILE" 2>/dev/null); then
    [ $(($(date +%s) - file_age)) -gt $CACHE_MAX_AGE ]
  else
    return 0
  fi
}

if cache_is_stale; then
  if git -C "$cwd" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null)
    git_common_dir=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null)
    if [ "$git_dir" != "$git_common_dir" ]; then
      wt_name=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")
      git_branch="worktree(${wt_name})"
    else
      git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
    fi
  fi
  echo "$git_branch" > "$CACHE_FILE"
else
  git_branch=$(cat "$CACHE_FILE")
fi

# Format token count (e.g., 15234 -> 15.2k, 1234567 -> 1.2M)
format_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    printf '%s.%sM' "$((n / 1000000))" "$(( (n % 1000000) / 100000 ))"
  elif [ "$n" -ge 1000 ]; then
    printf '%s.%sk' "$((n / 1000))" "$(( (n % 1000) / 100 ))"
  else
    printf '%s' "$n"
  fi
}

# Section separator
SEP=" ${DIM}|${RESET} "

# Context progress bar (colored = for filled, dim . for empty)
context_info=""
if [ -n "$used" ]; then
  used_int=${used%.*}
  BAR_WIDTH=10
  FILLED=$((used_int * BAR_WIDTH / 100))
  EMPTY=$((BAR_WIDTH - FILLED))

  if [ "$used_int" -ge 90 ]; then BAR_COLOR="$RED"
  elif [ "$used_int" -ge 70 ]; then BAR_COLOR="$YELLOW"
  else BAR_COLOR="$GREEN"; fi

  BAR=""
  [ "$FILLED" -gt 0 ] && BAR="${BAR_COLOR}$(printf "%${FILLED}s" | tr ' ' '#')${RESET}"
  [ "$EMPTY" -gt 0 ] && BAR="${BAR}${DIM}$(printf "%${EMPTY}s" | tr ' ' '-')${RESET}"

  context_info="${BAR} ${used_int}%"
fi

# Token usage (arrow indicators: input↓ output↑)
token_info=""
if [ -n "$input_tokens" ] && [ -n "$output_tokens" ]; then
  token_info="${DIM}tokens${RESET} ${BOLD_BLUE}↓$(format_tokens "$input_tokens")${RESET} ${BRIGHT_ORANGE}↑$(format_tokens "$output_tokens")${RESET}"
fi

# Lines changed
lines_info=""
if [ -n "$lines_added" ] && [ -n "$lines_removed" ]; then
  lines_info="${DIM}lines${RESET} ${GREEN}+${lines_added}${RESET} ${RED}-${lines_removed}${RESET}"
fi

# LSP info
lsp_info=""
if [ -n "$active_lsps" ]; then
  lsp_info="${DIM}lsp${RESET} ${GREEN}${active_lsps}${RESET}"
fi

# Compose status line
output="${CYAN}${short_cwd}${RESET}"
[ -n "$git_branch" ] && output="${output}${SEP}${git_branch}"
output="${output}${SEP}${model}"
[ -n "$context_info" ] && output="${output}${SEP}${context_info}"
[ -n "$token_info" ] && output="${output}${SEP}${token_info}"
[ -n "$lines_info" ] && output="${output}${SEP}${lines_info}"
[ -n "$lsp_info" ] && output="${output}${SEP}${lsp_info}"

printf '%b' "$output"
