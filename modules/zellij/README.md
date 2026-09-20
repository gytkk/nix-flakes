# Zellij

[default.nix](default.nix) installs a `zellij` wrapper and a generated `~/.config/zellij/config.kdl` rendered from the shared [config.kdl](files/config.kdl) template. Edit the template and run `home-manager switch --flake .#<environment>` to apply configuration changes. On macOS, rendering inserts `copy_command "pbcopy"` for clipboard access.

The template selects `modules.commonTheme`. Home Manager links `~/.config/zellij/themes` to the generated [theme exports](../../themes/exports/zellij). Change theme definitions through the [canonical theme pipeline](../../themes/README.md).

Running `zellij` without arguments opens the builtin `welcome` layout. Calls with arguments pass through to the packaged Zellij binary; the template's default layout is `default`. The repository's Zsh module provides the `zj` alias and leaves startup to the user.

The template disables startup tips and unbinds `Ctrl+b` so terminal applications receive that key instead of entering Zellij's tmux mode.
