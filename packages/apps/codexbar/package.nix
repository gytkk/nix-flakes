{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.60.3";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-b1JnP2ZuuAZS3a6/fWSTv3z3C41vV8+nEA27aP5mYog=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-91flVpOuPI0bRUw23Tj584TIqpfWdgT2kB07TrST1X4=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-rJrrdWJGLgP5IyIxAzu8Vnf4HVPc/VN6p5VpdWgWNME=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-UjQrGE0NfrFsnDqD602Ke4b2a1YlQzFttL0DDPX6ns4=";
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
