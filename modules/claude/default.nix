{
  config,
  pkgs,
  lib,
  flakeDirectory,
  ...
}:

let
  claude = "${pkgs.claude-code}/bin/claude";
  timeout = "${pkgs.coreutils}/bin/timeout --foreground";
  marketplaces = [
    "anthropics/skills"
    "anthropics/claude-code"
    "anthropics/claude-plugins-official"
    "gytkk/claude-marketplace"
    "backnotprop/plannotator"
    "openai/codex-plugin-cc"
    "thedotmack/claude-mem"
  ];

  # plugin-name@marketplace-name
  plugins = [
    "document-skills@anthropic-agent-skills"
    "commit-commands@claude-code-plugins"
    "security-guidance@claude-code-plugins"

    "ralph-loop@claude-plugins-official"

    "gopls-lsp@claude-plugins-official"
    "rust-analyzer-lsp@claude-plugins-official"
    "typescript-lsp@claude-plugins-official"

    # backnotprop/plannotator — visual plan annotation and review
    "plannotator@plannotator"

    # openai/codex-plugin-cc — Official Codex plugin for Claude Code
    "codex@openai-codex"

    # thedotmack/claude-mem — persistent memory compression for Claude Code
    "claude-mem@claude-mem"

    # gytkk/claude-marketplace — Scala LSP, Python LSP, Terraform LSP, and Nix LSP
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
    {
      name = "notion";
      cmd = "mcp add -s user --transport http notion https://mcp.notion.com/mcp";
    }
  ];
in
{
  home.packages = [
    pkgs.claude-code
  ];

  # Add XDG data bin to PATH (for plannotator CLI installed via install.sh)
  home.sessionPath = [
    "${config.xdg.dataHome}/bin"
  ];

  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/claude/files/settings.json";
  home.file.".claude/CLAUDE.md".source = ./files/CLAUDE.md;
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
      if ! echo "$MARKETPLACE_CACHE" | grep -qF "${mp}"; then
        log "Adding marketplace: ${mp}"
        if ${timeout} 60s ${claude} plugin marketplace add ${mp} < /dev/null >> "$SETUP_LOG" 2>&1; then
          log "  -> OK"
        else
          log "  -> FAILED (exit $?)"
        fi
      else
        log "Marketplace already registered: ${mp}"
      fi'') marketplaces}

    # Refresh marketplace index after adding new ones
    log "Updating marketplace index..."
    ${timeout} 30s ${claude} plugin marketplace update < /dev/null >> "$SETUP_LOG" 2>&1 || log "Marketplace update failed"

    # Install or update plugins
    ${lib.concatMapStringsSep "\n    " (plugin: ''
      if ! grep -qF "${plugin}" "$INSTALLED_PLUGINS" 2>/dev/null; then
        log "Installing plugin: ${plugin}"
        if ${timeout} 60s ${claude} plugin install ${plugin} < /dev/null >> "$SETUP_LOG" 2>&1; then
          log "  -> OK"
        else
          log "  -> FAILED (exit $?)"
        fi
      else
        log "Updating plugin: ${plugin}"
        if ${timeout} 60s ${claude} plugin update ${plugin} < /dev/null >> "$SETUP_LOG" 2>&1; then
          log "  -> OK"
        else
          log "  -> FAILED (exit $?)"
        fi
      fi'') plugins}

    # Cache MCP server list once to avoid repeated calls
    MCP_CACHE=$(${timeout} 15s ${claude} mcp list < /dev/null 2>/dev/null || echo "")

    # Register MCP servers (skip if already registered)
    ${lib.concatMapStringsSep "\n    " (
      mp:
      let
        name = mp.name;
        cmd = mp.cmd;
      in
      ''
        if ! echo "$MCP_CACHE" | grep -qF "${name}"; then
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

  # Install plannotator CLI binary (from GitHub releases, not in nixpkgs)
  # Binary installs to ${XDG_DATA_HOME}/bin/plannotator via install.sh
  home.activation.installPlannotator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PLANNOTATOR_BIN="${config.xdg.dataHome}/bin/plannotator"
    PLANNOTATOR_VERSION_FILE="${config.xdg.dataHome}/bin/.plannotator-version"
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

    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$PLANNOTATOR_BIN")"

    LATEST_TAG=""
    NEEDS_INSTALL=0
    if [ ! -x "$PLANNOTATOR_BIN" ]; then
      NEEDS_INSTALL=1
    else
      # Check latest version from GitHub
      LATEST_TAG=$(${pkgs.curl}/bin/curl -fsSL "https://api.github.com/repos/backnotprop/plannotator/releases/latest" 2>/dev/null | ${pkgs.gnugrep}/bin/grep '"tag_name"' | ${pkgs.coreutils}/bin/cut -d'"' -f4)
      LOCAL_VERSION=""
      if [ -f "$PLANNOTATOR_VERSION_FILE" ]; then
        LOCAL_VERSION=$(${pkgs.coreutils}/bin/cat "$PLANNOTATOR_VERSION_FILE")
      fi
      if [ -n "$LATEST_TAG" ] && [ "$LATEST_TAG" != "$LOCAL_VERSION" ]; then
        NEEDS_INSTALL=1
        echo "[$(date '+%H:%M:%S')] plannotator update available: $LOCAL_VERSION -> $LATEST_TAG" >> "$SETUP_LOG"
      fi
    fi

    if [ "$NEEDS_INSTALL" = "1" ]; then
      echo "[$(date '+%H:%M:%S')] Installing plannotator CLI..." >> "$SETUP_LOG"
      # install.sh installs to $HOME/.local/bin; copy to XDG_DATA_HOME/bin afterwards
      if ${pkgs.curl}/bin/curl -fsSL https://plannotator.ai/install.sh | ${pkgs.bash}/bin/bash >> "$SETUP_LOG" 2>&1; then
        # Copy to XDG data bin if install.sh installed to a different location
        INSTALL_SH_BIN="$HOME/.local/bin/plannotator"
        if [ -x "$INSTALL_SH_BIN" ] && [ "$INSTALL_SH_BIN" != "$PLANNOTATOR_BIN" ]; then
          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$PLANNOTATOR_BIN")"
          ${pkgs.coreutils}/bin/cp -f "$INSTALL_SH_BIN" "$PLANNOTATOR_BIN"
        fi
        # Record installed version
        if [ -n "$LATEST_TAG" ]; then
          echo "$LATEST_TAG" > "$PLANNOTATOR_VERSION_FILE"
          echo "[$(date '+%H:%M:%S')] plannotator installed ($LATEST_TAG) to $PLANNOTATOR_BIN" >> "$SETUP_LOG"
        else
          INSTALLED_TAG=$(${pkgs.curl}/bin/curl -fsSL "https://api.github.com/repos/backnotprop/plannotator/releases/latest" 2>/dev/null | ${pkgs.gnugrep}/bin/grep '"tag_name"' | ${pkgs.coreutils}/bin/cut -d'"' -f4)
          if [ -n "$INSTALLED_TAG" ]; then
            echo "$INSTALLED_TAG" > "$PLANNOTATOR_VERSION_FILE"
          fi
          echo "[$(date '+%H:%M:%S')] plannotator installed ($INSTALLED_TAG) to $PLANNOTATOR_BIN" >> "$SETUP_LOG"
        fi
      else
        echo "[$(date '+%H:%M:%S')] plannotator installation FAILED (exit $?)" >> "$SETUP_LOG"
      fi
    fi
  '';

}
