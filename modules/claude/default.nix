{
  config,
  pkgs,
  lib,
  flakeDirectory,
  ...
}:

let
  cfg = config.modules.claude;
  claude = "${pkgs.claude-code}/bin/claude";
  timeout = "${pkgs.coreutils}/bin/timeout --foreground";
  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/claude/${path}";
  marketplaces = [
    "anthropics/skills"
    "anthropics/claude-code"
    "anthropics/claude-plugins-official"
    "backnotprop/plannotator"
    "openai/codex-plugin-cc"
  ];

  # Local marketplaces sourced from the flake working tree.
  # Each entry is registered via `claude plugin marketplace add <path>`.
  localMarketplaces = [
    {
      name = "gytkk";
      path = "${flakeDirectory}/modules/claude/marketplace";
    }
  ];

  # plugin-name@marketplace-name
  plugins = [
    "document-skills@anthropic-agent-skills"
    "commit-commands@claude-code-plugins"
    "security-guidance@claude-code-plugins"

    "ralph-loop@claude-plugins-official"
    "superpowers@claude-plugins-official"

    "gopls-lsp@claude-plugins-official"
    "rust-analyzer-lsp@claude-plugins-official"
    "typescript-lsp@claude-plugins-official"

    # backnotprop/plannotator — visual plan annotation and review
    "plannotator@plannotator"

    # openai/codex-plugin-cc — Official Codex plugin for Claude Code
    "codex@openai-codex"

    # local gytkk marketplace (modules/claude/marketplace) — skills and LSP plugins
    "devils-advocate@gytkk"
    "metals-lsp@gytkk"
    "ty-lsp@gytkk"
    "terraform-ls@gytkk"
    "nixd-lsp@gytkk"
  ];

  mcpCommands = [
    {
      name = "context7";
      cmd = "mcp add -s user --transport http context7 https://mcp.context7.com/mcp";
    }
  ];
  removedMcpServers = [
    "notion"
  ];
in
{
  options.modules.claude.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable Claude Code module";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.claude-code
    ];

    # Add ~/.local/bin to PATH (plannotator install.sh installs here)
    home.sessionPath = [
      "${config.home.homeDirectory}/.local/bin"
    ];

    # Claude plugin operations may temporarily leave this as a regular file.
    home.file.".claude/settings.json" = {
      source = mkSymlink "files/settings.json";
      force = true;
    };
    home.file.".claude/CLAUDE.md".source = mkSymlink "files/CLAUDE.md";
    home.file.".claude/statusline-command.sh" = {
      source = ./files/statusline-command.sh;
      executable = true;
    };
    # Install marketplaces, plugins, and MCP servers
    home.activation.setupClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      # Ensure git, ssh, and which are available for plugin marketplace operations
      # (activation PATH only includes bash, coreutils, jq, etc.)
      export PATH="${
        lib.makeBinPath (
          with pkgs;
          [
            git
            openssh
            which
          ]
        )
      }:$PATH"

      ${pkgs.coreutils}/bin/mkdir -p "$HOME/.claude"
      SETUP_LOG="$HOME/.claude/nix-setup.log"

      log() { echo "[$(date '+%H:%M:%S')] $*" >> "$SETUP_LOG"; }
      log "=== Claude Code setup started ==="

      INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"

      # Pre-flight: verify Claude Code authentication by listing marketplaces.
      # --foreground prevents timeout(1) from creating a new process group,
      # which avoids SIGTTIN when child processes (git) open /dev/tty.
      if ! MARKETPLACE_CACHE=$(${timeout} 15s ${claude} plugin marketplace list < /dev/null 2>/dev/null); then
        log "ERROR: Claude Code auth check failed (marketplace list timed out or errored)."
        log "  Skipping all plugin/marketplace/MCP setup."
        log "  Run 'claude auth login' to re-authenticate, then retry 'home-manager switch'."
      else

      # Register marketplaces (failures are non-fatal)
      ${lib.concatMapStringsSep "\n    " (mp: ''
        if ! printf '%s\n' "$MARKETPLACE_CACHE" | ${pkgs.ripgrep}/bin/rg -q --fixed-strings -- "${mp}"; then
          log "Adding marketplace: ${mp}"
          if ${timeout} 60s ${claude} plugin marketplace add ${mp} < /dev/null >> "$SETUP_LOG" 2>&1; then
            log "  -> OK"
          else
            log "  -> FAILED (exit $?)"
          fi
        else
          log "Marketplace already registered: ${mp}"
        fi'') marketplaces}

      # Register local marketplaces (filesystem-sourced).
      # If a same-named marketplace was previously registered from GitHub,
      # remove it first so the local path takes over without name collision.
      KNOWN_MARKETPLACES="$HOME/.claude/plugins/known_marketplaces.json"
      ${lib.concatMapStringsSep "\n    " (mp: ''
        LOCAL_MP_NAME=${lib.escapeShellArg mp.name}
        LOCAL_MP_PATH=${lib.escapeShellArg mp.path}
        EXISTING_SOURCE=""
        EXISTING_PATH=""
        if [ -f "$KNOWN_MARKETPLACES" ]; then
          EXISTING_SOURCE=$(${pkgs.jq}/bin/jq -r --arg n "$LOCAL_MP_NAME" '.[$n].source.source // ""' "$KNOWN_MARKETPLACES" 2>/dev/null || echo "")
          EXISTING_PATH=$(${pkgs.jq}/bin/jq -r --arg n "$LOCAL_MP_NAME" '.[$n].source.path // ""' "$KNOWN_MARKETPLACES" 2>/dev/null || echo "")
        fi
        if [ "$EXISTING_SOURCE" = "github" ]; then
          log "Removing stale github marketplace: $LOCAL_MP_NAME"
          ${timeout} 30s ${claude} plugin marketplace remove "$LOCAL_MP_NAME" < /dev/null >> "$SETUP_LOG" 2>&1 || log "  -> remove FAILED (exit $?)"
          EXISTING_SOURCE=""
          EXISTING_PATH=""
        fi
        if [ "$EXISTING_PATH" != "$LOCAL_MP_PATH" ]; then
          log "Adding local marketplace: $LOCAL_MP_NAME -> $LOCAL_MP_PATH"
          if ${timeout} 60s ${claude} plugin marketplace add "$LOCAL_MP_PATH" < /dev/null >> "$SETUP_LOG" 2>&1; then
            log "  -> OK"
          else
            log "  -> FAILED (exit $?)"
          fi
        else
          log "Local marketplace already registered: $LOCAL_MP_NAME"
        fi'') localMarketplaces}

      # Refresh marketplace index after adding new ones
      log "Updating marketplace index..."
      ${timeout} 30s ${claude} plugin marketplace update < /dev/null >> "$SETUP_LOG" 2>&1 || log "Marketplace update failed"

      # Temporarily run plugin install/update against a copy so activation
      # does not mutate the repository-backed settings symlink.
      SETTINGS_FILE="$HOME/.claude/settings.json"
      SETTINGS_LINK_TARGET=""
      if [ -L "$SETTINGS_FILE" ]; then
        SETTINGS_LINK_TARGET=$(${pkgs.coreutils}/bin/readlink -f "$SETTINGS_FILE")
        ${pkgs.coreutils}/bin/cp --remove-destination "$SETTINGS_LINK_TARGET" "$SETTINGS_FILE"
        log "Temporarily made settings.json writable for plugin operations"
      fi

      # Install or update plugins. Always pin to user scope: a project-scope-only
      # install causes Claude Code to re-prompt the install in every other project,
      # and the previous substring check on installed_plugins.json could not tell
      # project-scope entries apart from user-scope ones.
      ${lib.concatMapStringsSep "\n    " (plugin: ''
        HAS_USER_SCOPE=0
        if [ -f "$INSTALLED_PLUGINS" ]; then
          if [ "$(${pkgs.jq}/bin/jq -r --arg p "${plugin}" '
                (.plugins[$p] // []) | map(select(.scope == "user")) | length
              ' "$INSTALLED_PLUGINS" 2>/dev/null)" != "0" ]; then
            HAS_USER_SCOPE=1
          fi
        fi
        if [ "$HAS_USER_SCOPE" = "0" ]; then
          log "Installing plugin (user scope): ${plugin}"
          if ${timeout} 60s ${claude} plugin install -s user ${plugin} < /dev/null >> "$SETUP_LOG" 2>&1; then
            log "  -> OK"
          else
            log "  -> FAILED (exit $?)"
          fi
        else
          log "Updating plugin (user scope): ${plugin}"
          if ${timeout} 60s ${claude} plugin update -s user ${plugin} < /dev/null >> "$SETUP_LOG" 2>&1; then
            log "  -> OK"
          else
            log "  -> FAILED (exit $?)"
          fi
        fi'') plugins}

      # Restore settings.json symlink
      if [ -n "$SETTINGS_LINK_TARGET" ]; then
        ${pkgs.coreutils}/bin/ln -sf "$SETTINGS_LINK_TARGET" "$SETTINGS_FILE"
        log "Restored settings.json symlink"
      fi

      # Cache MCP server list once to avoid repeated calls
      MCP_CACHE=$(${timeout} 15s ${claude} mcp list < /dev/null 2>/dev/null || echo "")

      # Remove MCP servers that are no longer managed here.
      ${lib.concatMapStringsSep "\n    " (name: ''
        if printf '%s\n' "$MCP_CACHE" | ${pkgs.ripgrep}/bin/rg -q --fixed-strings -- "${name}"; then
          log "Removing MCP server: ${name}"
          if ${timeout} 30s ${claude} mcp remove -s user ${name} < /dev/null >> "$SETUP_LOG" 2>&1; then
            log "  -> OK"
            MCP_CACHE=$(${timeout} 15s ${claude} mcp list < /dev/null 2>/dev/null || echo "")
          else
            log "  -> FAILED (exit $?)"
          fi
        fi'') removedMcpServers}

      # Register MCP servers (skip if already registered)
      ${lib.concatMapStringsSep "\n    " (
        mp:
        let
          name = mp.name;
          cmd = mp.cmd;
        in
        ''
          if ! printf '%s\n' "$MCP_CACHE" | ${pkgs.ripgrep}/bin/rg -q --fixed-strings -- "${name}"; then
            log "Adding MCP server: ${name}"
            if ${timeout} 30s ${claude} ${cmd} < /dev/null >> "$SETUP_LOG" 2>&1; then
              log "  -> OK"
            else
              log "  -> FAILED (exit $?)"
            fi
          else
            log "MCP server already registered: ${name}"
          fi''
      ) mcpCommands}

      fi # end auth check

      # Fix permissions on all shell scripts in plugins (Claude Code doesn't preserve +x)
      log "Fixing plugin script permissions..."
      if [ -d "$HOME/.claude/plugins" ]; then
        find "$HOME/.claude/plugins" -type f -name "*.sh" ! -perm -111 -exec chmod +x {} + 2>/dev/null || true
        PLUGIN_SCRIPTS=$(find "$HOME/.claude/plugins" -type f -name "*.sh" 2>/dev/null | wc -l)
        log "  -> Fixed permissions for $PLUGIN_SCRIPTS shell scripts"
      fi

      log "=== Claude Code setup finished ==="
    '';

    # Install plannotator CLI binary (from GitHub releases, not in nixpkgs).
    # install.sh hardcodes INSTALL_DIR="$HOME/.local/bin" and does not honor
    # an env override, so we just consume that location directly.
    home.activation.installPlannotator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      PLANNOTATOR_BIN="$HOME/.local/bin/plannotator"
      PLANNOTATOR_VERSION_FILE="$HOME/.local/bin/.plannotator-version"
      SETUP_LOG="$HOME/.claude/nix-setup.log"
      export PATH="${
        lib.makeBinPath (
          with pkgs;
          [
            curl
            coreutils
            gnugrep
            gawk
            perl
          ]
        )
      }:$PATH"
      ${pkgs.coreutils}/bin/mkdir -p "$HOME/.claude" "$HOME/.local/bin"

      fetchLatestPlannotatorTag() {
        ${pkgs.curl}/bin/curl -fsSL "https://api.github.com/repos/backnotprop/plannotator/releases/latest" 2>/dev/null \
          | ${pkgs.gnugrep}/bin/grep '"tag_name"' \
          | ${pkgs.coreutils}/bin/cut -d'"' -f4 \
          || true
      }

      LATEST_TAG=""
      NEEDS_INSTALL=0
      if [ ! -x "$PLANNOTATOR_BIN" ]; then
        NEEDS_INSTALL=1
      else
        # Check latest version from GitHub
        LATEST_TAG="$(fetchLatestPlannotatorTag)"
        LOCAL_VERSION=""
        if [ -f "$PLANNOTATOR_VERSION_FILE" ]; then
          LOCAL_VERSION="$(${pkgs.coreutils}/bin/cat "$PLANNOTATOR_VERSION_FILE" 2>/dev/null || true)"
        fi
        if [ -n "$LATEST_TAG" ] && [ "$LATEST_TAG" != "$LOCAL_VERSION" ]; then
          NEEDS_INSTALL=1
          echo "[$(date '+%H:%M:%S')] plannotator update available: $LOCAL_VERSION -> $LATEST_TAG" >> "$SETUP_LOG"
        fi
      fi

      if [ "$NEEDS_INSTALL" = "1" ]; then
        echo "[$(date '+%H:%M:%S')] Installing plannotator CLI..." >> "$SETUP_LOG"
        if ${pkgs.curl}/bin/curl -fsSL https://plannotator.ai/install.sh | ${pkgs.bash}/bin/bash >> "$SETUP_LOG" 2>&1; then
          # Record installed version
          if [ -n "$LATEST_TAG" ]; then
            echo "$LATEST_TAG" > "$PLANNOTATOR_VERSION_FILE"
            echo "[$(date '+%H:%M:%S')] plannotator installed ($LATEST_TAG) to $PLANNOTATOR_BIN" >> "$SETUP_LOG"
          else
            INSTALLED_TAG="$(fetchLatestPlannotatorTag)"
            if [ -n "$INSTALLED_TAG" ]; then
              echo "$INSTALLED_TAG" > "$PLANNOTATOR_VERSION_FILE"
            fi
            echo "[$(date '+%H:%M:%S')] plannotator installed ($INSTALLED_TAG) to $PLANNOTATOR_BIN" >> "$SETUP_LOG"
          fi
        else
          echo "[$(date '+%H:%M:%S')] plannotator installation FAILED (exit $?)" >> "$SETUP_LOG"
        fi
      fi

      # One-shot migration: remove legacy XDG-bin copy from the pre-cleanup
      # layout. No-op once cleaned up.
      LEGACY_BIN="${config.xdg.dataHome}/bin/plannotator"
      if [ -e "$LEGACY_BIN" ]; then
        ${pkgs.coreutils}/bin/rm -f "$LEGACY_BIN" "${config.xdg.dataHome}/bin/.plannotator-version"
        echo "[$(date '+%H:%M:%S')] Removed legacy $LEGACY_BIN" >> "$SETUP_LOG"
      fi
    '';
  };
}
