# VS Code Module

This module provides Visual Studio Code (VSCodium) installation and configuration optimized for WSL development environments.

## What it does

- Installs VSCodium (open-source VS Code without telemetry)
- Configures essential development extensions
- Provides WSL-optimized settings for performance and functionality
- Installs language servers and development tools for enhanced IDE experience
- Sets up proper terminal integration with existing zsh configuration

## Features

### Core Installation
- **VSCodium**: Open-source VS Code distribution without Microsoft telemetry
- **Extension Management**: Declarative extension installation via Nix
- **Settings Management**: Reproducible VS Code configuration across systems

### Pre-installed Extensions

#### Remote Development
- **Remote-WSL**: Essential for WSL development workflow
- **Git Integration**: Enhanced git features with GitLens

#### Language Support
- **Python**: Full Python development support with linting and formatting
- **TypeScript/JavaScript**: Advanced TypeScript language features
- **Nix**: Syntax highlighting and language server for Nix files
- **YAML/JSON**: Configuration file support
- **Markdown**: Documentation and README editing

#### Development Tools
- **Docker**: Container development and management
- **Kubernetes**: K8s manifest editing and cluster management
- **Spell Checker**: Code spell checking for comments and strings

### Language Servers & Tools

#### Installed Language Servers
- **nil**: Nix language server for code completion and error checking
- **Pyright**: Python type checking and IntelliSense
- **TypeScript Language Server**: JavaScript/TypeScript support
- **YAML Language Server**: YAML file validation and completion
- **Dockerfile Language Server**: Docker container configuration support

#### Code Formatters
- **Black**: Python code formatter
- **Prettier**: JavaScript/TypeScript/JSON formatter
- **nixfmt-rfc-style**: Nix code formatter following RFC style

### WSL Optimization

#### Performance Settings
- **File Watching**: Optimized file watcher exclusions for better performance
- **Polling Mode**: Enabled for WSL file system compatibility
- **Search Optimization**: Reduced indexing overhead for better responsiveness

#### Terminal Integration
- **Default Shell**: Configured to use zsh from Nix profile
- **Path Integration**: Proper PATH setup for Nix-managed tools
- **Environment Variables**: WSL-appropriate environment configuration

### Development Workflow

#### Editor Configuration
- **Font**: JetBrains Mono with ligature support
- **Tab Settings**: 2-space indentation with smart detection
- **Auto-formatting**: Format on save with organize imports
- **Theme**: Default Dark+ theme with Seti file icons

#### Git Integration
- **Smart Commit**: Intelligent commit suggestions
- **Auto-fetch**: Automatic remote updates
- **Sync Integration**: Seamless push/pull operations

#### Python Development
- **Interpreter**: Configured for system Python
- **Linting**: Pylint integration for code quality
- **Type Checking**: Pyright for static analysis
- **Formatting**: Black formatter for consistent code style

## Requirements

- Nix package manager
- Home Manager
- WSL environment (for optimal performance)
- Access to nix-vscode-extensions flake input

## Configuration Details

### File Watching Exclusions
The module excludes several directories from file watching to improve performance:
- `.git/objects/` - Git object database
- `node_modules/` - Node.js dependencies  
- `.nix-store/` - Nix store paths
- `result/` - Nix build results

### Extension Source
Extensions are installed from the VS Code Marketplace via the `nix-vscode-extensions` flake input, ensuring reproducible extension versions.

### Settings Synchronization
All VS Code settings are managed declaratively through Nix, ensuring consistent configuration across different machines and system rebuilds.

## Usage

### Installation
After applying this module to your Home Manager configuration:

```bash
home-manager switch --flake .#wsl-ubuntu
```

### Launching VS Code
```bash
# Launch VS Code
code

# Open current directory
code .

# Open specific file
code filename.py
```

### WSL Integration
When using VS Code with WSL:
1. Install VS Code on Windows
2. Install Remote-WSL extension
3. Use `code .` from WSL terminal to open projects
4. VS Code will automatically connect to WSL and use the configured environment

### Extension Management
Extensions are managed through the Nix configuration. To add new extensions:
1. Find the extension in `nix-vscode-extensions`
2. Add it to the `extensions` list in `default.nix`
3. Rebuild your Home Manager configuration

### Language Server Integration
Language servers are automatically available and configured:
- **Nix**: `nil` provides completions and error checking
- **Python**: `pyright` offers type checking and IntelliSense
- **TypeScript**: Built-in language server for JavaScript/TypeScript

## Customization

### Switching to Official VS Code
To use official VS Code instead of VSCodium:
1. Change `package = pkgs.vscodium;` to `package = pkgs.vscode;`
2. Add `nixpkgs.config.allowUnfree = true;` to your configuration
3. Rebuild configuration

### Adding Extensions
Add new extensions to the `extensions` list:
```nix
extensions = with inputs.nix-vscode-extensions.extensions.x86_64-linux.vscode-marketplace; [
  # existing extensions...
  new-extension.name
];
```

### Modifying Settings
Update the `userSettings` attribute set to customize VS Code behavior:
```nix
userSettings = {
  # existing settings...
  "editor.fontSize" = 16;
  "workbench.colorTheme" = "Monokai";
};
```

## Troubleshooting

### Extension Installation Issues
If extensions fail to install:
1. Check that `nix-vscode-extensions` input is properly configured in `flake.nix`
2. Verify extension names match those in the marketplace
3. Try rebuilding with `--impure` flag if needed

### Performance Issues
For slow performance in WSL:
1. Ensure projects are stored in WSL file system (not Windows)
2. Add additional exclusions to `files.watcherExclude`
3. Consider disabling unused extensions

### Language Server Problems
If language servers don't work:
1. Verify language server packages are installed
2. Check VS Code output panel for error messages
3. Restart VS Code after configuration changes

## Integration with Other Modules

This module integrates seamlessly with:
- **Git Module**: Uses configured git settings and credentials
- **Zsh Module**: Terminal integration with configured shell
- **Development Tools**: Works with mise, uv, and other dev tools

The configuration is designed to work as part of the larger Nix flakes Home Manager setup, providing a cohesive development environment.