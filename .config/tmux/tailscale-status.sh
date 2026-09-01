#!/bin/sh
# The Tailscale glyph in status-right. Prints one styled character; tmux
# expands the #[fg=...] tag that comes back from #().
#
# Three states, because "not connected" has two very different causes:
#   green  — mesh is up
#   grey   — tailscaled is alive but the VPN is down (`ts off`, or logged out)
#   red    — tailscaled itself is unreachable, so `ts on` won't help

# #() runs with the tmux *server's* PATH, which is whatever the first client
# happened to have; Homebrew's bin is the one that goes missing.
case ":$PATH:" in
  *:/opt/homebrew/bin:*) ;;
  *) PATH="/opt/homebrew/bin:$PATH" ;;
esac
export PATH

GLYPH="󰖂"   # nf-md-vpn (U+F0582) — deliberately not the ● used for Claude state

# --peers=false keeps this to a local query of the daemon (~20ms), well inside
# the 5s status-interval. A failed probe is the red case, not an empty string.
state=$(tailscale status --peers=false --json 2>/dev/null \
        | sed -n 's/.*"BackendState": *"\([^"]*\)".*/\1/p' | head -1)

case "$state" in
  Running) opt=@green ;;
  "")      opt=@red   ;;   # daemon not running / not installed
  *)       opt=@muted ;;   # Stopped, NeedsLogin, NoState, Starting
esac

# Newline-terminated: tmux reads a #() job's output a line at a time.
printf '#[fg=%s]%s\n' "$(tmux show-options -gv "$opt")" "$GLYPH"
