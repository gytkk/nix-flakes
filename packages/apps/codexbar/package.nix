{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.69.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-lvKB+2DqRXe7cxbQ1bHcGi0M8gY9zEsEb6SS6TpQc3s=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-7bJ0IV3AQKKxy8iRjPBNHkpbo+VCebc2x2s83W1DwHI=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-znywfcDMuH9PBpH/9Tc68NbVs3bthhsSV5+23Vwc4Jg=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-c5PEol9b3j3PF6j76KTufmcDQ25syTxiv5VtCklEUdM=";
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
