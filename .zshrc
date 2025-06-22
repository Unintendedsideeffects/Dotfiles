# ~/.zshrc — tracked in the bare repo
source $HOME/.dotfiles/shell/zshrc.base

source $HOME/.dotfiles/cli/common.sh
source $HOME/.dotfiles/cli/aliases
source $HOME/.dotfiles/cli/config.sh

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

if [[ -d $HOME/.dotfiles/shell/zshrc.d ]]; then
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)
          if grep -qi microsoft /proc/version 2>/dev/null; then
              source $HOME/.dotfiles/shell/zshrc.d/wsl.zsh
          elif [[ -f /etc/rocky-release ]]; then
              source $HOME/.dotfiles/shell/zshrc.d/rocky.zsh
          elif [[ "$(uname -r)" == *Crostini* ]]; then
              source $HOME/.dotfiles/shell/zshrc.d/crostini.zsh
          else
              source $HOME/.dotfiles/shell/zshrc.d/arch.zsh
          fi
          ;;
  esac
fi 