# nix-flakes

Home Manager configuration using Nix flakes for multiple environments.

## Usage

### Install Nix, Home Manager

- Nix: <https://nixos.org/download>
- Home Manager: <https://nix-community.github.io/home-manager/index.xhtml#sec-install-standalone>

Home manager 실행을 위한 config를 줘야 한다.

```
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf
```

### Install Home Manager profile for specific environment

```bash
home-manager switch --flake .#devsisters-macbook

home-manager switch --flake .#devsisters-macstudio

home-manager switch --flake .#wsl-ubuntu
```

### Build without switching

```bash
# Build configuration for specific environment
home-manager build --flake .#macbook
```

### List available configurations

```bash
nix flake show
```

### Update flake inputs

```bash
nix flake update
```

## References

- Nix Packages: <https://search.nixos.org/packages>
