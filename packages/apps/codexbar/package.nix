{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.60.4";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-aaG1JwJ4UN2hNFc0lUy5AHkBBjM9L5VtAlVJMxNFpKc=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-szzbDOG5Tb1O2FoI3AwszuxXZzw0QB2qaoofa5rwkdo=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-8GKyba26KW1QhhQDns/h5IAo3P7mQhp4pH7MuiHsPpE=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-oygcik7RgPY9axV77TMNKOS6bMn1riLHLK9PLAkRGwI=";
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
