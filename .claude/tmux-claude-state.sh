#!/bin/sh
# Mirror Claude Code's attention state into the tmux status bar.
#
# Wired to three hooks in ~/.claude/settings.json:
#   Notification      -> waiting   (Claude wants input: a permission prompt, or idle)
#   Stop              -> done      (Claude finished its turn)
#   UserPromptSubmit  -> clear     (you just replied, so it's your turn no longer)
#
# The state is stored as a *window* option so .tmux.conf can render a coloured
# dot next to that window in the status bar. The point is cross-window: run
# Claude in window 3, work in window 1, and the bar tells you which window is
# blocked on you instead of you cycling through them to check.
#
# Only inactive windows draw the dot (see window-status-format), and
# after-select-window clears the state — an indicator for the window you are
# already looking at carries no information.

# Hooks receive JSON on stdin. We don't need it, but drain it so Claude never
# blocks writing to a pipe nobody reads.
cat >/dev/null 2>&1

# Claude runs outside tmux plenty (plain terminal, CI, an editor's terminal).
# TMUX_PANE is set per-pane by tmux and inherited by anything started in it.
[ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] || exit 0

if [ "$1" = "clear" ]; then
  tmux set-option -uw -t "$TMUX_PANE" @claude_state 2>/dev/null
else
  tmux set-option -w -t "$TMUX_PANE" @claude_state "$1" 2>/dev/null
fi

# Redraw now rather than waiting up to status-interval seconds.
tmux refresh-client -S 2>/dev/null

# Never fail: a non-zero exit from a hook is surfaced to Claude as an error.
exit 0
