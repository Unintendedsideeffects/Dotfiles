# ~/.zshrc — tracked in the bare repo
source $HOME/shell/zshrc.base

source $HOME/cli/common.sh
source $HOME/cli/aliases
source $HOME/cli/config.sh

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

if [[ -d $HOME/shell/zshrc.d ]]; then
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)
          if grep -qi microsoft /proc/version 2>/dev/null; then
              source $HOME/shell/zshrc.d/wsl.zsh
          elif [[ -f /etc/rocky-release ]]; then
              source $HOME/shell/zshrc.d/rocky.zsh
          elif [[ "$(uname -r)" == *Crostini* ]]; then
              source $HOME/shell/zshrc.d/crostini.zsh
          else
              source $HOME/shell/zshrc.d/arch.zsh
          fi
          ;;
  esac
fi 