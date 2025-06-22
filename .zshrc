# ~/.zshrc — tracked in the bare repo
source ~/Dotfiles/shell/zshrc.base

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

if [[ -d ~/Dotfiles/shell/zshrc.d ]]; then
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)
          if grep -qi microsoft /proc/version 2>/dev/null; then
              source ~/Dotfiles/shell/zshrc.d/wsl.zsh
          elif [[ -f /etc/rocky-release ]]; then
              source ~/Dotfiles/shell/zshrc.d/rocky.zsh
          elif [[ "$(uname -r)" == *Crostini* ]]; then
              source ~/Dotfiles/shell/zshrc.d/crostini.zsh
          else
              source ~/Dotfiles/shell/zshrc.d/arch.zsh
          fi
          ;;
  esac
fi 