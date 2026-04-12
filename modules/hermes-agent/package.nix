{ pkgs, inputs }:
let
  basePackage = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
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
  '';
in
basePackage.overrideAttrs (old: {
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
  postFixup = (old.postFixup or "") + ''
    for bin in $out/bin/hermes $out/bin/hermes-agent $out/bin/hermes-acp; do
      wrapProgram "$bin" --prefix PYTHONPATH : ${pkgs.lib.escapeShellArg hermesSitecustomize}
    done
  '';
})
