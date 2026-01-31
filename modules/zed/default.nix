{
  config,
  lib,
  pkgs,
  isWSL ? false,
  ...
}:

let
  cfg = config.modules.zed;

  # 커스텀 One Half Light 테마
  oneHalfLightTheme = lib.importJSON ./themes/one-half-light.json;
in
{
  options.modules.zed = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Zed editor module";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;
      package = pkgs.zed-editor;

      # 자동 설치할 확장 목록
      # https://github.com/zed-industries/extensions/tree/main/extensions
      extensions = [
        "dockerfile"
        "git-firefly"
        "html"
        "make"
        "nix"
        "sql"
        "toml"
      ];

      # extraPackages: Zed에서 사용할 LSP 서버 등
      extraPackages = with pkgs; [
        nixd
      ];

      # settings.json 설정
      userSettings = {
        # Telemetry
        telemetry = {
          diagnostics = false;
          metrics = false;
        };

        # Features
        features = {
          copilot = false;
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
          use_multiline_find = true;
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

      # keymap.json 설정
      userKeymaps = [ ];

      # 설정 파일 변경 허용 (mutable)
      mutableUserSettings = true;
      mutableUserKeymaps = true;

      # 커스텀 테마 (~/.config/zed/themes/ 에 배치됨)
      themes = {
        "one-half-light-custom" = oneHalfLightTheme;
      };
    };
  };
}
