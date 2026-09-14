{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.60.2";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-osoQK2xGKp0eH5Xms+AKadX9V8t/d/jto8hjHyKE61I=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-Xj9HzHqEnfIdrX6V19MmljOPvFXqVkZKkZFjgqSr3mo=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-LrQAzwRmNdwmBgHzCRDyKdRZLcSXR5KsKHDWta1/qUQ=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-5fxfRMf4+h30Ssu1py0stF/zdLfBULSEKTR+r+Kind4=";
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
