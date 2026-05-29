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
  codex = "${pkgs.codex}/bin/codex";
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/codex/${path}";
  codexStopUploadCommand = "${config.home.homeDirectory}/.local/bin/codex-stop-upload";
  codexSessionStartSweepCommand = "${config.home.homeDirectory}/.local/bin/codex-session-start-sweep";
  plannotatorCommand = "${config.home.homeDirectory}/.local/bin/plannotator";
  codexHooksJson =
    builtins.replaceStrings
      [
        "~/.local/bin/codex-session-start-sweep"
        "~/.local/bin/codex-stop-upload"
        "~/.local/bin/plannotator"
      ]
      [
        codexSessionStartSweepCommand
        codexStopUploadCommand
        plannotatorCommand
      ]
      (builtins.readFile ./files/hooks.json);
  codexConfigPath = "${config.home.homeDirectory}/.codex/config.toml";
  legacySystemCodexConfigPath = "/etc/codex/config.toml";
  systemCodexConfigPath = "/etc/codex/managed_config.toml";
  systemCodexSkillsPath = "/etc/codex/skills";
  systemCodexConfigDirectory = "/etc/codex";
  managedConfigSource =
    if hasSystemCodexConfig then
      ./files/config.toml
    else
      "${flakeDirectory}/modules/codex/files/config.toml";
  managedSkillsSource =
    if hasSystemCodexConfig then ./skills else "${flakeDirectory}/modules/codex/skills";
  coreutils = pkgs.coreutils;
  ensureSystemCodexConfigFunction =
    if hasSystemCodexConfig then
      ""
    else
      ''
        ensure_system_symlink() {
          local destination="$1"
          local desired_target="$2"
          local current_target=""

          if [ -L "$destination" ]; then
            current_target="$(${coreutils}/bin/readlink "$destination" || true)"
          elif [ -e "$destination" ]; then
            errorEcho "$destination exists and is not a symlink. Move it aside and rerun home-manager switch."
            exit 1
          fi

          if [ "$current_target" = "$desired_target" ]; then
            return 0
          fi

          run "$sudo_bin" ${coreutils}/bin/rm -f "$destination"
          run "$sudo_bin" ${coreutils}/bin/ln -s "$desired_target" "$destination"

          if [ -n "''${DRY_RUN:-}" ]; then
            return 0
          fi

          current_target="$(${coreutils}/bin/readlink "$destination" || true)"
          if [ "$current_target" != "$desired_target" ]; then
            errorEcho "Expected $destination to point to $desired_target, got '$current_target'."
            exit 1
          fi
        }

        ensure_system_codex_config() {
          local config_target=${lib.escapeShellArg managedConfigSource}
          local skills_target=${lib.escapeShellArg managedSkillsSource}
          local sudo_bin=""
          local needs_update=0
          local current_target=""
          local legacy_target=""

          if [ -L ${lib.escapeShellArg systemCodexConfigPath} ]; then
            current_target="$(${coreutils}/bin/readlink ${lib.escapeShellArg systemCodexConfigPath} || true)"
            if [ "$current_target" != "$config_target" ]; then
              needs_update=1
            fi
          elif [ -e ${lib.escapeShellArg systemCodexConfigPath} ]; then
            errorEcho "${systemCodexConfigPath} exists and is not a symlink. Move it aside and rerun home-manager switch."
            exit 1
          else
            needs_update=1
          fi

          if [ -L ${lib.escapeShellArg systemCodexSkillsPath} ]; then
            current_target="$(${coreutils}/bin/readlink ${lib.escapeShellArg systemCodexSkillsPath} || true)"
            if [ "$current_target" != "$skills_target" ]; then
              needs_update=1
            fi
          elif [ -e ${lib.escapeShellArg systemCodexSkillsPath} ]; then
            errorEcho "${systemCodexSkillsPath} exists and is not a symlink. Move it aside and rerun home-manager switch."
            exit 1
          else
            needs_update=1
          fi

          if [ -L ${lib.escapeShellArg legacySystemCodexConfigPath} ]; then
            legacy_target="$(${coreutils}/bin/readlink ${lib.escapeShellArg legacySystemCodexConfigPath} || true)"
            if [ -n "$legacy_target" ]; then
              needs_update=1
            fi
          elif [ -e ${lib.escapeShellArg legacySystemCodexConfigPath} ]; then
            errorEcho "${legacySystemCodexConfigPath} exists and is not a symlink. Move it aside and rerun home-manager switch."
            exit 1
          fi

          if [ "$needs_update" != "1" ]; then
            return 0
          fi

          for candidate in /run/wrappers/bin/sudo /usr/bin/sudo /bin/sudo; do
            if [ -x "$candidate" ]; then
              sudo_bin="$candidate"
              break
            fi
          done

          if [ -z "$sudo_bin" ]; then
            errorEcho "Could not find sudo while managing /etc/codex."
            exit 1
          fi

          if ! "$sudo_bin" -n true 2>/dev/null && ! [ -t 0 ] && ! [ -t 1 ] && ! [ -t 2 ]; then
            errorEcho "Managing /etc/codex requires sudo, but no interactive terminal is available."
            errorEcho "Rerun home-manager switch from an interactive shell or refresh sudo credentials first."
            exit 1
          fi

          run "$sudo_bin" ${coreutils}/bin/mkdir -p ${lib.escapeShellArg systemCodexConfigDirectory}
          if [ -n "$legacy_target" ]; then
            run "$sudo_bin" ${coreutils}/bin/rm -f ${lib.escapeShellArg legacySystemCodexConfigPath}
          fi

          ensure_system_symlink ${lib.escapeShellArg systemCodexConfigPath} "$config_target"
          ensure_system_symlink ${lib.escapeShellArg systemCodexSkillsPath} "$skills_target"
        }
      '';
  codexUserConfigActivation = ''
    ${coreutils}/bin/mkdir -p "$HOME/.codex"

    if [ ! -e ${lib.escapeShellArg codexConfigPath} ]; then
      : > ${lib.escapeShellArg codexConfigPath}
      ${coreutils}/bin/chmod 600 ${lib.escapeShellArg codexConfigPath}
    fi
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
    home.file.".codex/hooks.json".text = codexHooksJson;

    home.activation.codexUserConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${ensureSystemCodexConfigFunction}
      ${lib.optionalString (!hasSystemCodexConfig) "ensure_system_codex_config"}
      ${codexUserConfigActivation}
    '';

    home.activation.setupCodexPlugins = lib.hm.dag.entryAfter [ "codexUserConfig" ] ''
      export PATH="${lib.makeBinPath (with pkgs; [ git ])}:$PATH"

      ${coreutils}/bin/mkdir -p "$HOME/.codex"
      SETUP_LOG="$HOME/.codex/nix-setup.log"
      SUPERPOWERS_REPO="$HOME/.codex/superpowers"
      SUPERPOWERS_SKILLS_DIR="$HOME/.agents/skills"
      SUPERPOWERS_SKILL_LINK="$SUPERPOWERS_SKILLS_DIR/superpowers"

      log() { echo "[$(${coreutils}/bin/date '+%H:%M:%S')] $*" >> "$SETUP_LOG"; }

      cleanup_fallback_link() {
        if [ -L "$SUPERPOWERS_SKILL_LINK" ]; then
          current_target="$(${coreutils}/bin/readlink "$SUPERPOWERS_SKILL_LINK" || true)"
          if [ "$current_target" = "$SUPERPOWERS_REPO/skills" ]; then
            ${coreutils}/bin/rm -f "$SUPERPOWERS_SKILL_LINK"
          fi
        fi
      }

      install_fallback_skills() {
        log "Falling back to upstream Codex skill discovery install"
        if [ -d "$SUPERPOWERS_REPO/.git" ]; then
          git -C "$SUPERPOWERS_REPO" pull --ff-only >> "$SETUP_LOG" 2>&1 || return 1
        elif [ -e "$SUPERPOWERS_REPO" ]; then
          log "  -> FAILED: $SUPERPOWERS_REPO exists but is not a git checkout"
          return 1
        else
          git clone https://github.com/obra/superpowers.git "$SUPERPOWERS_REPO" >> "$SETUP_LOG" 2>&1 || return 1
        fi

        if [ ! -d "$SUPERPOWERS_REPO/skills" ]; then
          log "  -> FAILED: $SUPERPOWERS_REPO/skills is missing"
          return 1
        fi
        if [ -e "$SUPERPOWERS_SKILL_LINK" ] && [ ! -L "$SUPERPOWERS_SKILL_LINK" ]; then
          log "  -> FAILED: $SUPERPOWERS_SKILL_LINK exists and is not a symlink"
          return 1
        fi

        ${coreutils}/bin/mkdir -p "$SUPERPOWERS_SKILLS_DIR"
        ${coreutils}/bin/ln -sfn "$SUPERPOWERS_REPO/skills" "$SUPERPOWERS_SKILL_LINK"
        log "  -> OK: linked $SUPERPOWERS_SKILL_LINK"
      }

      log "=== Codex plugin setup started ==="
      log "Installing plugin: superpowers@openai-curated"
      if ${codex} plugin add superpowers@openai-curated < /dev/null >> "$SETUP_LOG" 2>&1; then
        cleanup_fallback_link
        log "  -> OK"
      else
        log "  -> FAILED (exit $?)"
        install_fallback_skills || log "  -> fallback FAILED"
      fi
      log "=== Codex plugin setup finished ==="
    '';
  };
}
