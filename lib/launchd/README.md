# Launchd lifecycle backport

`backport.nix` applies one exact activation-script replacement to the pinned Home Manager launchd module. It deliberately fails when that source shape changes.

The replacement adapts the [macOS 26 `bootout --wait` gate](https://github.com/nix-community/home-manager/commit/ebc87daabc8d3f595e9a8b67107eaaa8115ad582), [bootstrap failure handling](https://github.com/nix-community/home-manager/commit/2f3da3d45fbf503f874bd7db7aa2c298e87ab9ea), and [harmless absent-domain handling](https://github.com/nix-community/home-manager/commit/79e6082586b3680ff32c8e75127545058f074fa4) to the pinned Home Manager revision `dcebe66f958673729896eec2de4abfd86ef22d21`. It remains limited to this repository's GUI-domain lifecycle and additionally aggregates per-agent failures and restores a replaced plist when a new bootstrap fails. A failed first bootstrap removes the newly installed plist so reapplication retries. It does not roll back the whole Home Manager generation.

Run the isolated behavioral fixture with `uv run --no-project -m unittest discover -s lib/launchd/tests -v`. It extracts the transformed activation body, injects fixture `launchctl` and `sw_vers` paths, and never contacts launchd. The fixture compares the pinned original behavior with the patch, tests rollback and reapplication, and verifies that dry-run does not change installed files.

On a Home Manager input update, compare the new lifecycle code with both snippets and rerun the fixture. Remove this patch and its import when upstream provides the required behavior. Keep real macOS activation and login checks separate from the stubbed lifecycle tests.
