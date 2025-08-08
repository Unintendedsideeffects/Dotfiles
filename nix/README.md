Dotfiles Nix (home-manager)

Quick start (non-NixOS):
1) Install Nix (multi-user). Enable flakes.
2) Run: `nix run home-manager/master -- init --switch` (first-time)
3) Apply: `home-manager switch --flake .#malcolm@host`

This config mirrors your classic dotfiles: zsh, fzf, zoxide, atuin, rg, yazi, and core CLI.


