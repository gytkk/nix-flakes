{
  config,
  options,
  lib,
  pkgs,
  username,
  homeDirectory,
  flakeDirectory,
  inputs,
  isWSL ? false,
  osConfig ? null,
  ...
}:

let
  agenixPackage = inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default;
  agx = pkgs.writeShellScriptBin "agx" ''
    set -eu

    secretsDir=${lib.escapeShellArg "${flakeDirectory}/secrets"}
    identity="$HOME/.ssh/id_ed25519"

    if [ ! -r "$identity" ]; then
      echo "agx: identity is not readable: $identity" >&2
      exit 1
    fi

    cd "$secretsDir"
    export RULES="$secretsDir/secrets.nix"
    exec ${agenixPackage}/bin/agenix "$@" -i "$identity"
  '';

  # Avoid exposing Wrangler's bundled node_modules, which conflicts with pkgs.typescript.
  wranglerBin = pkgs.buildEnv {
    name = "wrangler-bin-${pkgs.wrangler.version}";
    paths = [ pkgs.wrangler ];
    pathsToLink = [ "/bin" ];
  };

  # agenix의 store 경로 변경으로 launchd plist와 macOS 알림이 갱신되지 않도록 고정된 래퍼를 사용한다.
  # 스크립트가 바뀌면 아래 activation에서 래퍼를 다시 쓰고 secret을 마운트한다.
  agenixLaunchdWrapper = "${config.xdg.stateHome}/agenix-launchd-wrapper";

  # mkForce로 대체되기 전 agenix 명령은 raw option definitions의 list 값에서 복구한다.
  # Home Manager나 agenix가 안정된 실행 경로를 제공하면 이 우회 로직을 제거한다.
  agenixMountCommand =
    let
      args = lib.findFirst lib.isList null (
        map (d: d.activate-agenix.config.ProgramArguments or null) options.launchd.agents.definitions
      );
    in
    if args == null then null else lib.escapeShellArgs args;

  agenixWrapperSource =
    if agenixMountCommand == null then
      null
    else
      pkgs.writeScript "agenix-launchd-wrapper" ''
        #!/bin/sh
        exec ${agenixMountCommand}
      '';
in
{
  imports = [
    ./compat/home-manager.nix
    ../modules/claude-session-mining
    # 기본 모듈들 (항상 import됨)
    ../modules/agent-session-record
    ../modules/aerospace
    ../modules/claude
    ../modules/codex
    ../modules/ghostty
    ../modules/git
    ../modules/herdr
    ../modules/k9s
    ../modules/lsp
    ../modules/nix-gc
    ../modules/pi
    ../modules/shared-memory
    ../modules/tmux
    ../modules/vim
    ../modules/windows-terminal
    ../modules/zed
    ../modules/zellij
    ../modules/zsh
  ];

  options.modules.commonTheme = lib.mkOption {
    type = lib.types.str;
    default = "one-half-light";
    description = "Canonical theme id shared across theme-aware app modules.";
    example = "catppuccin-mocha";
  };

  config = {
    modules = {
      agentSessionRecord.enable = lib.mkDefault true;
      aerospace.enable = lib.mkDefault pkgs.stdenv.isDarwin;
      claude.enable = lib.mkDefault true;
      codex.enable = lib.mkDefault true;
      ghostty.enable = lib.mkDefault true;
      git.enable = lib.mkDefault true;
      herdr.enable = lib.mkDefault true;
      k9s.enable = lib.mkDefault true;
      lsp.enable = lib.mkDefault true;
      # NixOS hosts collect garbage at the system level via modules/nixos/baseline.nix.
      nixGc.enable = lib.mkDefault (osConfig == null);
      pi.enable = lib.mkDefault true;
      sharedMemory.enable = lib.mkDefault false;
      tmux.enable = lib.mkDefault true;
      vim.enable = lib.mkDefault true;
      windowsTerminal.enable = lib.mkDefault true;
      zed.enable = lib.mkDefault true;
      zellij.enable = lib.mkDefault true;
      zsh.enable = lib.mkDefault true;
    };

    # Disable news on update
    news.display = "silent";

    # services.home-manager.autoExpire is deliberately left off: it only expires
    # the home-manager profile, while each switch also adds a generation to the
    # nix-env profile beside it. modules/nix-gc prunes every profile instead.

    # 일회성 agenix 작업이 정상 종료 후 반복 실행되지 않도록 KeepAlive를 제거한다.
    # 세대가 바뀌어도 plist가 유지되도록 ProgramArguments는 고정된 래퍼를 가리킨다.
    launchd.agents.activate-agenix.config = lib.mkIf pkgs.stdenv.isDarwin {
      KeepAlive = lib.mkForce null;
      ProgramArguments = lib.mkIf (agenixMountCommand != null) (lib.mkForce [ agenixLaunchdWrapper ]);
    };

    # Surface introspection failure instead of silently reverting to the
    # notification churn (the freeze above simply stays inactive then).
    warnings =
      lib.optional (pkgs.stdenv.isDarwin && config.age.secrets != { } && agenixMountCommand == null)
        "agenix launchd command could not be recovered from option definitions; plist freeze is inactive and 'sh' background notifications will return.";

    # writeBoundary 뒤에 래퍼를 현재 세대의 mount script로 갱신하고 secret을 다시 마운트한다.
    # 마운트 실패는 다음 로그인 때 launchd가 재시도하므로 치명적 오류로 처리하지 않는다.
    home.activation.writeAgenixLaunchdWrapper =
      lib.mkIf (pkgs.stdenv.isDarwin && agenixMountCommand != null)
        (
          lib.hm.dag.entryBetween [ "setupLaunchAgents" ] [ "writeBoundary" ] ''
            wrapperPath=${lib.escapeShellArg agenixLaunchdWrapper}
            if ! cmp -s ${agenixWrapperSource} "$wrapperPath" || [ ! -x "$wrapperPath" ]; then
              run install -D -m 0755 ${agenixWrapperSource} "$wrapperPath"
              run "$wrapperPath" \
                || warnEcho "[agenix] secret remount failed; will retry at next login (see ~/Library/Logs/agenix)"
            fi
          ''
        );

    age = {
      identityPaths = [ "${homeDirectory}/.ssh/id_ed25519" ];
    }
    // lib.optionalAttrs pkgs.stdenv.isDarwin {
      # macOS 임시 디렉터리가 정리되어도 장기 사용 secret을 읽는 앱이 중단되지 않도록
      # 복호화한 agenix 세대를 XDG state에 보관한다.
      secretsDir = "${config.xdg.stateHome}/agenix";
      secretsMountPoint = "${config.xdg.stateHome}/agenix.d";
    };

    # Home Manager의 `launchctl bootout --wait` 오류를 피하려고 변경된 agenix plist를 먼저 내리고 삭제한다.
    # upstream이 `--wait`를 전달하지 않게 되면 이 우회 로직을 제거한다.
    home.activation.bootoutAgenixBeforeLaunchAgents = lib.mkIf pkgs.stdenv.isDarwin (
      lib.hm.dag.entryBefore [ "setupLaunchAgents" ] ''
        agentPlist="org.nix-community.home.activate-agenix.plist"
        newPlist="$(readlink -m "$newGenPath/LaunchAgents/$agentPlist")"
        oldPlist="${homeDirectory}/Library/LaunchAgents/$agentPlist"
        if [[ -e "$newPlist" && -e "$oldPlist" ]] && ! cmp -s "$newPlist" "$oldPlist"; then
          run /bin/launchctl bootout "gui/$UID/org.nix-community.home.activate-agenix" 2>/dev/null || true
          run rm -f "$oldPlist"
        fi
      ''
    );

    # XDG Base Directory Specification
    xdg = {
      enable = true;
      configHome = "${homeDirectory}/.config";
    };

    home = {
      inherit username homeDirectory;

      # Set language for shell sessions managed by home-manager
      language = {
        base = if isWSL then "C.UTF-8" else "ko_KR.UTF-8";
      };

      # Keep legacy nix profile installs visible in interactive shells.
      sessionPath = [
        "$HOME/.nix-profile/bin"
      ];

      # 기본 패키지 (모든 환경에서 공통)
      packages = with pkgs; [
        # Nix
        agent-core
        nixfmt

        # System utilities
        coreutils
        findutils
        gnupg
        libiconv

        # Development (common)
        docker
        gcc

        # Dev tools
        awscli2
        wranglerBin
        jq
        sqlite
        yq-go # yq 패키지는 더 이상 관리되지 않음
        fd
        ripgrep
        less
        wget
        curl
        rsync
        glow
        ntn
        pup

        # Git
        git
        gh
        lazygit
        delta
        bat

        # Python
        python3
        uv
        ruff

        # Rust
        rustup

        # JavaScript + Node.js
        bun
        pnpm
        nodejs
        typescript

        # Go
        go

        # Kubernetes
        kubectl
        kubectx
        kubernetes-helm

        # Secrets
        _1password-cli
        keybase
        agenixPackage
        agx

        # Modeling
        ffmpeg
        imagemagick
        yt-dlp

        # AI / Browser automation
        agent-browser

        # etc
        direnv

        # Fonts
        nerd-fonts.fira-code
        nerd-fonts.jetbrains-mono
        nanum-gothic-coding
        sarasa-gothic
        noto-fonts-cjk-sans
        noto-fonts-cjk-serif
      ];

      stateVersion = "26.05";

      # Rust/C 빌드 시 라이브러리 경로 (특히 macOS에서 libiconv 링킹용)
      sessionVariables = {
        LIBRARY_PATH = lib.makeLibraryPath [ pkgs.libiconv ];

        # rebuild마다 pup의 코드 서명이 바뀌어 macOS 키체인 알림이 반복되므로
        # 토큰을 ~/.config/pup/tokens_<site>.json에 0600 권한으로 저장한다.
        DD_TOKEN_STORAGE = "file";
      };
    };

    programs = {
      # Enable Home Manager
      home-manager = {
        enable = true;
      };

      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };
    };

  };
}
