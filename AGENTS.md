# AGENTS.md

This file provides guidance to Codex CLI when working with code in this repository.

> **Precedence**: General development rules (commit workflow, security, testing, etc.) are defined in the global `~/.codex/AGENTS.md`. This file contains project-specific rules and reference documentation. **Project-specific rules take precedence** over global rules when they conflict.

## Operational Rules

### Critical Rules

- DO NOT use git worktree for this repository
- Follow existing code patterns and module structure in this repository
- Use `nixfmt` to format all Nix files before committing
- Run `nix flake check` only for complex changes (multi-module, architecture changes); skip for simple edits unless explicitly requested
- Do NOT push unless explicitly requested
- When changing the canonical theme pipeline or generated theme exports, leave a local git commit in a sensible rollbackable unit before finishing the work

### Documentation Guidelines

- All documentation belongs in: `AGENTS.md`, `CLAUDE.md`, `README.md`, code comments (sparingly), commit messages
- When you work on markdown files, ensure they are following markdownlint rules

### Build/Test/Lint Commands

**Agent-safe commands** (Codex CLI can run these directly):

```bash
nixfmt <file.nix>                  # Format Nix files
nix flake show                     # Show available flake outputs
nix flake check --no-build         # Validate syntax without building
nix flake check                    # Full validation (complex changes only)
nix eval .#homeConfigurations.pylv-denim.config.home.packages --apply 'x: map (p: p.name) x'
```

**User-run commands** (ask the user to run these):

Standalone Home Manager commands require `--impure` because several modules
use out-of-store symlinks to the checkout path.

```bash
home-manager switch --impure --flake .#<environment>
nixos-rebuild switch --flake .#<host>
```

---

## Reference

### Nix Code Style

- **Formatting**: Enforced by `nixfmt` (2-space indent). Use `with pkgs;` for package lists.
- **Naming**: Variables/options use camelCase, files use lowercase, directories use lowercase/kebab, environments use kebab-case.
- **Module pattern**: `let cfg = config.modules.name; in { options.modules.name = { enable = lib.mkOption { ... }; }; config = lib.mkIf cfg.enable { ... }; }`
- **Imports**: Use relative paths, import directories by name (e.g., `../modules/claude`)
- **Conditionals**: `lib.mkIf`, `lib.mkMerge`, `lib.mkForce`
- **Host definition**: See `inventory.nix` for required fields (`kind`, `system`, `username`, `homeDirectory`, `profile`)
- **Secrets**: Use [agenix](https://github.com/ryantm/agenix) — `agenix -e secrets/name.age`, decrypts to `/run/agenix/<secretName>`

### Architecture

Nix flakes-based Home Manager and NixOS configuration supporting multiple environments (macOS and Linux) with layered base system.

```text
flake.nix                         # Main flake configuration
inventory.nix                     # All host/environment definitions (kind, system, profile)
base/default.nix                  # Common configuration for all environments
base/<company>/home.nix           # Company-specific extensions (devsisters, pylv)
modules/<name>/default.nix        # Reusable module
hosts/<name>/configuration.nix    # NixOS host configuration
lib/builders.nix                  # mkHomeConfig, mkNixOSConfig helpers
overlays/default.nix              # nixpkgs version overlays
secrets/secrets.nix               # Agenix secrets configuration
```

#### Environments

Defined in `inventory.nix` (single source of truth). `kind` field determines build type:

- **devsisters-macbook / devsisters-macstudio**: ARM64 macOS, devsisters base, home-only
- **pylv-denim**: x86_64 Linux/WSL, pylv base, home-only
- **pylv-sepia**: x86_64 Linux/NixOS server, pylv base (with Disko, agenix, copyparty, OpenClaw)
- **pylv-onyx**: x86_64 Linux/NixOS, pylv base

#### Base System

1. **`base/default.nix`**: Common config — core modules, standard dev packages, programs
2. **`base/devsisters/home.nix`**: saml2aws, vault, scala, ruby, databricks-cli, custom scripts
3. **`base/pylv/home.nix`**: Minimal (inherits base)
4. **`base/pylv/sepia.nix`**: `pylv-sepia` NixOS server specific config

### Module System

Each module in `modules/` manages a specific tool. **When modifying settings for any tool, look in the corresponding module directory first.**

For theme-backed apps, prefer the canonical theme pipeline under `themes/` over app-local theme copies:

- `themes/core/` is the source of truth for reusable theme definitions
- `themes/templates/` defines app adapter/template structure
- `themes/exports/` contains generated app-ready artifacts
- when changing a module to use a theme, prefer wiring the module to `themes/exports/<app>/...` rather than creating or editing duplicated app-local theme files inside `modules/<app>/themes/`
- after changing theme templates, generators, overrides, or generated exports, leave the repo with a local commit that captures the change in a clear rollbackable unit

```text
modules/<name>/
├── default.nix    # Main module configuration (ALWAYS exists)
├── files/         # Static config files (JSON, TOML, etc.)
├── themes/        # Legacy or app-local themes (prefer `themes/exports/` for generated themes)
└── agents/        # AI agent definitions (for AI tools)
```

#### Module Reference

| Module       | Purpose             | Key Files                                           | Mutable |
| ------------ | ------------------- | --------------------------------------------------- | ------- |
| `nixos/`     | NixOS common config | `baseline.nix`, `remote-access.nix`, `user.nix`     | NO      |
| `claude/`    | Claude Code         | `files/settings.json`, `files/CLAUDE.md`            | 부분적  |
| `codex/`     | OpenAI Codex CLI    | `files/config.toml`, `files/AGENTS.md`              | YES     |
| `ghostty/`   | Ghostty terminal    | `files/config`                                      | YES     |
| `git/`       | Git configuration   | `default.nix`                                       | NO      |
| `k9s/`       | Kubernetes manager  | `default.nix`                                       | NO      |
| `kitty/`     | Kitty terminal      | `files/kitty.conf`                                  | YES     |
| `lsp/`       | LSP server packages | `default.nix`                                       | NO      |
| `opencode/`  | OpenCode AI agent   | `files/opencode.json`, `files/AGENTS.md`            | YES     |
| `terraform/` | Terraform versions  | `default.nix` (direnv lazy-load)                    | NO      |
| `vim/`       | Neovim              | `files/config/init.lua`, `files/onelight.lua`       | YES     |
| `wezterm/`   | WezTerm terminal    | `files/wezterm.lua`                                 | YES     |
| `vscode/`    | VSCode (DISABLED)   | `default.nix`, `one-half-light-theme/`              | NO      |
| `zed/`       | Zed editor          | `files/settings.json`, `themes/one-half-light.json` | YES     |
| `zellij/`    | Zellij multiplexer  | `files/config.darwin.kdl`, `files/config.linux.kdl` | YES     |
| `zsh/`       | Zsh shell           | `default.nix`, `starship.toml`                      | 부분적  |

> **Mutable**: `mkOutOfStoreSymlink`로 설정 파일이 repo로 직접 symlink됨. 앱 UI에서 수정 가능, 변경이 즉시 repo에 반영. `nfc` alias로 커밋.

### Editor-Specific Notes

#### Neovim (`modules/vim/`)

`programs.neovim.initLua`가 `require('config')`으로 부트스트랩. 실제 설정은 `files/config/`에 있으며 `~/.config/nvim/lua/config/`로 symlink. Theme artifacts should prefer `themes/exports/nvim/` when generated from the canonical theme pipeline. LSP 서버 추가 시 `files/config/init.lua`의 `servers` 테이블 + `modules/lsp/default.nix`에 바이너리 추가.

#### VSCode (`modules/vscode/`) — DISABLED

현재 비활성화. VSCode 수정 요청 시 모듈 재활성화 여부를 먼저 확인할 것.

#### Zed (`modules/zed/`)

Settings, keymaps는 `mkOutOfStoreSymlink`로 symlink. Generated themes should be consumed from `themes/exports/zed/`. Extensions는 `default.nix`의 `nixExtensions` 리스트로 관리.

#### Terraform

direnv lazy loading 사용. `.envrc`에 `use_terraform` 추가하면 `required_version`을 읽어 자동 로드.

### AI Coding Agent Notes

AI 코딩 에이전트 설정 변경 시 **로컬 프로젝트 파일이 아닌 대응 모듈의 글로벌 설정 파일**을 수정할 것. 단, 이 저장소 전용 Codex 작업 규칙은 루트 `AGENTS.md`에 둔다.

- **Claude Code** (`modules/claude/`): Plugins은 [gytkk/claude-marketplace](https://github.com/gytkk/claude-marketplace)로 관리. LSP plugins은 `modules/lsp/default.nix`의 바이너리 필요.
- **Codex CLI** (`modules/codex/`): 기본 설정은 `files/config.toml`, 글로벌 기본 지침은 `files/AGENTS.md`, 이 저장소 전용 규칙은 루트 `AGENTS.md`.
- **OpenCode** (`modules/opencode/`): `files/opencode.json`으로 모델/MCP/플러그인 설정.
- **Codex Skills**: `codex` plugin — `/codex:critic`, `/codex:hephaestus`, `/codex:analyze`

### Package Management

- **Base packages** (`base/default.nix`): nixfmt, coreutils, findutils, docker, gcc, jq, fd, ripgrep, git, gh, lazygit, nodejs, bun, go, uv, ruff, rustup, kubectl, helm, etc.
- **LSP servers** (`modules/lsp/`): nixd, gopls, typescript-language-server, terraform-ls, metals, ty, yaml-language-server, marksman (rust-analyzer는 rustup이 제공)
- **Devsisters-specific** (`base/devsisters/`): saml2aws, vault, scala, ruby, databricks-cli
