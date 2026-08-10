{
  config,
  lib,
  pkgs,
  username,
  isWSL ? false,
  ...
}:

let
  cfg = config.modules.windowsTerminal;
  settingsPath = "/mnt/c/Users/${username}/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json";
  managedKeybindings = ./files/herdr-keybindings.json;
in
{
  options.modules.windowsTerminal.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Manage Windows Terminal settings used by WSL applications";
  };

  config = lib.mkIf (cfg.enable && isWSL) {
    home.activation.windowsTerminalHerdrKeybindings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      settings=${lib.escapeShellArg settingsPath}

      if [ ! -f "$settings" ]; then
        echo "Windows Terminal settings not found; skipping Herdr keybindings: $settings"
      else
        backup="$settings.home-manager.bak"
        tmp="$settings.home-manager.tmp"

        if ! ${pkgs.jq}/bin/jq --slurpfile managed ${lib.escapeShellArg (toString managedKeybindings)} '
          .actions = (
            (.actions // [] | map(select(
              .id != "User.herdrNextWorkspace"
              and .id != "User.herdrPreviousWorkspace"
            ))) + $managed[0].actions
          )
          | .keybindings = (
            (.keybindings // [] | map(select(
              .id != "User.herdrNextWorkspace"
              and .id != "User.herdrPreviousWorkspace"
              and ((.keys // "") | ascii_downcase) != "ctrl+tab"
              and ((.keys // "") | ascii_downcase) != "ctrl+shift+tab"
            ))) + $managed[0].keybindings
          )
        ' "$settings" > "$tmp"; then
          rm -f "$tmp"
          echo "Failed to update Windows Terminal settings: $settings" >&2
          exit 1
        fi

        if ${pkgs.diffutils}/bin/cmp -s "$settings" "$tmp"; then
          rm -f "$tmp"
        else
          if [ ! -f "$backup" ]; then
            cp "$settings" "$backup"
          fi
          chmod --reference="$settings" "$tmp"
          mv "$tmp" "$settings"
          echo "Windows Terminal Herdr keybindings updated: $settings"
        fi
      fi
    '';
  };
}
