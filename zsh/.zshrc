# Load in version control information
#autoload -Uz add-zsh-hook vcs_info 
#add-zsh-hook precmd vcs_info

# Setting Prompt text
setopt prompt_subst
PROMPT=' %B%F{magenta}%~%b
 %B$(git_remote_status)%b%F{cyan}%B❯%b%f '

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

# Custom ZSH Binds
bindkey '^ ' autosuggest-accept

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
        echo "%F{cyan}$(git rev-parse --abbrev-ref HEAD)⎇ %f"  # Up to date
      else
        echo "%F{red}$(git rev-parse --abbrev-ref HEAD)⎇ %f"  # Not up to date
      fi
    fi
  fi
}

# Load ; should be last.
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source /usr/share/autojump/autojump.zsh 2>/dev/null

