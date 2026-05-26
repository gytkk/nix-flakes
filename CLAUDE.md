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

- All documentation belongs in: CLAUDE.md, README.md, code comments (sparingly), commit messages
- When you work on markdown files, ensure they are following markdownlint rules

### Build/Test/Lint Commands

**Agent-safe commands** (Claude Code can run these directly):

```bash
nixfmt <file.nix>                  # Format Nix files
nix flake show                     # Show available flake outputs
nix flake check --no-build         # Validate syntax without building
nix flake check                    # Full validation (complex changes only)
nix eval .#homeConfigurations.pylv-denim.config.home.packages --apply 'x: map (p: p.name) x'
```

**User-run commands** (ask the user to run these):

Standalone Home Manager commands do not require `--impure`, but several
modules still install out-of-store symlinks to the checkout path.

```bash
home-manager switch --flake .#<environment>
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
4. **`base/pylv/sepia.nix`**: pylv-sepia NixOS server specific config

### Module System

Each module in `modules/` manages a specific tool. **When modifying settings for any tool, look in the corresponding module directory first.**

```text
modules/<name>/
├── default.nix    # Main module configuration (ALWAYS exists)
├── files/         # Static config files (JSON, TOML, etc.)
├── themes/        # Custom themes
└── agents/        # AI agent definitions (for AI tools)
```

#### Module Reference

| Module       | Purpose             | Key Files                                           | Mutable |
| ------------ | ------------------- | --------------------------------------------------- | ------- |
| `nixos/`     | NixOS common config | `baseline.nix`, `remote-access.nix`, `user.nix`     | NO      |
| `claude/`    | Claude Code         | `files/settings.json`, `files/CLAUDE.md`            | 부분적  |
| `codex/`     | OpenAI Codex CLI    | `files/config.toml`, `files/AGENTS.md`              | YES     |
| `ghostty/`   | Ghostty terminal    | `files/config`, `themes/exports/ghostty`            | YES     |
| `git/`       | Git configuration   | `default.nix`                                       | NO      |
| `k9s/`       | Kubernetes manager  | `default.nix`                                       | NO      |
| `kitty/`     | Kitty terminal      | `files/kitty.conf`                                  | YES     |
| `lsp/`       | LSP server packages | `default.nix`                                       | NO      |
| `opencode/`  | OpenCode AI agent   | `files/opencode.json`, `files/AGENTS.md`            | YES     |
| `terraform/` | Terraform versions  | `default.nix` (direnv lazy-load)                    | NO      |
| `vim/`       | Neovim              | `files/config/init.lua`, `files/onelight.lua`       | YES     |
| `vscode/`    | VSCode (DISABLED)   | `default.nix`, `one-half-light-theme/`              | NO      |
| `zed/`       | Zed editor          | `files/settings.json`, `themes/one-half-light.json` | YES     |
| `zellij/`    | Zellij multiplexer  | `files/config.darwin.kdl`, `files/config.linux.kdl` | YES     |
| `zsh/`       | Zsh shell           | `default.nix`, `starship.toml`                      | 부분적  |

> **Mutable**: `mkOutOfStoreSymlink`로 설정 파일이 repo로 직접 symlink됨. 앱 UI에서 수정 가능, 변경이 즉시 repo에 반영. `nfc` alias로 커밋.

### Editor-Specific Notes

#### Neovim (`modules/vim/`)

`programs.neovim.initLua`가 `require('config')`으로 부트스트랩. 실제 설정은 `files/config/`에 있으며 `~/.config/nvim/lua/config/`로 symlink. LSP 서버 추가 시 `files/config/init.lua`의 `servers` 테이블 + `modules/lsp/default.nix`에 바이너리 추가.

#### VSCode (`modules/vscode/`) — DISABLED

현재 비활성화. VSCode 수정 요청 시 모듈 재활성화 여부를 먼저 확인할 것.

#### Zed (`modules/zed/`)

Settings, keymaps, themes는 `mkOutOfStoreSymlink`로 symlink. Zed UI에서 편집 가능. Extensions는 `default.nix`의 `nixExtensions` 리스트로 관리.

#### Terraform

direnv lazy loading 사용. `.envrc`에 `use_terraform` 추가하면 `required_version`을 읽어 자동 로드.

### AI Coding Agent Notes

AI 코딩 에이전트 설정 변경 시 **로컬 프로젝트 파일이 아닌 이 모듈들의 글로벌 설정 파일**을 수정할 것.

- `modules/*/files/AGENTS.md`, `files/CLAUDE.md`, `files/config.toml` 같은 경로는 이 저장소가 관리하는 source file이다. 런타임에서 out-of-store symlink로 노출될 수는 있지만, 저장소 안의 파일 자체를 generated live copy로 취급하지 말고 module wiring에서 실제 연결 방식을 확인할 것.

- **Claude Code** (`modules/claude/`): Plugins은 [gytkk/claude-marketplace](https://github.com/gytkk/claude-marketplace)로 관리. LSP plugins은 `modules/lsp/default.nix`의 바이너리 필요.
- **OpenCode** (`modules/opencode/`): `files/opencode.json`으로 모델/MCP/플러그인 설정.
- **Codex Skills**: `codex` plugin — `/codex:critic`, `/codex:hephaestus`, `/codex:analyze`

### Package Management

- **Base packages** (`base/default.nix`): nixfmt, coreutils, findutils, docker, gcc, jq, fd, ripgrep, git, gh, lazygit, nodejs, bun, go, uv, ruff, `pkgs.rustToolchain`, kubectl, helm, etc.
- **LSP servers** (`modules/lsp/`): nixd, gopls, typescript-language-server, terraform-ls, metals, ty, yaml-language-server, marksman (Rust tooling including `rust-analyzer` comes from `pkgs.rustToolchain`)
- **Devsisters-specific** (`base/devsisters/`): saml2aws, vault, scala, ruby, databricks-cli
