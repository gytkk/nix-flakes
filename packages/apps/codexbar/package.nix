{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.65.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-cq0No5BYqE82zReKwqSS6xOfjJk5mXNGMCpDsZ1M8Ps=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-e/hb1wwbtlmS7rUpaMKm/5qZk2fJTRunG2BeyCUohJU=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-09bG280OWtHJt9iJ8aL1P7z2LJ5t32TTWyjzqyrOxYU=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-06G6ZSNkOXn2UaA8qvj1Umub8/r2fvw1cKBppNonBI8=";
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
