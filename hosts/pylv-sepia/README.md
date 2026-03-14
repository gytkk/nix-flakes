# pylv-sepia

NixOS configuration for pylv-sepia server, managed from the main flake.

## Initial Installation

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#pylv-sepia \
  root@<hostname>
```

## Updating Configuration

### From Local Machine

```bash
# From repository root
nix run nixpkgs#nixos-rebuild -- switch \
  --flake .#pylv-sepia \
  --target-host root@<hostname>
```

### On the Server

```bash
sudo nixos-rebuild switch --flake github:gytkk/nix-flakes#pylv-sepia
```

## Adding Packages

User packages are managed via Home Manager modules in `base/pylv/`.

Edit `base/pylv/home.nix` or `base/pylv/sepia.nix`:

```nix
home.packages = with pkgs; [
  # add packages here
];
```

## Obsidian Sync (Headless) Setup

서버 배포 후 1회 실행이 필요합니다.

```bash
# 1. SSH로 서버 접속
ssh pylv-sepia

# 2. Obsidian 계정 로그인
ob login

# 3. 원격 vault 목록 확인
ob sync-list-remote

# 4. vault 연결 (vault 이름은 ob sync-list-remote 결과 참고)
ob sync-setup --vault "<Vault Name>" --path ~/obsidian

# 5. pull-only 모드 설정 (서버는 읽기 전용)
ob sync-config --path ~/obsidian --sync-mode pull-only

# 6. systemd 서비스 재시작
sudo systemctl restart obsidian-sync

# 7. 상태 확인
systemctl status obsidian-sync
ob sync-status --path ~/obsidian
```

## File Structure

| File | Description |
|------|-------------|
| `configuration.nix` | NixOS system configuration (services, users) |
| `obsidian-headless.nix` | Obsidian Headless Sync service |
| `openclaw.nix` | OpenClaw Gateway AI assistant service |
| `disk-config.nix` | Disk partitioning configuration (disko) |
| `hardware-configuration.nix` | Auto-generated hardware configuration |

## Shared Modules

This configuration uses shared modules from the main flake:

- `modules/git` - Git configuration
- `modules/zsh` - Zsh with Oh-My-Zsh and Powerlevel10k
- `modules/vim` - Neovim configuration
- `modules/claude` - Claude Code configuration
- `modules/terraform` - Terraform version management
