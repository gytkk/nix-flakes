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
    {
      name = "context7";
      cmd = "mcp add -s user --transport http context7 https://mcp.context7.com/mcp";
    }
    {
      name = "notion";
      cmd = "mcp add -s user --transport http notion https://mcp.notion.com/mcp";
    }
    {
      name = "codex";
      cmd = "mcp add -s user codex -- codex mcp-server";
    }
    {
      name = "qmd";
      cmd = "mcp add -s user qmd -- qmd mcp";
    }
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
  # Add bun global bin to PATH (for QMD installed via bun install -g)
  home.sessionPath = [
    "${config.xdg.dataHome}/bin"
    "$HOME/.cache/.bun/bin"
  ];

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

  # Install QMD via bun, set up collection, and build indexes
  home.activation.setupQmd = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # QMD internally uses node; ensure Nix nodejs is found before asdf shims
    export PATH="${lib.makeBinPath [ pkgs.nodejs ]}:$PATH"
    SETUP_LOG="$HOME/.claude/nix-setup.log"
    log() { echo "[$(date '+%H:%M:%S')] $*" >> "$SETUP_LOG"; }
    QMD="$HOME/.cache/.bun/bin/qmd"
    if [ ! -x "$QMD" ]; then
      log "Installing QMD via bun..."
      # Use system clang for native module compilation (Nix gcc doesn't support -stdlib=libc++)
      if CXX=clang++ CC=clang ${pkgs.bun}/bin/bun install -g --trust @tobilu/qmd >> "$SETUP_LOG" 2>&1; then
        log "  -> QMD installed"
      else
        log "  -> QMD install FAILED (exit $?)"
      fi
    fi
    if [ -x "$QMD" ]; then
      # Remove legacy whole-home collection if it exists
      if $QMD collection list 2>/dev/null | grep -q "^home "; then
        log "Removing legacy QMD collection: home"
        $QMD collection remove home >> "$SETUP_LOG" 2>&1
      fi
      # Register per-directory collections
      for pair in \
        "development:$HOME/development" \
        "workspace:$HOME/workspace" \
        "worktrees:$HOME/worktrees" \
        "dotconfig:$HOME/.config"; do
        name="''${pair%%:*}"
        dir="''${pair#*:}"
        if [ -d "$dir" ] && ! $QMD collection list 2>/dev/null | grep -q "^$name "; then
          log "Adding QMD collection: $name ($dir **/*.md)"
          if $QMD collection add "$dir" --name "$name" --mask "**/*.md" >> "$SETUP_LOG" 2>&1; then
            log "  -> QMD collection '$name' added"
          else
            log "  -> QMD collection '$name' add FAILED (exit $?)"
          fi
        fi
      done
    fi
    if [ -x "$QMD" ]; then
      log "Updating QMD index (BM25)..."
      if $QMD update >> "$SETUP_LOG" 2>&1; then
        log "  -> QMD index updated"
      else
        log "  -> QMD index update FAILED (exit $?)"
      fi
      log "Building QMD vector embeddings..."
      if $QMD embed >> "$SETUP_LOG" 2>&1; then
        log "  -> QMD embeddings built"
      else
        log "  -> QMD embed FAILED (exit $?)"
      fi
    fi
  '';
}
