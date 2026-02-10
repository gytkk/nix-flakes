{ pkgs, lib, ... }:

let
  claude = "${pkgs.master.claude-code}/bin/claude";

  mcpCommands = [
    "mcp add -s user --transport http context7 https://mcp.context7.com/mcp"
    "mcp add -s user --transport http notion https://mcp.notion.com/mcp"
  ];

  marketplaceCommands = [
    "plugin marketplace add anthropics/skills"
    "plugin marketplace add anthropics/claude-code"
    "plugin marketplace add anthropics/claude-plugins-official"
    "plugin marketplace add gytkk/claude-marketplace"
  ];

  pluginCommands = [
    # anthropics/skills — document generation (PDF, DOCX, XLSX, PPTX)
    "plugin install document-skills@anthropic-agent-skills"
    # anthropics/claude-code — git commit/push/PR workflow
    "plugin install commit-commands@claude-code-plugins"
    # anthropics/claude-code — security warning hooks
    "plugin install security-guidance@claude-code-plugins"

    # anthropics/claude-plugins-official — LSP language servers
    "plugin install gopls-lsp@claude-plugins-official"
    "plugin install rust-analyzer-lsp@claude-plugins-official"
    "plugin install typescript-lsp@claude-plugins-official"

    # gytkk/claude-marketplace — custom agents, Scala LSP, Python LSP, Terraform LSP, and Nix LSP
    "plugin install metals-lsp@gytkk"
    "plugin install ty-lsp@gytkk"
    "plugin install terraform-ls@gytkk"
    "plugin install nixd-lsp@gytkk"
  ];

  allCommands = mcpCommands ++ marketplaceCommands ++ pluginCommands;
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

  home.activation.setupClaudeCode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${lib.concatMapStringsSep "\n" (cmd: "${claude} ${cmd}") allCommands}
  '';
}
