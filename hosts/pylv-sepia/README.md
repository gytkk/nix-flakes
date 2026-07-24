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

## Ghost

Ghost runs as one declarative Podman container using the
`ghost:6.53.0-bookworm` release pinned by OCI digest. The container runs Ghost
in production mode with SQLite and persists its complete content directory at
`/var/lib/ghost` on the host. No database password or other Ghost secret is
stored in Nix.

The application port is published only as `127.0.0.1:2368`. Nginx provides the
Cloudflare Tunnel origin only at `http://127.0.0.1:12368`, forwards requests to
Ghost, and fixes the public scheme and host as `https://ghost.pylv.dev`. Neither
port is opened in the NixOS firewall.

The Ghost 6 runtime in the image accepts the SQLite configuration override, but
the Docker Official Image documentation only supports the SQLite filename in
development mode and requires MySQL for its supported production deployment.
Treat this single-instance production SQLite deployment as an intentional,
locally operated exception and test Ghost upgrades against a restored backup
before changing the pinned image.

### Deploy

Review and activate the configuration from the repository root:

```bash
nix flake check --no-build
sudo nixos-rebuild switch --flake .#pylv-sepia
```

The first activation pulls the pinned image and starts `podman-ghost.service`.
This repository does not configure the Cloudflare public hostname.

In Cloudflare Zero Trust, open the existing sepia tunnel and add this public
hostname:

- Public hostname: `ghost.pylv.dev`
- Service type: `HTTP`
- Origin URL: `http://127.0.0.1:12368`

No new tunnel token, secret, DNS listener, or firewall rule is required.

### Status and Restart

```bash
sudo systemctl status podman-ghost.service nginx.service
sudo podman healthcheck run ghost
curl --fail --head \
  --header 'Host: ghost.pylv.dev' \
  http://127.0.0.1:12368/
sudo journalctl --unit podman-ghost.service --unit nginx.service
```

Restart Ghost without restarting the Cloudflare Tunnel:

```bash
sudo systemctl restart podman-ghost.service
```

### Local Backups

`ghost-backup.timer` runs daily with up to one hour of randomized delay. It
stops `podman-ghost.service`, uses SQLite's online backup command, adds the rest
of `/var/lib/ghost` (including uploads, themes, and settings), writes archives
under `/var/lib/ghost-backups`, and removes archives older than 30 days. Because
Ghost remains stopped while both the database snapshot and content archive are
created, each completed archive is a coherent restore point. The backup starts
Ghost again after either success or failure.

Each daily or manually started backup briefly interrupts the blog while the
archive is created.

```bash
sudo systemctl status ghost-backup.timer
sudo systemctl start ghost-backup.service
sudo journalctl --unit ghost-backup.service
sudo ls -lh /var/lib/ghost-backups/ghost-*.tar.gz
```

These are local backups on the same server. They do not protect against host or
disk loss. Copy and verify them in an off-host backup system.

### Restore

Choose an archive, extract it to a staging directory, and verify the database
before stopping Ghost:

```bash
backup=/var/lib/ghost-backups/ghost-YYYYMMDDTHHMMSSZ.tar.gz
restore=/var/lib/ghost-restore
sudo test ! -e "$restore"
sudo install -d -m 0700 "$restore"
sudo tar -xzf "$backup" -C "$restore"
sudo "$(command -v sqlite3)" -readonly \
  "$restore/data/ghost.db" \
  'PRAGMA integrity_check;'
```

The integrity check must print `ok`. Then replace the content directory while
Ghost is stopped, retaining the previous directory as a local rollback:

```bash
restore=/var/lib/ghost-restore
rollback="/var/lib/ghost.before-restore-$(date --utc +%Y%m%dT%H%M%SZ)"
sudo systemctl stop podman-ghost.service
sudo mv /var/lib/ghost "$rollback"
sudo mv /var/lib/ghost-restore /var/lib/ghost
sudo chown -R 1000:1000 /var/lib/ghost
sudo chmod 0750 /var/lib/ghost
sudo systemctl start podman-ghost.service
sudo podman healthcheck run ghost
```

After verifying the public site and Ghost Admin, retain or remove the rollback
directory according to the server's storage policy.

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
| --- | --- |
| `configuration.nix` | NixOS system configuration and host module imports |
| `ghost.nix` | Ghost container, loopback nginx origin, and local backups |
| `disk-config.nix` | Disk partitioning configuration (disko) |
| `hardware-configuration.nix` | Auto-generated hardware configuration |

## Shared Modules

This configuration uses shared modules from the main flake:

- `modules/git` - Git configuration
- `modules/zsh` - Zsh with Oh-My-Zsh and Powerlevel10k
- `modules/vim` - Neovim configuration
- `modules/claude` - Claude Code configuration
- `modules/terraform` - Terraform version management
