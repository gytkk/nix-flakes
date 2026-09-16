{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "0.9.1";

  platformMap = {
    "aarch64-darwin" = {
      target = "macos-aarch64";
      hash = "sha256-X8en5636ylb6gKqJ3LAlaTNXJo2rgoW5zi0IojE8id4=";
    };

    "x86_64-darwin" = {
      target = "macos-x86_64";
      hash = "sha256-BTvgY5k1/lSrXvvbRmUQVOT2p1OltDFTyIvWkSvOHpQ=";
    };

    "x86_64-linux" = {
      target = "linux-x86_64";
      hash = "sha256-KgL+0WvrZR7wBuHUPwSPZSyk3FitBTzS1ERQVj1cVLc=";
    };

    "aarch64-linux" = {
      target = "linux-aarch64";
      hash = "sha256-9Mz03nRfLLmjmpg+m6NwPa1Q7CpY3qgwJs6rchu9jZ4=";
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
