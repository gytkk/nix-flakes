{ pkgs, lib, ... }:

let
  claude = "${pkgs.master.claude-code}/bin/claude";
  timeout = "${pkgs.coreutils}/bin/timeout";

  marketplaces = [
    "anthropics/skills"
    "anthropics/claude-code"
    "anthropics/claude-plugins-official"
    "gytkk/claude-marketplace"
    "backnotprop/plannotator"
  ];

  # plugin-name@marketplace-name
  plugins = [
    # anthropics/skills — document generation (PDF, DOCX, XLSX, PPTX)
    "document-skills@anthropic-agent-skills"
    # anthropics/claude-code — git commit/push/PR workflow
    "commit-commands@claude-code-plugins"
    # anthropics/claude-code — security warning hooks
    "security-guidance@claude-code-plugins"

    "ralph-loop@claude-plugins-official"

    # anthropics/claude-plugins-official — LSP language servers
    "gopls-lsp@claude-plugins-official"
    "rust-analyzer-lsp@claude-plugins-official"
    "typescript-lsp@claude-plugins-official"

    # gytkk/claude-marketplace — custom agents, Scala LSP, Python LSP, Terraform LSP, and Nix LSP
    "metals-lsp@gytkk"
    "ty-lsp@gytkk"
    "terraform-ls@gytkk"
    "nixd-lsp@gytkk"

    # backnotprop/plannotator — visual plan annotation and review
    "plannotator@plannotator"
  ];

  mcpCommands = [
    "mcp add -s user --transport http context7 https://mcp.context7.com/mcp"
    "mcp add -s user --transport http notion https://mcp.notion.com/mcp"
  ];
in
{
  home.packages = [
    pkgs.master.claude-code

    # LSP servers for Claude Code plugins
    pkgs.gopls
    # rust-analyzer is provided by rustup (base/default.nix)
    pkgs.nodePackages.typescript-language-server
    pkgs.terraform-ls
  ];

  home.file.".claude/settings.json".source = ./files/settings.json;
  home.file.".claude/CLAUDE.md".source = ./files/CLAUDE.md;

  # Install marketplaces, plugins, and MCP servers
  home.activation.setupClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    INSTALLED_PLUGINS="$HOME/.claude/plugins/installed_plugins.json"

    # Ensure SSH_AUTH_SOCK is set (activation env may not inherit it)
    export SSH_AUTH_SOCK="''${SSH_AUTH_SOCK:-$(launchctl getenv SSH_AUTH_SOCK 2>/dev/null || echo "")}"

    # Check if SSH agent has keys loaded (needed for marketplace git clone)
    SSH_READY=true
    if ! /usr/bin/ssh-add -l >/dev/null 2>&1; then
      SSH_READY=false
      echo ""
      echo "SSH agent has no keys loaded. Marketplace operations will be skipped."
      echo "To enable marketplace plugins, run: ssh-add"
      echo "Then re-run: home-manager switch --flake .#<environment>"
      echo ""
    fi

    # Register marketplaces (requires SSH for git clone)
    if [ "$SSH_READY" = true ]; then
      ${lib.concatMapStringsSep "\n    " (mp: ''
        if ! ${timeout} 5s ${claude} plugin marketplace list 2>/dev/null | grep -q "${mp}"; then
          ${timeout} 10s ${claude} plugin marketplace add ${mp} >/dev/null 2>&1 || true
        fi'') marketplaces}
    fi

    # Install plugins (skip if already installed)
    ${lib.concatMapStringsSep "\n    " (plugin: ''
      if ! grep -q "${plugin}" "$INSTALLED_PLUGINS" 2>/dev/null; then
        ${timeout} 30s ${claude} plugin install ${plugin} >/dev/null 2>&1 || true
      fi'') plugins}

    # Register MCP servers (skip if already registered)
    ${lib.concatMapStringsSep "\n    " (
      cmd:
      let
        # Extract server name (4th token: mcp add -s user --transport http <name> <url>)
        name = builtins.elemAt (lib.splitString " " cmd) 7;
      in
      ''
        if ! ${timeout} 5s ${claude} mcp list 2>/dev/null | grep -q "${name}"; then
          ${timeout} 10s ${claude} ${cmd} >/dev/null 2>&1 || true
        fi''
    ) mcpCommands}
  '';

  # Install plannotator CLI binary (from GitHub releases, not in nixpkgs)
  # Export PATH so install.sh subprocess also has access to curl, etc.
  home.activation.installPlannotator = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if ! command -v plannotator &>/dev/null; then
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
      ${pkgs.curl}/bin/curl -fsSL https://plannotator.ai/install.sh | ${pkgs.bash}/bin/bash >/dev/null 2>&1
    fi
  '';
}
