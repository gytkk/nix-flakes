# nix-flakes

Home Manager configuration using Nix flakes for multiple environments.

## Usage

### Install Home Manager profile for specific environment:

```bash
# For MacBook (Apple Silicon)
home-manager switch --flake .#macbook

# For MacStudio (Apple Silicon)
home-manager switch --flake .#macstudio

# For WSL Ubuntu
home-manager switch --flake .#wsl-ubuntu
```

### Build without switching:

```bash
# Build configuration for specific environment
home-manager build --flake .#macbook
```

### List available configurations:

```bash
nix flake show
```

### Update flake inputs:

```bash
nix flake update
```
