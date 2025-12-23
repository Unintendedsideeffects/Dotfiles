{ config, pkgs, lib, ... }:

{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    # History configuration
    history = {
      size = 10000;
      save = 10000;
      path = "${config.xdg.dataHome}/zsh/history";
      ignoreDups = true;
      ignoreSpace = true;
      share = true;
    };

    # Environment variables
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      LANG = "en_US.UTF-8";
      LC_ALL = "en_US.UTF-8";
    };

    # Shell aliases
    shellAliases = {
      # Modern CLI tool replacements
      ls = "eza --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first";
      la = "eza -a --icons --group-directories-first";
      lla = "eza -la --icons --group-directories-first";
      lt = "eza -T --icons --group-directories-first";
      cat = "bat --paging=never";
      grep = "rg";
      cd = "z";

      # Git aliases
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gd = "git diff";
      gco = "git checkout";
      gcb = "git checkout -b";
      gl = "git log --oneline --graph --decorate";
      gp = "git push";
      gpl = "git pull";

      # Directory navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      "....." = "cd ../../../..";

      # Safety aliases
      rm = "rm -i";
      cp = "cp -i";
      mv = "mv -i";

      # Quick edit
      zshconfig = "nvim ~/.zshrc";
      nixconfig = "nvim ~/.config/home-manager/home.nix";
      vimconfig = "nvim ~/.config/nvim/init.lua";

      # Development
      py = "python3";
      pip = "pip3";
      venv = "python3 -m venv";
      activate = "source venv/bin/activate";

      # Network
      ip = "ip -c";
      ports = "netstat -tulanp";
      myip = "curl ifconfig.me";

      # System info
      df = "df -h";
      du = "du -h";
      free = "free -h";
      ps = "ps aux";
      top = "htop";

      # Docker
      d = "docker";
      dc = "docker-compose";
      dps = "docker ps";
      dimg = "docker images";

      # Kubernetes
      k = "kubectl";
      kg = "kubectl get";
      kd = "kubectl describe";
      kl = "kubectl logs";
      kx = "kubectl exec -it";

      # Misc
      c = "clear";
      h = "history";
      j = "jobs";
      path = "echo -e \${PATH//:/\\\\n}";
      now = "date +\"%T\"";
      today = "date +\"%Y-%m-%d\"";

      # Nix-specific
      nix-update = "nix flake update";
      nix-switch = "home-manager switch --flake .";
      nix-clean = "nix-collect-garbage -d";
    };

    # Init extra - additional shell configuration
    initExtra = ''
      # Set locale if not set
      if [[ -z "$LANG" ]]; then
        export LANG="en_US.UTF-8"
        export LC_ALL="en_US.UTF-8"
      fi

      # Dynamic editor selection
      if command -v nvim &> /dev/null; then
        export EDITOR="nvim"
        export VISUAL="nvim"
      elif command -v vim &> /dev/null; then
        export EDITOR="vim"
        export VISUAL="vim"
      else
        export EDITOR="vi"
        export VISUAL="vi"
      fi

      # FZF configuration
      if command -v fzf &> /dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
        export FZF_DEFAULT_OPTS='
          --height 40%
          --layout=reverse
          --border
          --inline-info
          --color=fg:#908caa,bg:#232136,hl:#ea9a97
          --color=fg+:#e0def4,bg+:#393552,hl+:#ea9a97
          --color=border:#44415a,header:#3e8fb0,gutter:#232136
          --color=spinner:#f6c177,info:#9ccfd8
          --color=pointer:#c4a7e7,marker:#eb6f92,prompt:#908caa
        '
      fi

      # Load machine-specific configuration if it exists
      [[ -f ~/.zshrc.local ]] && source ~/.zshrc.local

      # Load environment-specific configurations
      [[ -f ~/.config/zsh/local.zsh ]] && source ~/.config/zsh/local.zsh
    '';

    # Zsh options
    defaultKeymap = "emacs";  # or "viins" for vi mode

    # Additional options via oh-my-zsh style
    oh-my-zsh = {
      enable = false;  # We're not using oh-my-zsh, managing plugins directly
    };
  };

  # Bash configuration (fallback)
  programs.bash = {
    enable = true;
    enableCompletion = true;

    shellAliases = config.programs.zsh.shellAliases;

    initExtra = ''
      # Source zsh aliases for consistency
      export EDITOR="nvim"
      export VISUAL="nvim"
    '';
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  # Zoxide (smarter cd)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  # FZF (fuzzy finder)
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  # Atuin (shell history)
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    settings = {
      auto_sync = false;           # Disabled as per config.toml
      update_check = false;        # Disabled as per config.toml
      secrets_filter = true;       # Enabled as per config.toml
      search_mode = "fuzzy";
      filter_mode = "global";
      style = "compact";
      inline_height = 20;
      sync = {
        records = false;           # Disabled as per config.toml
      };
    };
  };

  # Direnv
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  # Eza (modern ls)
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
    git = true;
    icons = true;
  };

  # Bat (modern cat)
  programs.bat = {
    enable = true;
    config = {
      theme = "base16";
      pager = "less -FR";
    };
  };

  # Ripgrep
  home.file.".config/ripgrep/config".text = ''
    --smart-case
    --hidden
    --glob=!.git/*
    --glob=!node_modules/*
    --glob=!.cache/*
  '';

  home.sessionVariables = {
    RIPGREP_CONFIG_PATH = "${config.home.homeDirectory}/.config/ripgrep/config";
  };
}
