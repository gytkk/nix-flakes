{
  config,
  lib,
  pkgs,
  username,
  flakeDirectory,
  isWSL ? false,
  ...
}:

let
  cfg = config.modules.zed;

  mkSymlink = path: config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/modules/zed/${path}";

  # Nix로 관리할 확장 목록 (pkgs.zed-extensions에서 가져옴)
  nixExtensions = with pkgs.zed-extensions; [
    docker-compose
    dockerfile
    git-firefly
    make

    # Languages
    java
    scala
    sql
    nix
    proto
    toml
    html
    terraform
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

  # Zed config/data 경로 (플랫폼별)
  # Zed 0.222+ 부터 macOS에서도 config 경로가 ~/.config/zed 로 변경됨
  zedConfigPath = ".config/zed";

  zedDataPath =
    if pkgs.stdenv.isDarwin then "Library/Application Support/Zed" else ".local/share/zed";

  # WSL: Windows Zed 경로
  windowsZedConfigPath = "/mnt/c/Users/${username}/AppData/Roaming/Zed";
  windowsZedDataPath = "/mnt/c/Users/${username}/AppData/Local/Zed";

  # JSON 파일 생성 (WSL activation script용)
  settingsFile = pkgs.writeText "zed-settings.json" (builtins.readFile ./files/settings.json);
  keymapFile = pkgs.writeText "zed-keymap.json" (builtins.readFile ./files/keymap.json);
  themeFile = pkgs.writeText "one-half-light.json" (
    builtins.toJSON (lib.importJSON ../../themes/exports/zed/one-half-light.json)
  );

  # WSL: Windows Zed에 설정, 테마, 확장 배포 스크립트
  wslActivationScript = ''
    mkdir -p "${windowsZedConfigPath}/themes"
    mkdir -p "${windowsZedDataPath}/extensions/installed"

    # settings.json 백업 후 복사
    if [ -f "${windowsZedConfigPath}/settings.json" ] && [ ! -f "${windowsZedConfigPath}/settings.json.bak" ]; then
      cp "${windowsZedConfigPath}/settings.json" "${windowsZedConfigPath}/settings.json.bak"
      echo "Backed up existing settings to settings.json.bak"
    fi
    rm -f "${windowsZedConfigPath}/settings.json"
    cp "${settingsFile}" "${windowsZedConfigPath}/settings.json"

    # keymap.json 백업 후 복사
    if [ -f "${windowsZedConfigPath}/keymap.json" ] && [ ! -f "${windowsZedConfigPath}/keymap.json.bak" ]; then
      cp "${windowsZedConfigPath}/keymap.json" "${windowsZedConfigPath}/keymap.json.bak"
      echo "Backed up existing keymap to keymap.json.bak"
    fi
    rm -f "${windowsZedConfigPath}/keymap.json"
    cp "${keymapFile}" "${windowsZedConfigPath}/keymap.json"

    # 테마 파일 복사
    rm -f "${windowsZedConfigPath}/themes/one-half-light.json"
    cp "${themeFile}" "${windowsZedConfigPath}/themes/one-half-light.json"

    # 확장 복사 (Nix store → Windows 경로)
    for ext in ${extensionsDir}/*; do
      ext_name=$(basename "$ext")
      target="${windowsZedDataPath}/extensions/installed/$ext_name"
      rm -rf "$target"
      cp -rL "$ext" "$target"
    done

    echo "Zed config deployed to Windows:"
    echo "  - Settings: ${windowsZedConfigPath}"
    echo "  - Keymap: ${windowsZedConfigPath}"
    echo "  - Extensions: ${windowsZedDataPath}/extensions/installed"
  '';
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
      # macOS/Linux (non-WSL): 설정 파일을 repo에 직접 symlink
      (lib.mkIf (!isWSL) {
        # settings.json, keymap.json → repo 파일로 직접 symlink (mutable)
        home.file."${zedConfigPath}/settings.json".source = mkSymlink "files/settings.json";
        home.file."${zedConfigPath}/keymap.json".source = mkSymlink "files/keymap.json";

        # 커스텀 테마 → repo 파일로 직접 symlink (mutable)
        home.file."${zedConfigPath}/themes/one-half-light.json".source =
          config.lib.file.mkOutOfStoreSymlink "${flakeDirectory}/themes/exports/zed/one-half-light.json";

        # Nix로 확장 관리 (읽기 전용 — Nix 패키지 기반)
        home.file."${zedDataPath}/extensions/installed" = {
          recursive = true;
          force = true;
          source = extensionsDir;
        };
      })

      # WSL: Windows Zed에 설정, 테마, 확장 배포
      (lib.mkIf isWSL {
        home.activation.zedWindowsConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] wslActivationScript;
      })
    ]
  );
}
