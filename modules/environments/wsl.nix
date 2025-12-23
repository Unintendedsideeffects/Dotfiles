{ config, pkgs, lib, ... }:

{
  # WSL (Windows Subsystem for Linux) specific configuration

  dotfiles = {
    enableGui = false;  # WSL typically runs headless
    enableDevelopment = true;
    enableMinimal = false;
  };

  # WSL-specific packages
  home.packages = with pkgs; [
    wslu  # WSL utilities (if available in nixpkgs)
  ];

  # WSL-specific environment variables
  home.sessionVariables = {
    # Windows path integration
    BROWSER = "wslview";  # wslu browser wrapper
  };

  # WSL-specific shell configuration
  programs.zsh = {
    initExtra = ''
      # WSL-specific environment setup

      # Windows path support
      if [[ -d "/mnt/c" ]]; then
        # Add Windows paths if needed
        export WINDOWS_HOME="/mnt/c/Users/$USER"
      fi

      # Display server configuration for WSL2 with X11 forwarding
      if grep -qi microsoft /proc/version; then
        # WSL2 X11 configuration
        export DISPLAY=$(cat /etc/resolv.conf | grep nameserver | awk '{print $2}'):0
        export LIBGL_ALWAYS_INDIRECT=1

        # WSLg support (WSL with built-in GUI)
        if [[ -n "$WAYLAND_DISPLAY" ]]; then
          export DISPLAY=:0
        fi
      fi

      # Load WSL-specific configurations if they exist
      [[ -f ~/.config/zsh/wsl.zsh ]] && source ~/.config/zsh/wsl.zsh
    '';
  };

  # Link to WSL-specific dotfiles
  xdg.configFile."zsh/wsl.zsh" = lib.mkIf (builtins.pathExists "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/zshrc.d/wsl.zsh") {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.dotfiles/shell/zshrc.d/wsl.zsh";
  };
}
