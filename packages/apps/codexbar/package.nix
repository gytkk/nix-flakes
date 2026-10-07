{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.73.0";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-arm64";
      hash = "sha256-zY+FN3n4+uwAP1PV/CoWFK71d+yfYDy9WKlVm1ThWbk=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-GecFneaI5ivph5C8EBmCV/XTJuSj9BkRg8IxBuuReAo=";
    };

    "x86_64-linux" = {
      target = "linux-musl-x86_64";
      hash = "sha256-df2c/AB4Tu+Lrdbnb090y998E9sLf5ym4QXdt5Pm6Pg=";
    };

    "aarch64-linux" = {
      target = "linux-musl-aarch64";
      hash = "sha256-pAB9+mV3pDbq62tGYBmCxpVIxuIHMLPrkTPUJm1eqSs=";
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
