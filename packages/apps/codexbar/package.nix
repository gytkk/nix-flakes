{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.56.5";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-HYSZw7ez8CPvAljxTRj8WUf5+bMpr4ZBN9mtCjt4Auk=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-pWlZ3HLYJAdMFWnCglkyI9YjF2jZ3Wx0bnofmOnSb6U=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-gokH6oif3SSaxNGl7MsLssZtzKZ2lF6NbEUPY0acbo4=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-eQiV3IELL5+MrfTQv5AYVruuIn3xzZOmMVlcqn6E22k=";
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
