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
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/codex/${path}";
  codexConfigPath = "${config.home.homeDirectory}/.codex/config.toml";
  legacySystemCodexConfigPath = "/etc/codex/config.toml";
  systemCodexConfigPath = "/etc/codex/managed_config.toml";
  systemCodexConfigDirectory = "/etc/codex";
  managedConfigSource =
    if hasSystemCodexConfig then
      ./files/config.toml
    else
      "${flakeDirectory}/modules/codex/files/config.toml";
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
  ensureSystemCodexConfigFunction =
    if hasSystemCodexConfig then
      ""
    else
      ''
        ensure_system_codex_config() {
          local desired_target=${lib.escapeShellArg managedConfigSource}
          local current_target=""
          local legacy_target=""
          local sudo_bin=""

          if [ -L ${lib.escapeShellArg systemCodexConfigPath} ]; then
            current_target="$(${coreutils}/bin/readlink ${lib.escapeShellArg systemCodexConfigPath} || true)"
          elif [ -e ${lib.escapeShellArg systemCodexConfigPath} ]; then
            errorEcho "${systemCodexConfigPath} exists and is not a symlink. Move it aside and rerun home-manager switch."
            exit 1
          fi

          if [ "$current_target" = "$desired_target" ]; then
            return 0
          fi

          for candidate in /run/wrappers/bin/sudo /usr/bin/sudo /bin/sudo; do
            if [ -x "$candidate" ]; then
              sudo_bin="$candidate"
              break
            fi
          done

          if [ -z "$sudo_bin" ]; then
            errorEcho "Could not find sudo while managing ${systemCodexConfigPath}."
            exit 1
          fi

          if ! "$sudo_bin" -n true 2>/dev/null && ! [ -t 0 ] && ! [ -t 1 ] && ! [ -t 2 ]; then
            errorEcho "Managing ${systemCodexConfigPath} requires sudo, but no interactive terminal is available."
            errorEcho "Rerun home-manager switch from an interactive shell or refresh sudo credentials first."
            exit 1
          fi

          run "$sudo_bin" ${coreutils}/bin/mkdir -p ${lib.escapeShellArg systemCodexConfigDirectory}
          if [ -L ${lib.escapeShellArg legacySystemCodexConfigPath} ]; then
            legacy_target="$(${coreutils}/bin/readlink ${lib.escapeShellArg legacySystemCodexConfigPath} || true)"
            if [ -n "$legacy_target" ]; then
              run "$sudo_bin" ${coreutils}/bin/rm -f ${lib.escapeShellArg legacySystemCodexConfigPath}
            fi
          elif [ -e ${lib.escapeShellArg legacySystemCodexConfigPath} ]; then
            errorEcho "${legacySystemCodexConfigPath} exists and is not a symlink. Move it aside and rerun home-manager switch."
            exit 1
          fi

          run "$sudo_bin" ${coreutils}/bin/ln -sfn "$desired_target" ${lib.escapeShellArg systemCodexConfigPath}

          if [ -n "''${DRY_RUN:-}" ]; then
            return 0
          fi

          current_target="$(${coreutils}/bin/readlink ${lib.escapeShellArg systemCodexConfigPath} || true)"
          if [ "$current_target" != "$desired_target" ]; then
            errorEcho "Expected ${systemCodexConfigPath} to point to $desired_target, got '$current_target'."
            exit 1
          fi
        }
      '';
  codexUserConfigActivation = ''
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

    home.file.".codex/AGENTS.md".source = mkSymlink "files/AGENTS.md";
    home.file.".codex/hooks.json".source = mkSymlink "files/hooks.json";

    home.activation.codexUserConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${extractProjectsFunction}
      ${ensureSystemCodexConfigFunction}
      ${lib.optionalString (!hasSystemCodexConfig) "ensure_system_codex_config"}
      ${codexUserConfigActivation}
    '';
  };
}
