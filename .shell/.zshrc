# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Source common shell configuration
[ -f "$HOME/.shell/common.sh" ] && source "$HOME/.shell/common.sh"

# History configuration
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# Atuin shell history
if command -v atuin &>/dev/null; then
    eval "$(atuin init zsh)"
    # Bind better history search to up/down arrows
    bindkey '^[[A' _atuin_search_widget
    bindkey '^[[B' _atuin_search_widget
fi

# Basic settings
setopt AUTO_CD
setopt EXTENDED_GLOB
setopt PROMPT_SUBST
setopt NO_BEEP

# Completion system
autoload -Uz compinit
compinit -d "$XDG_CACHE_HOME/zsh/zcompdump-$ZSH_VERSION"
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' rehash true
setopt COMPLETE_ALIASES

# Key bindings
bindkey -e  # Use emacs key bindings
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Plugin management with zinit (if installed)
if [[ -f "$HOME/.local/share/zinit/zinit.git/zinit.zsh" ]]; then
    source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit

    # Load plugins
    zinit light zsh-users/zsh-autosuggestions
    zinit light zsh-users/zsh-syntax-highlighting
    zinit light zsh-users/zsh-history-substring-search
    zinit ice depth=1; zinit light romkatv/powerlevel10k
fi

# Modern CLI tools setup
if command -v exa &>/dev/null; then
    alias ls='exa --icons --group-directories-first'
    alias ll='exa -l --icons --group-directories-first'
    alias la='exa -la --icons --group-directories-first'
    alias tree='exa --tree --icons'
fi

if command -v bat &>/dev/null; then
    alias cat='bat --style=plain'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

if command -v fd &>/dev/null; then
    alias find='fd'
fi

if command -v rg &>/dev/null; then
    alias grep='rg'
fi

if command -v delta &>/dev/null; then
    git config --global core.pager "delta"
    git config --global interactive.diffFilter "delta --color-only"
fi

# Initialize zoxide if installed
if command -v zoxide &>/dev/null; then
    eval "$(zoxide init zsh)"
fi

# Initialize starship if installed
if command -v starship &>/dev/null; then
    eval "$(starship init zsh)"
fi

# FZF integration
if [ -f /usr/share/fzf/key-bindings.zsh ]; then
    source /usr/share/fzf/key-bindings.zsh
    source /usr/share/fzf/completion.zsh
    export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border --preview 'bat --color=always --style=numbers --line-range=:500 {}'"
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

# Load custom aliases if they exist
[ -f "$HOME/.alias/config" ] && source "$HOME/.alias/config"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh