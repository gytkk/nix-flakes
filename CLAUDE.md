# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Documentation Guidelines

- **NO ONE-OFF DOCUMENTATION FILES**: Do not create temporary or one-off documentation files (e.g., CHANGES.md, NOTES.md, etc.)
- All documentation belongs in:
  - CLAUDE.md - Primary source of truth for development guidelines
  - README.md - User-facing documentation
  - Code comments - Only when absolutely necessary
  - Commit messages - For change history
- If you need to document something, update the appropriate existing file
- When you work on markdown files, ensure they are following markdownlint rules

## Source of Truth & Code Patterns

- CLAUDE.md is the primary source of truth for coding rules
- Always follow existing code patterns and module structure
- Maintain architectural boundaries and consistency

## Commands

### Home Manager Operations

```bash
# Switch to environment-specific configuration
home-manager switch --flake .#devsisters-macbook
home-manager switch --flake .#devsisters-macstudio
home-manager switch --flake .#pylv-denim
home-manager switch --flake .#pylv-sepia

# Build without switching (test configuration)
home-manager build --flake .#devsisters-macbook
home-manager build --flake .#devsisters-macstudio
home-manager build --flake .#pylv-denim
home-manager build --flake .#pylv-sepia
```

### Nix Development

```bash
# Check flake configuration
nix flake check

# Enter development shell
nix develop
```

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

**For Java 8 projects:**
```bash
echo "use_java_8" > .envrc
direnv allow
```

**For Java 17 projects:**
```bash
echo "use_java_17" > .envrc
direnv allow
```

**Combined with other direnv functions:**
```bash
# .envrc example for Java 8 + Terraform
use_java_8
use nix
layout terraform 1.10.5
```

## Architecture

This is a Nix flakes-based Home Manager configuration supporting multiple environments (macOS and Linux). The configuration uses a layered base system with company-specific customizations.

### Core Structure

- `flake.nix`: Main flake configuration with inputs, outputs, and environment definitions
- `environments.nix`: All environment configurations in a single file
- `base/`: Layered Home Manager configurations
  - `base/home.nix`: Common base configuration for all environments
  - `base/devsisters/`: Devsisters-specific extensions
  - `base/pylv/`: Pylv-specific extensions
- `modules/`: Modular configuration components
- `lib/`: Helper functions and environment loaders

### Environment Configurations

All environments are defined in `environments.nix` with the following structure:

- **`devsisters-macbook`**: ARM64 macOS (gyutak@/Users/gyutak) with devsisters base profile
- **`devsisters-macstudio`**: ARM64 macOS (gyutak@/Users/gyutak) with devsisters base profile
- **`pylv-denim`**: x86_64 Linux (gytkk@/home/gytkk) with pylv base profile
- **`pylv-sepia`**: x86_64 Linux (gytkk@/home/gytkk) with pylv base profile

Each environment specifies a `baseProfile` which determines which base configuration to load.

### Base System Architecture

The layered base system provides inheritance and customization:

1. **`base/home.nix`**: Common configuration imported by all company bases
   - Core modules (claude, git, terraform, vim, zsh)
   - Standard development packages
   - Basic programs configuration

2. **`base/devsisters/home.nix`**: Extends base with Devsisters-specific tools
   - Authentication tools (saml2aws, vault)
   - Eclair CLI with Ruby environment
   - Company-specific aliases and environment variables

3. **`base/pylv/home.nix`**: Extends base with minimal Pylv-specific configuration
   - Currently inherits base configuration
   - Ready for company-specific customizations

### Module System

- **`modules/claude/`**: Claude Code installation with MCP support enabled
- **`modules/git/`**: Git configuration (gytkk/gytk.kim@gmail.com) with LFS, custom aliases, and global gitignore
- **`modules/java/`**: Java version management (8, 17) with directory-based switching via direnv
- **`modules/zsh/`**: Zsh with Oh-My-Zsh, Powerlevel10k theme, fzf, direnv, and development aliases
- **`modules/terraform/`**: Terraform version management with environment variable support

### Key Features

- **Layered base system**: Common configuration with company-specific extensions
- **Multi-environment support**: Different user accounts and system architectures
- **Single file environment management**: All environments defined in `environments.nix`
- **Development tooling**: docker, uv, nodejs, kubectl, k9s, awscli2
- **Shell experience**: Zsh with syntax highlighting, autosuggestion, and custom aliases
- **Code editing**: Neovim with development utilities
- **Nix tooling**: nixfmt-rfc-style for code formatting

### Package Management

Base packages defined in `base/default.nix`:

- **System**: coreutils, findutils, ripgrep, direnv
- **Development**: docker, uv, nodejs, awscli2, yq, gcc
- **Java**: OpenJDK 8, OpenJDK 17 with version switching tools
- **JavaScript/TypeScript**: nodejs, typescript, pnpm, turbo
- **Go**: go compiler and tools
- **Python**: uv package manager
- **Kubernetes**: kubectl, kubectx, k9s, helm
- **Nix**: nixfmt-rfc-style

Company-specific packages added in respective base configurations:

- **Devsisters**: saml2aws, vault, eclair, ruby_3_1, databricks-cli, scala_2_12, scala_3, sbt
- **Pylv**: Currently none (inherits base only)

### Configuration Management

- Test changes: `home-manager build --flake .#<environment>`
- Apply changes: `home-manager switch --flake .#<environment>`
- Format code: `nixfmt-rfc-style` for consistent styling
- Version control: All configurations tracked in git

### Adding New Environments

To add a new company or environment:

1. **Add base configuration** (if new company):
   ```bash
   mkdir base/new-company
   # Create base/new-company/home.nix that imports ../home.nix
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
