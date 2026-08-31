{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.8.2";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-aarch64";
      hash = "sha256-pdT01QTYswnJH4EQUFWTAPq6MSWEJfU8UIUvyW9q5XQ=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-q1AmLIGQzXqpBW0knSVcCMMow+hxbenPop208TG44sE=";
    };

    "x86_64-linux" = {
      target = "linux-x86_64";
      hash = "sha256-l2FQoU1JDJSyQ+ouGn6y37Z/EuNrGC25CTb2co5q7PQ=";
    };

    "aarch64-linux" = {
      target = "linux-aarch64";
      hash = "sha256-9VYQZY4cLg0qrvcwtLKriF9/i6AChas3K/sU8uPVtA0=";
    };
  };

  platform =
    platformMap.${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system: ${stdenvNoCC.hostPlatform.system}");

  src = fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-${platform.target}";
    hash = platform.hash;
  };
in
stdenvNoCC.mkDerivation {
  pname = "herdr";
  inherit version;

  dontUnpack = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ${src} $out/bin/herdr
    runHook postInstall
  '';

  meta = {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://herdr.dev";
    license = lib.licenses.asl20;
    platforms = builtins.attrNames platformMap;
    mainProgram = "herdr";
  };
}
