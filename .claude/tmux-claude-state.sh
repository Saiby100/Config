#!/bin/sh
# Mirror Claude Code's attention state into the tmux status bar and session tree.
#
# Wired to three hooks in ~/.claude/settings.json:
#   Notification      -> waiting   (Claude wants input: a permission prompt, or idle)
#   Stop              -> done      (Claude finished its turn)
#   UserPromptSubmit  -> clear     (you just replied, so it's your turn no longer)
#
# The state is recorded at three scopes at once, because three different
# surfaces need to answer three different questions:
#
#   @claude_pane_state     pane     which *pane* finished (tree.sh pane rows)
#   @claude_state          window   which *window* finished (window-status-format,
#                                   and tree.sh window rows)
#   @claude_session_state  session  which *session* finished (the dot after the
#                                   session counter in status-left, and tree.sh
#                                   session rows)
#
# The names differ rather than one name being set three times because pane
# options fall back to window options, and window options to session options.
# Sharing a name would make a pane with no state of its own read its window's
# "done", so every sibling pane would look finished.
#
# Each scope is cleared when you actually look at it -- see the after-select-pane,
# after-select-window and client-session-changed hooks in .tmux.conf. An
# indicator for something you are already looking at carries no information.

# Hooks receive JSON on stdin. We don't need it, but drain it so Claude never
# blocks writing to a pipe nobody reads.
cat >/dev/null 2>&1

# Claude runs outside tmux plenty (plain terminal, CI, an editor's terminal).
# TMUX_PANE is set per-pane by tmux and inherited by anything started in it.
[ -n "$TMUX" ] && [ -n "$TMUX_PANE" ] || exit 0

# -p, -w and no flag are the pane, window and session tables; -t resolves the
# window and session from the pane in every case.
if [ "$1" = "clear" ]; then
  tmux set-option -up -t "$TMUX_PANE" @claude_pane_state 2>/dev/null
  tmux set-option -uw -t "$TMUX_PANE" @claude_state 2>/dev/null
  tmux set-option -u  -t "$TMUX_PANE" @claude_session_state 2>/dev/null
else
  tmux set-option -p -t "$TMUX_PANE" @claude_pane_state "$1" 2>/dev/null
  tmux set-option -w -t "$TMUX_PANE" @claude_state "$1" 2>/dev/null
  tmux set-option    -t "$TMUX_PANE" @claude_session_state "$1" 2>/dev/null
fi

# Redraw now rather than waiting up to status-interval seconds.
tmux refresh-client -S 2>/dev/null

# Never fail: a non-zero exit from a hook is surfaced to Claude as an error.
exit 0
