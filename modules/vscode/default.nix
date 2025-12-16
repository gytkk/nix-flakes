{
  config,
  lib,
  pkgs,
  inputs,
  isWSL ? false,
  ...
}:

let
  # nix-vscode-extensions에서 시스템에 맞는 확장 가져오기 (nixpkgs에 없는 것만)
  marketplaceExtensions = inputs.nix-vscode-extensions.extensions.${pkgs.system}.vscode-marketplace;

  # unfree 확장에 대한 license override 헬퍼
  allowUnfree =
    ext:
    ext.overrideAttrs (old: {
      meta = (old.meta or { }) // {
        license = lib.licenses.mit;
      };
    });

  # nixpkgs 확장 (빠름, 캐시됨)
  nixpkgsExtensions = with pkgs.vscode-extensions; [
    # AI (copilot은 nixpkgs에서)
    github.copilot
    github.copilot-chat

    # Docker/Kubernetes
    ms-azuretools.vscode-docker
    ms-azuretools.vscode-containers
    ms-kubernetes-tools.vscode-kubernetes-tools
    ms-vscode-remote.remote-containers

    # Git/GitHub
    github.vscode-github-actions

    # Go
    golang.go

    # JavaScript/TypeScript
    bradlc.vscode-tailwindcss
    dbaeumer.vscode-eslint
    prisma.prisma

    # Localization
    ms-ceintl.vscode-language-pack-ko

    # Nix
    jnoortheen.nix-ide

    # Python
    charliermarsh.ruff
    ms-python.debugpy
    ms-python.python
    ms-python.vscode-pylance

    # Remote
    ms-vscode-remote.remote-wsl

    # Rust
    rust-lang.rust-analyzer

    # Terraform
    hashicorp.terraform

    # Tools
    ms-vscode.makefile-tools

    # Vim
    vscodevim.vim

    # YAML/TOML
    redhat.vscode-yaml
    tamasfe.even-better-toml
  ];

  # nix-vscode-extensions에서만 가져올 확장 (nixpkgs에 없거나 자주 업데이트되는 것들)
  extraExtensions = with marketplaceExtensions; [
    # AI (자주 업데이트되어 nixpkgs 해시가 오래됨)
    (allowUnfree anthropic.claude-code)

    # Theme
    mvllow.rose-pine
    catppuccin.catppuccin-vsc
    catppuccin.catppuccin-vsc-icons
    vscode-icons-team.vscode-icons

    # Git
    qezhu.gitlink

    # AWS
    boto3typed.boto3-ide

    # JavaScript/TypeScript
    vercel.turbo-vsc

    # Python (unfree)
    (allowUnfree ms-python.vscode-python-envs)
  ];

  # 공통 확장 프로그램 (macOS/Linux/WSL 모두 사용)
  commonExtensions = nixpkgsExtensions ++ extraExtensions;

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
    "workbench.colorTheme" = "Catppuccin Latte";
    "workbench.iconTheme" = "vscode-icons";
    "workbench.list.typeNavigationMode" = "filter";

    # Window
    "window.openFoldersInNewWindow" = "on";

    # Debug
    "debug.internalConsoleOptions" = "openOnSessionStart";

    # JavaScript
    "javascript.updateImportsOnFileMove.enabled" = "always";

    # Vim
    "vim.easymotion" = true;
    "vim.enableNeovim" = true;
    "vim.useCtrlKeys" = true;

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
  };
in
lib.mkMerge [
  # macOS/Linux (non-WSL): 전체 VSCode 설정
  (lib.mkIf (!isWSL) {
    programs.vscode = {
      enable = true;
      package = pkgs.vscode;
      mutableExtensionsDir = true;

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
