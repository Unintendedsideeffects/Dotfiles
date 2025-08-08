{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # core
    git gnupg curl
    # cli
    ripgrep fd fzf bat eza htop tree zoxide jq yq-go direnv
    # history/fileman
    atuin ranger yazi
    # editors & runtimes
    neovim python3 python312Packages.pip go nodejs pnpm
    # build/toolchain
    ccache gnumake cmake ninja pkg-config
    # archivers
    zip unzip xz
    # fonts
    jetbrains-mono noto-fonts noto-fonts-emoji
  ];
}


