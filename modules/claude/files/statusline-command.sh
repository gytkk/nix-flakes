#!/usr/bin/env bash
# Claude Code status line script

input=$(cat)

# Extract fields from JSON input
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // "?"')
model=$(echo "$input" | jq -r '.model.display_name // "?"')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Shorten home directory to ~
home="$HOME"
short_cwd="${cwd/#$home/\~}"

# Git branch
git_branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree > /dev/null 2>&1; then
  git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Context usage indicator
context_info=""
if [ -n "$remaining" ]; then
  remaining_int=${remaining%.*}
  context_info="ctx:${remaining_int}%"
fi

# Compose status line (plain text, no ANSI colors)
output="$short_cwd"
[ -n "$git_branch" ] && output="$output | $git_branch"
output="$output | $model"
[ -n "$context_info" ] && output="$output | $context_info"

printf '%s' "$output"
