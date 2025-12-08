{
  config,
  lib,
  pkgs,
  inputs,
  isWSL ? false,
  ...
}:

let
  # nix-vscode-extensions에서 시스템에 맞는 확장 가져오기
  vscodeExtensions = inputs.nix-vscode-extensions.extensions.${pkgs.system};

  # unfree 확장에 대한 license override 헬퍼
  allowUnfree =
    ext:
    ext.overrideAttrs (old: {
      meta = (old.meta or { }) // {
        license = lib.licenses.mit;
      };
    });

  # 공통 확장 프로그램 (macOS/Linux/WSL 모두 사용)
  # Microsoft 확장들은 대부분 unfree이므로 allowUnfree 적용
  commonExtensions = with vscodeExtensions.vscode-marketplace; [
    # AI (unfree)
    (allowUnfree anthropic.claude-code)
    (allowUnfree github.copilot)
    (allowUnfree github.copilot-chat)

    # Theme (unfree)
    (allowUnfree monokai.theme-monokai-pro-vscode)
    fehey.brackets-light-pro

    # AWS
    boto3typed.boto3-ide

    # Dart/Flutter
    dart-code.dart-code
    dart-code.flutter

    # Docker/Kubernetes (unfree)
    (allowUnfree ms-azuretools.vscode-containers)
    (allowUnfree ms-kubernetes-tools.vscode-kubernetes-tools)
    (allowUnfree ms-vscode-remote.remote-containers)

    # Git/GitHub
    eamodio.gitlens
    github.vscode-github-actions

    # Go
    golang.go

    # JavaScript/TypeScript
    bradlc.vscode-tailwindcss
    dbaeumer.vscode-eslint
    prisma.prisma
    vercel.turbo-vsc

    # Localization (unfree)
    (allowUnfree ms-ceintl.vscode-language-pack-ko)

    # Markdown
    davidanson.vscode-markdownlint

    # Nix
    jnoortheen.nix-ide

    # Python (unfree)
    charliermarsh.ruff
    (allowUnfree ms-python.debugpy)
    (allowUnfree ms-python.python)
    (allowUnfree ms-python.vscode-pylance)
    (allowUnfree ms-python.vscode-python-envs)

    # Remote (unfree)
    (allowUnfree ms-vscode-remote.remote-wsl)

    # Rust
    rust-lang.rust-analyzer

    # Terraform
    hashicorp.terraform

    # Tools (unfree)
    (allowUnfree ms-vscode.makefile-tools)
    (allowUnfree sourcegraph.amp)

    # Vim
    vscodevim.vim

    # YAML/TOML
    redhat.vscode-yaml
    tamasfe.even-better-toml
  ];

  # WSL용 확장 심볼릭 링크 생성
  wslExtensionLinks = builtins.listToAttrs (
    map (ext: {
      name = ".vscode-server/extensions/${ext.vscodeExtUniqueId}";
      value = {
        source = ext;
      };
    }) commonExtensions
  );

  # 공통 설정
  userSettings = {
    # Editor
    "editor.fontFamily" = "'Jetbrains Mono', monospace";
    "editor.fontSize" = 14;
    "editor.formatOnPaste" = true;
    "editor.formatOnSave" = true;
    "editor.inlineSuggest.enabled" = true;
    "editor.tabSize" = 2;

    # Explorer
    "explorer.confirmDelete" = false;
    "explorer.confirmDragAndDrop" = false;
    "explorer.confirmPasteNative" = false;

    # Files
    "files.autoSave" = "afterDelay";
    "files.exclude" = {
      ".pytest_cache" = true;
      ".serena" = true;
      "**/__pycache__" = true;
      "**/.direnv" = true;
      "**/.idea" = true;
      "**/dist" = true;
      "**/node_modules" = true;
    };
    "files.insertFinalNewline" = true;

    # Workbench
    "workbench.colorTheme" = "Brackets Light Pro";
    "workbench.iconTheme" = "Visual Studio Light Icons";

    # Window
    "window.openFoldersInNewWindow" = "on";

    # Debug
    "debug.internalConsoleOptions" = "openOnSessionStart";

    # JavaScript
    "javascript.updateImportsOnFileMove.enabled" = "always";

    # Vim
    "vim.easymotion" = true;
    "vim.enableNeovim" = true;
    "vim.useCtrlKeys" = false;

    # Python
    "python.analysis.typeCheckingMode" = "standard";
    "python.venvPath" = "\${workspaceFolder}/.venv";
    "[python]" = {
      "editor.codeActionsOnSave" = {
        "source.fixAll" = "explicit";
        "source.organizeImports" = "explicit";
      };
      "editor.formatOnSave" = true;
      "editor.tabSize" = 4;
    };

    # Ruff
    "ruff.configuration" = "";
    "ruff.configurationPreference" = "filesystemFirst";

    # Dart
    "[dart]" = {
      "editor.formatOnSave" = true;
      "editor.formatOnType" = true;
      "editor.rulers" = [ 80 ];
      "editor.selectionHighlight" = false;
      "editor.tabCompletion" = "onlySnippets";
      "editor.wordBasedSuggestions" = "off";
    };

    # GitHub Copilot
    "github.copilot.advanced" = {
      "useLanguageServer" = true;
    };
    "github.copilot.enable" = {
      "*" = true;
      "markdown" = true;
      "plaintext" = false;
      "scminput" = false;
    };
    "github.copilot.nextEditSuggestions.enabled" = true;

    # Kubernetes
    "vs-kubernetes" = {
      "vs-kubernetes.crd-code-completion" = "enabled";
    };

    # Docker Compose
    "[dockercompose]" = {
      "editor.autoIndent" = "advanced";
      "editor.defaultFormatter" = "redhat.vscode-yaml";
      "editor.insertSpaces" = true;
      "editor.quickSuggestions" = {
        "comments" = false;
        "other" = true;
        "strings" = true;
      };
      "editor.tabSize" = 2;
    };

    # GitHub Actions
    "[github-actions-workflow]" = {
      "editor.defaultFormatter" = "redhat.vscode-yaml";
    };

    # Claude Code
    "claudeCode.preferredLocation" = "panel";

    # AMP
    "amp.url" = "https://ampcode.com/";

    # Telemetry
    "redhat.telemetry.enabled" = true;
  };
in
lib.mkMerge [
  # macOS/Linux (non-WSL): 전체 VSCode 설정
  (lib.mkIf (!isWSL) {
    programs.vscode = {
      enable = true;
      package = pkgs.vscode;

      profiles.default = {
        extensions = commonExtensions;
        inherit userSettings;
      };
    };
  })

  # WSL: 확장만 심볼릭 링크로 설치 (VSCode는 Windows에서 실행)
  (lib.mkIf isWSL {
    home.file = wslExtensionLinks;
  })
]
