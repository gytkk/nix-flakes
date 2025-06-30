# VS Code Installation Plan for x86_64 WSL Environment

## Overview

This plan outlines the installation of Visual Studio Code for the x86_64 WSL Ubuntu environment using Nix flakes, with proper configuration for WSL-specific features and development workflow integration.

## Background Research

### WSL Integration Challenges
- VS Code in WSL requires proper server-client architecture
- NixOS-WSL has specific compatibility issues with VS Code server
- Extension marketplace access and WSL Remote extension are crucial
- File system boundaries between Windows and Linux need consideration

### Available Options

#### Option 1: VSCodium (Recommended)
- **Package**: `vscodium` from nixpkgs
- **License**: Open source, no unfree license issues
- **Features**: Full VS Code functionality without Microsoft telemetry
- **Extensions**: Compatible with Open VSX Registry
- **WSL Support**: Full WSL integration support

#### Option 2: Official VS Code
- **Package**: `vscode` from nixpkgs  
- **License**: Unfree, requires `allowUnfree = true`
- **Features**: Official Microsoft VS Code with full marketplace access
- **Extensions**: Access to Microsoft marketplace
- **WSL Support**: Native WSL integration with Remote-WSL extension

## Implementation Strategy

### Phase 1: Module Creation
1. **Create VS Code Module Structure**
   ```
   modules/vscode/
   ├── default.nix      # Main module configuration
   └── README.md        # Documentation
   ```

2. **Module Features**
   - Install VSCodium by default (can be overridden to vscode)
   - Pre-install essential development extensions
   - Configure WSL-specific settings
   - Set up proper file associations and editor preferences

### Phase 2: Environment Integration
1. **Update WSL Environment**
   - Modify `environments/wsl-ubuntu.nix` to include vscode module
   - Ensure proper system architecture targeting (x86_64-linux)

2. **Extension Management**
   - Utilize existing `nix-vscode-extensions` flake input
   - Pre-configure development extensions:
     - WSL extension for remote development
     - Git integration extensions
     - Language support (Python, JavaScript, etc.)
     - Nix language support

### Phase 3: Configuration Optimization
1. **WSL-Specific Settings**
   - Configure proper file watching for WSL file system
   - Set up integrated terminal to use WSL environment
   - Optimize performance for WSL environment

2. **Development Workflow Integration**
   - Integrate with existing zsh configuration
   - Connect with git module settings
   - Ensure compatibility with mise and other dev tools

## Technical Implementation Details

### Module Structure (`modules/vscode/default.nix`)
```nix
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  # Package installation (VSCodium by default)
  home.packages = with pkgs; [
    vscodium
  ];

  # VS Code configuration
  programs.vscode = {
    enable = true;
    package = pkgs.vscodium;
    
    # Essential extensions
    extensions = with inputs.nix-vscode-extensions.extensions.x86_64-linux.vscode-marketplace; [
      # WSL and Remote Development
      ms-vscode-remote.remote-wsl
      
      # Git Integration
      eamodio.gitlens
      
      # Language Support
      ms-python.python
      bradlc.vscode-tailwindcss
      
      # Nix Support
      bbenoist.nix
    ];
    
    # User settings optimized for WSL
    userSettings = {
      "terminal.integrated.shell.linux" = "/home/gytkk/.nix-profile/bin/zsh";
      "files.watcherExclude" = {
        "**/.git/objects/**" = true;
        "**/.git/subtree-cache/**" = true;
        "**/node_modules/*/**" = true;
      };
      "remote.WSL.fileWatcher.polling" = true;
    };
  };
}
```

### Environment Update (`environments/wsl-ubuntu.nix`)
```nix
{
  # System information
  system = "x86_64-linux";
  
  # User information
  username = "gytkk";
  homeDirectory = "/home/gytkk";
  
  # Environment-specific modules
  extraModules = [
    ../modules/vscode
  ];
}
```

## Benefits

### Development Experience
- **Unified Environment**: Single development environment across Windows and WSL
- **Native Performance**: Code execution in native Linux environment
- **Tool Integration**: Seamless integration with existing Nix-managed development tools
- **Version Control**: Consistent VS Code configuration across different machines

### WSL Optimization
- **File System Performance**: Optimized file watching and indexing for WSL
- **Terminal Integration**: Direct integration with configured zsh shell
- **Extension Compatibility**: Proper extension loading in WSL context

### Maintenance Benefits
- **Declarative Configuration**: VS Code settings managed through Nix
- **Reproducible Setup**: Consistent development environment setup
- **Extension Management**: Automatic extension installation and updates
- **Cross-Platform Compatibility**: Same configuration works on different systems

## Potential Challenges and Solutions

### Extension Marketplace Access
- **Challenge**: Some extensions may not be available in Open VSX Registry
- **Solution**: Provide option to use official VS Code with unfree license allowance

### Performance in WSL
- **Challenge**: File watching and indexing can be slow in WSL
- **Solution**: Optimized settings for WSL file system performance

### Windows-Linux File System Boundaries
- **Challenge**: Working with files across Windows and Linux file systems
- **Solution**: Configure proper workspace settings and file watching exclusions

## Testing Strategy

1. **Clean Installation Test**
   - Test on fresh WSL Ubuntu installation
   - Verify all extensions install correctly
   - Confirm WSL integration works properly

2. **Development Workflow Test**
   - Test with actual development projects
   - Verify git integration functionality
   - Confirm terminal and shell integration

3. **Performance Test**
   - Test file watching and indexing performance
   - Verify startup time is acceptable
   - Test extension loading performance

## Rollback Strategy

If issues arise:
1. **Module Disable**: Remove vscode module from WSL environment configuration
2. **Package Fallback**: Switch from vscodium to official vscode if needed
3. **Manual Installation**: Fall back to manual VS Code installation if Nix approach fails

## Future Enhancements

### Planned Improvements
- **Profile-Specific Extensions**: Different extension sets for different development types
- **Workspace Templates**: Pre-configured workspaces for common project types
- **Integration Enhancements**: Deeper integration with other development tools

### Potential Integrations
- **DevContainers**: Configuration for development containers
- **Remote Repositories**: Integration with remote git repositories
- **Cloud Sync**: Settings sync across different development environments

## Success Criteria

- [ ] VS Code/VSCodium successfully installs via Nix
- [ ] WSL Remote extension works properly
- [ ] Essential development extensions are pre-installed
- [ ] Terminal integration with zsh works correctly
- [ ] Git integration functions properly
- [ ] File watching and indexing perform acceptably
- [ ] Configuration is reproducible across system rebuilds

## Implementation Timeline

1. **Day 1**: Create vscode module and basic configuration
2. **Day 1**: Update WSL environment to include vscode module
3. **Day 1**: Test basic installation and functionality
4. **Day 1**: Create comprehensive documentation

This plan provides a comprehensive approach to integrating VS Code into the existing Nix flakes Home Manager configuration while addressing the specific challenges of WSL environments.
