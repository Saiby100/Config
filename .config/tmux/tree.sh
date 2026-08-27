#!/bin/sh
# One fzf popup replacing choose-tree entirely (prefix + w).
#
# Every session, window and pane in the server is one row of a tree, and fzf
# matches incrementally across the whole row — session name, window name, pane
# title and path at once. choose-tree can draw the same hierarchy but cannot
# match into it, so finding a pane meant scrolling; and create/rename/kill each
# needed a separate binding and a separate prompt. Here they are hotkeys on the
# row already under the cursor.
#
# Enter jumps to the row under the cursor. Moving things around is a mark and a
# destination instead: m marks rows, M moves everything marked into the row the
# cursor is on. That replaced the old `grab` and `send` modes (prefix + g and
# prefix + G), which were the same list opened twice with a different verb on
# enter and could only ever move one pane, always relative to the pane you
# happened to be sitting in. Marks name both ends explicitly, so the popup no
# longer needs a mode at all.
#
# The script re-enters itself: fzf's reload/execute/preview bindings all call
# "$0" with a mode argument. Modes are `list`, `act <verb> <key>` and
# `preview <key>`; no argument is the interactive entry.

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
MARK_FILE="${TMPDIR:-/tmp}/tmux-tree-marks"

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
#
# Fields 12 and 13 are the ancestry column, drawn only while searching (see
# emit below). A search filters the tree down to the matching rows, and a pane
# row on its own says nothing about which session or window it came out of —
# the connector to its parent is still drawn, but the parent itself has been
# filtered away. So each row also carries the names of its ancestors, ready to
# print when there is no tree left to read them off.
#
# The last three are Claude Code's state, written by ~/.claude/tmux-claude-state.sh
# at pane, window and session scope under three separate names. Every field here
# is evaluated in pane context, so a pane carries its own state *and* its
# window's and session's — which is what lets a folded session or window row
# still show that something inside it finished. The scopes are named separately
# precisely so this works: were they one name, tmux's pane → window → session
# option fallback would hand every pane its window's state as its own.
ROW_FMT="#{session_name}${TAB}#{session_windows}${TAB}#{p46:#{=45:#{session_name}}}${TAB}#{session_windows} window#{?#{==:#{session_windows},1},,s}\
${TAB}#{window_index}${TAB}#{window_panes}${TAB}#{p45:#{=44:#{window_name}}}${TAB}#{window_panes} pane#{?#{==:#{window_panes},1},,s}\
${TAB}#{pane_id}${TAB}#{p42:#{=41:#{?#{==:#{pane_title},#{host}},#{pane_current_command},#{pane_title}}}}${TAB}#{s|^$HOME|~|:pane_current_path}\
${TAB}#{p28:#{=27:#{session_name}}}${TAB}#{p28:#{=27:#{session_name} › #{window_index}: #{window_name}}}\
${TAB}#{@claude_pane_state}${TAB}#{@claude_state}${TAB}#{@claude_session_state}"

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
#
# Every row is numbered, and `:N` moves the cursor to row N. The number is the
# row's position in the list, not any tmux index: a window index only addresses
# a window inside its own session, so it cannot name the row you are looking at
# here — which is why the window label no longer carries one. Being a position
# also means the numbers renumber as folds open and close, which is the point,
# since what you type is always what you can see.
#
# They are drawn only while the query is empty, the same rule as folds and for
# the same reason: fzf filters the list after awk has numbered it, so under a
# search the numbers on screen would no longer be the positions they name.
#
# Four fixed-width columns sit in front of every label: a four-cell number
# gutter, a two-cell mark gutter, a two-cell Claude-state gutter and a two-cell
# type icon. All four are the same width on every row whatever it holds, so the
# label padding tmux already did in ROW_FMT still lines the meta column up; only
# a *varying* width would have to be paid for there.
#
# The state gutter is the same ● the tmux status bar draws, yellow for waiting
# and green for done, and it sits on session and window rows as well as panes.
# That is the whole point of it: the status bar can only tell you that *some
# other* session has Claude waiting, and this is where you find out which pane —
# including when the session or window holding it is folded shut.
#
# The icon is what tells a window row from a pane row. They were both plain fg
# text before, distinguishable only by how deep the connector ran, which is one
# glyph of difference three columns to the left of where you are reading. The
# colours differ now too (windows bold), but the icon is the part that reads at
# a glance. Glyphs are Nerd Font — ghostty is set to JetBrainsMono Nerd Font,
# and tmux inherits it.
#
# The ancestry column sits between the label and the meta, not in front of the
# row: in front it would have to be part of the prefix, whose width is what the
# per-depth label padding above is compensating for, and a session name is not
# a fixed width. After the label, where every row is already flush, a column of
# tmux-padded ancestry keeps the meta flush too. It is blue rather than muted
# so it reads as the session/window rows it names rather than as more meta.
#
# fzf matches the display column, so the ancestry is matched as well — which is
# the other half of the fix: "mrm claude" finds the Claude pane in the MRM
# window even though neither the pane title nor its path says MRM.
TREE_AWK='
function emit(key, prefix, colour, icon, label, anc, meta, state,   c, g, n, d) {
  c = (key == srcpane) ? ccur : colour
  g = (key in mark) ? (cmark gmark " " coff) : "  "
  d = (state == "waiting") ? (cwait gstate " " coff) \
    : (state == "done")    ? (cdone gstate " " coff) : "  "
  n = searching ? "    " : sprintf("%3d ", ++nr)
  printf "%s\t%s\n", key,
         cmuted n coff g d cmuted prefix c icon label coff canc anc cmuted meta coff
}
BEGIN {
  FS = "\t"
  while ((getline line < foldfile) > 0) fold[line] = 1
  while ((getline line < markfile) > 0) mark[line] = 1
  down = "\342\226\276 "; right = "\342\226\270 "
  tee = "\342\224\234\342\224\200 "; elbow = "\342\224\224\342\224\200 "
  pipe = "\342\224\202  "; blank = "   "
  isess = "\357\210\263 "; iwin = "\357\213\220 "; ipane = "\357\204\240 "
  gmark = "\357\200\214"; gstate = "\342\227\217"
  # A session row has no ancestor to name, but still owes the column its width
  # while searching, or its meta would sit left of everything else there.
  noanc = sprintf("%28s", "")
}
{
  if ($1 != sess) {
    sess = $1; swins = $2 + 0; wseen = 0; win = ""
    skey = "s:" sess
    sshut = (!searching && (skey in fold))
    emit(skey, sshut ? right : down, csess, isess, $3, searching ? noanc : "", $4, $16)
  }
  if (sshut) next

  wkey = "w:" sess ":" $5
  if (wkey != win) {
    win = wkey; wpanes = $6 + 0; pseen = 0; wseen++
    wlast = (wseen == swins)
    emit(wkey, wlast ? elbow : tee, cwin, iwin, $7, searching ? $12 : "", $8, $15)
    wshut = (!searching && (wkey in fold))
    trunk = wlast ? blank : pipe
  }
  if (wshut) next

  pseen++
  emit("p:" $9, trunk (pseen == wpanes ? elbow : tee), cpane, ipane, $10,
       searching ? $13 : "", $11, $14)
}'

list() {
  tmux list-panes -a -F "$ROW_FMT" 2>/dev/null \
    | awk -v searching="$1" -v foldfile="$FOLD_FILE" -v markfile="$MARK_FILE" \
          -v srcpane="p:$SRC_PANE" \
          -v csess="$C_BLUE$C_BOLD" -v cwin="$C_FG$C_BOLD" -v cpane="$C_FG" \
          -v cmuted="$C_MUTED" -v ccur="$C_GREEN" -v cmark="$C_YELLOW" \
          -v cwait="$C_YELLOW" -v cdone="$C_GREEN" \
          -v canc="$C_BLUE" -v coff="$C_OFF" "$TREE_AWK"
}

# --- Targets ---------------------------------------------------------------
# A tmux target string for any key. A session or window key resolves to its
# active pane, which is what makes preview and M work on a collapsed row
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

pause() {
  printf '\n\nPress enter to continue.'
  read -r _
}

# --- Moving marked rows -----------------------------------------------------
# m marks a row; M drops everything marked into the row the cursor is on. That
# is the whole of what used to be `grab` and `send`: those could only move the
# one pane you were sitting in, to or from one place, and needed two bindings
# and two modes to say which direction. A mark names the source and the cursor
# names the destination, so one key covers both directions and any number of
# rows at once.
#
# A pane can live in any window, so it goes to the window holding the chosen
# row. A window has no such freedom — a window cannot sit inside another window
# — so a marked window takes the chosen row's *session* instead. That is what
# makes M on a pane row meaningful for a marked window rather than an error: it
# reads as "the session that pane is in".
#
# Rows already at their destination are skipped rather than refused, so a mixed
# bag of marks does as much as it can; only real failures are reported.
#
# join-pane names its source with -s. Without it tmux prefers the *marked*
# pane — tmux's own select-pane -m mark, which the status-bar drag bindings in
# .tmux.conf set — and a leftover one there would move a pane nobody chose. -d
# on both moves keeps focus where it is: the point of arranging from a list is
# that you are arranging, not following.
move_marked() {
  dst=$1
  if [ ! -s "$MARK_FILE" ]; then
    printf 'Nothing marked. Press m on a row first.'
    pause
    return
  fi

  # One lookup, not two: the session is the window target minus its index.
  # Trimming from the right rather than the left is what keeps a session name
  # containing a colon intact. The pattern test is the liveness check —
  # display-message exits 0 on a target that no longer exists and prints a
  # half-empty answer, so the exit status is no use here.
  dst_win=$(tmux display-message -p -t "$dst" '#{session_name}:#{window_index}' 2>/dev/null)
  case $dst_win in
    ?*:[0-9]*) dst_sess=${dst_win%:*} ;;
    *) printf 'That row is gone.'; pause; return ;;
  esac

  moved=0 errs=''
  while IFS= read -r mk; do
    case $mk in
      p:*)
        src=${mk#p:}
        here=$(tmux display-message -p -t "$src" '#{session_name}:#{window_index}' 2>/dev/null)
        [ -n "$here" ] || { errs="$errs
  $src is gone."; continue; }
        [ "$here" != "$dst_win" ] || continue
        if out=$(tmux join-pane -dh -s "$src" -t "$dst_win" 2>&1); then
          moved=$((moved + 1))
        else
          errs="$errs
  $src: $out"
        fi
        ;;
      w:*)
        # The key is w:<session>:<index>, so stripping "w:" leaves a target
        # window tmux takes as-is.
        src=${mk#w:}
        [ "${src%%:*}" != "$dst_sess" ] || continue
        # -t "<session>:" with no index is how tmux is asked for the next free
        # one; naming an index would collide with whatever already holds it.
        if out=$(tmux move-window -d -s "$src" -t "$dst_sess:" 2>&1); then
          moved=$((moved + 1))
        else
          errs="$errs
  $src: $out"
        fi
        ;;
    esac
  done < "$MARK_FILE"

  : > "$MARK_FILE"
  [ -z "$errs" ] || { printf 'Moved %d.%s' "$moved" "$errs"; pause; }
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
    collapse|expand)
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
        # Not `grep ... && mv`: grep exits 1 when it selects no lines, and
        # unfolding the last folded row is exactly that case — so the mv was
        # skipped and the row never opened. The redirection has already
        # written the (possibly empty) file by then, so move it regardless.
        grep -vxF "$key" "$FOLD_FILE" > "$FOLD_FILE.tmp"
        mv "$FOLD_FILE.tmp" "$FOLD_FILE"
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
    mark)
      # Same toggle-in-a-file shape as the folds above, and the same reason the
      # mv is unconditional: grep exits 1 when it selects no lines, which is
      # exactly the unmark-the-last-mark case, and the redirection has already
      # written the file by then.
      touch "$MARK_FILE"
      if grep -qxF "$key" "$MARK_FILE"; then
        grep -vxF "$key" "$MARK_FILE" > "$MARK_FILE.tmp"
        mv "$MARK_FILE.tmp" "$MARK_FILE"
      else
        printf '%s\n' "$key" >> "$MARK_FILE"
      fi
      ;;
    unmark) : > "$MARK_FILE" ;;
    move)   move_marked "$tgt" ;;
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
# Marking is the other exception, in the opposite direction: marking a run of
# panes is the common case, so m steps down a row afterwards the way it does in
# the Telescope buffer picker. fzf clamps a pos() past the end, so the last row
# needs no special case.
save_pos() {
  _off=0
  case $3:$1 in
    collapse:p:*) _off=$(tmux display-message -p -t "${1#p:}" '#{pane_index}' 2>/dev/null) || _off=0 ;;
    mark:*)       _off=-1 ;;
  esac
  printf 'pos(%d)' "$(($2 + 1 - _off))" > "$POS_FILE"
}

# `:N` is the same cursor handoff read the other way round: nothing is being
# mutated, so there is no position to work out — the number typed *is* the
# position. It goes to the same file so the same after-act transform applies it.
#
# execute() rather than execute-silent(), for the reason the mutation prompts
# use it: the child needs the terminal to draw its prompt and read a line. A
# blank or non-numeric answer writes nothing, and an empty transform leaves the
# cursor where it was — so backing out of the prompt costs nothing.
goto() {
  ask "Go to row: " || exit 0
  case $REPLY_ in
    ''|*[!0-9]*) exit 0 ;;
  esac
  printf 'pos(%d)' "$REPLY_" > "$POS_FILE"
}

case ${1:-} in
  list)    list "$2"; exit 0 ;;
  goto)    goto; exit 0 ;;
  after-act) cat "$POS_FILE" 2>/dev/null; rm -f "$POS_FILE"; exit 0 ;;
  act)     act "$2" "$3" "$4"; exit 0 ;;
  preview) tmux capture-pane -ep -t "$(target "$2")" 2>/dev/null; exit 0 ;;
esac

# --- Interactive -----------------------------------------------------------
command -v fzf >/dev/null 2>&1 || die "fzf not found on PATH.

  brew install fzf

PATH was:
$PATH"

# Resolved here rather than passed in from the binding, because display-popup
# does NOT format-expand its shell-command — passing '#{pane_id}' handed the
# script the literal placeholder. Asking tmux from inside the popup works: the
# popup belongs to the client, so these resolve against the client's active
# pane, not against the popup itself. Exported so the reload/execute children
# see the same answers.
SRC_PANE=$(tmux display-message -p '#{pane_id}')
SRC_SESSION=$(tmux display-message -p '#{session_name}')
export SRC_PANE SRC_SESSION
[ -n "$SRC_PANE" ] || die "could not determine the current tmux pane."

# Folds are reseeded on every open rather than persisted: the popup opens on the
# whole tree — the question it answers is what is open everywhere, not just here
# — and a fold you set is only ever meant to last as long as the popup is up.
: > "$FOLD_FILE"
# Marks are reseeded empty for the same reason, and more strongly: a mark left
# over from a previous popup would name a row you have since forgotten about,
# and M would move it.
: > "$MARK_FILE"
rm -f "$POS_FILE"

prompt="$SRC_SESSION > "

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
VIM_NAV='j,k,g,G,d,u,:'
VIM_MODE='i,a,/,q'
VIM_ACT='h,l,n,r,x,p,m,M,U'

dead_keys=''
dead_binds=''
for k in b c e f o s t v w y z space \
         A B C D E F H I J K L N O P Q R S T V W X Y Z \
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

# ctrl-based keys work in both modes, so nothing has to be remembered twice:
# normal mode adds unshifted aliases, and everything that stays in the popup
# has a ctrl form reachable from a search too. Marking during a search is the
# reason that matters here — a search is exactly how you reach the rows you
# want to mark, and having to leave it for each one would undo the point.
#
# Folding is the exception: it is h/l only, with no ctrl alias. A tree wants a
# direction rather than a toggle — h always closes, l always opens, whatever
# the row is doing now — and there is no unmodified pair to alias it to.
#
# `:` clears the query and rebuilds before prompting. With an empty query, which
# is the only state that shows numbers, both are no-ops; pressed under a search
# they put back the list the numbers were counted over, so the answer means what
# it says rather than landing on the Nth surviving match. reload-sync rather
# than leaving it to the change event, so the list is back before the prompt.
header='j/k move  h/l fold  :N row  g/G ends  d/u page  n new  r rename  x kill  p preview  q quit
m mark  M move marked here  U unmark all   i or / search (esc back)   ^j ^k ^n ^r ^x ^t ^g   ↵ jump'

out=$(list | fzf \
  --ansi \
  --no-sort \
  --layout=reverse \
  --delimiter="$TAB" \
  --with-nth=2.. \
  --prompt="$P_NORMAL" \
  --header="$header" \
  --header-first \
  --expect=enter \
  --bind='ctrl-j:down,ctrl-k:up' \
  --bind="esc:rebind($MODAL_KEYS)+change-prompt($P_NORMAL)" \
  --bind="i:unbind($MODAL_KEYS)+change-prompt($P_INSERT)" \
  --bind="a:unbind($MODAL_KEYS)+change-prompt($P_INSERT)" \
  --bind="/:unbind($MODAL_KEYS)+change-prompt($P_INSERT)" \
  --bind='j:down,k:up,g:first,G:last,d:half-page-down,u:half-page-up' \
  --bind="::clear-query+reload-sync('$SELF' list)+execute('$SELF' goto)+transform('$SELF' after-act)" \
  --bind='q:abort,p:toggle-preview' \
  --bind="$dead_binds" \
  --bind="n:execute('$SELF' act new {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="r:execute('$SELF' act rename {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="x:execute('$SELF' act kill {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="h:execute-silent('$SELF' act collapse {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="l:execute-silent('$SELF' act expand {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="m:execute-silent('$SELF' act mark {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="U:execute-silent('$SELF' act unmark {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="M:execute('$SELF' act move {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind='?:toggle-preview' \
  --bind="change:reload('$SELF' list {q})" \
  --bind='alt-j:preview-down,alt-k:preview-up' \
  --bind="ctrl-n:execute('$SELF' act new {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="ctrl-r:execute('$SELF' act rename {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="ctrl-x:execute('$SELF' act kill {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="ctrl-t:execute-silent('$SELF' act mark {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
  --bind="ctrl-g:execute('$SELF' act move {1} {n})+reload-sync('$SELF' list {q})+transform('$SELF' after-act)" \
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

# Line 1 is the --expect key, line 2 the chosen row.
key=$(printf '%s\n' "$out" | sed -n 2p | cut -d"$TAB" -f1)
[ -n "$key" ] || exit 0
tgt=$(target "$key")

# Enter is the only key that closes the popup with a row: everything else acts
# in place and reloads. select-window resolves a pane target to its containing
# window, and select-pane unzooms that window on its own if it was zoomed on
# some other pane — so the row you picked is always the one you land on and can
# see. switch-client first, because the target may be another session.
tmux switch-client -t "$(tmux display-message -p -t "$tgt" '#{session_name}')"
tmux select-window -t "$tgt"
case $key in p:*) tmux select-pane -t "$tgt" ;; esac
