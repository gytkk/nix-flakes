{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.64.1";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-lau46ihVCibumECA9uq8NjJoJf4Hx52nq05ifhth/24=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-37ws8ioGbLxEKf5Fdt+sxHn3JmZGR2eVgIeAFuZ5umE=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-S86hfbvU/aOyhI137Q2/oV30UrixhHL9/hUHpX/BQUw=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-3H6XjjGex65RiAJEgwmXHRk6qX79SGEIXvU4tGABOts=";
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
