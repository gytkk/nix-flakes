# AGENTS.md

This file provides guidance to Codex CLI when working with code in this repository.

> **Precedence**: General development rules (commit workflow, security, testing, etc.) are defined in the global `~/.codex/AGENTS.md`. This file contains project-specific rules and reference documentation. **Project-specific rules take precedence** over global rules when they conflict.

## Operational Rules

### Critical Rules

- DO NOT use git worktree for this repository
- Follow existing code patterns and module structure in this repository
- Use `nixfmt` to format all Nix files before committing
- Prefer narrow, fast checks. Run time-consuming Nix evaluation commands such as `nix eval` and `nix flake check` only when they are required to validate the requested change or the user explicitly requests them. Skip them for documentation-only changes, simple edits, and checks unrelated to the changed behavior.
- Do NOT push unless explicitly requested
- When changing the canonical theme pipeline or generated theme exports, leave a local git commit in a sensible rollbackable unit before finishing the work

### Documentation Guidelines

- All documentation belongs in: `AGENTS.md`, `CLAUDE.md`, `README.md`, code comments (sparingly), commit messages

### Build/Test/Lint Commands

**Agent-safe commands** (Codex CLI can run these directly):

```bash
nixfmt <file.nix>                  # Format Nix files
nix flake show                     # Show available flake outputs
nix flake check --no-build         # Validate complex or evaluation-sensitive changes
nix flake check                    # Fully validate complex changes when required
nix eval .#homeConfigurations.pylv-denim.config.home.packages --apply 'x: map (p: p.name) x' # Evaluate a specific output when required
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
- **Module pattern**: Home Manager modules expose `options.modules.<name>.enable` and gate runtime config with `lib.mkIf cfg.enable`. `base/default.nix` owns common default enable values; profile files override with `lib.mkForce` or plain assignments when needed.
- **Imports**: Use relative paths, import directories by name (e.g., `../modules/claude`)
- **Conditionals**: `lib.mkIf`, `lib.mkMerge`, `lib.mkForce`
- **Host definition**: See `inventory.nix` for required fields (`kind`, `system`, `username`, `homeDirectory`, `profile`)
- **Secrets**: Use [agenix](https://github.com/ryantm/agenix) — `agenix -e secrets/name.age`, decrypts to `/run/agenix/<secretName>`

### Architecture

Nix flakes-based standalone Home Manager and NixOS configuration supporting multiple environments (macOS and Linux) with layered base system.

```text
flake.nix                         # Main flake configuration
inventory.nix                     # All Home Manager environments and NixOS hosts
base/default.nix                  # Common Home Manager configuration
base/<profile>/home.nix           # Profile-specific Home Manager extensions
agent-core/                       # Canonical agent rules, adapters, skills, and renderer
modules/<name>/default.nix        # Reusable Home Manager or NixOS module
modules/nixos/                    # Common NixOS modules and shared secrets
hosts/<name>/configuration.nix    # NixOS host configuration
packages/apps/                    # Non-nixpkgs app packages and manual updaters
lib/pkgs.nix                      # Overlay and per-system package-set construction
lib/home-configurations.nix       # Home Manager configuration builder
lib/nixos-configurations.nix      # NixOS configuration builder
lib/builders.nix                  # Backward-compatible builder aggregation
overlays/default.nix              # nixpkgs version overlays
secrets/secrets.nix               # Agenix recipient configuration
```

#### Environments

Defined in `inventory.nix` (single source of truth). `kind` field determines build type:

- **devsisters-macbook / devsisters-macstudio**: ARM64 macOS, devsisters base, home-only
- **pylv-denim**: x86_64 Linux/WSL, pylv base, home-only
- **pylv-sepia**: x86_64 Linux/NixOS server, pylv base (with Disko, agenix, copyparty)
- **pylv-onyx**: x86_64 Linux/NixOS, pylv base (with niri, DankMaterialShell, user-managed OpenClaw)

#### Base System

1. **`base/default.nix`**: Common config — core modules, standard dev packages, programs
2. **`base/devsisters/home.nix`**: saml2aws, vault, scala, ruby, databricks-cli, custom scripts
3. **`base/pylv/home.nix`**: Minimal (inherits base)
4. **`base/pylv/sepia.nix`**: `pylv-sepia` NixOS server specific config

### Module System

Each module in `modules/` manages a specific tool. **When modifying settings for any tool, look in the corresponding module directory first.** `agent-core/` owns canonical agent instructions and shared skills. Runtime modules consume generated outputs and must not reimplement render or selection logic.

Common NixOS modules live under `modules/nixos`; host-specific NixOS input
modules and values live in `hosts/<name>/configuration.nix`. `modules/openclaw`
keeps the NixOS and Home Manager integration for the user-managed OpenClaw
install. It does not own the OpenClaw package, mutable state, or user service.

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
| `claude/`    | Claude Code         | `default.nix`, `files/settings.json`                 | 부분적  |
| `codex/`     | OpenAI Codex CLI    | `default.nix`, `files/config.toml`                   | YES     |
| `ghostty/`   | Legacy Ghostty terminal | `files/config`, `themes/exports/ghostty`        | YES     |
| `git/`       | Git configuration   | `default.nix`                                       | NO      |
| `k9s/`       | Kubernetes manager  | `default.nix`                                       | NO      |
| `kitty/`     | Kitty terminal      | `files/kitty.conf`                                  | YES     |
| `lsp/`       | LSP server packages | `default.nix`                                       | NO      |
| `terraform/` | Terraform versions  | `default.nix` (direnv lazy-load)                    | NO      |
| `vim/`       | Neovim              | `files/config/init.lua`, `files/onelight.lua`       | YES     |
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

AI 코딩 에이전트 설정을 변경할 때 공통 지침, runtime adapter, shared skill은 `agent-core/`에서 수정한다. Runtime 전용 설정은 대응 모듈에서 수정하고, 이 저장소에서만 적용하는 작업 규칙은 루트 `AGENTS.md`에 둔다.

- `agent-core/rules/`는 공통 지침, `agent-core/adapters/`는 runtime별 지침, `agent-core/skills/`는 shared skill의 canonical catalog다. `agent-core/manifest.toml`이 조합 순서와 runtime별 노출을 정의한다.
- Skill은 필요한 capability를 runtime 중립적으로 표현한다. Runtime tool, SDK, metadata, plugin 설정은 대응 module이 소유하며, runtime module에 shared skill 복사본이나 별도 selection logic을 추가하지 않는다.
- `agent-core render`의 immutable output을 Nix module에서 설치한다. Pi는 operating invariant를 `APPEND_SYSTEM.md`로 분리하고, OpenClaw는 prompt hook으로 `AGENTS.core.md`를 주입한다.

- **Claude Code** (`modules/claude/`): Plugins은 [gytkk/claude-marketplace](https://github.com/gytkk/claude-marketplace)로 관리한다. Command와 agent를 제공하는 `devils-advocate`와 LSP plugin은 marketplace에 남기고 공통 prompt와 shared skill은 agent-core output을 사용한다.
- **Codex CLI** (`modules/codex/`): 기본 설정은 `files/config.toml`에서 관리하며 최종 instruction과 skill tree는 agent-core output을 사용한다.
- **Pi** (`modules/pi/`): Settings와 extension은 module에서 관리하며 최종 instruction과 skill tree는 agent-core output을 사용한다.
- **OpenClaw** (`modules/openclaw/`): Mutable `openclaw.json`, workspace, auth/session state는 Nix가 소유하지 않는다. Agent-core integration은 managed skill tree와 `before_prompt_build` hook만 설치한다.
- **Codex Skills**: `codex` plugin — `/codex:critic`, `/codex:hephaestus`, `/codex:analyze`

### Package Management

- **Base packages** (`base/default.nix`): nixfmt, coreutils, findutils, docker, gcc, jq, fd, ripgrep, git, gh, lazygit, nodejs, bun, go, uv, ruff, rustup, kubectl, helm, etc.
- **LSP servers** (`modules/lsp/`): nixd, gopls, typescript-language-server, terraform-ls, metals, ty, yaml-language-server, marksman (`rust-analyzer` must be installed in the active rustup toolchain)
- **Devsisters-specific** (`base/devsisters/`): saml2aws, vault, scala, ruby, databricks-cli
