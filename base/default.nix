{
  config,
  options,
  lib,
  pkgs,
  username,
  homeDirectory,
  inputs,
  isWSL ? false,
  ...
}:

let
  # agenix's launchd agent execs a mount-secrets store path that changes with
  # every secrets/input update, and Home Manager wraps every agent command as
  # `/bin/sh -c "/bin/wait4path /nix/store && exec ..."`. Each plist change
  # therefore re-registers a new "sh" background item with macOS Background
  # Task Management and pops a notification. Freeze the plist by pointing it
  # at this stable out-of-store wrapper; writeAgenixLaunchdWrapper below
  # rewrites the wrapper (and remounts secrets) when the script changes.
  agenixLaunchdWrapper = "${config.xdg.stateHome}/agenix-launchd-wrapper";

  # Recover agenix's original mount command from the raw option definitions:
  # the merged config value is mkForce-replaced with the wrapper path, but the
  # definition list still contains agenix's plain list. Our own definition is
  # skipped because its nested mkIf marker is not discharged at this level
  # (and the ProgramArguments below it is an mkForce marker), so lib.isList
  # rejects it either way. Remove this workaround if Home Manager's launchd
  # module gains a stable-exec-path/BTM story or agenix exposes a stable
  # entry point.
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
    # 기본 모듈들 (항상 import됨)
    ../modules/agent-session-record
    ../modules/aerospace
    ../modules/claude
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
    # ProgramArguments is frozen to the stable wrapper path so the plist bytes
    # never change between generations (see agenixLaunchdWrapper above).
    launchd.agents.activate-agenix.config = lib.mkIf pkgs.stdenv.isDarwin {
      KeepAlive = lib.mkForce null;
      ProgramArguments = lib.mkIf (agenixMountCommand != null) (lib.mkForce [ agenixLaunchdWrapper ]);
    };

    # Daily session-mining loop: generate agent-core improvement candidates from
    # the workspace's new Claude Code transcripts, so the reflect -> promote loop
    # keeps improving on its own. The runner lives in the gytkk-space repo at a
    # stable path, so the plist bytes do not change between generations (same BTM
    # notification concern as agenix above). launchd catches up a missed 06:00 run
    # after the Mac wakes from sleep. See gytkk-space/automation/mine-sessions.sh.
    launchd.agents.claude-session-mining.config = lib.mkIf pkgs.stdenv.isDarwin {
      ProgramArguments = [
        "/bin/sh"
        "-c"
        "/bin/wait4path /nix/store && exec ${homeDirectory}/workspace/gytkk-space/automation/mine-sessions.sh"
      ];
      StartCalendarInterval = [
        {
          Hour = 6;
          Minute = 0;
        }
      ];
      ProcessType = "Background";
      StandardOutPath = "${homeDirectory}/Library/Logs/claude-mining/launchd.stdout";
      StandardErrorPath = "${homeDirectory}/Library/Logs/claude-mining/launchd.stderr";
    };

    # launchd opens the agent's StandardOut/ErrorPath at spawn time, before the
    # runner can create the directory itself, so ensure it exists at activation.
    home.activation.claudeMiningLogDir = lib.mkIf pkgs.stdenv.isDarwin (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run mkdir -p ${lib.escapeShellArg "${homeDirectory}/Library/Logs/claude-mining"}
      ''
    );

    # Surface introspection failure instead of silently reverting to the
    # notification churn (the freeze above simply stays inactive then).
    warnings =
      lib.optional (pkgs.stdenv.isDarwin && config.age.secrets != { } && agenixMountCommand == null)
        "agenix launchd command could not be recovered from option definitions; plist freeze is inactive and 'sh' background notifications will return.";

    # Keep the wrapper pointing at the current generation's mount script. The
    # stable plist means launchd no longer restarts the agent on switch, so
    # remount secrets here whenever the script changed. Runs after
    # writeBoundary so a failed pre-flight check cannot leave a rewritten
    # wrapper behind; a failed remount is non-fatal because launchd retries
    # at next login (RunAtLoad).
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
