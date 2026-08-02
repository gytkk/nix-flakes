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

The container shares the host network, but Ghost binds only to
`127.0.0.1:2368`. This avoids a Podman DNAT dependency while keeping the
application private. Nginx provides the Cloudflare Tunnel origin only at
`http://127.0.0.1:12368`, forwards requests to Ghost, and fixes the public
scheme and host as `https://ghost.pylv.dev`. Neither port is opened in the
NixOS firewall.

The Ghost 6 runtime in the image accepts the SQLite configuration override, but
the Docker Official Image documentation only supports the SQLite filename in
development mode and requires MySQL for its supported production deployment.
Treat this single-instance production SQLite deployment as an intentional,
locally operated exception and test Ghost upgrades against a restored backup
before changing the pinned image.

### Declarative Settings and Theme Plan

Status: proposed. Implement this only after approving the remaining product and
security decisions below.

#### Desired State

- Anyone can read public posts without creating an account.
- Member signup, newsletters, and comments are disabled initially.
- Staff continue to authenticate through Ghost Admin at `/ghost`.
- Supported publication settings are reconciled through the Ghost Admin API;
  the SQLite database is never edited directly.
- A repository-managed custom theme controls layout and styling.
- Secrets remain encrypted with agenix and never enter the Nix store, generated
  units, logs, or Git history.

The initial managed Ghost settings are:

| Ghost setting | Desired value | Purpose |
| --- | --- | --- |
| `is_private` | `false` | Allow unauthenticated site visits |
| `members_signup_access` | `none` | Disable member signup and member features |
| `default_content_visibility` | `public` | Make new posts public by default |
| `comments_enabled` | `off` | Disable member-only comments |

#### Configuration Boundaries

| Concern | Source of truth |
| --- | --- |
| Container, database, URL, mail, storage, and proxy | `ghost.nix` |
| Selected publication settings and navigation | Admin API desired-state file |
| Owner account and initial custom integration | One-time Ghost Admin bootstrap |
| Admin API credential | agenix secret |
| Layout, templates, CSS, JavaScript, and theme defaults | Repository-managed Ghost theme |
| Posts, pages, images, and other editorial content | Ghost content database and uploads |
| Public hostname and optional admin access policy | Cloudflare Zero Trust dashboard |

Editorial content should not be continuously reconciled by Nix. This keeps
normal authoring in Ghost Admin independent from infrastructure deployments.

#### Proposed Repository Layout

```text
hosts/pylv-sepia/
├── ghost.nix
└── ghost/
    ├── settings.json
    ├── sync-settings.js
    ├── routes.yaml
    └── theme/
        ├── package.json
        ├── default.hbs
        ├── index.hbs
        ├── post.hbs
        ├── page.hbs
        ├── partials/
        └── assets/
            ├── css/
            ├── js/
            └── images/
```

Keep the sync script narrow: it should update only keys explicitly present in
`settings.json`. It must not overwrite unrelated settings changed through Ghost
Admin.

#### Implementation Phases

1. **Finish the current runtime rollout**
   - Activate the host-network and backup ownership fix.
   - Run a manual backup and verify the SQLite integrity check and archive.
   - Confirm the origin returns HTTP 200 after a Ghost restart.

2. **Bootstrap Admin API access**
   - Create the Owner account manually if it does not exist.
   - Create one custom integration dedicated to configuration reconciliation.
   - Encrypt its Admin API key as a new agenix secret.
   - Confirm the key can read and update settings without printing it in logs.

3. **Add idempotent settings reconciliation**
   - Add the desired-state JSON and a small Admin API client.
   - Generate short-lived Admin API JWTs only in memory.
   - Add `ghost-settings-sync.service` after `podman-ghost.service`.
   - Wait for the Ghost health check before calling the API, use bounded retries,
     and fail with actionable errors.
   - Snapshot the currently managed values before the first write so they can be
     restored without editing SQLite.

4. **Add the repository-managed theme**
   - Start from the current Source theme behavior rather than rebuilding every
     feature at once.
   - Package the theme from the repository and mount it read-only into
     `/var/lib/ghost/content/themes`.
   - Validate it with GScan during checks.
   - Activate it through the Admin API only after validation and Ghost startup.
   - Keep Source available as the immediate fallback theme.
   - Put adjustable colors, typography, and layout choices in Ghost custom theme
     settings; keep structural layout in Handlebars and CSS.

5. **Add routing only when required**
   - Keep Ghost's default routes for the first theme release.
   - Add and mount `routes.yaml` only for a concrete collection, channel, or URL
     requirement.
   - Validate feeds, pagination, tags, authors, and canonical URLs after routing
     changes.

6. **Make the publication public safely**
   - Remove the current host-wide Cloudflare Access requirement before launch.
   - Prefer Ghost's built-in Staff authentication initially.
   - If Cloudflare Access is retained for admin defense in depth, do not protect
     `/ghost*` blindly: explicitly verify that the public Content API,
     ActivityPub endpoints, assets, feeds, and any member endpoints remain
     reachable without Cloudflare authentication.

#### Verification and Rollout

Before committing each logical change:

```bash
nixfmt hosts/pylv-sepia/ghost.nix
nix flake check --no-build
nix build .#nixosConfigurations.pylv-sepia.config.system.build.toplevel
```

Also verify:

- GScan accepts the packaged theme.
- The generated Podman unit mounts the intended theme and no secret value.
- The sync unit is idempotent and a second run makes no unexpected changes.
- An unauthenticated request can read the home page and a public post.
- Member signup, newsletter subscription, and comments are unavailable.
- Ghost Admin still accepts the Owner account.
- RSS, sitemap, public assets, Content API, and ActivityPub endpoints do not
  redirect to Cloudflare Access.
- A manual `ghost-backup.service` run produces an integrity-checked archive.

Activate only after the checks pass:

```bash
sudo nixos-rebuild switch --flake .#pylv-sepia
```

#### Rollback

- Retain a pre-change backup and the API snapshot of managed settings.
- Revert the relevant Git commit and switch the previous NixOS configuration.
- Reactivate Source through Ghost Admin or the Admin API if the custom theme
  fails.
- Restore managed settings through the API snapshot; do not patch SQLite.

#### Decisions Required Before Implementation

- Select the first theme direction: Source-derived minimal customization or a
  new visual design.
- Decide whether Ghost Staff authentication alone is sufficient or whether a
  carefully scoped Cloudflare Access policy is required for admin routes.
- Decide whether navigation should be API-managed or remain editorial.
- Select an SMTP provider before enabling password recovery, staff invitations,
  or members. Select Mailgun separately before enabling newsletters.
- Decide whether GScan is run through a pinned package derivation or a separate
  repository check.

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
