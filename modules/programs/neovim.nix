{ config, pkgs, lib, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;

    # Use neovim from nixpkgs
    package = pkgs.neovim-unwrapped;

    # Additional packages available to Neovim
    extraPackages = with pkgs; [
      # Language servers
      nil                    # Nix
      lua-language-server
      nodePackages.typescript-language-server
      nodePackages.pyright
      nodePackages.bash-language-server
      nodePackages.vscode-langservers-extracted  # HTML/CSS/JSON/ESLint
      rust-analyzer
      gopls
      terraform-ls

      # Formatters
      nixpkgs-fmt
      stylua
      nodePackages.prettier
      black
      isort
      shfmt
      rustfmt
      gofumpt

      # Linters
      shellcheck
      nodePackages.eslint
      ruff

      # Tools
      tree-sitter
      ripgrep
      fd
      git

      # Clipboard support
      xclip
      wl-clipboard
    ];

    # These will be available to Neovim via stdpath("config")
    # The actual configuration is managed in ~/.config/nvim/
    # Home Manager will symlink the existing config
  };

  # Ensure existing nvim config is preserved
  # Home Manager will create symlinks to the dotfiles repo
  xdg.configFile."nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Dotfiles/.config/nvim";
    recursive = true;
  };
}
