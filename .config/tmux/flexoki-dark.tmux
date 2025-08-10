# Flexoki Dark for tmux
set -g status-style fg=#d3c6aa,bg=#100f0f
set -g message-style fg=#d3c6aa,bg=#1d1c1c
set -g pane-border-style fg=#403e3d
set -g pane-active-border-style fg=#ffb454
set -g status-left '#[fg=#ffb454] #S '
set -g status-right '#[fg=#ffb454] %Y-%m-%d %H:%M '
setw -g window-status-current-format '#[fg=#100f0f,bg=#ffb454] #I:#W '
setw -g window-status-format '#[fg=#d3c6aa,bg=#1d1c1c] #I:#W '
