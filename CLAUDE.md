# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Precedence**: General development rules (commit workflow, security, testing, etc.) are defined in the global `~/.claude/CLAUDE.md`. This file contains project-specific rules and reference documentation. **Project-specific rules take precedence** over global rules when they conflict.

## Operational Rules

### Critical Rules

- DO NOT use git worktree for this repository
- Follow existing code patterns and module structure in this repository
- Use `nixfmt` to format all Nix files before committing (delegate to subagent using sonnet model)
- Run `nix flake check` only for complex changes (multi-module, architecture changes); skip for simple edits unless explicitly requested
- Do NOT push unless explicitly requested

### Documentation Guidelines

- All documentation belongs in:
  - CLAUDE.md - Primary source of truth for development guidelines
  - README.md - User-facing documentation
  - Code comments - Only when absolutely necessary
  - Commit messages - For change history
- When you work on markdown files, ensure they are following markdownlint rules

### Security

- Use agenix for secrets management (see [Secrets Management](#secrets-management-agenix) for details)
- Secrets decrypt to `/run/agenix/<secretName>`

### Build/Test/Lint Commands

**Agent-safe commands** (Claude Code can run these directly):

```bash
nixfmt <file.nix>                  # Format Nix files
nixfmt **/*.nix                    # Format all Nix files
nix flake show                     # Show available flake outputs
nix flake check --no-build         # Validate syntax without building

# Only for complex changes (multi-module, flake outputs, architecture-level):
nix flake check                    # Full validation including builds

# Check evaluation errors for a specific environment:
nix eval .#homeConfigurations.pylv-denim.config.home.packages --apply 'x: map (p: p.name) x'
```

**User-run commands** (ask the user to run these):

```bash
home-manager build --flake .#pylv-denim
home-manager build --flake .#pylv-sepia
home-manager build --flake .#devsisters-macbook
home-manager build --flake .#devsisters-macstudio
home-manager switch --flake .#<environment>
nixos-rebuild build --flake .#pylv-sepia
nixos-rebuild switch --flake .#pylv-sepia
```

---

## Reference

### Nix Code Style Guidelines

#### File Structure

```nix
{
  config,
  lib,
  pkgs,
  username,           # Custom args from extraSpecialArgs
  homeDirectory,
  inputs,
  isWSL ? false,      # Optional parameters with defaults
  ...
}:

let
  cfg = config.modules.moduleName;
in
{
  # Main configuration body
}
```

#### Imports

```nix
imports = [
  ../modules/claude
  ../modules/git
];
```

- Use relative paths for imports within the repository
- Import directories containing `default.nix` by directory name

#### Formatting Rules

- Opening brace `{` on same line for function parameters
- One attribute per line in attribute sets
- Semicolons at end of each attribute
- Closing brace `}` on separate line
- Use 2-space indentation (enforced by nixfmt)
- Use `with pkgs;` for package lists

#### Naming Conventions

| Type              | Convention      | Example                               |
| ----------------- | --------------- | ------------------------------------- |
| Variables         | camelCase       | `terraformPackages`, `defaultVersion` |
| Module options    | camelCase       | `enable`, `runEnv`, `versions`        |
| Files             | lowercase       | `default.nix`, `home.nix`             |
| Directories       | lowercase/kebab | `modules/`, `base/devsisters/`        |
| Environment names | kebab-case      | `pylv-denim`, `devsisters-macbook`    |

#### Module Pattern

```nix
let
  cfg = config.modules.moduleName;
in
{
  options.modules.moduleName = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable this module";
    };
  };

  config = lib.mkIf cfg.enable {
    # Configuration when enabled
  };
}
```

#### Package Lists

```nix
home.packages = with pkgs; [
  packageName
  pkgs.stable-25_05.ruby_3_2     # Specific nixpkgs version
  pkgs.claude-code                # claude-code-nix flake
  (pkgs.writeShellScriptBin "script-name" ''
    script content
  '')
];
```

#### Conditional Configuration

```nix
config = lib.mkIf cfg.enable { ... };                              # Single condition
lib.mkMerge [ (lib.mkIf (!isWSL) { ... }) (lib.mkIf isWSL { ... }) ] # Multiple
programs.git.settings.user.email = lib.mkForce "x@example.com";    # Force override
```

#### Environment Definition (environments.nix)

```nix
{
  "environment-name" = {
    baseProfile = "company";       # Required: determines base config
    system = "x86_64-linux";       # Required: architecture
    username = "user";             # Required: user account
    homeDirectory = "/home/user";  # Required: home path
    isWSL = true;                  # Optional: WSL detection
    # flakeDirectory is auto-derived: ${homeDirectory}/development/nix-flakes
    extraModules = [ ./extra.nix ]; # Optional: additional modules
  };
}
```

### Architecture

This is a Nix flakes-based Home Manager configuration supporting multiple environments (macOS and Linux). The configuration uses a layered base system with company-specific customizations.

#### Directory Structure

```text
flake.nix                         # Main flake configuration
environments.nix                  # All environment definitions
hosts.nix                         # NixOS host definitions
base/default.nix                  # Common configuration for all environments
base/<company>/home.nix           # Company-specific extensions
modules/<name>/default.nix        # Reusable module
hosts/<name>/configuration.nix    # NixOS host configuration
lib/builders.nix                  # mkHomeConfig, mkNixOSConfig helpers
overlays/default.nix              # nixpkgs version overlays (nixpkgs-versions)
secrets/secrets.nix               # Agenix secrets configuration
```

#### Environment Configurations

All environments are defined in `environments.nix`:

- **`devsisters-macbook`**: ARM64 macOS (gyutak@/Users/gyutak) with devsisters base profile
- **`devsisters-macstudio`**: ARM64 macOS (gyutak@/Users/gyutak) with devsisters base profile
- **`pylv-denim`**: x86_64 Linux/WSL (gytkk@/home/gytkk) with pylv base profile
- **`pylv-sepia`**: x86_64 Linux/NixOS server (gytkk@/home/gytkk) with pylv base profile

#### NixOS Host Configurations

NixOS hosts are defined in `hosts.nix`:

- **`pylv-sepia`**: x86_64 Linux NixOS server with Disko, agenix, Home Manager, copyparty, and OpenClaw AI gateway (NixOS system service via `services.openclaw-gateway`)

#### Base System Architecture

The layered base system provides inheritance and customization:

1. **`base/default.nix`**: Common configuration imported by all company bases
   - Core modules (claude, ghostty, git, k9s, lsp, opencode, terraform, vim, vscode, zed, zsh)
   - Standard development packages
   - Basic programs configuration

2. **`base/devsisters/home.nix`**: Extends base with Devsisters-specific tools
   - Authentication tools (saml2aws, vault)
   - Scala, Ruby, Databricks CLI
   - Custom scripts (login, sign)
   - Company-specific aliases and environment variables

3. **`base/pylv/home.nix`**: Extends base with minimal Pylv-specific configuration
   - Currently inherits base configuration
   - Ready for company-specific customizations

4. **`base/pylv/sepia.nix`**: Environment-specific config for pylv-sepia NixOS server
   - Currently minimal (OpenClaw moved to NixOS system service)
   - Only imported by pylv-sepia environment via `extraModules`

### Module System

Each module in `modules/` manages a specific tool or application. **When asked to modify settings for any tool (VSCode, Zed, Git, etc.), always look in the corresponding module directory first.**

#### Module Structure Pattern

```text
modules/<name>/
├── default.nix          # Main module configuration (ALWAYS exists)
├── files/               # Static config files deployed to home directory
│   ├── settings.json    # JSON configuration files
│   └── *.md             # Markdown files (instructions, agents)
├── themes/              # Custom themes (JSON, TOML)
├── agents/              # AI agent definitions (for AI tools)
├── skills/              # Skill definitions (for AI tools)
└── README.md            # Module documentation (optional)
```

#### Quick Module Reference

| Module       | Purpose                  | Config Location                              | Key Files                                | Mutable |
| ------------ | ------------------------ | -------------------------------------------- | ---------------------------------------- | ------- |
| `claude/`    | Claude Code AI assistant | `~/.claude/`                                 | `files/settings.json`, `files/CLAUDE.md`    | 부분적  |
| `codex/`     | OpenAI Codex CLI         | `~/.codex/`                                  | `files/config.toml`, `files/AGENTS.md`      | YES     |
| `ghostty/`   | Ghostty terminal         | `~/.config/ghostty/`                         | `files/config`                              | YES     |
| `git/`       | Git configuration        | `~/.gitconfig`                               | `default.nix`                               | NO      |
| `helix/`     | Helix editor             | `~/.config/helix/`                           | `files/config.toml`                         | YES     |
| `k9s/`       | Kubernetes manager       | `~/.config/k9s/`                             | `default.nix`                               | NO      |
| `lsp/`       | LSP server packages      | system PATH                                  | `default.nix`                               | NO      |
| `opencode/`  | OpenCode AI agent        | `~/.config/opencode/`                        | `files/opencode.json`, `files/AGENTS.md`    | YES     |
| `terraform/` | Terraform versions       | direnv lazy-load                             | `default.nix`                               | NO      |
| `vim/`       | Neovim                   | `~/.config/nvim/`                            | `files/config/init.lua`, `files/onelight.lua` | YES     |
| `vscode/`    | VSCode editor (DISABLED) | `~/.config/Code/`                            | `default.nix`, `themes/`                    | NO      |
| `zed/`       | Zed editor               | `~/Library/Application Support/Zed/` (macOS) | `files/settings.json`, `themes/`            | YES     |
| `zsh/`       | Zsh shell                | `~/.zshrc`                                   | `default.nix`, `starship.toml`              | NO      |

> **Mutable**: `mkOutOfStoreSymlink`을 사용해 설정 파일이 repo로 직접 symlink됨.
> 앱 UI에서 자유롭게 수정 가능하며, 변경이 즉시 repo에 반영됨. `nfc` alias로 빠르게 커밋.

#### How to Find and Modify Settings

**Step 1**: Identify the module

```bash
ls modules/  # See available modules
```

**Step 2**: Check module structure

```bash
ls -la modules/<name>/  # See files in the module
```

**Step 3**: Locate the setting

- **Nix options** (packages, enable flags, program settings) → `default.nix`
- **Static config files** (JSON, TOML, YAML) → `files/` or root of module
- **Themes** → `themes/` directory
- **AI agents/skills** → `agents/` or `skills/` directories

**Step 4**: Make the change and validate

```bash
nix flake check --no-build  # Validate syntax
# Ask user to run: home-manager switch --flake .#<environment>
```

### Editor Configurations

#### Neovim Module (`modules/vim/`)

| File                    | Purpose                                                        |
| ----------------------- | -------------------------------------------------------------- |
| `default.nix`           | programs.neovim setup, symlink configuration                   |
| `files/config/init.lua` | Full Neovim config: plugins, LSP, keybindings (mutable)        |
| `files/onelight.lua`    | Custom onelight colorscheme (mutable)                          |

**Architecture**: `programs.neovim.initLua` bootstraps with `require('config')`. Actual config lives in `files/config/` symlinked to `~/.config/nvim/lua/config/` via `mkOutOfStoreSymlink`. Changes take effect on Neovim restart without `home-manager switch`.

**Common modification scenarios**:

- Change editor settings → Edit `files/config/init.lua` → `vim.cmd` block at top
- Add/modify plugins → Edit `files/config/init.lua` → `lazy.setup` spec
- Add LSP server → Edit `files/config/init.lua` → `servers` table + add binary to `modules/lsp/default.nix`
- Change colorscheme → Edit `files/onelight.lua`

#### VSCode Module (`modules/vscode/`) - DISABLED

> **Status**: This module is currently **disabled** (`enable = false`). Zed is the primary editor.
>
> **AI Assistant Note**: When the user requests VSCode-related modifications, **ask first** whether to re-enable the module before making changes. To re-enable, set `modules.vscode.enable = true` in the appropriate base or environment configuration.

| File                    | Purpose                                                                |
| ----------------------- | ---------------------------------------------------------------------- |
| `default.nix`           | Extensions, settings, keybindings (via Home Manager `programs.vscode`) |
| `one-half-light-theme/` | Custom theme package                                                   |

**Common modification scenarios**:

- Add/remove extension → Edit `default.nix` → `programs.vscode.extensions`
- Change settings → Edit `default.nix` → `programs.vscode.userSettings`
- Add keybinding → Edit `default.nix` → `programs.vscode.keybindings`
- Modify theme → Edit `one-half-light-theme/themes/one-half-light.json`

#### Zed Module (`modules/zed/`)

| File                         | Purpose                                                   |
| ---------------------------- | --------------------------------------------------------- |
| `default.nix`                | Extensions, platform paths, symlink setup                 |
| `files/settings.json`        | Editor settings (mutable, symlinked to Zed config path)   |
| `files/keymap.json`          | Keybindings (mutable, symlinked to Zed config path)       |
| `themes/one-half-light.json` | Custom theme definition (mutable, symlinked to Zed theme) |

**Common modification scenarios**:

- Change editor settings → Edit `files/settings.json` directly (or from Zed UI)
- Change theme → Edit `themes/one-half-light.json` directly
- Add keybinding → Edit `files/keymap.json` directly (or from Zed UI)
- Add extensions → Edit `default.nix` → `nixExtensions` list (uses `pkgs.zed-extensions`)

**Note**: Settings, keymaps, themes are JSON files symlinked to the repo via `mkOutOfStoreSymlink`. Editable from Zed UI, changes are immediately reflected in the repo.

#### Ghostty Module (`modules/ghostty/`)

| File           | Purpose                                                      |
| -------------- | ------------------------------------------------------------ |
| `default.nix`  | Theme symlinks, config symlink setup                         |
| `files/config` | Terminal settings (mutable, symlinked to Ghostty config dir) |

**Common modification scenarios**:

- Change font → Edit `files/config` → `font-family`
- Change theme/colors → Edit `files/config`
- Add keybindings → Edit `files/config`

#### Zsh Module (`modules/zsh/`)

| File            | Purpose                                               |
| --------------- | ----------------------------------------------------- |
| `default.nix`   | Shell config, aliases, plugins, environment variables |
| `starship.toml` | Starship prompt theme configuration                   |

**Common modification scenarios**:

- Add alias → Edit `default.nix` → `programs.zsh.shellAliases`
- Add environment variable → Edit `default.nix` → `programs.zsh.sessionVariables`
- Change prompt → Edit `starship.toml`
- Add shell initialization → Edit `default.nix` → `programs.zsh.initContent`

### AI Coding Agent Configurations

When updating AI coding agent settings (agents, tools, skills, MCP servers, etc.), **modify the global configuration files in these modules** rather than local project files. Changes here apply globally across all projects.

#### Claude Code Module (`modules/claude/`)

Global configuration for Claude Code (Anthropic's AI coding assistant).

| File                  | Purpose                                        | Deployed To               |
| --------------------- | ---------------------------------------------- | ------------------------- |
| `files/settings.json` | Model selection, permissions, MCP settings     | `~/.claude/settings.json` |
| `files/CLAUDE.md`     | Global development guidelines for Claude Code  | `~/.claude/CLAUDE.md`     |

**Plugins** are managed via marketplace system and [gytkk/claude-marketplace](https://github.com/gytkk/claude-marketplace):

- `document-skills`, `commit-commands`, `security-guidance` (official plugins)
- `ralph-loop` (official plugin)
- LSP plugins: `gopls-lsp`, `rust-analyzer-lsp`, `typescript-lsp`, `metals-lsp`, `ty-lsp`, `terraform-ls`, `nixd-lsp`
- `plannotator`: Visual plan annotation, review, and team sharing — CLI auto-installed via activation script

> **Note**: Each LSP plugin requires its corresponding binary on `PATH`.
> LSP binaries are centralized in `modules/lsp/default.nix`.

**Common modification scenarios**:

- Add new MCP server → Edit `default.nix` (MCP servers configured via activation script)
- Add new pre-approved tool → Edit `files/settings.json` → `permissions.allow`
- Change default model → Edit `files/settings.json` → `model`
- Update global guidelines → Edit `files/CLAUDE.md`
- Add/modify plugins → Edit [gytkk/claude-marketplace](https://github.com/gytkk/claude-marketplace) repo

#### OpenCode Module (`modules/opencode/`)

Global configuration for OpenCode (open-source AI coding agent).

| File                             | Purpose                                    | Deployed To                                   |
| -------------------------------- | ------------------------------------------ | --------------------------------------------- |
| `files/opencode.json`           | Model, theme, plugins, MCP settings        | `~/.config/opencode/opencode.json`            |
| `files/oh-my-opencode.json`     | Oh-My-OpenCode agent/category model config | `~/.config/opencode/oh-my-opencode.json`      |
| `files/AGENTS.md`               | Global instructions for OpenCode behavior  | `~/.config/opencode/AGENTS.md`                |
| `files/agents/*.md`             | Custom agent definitions                   | `~/.config/opencode/agents/`                  |
| `files/plugins/native-notify.ts` | Terminal notification plugin              | `~/.config/opencode/plugins/native-notify.ts` |

**Custom Agents** (in `files/agents/`):

- `troubleshoot.md`: Troubleshooting agent

**Common modification scenarios**:

- Add new MCP server → Edit `files/opencode.json` → `mcp`
- Add new plugin → Edit `files/opencode.json` → `plugin`
- Change default model → Edit `files/opencode.json` → `model`
- Update global instructions → Edit `files/AGENTS.md`
- Create new custom agent → Add `files/agents/{agent-name}.md`

### Terraform Version Management

Terraform uses **lazy loading** - only the default version is installed during `home-manager switch`. Other versions are loaded on-demand via direnv.

```bash
# Default terraform (configured in modules.terraform.defaultVersion)
terraform version
```

#### Directory-specific Terraform Versions (with direnv)

Create `.envrc` files in Terraform project directories:

```bash
echo "use_terraform" > .envrc
direnv allow
```

The `use_terraform` function automatically:

- Reads `required_version` from backend.tf/versions.tf/main.tf
- If different from default, loads the version via nix-direnv (cached in /nix/store)
- First load builds the version; subsequent loads are instant

### Secrets Management (agenix)

This repository uses [agenix](https://github.com/ryantm/agenix) for managing secrets in NixOS configurations.

```bash
# Edit or create a secret (opens $EDITOR)
agenix -e secrets/secret-name.age

# Re-encrypt all secrets after adding new keys
agenix -r
```

**Workflow:**

1. Add public keys to `secrets/secrets.nix`
2. Define which keys can decrypt each secret
3. Create encrypted secret: `agenix -e secrets/my-secret.age`
4. Reference in NixOS config:

   ```nix
   age.secrets.mySecret.file = ../../secrets/my-secret.age;
   # Decrypted file available at /run/agenix/mySecret
   ```

### Package Management

Base packages defined in `base/default.nix`:

- **Nix**: nixfmt
- **System**: coreutils, findutils, gnupg, libiconv, direnv, tmux, less, wget, curl
- **Development**: docker, gcc, awscli2, jq, yq-go, fd, ripgrep
- **Git**: git, gh, lazygit, delta, bat
- **JavaScript/TypeScript**: nodejs, bun, typescript, pnpm, turbo
- **Go**: go
- **Python**: uv, ruff
- **Rust**: rustup
- **Kubernetes**: kubectl, kubectx, helm (k9s is provided via `modules/k9s` program module)
- **Secrets**: 1password-cli, keybase
- **Media**: ffmpeg, yt-dlp
- **ML**: micromamba
- **Fonts**: nerd-fonts (fira-code, jetbrains-mono), sarasa-gothic

LSP server packages (centralized in `modules/lsp/`):

- nixd, gopls, typescript-language-server, terraform-ls, metals, ty, yaml-language-server, marksman
- rust-analyzer is provided by rustup (not in modules/lsp)

Company-specific packages:

- **Devsisters**: saml2aws, vault, databricks-cli, scala_2_12, ruby_3_2, custom scripts (login, sign)
- **Pylv**: Currently none (inherits base only)

### Adding New Environments

To add a new company or environment:

1. **Add base configuration** (if new company):

   ```bash
   mkdir base/new-company
   # Create base/new-company/home.nix that imports ../default.nix
   ```

2. **Add environment to `environments.nix`**:

   ```nix
   "new-environment" = {
     baseProfile = "new-company";
     system = "aarch64-darwin";
     username = "user";
     homeDirectory = "/Users/user";
   };
   ```

3. **Test the configuration**:

   ```bash
   home-manager build --flake .#new-environment
   ```

### Codex Skills (Marketplace Plugin)

Codex MCP integration skills are managed as the `codex` plugin in [gytkk/claude-marketplace](https://github.com/gytkk/claude-marketplace). Install via `claude plugin install codex@gytkk`.

#### Prerequisites

- Codex CLI installed: `npm install -g @openai/codex`
- Codex MCP server registered (auto-registered in nix-flakes `modules/claude/default.nix`)

#### Usage

```bash
/codex:critic "<original user request>"      # Verify code/plans/content
/codex:hephaestus "<task objective>"          # Autonomous deep worker
/codex:analyze "<analysis target>"            # General-purpose deep analysis
```

#### How It Works

- Registers `codex mcp-server` as an MCP server, providing `mcp__codex__codex` and `mcp__codex__codex-reply` tools
- **Critic**: Collects review targets from git diff, explicit content, or conversation context and requests Codex review
- **Hephaestus**: Delegates complex implementation tasks to Codex for autonomous explore → plan → execute → verify
- **Analyze**: Performs deep analysis on code, logs, errors, performance, etc. to deliver structured insights
- Thread-based conversations enable iterative refinement (previous context retained)
- Session-scoped unique IDs isolate result files: `~/.ai/{skill}-{SESSION_ID}-result.json`
