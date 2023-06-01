# Load in version control information
autoload -Uz add-zsh-hook vcs_info 
precmd() { vcs_info }

zstyle ':vcs_info:git:*' formats '%b '
zstyle ':vcs_info:*' check-for-changes true

# Define colours for different Git status
zstyle ':vcs_info:git*' unstagedstr '%F{yellow} %f'
zstyle ':vcs_info:git*' stagedstr '%F{green} %f'
zstyle ':vcs_info:git*' cleanstr ''

# Setting Prompt text
setopt PROMPT_SUBST
PROMPT=' %B%F{magenta}%~%b
 %B%F{cyan}${vcs_info_msg_0_}❯ %b%f'

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

# Load ; should be last.
source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh 2>/dev/null
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh 2>/dev/null
source /usr/share/autojump/autojump.zsh 2>/dev/null
