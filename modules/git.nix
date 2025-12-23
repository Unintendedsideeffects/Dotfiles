{ config, pkgs, lib, ... }:

{
  programs.git = {
    enable = true;

    # User configuration - set these via git config or override in local config
    userName = lib.mkDefault "Your Name";
    userEmail = lib.mkDefault "your.email@example.com";

    # Git aliases
    aliases = {
      # Status and info
      s = "status";
      st = "status";

      # Add
      a = "add";
      aa = "add --all";
      ap = "add --patch";

      # Commit
      c = "commit";
      cm = "commit -m";
      ca = "commit --amend";
      can = "commit --amend --no-edit";

      # Checkout
      co = "checkout";
      cob = "checkout -b";

      # Branch
      b = "branch";
      ba = "branch -a";
      bd = "branch -d";
      bD = "branch -D";

      # Diff
      d = "diff";
      ds = "diff --staged";
      dc = "diff --cached";

      # Log
      l = "log --oneline --graph --decorate";
      lg = "log --oneline --graph --decorate --all";
      ll = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";

      # Push/Pull
      p = "push";
      pl = "pull";
      pf = "push --force-with-lease";

      # Fetch
      f = "fetch";
      fa = "fetch --all";

      # Rebase
      rb = "rebase";
      rbi = "rebase -i";
      rbc = "rebase --continue";
      rba = "rebase --abort";

      # Stash
      sh = "stash";
      shp = "stash pop";
      shl = "stash list";

      # Reset
      unstage = "reset HEAD --";
      undo = "reset --soft HEAD^";

      # Misc
      alias = "!git config --get-regexp ^alias\\. | sed -e s/^alias\\.// -e s/\\ /\\ =\\ /";
      branches = "branch -a";
      remotes = "remote -v";
      contributors = "shortlog -sn";

      # Custom workflow aliases from .gitconfig-aliases
      all = "!git submodule foreach --recursive git";
    };

    # Global gitignore
    ignores = [
      # OS generated files
      ".DS_Store"
      ".DS_Store?"
      "._*"
      ".Spotlight-V100"
      ".Trashes"
      "ehthumbs.db"
      "Thumbs.db"

      # Editor files
      "*~"
      "*.swp"
      "*.swo"
      ".*.swp"
      ".*.swo"
      "*.kate-swp"
      ".vscode/"
      ".idea/"
      "*.sublime-project"
      "*.sublime-workspace"

      # Build artifacts
      "*.o"
      "*.so"
      "*.dylib"
      "*.exe"
      "*.out"
      "*.class"

      # Logs
      "*.log"
      "npm-debug.log*"
      "yarn-debug.log*"
      "yarn-error.log*"

      # Dependencies
      "node_modules/"
      "bower_components/"
      ".bundle/"
      "vendor/bundle/"

      # Environment files
      ".env"
      ".env.local"
      ".env.*.local"

      # Testing
      "coverage/"
      ".nyc_output/"

      # Misc
      ".cache/"
      ".tmp/"
      ".temp/"
    ];

    # Git configuration
    extraConfig = {
      # Core settings
      core = {
        editor = "nvim";
        pager = "less -R";
        autocrlf = "input";
        safecrlf = false;
        whitespace = "trailing-space,space-before-tab";
      };

      # Color output
      color = {
        ui = "auto";
        branch = "auto";
        diff = "auto";
        status = "auto";
      };

      # Push settings
      push = {
        default = "simple";
        followTags = true;
        autoSetupRemote = true;
      };

      # Pull settings
      pull = {
        rebase = false;
        ff = "only";
      };

      # Fetch settings
      fetch = {
        prune = true;
        pruneTags = true;
      };

      # Rebase settings
      rebase = {
        autoStash = true;
        autoSquash = true;
      };

      # Merge settings
      merge = {
        conflictStyle = "diff3";
        ff = false;
      };

      # Diff settings
      diff = {
        algorithm = "histogram";
        colorMoved = "default";
      };

      # Init settings
      init = {
        defaultBranch = "main";
      };

      # Credential helper
      credential = {
        helper = "cache --timeout=3600";
      };

      # URL shortcuts
      url = {
        "git@github.com:" = {
          insteadOf = "gh:";
        };
        "https://github.com/" = {
          insteadOf = "github:";
        };
      };

      # Include conditional configs
      includeIf = {
        # Example: work directory specific config
        # "gitdir:~/work/" = {
        #   path = "~/.gitconfig-work";
        # };
      };
    };

    # Delta (better diff viewer)
    delta = {
      enable = true;
      options = {
        features = "decorations";
        navigate = true;
        light = false;
        side-by-side = false;
        line-numbers = true;
        syntax-theme = "base16";

        decorations = {
          commit-decoration-style = "bold yellow box ul";
          file-style = "bold yellow ul";
          file-decoration-style = "none";
        };
      };
    };

    # LFS
    lfs = {
      enable = true;
    };
  };

  # Lazygit configuration
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        theme = {
          activeBorderColor = [ "cyan" "bold" ];
          inactiveBorderColor = [ "white" ];
          selectedLineBgColor = [ "blue" ];
        };
      };
      git = {
        paging = {
          colorArg = "always";
          pager = "delta --dark --paging=never";
        };
      };
    };
  };

  # GitHub CLI
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      editor = "nvim";
      prompt = "enabled";
      pager = "less";
    };
  };
}
