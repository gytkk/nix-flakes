{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.64.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-e16zFeHmb/t6U6Zaqwx0ERYa1oY48KmEWmEbyKfmzTw=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-6VMHkhJRV0NOxhx4TNuyAXWPCRkCUSqaP3RrcqD4xaI=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-WvX+h4qy8VYXrNTbBKhHhNY82W766RUGmaomWRC8T5A=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-x8mBT8J1ZW7XzELK/NDFdXF5Lp3nPHNHBKuHURnBT3Y=";
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
