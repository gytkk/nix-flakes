# Secret Key Investigation Result

Updated: 2026-04-19 UTC+09:00

## Scope

- File: `secrets/secrets.nix`
- Directory: `secrets/`
- Focus: current user-key usage and cleanup candidates

## Current Status

- This document supersedes the earlier 2026-04-13 note.
- The repository currently contains six live agenix secrets:
  - `cloudflare-tunnel-onyx-token.age`
  - `cloudflare-tunnel-sepia-token.age`
  - `databricks-token.age`
  - `discord-bot-token.age`
  - `gws-credentials.age`
  - `open-webui-env.age`
- `hermes-webui-env.age` and `hermes-discord-bot-token.age` were removed in commit
  `d7d80b1` on 2026-04-14.

## Current Key Layout

- `gytkk` is the default user recipient through `allUsers`.
- `gytkkCurrent` has been removed from `secrets/secrets.nix`.
- `open-webui-env.age` no longer carries a recipient exception.
- All live secrets now use the normal key groups defined in `secrets/secrets.nix`.

## Local Verification

- On 2026-04-19, `~/.ssh/id_ed25519.pub` matched:
  - `gytkk = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJhE4Uakcz7usa0aetMqb99LYybOQ0I+sWKOiAidmBio"`
- It did not match:
  - `gytkkCurrent = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH4fQ+YuQEWjtoSxCYydHbmerei0EQ2QC/z7GQZWjZmU"`
- Decryption from the `secrets/` directory succeeded for:
  - `open-webui-env.age`
  - `cloudflare-tunnel-onyx-token.age`
  - `gws-credentials.age`
  - `databricks-token.age`
- That confirms the current local machine can decrypt the actively used secrets with
  the `gytkk` key.

## Cleanup Candidates

- Keep `secrets/` file inventory as-is for now.
- There are no obviously unused `.age` files left in the directory.
- There is no remaining recipient-level cleanup tied to `gytkkCurrent`.
- Future cleanup, if needed, should focus on whether user keys should stay per-user
  or move to a clearer per-device naming scheme.

## Conclusion

- The user-key cleanup is complete for the current repository state.
- `gytkk` is the active default user key.
- `gytkkCurrent` is no longer part of the live secret recipient set.
