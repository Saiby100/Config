#!/bin/sh
# The Claude-state dot after the session counter in status-left. Prints one
# styled character, or nothing at all; tmux expands the #[fg=...] tag that
# comes back from #().
#
#   yellow — some unattended session has Claude blocked on you
#   green  — some unattended session has Claude finished its turn
#   (none) — nothing waiting anywhere you aren't already looking
#
# Yellow wins when both are live: a permission prompt is holding work up, a
# finished turn is not.
#
# Sessions with a client attached are skipped. You are looking at those, and
# window-status-format already draws a per-window dot inside them — the point
# of this one is strictly the sessions the status bar cannot show you. It also
# means no separate clearing hook is needed for the session you are in: it is
# attached, so it never counts.
#
# A #() helper rather than a #{?...} conditional in status-left because tmux's
# format language cannot iterate over sessions. Filtering on session_attached
# rather than taking the current session name as an argument keeps this
# independent of format expansion inside #(), and stays correct with more than
# one client attached to different sessions.

# display-popup/#() run with the tmux *server's* PATH, which is whatever the
# first client happened to have. Homebrew's bin is the one that goes missing on a
# server started from a bare env — same guard as tree.sh.
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
# exactly as it was, so the separator cannot live in status-left.
#
# Newline-terminated: tmux reads a #() job's output a line at a time.
printf ' #[fg=%s]%s\n' "$(tmux show-options -gv "$opt")" "$DOT"
