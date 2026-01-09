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

## File Structure

| File | Description |
|------|-------------|
| `configuration.nix` | NixOS system configuration (services, users) |
| `disk-config.nix` | Disk partitioning configuration (disko) |
| `hardware-configuration.nix` | Auto-generated hardware configuration |

## Shared Modules

This configuration uses shared modules from the main flake:

- `modules/git` - Git configuration
- `modules/zsh` - Zsh with Oh-My-Zsh and Powerlevel10k
- `modules/vim` - Neovim configuration
- `modules/claude` - Claude Code configuration
- `modules/terraform` - Terraform version management

## Kubernetes (k3s)

### Immich Migration to Kubernetes

Kubernetes manifests are stored in `k8s/immich/`.

#### Prerequisites

1. Install CloudNative-PG operator:

```bash
kubectl apply --server-side -f \
  https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.25/releases/cnpg-1.25.1.yaml
```

2. Wait for operator to be ready:

```bash
kubectl wait --for=condition=Available deployment/cnpg-controller-manager \
  -n cnpg-system --timeout=120s
```

#### Deploy Immich

```bash
# 1. Create namespace and PVCs
kubectl apply -f k8s/immich/namespace.yaml
kubectl apply -f k8s/immich/pvc.yaml

# 2. Deploy PostgreSQL (CloudNative-PG)
kubectl apply -f k8s/immich/postgres.yaml

# 3. Wait for database to be ready
kubectl wait --for=condition=Ready cluster/immich-database -n immich --timeout=300s

# 4. Deploy Redis
kubectl apply -f k8s/immich/redis.yaml

# 5. Install Immich via Helm
helm install immich oci://ghcr.io/immich-app/immich-charts/immich \
  -n immich -f k8s/immich/values.yaml

# 6. Verify deployment
kubectl get pods -n immich
```

#### Configure Cloudflare Tunnel

Add to Cloudflare Zero Trust dashboard:
- Public hostname: `photos.yourdomain.com`
- Service: `http://immich-server.immich.svc.cluster.local:2283`

#### Data Migration (from NixOS service)

```bash
# 1. Stop NixOS Immich service
sudo systemctl stop immich-server

# 2. Copy media files to new location
sudo rsync -av /var/lib/immich/upload/ /srv/immich/library/upload/

# 3. Export database (if needed)
# The NixOS service uses its own PostgreSQL, you may need to export/import data
```
