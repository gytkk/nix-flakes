{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.56.3";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-Y21ANSLVUXLvDLNLDY+xuDmUO0qQ1vNliJ5s6P6YwNY=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-guC7D/0epxoPYyK9gVV4ROHO1AuQhYzW2XDsQE2bz5o=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-YTYjbw8f8HJYuNTIyWTwr4uFSv+W1nCtCT6eL8c6q6M=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-9T1IpmKduFHDOhn5ORtTCNP1YzFSW6E50lfQaktyV6Y=";
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
