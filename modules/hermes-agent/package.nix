{ pkgs, inputs }:
let
  basePackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  hermesPythonEnv = pkgs.callPackage "${inputs.hermes-agent}/nix/python.nix" {
    inherit (inputs.hermes-agent.inputs) uv2nix pyproject-nix pyproject-build-systems;
  };
  hermesSitecustomize = pkgs.writeTextDir "sitecustomize.py" ''
    import os
    import stat
    from pathlib import Path


    def _normalize_skills_tree() -> None:
        hermes_home = Path(os.environ.get("HERMES_HOME", Path.home() / ".hermes"))
        skills_dir = hermes_home / "skills"
        if not skills_dir.exists():
            return

        for path in (skills_dir, *skills_dir.rglob("*")):
            try:
                current_mode = path.stat().st_mode
                writable_mode = current_mode | stat.S_IWUSR | stat.S_IWGRP
                if path.is_dir():
                    writable_mode |= stat.S_IXUSR | stat.S_IXGRP | stat.S_ISGID
                os.chmod(path, writable_mode)
            except OSError:
                continue


    try:
        from tools import skills_sync as _skills_sync
    except Exception:
        _skills_sync = None

    if _skills_sync is not None:
        _orig_sync_skills = _skills_sync.sync_skills

        def _patched_sync_skills(*args, **kwargs):
            result = _orig_sync_skills(*args, **kwargs)
            _normalize_skills_tree()
            return result

        _skills_sync.sync_skills = _patched_sync_skills


    def _hex_triplet(value: str):
        if isinstance(value, str) and len(value) == 7 and value.startswith("#"):
            return tuple(int(value[i:i + 2], 16) for i in (1, 3, 5))
        return None


    def _skin_hex(skin, key: str, fallback: str) -> str:
        value = skin.get_color(key, fallback)
        if isinstance(value, str) and len(value) == 7 and value.startswith("#"):
            return value
        return fallback


    def _patch_inline_diff_colors() -> None:
        try:
            import agent.display as _display
            from hermes_cli.skin_engine import get_active_skin
        except Exception:
            return

        if getattr(_display, "_nix_flakes_diff_patch", False):
            return

        _orig_diff_ansi = _display._diff_ansi

        def _patched_diff_ansi():
            colors = dict(_orig_diff_ansi())
            try:
                skin = get_active_skin()
                minus_fg = _hex_triplet(skin.get_color("diff_minus_fg", ""))
                minus_bg = _hex_triplet(skin.get_color("diff_minus_bg", ""))
                plus_fg = _hex_triplet(skin.get_color("diff_plus_fg", ""))
                plus_bg = _hex_triplet(skin.get_color("diff_plus_bg", ""))

                if minus_fg and minus_bg:
                    fr, fg, fb = minus_fg
                    br, bg, bb = minus_bg
                    colors["minus"] = f"\033[38;2;{fr};{fg};{fb};48;2;{br};{bg};{bb}m"
                if plus_fg and plus_bg:
                    fr, fg, fb = plus_fg
                    br, bg, bb = plus_bg
                    colors["plus"] = f"\033[38;2;{fr};{fg};{fb};48;2;{br};{bg};{bb}m"
            except Exception:
                pass
            return colors

        _display._diff_ansi = _patched_diff_ansi
        _display._nix_flakes_diff_patch = True
        _display.reset_diff_colors()


    def _patch_prompt_toolkit_colors() -> None:
        try:
            import hermes_cli.skin_engine as _skin_engine
        except Exception:
            return

        if getattr(_skin_engine, "_nix_flakes_prompt_toolkit_patch", False):
            return

        _orig_get_overrides = _skin_engine.get_prompt_toolkit_style_overrides

        def _patched_get_prompt_toolkit_style_overrides():
            overrides = dict(_orig_get_overrides())
            try:
                skin = _skin_engine.get_active_skin()
                prompt_fg = _skin_hex(skin, "prompt", _skin_hex(skin, "banner_text", "#FFF8DC"))
                menu_fg = _skin_hex(skin, "completion_fg", _skin_hex(skin, "banner_text", "#FFF8DC"))
                menu_bg = _skin_hex(skin, "completion_bg", "#f5f5f5")
                current_fg = _skin_hex(skin, "completion_current_fg", menu_fg)
                current_bg = _skin_hex(skin, "completion_current_bg", "#bfceff")
                meta_fg = _skin_hex(skin, "completion_meta_fg", _skin_hex(skin, "banner_dim", "#555555"))
                meta_bg = _skin_hex(skin, "completion_meta_bg", menu_bg)
                current_meta_fg = _skin_hex(skin, "completion_current_meta_fg", _skin_hex(skin, "ui_accent", current_fg))
                current_meta_bg = _skin_hex(skin, "completion_current_meta_bg", current_bg)
                overrides.update({
                    "input-area": prompt_fg,
                    "prompt": prompt_fg,
                    "prompt-working": prompt_fg,
                    "text-area": prompt_fg,
                    "text-area.prompt": prompt_fg,
                    "completion-menu": f"bg:{menu_bg} {menu_fg}",
                    "completion-menu.completion": f"bg:{menu_bg} {menu_fg}",
                    "completion-menu.completion.current": f"bg:{current_bg} {current_fg}",
                    "completion-menu.meta.completion": f"bg:{meta_bg} {meta_fg}",
                    "completion-menu.meta.completion.current": f"bg:{current_meta_bg} {current_meta_fg}",
                })
            except Exception:
                pass
            return overrides

        _skin_engine.get_prompt_toolkit_style_overrides = _patched_get_prompt_toolkit_style_overrides
        _skin_engine._nix_flakes_prompt_toolkit_patch = True


    _patch_inline_diff_colors()
    _patch_prompt_toolkit_colors()
  '';
in
basePackage.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
  passthru = (old.passthru or { }) // {
    pythonEnv = hermesPythonEnv;
    pythonExecutable = "${hermesPythonEnv}/bin/python";
    pythonSitePackages = "${hermesPythonEnv}/${pkgs.python311.sitePackages}";
    sitecustomize = hermesSitecustomize;
  };
  postFixup = (old.postFixup or "") + ''
    for bin in $out/bin/hermes $out/bin/hermes-agent $out/bin/hermes-acp; do
      wrapProgram "$bin" \
        --unset NO_COLOR \
        --set-default PROMPT_TOOLKIT_COLOR_DEPTH DEPTH_24_BIT \
        --prefix PYTHONPATH : ${pkgs.lib.escapeShellArg hermesSitecustomize}
    done
  '';
})
