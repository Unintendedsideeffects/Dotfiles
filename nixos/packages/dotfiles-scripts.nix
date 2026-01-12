# Dotfiles Scripts Package
# Packages all custom scripts from .dotfiles/bin
{ lib, stdenv, writeShellScriptBin, makeWrapper
, bash, coreutils, gnugrep, gnused, gawk, findutils
, jq, rofi, dunst, i3, networkmanager, pulseaudio, brightnessctl
}:

let
  # Common dependencies for scripts
  scriptPath = lib.makeBinPath [
    bash
    coreutils
    gnugrep
    gnused
    gawk
    findutils
    jq
  ];

  # GUI/Desktop dependencies
  guiPath = lib.makeBinPath [
    rofi
    dunst
    i3
    networkmanager
    pulseaudio
    brightnessctl
  ];

in stdenv.mkDerivation {
  pname = "dotfiles-scripts";
  version = "1.0.0";

  src = ../../.dotfiles;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/dotfiles

    # Copy all scripts from bin directory
    if [ -d bin ]; then
      cp -r bin/* $out/bin/ || true
      # Make all scripts executable
      chmod +x $out/bin/* 2>/dev/null || true
      find $out/bin -type f -name "*.sh" -exec chmod +x {} \; || true
      find $out/bin -type f ! -name "*.*" -exec chmod +x {} \; || true
    fi

    # Copy blocklets
    if [ -d bin/blocklets ]; then
      mkdir -p $out/share/dotfiles/blocklets
      cp -r bin/blocklets/* $out/share/dotfiles/blocklets/ || true
      chmod +x $out/share/dotfiles/blocklets/* 2>/dev/null || true
    fi

    # Copy CLI utilities
    if [ -d cli ]; then
      mkdir -p $out/share/dotfiles/cli
      cp -r cli/* $out/share/dotfiles/cli/ || true
    fi

    # Copy library files
    if [ -d lib ]; then
      mkdir -p $out/share/dotfiles/lib
      cp -r lib/* $out/share/dotfiles/lib/ || true
    fi

    # Copy package lists for reference
    if [ -d pkglists ]; then
      mkdir -p $out/share/dotfiles/pkglists
      cp -r pkglists/* $out/share/dotfiles/pkglists/ || true
    fi

    # Wrap scripts with proper PATH
    for script in $out/bin/*; do
      if [ -f "$script" ] && [ -x "$script" ]; then
        wrapProgram "$script" \
          --prefix PATH : "${scriptPath}:${guiPath}" \
          --set DOTFILES_DIR "$out/share/dotfiles" \
          || true
      fi
    done
  '';

  meta = with lib; {
    description = "Custom dotfiles scripts and utilities";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
