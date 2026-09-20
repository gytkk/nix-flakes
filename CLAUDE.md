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

- All documentation belongs in: AGENTS.md, CLAUDE.md, README.md, code comments (sparingly), commit messages
- When module paths or behavior change, update the module README and its root documentation links. Run `uv run --no-project docs/check-paths.py` to check the current entry-point documents; pass other changed Markdown files explicitly.

### Build/Test/Lint Commands

**Agent-safe commands** (Claude Code can run these directly):

```bash
nixfmt <file.nix>                  # Format Nix files
nix flake show                     # Show available flake outputs
nix flake check --no-build         # Validate flake outputs without building
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
- **Module pattern**: Home Manager modules expose `options.modules.<name>.enable` and gate runtime config with `lib.mkIf cfg.enable`. `base/default.nix` owns common default enable values; profile files override with `lib.mkForce` or plain assignments when needed.
- **Imports**: Use relative paths, import directories by name (e.g., `../modules/claude`)
- **Conditionals**: `lib.mkIf`, `lib.mkMerge`, `lib.mkForce`
- **Host definition**: See `inventory.nix` for required fields (`kind`, `system`, `username`, `homeDirectory`, `profile`)
- **Secrets**: Use [agenix](https://github.com/ryantm/agenix). Run `agenix -e secrets/<name>.age` with the secret's filename; NixOS decrypts it to `/run/agenix/<secretName>`.

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
- **pylv-onyx**: x86_64 Linux/NixOS, pylv base (with niri, DankMaterialShell, OpenClaw)

#### Base System

1. **`base/default.nix`**: Common config — core modules, standard dev packages, programs
2. **`base/devsisters/home.nix`**: saml2aws, vault, kc2aws, scala, ruby, databricks-cli, custom scripts
3. **`base/pylv/home.nix`**: Minimal (inherits base)
4. **`base/pylv/sepia.nix`**: pylv-sepia NixOS server specific config

### Module System

Each module in `modules/` manages a specific tool. **When modifying settings for any tool, look in the corresponding module directory first.** `agent-core/` owns canonical agent instructions and shared skills. Runtime modules consume generated outputs and must not reimplement rendering or selection.

Common NixOS modules live under `modules/nixos`; host-specific NixOS input
modules and values live in `hosts/<name>/configuration.nix`. OpenClaw host
values are set in `hosts/pylv-onyx/configuration.nix` through
`modules.openclaw`.

```text
modules/<name>/
├── default.nix    # Main module configuration (ALWAYS exists)
├── files/         # Static config files (JSON, TOML, etc.)
├── themes/        # Legacy or app-local themes; generated themes live in themes/exports/
└── agents/        # AI agent definitions (for AI tools)
```

#### Module reference

Before changing an app module, read the shared [module reference](AGENTS.md#module-reference) and [editor-specific notes](AGENTS.md#editor-specific-notes) for its source paths, installation behavior, and activation constraints. Those sections also cover VSCode's disabled status, Terraform's direnv integration, and links to module READMEs.

### AI Coding Agent Notes

AI 코딩 에이전트 설정을 변경할 때 공통 지침, runtime adapter, shared skill은 `agent-core/`에서 수정한다. Runtime 전용 설정은 대응 모듈에서 수정한다.

- `agent-core/rules/`는 공통 지침, `agent-core/adapters/`는 runtime별 지침, `agent-core/skills/`는 shared skill의 canonical catalog다. `agent-core/manifest.toml`이 조합 순서와 runtime별 노출을 정의한다.
- Skill은 필요한 capability를 runtime 중립적으로 표현한다. Runtime tool, SDK, metadata, plugin 설정은 대응 module이 소유하며, runtime module에 shared skill 복사본이나 별도 selection logic을 추가하지 않는다.
- **Claude Code** (`modules/claude/`): Plugin과 marketplace 목록은 [Claude README](modules/claude/README.md)에서 확인한다. Runtime 전용 `devils-advocate`와 LSP plugin은 `modules/claude/marketplace/`에 있으며 LSP plugin은 `modules/lsp/default.nix`의 바이너리가 필요하다.

### Package Management

- **Base packages** (`base/default.nix`): nixfmt, coreutils, findutils, docker, gcc, jq, fd, ripgrep, git, gh, lazygit, nodejs, bun, go, uv, ruff, rustup, kubectl, helm, etc.
- **LSP servers** (`modules/lsp/`): nixd, gopls, typescript-language-server, terraform-ls, metals, ty, yaml-language-server, marksman (`rust-analyzer` must be installed in the active rustup toolchain)
- **Devsisters-specific** (`base/devsisters/`): saml2aws, vault, scala, ruby, databricks-cli, kc2aws
  - `kc2aws` comes from the private `keycloak2aws` flake input (`git+ssh://...`), pinned in `flake.lock`. To pull the latest `main`: `nix flake update keycloak2aws`, then `home-manager switch`. Commit the resulting `flake.lock` change.
