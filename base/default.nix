{
  config,
  lib,
  pkgs,
  username,
  homeDirectory,
  inputs,
  isWSL ? false,
  ...
}:

{
  imports = [
    # 기본 모듈들 (항상 import됨)
    ../modules/agent-session-record
    ../modules/aerospace
    ../modules/claude
    ../modules/cmux
    ../modules/codex
    ../modules/ghostty
    ../modules/git
    ../modules/k9s
    ../modules/lsp
    ../modules/omnigent
    ../modules/opencode
    ../modules/pi
    ../modules/tmux
    ../modules/vim
    ../modules/wezterm
    ../modules/zed
    ../modules/zellij
    ../modules/zsh
  ];

  options.modules.commonTheme = lib.mkOption {
    type = lib.types.str;
    default = "vira-graphene";
    description = "Canonical theme id shared across theme-aware app modules.";
    example = "catppuccin-mocha";
  };

  config = {
    modules = {
      agentSessionRecord.enable = lib.mkDefault true;
      aerospace.enable = lib.mkDefault pkgs.stdenv.isDarwin;
      claude.enable = lib.mkDefault true;
      cmux.enable = lib.mkDefault true;
      codex.enable = lib.mkDefault true;
      ghostty.enable = lib.mkDefault true;
      git.enable = lib.mkDefault true;
      k9s.enable = lib.mkDefault true;
      lsp.enable = lib.mkDefault true;
      omnigent.enable = lib.mkDefault true;
      opencode.enable = lib.mkDefault true;
      pi.enable = lib.mkDefault true;
      tmux.enable = lib.mkDefault true;
      vim.enable = lib.mkDefault true;
      wezterm.enable = lib.mkDefault true;
      zed.enable = lib.mkDefault true;
      zellij.enable = lib.mkDefault true;
      zsh.enable = lib.mkDefault true;
    };

    # Disable news on update
    news.display = "silent";

    # macOS: App Management 권한 문제 방지
    # stateVersion >= 25.11에서 copyApps가 기본 활성화되며,
    # 매 switch마다 tccutil reset으로 TCC App Management 권한을 리셋함
    # Nix로 .app 번들을 설치하지 않으므로 비활성화
    targets.darwin.copyApps.enable = false;

    # agenix's Home Manager LaunchAgent is a one-shot secret activation step.
    # Its upstream KeepAlive.Crashed=false makes launchd rerun it continuously
    # after normal exits, which can race with Home Manager's agent reload.
    launchd.agents.activate-agenix.config = lib.mkIf pkgs.stdenv.isDarwin {
      KeepAlive = lib.mkForce null;
    };

    # Home Manager agenix defaults to DARWIN_USER_TEMP_DIR on macOS. Keep
    # decrypted generations in XDG state so temp cleanup does not break apps
    # that read long-lived secrets such as Neovim's OpenAI API key.
    age = lib.mkIf pkgs.stdenv.isDarwin {
      secretsDir = "${config.xdg.stateHome}/agenix";
      secretsMountPoint = "${config.xdg.stateHome}/agenix.d";
    };

    # macOS `launchctl bootout` rejects the `--wait` flag that Home Manager
    # passes since nix-community/home-manager@9cb587a (2026-05-01), so its
    # agent reload aborts with "Unrecognized target specifier" and the
    # follow-up `bootstrap` fails with I/O error 5. This only bites when the
    # activate-agenix plist changes between generations. Pre-unload (plain
    # `bootout`, no `--wait`) and drop the stale plist so Home Manager's broken
    # reload path is skipped and it re-bootstraps cleanly. Remove once upstream
    # stops passing `--wait` to bootout.
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
        rustToolchain

        # JavaScript + Node.js
        bun
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
        inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default

        # Modeling
        ffmpeg
        imagemagick
        pkgs.stable-25_05.micromamba
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

    home.activation.installPackages = lib.mkForce (
      lib.hm.dag.entryAfter [ "writeBoundary" ] (
        if config.submoduleSupport.externalPackageInstall then
          ''
            nixProfileRemove home-manager-path
          ''
        else
          ''
            nixReplaceProfile() {
              local oldNix="$(command -v nix)"

              nixProfileRemove 'home-manager-path'

              run "$oldNix" profile install "$1"
            }

            if [[ -e ${config.home.profileDirectory}/manifest.json ]] ; then
              INSTALL_CMD="nix profile install"
              INSTALL_CMD_ACTUAL="nixReplaceProfile"
              LIST_CMD="nix profile list"
              REMOVE_CMD_SYNTAX='nix profile remove {number | store path}'
            else
              INSTALL_CMD="nix-env -i"
              INSTALL_CMD_ACTUAL="run nix-env -i"
              LIST_CMD="nix-env -q"
              REMOVE_CMD_SYNTAX='nix-env -e {package name}'
            fi

            if ! $INSTALL_CMD_ACTUAL ${config.home.path} ; then
              echo
              _iError $'Oops, Nix failed to install your new Home Manager profile!\n\nPerhaps there is a conflict with a package that was installed using\n"%s"? Try running\n\n    %s\n\nand if there is a conflicting package you can remove it with\n\n    %s\n\nThen try activating your Home Manager configuration again.' "$INSTALL_CMD" "$LIST_CMD" "$REMOVE_CMD_SYNTAX"
              exit 1
            fi

            unset -f nixReplaceProfile
            unset INSTALL_CMD INSTALL_CMD_ACTUAL LIST_CMD REMOVE_CMD_SYNTAX
          ''
      )
    );
  };
}
