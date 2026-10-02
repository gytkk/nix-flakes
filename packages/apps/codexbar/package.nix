{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.71.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-u/DtIuPxQnZMeTzhIUjw26sTwU8zSgUUfmfKj0+0SBw=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-aZXbX/Odv3MH86MBtUwbezNV4swkJf8iVAOIeRS/Ba0=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-t24jagxMEMdz+/waIZtEiRtAJMSSAiCgCXtsnWbCcxM=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-mx5SN6FEQFldsNZ3O+n8K14oKg/dPAL+yeqPZo33wt8=";
    };
  };

  platform =
    platformMap.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/steipete/CodexBar/releases/download/v${version}/CodexBarCLI-v${version}-${platform.target}.tar.gz";
    hash = platform.hash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "codexbar";
  inherit version src;

  dontStrip = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/lib/codexbar
    cp -R ./* $out/lib/codexbar/
    ln -s $out/lib/codexbar/CodexBarCLI $out/bin/codexbar
    runHook postInstall
  '';

  meta = {
    description = "CLI for Codex and Claude usage and cost data";
    homepage = "https://codex.bar";
    license = lib.licenses.mit;
    platforms = builtins.attrNames platformMap;
    mainProgram = "codexbar";
  };
}
