{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.66.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-ehcr0UPRngdO1bP/smQsSGtpR922wkpToz/7Sj0WHVA=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-SHffzrIY8mQ9GJtnQYz9Zux4AgIcy5rCo5GsYiAsJPQ=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-TcE/8C8thZ7qZe67kca6utQszQfF/wjO3vQuO755wMQ=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-eQ6PbE9NUH8uyKZCGnMzkkgEYLFTSzP+PaqATusb9nY=";
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
