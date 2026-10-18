{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.77.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-6easleNYQC1IitPLTrpPSa0pZ9g858h9gnJxRfGpV2Q=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-ILwNrEWA1KLWbj7kP0gJVNJwkTttKXUeh6TF+CJdKlw=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-4esNB1aFe0uJQOHvB1Yn/JWC17Vd4GemII3BCEtmtDc=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-wq30BNch6t6KEcg/W2wSCMHt5V9cBuZk9cWqojZ7Hcw=";
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
