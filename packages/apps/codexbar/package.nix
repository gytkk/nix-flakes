{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.67.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-hr6gUPtBI4+6zOXpPWUP2+YDT2Oq8vozAUFH73GRDUk=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-by7Lv9SH6tLCQW0HqF5fI/ExXiZ0qKr3ftjPlZg+UFs=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-xo0K67TEsb/KZ0ATj87Trhvr0FHsMi1DYUFkAeG9uUQ=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-olixow9hw8lTHNZsKdVqNRB2jwHK/ZT1Xdq2DwjGF/U=";
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
