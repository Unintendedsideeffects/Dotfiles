{ config, pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    initExtra = ''
      if command -v eza >/dev/null 2>&1; then
        alias ls='eza -alh --group-directories-first --icons=auto'
      else
        alias ls='ls --color=auto -alh'
      fi
      if command -v batcat >/dev/null 2>&1; then alias bat='batcat'; fi
      if command -v fdfind >/dev/null 2>&1; then alias fd='fdfind'; fi
      alias ya='yazi'
    '';
  };

  programs.fzf = {
    enable = true;
    defaultOptions = [ "--height 40%" "--layout=reverse" "--border" ];
  };

  programs.zoxide.enable = true;
  programs.atuin = {
    enable = true;
    settings = {
      auto_sync = false;
      update_check = false;
      secrets_filter = true;
      sync = { records = false; };
    };
  };

  programs.direnv = { enable = true; nix-direnv.enable = true; };

  programs.starship = {
    enable = true;
    settings = {
      hostname = {
        ssh_only = true;
        disabled = false;
        format = "[$hostname]($style) ";
        style = "bold green";
      };
    };
  };

  home.file = {
    ".config/ghostty/config".text = ''
      background = 000000
    '';
    ".config/ripgrep/rg.conf".text = ''
      --smart-case
      --colors=match:style:bold
      --hidden
      --glob=!.git
    '';
    ".config/yazi/yazi.toml".text = ''
      [manager]
      ratio = [1, 2, 3]
      show_hidden = true
      sort_by = "natural"
    '';
  };
}


