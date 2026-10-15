{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.76.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-uOXnyp8tJvyEMBW3buDHpHuNfej6iy3y0aO8VUMhWDE=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-44UO3Zlpj9Y4N3XpdOtF02ZkAlWTZ3wyaNoYpNWb16Y=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-uMJdF37glQY1NDYod4waKKj0VgeBFvsIfNKXjF1Msrk=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-0CRR9aDT5Chl0A9d+5Yjw3pg3KdwsraQIa9GRFzXTs4=";
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
