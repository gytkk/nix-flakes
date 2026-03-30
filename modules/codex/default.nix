{
  config,
  pkgs,
  lib,
  flakeDirectory,
  hasSystemCodexConfig ? false,
  ...
}:

let
  cfg = config.modules.codex;
  codexConfigPath = "${config.home.homeDirectory}/.codex/config.toml";
  managedConfigSource = "${flakeDirectory}/modules/codex/files/config.toml";
  coreutils = pkgs.coreutils;
  extractProjectsFunction = ''
    extract_projects() {
      local src="$1"

      if [ ! -r "$src" ]; then
        return 0
      fi

      ${pkgs.gawk}/bin/awk '
        BEGIN {
          in_projects = 0
          printed = 0
        }
        /^\[projects\.".*"\][[:space:]]*$/ {
          if (printed == 1) {
            print ""
          }

          print
          in_projects = 1
          printed = 1
          next
        }
        /^\[/ {
          in_projects = 0
        }
        in_projects {
          print
        }
      ' "$src"
    }
  '';
  codexUserConfigActivation =
    if hasSystemCodexConfig then
      ''
        ${coreutils}/bin/mkdir -p "$HOME/.codex"

        projects_tmp="$(${coreutils}/bin/mktemp)"
        extract_projects ${lib.escapeShellArg codexConfigPath} > "$projects_tmp"

        ${coreutils}/bin/rm -f ${lib.escapeShellArg codexConfigPath}

        if [ -s "$projects_tmp" ]; then
          ${coreutils}/bin/install -m 600 "$projects_tmp" ${lib.escapeShellArg codexConfigPath}
        else
          : > ${lib.escapeShellArg codexConfigPath}
          ${coreutils}/bin/chmod 600 ${lib.escapeShellArg codexConfigPath}
        fi

        ${coreutils}/bin/rm -f "$projects_tmp"
      ''
    else
      ''
        ${coreutils}/bin/mkdir -p "$HOME/.codex"

        base_tmp="$(${coreutils}/bin/mktemp)"
        projects_tmp="$(${coreutils}/bin/mktemp)"

        ${coreutils}/bin/cp ${lib.escapeShellArg managedConfigSource} "$base_tmp"
        extract_projects ${lib.escapeShellArg codexConfigPath} > "$projects_tmp"

        if [ -s "$projects_tmp" ]; then
          printf '\n' >> "$base_tmp"
          ${coreutils}/bin/cat "$projects_tmp" >> "$base_tmp"
        fi

        ${coreutils}/bin/rm -f ${lib.escapeShellArg codexConfigPath}
        ${coreutils}/bin/install -m 600 "$base_tmp" ${lib.escapeShellArg codexConfigPath}
        ${coreutils}/bin/rm -f "$base_tmp" "$projects_tmp"
      '';
in
{
  options.modules.codex = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Codex CLI module";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ pkgs.codex ];

    home.file.".codex/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/codex/files/AGENTS.md";

    home.activation.codexUserConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${extractProjectsFunction}
      ${codexUserConfigActivation}
    '';
  };
}
