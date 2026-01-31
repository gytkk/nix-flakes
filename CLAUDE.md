# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Critical Rules

- Follow existing code patterns and module structure in this repository
- Use `nixfmt-rfc-style` to format all Nix files before committing
- Do NOT run build tests directly - ask the user to test instead (builds can take several minutes)
- Do NOT push unless explicitly requested

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

# Format Nix files
nixfmt-rfc-style <file.nix>
nixfmt-rfc-style **/*.nix        # Format all Nix files

# Show available flake outputs
nix flake show

# Update flake inputs
nix flake update

# Enter development shell
nix develop
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
- Use 2-space indentation (enforced by nixfmt-rfc-style)
- Use `with pkgs;` for package lists

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Variables | camelCase | `terraformPackages`, `defaultVersion` |
| Module options | camelCase | `enable`, `runEnv`, `versions` |
| Files | lowercase | `default.nix`, `home.nix` |
| Directories | lowercase/kebab | `modules/`, `base/devsisters/` |
| Environment names | kebab-case | `pylv-denim`, `devsisters-macbook` |

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
  pkgs.master.claude-code         # Master branch package
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
lib/builders.nix          # mkHomeConfig, mkNixOSConfig helpers
overlays/default.nix      # nixpkgs version overlays
```

### Core Structure

- `flake.nix`: Main flake configuration with inputs, outputs, and environment definitions
- `environments.nix`: All environment configurations in a single file
- `base/`: Layered Home Manager configurations
  - `base/default.nix`: Common base configuration for all environments
  - `base/devsisters/`: Devsisters-specific extensions
  - `base/pylv/`: Pylv-specific extensions
- `modules/`: Modular configuration components
- `lib/`: Helper functions and environment loaders

### Environment Configurations

All environments are defined in `environments.nix` with the following structure:

- **`devsisters-macbook`**: ARM64 macOS (gyutak@/Users/gyutak) with devsisters base profile
- **`devsisters-macstudio`**: ARM64 macOS (gyutak@/Users/gyutak) with devsisters base profile
- **`pylv-denim`**: x86_64 Linux/WSL (gytkk@/home/gytkk) with pylv base profile
- **`pylv-sepia`**: x86_64 Linux/WSL (gytkk@/home/gytkk) with pylv base profile

Each environment specifies a `baseProfile` which determines which base configuration to load.

### Base System Architecture

The layered base system provides inheritance and customization:

1. **`base/default.nix`**: Common configuration imported by all company bases
   - Core modules (claude, ghostty, git, java, k9s, opencode, terraform, vim, vscode, zsh)
   - Standard development packages
   - Basic programs configuration

2. **`base/devsisters/home.nix`**: Extends base with Devsisters-specific tools
   - Authentication tools (saml2aws, vault)
   - Scala, Ruby, Databricks CLI
   - Company-specific aliases and environment variables

3. **`base/pylv/home.nix`**: Extends base with minimal Pylv-specific configuration
   - Currently inherits base configuration
   - Ready for company-specific customizations

### Module System

- **`modules/claude/`**: Claude Code installation with MCP support
- **`modules/ghostty/`**: Ghostty terminal configuration with themes
- **`modules/git/`**: Git configuration with LFS, custom aliases, and global gitignore
- **`modules/java/`**: Java version management (8, 17) with directory-based switching via direnv
- **`modules/k9s/`**: Kubernetes cluster manager
- **`modules/opencode/`**: OpenCode AI coding agent
- **`modules/terraform/`**: Terraform version management with lazy loading via direnv
- **`modules/vim/`**: Neovim configuration
- **`modules/vscode/`**: VSCode with extensions (full install on macOS, symlinks on WSL)
- **`modules/zsh/`**: Zsh with Oh-My-Zsh, Powerlevel10k theme, fzf, direnv

### AI Coding Agent Configurations

When updating AI coding agent settings (agents, tools, skills, MCP servers, etc.), **modify the global configuration files in these modules** rather than local project files. Changes here apply globally across all projects.

#### Claude Code Module (`modules/claude/`)

Global configuration for Claude Code (Anthropic's AI coding assistant).

| File | Purpose | Deployed To |
|------|---------|-------------|
| `files/settings.json` | Model selection, permissions, MCP settings | `~/.claude/settings.json` |
| `files/mcp.json` | MCP server configurations | `~/.claude/mcp.json` |
| `files/CLAUDE.md` | Global instructions for Claude behavior | `~/.claude/CLAUDE.md` |
| `agents/*.md` | Custom agent definitions | `~/.claude/agents/` |

**Custom Agents** (in `agents/`):

- `code-reviewer.md`: Code review agent
- `software-dev-engineer.md`: Software development guidance
- `test-code-writer.md`: Test code generation

**Common modification scenarios**:

- Add new MCP server → Edit `files/mcp.json`
- Add new pre-approved command → Edit `files/settings.json` → `permissions.allow`
- Change default model → Edit `files/settings.json` → `model`
- Update global instructions → Edit `files/CLAUDE.md`
- Create new custom agent → Add `agents/{agent-name}.md`

#### OpenCode Module (`modules/opencode/`)

Global configuration for OpenCode (open-source AI coding agent).

| File | Purpose | Deployed To |
|------|---------|-------------|
| `files/opencode.json` | Model, theme, plugins, MCP settings | `~/.config/opencode/opencode.json` |
| `files/AGENTS.md` | Global instructions for OpenCode behavior | `~/.config/opencode/AGENTS.md` |
| `files/agents/*.md` | Custom agent definitions | `~/.config/opencode/agents/` |
| `files/skills/*/SKILL.md` | Custom skill definitions | `~/.config/opencode/skills/` |

**Custom Agents** (in `files/agents/`):

- `review.md`: Code review agent
- `troubleshoot.md`: Troubleshooting agent

**Custom Skills** (in `files/skills/`):

- `git-commit/SKILL.md`: Conventional commits skill
- `git-pr/SKILL.md`: GitHub PR creation skill

**Common modification scenarios**:

- Add new MCP server → Edit `files/opencode.json` → `mcp`
- Add new plugin → Edit `files/opencode.json` → `plugin`
- Change default model → Edit `files/opencode.json` → `model`
- Update global instructions → Edit `files/AGENTS.md`
- Create new custom agent → Add `files/agents/{agent-name}.md`
- Create new custom skill → Add `files/skills/{skill-name}/SKILL.md`

### Package Management

Base packages defined in `base/default.nix`:

- **System**: coreutils, findutils, ripgrep, direnv
- **Development**: docker, gcc, awscli2, jq, yq-go
- **Java**: OpenJDK 17 (default), OpenJDK 8 via direnv
- **JavaScript/TypeScript**: nodejs, bun, typescript, pnpm, turbo
- **Go**: go compiler and tools
- **Python**: uv package manager
- **Rust**: rustup
- **Kubernetes**: kubectl, kubectx, k9s, helm
- **Secrets**: 1password-cli, keybase
- **Nix**: nixfmt

Company-specific packages:

- **Devsisters**: saml2aws, vault, databricks-cli, scala_2_12, ruby_3_2
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
