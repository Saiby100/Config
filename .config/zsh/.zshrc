if [ -z "$TMUX" ]; then
  tmux new-session
fi

# Load in version control information
#autoload -Uz add-zsh-hook vcs_info 
#add-zsh-hook precmd vcs_info

# Setting Prompt text
setopt prompt_subst
#PROMPT=' %B%F{magenta}%~%b
# %B$(git_remote_status)%b%F{cyan}%B❯%b%f '
PROMPT=' %B%F{#de9dac}%~%b
 %B$(git_remote_status)%b%F{#70e9ff}%B❯%b%f '

#zstyle ':vcs_info:*' check-for-changes true

# Define colours for different Git status
#zstyle ':vcs_info:*' unstagedstr ' %F{yellow}⎇ %f'
#zstyle ':vcs_info:*' stagedstr ' %F{green}⎇ %f'

#zstyle ':vcs_info:git:*' formats '%b%u%c'
#zstyle ':vcs_info:git:*' actionformats '%b|%a%u%c'

# Custom Variables
EDITOR=vim

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
    local remote=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null)
    if [[ -n $remote ]]; then
      local tracking=$(git rev-parse --symbolic-full-name --abbrev-ref @{u} 2>/dev/null)
      if [[ $tracking == $remote ]]; then
        echo "%F{#70e9ff}$(git rev-parse --abbrev-ref HEAD)⎇ %f"  # Up to date
      else
        echo "%F{red}$(git rev-parse --abbrev-ref HEAD)⎇ %f"  # Not up to date
      fi
    fi
  fi
}

# Run a Lowdefy app on a custom port, from inside its app folder.
# Auth magic-links respect the chosen port (AUTH_TRUST_HOST makes NextAuth
# use the request Host header instead of the fixed NEXTAUTH_URL).
# Usage:  cd apps/prp-team && ldfport 8000
function ldfport() {
  local port=$1
  if [[ -z $port ]]; then
    echo "usage: ldfport <port>" >&2
    return 1
  fi

  # Walk up from the current dir to find the app root (has lowdefy.yaml).
  local dir=$PWD
  while [[ $dir != / && ! -f $dir/lowdefy.yaml ]]; do
    dir=${dir:h}
  done
  if [[ ! -f $dir/lowdefy.yaml ]]; then
    echo "ldfport: no lowdefy.yaml found above $PWD" >&2
    return 1
  fi

  # The Infisical secret path is hardcoded in the app's own package.json
  # scripts (e.g. --path=/apps/taste), which may differ from the folder name.
  local infpath=$(grep -oE -- '--path=[^ "]+' "$dir/package.json" 2>/dev/null | head -1 | sed 's/--path=//')
  if [[ -z $infpath ]]; then
    echo "ldfport: could not find an Infisical --path in $dir/package.json" >&2
    return 1
  fi

  echo "▶ ${dir:t}  →  http://localhost:$port  (infisical $infpath)"
  ( cd "$dir" && \
    infisical run --env=dev --path="$infpath" -- \
    env AUTH_TRUST_HOST=true pnpm exec lowdefy dev --port "$port" --no-open )
}

#Path Variables
export PATH=$PATH:/home/saiby/.kotlinc/bin #Kotlin compiler
export PATH=$PATH:/usr/local/gradle/gradle-8.3/bin #Gradle
export PATH=$HOME/.local/bin:$PATH

# Load ; should be last.
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source /usr/share/autojump/autojump.zsh 2>/dev/null

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
