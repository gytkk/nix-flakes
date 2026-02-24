# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Operational Rules

### Critical Rules

- DO NOT use git worktree for this repository
- Follow existing code patterns and module structure in this repository
- Use `nixfmt` to format all Nix files before committing (delegate to subagent using sonnet model)
- Do NOT run build tests directly - ask the user to test instead (builds can take several minutes)
- Run `nix flake check` only for complex changes (multi-module, architecture changes); skip for simple edits unless explicitly requested
- Do NOT push unless explicitly requested

### Documentation Guidelines

- **NO ONE-OFF DOCUMENTATION FILES**: Do not create temporary or one-off documentation files (e.g., CHANGES.md, NOTES.md, etc.)
- All documentation belongs in:
  - CLAUDE.md - Primary source of truth for development guidelines
  - README.md - User-facing documentation
  - Code comments - Only when absolutely necessary
  - Commit messages - For change history
- If you need to document something, update the appropriate existing file
- When you work on markdown files, ensure they are following markdownlint rules

### Git Conventions

- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `refactor:`
- Write in imperative mood: "Add feature" not "Added feature"
- Keep commits atomic: one logical change per commit
- Commit changes after completing a logical unit of work (when possible)

### Security

- Never commit secrets or credentials
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
- **`pylv-sepia`**: x86_64 Linux/NixOS server (gytkk@/home/gytkk) with pylv base profile + OpenClaw

#### NixOS Host Configurations

NixOS hosts are defined in `hosts.nix`:

- **`pylv-sepia`**: x86_64 Linux NixOS server with Disko, agenix, Home Manager, copyparty, and OpenClaw AI gateway

#### Base System Architecture

The layered base system provides inheritance and customization:

1. **`base/default.nix`**: Common configuration imported by all company bases
   - Core modules (claude, ghostty, git, k9s, openclaw, opencode, terraform, vim, vscode, zed, zsh)
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
   - OpenClaw AI gateway (Discord integration enabled)
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

| Module       | Purpose                  | Config Location                              | Key Files                                               |
| ------------ | ------------------------ | -------------------------------------------- | ------------------------------------------------------- |
| `claude/`    | Claude Code AI assistant | `~/.claude/`                                 | `files/settings.json`, `files/CLAUDE.md`                |
| `codex/`     | OpenAI Codex CLI         | `~/.codex/`                                  | `files/config.toml`, `files/AGENTS.md`                  |
| `ghostty/`   | Ghostty terminal         | `~/.config/ghostty/`                         | `default.nix` (inline config)                           |
| `git/`       | Git configuration        | `~/.gitconfig`                               | `default.nix`                                           |
| `k9s/`       | Kubernetes manager       | `~/.config/k9s/`                             | `default.nix`                                           |
| `openclaw/`  | OpenClaw AI gateway      | Systemd/Launchd service                      | `default.nix`                                           |
| `opencode/`  | OpenCode AI agent        | `~/.config/opencode/`                        | `files/opencode.json`, `files/AGENTS.md`                |
| `terraform/` | Terraform versions       | direnv lazy-load                             | `default.nix`                                           |
| `vim/`       | Neovim                   | `~/.config/nvim/`                            | `default.nix`                                           |
| `vscode/`    | VSCode editor (DISABLED) | `~/.config/Code/`                            | `default.nix`, `themes/`                                |
| `zed/`       | Zed editor               | `~/Library/Application Support/Zed/` (macOS) | `default.nix`, `themes/`                                |
| `zsh/`       | Zsh shell                | `~/.zshrc`                                   | `default.nix`, `starship.toml`                          |

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

| File                         | Purpose                                                 |
| ---------------------------- | ------------------------------------------------------- |
| `default.nix`                | All settings defined inline in `userSettings` attribute |
| `themes/one-half-light.json` | Custom theme definition                                 |

**Common modification scenarios**:

- Change editor settings → Edit `default.nix` → `userSettings` attribute set
- Modify vim settings → Edit `default.nix` → `userSettings.vim`
- Change theme → Edit `default.nix` → `userSettings.theme` or `themes/one-half-light.json`
- Add language config → Edit `default.nix` → `userSettings.languages`
- Add LSP config → Edit `default.nix` → `userSettings.lsp`
- Add extensions → Edit `default.nix` → `nixExtensions` list (uses `pkgs.zed-extensions`)

**Note**: Zed settings are defined as Nix attribute sets in `default.nix`, not separate JSON files. The module converts them to JSON automatically.

#### Ghostty Module (`modules/ghostty/`)

| File          | Purpose                              |
| ------------- | ------------------------------------ |
| `default.nix` | All terminal settings defined inline |

**Common modification scenarios**:

- Change font → Edit `default.nix` → `programs.ghostty.settings.font-family`
- Change theme/colors → Edit `default.nix` → `programs.ghostty.settings`
- Add keybindings → Edit `default.nix` → `programs.ghostty.settings`

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
> LSP binaries are installed via `home.packages` in `modules/claude/default.nix`.

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

- **Nix**: nixfmt, nixd
- **System**: coreutils, findutils, gnupg, libiconv, direnv, tmux, less, wget, curl
- **Development**: docker, gcc, awscli2, jq, yq-go, ripgrep
- **Git**: git, gh, lazygit, delta, bat
- **JavaScript/TypeScript**: nodejs, bun, typescript, pnpm, turbo
- **Go**: go, gopls
- **Python**: uv package manager, ty type checker
- **Rust**: rustup
- **Kubernetes**: kubectl, kubectx, helm (k9s is provided via `modules/k9s` program module)
- **Secrets**: 1password-cli, keybase
- **Media**: ffmpeg, yt-dlp
- **ML**: micromamba
- **Fonts**: nerd-fonts (fira-code, jetbrains-mono), sarasa-gothic

Company-specific packages:

- **Devsisters**: saml2aws, vault, databricks-cli, scala_2_12, metals, ruby_3_2, custom scripts (login, sign)
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

Codex MCP 통합 스킬은 [gytkk/claude-marketplace](https://github.com/gytkk/claude-marketplace)의
`codex` 플러그인으로 관리됩니다. `claude plugin install codex@gytkk`로 설치됩니다.

#### Prerequisites

- Codex CLI 설치: `npm install -g @openai/codex`
- Codex MCP 서버 등록 (nix-flakes `modules/claude/default.nix`에서 자동 등록)

#### 사용법

```bash
/codex:critic "<원래 사용자 요청>"      # 코드/계획/콘텐츠 검증
/codex:hephaestus "<작업 목표 설명>"    # 자율적 딥 워커
/codex:analyze "<분석 대상 설명>"       # 범용 심층 분석
```

#### 동작 원리

- `codex mcp-server`를 MCP 서버로 등록하여 `mcp__codex__codex`, `mcp__codex__codex-reply` 도구를 사용
- **Critic**: git diff, 명시적 콘텐츠, 또는 대화 컨텍스트에서 검증 대상을 수집하여 Codex에 리뷰 요청
- **Hephaestus**: 복잡한 구현 작업을 Codex에 위임하여 탐색 → 계획 → 실행 → 검증을 자율 수행
- **Analyze**: 코드, 로그, 에러, 성능 등 임의의 대상을 심층 분석하여 구조화된 인사이트 제공
- Thread 기반 대화로 반복 개선 (이전 컨텍스트 유지)
- 세션별 고유 ID로 결과 파일 격리: `~/.ai/{skill}-{SESSION_ID}-result.json`
