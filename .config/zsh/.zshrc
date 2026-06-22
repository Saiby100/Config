if [ -z "$TMUX" ]; then
  tmux new-session
fi

# Prompt — custom git status via git_remote_status() defined below.
setopt prompt_subst
PROMPT=' %B%F{#de9dac}%~%b
 %B$(git_remote_status)%b%F{#70e9ff}%B❯%b%f '

# Custom Variables
export EDITOR=vim

# Vi keybindings on the command line. Set explicitly instead of relying on
# zsh's auto-detection from $EDITOR (which only triggers if EDITOR contains
# "vi" and is exported before ZLE initializes — too fragile).
bindkey -v
KEYTIMEOUT=1                       # ~10ms after Esc, so mode switch feels instant

# History in cache directory:
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.cache/zshhistory
setopt appendhistory


# Basic auto/tab complete:
autoload -U compinit
zstyle ':completion:*' menu select
zmodload zsh/complist
compinit
_comp_options+=(globdots)               # Include hidden files.

# Load aliases and shortcuts if existent.
[ -f "$HOME/.config/zsh/.zsh/aliasrc" ] && source "$HOME/.config/zsh/.zsh/aliasrc"


function git_remote_status() {
  if [[ $(git rev-parse --is-inside-work-tree 2>/dev/null) == "true" ]]; then
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    local upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    if [[ -n $upstream ]]; then
      # Compare local HEAD against the last-fetched upstream commit. Reflects
      # ahead/behind/diverged without a network call (run `git fetch` to refresh).
      local local_rev=$(git rev-parse @ 2>/dev/null)
      local remote_rev=$(git rev-parse @{u} 2>/dev/null)
      if [[ $local_rev == $remote_rev ]]; then
        echo "%F{#70e9ff}$branch⎇ %f"  # In sync with upstream
      else
        echo "%F{red}$branch⎇ %f"  # Ahead / behind / diverged
      fi
    elif [[ -n $branch ]]; then
      echo "%F{yellow}$branch⎇ %f"  # Local only — no upstream yet
    fi
  fi
}

#Path Variables
export PATH=$HOME/.local/bin:$PATH

# Plugins — source the first path that exists. Covers Linux (/usr/share) and
# Homebrew on macOS (Apple Silicon /opt/homebrew, Intel /usr/local). Sourced
# near the end so syntax-highlighting wraps the final ZLE setup.
_source_first() {
  local f
  for f in "$@"; do
    [ -r "$f" ] && { source "$f"; return; }
  done
}

_source_first \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh

_source_first \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

_source_first \
  /usr/share/autojump/autojump.zsh \
  /opt/homebrew/etc/profile.d/autojump.sh \
  /usr/local/etc/profile.d/autojump.sh

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# Machine-local overrides — keep this last so it can override anything above.
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
