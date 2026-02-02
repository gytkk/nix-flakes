{ inputs, ... }:

{
  # Fix for nix-openclaw hasown dependency issue
  # See: https://github.com/openclaw/nix-openclaw/issues/45
  # The form-data package requires 'hasown' but pnpm doesn't symlink it
  openclaw-fix = final: prev: {
    openclaw-gateway = prev.openclaw-gateway.overrideAttrs (oldAttrs: {
      # Use postFixup because the upstream uses a custom installPhase script
      # that doesn't call runHook postInstall
      postFixup = (oldAttrs.postFixup or "") + ''
        # Work around missing dependency declaration in form-data (hasown).
        # form-data requires 'hasown' but doesn't declare it, causing runtime failures.
        # This follows the same pattern as the strip-ansi workaround in upstream.
        form_data_pkg="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/form-data@*/node_modules/form-data" -print | head -n 1)"
        hasown_src="$(find "$out/lib/openclaw/node_modules/.pnpm" -path "*/hasown@*/node_modules/hasown" -print | head -n 1)"

        if [ -n "$hasown_src" ]; then
          if [ -n "$form_data_pkg" ] && [ ! -e "$form_data_pkg/../hasown" ]; then
            echo "Linking hasown into form-data node_modules..."
            ln -s "$hasown_src" "$form_data_pkg/../hasown"
          fi

          # Also link to gateway root node_modules for safety
          if [ ! -e "$out/lib/openclaw/node_modules/hasown" ]; then
            mkdir -p "$out/lib/openclaw/node_modules"
            ln -s "$hasown_src" "$out/lib/openclaw/node_modules/hasown"
          fi
        fi
      '';
    });
  };

  # 각 nixpkgs 버전을 pkgs.X로 접근 가능하게 하는 overlay
  # Lazy import: 실제 사용되는 패키지만 import하여 evaluation 시간 단축
  nixpkgs-versions =
    final: _prev:
    let
      # Lazy import helper - 패키지가 실제로 접근될 때만 nixpkgs를 import
      mkLazyPkgs =
        nixpkgsInput: packages:
        builtins.listToAttrs (
          map (name: {
            inherit name;
            value =
              (import nixpkgsInput {
                localSystem = final.stdenv.hostPlatform.system;
                config.allowUnfree = true;
              }).${name};
          }) packages
        );
    in
    {
      # stable-25_05: ruby_3_2, micromamba 사용
      stable-25_05 = mkLazyPkgs inputs.nixpkgs-25_05 [
        "ruby_3_2"
        "micromamba"
      ];

      # master: opencode, claude-code 사용
      master = mkLazyPkgs inputs.nixpkgs-master [
        "opencode"
        "claude-code"
      ];
    };
}
