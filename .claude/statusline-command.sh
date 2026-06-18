#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Core fields
cwd_full=$(echo "$input" | jq -r '.workspace.current_dir')
cwd=$(echo "$cwd_full" | sed "s|^$HOME|~|")
model=$(echo "$input" | jq -r '.model.display_name')
transcript=$(echo "$input" | jq -r '.transcript_path // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
vim_mode=$(echo "$input" | jq -r '.vim.mode // empty')

# Git branch
git_branch=""
if cd "$cwd_full" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
  export GIT_OPTIONAL_LOCKS=0
  git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
fi

# --- Context indicator (from latest assistant usage) -----------------------
ctx_seg=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  ctx_tokens=$(grep '"usage"' "$transcript" 2>/dev/null | tail -1 | \
    jq -r '(.message.usage // .usage) | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0))' 2>/dev/null)
  if [ -n "$ctx_tokens" ] && [ "$ctx_tokens" -gt 0 ] 2>/dev/null; then
    window=200000
    pct=$(( ctx_tokens * 100 / window ))
    [ "$pct" -gt 100 ] && pct=100
    # color by fill level (OneDark Pro: green -> yellow -> red)
    if   [ "$pct" -lt 50 ]; then ccol="152;195;121"   # green  #98c379
    elif [ "$pct" -lt 80 ]; then ccol="229;192;123"   # yellow #e5c07b
    else                         ccol="224;108;117"   # red    #e06c75
    fi
    # 10-cell bar
    filled=$(( pct / 10 ))
    bar=""
    for i in $(seq 1 10); do
      if [ "$i" -le "$filled" ]; then bar="${bar}█"; else bar="${bar}░"; fi
    done
    ktok=$(( ctx_tokens / 1000 ))
    ctx_seg="\033[38;2;${ccol}m${bar} ${pct}% (${ktok}k)\033[0m"
  fi
fi

# --- Usage / cost indicator ------------------------------------------------
usage_seg=""
if [ -n "$cost" ] && [ "$cost" != "0" ] && [ "$cost" != "null" ]; then
  usd=$(LC_ALL=C awk -v c="$cost" 'BEGIN{printf "%.2f", c}')
  usage_seg="\033[38;2;198;120;221m\$${usd}\033[0m"   # purple #c678dd
fi

# --- Vim mode indicator ----------------------------------------------------
vim_seg=""
if [ -n "$vim_mode" ]; then
  if [ "$vim_mode" = "NORMAL" ]; then
    # inverted blue badge #61afef
    vim_seg="\033[48;2;97;175;239;38;2;40;44;52;1m NORMAL \033[0m"
  else
    # inverted green badge #98c379
    vim_seg="\033[48;2;152;195;121;38;2;40;44;52;1m INSERT \033[0m"
  fi
fi

# --- Assemble --------------------------------------------------------------
# OneDark Pro palette (24-bit, matches tmux-onedark-theme)
sep=" \033[38;2;92;99;112m|\033[0m "                  # comment-grey #5c6370
out=""
[ -n "$vim_seg" ] && out="${vim_seg} "
out="${out}\033[38;2;97;175;239m${cwd}\033[0m"        # blue  #61afef
[ -n "$git_branch" ] && out="${out}${sep}\033[38;2;152;195;121m${git_branch}\033[0m"  # green #98c379
out="${out}${sep}\033[38;2;86;182;194m${model}\033[0m"  # cyan  #56b6c2
[ -n "$ctx_seg" ]   && out="${out}${sep}${ctx_seg}"
[ -n "$usage_seg" ] && out="${out}${sep}${usage_seg}"

printf "%b" "$out"
