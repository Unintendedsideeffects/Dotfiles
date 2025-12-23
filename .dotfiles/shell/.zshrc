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

ZSH_THEME="bullet-train"

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

# Ghostty TERM handling for SSH
# Prevent exporting unavailable $TERM over SSH
if [[ -n "$SSH_CONNECTION" ]] || [[ -n "$SSH_CLIENT" ]] || [[ -n "$SSH_TTY" ]]; then
  if [[ "$TERM" == "xterm-ghostty" ]]; then
    export TERM=xterm-256color
  fi
fi

source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
powerline-daemon -q
. /usr/share/powerline/bindings/zsh/powerline.zsh
