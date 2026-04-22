#!/usr/bin/env bash
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
model=$(echo "$input" | jq -r '.model.display_name')

# Get git branch, skipping optional locks
git_branch=$(git --git-dir="$cwd/.git" --work-tree="$cwd" branch --show-current 2>/dev/null)

if [ -n "$git_branch" ]; then
  printf "%s  |  %s  |  %s" "$cwd" "$model" "$git_branch"
else
  printf "%s  |  %s" "$cwd" "$model"
fi
