# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt autocd extendedglob
bindkey -v
# End of lines configured by zsh-newuser-install

# The following lines were added by compinstall
zstyle :compinstall filename '/home/malcolm/.zshrc'

autoload -Uz compinit
compinit
autoload -Uz promptinit
promptinit
zstyle ':completion:*' menu select
setopt HIST_IGNORE_DUPS
setopt COMPLETE_ALIASES
ttyctl -f
zstyle ':completion:*' rehash true
# End of lines added by compinstall

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Which plugins would you like to load?
plugins=(git)

source $ZSH/oh-my-zsh.sh

# Terminal color settings for Linux
if [ "$TERM" = "linux" ]; then
  /bin/echo -e "
  \e]P0000000
  \e]P16666cc
  \e]P200779f
  \e]P33b6bcc
  \e]P4217199
  \e]P54068a5
  \e]P6493b8b
  \e]P7a0a0a0
  \e]P8000000
  \e]P96666cc
  \e]PA00779f
  \e]PB3b6bcc
  \e]PC217199
  \e]PD4068a5
  \e]PE493b8b
  \e]PFa0a0a0
  "
  # get rid of artifacts
  clear
fi

# Load syntax highlighting
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Powerline configuration
powerline-daemon -q
. /usr/share/powerline/bindings/zsh/powerline.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Modern CLI Tools Integration
# Initialize Starship
eval "$(starship init zsh)"

# Source alias configuration
if [ -f ~/.alias/config ]; then
    source ~/.alias/config
fi

# Use fzf for fuzzy finding
if command -v fzf &> /dev/null; then
    source /usr/share/fzf/key-bindings.zsh
    source /usr/share/fzf/completion.zsh
    export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'
fi