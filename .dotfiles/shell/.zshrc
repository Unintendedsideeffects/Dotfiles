# ~/.zshrc
# Machine-specific overrides belong in ~/.zshrc.local.

source "$HOME/.dotfiles/shell/zshrc.base"

[[ -f "$HOME/.dotfiles/cli/common.sh" ]] && source "$HOME/.dotfiles/cli/common.sh"
[[ -f "$HOME/.dotfiles/cli/aliases" ]] && source "$HOME/.dotfiles/cli/aliases"
[[ -f "$HOME/.dotfiles/cli/config.sh" ]] && source "$HOME/.dotfiles/cli/config.sh"

[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

if [[ -d "$HOME/.dotfiles/shell/zshrc.d" ]]; then
  case "$(uname -s)" in
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        source "$HOME/.dotfiles/shell/zshrc.d/wsl.zsh"
      elif [[ -f /etc/rocky-release ]]; then
        source "$HOME/.dotfiles/shell/zshrc.d/rocky.zsh"
      elif [[ "$(uname -r)" == *Crostini* ]]; then
        source "$HOME/.dotfiles/shell/zshrc.d/crostini.zsh"
      else
        source "$HOME/.dotfiles/shell/zshrc.d/arch.zsh"
      fi
      ;;
  esac
fi

if [[ -o interactive ]] && command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh 2>/dev/null)"
fi
