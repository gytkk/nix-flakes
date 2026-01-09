# AGENTS.md

This file provides guidance to agentic coding agents working in this Nix flakes repository.

## Critical Rules

- Follow existing code patterns and module structure in this repository
- Use `nixfmt-rfc-style` to format all Nix files before committing
- Test changes with `home-manager build` before applying with `switch`
- CLAUDE.md is the primary source of truth - this file supplements it

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

## Architecture Quick Reference

```
base/default.nix          # Common configuration for all environments
base/<company>/home.nix   # Company-specific extensions
modules/<name>/default.nix # Reusable module
environments.nix          # All environment definitions
lib/builders.nix          # mkHomeConfig, mkNixOSConfig helpers
overlays/default.nix      # nixpkgs version overlays
```

## Git Conventions

- Use [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `docs:`, `refactor:`
- Write in imperative mood: "Add feature" not "Added feature"
- Keep commits atomic: one logical change per commit
- Do NOT push unless explicitly requested

## Security

- Never commit secrets or credentials
- Use agenix for secrets management:
  ```nix
  age.secrets.secretName.file = ../../secrets/secret-name.age;
  ```
- Secrets decrypt to `/run/agenix/<secretName>`

## Documentation

- Update CLAUDE.md for development guidelines
- Update README.md for user-facing documentation
- Do NOT create one-off documentation files
- Use comments sparingly, only for complex logic
