#!/bin/sh
# The Claude-state dot after the session counter in status-left. Prints one
# styled character, or nothing at all; tmux expands the #[fg=...] tag.
#
#   yellow — some unattended session has Claude blocked on you
#   green  — some unattended session has Claude finished its turn
#
# Yellow wins when both are live: a permission prompt is holding work up, a
# finished turn is not. Sessions with a client attached are skipped —
# window-status-format already draws a per-window dot inside those.

# #() runs with the tmux *server's* PATH, which is whatever the first client
# happened to have; Homebrew's bin is the one that goes missing.
case ":$PATH:" in
  *:/opt/homebrew/bin:*) ;;
  *) PATH="/opt/homebrew/bin:$PATH" ;;
esac
export PATH

DOT="●"   # the same glyph window-status-format uses for per-window state

states=$(tmux list-sessions -F '#{session_attached} #{@claude_session_state}' 2>/dev/null \
         | awk '$1 == 0 { print $2 }')

case "$states" in
  *waiting*) opt=@yellow ;;
  *done*)    opt=@green  ;;
  *)         exit 0      ;;   # nothing to say, so add nothing to the cap
esac

# The leading space is ours: printing nothing at all above has to leave the cap
# exactly as it was, so the separator cannot live in status-left. Newline-
# terminated: tmux reads a #() job's output a line at a time.
printf ' #[fg=%s]%s\n' "$(tmux show-options -gv "$opt")" "$DOT"
