{ config, pkgs, lib, ... }:

{
  options = {
    dotfiles = {
      enableGui = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GUI packages and window managers";
      };

      enableDevelopment = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable development tools and languages";
      };

      enableMinimal = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Minimal package set (essential only)";
      };
    };
  };

  config = {
    home.packages = with pkgs;
      # Essential packages (always installed)
      [
        # Core utilities
        coreutils
        findutils
        gnugrep
        gnused
        gawk
        sudo

        # Shell
        zsh
        zsh-completions
        zsh-syntax-highlighting
        zsh-autosuggestions

        # Editor
        neovim

        # Terminal multiplexers
        tmux

        # Documentation
        man-db
        man-pages

        # Network tools
        curl
        wget
        openssh

        # Version control
        git

        # Compression
        zip
        unzip
        gzip
        bzip2
        xz
      ]

      # Modern CLI tools (unless minimal)
      ++ lib.optionals (!config.dotfiles.enableMinimal) [
        # Modern replacements
        ripgrep           # Modern grep
        fd                # Modern find
        bat               # Modern cat with syntax highlighting
        eza               # Modern ls
        fzf               # Fuzzy finder
        zoxide            # Smarter cd
        starship          # Modern prompt
        atuin             # Shell history search

        # File management
        ranger
        yazi              # Modern file manager
        tree
        du-dust           # Modern du
        duf               # Modern df
        ncdu              # Disk usage analyzer

        # System monitoring
        htop
        btop              # Modern htop
        bottom            # Another htop alternative
        procs             # Modern ps

        # Development utilities
        jq                # JSON processor
        yq-go             # YAML processor
        direnv            # Directory environment manager
        just              # Command runner

        # Text processing
        sd                # Modern sed
        choose            # Modern cut/awk

        # Network utilities
        bandwhich         # Network bandwidth monitor
        dog               # Modern dig
        httpie            # HTTP client
        nmap
        netcat
        socat

        # Misc utilities
        tldr              # Simplified man pages
        tealdeer          # Fast tldr client
        tokei             # Code statistics
        hyperfine         # Benchmarking tool
        progress          # Progress viewer for cp, mv, etc.
      ]

      # Development tools
      ++ lib.optionals config.dotfiles.enableDevelopment [
        # Build tools
        gcc
        gnumake
        cmake
        ninja
        pkg-config
        ccache
        autoconf
        automake
        libtool

        # Languages
        python3
        python311Packages.pip
        python311Packages.virtualenv
        go
        rustc
        cargo
        rust-analyzer
        nodejs
        nodePackages.npm
        nodePackages.pnpm
        nodePackages.yarn

        # Language servers and tools
        nil               # Nix language server
        nixpkgs-fmt
        shellcheck
        shfmt

        # Version control
        git-lfs
        gh                # GitHub CLI
        lazygit           # Terminal UI for git

        # Container tools
        docker-compose
        kubectl
        k9s               # Kubernetes CLI

        # Other dev tools
        gnupg
        pass              # Password manager
        age               # Modern encryption tool
      ]

      # GUI packages
      ++ lib.optionals config.dotfiles.enableGui [
        # Wayland/Sway
        sway
        swaylock
        swayidle
        swaybg
        waybar
        wl-clipboard
        grim              # Screenshot
        slurp             # Region selector
        mako              # Notification daemon
        wofi              # Wayland launcher
        rofi-wayland      # Rofi for Wayland

        # X11/i3 (fallback)
        i3
        i3status
        i3lock
        rofi
        dunst
        picom
        feh               # Image viewer / wallpaper setter
        flameshot         # Screenshot tool
        xclip
        xsel
        xdotool
        wmctrl

        # Terminals
        kitty
        ghostty
        alacritty

        # Fonts
        (nerdfonts.override { fonts = [ "JetBrainsMono" "Hack" "FiraCode" "Iosevka" ]; })
        noto-fonts
        noto-fonts-emoji
        noto-fonts-cjk
        font-awesome
        liberation_ttf
        dejavu_fonts

        # Audio
        pipewire
        wireplumber
        pavucontrol
        pamixer
        playerctl

        # Applications
        firefox
        google-chrome
        obsidian
        vscode
        discord
        telegram-desktop
        mpv
        vlc

        # Icon themes
        adwaita-icon-theme
        hicolor-icon-theme
        papirus-icon-theme

        # GTK themes
        arc-theme
        materia-theme

        # Graphics libraries
        mesa
        vulkan-loader
        vulkan-tools
      ];

    # Fonts configuration
    fonts.fontconfig.enable = lib.mkIf config.dotfiles.enableGui true;
  };
}
