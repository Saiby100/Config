# Load in version control information

# Setting Prompt text
setopt prompt_subst
PROMPT=' %B%F{#de9dac}%~%b
 %B$(git_remote_status)%b%F{#70e9ff}%B❯%b%f '

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
        echo "%F{#70e9ff}$(git rev-parse --abbrev-ref HEAD)%f"  # Up to date
      else
        echo "%F{red}$(git rev-parse --abbrev-ref HEAD)%f"  # Not up to date
      fi
    fi
  fi
}

#Path Variables
export PATH=$PATH:/home/saiby/.kotlinc/bin #Kotlin compiler
export PATH=$PATH:/usr/local/gradle/gradle-8.3/bin #Gradle

#Xserver
export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2; exit;}'):0.0 
export LIBGL_ALWAYS_INDIRECT=1

# Load ; should be last.
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source /usr/share/autojump/autojump.zsh 2>/dev/null
