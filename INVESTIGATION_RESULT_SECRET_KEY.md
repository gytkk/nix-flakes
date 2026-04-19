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

- `gytkk` is still the default user recipient through `allUsers`.
- `gytkkCurrent` is still defined, but it is only used for `open-webui-env.age`.
- The current repo state does not look like a broad key migration in progress.
- Instead, it has one explicit exception recipient set for Open WebUI.

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
- Make the `open-webui-env.age` exception explicit in `secrets/secrets.nix`.
- Decide whether `gytkkCurrent` is still needed:
  - If it is still needed, keep it scoped to the explicit Open WebUI exception and
    document why.
  - If it is no longer needed, rekey `open-webui-env.age` without it and remove the
    key definition.

## Conclusion

- The main cleanup need is documentation and recipient intent clarity.
- The immediate target is not deleting secret files.
- `gytkkCurrent` is currently a narrow exception, not the active default user key.
