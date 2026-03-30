{
  config,
  homeDirectory,
  lib,
  pkgs,
  ...
}:

let
  sidebarScanDir = "${homeDirectory}/.local/share/zellij/sidebar-projects";
  updateProjectSidebarScanDir = pkgs.writeShellApplication {
    name = "update-zellij-project-sidebar-scan-dir";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      scan_dir=${lib.escapeShellArg sidebarScanDir}
      mkdir -p "$scan_dir"

      for existing in "$scan_dir"/*; do
        [ -L "$existing" ] || continue
        rm -f "$existing"
      done

      for root in ${lib.escapeShellArg "${homeDirectory}/development"} ${lib.escapeShellArg "${homeDirectory}/workspace"}; do
        [ -d "$root" ] || continue
        root_name="$(basename "$root")"

        for path in "$root"/*; do
          [ -d "$path" ] || continue
          name="$(basename "$path")"
          target="$scan_dir/$name"

          if [ -e "$target" ]; then
            if [ -L "$target" ] && [ "$(readlink "$target")" = "$path" ]; then
              continue
            fi

            name="''${name}-''${root_name}"
            target="$scan_dir/$name"
            suffix=1
            while [ -e "$target" ]; do
              if [ -L "$target" ] && [ "$(readlink "$target")" = "$path" ]; then
                break
              fi
              target="$scan_dir/$name-''${suffix}"
              suffix=$((suffix + 1))
            done
          fi

          ln -sfn "$path" "$target"
        done
      done
    '';
  };
in
{
  programs.zellij = {
    enable = true;

    settings = {
      default_layout = "project-sidebar";
      theme = "ayu-light";
      show_startup_tips = false;
    };

    extraConfig = ''
      keybinds {
          shared_except "tmux" "locked" {
              unbind "Ctrl b"
          }
      }
    '';
  };

  home.activation.zellijProjectSidebarScanDir = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ${lib.getExe updateProjectSidebarScanDir}
  '';

  xdg.configFile."zellij/layouts/project-sidebar.kdl".text = ''
    layout {
        pane size=1 borderless=true {
            plugin location="zellij:tab-bar"
        }
        pane split_direction="vertical" {
            pane size="18%" name="Projects" {
                plugin location="file:${homeDirectory}/.config/zellij/plugins/zellij-project-sidebar.wasm" {
                    scan_dir "${sidebarScanDir}"
                    session_layout "${homeDirectory}/.config/zellij/layouts/project-sidebar.kdl"
                    verbosity "minimal"
                }
            }
            pane
        }
        pane size=1 borderless=true {
            plugin location="zellij:status-bar"
        }
    }
  '';

  xdg.configFile."zellij/plugins/zellij-project-sidebar.wasm".source =
    ./files/zellij-project-sidebar.wasm;
  xdg.configFile."zellij/themes/ayu-light.kdl".source = ./files/ayu-light.kdl;

  programs.zsh.initContent = lib.mkAfter ''
    if [[ -o interactive ]] \
      && [[ -z "$ZELLIJ" ]] \
      && [[ -z "$TMUX" ]] \
      && [[ -z "$SSH_CONNECTION" ]] \
      && [[ -z "$SSH_CLIENT" ]] \
      && [[ -z "$SSH_TTY" ]] \
      && { [[ "$TERM_PROGRAM" == "ghostty" ]] || [[ "$TERM_PROGRAM" == "xterm-ghostty" ]] || [[ "$TERM" == "xterm-ghostty" ]] || [[ -n "$GHOSTTY_RESOURCES_DIR" ]]; }; then
      ${lib.getExe updateProjectSidebarScanDir}
      exec ${lib.getExe config.programs.zellij.package}
    fi
  '';
}
