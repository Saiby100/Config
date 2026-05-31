#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Get current working directory and model from JSON
cwd_full=$(echo "$input" | jq -r '.workspace.current_dir')
cwd=$(echo "$cwd_full" | sed "s|^$HOME|~|")
model=$(echo "$input" | jq -r '.model.display_name')

# Get git branch if in a git repo
git_branch=""
if cd "$cwd_full" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
  # Skip optional locks for git commands
  export GIT_OPTIONAL_LOCKS=0
  git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# Color scheme: 218 (salmon/pink), 123 (cyan), 33 (blue)
# Single line: directory | branch | model
if [ -n "$git_branch" ]; then
  printf "\033[38;5;218m%s\033[0m | \033[38;5;123m%s\033[0m | \033[38;5;33m%s\033[0m" "$cwd" "$git_branch" "$model"
else
  printf "\033[38;5;218m%s\033[0m | \033[38;5;33m%s\033[0m" "$cwd" "$model"
fi
