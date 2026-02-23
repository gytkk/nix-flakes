{
  config,
  pkgs,
  lib,
  ...
}:

let
  claude = "${pkgs.claude-code}/bin/claude";
  timeout = "${pkgs.coreutils}/bin/timeout";
  jq = "${pkgs.jq}/bin/jq";

  marketplaces = [
    "anthropics/skills"
    "anthropics/claude-code"
    "anthropics/claude-plugins-official"
    "gytkk/claude-marketplace"
    "backnotprop/plannotator"
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

    # gytkk/claude-marketplace — Codex skills, Scala LSP, Python LSP, Terraform LSP, and Nix LSP
    "codex@gytkk"
    "metals-lsp@gytkk"
    "ty-lsp@gytkk"
    "terraform-ls@gytkk"
    "nixd-lsp@gytkk"
  ];

  mcpCommands = [
    "mcp add -s user --transport http context7 https://mcp.context7.com/mcp"
    "mcp add -s user --transport http notion https://mcp.notion.com/mcp"
  ];
in
{
  home.packages = [
    pkgs.claude-code

    # rust-analyzer is provided by rustup (base/default.nix)
    pkgs.nodePackages.typescript-language-server
    pkgs.terraform-ls
  ];

  # Add XDG data bin to PATH (for plannotator CLI installed via install.sh)
  home.sessionPath = [ "${config.xdg.dataHome}/bin" ];

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

    SETUP_LOG="$HOME/.claude/nix-setup.log"
    SETTINGS_FILE="$HOME/.claude/settings.json"

    log() { echo "[$(date '+%H:%M:%S')] $*" >> "$SETUP_LOG"; }
    log "=== Claude Code setup started ==="

    # Remove read-only symlink from previous nix setup
    if [ -L "$SETTINGS_FILE" ]; then
      rm "$SETTINGS_FILE"
      log "Removed settings.json symlink"
    fi

    # Merge nix settings into existing settings.json (nix takes precedence)
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    if [ -f "$SETTINGS_FILE" ]; then
      ${jq} -s '.[0] * .[1]' "$SETTINGS_FILE" ${./files/settings.json} > "$SETTINGS_FILE.tmp"
      mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"
      log "Merged settings.json"
    else
      cp ${./files/settings.json} "$SETTINGS_FILE"
      chmod 644 "$SETTINGS_FILE"
      log "Copied initial settings.json"
    fi

    INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"

    # Cache marketplace list once to avoid repeated calls
    # All claude commands use < /dev/null to prevent SIGTTIN when timeout(1)
    # creates a new process group (background group reading from tty = stopped)
    MARKETPLACE_CACHE=$(${timeout} 15s ${claude} plugin marketplace list < /dev/null 2>/dev/null || echo "")

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
      cmd:
      let
        # Extract server name: mcp add -s user --transport http <name> <url>
        #                       0    1  2  3     4          5    6      7
        name = builtins.elemAt (lib.splitString " " cmd) 6;
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

    log "=== Claude Code setup finished ==="
  '';

  # Install plannotator CLI binary (from GitHub releases, not in nixpkgs)
  # Binary installs to ${XDG_DATA_HOME}/bin/plannotator via install.sh
  home.activation.installPlannotator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PLANNOTATOR_BIN="${config.xdg.dataHome}/bin/plannotator"
    SETUP_LOG="$HOME/.claude/nix-setup.log"
    if [ ! -x "$PLANNOTATOR_BIN" ]; then
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
      echo "[$(date '+%H:%M:%S')] Installing plannotator CLI..." >> "$SETUP_LOG"
      if ${pkgs.curl}/bin/curl -fsSL https://plannotator.ai/install.sh | ${pkgs.bash}/bin/bash >> "$SETUP_LOG" 2>&1; then
        echo "[$(date '+%H:%M:%S')] plannotator installed to $PLANNOTATOR_BIN" >> "$SETUP_LOG"
      else
        echo "[$(date '+%H:%M:%S')] plannotator installation FAILED (exit $?)" >> "$SETUP_LOG"
      fi
    fi
  '';
}
