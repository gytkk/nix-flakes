{ pkgs, ... }:

let
  keyListCommand = "{ ${pkgs.tmux}/bin/tmux list-keys -N; printf '\\n-- all bindings --\\n'; ${pkgs.tmux}/bin/tmux list-keys; } | ${pkgs.less}/bin/less -R";
in
{
  programs.tmux = {
    enable = true;
    prefix = "C-b";
    terminal = "tmux-256color";
    keyMode = "vi";
    mouse = true;
    focusEvents = true;
    historyLimit = 100000;
    clock24 = true;

    extraConfig = ''
      set -g status on
      set -g status-interval 5
      set -g status-position top
      set -g status-left-length 60
      set -g status-right-length 140
      set -g status-style "bg=colour236,fg=colour248"
      set -g status-left "#[fg=colour16,bg=colour39,bold] #S #[fg=colour39,bg=colour236,nobold] "
      set -g status-right "#[fg=colour245]C-b h help | C-b ? keys | C-b w tree #[fg=colour39]%Y-%m-%d %H:%M "
      setw -g window-status-format " #I:#W#{?window_flags,#{window_flags},} "
      setw -g window-status-current-format "#[fg=colour16,bg=colour248,bold] #I:#W#{?window_flags,#{window_flags},} #[default]"

      set -g display-time 2000
      set -g renumber-windows on
      setw -g monitor-activity on

      bind-key -N "Open tmux help menu" h display-menu -T "tmux help" \
        "Full key list" "?" { display-popup -E -w 90% -h 90% "${keyListCommand}" } \
        "" \
        "New window" "c" { new-window -c "#{pane_current_path}" } \
        "Rename window" "," { command-prompt -I "#W" "rename-window -- %%" } \
        "Choose session/window tree" "w" { choose-tree -Zw } \
        "" \
        "Split pane right" "v" { split-window -h -c "#{pane_current_path}" } \
        "Split pane down" "s" { split-window -v -c "#{pane_current_path}" } \
        "Zoom pane" "z" { resize-pane -Z } \
        "Kill pane" "x" { confirm-before -p "kill-pane #P? (y/n)" kill-pane } \
        "" \
        "Copy mode" "[" { copy-mode } \
        "Paste buffer" "]" { paste-buffer } \
        "" \
        "Command prompt" ":" { command-prompt } \
        "Reload config" "r" { source-file ~/.config/tmux/tmux.conf \; display-message "tmux config reloaded" }

      bind-key -N "Show tmux key bindings" ? display-popup -E -w 90% -h 90% "${keyListCommand}"
      bind-key -N "Reload tmux config" r source-file ~/.config/tmux/tmux.conf \; display-message "tmux config reloaded"
      bind-key -N "Split pane right in the current directory" v split-window -h -c "#{pane_current_path}"
      bind-key -N "Split pane down in the current directory" s split-window -v -c "#{pane_current_path}"
      bind-key -N "Choose a session, window, or pane" w choose-tree -Zw
      bind-key -N "Create a new window in the current directory" c new-window -c "#{pane_current_path}"

      bind-key -T copy-mode-vi v send-keys -X begin-selection
      bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
      bind-key -T copy-mode-vi Escape send-keys -X cancel
    '';
  };
}
