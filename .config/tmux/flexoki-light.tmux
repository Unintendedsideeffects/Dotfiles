# Flexoki Light for tmux
set -g status-style fg=#3a3a3a,bg=#fffcf0
set -g message-style fg=#3a3a3a,bg=#f2eadf
set -g pane-border-style fg=#d0c9c2
set -g pane-active-border-style fg=#d14
set -g status-left '#[fg=#d14] #S '
set -g status-right '#[fg=#d14] %Y-%m-%d %H:%M '
setw -g window-status-current-format '#[fg=#fffcf0,bg=#d14] #I:#W '
setw -g window-status-format '#[fg=#3a3a3a,bg=#f2eadf] #I:#W '
