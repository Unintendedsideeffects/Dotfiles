{ config, pkgs, ... }:
{
  programs.git = {
    enable = true;
    aliases = {
      all = "!git-all() { local target_dir=\".\"; if [ -d \"$1\" ]; then target_dir=\"$1\"; shift; fi; if [ $# -eq 0 ]; then echo \"Usage: git-all [directory] <git-command> [args...]\"; return 1; fi; local start_dir=$(pwd); cd \"$target_dir\" || return 1; for dir in */; do if [ -d \"$dir/.git\" ]; then echo \"📁 $(basename \"$dir\")\"; echo \"────────────────────────────────\"; (cd \"$dir\" && git \"$@\"); echo \"\"; fi; done; cd \"$start_dir\"; }; git-all";
    };
  };
}