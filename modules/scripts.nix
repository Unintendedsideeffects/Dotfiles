{ config, pkgs, lib, ... }:

{
  # Make dotfiles scripts available in PATH
  # This exposes all scripts from .dotfiles/bin/

  home.packages = [
    (pkgs.stdenv.mkDerivation {
      name = "dotfiles-scripts";
      src = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.dotfiles/bin";

      installPhase = ''
        mkdir -p $out/bin

        # Copy all executable shell scripts
        find . -type f -name "*.sh" -executable -exec cp {} $out/bin/ \;

        # Copy other executable scripts (python, etc.)
        find . -type f -executable ! -name "*.sh" -exec cp {} $out/bin/ \;

        # Copy blocklets
        if [ -d blocklets ]; then
          mkdir -p $out/share/dotfiles/blocklets
          cp -r blocklets/* $out/share/dotfiles/blocklets/
        fi

        # Copy arch utilities
        if [ -d arch_small_utilities ]; then
          mkdir -p $out/share/dotfiles/arch_utilities
          cp -r arch_small_utilities/* $out/share/dotfiles/arch_utilities/
        fi
      '';

      meta = {
        description = "Personal dotfiles utility scripts";
        platforms = lib.platforms.linux;
      };
    })
  ];

  # Alternative: Simply add the bin directory to PATH
  # This is simpler and doesn't copy files
  home.sessionPath = [
    "${config.home.homeDirectory}/Dotfiles/.dotfiles/bin"
  ];

  # Create convenient aliases for commonly used scripts
  programs.zsh.shellAliases = {
    # Bootstrap and setup
    dotfiles-bootstrap = "${config.home.homeDirectory}/Dotfiles/.dotfiles/bin/bootstrap.sh";
    dotfiles-update = "${config.home.homeDirectory}/Dotfiles/.dotfiles/bin/update.sh";
    dotfiles-validate = "${config.home.homeDirectory}/Dotfiles/.dotfiles/bin/validate.sh";

    # GUI utilities (if GUI is enabled)
  } // lib.optionalAttrs config.dotfiles.enableGui {
    rofi-volume = "${config.home.homeDirectory}/Dotfiles/.dotfiles/bin/rofi-volume.sh";
    wallpaper-set = "${config.home.homeDirectory}/Dotfiles/.dotfiles/bin/wallpaper-script.sh";
    power-menu = "${config.home.homeDirectory}/Dotfiles/.dotfiles/bin/power.sh";
    launch-gui = "${config.home.homeDirectory}/Dotfiles/.dotfiles/bin/launch-gui-session.sh";
  };
}
