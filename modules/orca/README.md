# Orca

[default.nix](default.nix) installs a generated appearance patch at `~/.config/orca/settings.json` and the `orca-apply-settings` command. The module is enabled by default on macOS. Orca itself is installed and updated separately.

The selected `modules.commonTheme` supplies a custom terminal theme from [the Orca exports](../../themes/exports/orca). Its terminal colors include the same app-specific overrides as Ghostty. The app follows the theme's light or dark mode, and the left sidebar matches the terminal. [appearance.json](files/appearance.json) sets the font, cursor, opacity, and contrast. Starship continues to use the existing zsh initialization and shared `~/.config/starship.toml`.

The settings contract is verified against Orca 1.4.206. This version wraps `terminalFontFamily` in double quotes before passing it to xterm.js, so the value intentionally leaves its outer quotes implicit to form the JetBrains Mono and Sarasa Mono CL fallback list. The font size starts at 12; Orca and Ghostty use different renderers, so equal numeric sizes do not guarantee equal visual sizes. Orca's bar cursor does not expose Ghostty's cursor thickness adjustment. Color Contrast uses a custom ratio of 1.6, matching the Ghostty configuration.

## Apply settings

1. Apply Home Manager for this checkout, for example `home-manager switch --flake .#devsisters-macbook`.
2. Quit Orca completely, including any Orca server using the profile. Keep it closed until the apply command finishes.
3. Run `orca-apply-settings`, then reopen Orca.

Home Manager only installs the patch and command. Orca does not read this patch automatically, and activation does not modify its data file. Run the apply command again after changing the common theme or appearance settings and applying Home Manager.

The command updates only the patch's keys inside `settings`, replaces custom themes with matching managed IDs, and preserves other settings, custom themes, projects, and sessions. It clears the legacy global terminal color overrides so they cannot mask the selected theme. It refuses to run while Orca is open, rejects malformed data, makes a private backup before each change, and replaces the data file atomically. Repeated application without an intervening change does not create another backup. To restore a backup, quit Orca and copy the backup path printed by the command over the same data file.

By default, the command reads `activeProfileId` from `~/Library/Application Support/orca/orca-profile-index.json` and updates `profiles/<id>/orca-data.json` under that directory. Only installations without a profile index use the legacy root `orca-data.json`. An invalid index or missing active profile stops the command. Set `modules.orca.dataFile` to an explicit file path to target another profile. This module currently supports macOS only.

## Checks

```bash
uv run --no-project -m unittest discover -s themes -p 'test_orca_generator.py'
uv run --no-project -m unittest discover -s modules/orca -p 'test_*.py'
uv run --no-project themes/check_templates.py
```
