#!/bin/sh
# CPU and memory load for status-right, as one styled string:
#   󰘙 12%  󰍛 43%
#
# Labelled with nf-md glyphs (chip / memory chip) rather than the words CPU and
# MEM: the status bar already spells out the session name, the window names and
# the clock, and two more three-letter words in caps read as another name rather
# than a gauge. Same family as the zoom and VPN glyphs already in this bar.
#
# Both numbers are read cheaply enough to run every status-interval (5s).
# `top -l 1` is the obvious source for CPU on macOS but samples for about a
# second before printing, which would stall every status redraw; ps reports the
# kernel's own decaying per-process average and returns immediately, so the
# figure is summed here and divided by the core count instead.
#
# Memory mirrors what Activity Monitor calls "Memory Used": active + wired +
# compressed pages. Free/inactive pages are excluded — macOS keeps inactive
# pages populated as cache and counting them reads as permanently full.
#
# White at rest rather than the @muted grey the rest of the bar idles in: these
# are the only two numbers up there that change on their own, and a muted glyph
# against @bg was hard to pick out at a glance.
#
# Colours come back out of tmux so the palette at the top of .tmux.conf stays
# the single source of truth, and the branching happens here to keep this to one
# #() invocation per redraw.

case ":$PATH:" in
  *:/opt/homebrew/bin:*) ;;
  *) PATH="/opt/homebrew/bin:$PATH" ;;
esac
export PATH

ncpu=$(sysctl -n hw.ncpu 2>/dev/null || echo 1)
cpu=$(ps -A -o %cpu= 2>/dev/null | awk -v n="$ncpu" '{s+=$1} END {printf "%d", (n>0 ? s/n : s)}')
[ -n "$cpu" ] || cpu=0
[ "$cpu" -gt 100 ] && cpu=100

mem=$(vm_stat 2>/dev/null | awk '
  /page size of/       { for (i=1;i<=NF;i++) if ($i+0>1024) ps=$i }
  /Pages active/       { active=$3 }
  /Pages wired down/   { wired=$4 }
  /Pages free/         { free=$3 }
  /Pages inactive/     { inactive=$3 }
  /Pages speculative/  { spec=$3 }
  /Pages occupied by compressor/ { comp=$5 }
  END {
    gsub(/\./,"",active); gsub(/\./,"",wired); gsub(/\./,"",free)
    gsub(/\./,"",inactive); gsub(/\./,"",spec); gsub(/\./,"",comp)
    total = active + wired + free + inactive + spec + comp
    if (total > 0) printf "%d", (active + wired + comp) * 100 / total
  }')
[ -n "$mem" ] || mem=0

# One show-options call per name — -gv takes a single option.
white=$(tmux show-options -gv @white)
yellow=$(tmux show-options -gv @yellow)
red=$(tmux show-options -gv @red)

colour() {
  if   [ "$1" -ge 90 ]; then echo "$red"
  elif [ "$1" -ge 70 ]; then echo "$yellow"
  else echo "$white"
  fi
}

# Newline-terminated: tmux reads a #() job's output a line at a time.
printf '#[fg=%s] %d%%#[fg=%s]  #[fg=%s] %d%%\n' \
  "$(colour "$cpu")" "$cpu" "$white" "$(colour "$mem")" "$mem"
