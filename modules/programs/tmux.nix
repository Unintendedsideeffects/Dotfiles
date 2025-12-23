{ config, pkgs, lib, ... }:

{
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    historyLimit = 10000;
    baseIndex = 1;
    keyMode = "vi";
    mouse = true;
    escapeTime = 0;

    # Prefix key
    prefix = "C-a";

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      continuum
      vim-tmux-navigator
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavour 'mocha'
        '';
      }
    ];

    extraConfig = ''
      # True color support
      set -g default-terminal "screen-256color"
      set -ga terminal-overrides ",*256col*:Tc"
      set -ga terminal-overrides '*:Ss=\E[%p1%d q:Se=\E[ q'
      set-environment -g COLORTERM "truecolor"

      # Enable RGB colour if running in xterm(1)
      set-option -sa terminal-overrides ",xterm*:Tc"

      # Window and pane numbering
      set -g base-index 1
      setw -g pane-base-index 1
      set -g renumber-windows on

      # Activity monitoring
      setw -g monitor-activity on
      set -g visual-activity off

      # Set status bar position
      set -g status-position top

      # Increase display time for messages
      set -g display-time 2000

      # Vi mode
      set-window-option -g mode-keys vi
      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel

      # Split panes using | and -
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # Reload config
      bind r source-file ~/.config/tmux/tmux.conf \; display-message "Config reloaded..."

      # Switch panes using Alt-arrow without prefix
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Switch windows using Shift-arrow without prefix
      bind -n S-Left previous-window
      bind -n S-Right next-window

      # Resize panes
      bind -r H resize-pane -L 5
      bind -r J resize-pane -D 5
      bind -r K resize-pane -U 5
      bind -r L resize-pane -R 5

      # Synchronize panes
      bind S set-window-option synchronize-panes

      # Clear screen and scrollback
      bind C-l send-keys 'C-l' \; clear-history

      # Create new window in current path
      bind c new-window -c "#{pane_current_path}"

      # Continuum settings
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '15'

      # Resurrect settings
      set -g @resurrect-strategy-nvim 'session'
      set -g @resurrect-capture-pane-contents 'on'
    '';
  };
}
