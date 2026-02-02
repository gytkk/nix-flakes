{
  config,
  lib,
  pkgs,
  username,
  isWSL ? false,
  ...
}:

let
  cfg = config.modules.zed;

  # 커스텀 One Half Light 테마
  oneHalfLightTheme = lib.importJSON ./themes/one-half-light.json;

  # Nix로 관리할 확장 목록 (pkgs.zed-extensions에서 가져옴)
  nixExtensions = with pkgs.zed-extensions; [
    docker-compose
    dockerfile
    git-firefly
    html
    make
    nix
    sql
    toml
  ];

  # 모든 확장을 하나의 디렉토리로 병합
  extensionsDir = pkgs.runCommand "zed-extensions-merged" { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (ext: ''
      if [ -d "${ext}/share/zed/extensions" ]; then
        for dir in ${ext}/share/zed/extensions/*; do
          if [ -d "$dir" ]; then
            cp -rL "$dir" $out/
          fi
        done
      fi
    '') nixExtensions}
  '';

  # 공통 설정
  userSettings = {
    # Telemetry
    telemetry = {
      diagnostics = false;
      metrics = false;
    };

    # UI
    ui_font_family = "JetBrainsMono Nerd Font";
    ui_font_size = 14;
    buffer_font_family = "JetBrainsMono Nerd Font";
    buffer_font_size = 14;

    # Theme (커스텀 One Half Light 테마 사용)
    theme = {
      mode = "system";
      light = "One Half Light Custom";
      dark = "One Dark";
    };

    # Editor
    tab_size = 2;
    format_on_save = "on";
    remove_trailing_whitespace_on_save = true;
    ensure_final_newline_on_save = true;
    show_whitespaces = "boundary";

    # Vim mode
    vim_mode = true;
    vim = {
      use_system_clipboard = "always";
      use_smartcase_find = true;
    };

    # Base keymap (for non-vim keybindings)
    base_keymap = "VSCode";

    # Terminal
    terminal = {
      shell = {
        program = "zsh";
      };
      font_family = "JetBrainsMono Nerd Font";
      font_size = 14;
    };

    # File types
    file_types = {
      "JSON" = [
        "flake.lock"
      ];
    };

    # Languages
    languages = {
      Nix = {
        tab_size = 2;
        formatter = {
          external = {
            command = "nixfmt";
          };
        };
        language_servers = [
          "nixd"
        ];
      };
      Python = {
        tab_size = 4;
        format_on_save = "on";
        language_servers = [
          "ty"
        ];
      };
      Markdown = {
        soft_wrap = "editor_width";
      };
    };

    # LSP
    lsp = {
      nixd = {
        settings = {
          nixpkgs = {
            expr = "import <nixpkgs> {}";
          };
        };
      };
    };

    # Files
    file_scan_exclusions = [
      "**/.git"
      "**/.svn"
      "**/.hg"
      "**/CVS"
      "**/.DS_Store"
      "**/Thumbs.db"
      "**/.direnv"
      "**/node_modules"
      "**/__pycache__"
      "**/.pytest_cache"
      "**/dist"
      "**/.idea"
    ];

    # Git
    git = {
      inline_blame = {
        enabled = true;
      };
    };

    # Inlay hints
    inlay_hints = {
      enabled = true;
    };

    # Auto update
    auto_update = false;
  };

  # JSON 파일 생성
  settingsFile = pkgs.writeText "zed-settings.json" (builtins.toJSON userSettings);
  themeFile = pkgs.writeText "one-half-light-custom.json" (builtins.toJSON oneHalfLightTheme);

  # Windows Zed 경로 (WSL에서 접근)
  windowsZedConfigPath = "/mnt/c/Users/${username}/AppData/Roaming/Zed";
  windowsZedDataPath = "/mnt/c/Users/${username}/AppData/Local/Zed";
in
{
  options.modules.zed = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Zed editor module";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      # macOS/Linux (non-WSL): 전체 Zed 설정
      (lib.mkIf (!isWSL) {
        programs.zed-editor = {
          enable = true;
          package = pkgs.zed-editor;

          extraPackages = with pkgs; [
            nixd
            ty
          ];

          inherit userSettings;

          userKeymaps = [ ];

          mutableUserSettings = true;
          mutableUserKeymaps = true;

          themes = {
            "one-half-light-custom" = oneHalfLightTheme;
          };
        };

        # Nix로 확장 관리 (nix-zed-extensions Home Manager 모듈 방식)
        # macOS: ~/Library/Application Support/Zed/extensions/installed/
        # Linux: ~/.local/share/zed/extensions/installed/
        home.file."${
          if pkgs.stdenv.isDarwin then
            "Library/Application Support/Zed/extensions/installed"
          else
            ".local/share/zed/extensions/installed"
        }" =
          {
            recursive = true;
            source = extensionsDir;
          };

        # macOS: Nix로 설치된 Zed.app을 ~/Applications에 링크
        home.activation.installZedApp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          app_src="${pkgs.zed-editor}/Applications/Zed.app"
          app_dest="$HOME/Applications/Zed.app"

          if [ -e "$app_src" ]; then
            # 기존 앱 제거 (심볼릭 링크 또는 디렉토리)
            if [ -L "$app_dest" ] || [ -d "$app_dest" ]; then
              rm -rf "$app_dest"
            fi

            # 새 앱 복사 (심볼릭 링크 대신 복사 - Spotlight 인덱싱을 위해)
            mkdir -p "$HOME/Applications"
            cp -RL "$app_src" "$app_dest"
            echo "Zed.app installed to ~/Applications/"
          fi
        '';
      })

      # WSL: Windows Zed에 설정, 테마, 확장 배포 (Zed는 Windows에서 실행)
      (lib.mkIf isWSL {
        # WSL에서는 Zed 패키지 설치하지 않음 (Windows에서 실행)
        programs.zed-editor.enable = false;

        # activation 스크립트로 Windows 경로에 설정, 테마, 확장 복사
        home.activation.zedWindowsConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          # Windows Zed 설정 디렉토리 생성
          mkdir -p "${windowsZedConfigPath}/themes"
          mkdir -p "${windowsZedDataPath}/extensions/installed"

          # settings.json 복사 (Zed는 JSON5를 사용하므로 병합이 어려움)
          if [ -f "${windowsZedConfigPath}/settings.json" ] && [ ! -f "${windowsZedConfigPath}/settings.json.bak" ]; then
            cp "${windowsZedConfigPath}/settings.json" "${windowsZedConfigPath}/settings.json.bak"
            echo "Backed up existing settings to settings.json.bak"
          fi
          rm -f "${windowsZedConfigPath}/settings.json"
          cp "${settingsFile}" "${windowsZedConfigPath}/settings.json"

          # 테마 파일 복사 (기존 읽기 전용 파일 제거 후 복사)
          rm -f "${windowsZedConfigPath}/themes/one-half-light-custom.json"
          cp "${themeFile}" "${windowsZedConfigPath}/themes/one-half-light-custom.json"

          # 확장 복사 (Nix store에서 Windows 경로로)
          # 기존 Nix 관리 확장 제거 후 새로 복사
          for ext in ${extensionsDir}/*; do
            ext_name=$(basename "$ext")
            target="${windowsZedDataPath}/extensions/installed/$ext_name"

            # 기존 확장 제거 (심볼릭 링크든 디렉토리든)
            rm -rf "$target"

            # 새 확장 복사 (-L: 심볼릭 링크를 따라가서 실제 파일 복사)
            cp -rL "$ext" "$target"
          done

          echo "Zed config deployed to Windows:"
          echo "  - Settings: ${windowsZedConfigPath}"
          echo "  - Extensions: ${windowsZedDataPath}/extensions/installed"
        '';
      })
    ]
  );
}
