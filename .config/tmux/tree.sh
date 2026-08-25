#!/bin/sh
# One fzf popup replacing choose-tree entirely (prefix + w).
#
#   tree.sh              (prefix + w)  browse everything, enter jumps
#   tree.sh grab         (prefix + g)  same list, enter pulls a pane to me
#   tree.sh send         (prefix + G)  same list, enter pushes my pane there
#
# Every session, window and pane in the server is one row of a tree, and fzf
# matches incrementally across the whole row — session name, window name, pane
# title and path at once. choose-tree can draw the same hierarchy but cannot
# match into it, so finding a pane meant scrolling; and create/rename/kill each
# needed a separate binding and a separate prompt. Here they are hotkeys on the
# row already under the cursor.
#
# The script re-enters itself: fzf's reload/execute/preview bindings all call
# "$0" with a mode argument. Modes are `list`, `act <verb> <key>` and
# `preview <key>`; no argument (or jump/grab/send) is the interactive entry.

# display-popup runs a non-login sh whose PATH comes from the tmux *server's*
# environment, which is whatever the first client happened to have. Homebrew's
# bin is the one that goes missing on a server started from a bare env.
case ":$PATH:" in
  *:/opt/homebrew/bin:*) ;;
  *) PATH="/opt/homebrew/bin:$PATH" ;;
esac
export PATH

# display-popup -E tears the popup down the instant the command exits, so any
# failure that just prints and returns is invisible — it reads as the popup
# flashing open and closing. Every abnormal exit goes through die() to hold the
# window open long enough to read the reason.
die() {
  printf '%s\n\n' "$*"
  printf 'Press enter to close.'
  read -r _
  exit 1
}

# Set TMUX_TREE_DEBUG=1 in the tmux server environment to trace a run:
#   tmux setenv -g TMUX_TREE_DEBUG 1
# The trace lands in the log below and survives the popup closing.
if [ "${TMUX_TREE_DEBUG:-0}" = "1" ]; then
  exec 2>>"${TMPDIR:-/tmp}/tmux-tree.log"
  echo "--- $(date '+%F %T') pid=$$ argv=$* ---" >&2
  set -x
fi

# fzf's reload/execute/preview bindings all re-run this script, so the path has
# to survive being handed to a child with a different cwd. The tmux bindings
# already pass an absolute path; this only covers running it by hand.
SELF=$0
case $SELF in
  /*) ;;
  *)  SELF=$(cd "$(dirname "$SELF")" && pwd)/$(basename "$SELF") ;;
esac
TAB=$(printf '\t')
FOLD_FILE="${TMPDIR:-/tmp}/tmux-tree-folds"

# --- Palette ---------------------------------------------------------------
# fzf does not expand tmux formats, so the onedark user options from
# .tmux.conf are read once and turned into truecolor SGR sequences by hand.
# One source of truth is worth the hex parsing.
#
# Fetched in a single display-message and parsed with expansions only. The
# obvious version — show-options per colour, cut(1) per hex pair — cost five
# server round-trips and a dozen forks before the list was even built, on a
# script that reruns on every keystroke of a search.
sgr() {
  h=${1#\#}
  [ ${#h} -eq 6 ] || return 0
  r=${h%????} gb=${h#??}
  printf '\033[38;2;%d;%d;%dm' "$((0x$r))" "$((0x${gb%??}))" "$((0x${gb#??}))"
}

# Computed once and exported, so the reload and preview children the popup
# spawns on every keystroke inherit them instead of paying for the round-trip
# again.
if [ -z "${C_OFF:-}" ]; then
  IFS="$TAB" read -r _blue _fg _muted _green _yellow <<EOF
$(tmux display-message -p "#{@blue}${TAB}#{@fg}${TAB}#{@muted}${TAB}#{@green}${TAB}#{@yellow}")
EOF
  C_OFF=$(printf '\033[0m')
  C_BOLD=$(printf '\033[1m')
  C_BLUE=$(sgr "$_blue")
  C_FG=$(sgr "$_fg")
  C_MUTED=$(sgr "$_muted")
  C_GREEN=$(sgr "$_green")
  C_YELLOW=$(sgr "$_yellow")
  export C_OFF C_BOLD C_BLUE C_FG C_MUTED C_GREEN C_YELLOW
fi

# --- Row formats -----------------------------------------------------------
# One `list-panes -a` produces the whole tree. Sessions and windows do not
# need listings of their own: every window holds at least one pane and every
# session at least one window, so each pane line already carries its
# ancestors, and awk emits a session or window row the first time it sees a
# new one. That turns three server round-trips into one.
#
# Padding is tmux's own #{pN:...} (pad) and #{=N:...} (clip) rather than
# printf or column(1): both are display-width aware, so the box-drawing
# prefixes and any wide characters in a title stay in their columns. The
# widths differ per depth so the meta column lines up under the deeper prefix.
#
# pane_title defaults to the hostname, so a pane where nothing set a title
# would show the machine name on every row; that case falls back to the
# running command, the same suppression pane-border-format uses in .tmux.conf.
# Claude Code keeps pane_title set to what the session is about ("Obsidian
# vault organization"), which identifies a pane far better than the window
# name or the command (Claude reports a version string, not "claude").
ROW_FMT="#{session_name}${TAB}#{session_windows}${TAB}#{p46:#{=45:#{session_name}}}${TAB}#{session_windows} window#{?#{==:#{session_windows},1},,s}\
${TAB}#{window_index}${TAB}#{window_panes}${TAB}#{p45:#{=44:#{window_index}: #{window_name}}}${TAB}#{window_panes} pane#{?#{==:#{window_panes},1},,s}\
${TAB}#{pane_id}${TAB}#{p42:#{=41:#{?#{==:#{pane_title},#{host}},#{pane_current_command},#{pane_title}}}}${TAB}#{s|^$HOME|~|:pane_current_path}"

# --- Building the list -----------------------------------------------------
# A fold hides rows, and a hidden row cannot be fuzzy-matched — which would
# make "search for a pane anywhere" and "start with the other sessions
# collapsed" mutually exclusive. So folds only apply while the query is empty:
# the moment you type, the whole tree is in the list, and clearing the query
# folds it back up.
#
# Rows come out as key TAB coloured-display, and fzf is given --with-nth=2..
# so the key is hidden and, more importantly, never matched against —
# searching for "p" should not hit every pane row.
#
# Last children get the elbow so each trunk actually ends; the counts come
# from session_windows and window_panes rather than a lookahead. Every
# connector is three display cells wide, which is what keeps the column
# padding tmux already did in the format string honest.
TREE_AWK='
function emit(key, prefix, colour, label, meta,   c) {
  c = (key == srcpane) ? ccur : colour
  printf "%s\t%s%s%s%s%s%s%s%s\n", key, cmuted, prefix, c, label, coff, cmuted, meta, coff
}
BEGIN {
  FS = "\t"
  while ((getline line < foldfile) > 0) fold[line] = 1
  down = "\342\226\276 "; right = "\342\226\270 "
  tee = "\342\224\234\342\224\200 "; elbow = "\342\224\224\342\224\200 "
  pipe = "\342\224\202  "; blank = "   "
}
{
  if ($1 != sess) {
    sess = $1; swins = $2 + 0; wseen = 0; win = ""
    skey = "s:" sess
    sshut = (!searching && (skey in fold))
    emit(skey, sshut ? right : down, csess, $3, $4)
  }
  if (sshut) next

  wkey = "w:" sess ":" $5
  if (wkey != win) {
    win = wkey; wpanes = $6 + 0; pseen = 0; wseen++
    wlast = (wseen == swins)
    emit(wkey, wlast ? elbow : tee, cwin, $7, $8)
    wshut = (!searching && (wkey in fold))
    trunk = wlast ? blank : pipe
  }
  if (wshut) next

  pseen++
  emit("p:" $9, trunk (pseen == wpanes ? elbow : tee), cwin, $10, $11)
}'

list() {
  tmux list-panes -a -F "$ROW_FMT" 2>/dev/null \
    | awk -v searching="$1" -v foldfile="$FOLD_FILE" -v srcpane="p:$SRC_PANE" \
          -v csess="$C_BLUE$C_BOLD" -v cwin="$C_FG" -v cmuted="$C_MUTED" \
          -v ccur="$C_GREEN" -v coff="$C_OFF" "$TREE_AWK"
}

# --- Targets ---------------------------------------------------------------
# A tmux target string for any key. A session or window key resolves to its
# active pane, which is what makes preview and grab work on a collapsed row
# without the cursor having to reach a pane.
target() {
  case $1 in
    p:*) printf '%s' "${1#p:}" ;;
    w:*) printf '%s' "${1#w:}" ;;
    s:*) printf '%s:' "${1#s:}" ;;
  esac
}

# The new thing opens where the row it was created from is, which is almost
# always the intent. Resolved with display-message rather than passing
# -c "#{pane_current_path}" straight to tmux: that format would be expanded
# against whatever tmux considers current, not against the chosen row.
cwd_of() { tmux display-message -p -t "$1" '#{pane_current_path}'; }

ask() {
  printf '%s' "$1" >&2
  read -r REPLY_ || return 1
  [ -n "$REPLY_" ]
}

# --- Mutations -------------------------------------------------------------
# Run from fzf execute() bindings, which hand the child the terminal, so a
# read -r prompt draws over the list and hands control back on enter. Each is
# followed by reload($SELF list) in the binding, so the tree redraws in place
# and the popup never closes for a create, rename, kill or fold.
act() {
  verb=$1 key=$2 pos=$3
  [ -n "$key" ] || exit 0
  tgt=$(target "$key")
  save_pos "$key" "${pos:-0}" "$verb"

  case $verb in
    fold|collapse|expand)
      # h on a pane closes the window holding it, the way h on a file closes
      # its directory in a file tree — otherwise the key is a dead end on a
      # third of the rows. Panes have nothing of their own to fold.
      case $key in
        p:*) [ "$verb" = collapse ] || exit 0
             key="w:$(tmux display-message -p -t "$tgt" '#{session_name}:#{window_index}')" ;;
      esac
      touch "$FOLD_FILE"
      if grep -qxF "$key" "$FOLD_FILE"; then
        [ "$verb" = collapse ] && exit 0
        grep -vxF "$key" "$FOLD_FILE" > "$FOLD_FILE.tmp" && mv "$FOLD_FILE.tmp" "$FOLD_FILE"
      else
        [ "$verb" = expand ] && exit 0
        printf '%s\n' "$key" >> "$FOLD_FILE"
      fi
      ;;
    new)
      # What "new" means is read off the cursor: a sibling of whatever it sits
      # on. Sessions and windows are prompted for a name — an unnamed one is
      # exactly the one you forget is open, the same reasoning as bind c/C in
      # .tmux.conf. Panes have no name to ask for.
      case $key in
        s:*) ask "New session name: " &&
             tmux new-session -d -s "$REPLY_" -c "$(cwd_of "$tgt")" ;;
        # -a inserts after the window under the cursor; without it a bare
        # index that is already taken is an error rather than a sibling.
        w:*) ask "New window name: " &&
             tmux new-window -d -a -n "$REPLY_" -t "$tgt" -c "$(cwd_of "$tgt")" ;;
        p:*) tmux split-window -h -d -t "$tgt" -c "$(cwd_of "$tgt")" ;;
      esac
      ;;
    rename)
      case $key in
        s:*) ask "Rename session to: " && tmux rename-session -t "$tgt" "$REPLY_" ;;
        w:*) ask "Rename window to: " && {
               tmux rename-window -t "$tgt" "$REPLY_"
               # automatic-rename is on globally in .tmux.conf, so a hand-typed
               # name would be overwritten by the directory basename on the next
               # cd. tmux does turn it off itself on rename-window, but saying so
               # explicitly costs nothing and does not depend on that staying true.
               tmux set-window-option -t "$tgt" automatic-rename off
             } ;;
        p:*) ask "Pane title: " && tmux select-pane -t "$tgt" -T "$REPLY_" ;;
      esac
      ;;
    kill)
      # Only sessions confirm. A session takes every window and pane with it,
      # and a mistyped fuzzy match is a real way to lose one; a pane or window
      # is cheap enough that a y/n on every kill would defeat the point of
      # having the key here at all.
      case $key in
        s:*) printf "kill session '%s'? (y/n) " "${key#s:}" >&2
             read -r yn
             case $yn in y|Y) tmux kill-session -t "$tgt" ;; esac ;;
        w:*) tmux kill-window -t "$tgt" ;;
        p:*) tmux kill-pane -t "$tgt" ;;
      esac
      ;;
  esac
}

# A reload drops the cursor at the top of the list, which after folding a row
# or renaming one means losing your place. fzf ships --track --id-nth for
# exactly this and it worked, but it is unusable here: tracking blocks query
# input while it re-finds the row after each reload, and this list reloads on
# every keystroke of a search, so fast typing lost characters — "test" arrived
# as "tt". So the cursor is placed by hand instead.
#
# Each action works out where the cursor should end up and leaves the answer
# in a file for a transform after the reload to read back as a pos() action.
# The handoff is a file rather than the obvious transform argument because fzf
# expands {1} and {n} separately for each action in a chain, at the moment
# that action runs: by the time a trailing transform fires the reload has
# already happened, and both describe the row the cursor accidentally landed
# on. Only the first action in the chain still sees the row you acted on.
POS_FILE="${TMPDIR:-/tmp}/tmux-tree-pos"

# Always writes: an empty transform leaves the cursor wherever the reload put
# it, which is the top. Most actions leave the row where it was, so the answer
# is usually just where the cursor already is — $2 is its zero-based index, so
# +1 makes it the 1-based position fzf's pos() wants. The exception is h on a
# pane, which closes the window above it: that pane sits exactly pane_index
# rows below its window row, panes being listed in index order.
save_pos() {
  _off=0
  case $3:$1 in
    collapse:p:*) _off=$(tmux display-message -p -t "${1#p:}" '#{pane_index}' 2>/dev/null) || _off=0 ;;
  esac
  printf 'pos(%d)' "$(($2 + 1 - _off))" > "$POS_FILE"
}

case ${1:-} in
  list)    list "$2"; exit 0 ;;
  after-act) cat "$POS_FILE" 2>/dev/null; rm -f "$POS_FILE"; exit 0 ;;
  act)     act "$2" "$3" "$4"; exit 0 ;;
  preview) tmux capture-pane -ep -t "$(target "$2")" 2>/dev/null; exit 0 ;;
esac

# --- Interactive -----------------------------------------------------------
command -v fzf >/dev/null 2>&1 || die "fzf not found on PATH.

  brew install fzf

PATH was:
$PATH"

mode=${1:-jump}

# Resolved here rather than passed in from the binding, because display-popup
# does NOT format-expand its shell-command — passing '#{pane_id}' handed the
# script the literal placeholder. Asking tmux from inside the popup works: the
# popup belongs to the client, so these resolve against the client's active
# pane, not against the popup itself. Exported so the reload/execute children
# see the same answers.
SRC_PANE=$(tmux display-message -p '#{pane_id}')
SRC_WINDOW=$(tmux display-message -p '#{session_name}:#{window_index}')
SRC_SESSION=$(tmux display-message -p '#{session_name}')
export SRC_PANE SRC_WINDOW SRC_SESSION
[ -n "$SRC_PANE" ] || die "could not determine the current tmux pane."

# Folds are reseeded on every open rather than persisted: the current session
# expanded and the rest collapsed is the useful default every time, and a fold
# you set is only ever meant to last as long as the popup is up.
tmux list-sessions -F 's:#{session_name}' 2>/dev/null \
  | grep -vxF "s:$SRC_SESSION" > "$FOLD_FILE"
rm -f "$POS_FILE"

case $mode in
  send) prompt="send $SRC_PANE to > " ;;
  grab) prompt="grab into $SRC_WINDOW > " ;;
  *)    prompt="$SRC_SESSION > " ;;
esac

# --- Modal editing ---------------------------------------------------------
# fzf has no modes, but it has unbind() and rebind(), and that is enough to
# build one: every normal-mode key is declared as a binding, i/a// unbind the
# lot so they type like ordinary characters again (insert mode), and esc
# rebinds them (normal mode).
#
# The popup opens in normal mode — bindings live, no `start:unbind` — because
# the first thing you do here is almost always move to a row you can already
# see, and reaching a visible row should not cost a mode switch. Searching is
# the fallback for when it is not on screen, and that is what i and / are for.
#
# Only rebind() can turn a binding back on, and only for a key that was
# declared at startup — which is why the dead keys below have to be declared
# rather than simply left out.
#
# The dead keys are the point of having modes at all. Without them a stray `w`
# in normal mode would silently land in the query and start filtering, so the
# mode would only be as real as your memory of which letters do something.
# Bound to ignore, normal mode is inert except where it is not.
VIM_NAV='j,k,g,G,d,u'
VIM_MODE='i,a,/,q'
VIM_ACT='h,l,n,r,x,p'

dead_keys=''
dead_binds=''
for k in b c e f m o s t v w y z space \
         A B C D E F H I J K L M N O P Q R S T U V W X Y Z \
         0 1 2 3 4 5 6 7 8 9; do
  dead_keys="$dead_keys,$k"
  dead_binds="$dead_binds,$k:ignore"
done
MODAL_KEYS="$VIM_NAV,$VIM_MODE,$VIM_ACT${dead_keys}"
dead_binds=${dead_binds#,}

# The prompt is the mode indicator, and it is yellow in normal mode for the
# same reason the status bar turns yellow while the prefix is pending: yellow
# here means "the next key does something other than what it says". Since the
# popup starts in normal mode, that is also the prompt it opens with.
P_INSERT="$prompt"
P_NORMAL="$C_YELLOW$prompt"

# ctrl-based keys work in both modes, so nothing has to be remembered twice —
# normal mode adds unshifted aliases for the ones that stay in the popup (with
# h/l for fold in place of ^space, since a tree wants a direction not a
# toggle: h always closes, l always opens, whatever the row is doing now), and
# leaves send and grab on ^s/^g because both close the popup and fzf reports a
# closing key through --expect, which is not a binding and so cannot be
# rebound per mode.
header='j/k move  h/l fold  g/G ends  d/u page  n new  r rename  x kill  p preview  q quit
i or / to search (esc back)   ^j ^k ^n ^r ^x ^space fold  ^s send  ^g grab   ↵ act'

out=$(list | fzf \
  --ansi \
  --no-sort \
  --layout=reverse \
  --delimiter="$TAB" \
  --with-nth=2.. \
  --prompt="$P_NORMAL" \
  --header="$header" \
  --header-first \
  --expect=enter,ctrl-s,ctrl-g \
  --bind='ctrl-j:down,ctrl-k:up' \
  --bind="esc:rebind($MODAL_KEYS)+change-prompt($P_NORMAL)" \
  --bind="i:unbind($MODAL_KEYS)+change-prompt($P_INSERT)" \
  --bind="a:unbind($MODAL_KEYS)+change-prompt($P_INSERT)" \
  --bind="/:unbind($MODAL_KEYS)+change-prompt($P_INSERT)" \
  --bind='j:down,k:up,g:first,G:last,d:half-page-down,u:half-page-up' \
  --bind='q:abort,p:toggle-preview' \
  --bind="$dead_binds" \
  --bind="n:execute('$SELF' act new {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="r:execute('$SELF' act rename {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="x:execute('$SELF' act kill {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="h:execute-silent('$SELF' act collapse {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="l:execute-silent('$SELF' act expand {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind='?:toggle-preview' \
  --bind="change:reload('$SELF' list {q})" \
  --bind='alt-j:preview-down,alt-k:preview-up' \
  --bind="ctrl-space:execute-silent('$SELF' act fold {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="ctrl-n:execute('$SELF' act new {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="ctrl-r:execute('$SELF' act rename {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="ctrl-x:execute('$SELF' act kill {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --preview="'$SELF' preview {1}" \
  --preview-window=right,45%)
rc=$?

# 0 chose something, 1 is "no match", 130 is Esc/Ctrl-C. Those three are the
# user deciding, so close quietly. Anything else is fzf itself failing and
# would otherwise be the flash-and-vanish case.
case "$rc" in
  0)      ;;
  1|130)  exit 0 ;;
  *)      die "fzf exited with status $rc." ;;
esac

pressed=$(printf '%s\n' "$out" | sed -n 1p)
key=$(printf '%s\n' "$out" | sed -n 2p | cut -d"$TAB" -f1)
[ -n "$key" ] || exit 0
tgt=$(target "$key")

# Enter means whichever job the popup was opened for; ctrl-s and ctrl-g reach
# the other two without reopening it.
case $pressed in
  ctrl-s) action=send ;;
  ctrl-g) action=grab ;;
  *)      action=$mode ;;
esac

case $action in
  send)
    # -s names the source explicitly. Without it join-pane silently prefers
    # the *marked* pane over the current one, and the status-bar drag bindings
    # in .tmux.conf traffic in marks — so a leftover mark would move the wrong
    # pane. -d is what makes this "send" rather than "move with": without it
    # tmux follows the pane into the target and you lose the window you were
    # working in, which is the whole point.
    dst=$(tmux display-message -p -t "$tgt" '#{session_name}:#{window_index}')
    [ "$dst" != "$SRC_WINDOW" ] || die "that pane is already in this window."
    tmux join-pane -dh -s "$SRC_PANE" -t "$dst" ;;
  grab)
    src=$(tmux display-message -p -t "$tgt" '#{pane_id}')
    [ "$src" != "$SRC_PANE" ] || die "that is the pane you are in."
    tmux join-pane -h -s "$src" -t "$SRC_PANE" ;;
  *)
    # select-window resolves a pane target to its containing window, and
    # select-pane unzooms that window on its own if it was zoomed on some
    # other pane — so the row you picked is always the one you land on and can
    # see. switch-client first, because the target may be another session.
    tmux switch-client -t "$(tmux display-message -p -t "$tgt" '#{session_name}')"
    tmux select-window -t "$tgt"
    case $key in p:*) tmux select-pane -t "$tgt" ;; esac ;;
esac
