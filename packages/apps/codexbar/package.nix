{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.70.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-Ip/NP6clX8O42Qu9IJ1ttB1WPOILNuVtm2sbAa1nBJY=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-FR9KOUA7EZOl4lv3WNPjeTZZ208t4l2yQHVX+evDwGs=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-NHDILlXRAauo7XUoDazOmaIMjlWqNPQiSDhWB044Ib0=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-ZrB6FxjC/F3/9i0IUSKcIJLjyeoSPSe9KrfCcWvou2c=";
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
