# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Critical Rules

- DO NOT use git worktree for this repository
- Follow existing code patterns and module structure in this repository
- Use `nixfmt` to format all Nix files before committing (you should delegate this task to subagent using sonnet model)
- Do NOT run build tests directly - ask the user to test instead (builds can take several minutes)
- Skip `nix flake check` unless explicitly requested - it often takes too long
- Do NOT push unless explicitly requested
- Commit changes after completing a logical unit of work (when possible)

## Documentation Guidelines

- **NO ONE-OFF DOCUMENTATION FILES**: Do not create temporary or one-off documentation files (e.g., CHANGES.md, NOTES.md, etc.)
- All documentation belongs in:
  - CLAUDE.md - Primary source of truth for development guidelines
  - README.md - User-facing documentation
  - Code comments - Only when absolutely necessary
  - Commit messages - For change history
- If you need to document something, update the appropriate existing file
- When you work on markdown files, ensure they are following markdownlint rules

## Build/Test/Lint Commands

```bash
# Validate flake configuration (run this first)
nix flake check

# Test build specific environment (without applying)
home-manager build --flake .#pylv-denim
home-manager build --flake .#pylv-sepia
home-manager build --flake .#devsisters-macbook
home-manager build --flake .#devsisters-macstudio

# Apply configuration (after successful build)
home-manager switch --flake .#<environment>

# NixOS build and apply (for pylv-sepia)
nixos-rebuild build --flake .#pylv-sepia
nixos-rebuild switch --flake .#pylv-sepia

# Format Nix files
nixfmt <file.nix>
nixfmt **/*.nix        # Format all Nix files

# Show available flake outputs
nix flake show
```

### Testing a Single Module

```bash
# Build and check specific environment to test module changes
home-manager build --flake .#pylv-denim 2>&1 | head -50

# Check for evaluation errors without building
nix eval .#homeConfigurations.pylv-denim.config.home.packages --apply 'x: map (p: p.name) x'
```

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

### Java Version Management

```bash
# Switch Java versions globally
java8          # Switch to Java 8
java17         # Switch to Java 17
java-switch 8  # Alternative syntax
java-switch 17 # Alternative syntax

# Check current Java version
java -version
echo $JAVA_HOME
```

#### Directory-specific Java Versions (with direnv)

Create `.envrc` files in project directories:

```bash
# For Java 8 projects
echo "use_java_8" > .envrc
direnv allow

# For Java 17 projects
echo "use_java_17" > .envrc
direnv allow

# Combined with Terraform
cat > .envrc << 'EOF'
use_java_8
use_terraform
EOF
direnv allow
```

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

## Nix Code Style Guidelines

### File Structure

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

### Imports

```nix
imports = [
  ../modules/claude
  ../modules/git
];
```

- Use relative paths for imports within the repository
- Import directories containing `default.nix` by directory name

### Formatting Rules

- Opening brace `{` on same line for function parameters
- One attribute per line in attribute sets
- Semicolons at end of each attribute
- Closing brace `}` on separate line
- Use 2-space indentation (enforced by nixfmt)
- Use `with pkgs;` for package lists

### Naming Conventions

| Type              | Convention      | Example                               |
| ----------------- | --------------- | ------------------------------------- |
| Variables         | camelCase       | `terraformPackages`, `defaultVersion` |
| Module options    | camelCase       | `enable`, `runEnv`, `versions`        |
| Files             | lowercase       | `default.nix`, `home.nix`             |
| Directories       | lowercase/kebab | `modules/`, `base/devsisters/`        |
| Environment names | kebab-case      | `pylv-denim`, `devsisters-macbook`    |

### Module Pattern

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

### Package Lists

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

### Conditional Configuration

```nix
config = lib.mkIf cfg.enable { ... };                              # Single condition
lib.mkMerge [ (lib.mkIf (!isWSL) { ... }) (lib.mkIf isWSL { ... }) ] # Multiple
programs.git.settings.user.email = lib.mkForce "x@example.com";    # Force override
```

### Environment Definition (environments.nix)

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

## Architecture

This is a Nix flakes-based Home Manager configuration supporting multiple environments (macOS and Linux). The configuration uses a layered base system with company-specific customizations.

### Quick Reference

```text
base/default.nix          # Common configuration for all environments
base/<company>/home.nix   # Company-specific extensions
modules/<name>/default.nix # Reusable module
environments.nix          # All environment definitions
hosts.nix                 # NixOS host definitions
hosts/<name>/configuration.nix # NixOS host configuration
lib/builders.nix          # mkHomeConfig, mkNixOSConfig helpers
overlays/default.nix      # nixpkgs version overlays (nixpkgs-versions)
secrets/secrets.nix       # Agenix secrets configuration
```

### Core Structure

- `flake.nix`: Main flake configuration with inputs, outputs, and environment definitions
- `environments.nix`: All environment configurations in a single file
- `hosts.nix`: NixOS host definitions (currently pylv-sepia)
- `base/`: Layered Home Manager configurations
  - `base/default.nix`: Common base configuration for all environments
  - `base/devsisters/`: Devsisters-specific extensions
  - `base/pylv/`: Pylv-specific extensions
- `hosts/`: NixOS host configurations
  - `hosts/pylv-sepia/`: NixOS server configuration (configuration.nix, disk-config.nix, hardware-configuration.nix)
- `modules/`: Modular configuration components
- `lib/`: Helper functions and environment loaders
- `secrets/`: Encrypted secrets management (agenix)
- `docs/`: Additional documentation

### Environment Configurations

All environments are defined in `environments.nix` with the following structure:

- **`devsisters-macbook`**: ARM64 macOS (gyutak@/Users/gyutak) with devsisters base profile
- **`devsisters-macstudio`**: ARM64 macOS (gyutak@/Users/gyutak) with devsisters base profile
- **`pylv-denim`**: x86_64 Linux/WSL (gytkk@/home/gytkk) with pylv base profile
- **`pylv-sepia`**: x86_64 Linux/NixOS server (gytkk@/home/gytkk) with pylv base profile + OpenClaw

Each environment specifies a `baseProfile` which determines which base configuration to load.

### NixOS Host Configurations

NixOS hosts are defined in `hosts.nix` with full system configurations:

- **`pylv-sepia`**: x86_64 Linux NixOS server with Disko, agenix, Home Manager, copyparty, and OpenClaw AI gateway

### Base System Architecture

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

| File                      | Purpose                                   | Deployed To                        |
| ------------------------- | ----------------------------------------- | ---------------------------------- |
| `files/opencode.json`         | Model, theme, plugins, MCP settings       | `~/.config/opencode/opencode.json`         |
| `files/oh-my-opencode.json`   | Oh-My-OpenCode agent/category model config| `~/.config/opencode/oh-my-opencode.json`   |
| `files/AGENTS.md`             | Global instructions for OpenCode behavior | `~/.config/opencode/AGENTS.md`             |
| `files/agents/*.md`           | Custom agent definitions                  | `~/.config/opencode/agents/`               |
| `files/plugins/native-notify.ts` | Terminal notification plugin           | `~/.config/opencode/plugins/native-notify.ts` |

**Custom Agents** (in `files/agents/`):

- `troubleshoot.md`: Troubleshooting agent

**Common modification scenarios**:

- Add new MCP server → Edit `files/opencode.json` → `mcp`
- Add new plugin → Edit `files/opencode.json` → `plugin`
- Change default model → Edit `files/opencode.json` → `model`
- Update global instructions → Edit `files/AGENTS.md`
- Create new custom agent → Add `files/agents/{agent-name}.md`

### Package Management

Base packages defined in `base/default.nix`:

- **System**: coreutils, findutils, gnupg, libiconv, direnv, tmux, less, wget, curl
- **Development**: docker, gcc, awscli2, jq, yq-go, ripgrep
- **Git**: git, gh, lazygit, delta, bat
- **Java**: OpenJDK 17 (default), OpenJDK 8 via direnv
- **JavaScript/TypeScript**: nodejs, bun, typescript, pnpm, turbo
- **Go**: go compiler and tools
- **Python**: uv package manager, ty type checker
- **Rust**: rustup
- **Kubernetes**: kubectl, kubectx, k9s, helm
- **Secrets**: 1password-cli, keybase
- **Media**: ffmpeg, yt-dlp
- **ML**: micromamba
- **Nix**: nixfmt, nixd
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

## Codex Critic (코드 검증 스킬)

Codex CLI를 사용하여 코드 변경사항, 계획, 또는 임의의 콘텐츠를 독립적으로 검증하는 스킬입니다.
SKILL.md에 모든 오케스트레이션 로직이 포함되어 있으며, 별도의 bash script 없이 Claude Code가
직접 `codex exec`를 호출합니다.

### 사용법

```bash
/codex-critic "<원래 사용자 요청>"
```

### 입력 모드

- **Git diff** (기본): staged → working tree → last commit 순으로 diff 수집
- **임의 콘텐츠**: 파일 경로, 텍스트 블록, 계획 등을 직접 전달하여 검증
- **대화 컨텍스트**: 위 두 가지가 없으면 최근 작업 내용에서 추론

### 구조

| 파일 | 용도 |
|------|------|
| `modules/claude/skills/codex-critic/SKILL.md` | 스킬 정의 및 전체 오케스트레이션 로직 |
| `modules/claude/skills/codex-critic/references/critic-schema.json` | 출력 JSON 스키마 |
| `modules/claude/files/codex-critic-agents.md` | Codex 리뷰어 페르소나 (`~/.codex-critic/AGENTS.md`로 배포) |
| `.ai/critic-result.json` | 최종 결과 (런타임 생성, gitignored) |

### 동작 원리

1. 입력 결정: git diff, 명시적 콘텐츠, 또는 대화 컨텍스트에서 검증 대상 수집
2. `codex exec --sandbox read-only`로 Codex에게 검증 요청
3. 결과가 불충분하면 (score < 8, verdict != pass) 최대 5회 반복 개선
4. 구조화된 JSON 결과를 `.ai/critic-result.json`에 저장
5. Claude Code가 결과를 읽어 요약/권고 제공

### 환경 변수

| 변수 | 기본값 | 설명 |
|------|--------|------|
| `OPENAI_API_KEY` | (필수) | OpenAI API 키 |
| `CRITIC_MAX_ITER` | 5 | 최대 반복 횟수 |
| `CRITIC_MAX_DIFF_LINES` | 500 | diff 최대 줄 수 |
| `CRITIC_SANDBOX` | read-only | Codex sandbox 모드 |

### 규칙

- 자동 호출 금지: `/codex-critic` 명시적 실행만 허용
- Codex는 read-only sandbox에서 실행 (파일 수정 불가)
- 결과 기반 수정은 Claude Code가 수행하며, 사용자 승인 후 진행
- `.ai/` 디렉토리의 런타임 출력물은 gitignored

## Git Conventions

- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `refactor:`
- Write in imperative mood: "Add feature" not "Added feature"
- Keep commits atomic: one logical change per commit

## Security

- Never commit secrets or credentials
- Use agenix for secrets management:

  ```nix
  age.secrets.secretName.file = ../../secrets/secret-name.age;
  ```

- Secrets decrypt to `/run/agenix/<secretName>`
