{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.63.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-cpcKSyWSkChoXhPUBU5BgNsxQHNCKiFEmJL1mR//S5E=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-B10/r+uKS1pIWsWxWTSZnh45MjZlrGIBv4CrYX2rEOQ=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-MiRhRvIXUwc8fh3zd/73bOkqba5eSGzihg9PFQiX8nw=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-66nnBVKbcDscOggLa6vmXenWbqiSPAV4BoInV1PfeEs=";
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
