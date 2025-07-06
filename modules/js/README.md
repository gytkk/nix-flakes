# JavaScript Module

This module provides JavaScript development tools and global package management using pnpm.

## Features

- Global npm/pnpm package installation support
- NestJS CLI example implementation
- Helper scripts for package management
- Declarative package configuration

## Usage

### Global Package Installation

The module provides two approaches for global package installation:

#### 1. Declarative Nix Packages (Recommended)

Add packages directly to the Nix configuration:

```nix
# In modules/js/default.nix
nestjs-cli = buildGlobalNpmPackage {
  pname = "@nestjs/cli";
  version = "10.2.1";
  # ... configuration
};
```

#### 2. Runtime pnpm Installation

Use the provided helper script:

```bash
pnpm-global-install @nestjs/cli
```

## Configuration

The module automatically:
- Configures pnpm for global package installation
- Creates tracking files for installed packages
- Provides helper scripts for package management

## Example Packages

- `@nestjs/cli` - NestJS command-line interface
- Add more packages by following the `buildGlobalNpmPackage` pattern

## Notes

- Hash values need to be calculated using `nix-prefetch-github` or similar tools
- Global packages are installed in the Nix store for reproducibility
- Use `pnpm-global-install` for ad-hoc package installations